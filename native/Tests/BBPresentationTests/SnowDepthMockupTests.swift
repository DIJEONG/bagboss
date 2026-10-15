import Testing
import Foundation
import Metal
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 눈 무도장 깊이 · 원근 · 조명 강화 목업(감독 판단용 — BB_DUMP=1 일 때만) → tools/js/out/stage/snow_depth_*.png
///   게임 로직 · 렌더러 출력은 건드리지 않는다(이 파일 밖은 그대로). 같은 게임 프레임 하나를
///   (가) [렌더러] 실제 셰이더에 값만 바꿔 다시 그리고(광원 세기 · 웅덩이 · 블룸 · 림 광원 · 젖은 바닥 반사 재질)
///   (나) [후처리] 시험 장치에서 RGBA 로 덧칠(원경 흐림 · 안개 · 전경 층 · 바닥 원근 선 · 반사 줄기 · 림 가장자리) — 실제로는 셰이더 패스로 옮길 몫
///   해서 칸마다 합성한다. 픽셀 DOF = 장면 해상도에서 흐린 뒤 게임 후처리와 같은 24단 베이어 디더로 다시 자른다.
@Suite(.serialized) struct SnowDepthMockupTests {
    typealias Strip = NativeMoveStripTests
    static let out = Strip.root.appending(path: "tools/js/out/stage")
    static let W = 480, H = 270, vw = 198

    // MARK: 장면 준비(무도장 · 눈 승강장 배경 · 콤보 시연 — 둘이 맞붙은 프레임)

