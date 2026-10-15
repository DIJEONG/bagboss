import Foundation
import Metal
import BBPresentation

// 오버레이 패스(docs/06 §2.5 'Overlay'): 웹 `#ui` 캔버스(무대 VW·3 × H·3, 무대 뷰에 맞춰 nearest 로 늘림)를 대신한다.
// 입력은 BBPresentation 의 OverlayList(HUDOverlay.build) 하나 — 게임 상태를 읽지 않는다.
//  · UI 해상도 4×MSAA 컬러 + 스텐실8 → 단일 표본으로 풀기(캔버스 안티에일리어싱 흉내)
//  · 경로 채우기 = 스텐실 감김(nonzero) → 덮개, 선 = 스텐실 1 → 덮개, 자르기 = 스텐실 0x80 비트
//  · 텍스처는 아틀라스 한 장(CPU OverlayAtlas → dirty 행만 올림). 최근접/선형 표본은 정점이 고른다
// 결과(output)는 미리 곱한 RGBA. encodeComposite 가 화면(드로어블) 위에 최근접으로 얹는다(웹 .ui-layer image-rendering:pixelated).
// 셰이더는 아래 문자열(패키지 리소스를 늘리지 않으려고 — Shaders.metal 은 웹 GLSL 1:1 이식 전용).

public final class OverlayRenderer {
    public let device: MTLDevice
    let colorPSO: MTLRenderPipelineState, stencilPSO: MTLRenderPipelineState
    let library: MTLLibrary
    private var compositePSOs: [MTLPixelFormat: MTLRenderPipelineState] = [:]
    /// 정점 버퍼 풀(프레임마다 makeBuffer 하지 않는다)
    private lazy var buffers = BufferPool(device: device)
    private var ds: [String: MTLDepthStencilState] = [:]
    private var atlasTex: MTLTexture
    private var uploadedVersion = -1
    private weak var uploadedAtlas: OverlayAtlas?
    public static let sampleCount = 4
    public static let format = MTLPixelFormat.rgba8Unorm

