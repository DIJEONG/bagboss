import Foundation
import Metal
import BBContent

/// 웹과 같은 5단계 렌더러: G-버퍼(스프라이트 · 그림자 · 3D) → 합성(느와르) → 블룸(밝은 부분 · 블러) → 후처리 → 화면 출력.
/// 단계별 결과는 `Targets` 에 남아 있어 테스트가 웹 캡처와 단계마다 비교한다.
public final class FrameRenderer {
    public let device: MTLDevice
    let atlasA: MTLTexture, atlasN: MTLTexture, palette: MTLTexture
    let spritePSO: MTLRenderPipelineState, shadowPSO: MTLRenderPipelineState, meshPSO: MTLRenderPipelineState
    let compositePSO: MTLRenderPipelineState, brightPSO: MTLRenderPipelineState, blurPSO: MTLRenderPipelineState, postPSO: MTLRenderPipelineState
    let farPSO: MTLRenderPipelineState, blur4PSO: MTLRenderPipelineState
    let library: MTLLibrary
    let noDepth: MTLDepthStencilState, lessDepth: MTLDepthStencilState
    private var blitPSOs: [MTLPixelFormat: MTLRenderPipelineState] = [:]
    /// 행인 그림 텍스처 고리(셋 — GPU 가 읽는 중인 것을 덮어쓰지 않게)
    private var passerTex: [MTLTexture] = [], passerK = 0, passerVer = 0
    /// 정점 버퍼 풀(프레임마다 makeBuffer 하지 않는다)
    private lazy var buffers = BufferPool(device: device)

    public static let gbufferFormat = MTLPixelFormat.rgba8Unorm
    public static let depthFormat = MTLPixelFormat.depth16Unorm
    /// 원경 흐림(무도장 깊이) 반 해상도 타깃 — rgb×가중 · 가중을 담아 8비트로는 어두운 곳이 뭉개진다
    public static let farFormat = MTLPixelFormat.rgba16Float

    /// - library: 미리 만든 셰이더 묶음(앱 번들 default.metallib 등). nil 이면 `library(for:)`(번들 → 실행 중 컴파일, 프로세스에 한 번)
    public init(device: MTLDevice, atlas: AtlasMeta, library prebuilt: MTLLibrary? = nil) throws {
        self.device = device
        // 무거운 것(아틀라스 풀기 · 텍스처 · 셰이더 · 파이프라인)은 프로세스에 한 번 — 렌더러를 여럿 만들어도(게임 · 보도 사진 · 점검 탭) 다시 하지 않는다
        let R = try Shared.resources(device: device, atlas: atlas, library: prebuilt)
        atlasA = R.atlasA; atlasN = R.atlasN; palette = R.palette; library = R.library
        spritePSO = R.pso[0]; shadowPSO = R.pso[1]; meshPSO = R.pso[2]
        compositePSO = R.pso[3]; brightPSO = R.pso[4]; blurPSO = R.pso[5]; postPSO = R.pso[6]
        farPSO = R.pso[7]; blur4PSO = R.pso[8]
        noDepth = R.noDepth; lessDepth = R.lessDepth
    }

    /// 프로세스 공용 자원(장치 · 아틀라스 원본마다 하나). 만들기는 잠금 밖 — 같은 열쇠를 동시에 만들면 먼저 끝난 것을 쓴다
    final class Shared: @unchecked Sendable {
        let atlasA: MTLTexture, atlasN: MTLTexture, palette: MTLTexture
        let library: MTLLibrary
        let pso: [MTLRenderPipelineState]
        let noDepth: MTLDepthStencilState, lessDepth: MTLDepthStencilState

        private static let lock = NSLock()
        nonisolated(unsafe) private static var cache: [String: Shared] = [:]
        nonisolated(unsafe) private static var libraries: [UInt64: MTLLibrary] = [:]