    final class Run {
        let R: Strip.Rig, sim: Sim
        var k = 0
        init() throws {
            R = try Strip.Rig(native: true); R.d.camera.visibleWidth = Double(SnowDepthMockupTests.vw)
            R.d.dojoDepth = 0   // 목업은 '지금' 렌더러 위에 덧칠한다(실제 구현 dojoDepth 는 끈다)
            var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1
            sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 7, config: c)
            for _ in 0..<30 { tick() }
            sim.apply(.dojo(.background("snow")))
            for _ in 0..<60 { tick() }
        }
        @discardableResult func tick() -> (SimSnapshot, StageFrame) {
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60); k += 1
            return (s, f)
        }
    }

    // MARK: 실수 영상

    struct Img {
        var w: Int, h: Int, c: [SIMD4<Float>]
        init(w: Int, h: Int, _ v: SIMD4<Float> = .zero) { self.w = w; self.h = h; c = Array(repeating: v, count: w * h) }
        subscript(x: Int, y: Int) -> SIMD4<Float> {
            get { c[max(0, min(h - 1, y)) * w + max(0, min(w - 1, x))] }
            set { c[y * w + x] = newValue }
        }
        /// 분리 가우스(가장자리 고정) — 알파 채널도 같이(미리 곱한 색이면 정규화 합성)
        func blur(_ s: Float) -> Img {
            guard s > 0.05 else { return self }
            let r = Int((s * 3).rounded(.up)); var k = (-r...r).map { exp(-Float($0 * $0) / (2 * s * s)) }
            let sum = k.reduce(0, +); k = k.map { $0 / sum }
            var a = Img(w: w, h: h), b = Img(w: w, h: h)
            for y in 0..<h { for x in 0..<w { var acc = SIMD4<Float>.zero; for i in -r...r { acc += self[x + i, y] * k[i + r] }; a.c[y * w + x] = acc } }
            for y in 0..<h { for x in 0..<w { var acc = SIMD4<Float>.zero; for i in -r...r { acc += a[x, y + i] * k[i + r] }; b.c[y * w + x] = acc } }
            return b
        }
        /// 반 해상도 상자 평균
        func half() -> Img {
            var o = Img(w: (w + 1) / 2, h: (h + 1) / 2)
            for y in 0..<o.h { for x in 0..<o.w { o.c[y * o.w + x] = (self[2 * x, 2 * y] + self[2 * x + 1, 2 * y] + self[2 * x, 2 * y + 1] + self[2 * x + 1, 2 * y + 1]) / 4 } }
            return o
        }
        /// 최근접으로 n 배
        func up(_ n: Int, w W: Int, h H: Int) -> Img {
            var o = Img(w: W, h: H); for y in 0..<H { for x in 0..<W { o.c[y * W + x] = self[x / n, y / n] } }; return o
        }
        /// 쌍선형으로 n 배(소프트 블러 칸 — 화면 해상도에서 매끈하게)
        func bilinear(_ n: Int) -> Img {
            var o = Img(w: w * n, h: h * n)
            for y in 0..<o.h { for x in 0..<o.w {
                let fx = (Float(x) + 0.5) / Float(n) - 0.5, fy = (Float(y) + 0.5) / Float(n) - 0.5
                let x0 = Int(floor(fx)), y0 = Int(floor(fy)), tx = fx - Float(x0), ty = fy - Float(y0)
                let a = self[x0, y0] * (1 - tx) + self[x0 + 1, y0] * tx, b = self[x0, y0 + 1] * (1 - tx) + self[x0 + 1, y0 + 1] * tx
                o.c[y * o.w + x] = a * (1 - ty) + b * ty
            } }
            return o
        }
        static func from(_ px: [UInt8], w: Int, h: Int) -> Img {
            var o = Img(w: w, h: h)
            for i in 0..<(w * h) { o.c[i] = SIMD4(Float(px[i * 4]), Float(px[i * 4 + 1]), Float(px[i * 4 + 2]), 255) / 255 }
            return o
        }
        /// 게임 후처리 끝과 같은 24단 · 베이어 4×4 양자화(postFS 마지막 줄)
        func quant24() -> Img {
            let B: [Float] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
            var o = self
            for y in 0..<h { for x in 0..<w {
                let t = B[(y & 3) * 4 + (x & 3)] / 16; var v = c[y * w + x]
                for j in 0..<3 { v[j] = floor(max(0, min(1, v[j])) * 24 + t) / 24 }
                v[3] = 1; o.c[y * w + x] = v
            } }
            return o
        }
        var bytes: [UInt8] {
            var o = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<(w * h) { for j in 0..<3 { o[i * 4 + j] = UInt8(max(0, min(255, (c[i][j] * 255).rounded()))) } }
            return o
        }
    }

    // MARK: 층 지도(배경 정점 → 화면 픽셀마다 어느 층인가)

    /// 0 하늘 · 1 맨해튼 · 2 퀸즈 · 3 길 건너 아파트 · 4 나무 · 5 승강장(난간 · 가로등 · 가판대 · 눈 바닥) · 6 앞 가지(시차 1.25)
    static func layerMap(_ mesh: [Float], camX: Int) -> [UInt8] {
        let zs: [Float] = [0.996, 0.995, 0.994, 0.993, 0.992, 0.9855, 0.9845]
        var L = [UInt8](repeating: 0, count: vw * H), Z = [Float](repeating: 9, count: vw * H)
        var i = 0
        while i + 60 <= mesh.count {
            var x0 = Float.infinity, x1 = -Float.infinity, y0 = Float.infinity, y1 = -Float.infinity
            for v in 0..<6 { let b = i + v * 10; x0 = min(x0, mesh[b]); x1 = max(x1, mesh[b]); y0 = min(y0, mesh[b + 1]); y1 = max(y1, mesh[b + 1]) }
            let z = mesh[i + 2]
            let li = zs.enumerated().min { abs($0.element - z) < abs($1.element - z) }!.offset
            let lay = abs(zs[li] - z) < 0.0003 ? UInt8(li) : 5   // 자국 · 충격 무늬 → 승강장
            let ya = max(0, Int(y0)), yb = min(H, Int(y1)), xa = max(0, Int(x0) - camX), xb = min(vw, Int(x1) - camX)
            guard ya < yb, xa < xb else { i += 60; continue }
            for y in ya..<yb { for x in xa..<xb {
                let k = y * vw + x; if z < Z[k] { Z[k] = z; L[k] = lay }
            } }
            i += 60
        }
        return L
    }

    // MARK: 칸 설정

    struct Look {
        var name: String, note: String
        var far: Float = 0        // 원경 흐림 + 안개 · 명도(0 끔 · 1 적정 · 1.6 강하게)
        var fg: Float = 0         // 전경 흐린 층
        var lights: Float = 0     // 광원 강화(렌더러)
        var rim: Float = 0        // 인물 림(렌더러 림 광원 + 1px 가장자리)
        var floor: Float = 0      // 바닥 원근 + 반사
        var dof: DOF = .pixel
    }
    enum DOF { case pixel, block, soft }

    /// 렌더러 값 바꾸기(장면 광원 · 후처리) — 실제 셰이더 결과
    static func editScene(_ f: inout StageFrame, _ L: Look, chars: [SimSnapshot.ActorView]) {
        if L.lights > 0 {
            let k = Double(L.lights)
            var ls = f.scene.lighting.lights
            for j in ls.indices {
                if ls[j].dirl != nil { ls[j].c = [0.42, 0.58, 1]; ls[j].i *= 1 - 0.3 * k; continue }       // 하늘 채움광: 더 차갑고 약하게(따뜻한 빛과 대비)
                if ls[j].spot != nil { ls[j].i *= 1 + 0.2 * k; ls[j].r *= 1 + 0.1 * k; continue }        // 가로등 스폿
                if ls[j].z == 16 { ls[j].r *= 1 + 0.3 * k; ls[j].i *= 1 + 0.35 * k; ls[j].c = [1, 0.58, 0.26]; continue }   // 바닥 웅덩이
                if ls[j].z == 18 { ls[j].r *= 1 + 0.2 * k; ls[j].i *= 1 + 0.25 * k; continue }              // 가판대
            }
            f.scene.lighting.lights = ls
            f.scene.lighting.ambient *= 1 - 0.25 * k
            f.scene.post.bloom *= 1 + 0.7 * k
            f.scene.post.vols = f.scene.post.vols.map { v in var q = v; q.halo *= 1 + 1.2 * k; q.i *= 1 + 0.5 * k; return q }
        }
        if L.rim > 0, let H = chars.first(where: { $0.isHero }) {
            // 주인공 · 무리 보조광(마지막 둘)을 림 광원 둘로 바꾼다: 가까운 가로등 쪽 따뜻한 빛 · 반대쪽 차가운 빛(가판대 · 하늘)
            let k = Double(L.rim)
            let cx = chars.reduce(0) { $0 + $1.x } / Double(max(1, chars.count))
            let lamp = SnowGeo.lamps.min { abs($0 - cx) < abs($1 - cx) }! + 7
            let side: Double = lamp < cx ? -1 : 1
            var ls = Array(f.scene.lighting.lights.prefix(6))
            ls.append(SceneLight(x: cx + side * 34, y: H.y - 46, z: 5, r: 130, c: [1, 0.62, 0.3], i: 1.1 * k))
            ls.append(SceneLight(x: cx - side * 38, y: H.y - 40, z: 5, r: 110, c: [0.55, 0.72, 1], i: 0.75 * k))
            f.scene.lighting.lights = ls
        }
    }

    // MARK: 전경 층(장면 해상도 · 화면 좌표 — 시차 1.6 가정)

    static func foreground(strong: Bool, t: Double = 0) -> Img {
        let w = vw, h = H
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        let ink = CGColor(srgbRed: 0.025, green: 0.03, blue: 0.07, alpha: 1)
        let warm = CGColor(srgbRed: 0.55, green: 0.32, blue: 0.16, alpha: 1)
        let snow = CGColor(srgbRed: 0.62, green: 0.70, blue: 0.86, alpha: 1)
        // 1) 앞 난간(카메라 바로 앞 · 아래 띠): 눈 덮인 가로대 + 기둥
        ctx.setFillColor(ink)
        ctx.fill(CGRect(x: 0, y: 254, width: w, height: 5))
        for px in [14, 92, 170] { ctx.fill(CGRect(x: px, y: 254, width: 7, height: 16)) }
        ctx.setFillColor(snow); ctx.fill(CGRect(x: 0.0, y: 251.0, width: Double(w), height: 3.5))
        for px in [14.0, 92, 170] { ctx.fillEllipse(in: CGRect(x: px - 1.5, y: 249.5, width: 10, height: 4)) }
        // 2) 지나가는 사람 실루엣(오른쪽 우산 쓴 사람 · 왼쪽 코트 입은 사람) — 화면 가장자리에 걸치게
        func person(_ x: CGFloat, _ top: CGFloat, _ s: CGFloat, umbrella: Bool, rimLeft: Bool) {
            func body(_ col: CGColor, _ dx: CGFloat) {
                ctx.setFillColor(col)
                ctx.fillEllipse(in: CGRect(x: x - 7 * s + dx, y: top + 14 * s, width: 14 * s, height: 16 * s))             // 머리
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x - 9 * s + dx, y: top + 30 * s)); p.addLine(to: CGPoint(x: x + 9 * s + dx, y: top + 30 * s))
                p.addLine(to: CGPoint(x: x + 15 * s + dx, y: top + 100 * s)); p.addLine(to: CGPoint(x: x - 14 * s + dx, y: top + 100 * s)); p.closeSubpath()
                ctx.addPath(p); ctx.fillPath()                                                                               // 코트
                ctx.fill(CGRect(x: x - 9 * s + dx, y: top + 98 * s, width: 7 * s, height: 40 * s))
                ctx.fill(CGRect(x: x + 3 * s + dx, y: top + 98 * s, width: 7 * s, height: 40 * s))                       // 다리
                if umbrella {
                    let u = CGMutablePath()
                    u.addArc(center: CGPoint(x: x + 2 * s + dx, y: top + 12 * s), radius: 30 * s, startAngle: .pi, endAngle: 0, clockwise: false)
                    u.closeSubpath(); ctx.addPath(u); ctx.fillPath()
                    ctx.fill(CGRect(x: x + 1 * s + dx, y: top + 10 * s, width: 1.6 * s, height: 30 * s))
                }
            }
            body(warm, rimLeft ? -1.6 : 1.6)    // 가로등 쪽 가장자리만 따뜻하게(흐리면 번진 테두리 빛)
            body(ink, 0)
            if umbrella {   // 우산 위 눈
                ctx.setFillColor(snow)
                let u = CGMutablePath()
                u.addArc(center: CGPoint(x: x + 2 * s, y: top + 12 * s), radius: 30 * s, startAngle: .pi * 1.12, endAngle: .pi * 1.88, clockwise: false)
                u.addArc(center: CGPoint(x: x + 2 * s, y: top + 15 * s), radius: 28 * s, startAngle: .pi * 1.85, endAngle: .pi * 1.15, clockwise: true)
                u.closeSubpath(); ctx.addPath(u); ctx.fillPath()
            }
        }
        person((strong ? 184 : 192) - 26 * t, strong ? 92 : 112, strong ? 1.35 : 1.15, umbrella: true, rimLeft: true)
        person((strong ? 6 : -2) + 22 * t, strong ? 120 : 140, strong ? 1.2 : 1.0, umbrella: false, rimLeft: false)
        // 3) 카메라 앞 큰 눈송이(초점 밖 — 가로등 가까이는 따뜻하게)
        var g = SplitMix64(seed: 99)
        for _ in 0..<(strong ? 22 : 14) {
            let x = g.next() * Double(w) + 9 * t, y = (20 + g.next() * 220 + 70 * t).truncatingRemainder(dividingBy: 250), r = 1.6 + g.next() * (strong ? 3.6 : 2.6)
            let near = exp(-pow((x - 74) / 50, 2) - pow((y - 90) / 90, 2))
            ctx.setFillColor(CGColor(srgbRed: 0.7 + 0.3 * near, green: 0.75 + 0.05 * near, blue: 0.95 - 0.45 * near, alpha: 0.4 + 0.3 * g.next()))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        var o = Img(w: w, h: h)
        for i in 0..<(w * h) { o.c[i] = SIMD4(Float(buf[i * 4]), Float(buf[i * 4 + 1]), Float(buf[i * 4 + 2]), Float(buf[i * 4 + 3])) / 255 }   // 미리 곱한 색
        return o
    }

    // MARK: 한 칸 만들기

    struct Frame { let s: SimSnapshot; let f: StageFrame; let cx: Int }

    /// 렌더 한 쌍(전부 · 인물 뺀 배경) + gInfo
    static func renderPair(_ R: Strip.Rig, _ F: Frame, _ L: Look) throws -> (a: Img, b: Img, info: [UInt8]) {
        var f = F.f
        editScene(&f, L, chars: F.s.actors.filter { !$0.hidden && ($0.isHero || $0.isEnemy) })
        func go(_ f: StageFrame) throws -> ([UInt8], [UInt8]) {
            var rf = RenderFrame(stage: f, atlas: R.content.sprites)
            rf.applyHUD(R.d.hud.state, now: F.s.time)
            if L.floor > 0, rf.post != nil {
                // 젖은(다져진 얼음) 바닥 반사 — 기존 postFS 의 젖은 바닥 갈래를 눈 재질(SNOWF 64)에 0.16 으로(웅덩이 SNOWW 까지 넣으면 0.42 라 하얗게 뜬다)
                rf.post!.reflectY = Float(SnowGeo.groundTop) - 1; rf.post!.wetMaterials = [-1, Float(NativePalette.SNOWF), -1]
            }
            let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
            return (try R.fr.readBack(R.tg.output(for: rf), queue: R.q), try R.fr.readBack(R.tg.gInfo, queue: R.q))
        }
        let (pa, ia) = try go(f)
        var fb = f; fb.mesh = []; fb.shadows = []; fb.preMesh = []; fb.front = []
        let (pb, _) = try go(fb)
        func crop(_ p: [UInt8]) -> [UInt8] {   // 알파까지 그대로(gInfo.a = 인물 부위 표시)
            var o = [UInt8](repeating: 0, count: vw * H * 4)
            for y in 0..<H { for x in 0..<vw { let sx = max(0, min(W - 1, F.cx + x)), si = (y * W + sx) * 4, d = (y * vw + x) * 4; for j in 0..<4 { o[d + j] = p[si + j] } } }
            return o
        }
        return (Img.from(crop(pa), w: vw, h: H), Img.from(crop(pb), w: vw, h: H), crop(ia))
    }

    /// 칸 → 장면 해상도 결과(픽셀 DOF · 블록) 또는 화면 해상도(소프트 — 3배)
    static func panel(_ R: Strip.Rig, _ F: Frame, _ L: Look, scale: Int, fgT: Double = 0) throws -> Img {
        let (A, B, info) = try renderPair(R, F, L)
        let lay = layerMap(F.f.backMesh, camX: F.cx)
        let n = vw * H
        // 움직이는 것(인물 · 눈 입자 · 그림자 · 파편): 인물 G-버퍼 표시 또는 배경만 그림과 다른 곳
        var dyn = [Bool](repeating: false, count: n), chr = [Bool](repeating: false, count: n)
        for i in 0..<n {
            let a = info[i * 4 + 3]; chr[i] = a > 196 && a < 252
            let d = A.c[i] - B.c[i]; dyn[i] = chr[i] || Swift.abs(d.x) + Swift.abs(d.y) + Swift.abs(d.z) > 0.09
        }
        // 1) 원경: 층별 흐림 양 · 안개 · 명도(하늘 · 먼 층만 — 승강장 · 인물은 또렷)
        let blurAmt: [Float] = [1, 1, 0.85, 0.62, 0.42, 0, 0]
        let hazeAmt: [Float] = [0.35, 0.65, 0.55, 0.42, 0.28, 0, 0]
        var base = B
        if L.far > 0 {
            let sMax: Float = 1.5 * L.far.squareRoot()
            // 먼 층만 담은 정규화 블러(승강장 · 앞 가지가 번져 들지 않게)
            var src = Img(w: vw, h: H)
            for i in 0..<n where lay[i] <= 4 { src.c[i] = SIMD4(B.c[i].x, B.c[i].y, B.c[i].z, 1) }
            let lv: [Img] = [src, src.blur(sMax / 3), src.blur(sMax * 2 / 3), src.blur(sMax)]
            let fogC = SIMD3<Float>(0.09, 0.12, 0.24)
            for i in 0..<n where lay[i] <= 4 {
                let t = blurAmt[Int(lay[i])] * 3, j = min(2, Int(t)), u = t - Float(j)
                var v = lv[j].c[i] * (1 - u) + lv[j + 1].c[i] * u
                v /= max(v.w, 1e-4)
                var c = SIMD3(v.x, v.y, v.z)
                let lum = (c * SIMD3(0.299, 0.587, 0.114)).sum(), keep = 1 - 0.55 * max(0, min(1, (lum - 0.45) / 0.35))   // 불 켜진 창 · 간판은 덜 덮는다
                let hz = min(0.6, hazeAmt[Int(lay[i])] * L.far) * keep
                c = c + (fogC - c) * hz                                      // 대기 안개
                c *= 1 - 0.18 * min(1, L.far) * hazeAmt[Int(lay[i])]          // 명도 한 단 낮춤
                let g = (c * SIMD3(0.299, 0.587, 0.114)).sum(); c = SIMD3(repeating: g) + (c - SIMD3(repeating: g)) * (1 - 0.35 * hz)   // 채도 낮춤
                base.c[i] = SIMD4(c.x, c.y, c.z, 1)
            }
        }
        // 2) 승강장(바닥 · 난간) + 움직이는 것
        var img = base
        for i in 0..<n where dyn[i] { img.c[i] = A.c[i] }
        // 3) 바닥 원근 · 반사 줄기(후처리 — 인물 · 입자 밑 바닥에만)
        if L.floor > 0 {
            let k = L.floor, vpX = Float(vw) / 2, vpY: Float = 132, lip = Float(SnowGeo.lip)
            let edge = SnowFloor.table.edge
            for y in 0..<H { for x in 0..<vw {
                let i = y * vw + x, sx = F.cx + x
                guard !dyn[i], lay[i] == 5, sx >= 0, sx < SnowGeo.W, y > edge[sx] + 1, y < SnowGeo.lip else { continue }
                let Y = Float(y), X = Float(x)
                var c = SIMD3(img.c[i].x, img.c[i].y, img.c[i].z)
                // (가) 다져진 길(214~232) 속 보도 블록 이음매 — 소실점으로 모이는 세로 줄 + 앞으로 갈수록 벌어지는 가로 줄
                let depth = (Y - vpY) / (lip - vpY)                 // 0 먼 쪽 → 1 앞
                let path = Y >= 214 && Y <= 233
                let u = (X - vpX) / depth                            // 바닥 평면 가로 좌표(앞 모서리 기준 픽셀)
                let seamX = abs(u.truncatingRemainder(dividingBy: 26)) < 1.2 / depth * 0.9
                let rowsY: [Float] = [205, 210, 216, 223, 231, 241]   // 원근으로 벌어지는 가로 줄
                let seamY = rowsY.contains { abs($0 - Y) < 0.5 }
                if path && (seamX || seamY) && SnowPaint.n2(Double(X) / 11, Double(Y) / 3, 91) > 0.42 { c *= 1 - 0.14 * k }   // 눈이 쓸린 곳만 듬성듬성
                // (나) 승강장 앞 모서리 노란 점자 블록(눈이 쓸린 곳만 드러난다)
                if Y >= lip - 6 && Y < lip - 4 && SnowPaint.n1(Double(sx) / 7, 77) > 0.6 { c = c * (1 - 0.3 * k) + SIMD3(0.62, 0.5, 0.16) * 0.3 * k }
                // (다) 발자국 줄(두 줄 · 원근으로 좁아진다)
                for (fx, ph) in [(Float(-34), Float(0)), (Float(48), Float(5))] {
                    let lx = vpX + fx * depth, step = 7 * depth
                    let q = (Y + ph).truncatingRemainder(dividingBy: max(3, step * 2))
                    if abs(X - lx - (q < step ? -1.5 : 1.5) * depth) < 1.1 * depth && q.truncatingRemainder(dividingBy: step) < 1.6 * depth && !path { c *= 1 - 0.18 * k }
                }
                // (라) 얼음 광택 · 광원 반사 줄기(가로등 머리 · 가판대 창 — 세로로 번진 따뜻한 띠)
                let srcs: [(Float, Float, SIMD3<Float>)] = SnowGeo.lamps.map { (Float($0 + 7) - Float(F.cx), 0.5, SIMD3(1, 0.62, 0.3)) } + [(Float(SnowGeo.kioskX + 23) - Float(F.cx), 0.7, SIMD3(1, 0.8, 0.45))]
                for (sx0, a, col) in srcs {
                    let dx = (X - sx0) / (3 + 2.5 * depth), dy = (Y - 202) / 46
                    let s = exp(-dx * dx) * exp(-dy * dy) * (0.75 + 0.25 * sin(Y * 1.7))
                    c += col * s * a * 0.32 * k
                }
                img.c[i] = SIMD4(c.x, c.y, c.z, 1)
            } }
        }
        // 4) 인물 림 가장자리(1px — 광원 쪽 바깥 테두리가 비어 있으면 따뜻하게, 반대쪽은 차갑게)
        if L.rim > 0 {
            let chars = F.s.actors.filter { !$0.hidden && ($0.isHero || $0.isEnemy) }
            let cx = chars.reduce(0) { $0 + $1.x } / Double(max(1, chars.count))
            let lamp = SnowGeo.lamps.min { abs($0 - cx) < abs($1 - cx) }! + 7
            let side = lamp < cx ? -1 : 1
            let k = L.rim
            var o = img
            for y in 1..<(H - 1) { for x in 1..<(vw - 1) {
                let i = y * vw + x; guard chr[i] else { continue }
                var c = SIMD3(img.c[i].x, img.c[i].y, img.c[i].z)
                if !chr[i + side] { c = c * (1 - 0.38 * k) + SIMD3(1, 0.66, 0.34) * 0.38 * k }
                else if !chr[i - side] { c = c * (1 - 0.2 * k) + SIMD3(0.5, 0.66, 1) * 0.2 * k }
                else if !chr[i - vw] { c = c * (1 - 0.22 * k) + SIMD3(0.75, 0.75, 0.9) * 0.22 * k }   // 머리 · 어깨 위 하늘빛
                o.c[i] = SIMD4(c.x, c.y, c.z, 1)
            } }
            img = o
        }
        // 5) 전경: 앞 가지(시차 1.25 층)도 초점 밖 → 전경 흐림에 넣는다
        var fgLayer = Img(w: vw, h: H)
        if L.fg > 0 {
            for i in 0..<n where lay[i] == 6 && !dyn[i] { fgLayer.c[i] = SIMD4(B.c[i].x, B.c[i].y, B.c[i].z, 1) * 0.85 }
            let fgd = foreground(strong: L.fg > 1.2, t: fgT)
            for i in 0..<n { let s = fgd.c[i]; fgLayer.c[i] = s + fgLayer.c[i] * (1 - s.w) }
            // 가지 뒤 가려진 원경은 1)의 흐린 원경으로 메운다(정규화 블러 결과 사용)
            if L.far == 0 {   // 원경 흐림 없을 때도 가지 자리는 비워야 하므로 이웃 원경으로 메운다
                var src = Img(w: vw, h: H); for i in 0..<n where lay[i] <= 4 { src.c[i] = SIMD4(B.c[i].x, B.c[i].y, B.c[i].z, 1) }
                let bl = src.blur(2.5)
                for i in 0..<n where lay[i] == 6 && !dyn[i] { let v = bl.c[i]; if v.w > 0.01 { img.c[i] = v / v.w } }
            }
        }
        let fgS: Float = 2.2 * max(1, L.fg)   // 전경 흐림 반경(장면 px)
        func over(_ bg: Img, _ fg: Img) -> Img { var o = bg; for i in 0..<o.c.count { let s = fg.c[i]; o.c[i] = SIMD4(s.x, s.y, s.z, 0) + bg.c[i] * (1 - s.w); o.c[i].w = 1 }; return o }
        switch L.dof {
        case .pixel:
            var r = img
            if L.fg > 0 { r = over(r, fgLayer.blur(fgS)) }
            return r.quant24().up(scale, w: vw * scale, h: H * scale)
        case .block:
            // 흐릴 층을 반 해상도에서 흐린 뒤 최근접으로 키움 → 2px 덩어리(픽셀 격자 유지) → 24단 디더
            var r = img
            if L.far > 0 {
                var src = Img(w: vw, h: H); for i in 0..<n where lay[i] <= 4 { src.c[i] = SIMD4(img.c[i].x, img.c[i].y, img.c[i].z, 1) }
                let hb = src.half().blur(0.5 * L.far).up(2, w: vw, h: H)
                for i in 0..<n where lay[i] <= 4 && !dyn[i] { let v = hb.c[i]; if v.w > 0.01 { r.c[i] = v / v.w } }
            }
            if L.fg > 0 { r = over(r, fgLayer.half().blur(fgS / 2).up(2, w: vw, h: H)) }
            return r.quant24().up(scale, w: vw * scale, h: H * scale)
        case .soft:
            // 화면 해상도 부드러운 블러: 흐린 층은 쌍선형 확대(양자화 없음) · 또렷한 층은 최근접
            let crisp = img.up(scale, w: vw * scale, h: H * scale), smooth = img.bilinear(scale)
            var r = crisp
            for y in 0..<(H * scale) { for x in 0..<(vw * scale) {
                let i = (y / scale) * vw + x / scale
                if lay[i] <= 4 && !dyn[i] && L.far > 0 { r.c[y * r.w + x] = smooth.c[y * r.w + x] }
            } }
            if L.fg > 0 { r = over(r, fgLayer.bilinear(scale).blur(fgS * Float(scale))) }
            return r
        }
    }

    // MARK: 시트 출력(칸 위 이름 · 아래 기법 메모)

    static func savePNG(_ img: Img, _ name: String) throws {
        var b = img.bytes
        let ctx = CGContext(data: &b, width: img.w, height: img.h, bitsPerComponent: 8, bytesPerRow: img.w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        try write(ctx.makeImage()!, name)
    }
    static func write(_ cg: CGImage, _ name: String) throws {
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let url = out.appending(path: name + ".png")
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, cg, nil); CGImageDestinationFinalize(dst)
        print("[snow depth] → \(url.path)")
    }
    static func sheet(_ panels: [(Img, String, String)], cols: Int, name: String, title: String) throws {
        let pw = panels[0].0.w, ph = panels[0].0.h, gap = 18, top = 64, lab = 46, note = 58
        let rows = (panels.count + cols - 1) / cols
        let Wd = cols * (pw + gap) + gap, Hd = top + rows * (lab + ph + note + gap) + gap
        let ctx = CGContext(data: nil, width: Wd, height: Hd, bitsPerComponent: 8, bytesPerRow: Wd * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.07, blue: 0.1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: Wd, height: Hd))
        func text(_ s: String, _ x: Int, _ yTop: Int, size: CGFloat, bold: Bool, col: CGColor, maxW: Int) {
            let font = CTFontCreateWithName((bold ? "AppleSDGothicNeo-Bold" : "AppleSDGothicNeo-Regular") as CFString, size, nil)
            let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): col])
            let fs = CTFramesetterCreateWithAttributedString(attr)
            let path = CGPath(rect: CGRect(x: x, y: Hd - yTop - 200, width: maxW, height: 200), transform: nil)
            CTFrameDraw(CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), path, nil), ctx)
        }
        text(title, gap, 14, size: 30, bold: true, col: CGColor(srgbRed: 1, green: 0.84, blue: 0.4, alpha: 1), maxW: Wd - 2 * gap)
        for (k, (img, label, memo)) in panels.enumerated() {
            let ox = gap + (k % cols) * (pw + gap), oy = top + (k / cols) * (lab + ph + note + gap)
            text(label, ox, oy + 6, size: 27, bold: true, col: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), maxW: pw)
            var b = img.bytes
            let ic = CGContext(data: &b, width: img.w, height: img.h, bitsPerComponent: 8, bytesPerRow: img.w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.interpolationQuality = .none
            ctx.draw(ic.makeImage()!, in: CGRect(x: ox, y: Hd - (oy + lab) - ph, width: pw, height: ph))
            text(memo, ox, oy + lab + ph + 6, size: 19, bold: false, col: CGColor(srgbRed: 0.72, green: 0.76, blue: 0.86, alpha: 1), maxW: pw)
        }
        try write(ctx.makeImage()!, name)
    }

    // MARK: 칸 정의

    static let looks: [Look] = [
        Look(name: "0. 현재", note: "지금 렌더러 그대로"),
        Look(name: "1. 원경 흐림 + 안개 · 명도", note: "[후처리] 층별 흐림 + 안개 섞기 · 한 단 어둡게 · 채도↓ → 24단 디더", far: 1),
        Look(name: "2. 전경 흐린 층", note: "[후처리] 앞 난간 · 행인 · 큰 눈송이 · 앞 가지(1.25층) 흐림 → 24단 디더", fg: 1),
        Look(name: "3. 광원 강화", note: "[렌더러] 등 · 웅덩이 · 가판대 세기/반경↑ · 블룸↑ · 하늘 채움↓(따뜻/차가운 대비)", lights: 1),
        Look(name: "4. 인물 림라이트", note: "[렌더러] 보조광 → 좌우 림 광원 둘 + [후처리] 1px 가장자리", rim: 1),
        Look(name: "5. 바닥 원근 + 반사", note: "[렌더러] 젖은 바닥 반사를 눈 재질에 + [후처리] 이음매 · 발자국 · 점자블록 · 반사 줄기", floor: 1),
        Look(name: "6. 전부 합침 (적정)", note: "1~5 적정 세기 · 픽셀 DOF(블러 → 24단 베이어)", far: 1, fg: 1, lights: 1, rim: 1, floor: 1),
        Look(name: "7. 전부 합침 (강하게)", note: "1~5 강하게 · 픽셀 DOF(블러 → 24단 베이어)", far: 1.7, fg: 1.6, lights: 1.6, rim: 1.4, floor: 1.5),
    ]

    static func pickFrame(_ r: Run) -> Frame {
        r.sim.apply(.dojo(.combo(0)))
        var last: (SimSnapshot, StageFrame)!
        for _ in 0...18 { last = r.tick() }
        return Frame(s: last.0, f: last.1, cx: Int(last.1.view.cameraX.rounded()))
    }

    @Test(.enabled(if: Strip.dump)) func mockup() throws {
        let r = try Run()
        let F = Self.pickFrame(r)
        print("[snow depth] " + F.s.actors.filter { !$0.hidden }.map { "\($0.def) \($0.pose.anim) x\(Int($0.x))" }.joined(separator: " · ") + " cam \(F.cx)")
        var panels: [(Img, String, String)] = []
        for L in Self.looks { panels.append((try Self.panel(r.R, F, L, scale: 3), L.name, L.note)) }
        try Self.sheet(panels, cols: 4, name: "snow_depth_mockup", title: "눈 무도장 · 깊이 / 원근 / 조명 목업 — 같은 게임 프레임 · 화면 틀(보이는 폭 198px) 3배")
        for k in [0, 6, 7] { try Self.savePNG(try Self.panel(r.R, F, Self.looks[k], scale: 5), "snow_depth_\(k)") }
        // DOF 방식 비교(7 강하게 기준): 소프트 블러 · 픽셀 DOF(블러→디더) · 픽셀 DOF(반해상도 블록)
        var cmp: [(Img, String, String)] = [(panels[0].0, "현재", "지금 렌더러")]
        for (d, nm, memo) in [(DOF.soft, "소프트 블러", "화면 해상도 가우스(양자화 없음) — 영상에 가장 가깝지만 픽셀 격자가 사라진다"),
                              (DOF.pixel, "픽셀 DOF · 디더", "장면 해상도 블러 → 게임과 같은 24단 베이어로 다시 자름"),
                              (DOF.block, "픽셀 DOF · 블록", "반 해상도에서 흐림 → 2px 덩어리 → 24단 디더")] {
            var L = Self.looks[7]; L.dof = d
            cmp.append((try Self.panel(r.R, F, L, scale: 3), nm, memo))
        }
        try Self.sheet(cmp, cols: 4, name: "snow_depth_dof_compare", title: "흐림 방식 비교 — 7(강하게) 설정 · 소프트 vs 픽셀 친화")
        // 확대(6배) 부분: 건물 창 · 전경 행인 가장자리
        var zoom: [(Img, String, String)] = []
        for (img, nm, _) in cmp {
            var z = Img(w: 66 * 6, h: 90 * 6)
            let s = img.w / Self.vw   // 3
            for y in 0..<z.h { for x in 0..<z.w { z.c[y * z.w + x] = img[120 * s + x * s / 6, 110 * s + y * s / 6] } }
            zoom.append((z, nm, "x 120~186 · y 110~200 (6배)"))
        }
        try Self.sheet(zoom, cols: 4, name: "snow_depth_dof_zoom", title: "흐림 방식 확대 — 원경 창 · 전경 행인 가장자리")
    }

    /// 짧은 움직임(GIF · 2초 · 12fps): 왼쪽 현재 · 오른쪽 6(적정) — 같은 시뮬 틱을 둘 다 그린다(전경 행인 · 큰 눈송이가 지나간다)
    @Test(.enabled(if: Strip.dump)) func clip() throws {
        let r = try Run()
        _ = Self.pickFrame(r)
        let url = Self.out.appending(path: "snow_depth_clip.gif")
        let n = 24
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, n, nil)!
        CGImageDestinationSetProperties(dst, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        for k in 0..<n {
            var last: (SimSnapshot, StageFrame)!
            for _ in 0..<5 { last = r.tick() }
            let F = Frame(s: last.0, f: last.1, cx: Int(last.1.view.cameraX.rounded()))
            let a = try Self.panel(r.R, F, Self.looks[0], scale: 2), b = try Self.panel(r.R, F, Self.looks[6], scale: 2, fgT: Double(k) / Double(n))
            var both = Img(w: a.w * 2 + 8, h: a.h, SIMD4(0.07, 0.07, 0.1, 1))
            for y in 0..<a.h { for x in 0..<a.w { both.c[y * both.w + x] = a.c[y * a.w + x]; both.c[y * both.w + a.w + 8 + x] = b.c[y * a.w + x] } }
            var bytes = both.bytes
            let ctx = CGContext(data: &bytes, width: both.w, height: both.h, bitsPerComponent: 8, bytesPerRow: both.w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            CGImageDestinationAddImage(dst, ctx.makeImage()!, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 1.0 / 12]] as CFDictionary)
        }
        CGImageDestinationFinalize(dst)
        print("[snow depth] → \(url.path)")
    }
}