    public init(device: MTLDevice) throws {
        self.device = device
        let lib = try Self.sharedLibrary(device)
        library = lib
        func pso(_ fs: String, writes: Bool, blend: Bool) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = lib.makeFunction(name: "overlayVS"); d.fragmentFunction = lib.makeFunction(name: fs)
            d.colorAttachments[0].pixelFormat = Self.format
            d.stencilAttachmentPixelFormat = .stencil8
            d.rasterSampleCount = Self.sampleCount
            if !writes { d.colorAttachments[0].writeMask = [] }
            if blend {
                let c = d.colorAttachments[0]!
                c.isBlendingEnabled = true
                c.sourceRGBBlendFactor = .one; c.destinationRGBBlendFactor = .oneMinusSourceAlpha
                c.sourceAlphaBlendFactor = .one; c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: d)
        }
        colorPSO = try pso("overlayFS", writes: true, blend: true)
        stencilPSO = try pso("overlayFS", writes: false, blend: false)
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: OverlayAtlas.size, height: OverlayAtlas.size, mipmapped: false)
        td.usage = .shaderRead; td.storageMode = .shared
        guard let t = device.makeTexture(descriptor: td) else { throw RenderError.textureAllocation }
        atlasTex = t
    }

    private static let libLock = NSLock()
    nonisolated(unsafe) private static var libraries: [UInt64: MTLLibrary] = [:]

    /// 오버레이 셰이더 묶음(문자열 소스 → 실행 중 컴파일, 프로세스에 한 번 — 앱은 시작 때 뒤 스레드에서 미리 부른다)
    public static func sharedLibrary(_ device: MTLDevice) throws -> MTLLibrary {
        libLock.lock(); if let l = libraries[device.registryID] { libLock.unlock(); return l }; libLock.unlock()
        let lib = try device.makeLibrary(source: source, options: MTLCompileOptions())
        libLock.lock(); defer { libLock.unlock() }
        if let l0 = libraries[device.registryID] { return l0 }
        libraries[device.registryID] = lib
        return lib
    }

    /// 화면 얹기 파이프라인을 미리 만든다(첫 HUD 프레임 멈칫 줄이기)
    public func prepareComposite(format: MTLPixelFormat) throws { _ = try compositePSO(format) }

    private func compositePSO(_ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
        if let p = compositePSOs[format] { return p }
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = library.makeFunction(name: "overlayFullVS"); d.fragmentFunction = library.makeFunction(name: "overlayCompositeFS")
        d.colorAttachments[0].pixelFormat = format
        let c = d.colorAttachments[0]!
        c.isBlendingEnabled = true
        c.sourceRGBBlendFactor = .one; c.destinationRGBBlendFactor = .oneMinusSourceAlpha
        c.sourceAlphaBlendFactor = .one; c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        let pso = try device.makeRenderPipelineState(descriptor: d); compositePSOs[format] = pso
        return pso
    }

    /// UI 해상도 대상(다중 표본 · 스텐실 · 결과)
    public final class Target {
        public let width: Int, height: Int
        let msaa: MTLTexture, stencil: MTLTexture
        public let output: MTLTexture
        public init(device: MTLDevice, width: Int, height: Int) throws {
            self.width = width; self.height = height
            func make(_ f: MTLPixelFormat, _ samples: Int, _ usage: MTLTextureUsage, memoryless: Bool) throws -> MTLTexture {
                let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: f, width: width, height: height, mipmapped: false)
                d.usage = usage
                if samples > 1 { d.textureType = .type2DMultisample; d.sampleCount = samples }
                #if os(iOS)
                d.storageMode = memoryless ? .memoryless : .private
                #else
                d.storageMode = .private
                #endif
                guard let t = device.makeTexture(descriptor: d) else { throw RenderError.textureAllocation }
                return t
            }
            msaa = try make(OverlayRenderer.format, OverlayRenderer.sampleCount, .renderTarget, memoryless: true)
            stencil = try make(.stencil8, OverlayRenderer.sampleCount, .renderTarget, memoryless: true)
            output = try make(OverlayRenderer.format, 1, [.renderTarget, .shaderRead], memoryless: false)
        }
    }

    private func state(_ key: String, _ make: (MTLStencilDescriptor) -> Void) -> MTLDepthStencilState {
        if let s = ds[key] { return s }
        let d = MTLDepthStencilDescriptor()
        let st = MTLStencilDescriptor(); make(st)
        d.frontFaceStencil = st
        let back = MTLStencilDescriptor(); make(back)
        if key == "fill" { back.depthStencilPassOperation = .decrementWrap }
        d.backFaceStencil = back
        let s = device.makeDepthStencilState(descriptor: d)!
        ds[key] = s; return s
    }

    private func syncAtlas(_ atlas: OverlayAtlas) {
        if uploadedAtlas !== atlas { uploadedAtlas = atlas; uploadedVersion = -1 }
        guard atlas.version != uploadedVersion else { return }
        let full = uploadedVersion < 0
        atlas.withPixels { px, dirty in
            let rows: Range<Int> = full ? 0..<OverlayAtlas.size : (dirty ?? 0..<0)
            guard !rows.isEmpty else { return }
            px.withUnsafeBytes { raw in
                let bpr = OverlayAtlas.size * 4
                atlasTex.replace(region: MTLRegionMake2D(0, rows.lowerBound, OverlayAtlas.size, rows.count), mipmapLevel: 0,
                                 withBytes: raw.baseAddress!.advanced(by: rows.lowerBound * bpr), bytesPerRow: bpr)
            }
        }
        atlas.clearDirty()
        uploadedVersion = atlas.version
    }

    /// 목록을 UI 해상도 대상에 그린다(투명으로 지우고 시작)
    public func encode(_ list: OverlayList, atlas: OverlayAtlas, target t: Target, into cb: MTLCommandBuffer) throws {
        syncAtlas(atlas)
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = t.msaa; rp.colorAttachments[0].resolveTexture = t.output
        rp.colorAttachments[0].loadAction = .clear; rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rp.colorAttachments[0].storeAction = .multisampleResolve
        rp.stencilAttachment.texture = t.stencil; rp.stencilAttachment.loadAction = .clear; rp.stencilAttachment.clearStencil = 0; rp.stencilAttachment.storeAction = .dontCare
        guard let e = cb.makeRenderCommandEncoder(descriptor: rp) else { throw RenderError.encoder }
        e.label = "오버레이(HUD)"
        defer { e.endEncoding() }
        guard !list.batches.isEmpty, !list.vertices.isEmpty else { return }
        guard let vb = buffers.buffer(list.vertices, for: cb) else { throw RenderError.encoder }
        // 목록은 그 프레임의 UI 크기로 만든다(대상과 다르면 늘려 맞춤)
        let u: [Float] = [Float(list.width), Float(list.height), Float(OverlayAtlas.size), Float(OverlayAtlas.size)]
        e.setVertexBuffer(vb, offset: 0, index: 0); e.setVertexBytes(u, length: 16, index: 1)
        e.setFragmentTexture(atlasTex, index: 0)
        let direct = state("direct") { _ in }
        let directClip = state("directClip") { s in s.stencilCompareFunction = .equal; s.readMask = 0x80; s.writeMask = 0 }
        let fill = state("fill") { s in s.stencilCompareFunction = .always; s.depthStencilPassOperation = .incrementWrap; s.writeMask = 0x7F; s.readMask = 0xFF }
        let stroke = state("stroke") { s in s.stencilCompareFunction = .always; s.depthStencilPassOperation = .replace; s.writeMask = 0x7F }
        let cover = state("cover") { s in s.stencilCompareFunction = .notEqual; s.readMask = 0x7F; s.depthStencilPassOperation = .zero; s.stencilFailureOperation = .zero; s.writeMask = 0x7F }
        let coverClip = state("coverClip") { s in s.stencilCompareFunction = .less; s.readMask = 0xFF; s.depthStencilPassOperation = .zero; s.stencilFailureOperation = .zero; s.writeMask = 0x7F }
        let clipSet = state("clipSet") { s in s.stencilCompareFunction = .always; s.depthStencilPassOperation = .replace; s.writeMask = 0x80 }
        let clipClear = state("clipClear") { s in s.stencilCompareFunction = .always; s.depthStencilPassOperation = .replace; s.writeMask = 0x80 }
        for b in list.batches {
            switch b.kind {
            case .direct:
                e.setRenderPipelineState(colorPSO)
                if b.clipped { e.setDepthStencilState(directClip); e.setStencilReferenceValue(0x80) } else { e.setDepthStencilState(direct) }
            case .stencilFill: e.setRenderPipelineState(stencilPSO); e.setDepthStencilState(fill)
            case .stencilStroke: e.setRenderPipelineState(stencilPSO); e.setDepthStencilState(stroke); e.setStencilReferenceValue(1)
            case .cover:
                e.setRenderPipelineState(colorPSO)
                if b.clipped { e.setDepthStencilState(coverClip); e.setStencilReferenceValue(0x80) } else { e.setDepthStencilState(cover); e.setStencilReferenceValue(0) }
            case .clipSet: e.setRenderPipelineState(stencilPSO); e.setDepthStencilState(clipSet); e.setStencilReferenceValue(0x80)
            case .clipClear: e.setRenderPipelineState(stencilPSO); e.setDepthStencilState(clipClear); e.setStencilReferenceValue(0)
            }
            e.drawPrimitives(type: .triangle, vertexStart: b.first, vertexCount: b.count)
        }
    }

    /// 오버레이 결과를 화면(드로어블) 위에 얹는다 — 패스는 호출자가 준비(loadAction = .load)
    public func encodeComposite(_ overlay: MTLTexture, pass: MTLRenderPassDescriptor, format: MTLPixelFormat, into cb: MTLCommandBuffer) throws {
        let pso = try compositePSO(format)
        guard let e = cb.makeRenderCommandEncoder(descriptor: pass) else { throw RenderError.encoder }
        e.label = "오버레이 얹기"
        e.setRenderPipelineState(pso); e.setFragmentTexture(overlay, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    /// 화면 밖에서 그려 곧은 RGBA(위→아래 행)로 읽는다 — 테스트 · 디버그
    public func render(_ list: OverlayList, atlas: OverlayAtlas, queue: MTLCommandQueue) throws -> [UInt8] {
        let t = try Target(device: device, width: list.width, height: list.height)
        guard let cb = queue.makeCommandBuffer() else { throw RenderError.encoder }
        try encode(list, atlas: atlas, target: t, into: cb)
        let bpr = list.width * 4, len = bpr * list.height
        guard let buf = device.makeBuffer(length: len, options: .storageModeShared), let b = cb.makeBlitCommandEncoder() else { throw RenderError.encoder }
        b.copy(from: t.output, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: list.width, height: list.height, depth: 1),
               to: buf, destinationOffset: 0, destinationBytesPerRow: bpr, destinationBytesPerImage: len)
        b.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        if let err = cb.error { throw err }
        var px = [UInt8](UnsafeRawBufferPointer(start: buf.contents(), count: len))
        Self.unpremultiply(&px)
        return px
    }

    /// 미리 곱한 → 곧은(캔버스 getImageData 와 같은 표현)
    public static func unpremultiply(_ px: inout [UInt8]) {
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Int(px[i + 3]); if a == 0 { px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; continue }
            if a == 255 { continue }
            for c in 0..<3 { px[i + c] = UInt8(min(255, (Int(px[i + c]) * 255 + a / 2) / a)) }
        }
    }

    static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct OV { float4 pos [[position]]; float2 uv; float4 col; float lin; };
    struct OU { float2 size; float2 atlas; };
    vertex OV overlayVS(uint vid [[vertex_id]], const device float* v [[buffer(0)]], constant OU& U [[buffer(1)]]) {
        const device float* p = v + vid * 9;
        OV o;
        o.pos = float4(p[0] / U.size.x * 2.0 - 1.0, 1.0 - p[1] / U.size.y * 2.0, 0.0, 1.0);
        o.uv = float2(p[2], p[3]) / U.atlas;
        o.col = float4(p[4], p[5], p[6], p[7]);
        o.lin = p[8];
        return o;
    }
    fragment float4 overlayFS(OV in [[stage_in]], texture2d<float> atlas [[texture(0)]]) {
        constexpr sampler sn(filter::nearest, address::clamp_to_edge);
        constexpr sampler sl(filter::linear, address::clamp_to_edge);
        float4 t = in.lin > 0.5 ? atlas.sample(sl, in.uv) : atlas.sample(sn, in.uv);
        float4 c = t * in.col;
        return float4(c.rgb * c.a, c.a);
    }
    struct FV { float4 pos [[position]]; float2 uv; };
    vertex FV overlayFullVS(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        FV o; o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0); o.uv = float2(p.x, 1.0 - p.y); return o;
    }
    fragment float4 overlayCompositeFS(FV in [[stage_in]], texture2d<float> t [[texture(0)]]) {
        constexpr sampler sn(filter::nearest, address::clamp_to_edge);
        return t.sample(sn, in.uv);
    }
    """
}