        static func resources(device: MTLDevice, atlas: AtlasMeta, library: MTLLibrary?) throws -> Shared {
            let key = "\(device.registryID)|\(atlas.sourceSha16)|\(atlas.atlas.a)"
            lock.lock(); if let r = cache[key] { lock.unlock(); return r }; lock.unlock()
            let r = try Shared(device: device, atlas: atlas, library: library)
            lock.lock(); defer { lock.unlock() }
            if let r0 = cache[key] { return r0 }
            cache[key] = r
            return r
        }

        /// 셰이더 묶음: ① 앱 번들의 default.metallib(Xcode 가 빌드 때 컴파일 — 앱 타깃에 Shaders.metal 을 넣어 둠)
        /// ② 없으면(swift test) 패키지 리소스 Shaders.metal 을 실행 중 컴파일. 프로세스에 한 번
        static func library(for device: MTLDevice) throws -> MTLLibrary {
            lock.lock(); if let l = libraries[device.registryID] { lock.unlock(); return l }; lock.unlock()
            let lib = try FrameRenderer.prebuiltLibrary(device) ?? FrameRenderer.makeLibrary(device)
            lock.lock(); defer { lock.unlock() }
            if let l0 = libraries[device.registryID] { return l0 }
            libraries[device.registryID] = lib
            return lib
        }

        private init(device: MTLDevice, atlas: AtlasMeta, library prebuilt: MTLLibrary?) throws {
            // 아틀라스 풀기(A · N 각 29MB) ‖ 셰이더 묶음 → 파이프라인 7개를 동시에
            let queue = device.makeCommandQueue()
            let box = Collect(4)
            let w = atlas.atlas.width, h = atlas.atlas.height, pal = atlas.palette
            let jobs: [(String, Int, Int)] = [(atlas.atlas.a, w, h), (atlas.atlas.n, w, h), (pal.file, pal.steps, pal.materials * pal.palettes)]
            DispatchQueue.concurrentPerform(iterations: 4) { k in
                box.run(k) { k < 3 ? try FrameRenderer.uploadPacked(device, queue, jobs[k].0, width: jobs[k].1, height: jobs[k].2,
                                                                     patch: k == 2 ? { NativePalette.apply(to: $0, steps: pal.steps, materials: pal.materials, palettes: pal.palettes) } : nil)
                                   : try prebuilt ?? Shared.library(for: device) }
            }
            try box.check()
            guard let a = box[0] as? MTLTexture, let n = box[1] as? MTLTexture, let p = box[2] as? MTLTexture, let lib = box[3] as? MTLLibrary else { throw RenderError.textureAllocation }
            atlasA = a; atlasN = n; palette = p; library = lib

            let g = [FrameRenderer.gbufferFormat, FrameRenderer.gbufferFormat]
            func desc(_ vs: String, _ fs: String, colors: [MTLPixelFormat], depth: Bool = false) -> MTLRenderPipelineDescriptor {
                let d = MTLRenderPipelineDescriptor()
                d.vertexFunction = lib.makeFunction(name: vs)
                d.fragmentFunction = lib.makeFunction(name: fs)
                for (i, f) in colors.enumerated() { d.colorAttachments[i].pixelFormat = f }
                if depth { d.depthAttachmentPixelFormat = FrameRenderer.depthFormat }
                return d
            }
            let shadow = desc("spriteVS", "spriteFS", colors: g, depth: true)
            // 그림자: 웹 blendFunc(DST_COLOR, ZERO) + colorMask(G 만) — 두 장 모두에 적용(GL colorMask 는 전역)
            for i in 0..<2 {
                let c = shadow.colorAttachments[i]!
                c.isBlendingEnabled = true
                c.sourceRGBBlendFactor = .destinationColor; c.destinationRGBBlendFactor = .zero
                c.sourceAlphaBlendFactor = .destinationAlpha; c.destinationAlphaBlendFactor = .zero
                c.writeMask = .green
            }
            let F = [FrameRenderer.gbufferFormat]
            nonisolated(unsafe) let descs = [desc("spriteVS", "spriteFS", colors: g, depth: true), shadow, desc("meshVS", "meshFS", colors: g, depth: true),
                         desc("fullVS", "compositeNoirFS", colors: F), desc("fullVS", "brightFS", colors: F),
                         desc("fullVS", "blurFS", colors: F), desc("fullVS", "postFS", colors: F),
                         desc("fullVS", "farFS", colors: [FrameRenderer.farFormat]), desc("fullVS", "blur4FS", colors: [FrameRenderer.farFormat])]
            let pbox = Collect(descs.count)
            DispatchQueue.concurrentPerform(iterations: descs.count) { k in pbox.run(k) { try device.makeRenderPipelineState(descriptor: descs[k]) } }
            try pbox.check()
            pso = (0..<descs.count).compactMap { pbox[$0] as? MTLRenderPipelineState }
            guard pso.count == descs.count else { throw RenderError.encoder }

            let nd = MTLDepthStencilDescriptor(); nd.depthCompareFunction = .always; nd.isDepthWriteEnabled = false
            let ld = MTLDepthStencilDescriptor(); ld.depthCompareFunction = .less; ld.isDepthWriteEnabled = true
            noDepth = device.makeDepthStencilState(descriptor: nd)!
            lessDepth = device.makeDepthStencilState(descriptor: ld)!
        }
    }

    /// 앱 번들(Bundle.main)의 default.metallib 에 이 렌더러 함수가 다 있으면 그것(빌드 때 컴파일 — MTL_FAST_MATH=NO). 없으면 nil
    static func prebuiltLibrary(_ device: MTLDevice) -> MTLLibrary? {
        if ProcessInfo.processInfo.environment["BB_SHADER_SOURCE"] == "1" { return nil }   // 대조용: 실행 중 컴파일 강제
        guard let lib = try? device.makeDefaultLibrary(bundle: .main) else { return nil }
        let need: Set = ["spriteVS", "spriteFS", "meshVS", "meshFS", "fullVS", "compositeNoirFS", "brightFS", "blurFS", "postFS", "blitFS", "farFS", "blur4FS"]
        return need.isSubset(of: Set(lib.functionNames)) ? lib : nil
    }

    /// 셰이더는 실행 중에 컴파일한다(`swift test` 에서도 같은 경로). 빠른 수학은 끈다 — 웹의 fract(sin()) 해시와 맞추려고.
    static func makeLibrary(_ device: MTLDevice) throws -> MTLLibrary {
        guard let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal") else { throw RenderError.missingShaders }
        let src = try String(contentsOf: url, encoding: .utf8)
        let o = MTLCompileOptions()
        if #available(iOS 18.0, macOS 15.0, *) { o.mathMode = .safe } else { o.fastMathEnabled = false }
        return try device.makeLibrary(source: src, options: o)
    }

    /// 프로세스 공용 셰이더 묶음(앱이 시작 때 뒤 스레드에서 미리 부른다)
    public static func sharedLibrary(_ device: MTLDevice) throws -> MTLLibrary { try Shared.library(for: device) }

    static func upload(_ device: MTLDevice, _ img: RGBA8Image) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: img.width, height: img.height, mipmapped: false)
        d.usage = .shaderRead
        d.storageMode = .shared
        guard let t = device.makeTexture(descriptor: d) else { throw RenderError.textureAllocation }
        img.bytes.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, img.width, img.height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: img.width * 4) }
        return t
    }

    /// 압축 픽셀 파일 → 공유 MTLBuffer 로 바로 풀기 → GPU 복사로 private 텍스처(사본 · 타일링 CPU 복사 없음). 끝날 때까지 기다린다
    static func uploadPacked(_ device: MTLDevice, _ queue: MTLCommandQueue?, _ file: String, width: Int, height: Int,
                             patch: ((UnsafeMutableRawPointer) -> Void)? = nil) throws -> MTLTexture {
        let len = width * height * 4
        guard let queue, let buf = device.makeBuffer(length: len, options: .storageModeShared) else { throw RenderError.textureAllocation }
        try RGBA8Image.decompress(file, width: width, height: height, into: buf.contents())
        patch?(buf.contents())   // 팔레트: 네이티브 재질 램프(빈 줄만 — BBContent NativePalette)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        d.usage = .shaderRead
        d.storageMode = .private
        guard let t = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer(), let b = cb.makeBlitCommandEncoder() else { throw RenderError.textureAllocation }
        b.copy(from: buf, sourceOffset: 0, sourceBytesPerRow: width * 4, sourceBytesPerImage: len, sourceSize: MTLSize(width: width, height: height, depth: 1),
               to: t, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        b.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        if let e = cb.error { throw e }
        return t
    }

    // MARK: 렌더 타깃

    /// 장면 해상도의 중간 결과들. 해상도가 바뀌면 새로 만든다(웹 allocTargets).
    public final class Targets {
        public let width: Int, height: Int
        public let gInfo: MTLTexture, gNorm: MTLTexture, depth: MTLTexture, comp: MTLTexture
        public let bloomA: MTLTexture, bloomB: MTLTexture, post: MTLTexture
        /// 네이티브 원경 흐림(반 해상도) · 지난 열쇠 · 나이(캐시 — 너무 오래 쓰지 않게)
        public let farA: MTLTexture, farB: MTLTexture
        var farKey: Int?, farAge = 0
        public init(device: MTLDevice, width: Int, height: Int) throws {
            self.width = width; self.height = height
            func make(_ w: Int, _ h: Int, _ f: MTLPixelFormat = FrameRenderer.gbufferFormat) throws -> MTLTexture {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: f, width: w, height: h, mipmapped: false)
                d.usage = [.renderTarget, .shaderRead]; d.storageMode = .private
                guard let t = device.makeTexture(descriptor: d) else { throw RenderError.textureAllocation }
                return t
            }
            gInfo = try make(width, height); gNorm = try make(width, height); comp = try make(width, height)
            depth = try make(width, height, FrameRenderer.depthFormat)
            bloomA = try make(width >> 1, height >> 1); bloomB = try make(width >> 1, height >> 1); post = try make(width, height)
            farA = try make(width >> 1, height >> 1, FrameRenderer.farFormat); farB = try make(width >> 1, height >> 1, FrameRenderer.farFormat)
        }
        /// 화면에 낼 최종 장면(후처리가 있으면 그 결과)
        public func output(for frame: RenderFrame) -> MTLTexture { frame.post == nil ? comp : post }
    }

    // MARK: 인코딩

    public func encode(_ f: RenderFrame, targets t: Targets, into cb: MTLCommandBuffer) throws {
        guard t.width == f.width, t.height == f.height else { throw RenderError.targetSize }
        try encodeGBuffer(f, t, cb)
        try fullscreen(cb, t.comp, compositePSO, uniforms: f.compositeUniforms, textures: [t.gInfo, t.gNorm, palette])
        if let p = f.post {
            try fullscreen(cb, t.bloomA, brightPSO, uniforms: [SIMD4(Float(f.width), Float(f.height), 0, 0)], textures: [t.comp, t.gInfo])
            let half = SIMD2(Float(f.width >> 1), Float(f.height >> 1))
            for r in p.blurRadii {
                try fullscreen(cb, t.bloomB, blurPSO, uniforms: [SIMD4(r, 0, half.x, half.y)], textures: [t.bloomA])
                try fullscreen(cb, t.bloomA, blurPSO, uniforms: [SIMD4(0, r, half.x, half.y)], textures: [t.bloomB])
            }
            // 네이티브 원경 흐림(무도장 깊이): 먼 층만 반 해상도로 뽑아 흐린다 — 열쇠가 같으면(정지 층 · 같은 카메라) 지난 것을 그대로(30프레임마다 새로)
            if p.wantsFar {
                if p.farKey == nil || p.farKey != t.farKey || t.farAge >= 30 {
                    try fullscreen(cb, t.farA, farPSO, uniforms: [SIMD4(Float(f.width), Float(f.height), p.depthFar.y, 0)], textures: [t.comp, t.gInfo, t.gNorm])
                    try fullscreen(cb, t.farB, blur4PSO, uniforms: [SIMD4(p.farBlur, 0, half.x, half.y)], textures: [t.farA])
                    try fullscreen(cb, t.farA, blur4PSO, uniforms: [SIMD4(0, p.farBlur, half.x, half.y)], textures: [t.farB])
                    t.farKey = p.farKey; t.farAge = 0
                } else { t.farAge += 1 }
            } else { t.farKey = nil }
            try fullscreen(cb, t.post, postPSO, uniforms: f.postUniforms(p), textures: [t.comp, t.bloomA, t.gInfo, t.gNorm, t.farA, try passerTexture(p) ?? t.farB])
        }
    }

    private func encodeGBuffer(_ f: RenderFrame, _ t: Targets, _ cb: MTLCommandBuffer) throws {
        let rp = MTLRenderPassDescriptor()
        for (i, tex) in [t.gInfo, t.gNorm].enumerated() {
            rp.colorAttachments[i].texture = tex; rp.colorAttachments[i].loadAction = .clear
            rp.colorAttachments[i].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0); rp.colorAttachments[i].storeAction = .store
        }
        rp.depthAttachment.texture = t.depth; rp.depthAttachment.loadAction = .clear; rp.depthAttachment.clearDepth = 1; rp.depthAttachment.storeAction = .dontCare
        guard let e = cb.makeRenderCommandEncoder(descriptor: rp) else { throw RenderError.encoder }
        e.label = "G-버퍼"
        let sv = buffers.buffer(f.spriteVertices, for: cb)
        let mv = buffers.buffer(f.meshVertices, for: cb)
        let su = f.spriteUniforms, shu = f.shadowUniforms
        e.setFragmentTexture(atlasA, index: 0); e.setFragmentTexture(atlasN, index: 1)
        e.setFragmentBytes(f.remap, length: f.remap.count * 4, index: 1)
        for d in f.gbuffer {
            switch d {
            case .sprite(let first, let count, let shadow):
                guard let sv, count > 0 else { continue }
                e.setRenderPipelineState(shadow ? shadowPSO : spritePSO); e.setDepthStencilState(noDepth)
                let u = shadow ? shu : su
                e.setVertexBuffer(sv, offset: 0, index: 0)
                e.setVertexBytes(u, length: u.count * 16, index: 1); e.setFragmentBytes(u, length: u.count * 16, index: 0)
                e.drawPrimitives(type: .triangle, vertexStart: first, vertexCount: count)
            case .mesh(let first, let count):
                guard let mv, count > 0 else { continue }
                e.setRenderPipelineState(meshPSO); e.setDepthStencilState(lessDepth)
                e.setVertexBuffer(mv, offset: 0, index: 0); e.setVertexBytes(su, length: su.count * 16, index: 1)
                e.drawPrimitives(type: .triangle, vertexStart: first, vertexCount: count)
            }
        }
        e.endEncoding()
    }

    private func fullscreen(_ cb: MTLCommandBuffer, _ target: MTLTexture, _ pso: MTLRenderPipelineState,
                            uniforms: [SIMD4<Float>], textures: [MTLTexture]) throws {
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = target; rp.colorAttachments[0].loadAction = .dontCare; rp.colorAttachments[0].storeAction = .store
        guard let e = cb.makeRenderCommandEncoder(descriptor: rp) else { throw RenderError.encoder }
        e.setRenderPipelineState(pso)
        e.setFragmentBytes(uniforms, length: uniforms.count * 16, index: 0)
        for (i, t) in textures.enumerated() { e.setFragmentTexture(t, index: i) }
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    /// 행인 그림을 작은 텍스처로(무도장 깊이 — 이벤트 동안만). 크기가 바뀌면 다시 만든다
    private func passerTexture(_ p: PostParams) throws -> MTLTexture? {
        guard let px = p.passer, p.passerSize.x > 0, px.count == p.passerSize.x * p.passerSize.y * 4 else { return nil }
        let w = p.passerSize.x, h = p.passerSize.y
        if passerTex.first.map({ $0.width != w || $0.height != h }) ?? true {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
            d.usage = .shaderRead; d.storageMode = .shared
            passerVer = 0
            passerTex = try (0..<3).map { _ in guard let t = device.makeTexture(descriptor: d) else { throw RenderError.textureAllocation }; return t }
        }
        if p.passerVersion != 0 && p.passerVersion == passerVer { return passerTex[passerK] }   // 같은 판 — 다시 올리지 않는다
        passerVer = p.passerVersion
        passerK = (passerK + 1) % passerTex.count
        let t = passerTex[passerK]
        px.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: w * 4) }
        return t
    }

    /// 화면(드로어블) 출력 — 패스 설명자는 호출자가 준비한다(MTKView.currentRenderPassDescriptor 등)
    public func encodeBlit(_ f: RenderFrame, source: MTLTexture, pass: MTLRenderPassDescriptor, format: MTLPixelFormat, into cb: MTLCommandBuffer) throws {
        let pso = try blitPSO(format)
        guard let e = cb.makeRenderCommandEncoder(descriptor: pass), let target = pass.colorAttachments[0].texture else { throw RenderError.encoder }
        let b = f.blit
        let u: [SIMD4<Float>] = [SIMD4(Float(f.width), Float(f.height), Float(target.width), Float(target.height)),
                                 SIMD4(b.zoom, b.zoomCenter.x, b.zoomCenter.y, b.cameraX), SIMD4(b.visibleWidth, b.roll, 0, 0)]
        e.setRenderPipelineState(pso)
        e.setFragmentBytes(u, length: u.count * 16, index: 0); e.setFragmentTexture(source, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    /// 화면 출력 파이프라인을 미리 만든다(첫 프레임 멈칫 줄이기 — 앱이 뒤 스레드에서 부른다)
    public func prepareBlit(format: MTLPixelFormat) throws { _ = try blitPSO(format) }

    private func blitPSO(_ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
        if let p = blitPSOs[format] { return p }
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = library.makeFunction(name: "fullVS"); d.fragmentFunction = library.makeFunction(name: "blitFS")
        d.colorAttachments[0].pixelFormat = format
        let p = try device.makeRenderPipelineState(descriptor: d); blitPSOs[format] = p; return p
    }

    // MARK: 읽기(테스트 · 디버그)

    /// 렌더 타깃을 RGBA8 바이트(행 우선, 위→아래)로 읽는다. 동기 — 테스트 · 디버그 전용.
    public func readBack(_ tex: MTLTexture, queue: MTLCommandQueue) throws -> [UInt8] {
        let bpr = tex.width * 4, len = bpr * tex.height
        guard let buf = device.makeBuffer(length: len, options: .storageModeShared),
              let cb = queue.makeCommandBuffer(), let b = cb.makeBlitCommandEncoder() else { throw RenderError.encoder }
        b.copy(from: tex, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: tex.width, height: tex.height, depth: 1),
               to: buf, destinationOffset: 0, destinationBytesPerRow: bpr, destinationBytesPerImage: len)
        b.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        return [UInt8](UnsafeRawBufferPointer(start: buf.contents(), count: len))
    }
}

/// 병렬 작업 결과 모으기(잠금)
final class Collect: @unchecked Sendable {
    private let lock = NSLock()
    private var out: [Any?]
    private var errors: [Error] = []
    init(_ n: Int) { out = Array(repeating: nil, count: n) }
    func run(_ k: Int, _ f: () throws -> Any) {
        do { let v = try f(); lock.lock(); out[k] = v; lock.unlock() } catch { lock.lock(); errors.append(error); lock.unlock() }
    }
    func check() throws { lock.lock(); defer { lock.unlock() }; if let e = errors.first { throw e } }
    subscript(k: Int) -> Any? { lock.lock(); defer { lock.unlock() }; return out[k] }
}

public enum RenderError: Error {
    case missingShaders, textureAllocation, encoder, targetSize, badCapture(String)
}
