import Testing
import Foundation
import Metal
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 무도장 깊이 · 조명(docs/10 §10)
///   · 깃발 · 세기 가르기(늘 돈다): 꺼짐(세기 0 · 웹 깃발 · 무도장 밖 눈 승강장)이면 StageFrame.depth 가 없고 렌더가 바이트까지 같다
///   · 전 · 후 비교(BB_DUMP=1): 무도장 배경 셋 × (끔 · 켬) 같은 프레임 → tools/js/out/stage/dojo_depth_before_after.png
///   · 성능(BB_BENCH=1 · -c release): 배경 셋 켬/끔 — 연출+조립+인코딩 CPU ms · GPU ms/프레임
@Suite(.serialized) struct DojoDepthTests {
    typealias Strip = NativeMoveStripTests
    typealias M = SnowDepthMockupTests

    /// 무도장 시뮬 + 연출기 둘(같은 이벤트를 받는다 — 하나는 끔 · 하나는 켬)
    final class Pair {
        let A: Strip.Rig, B: Strip.Rig, sim: Sim
        var k = 0
        init(bg: String, nativeCatalog: Bool = true) throws {
            A = try Strip.Rig(native: nativeCatalog); B = try Strip.Rig(native: nativeCatalog)
            for R in [A, B] { R.d.camera.visibleWidth = Double(M.vw) }
            A.d.dojoDepth = 0; B.d.dojoDepth = 1
            var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1
            sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 7, config: c)
            for _ in 0..<30 { _ = tick() }
            if bg != "dojo" { sim.apply(.dojo(.background(bg))) }
            for _ in 0..<60 { _ = tick() }
        }
        func tick() -> (SimSnapshot, StageFrame, StageFrame) {
            let ev = sim.step(), s = sim.snapshot, now = Double(k) / 60
            _ = A.d.apply(ev, snapshot: s, now: now); _ = B.d.apply(ev, snapshot: s, now: now)
            let fa = A.d.frame(s, dt: 1.0 / 60, now: now), fb = B.d.frame(s, dt: 1.0 / 60, now: now); k += 1
            return (s, fa, fb)
        }
    }
    static func render(_ R: Strip.Rig, _ s: SimSnapshot, _ f: StageFrame) throws -> [UInt8] {
        var rf = RenderFrame(stage: f, atlas: R.content.sprites)
        rf.applyHUD(R.d.hud.state, now: s.time)
        let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
        return try R.fr.readBack(R.tg.output(for: rf), queue: R.q)
    }

    // MARK: 깃발 · 세기

    @Test func gating() throws {
        // 웹 깃발(HUDCatalog.native 꺼짐): 세기 1 이어도 없음
        let W = try Pair(bg: "snow", nativeCatalog: false)
        for _ in 0..<5 { let (_, a, b) = W.tick(); #expect(a.depth == nil && b.depth == nil) }
        // 네이티브 · 무도장: 세기 0 = 없음, 1 = 있음 · 배경마다
        for bg in ["snow", "dojo", "cross"] {
            let P = try Pair(bg: bg)
            let (s, a, b) = P.tick()
            #expect(a.depth == nil)
            let D = try #require(b.depth)
            #expect(D.farMix > 0 && D.rimEdge > 0)
            #expect(D.wetSnow == (bg == "snow") && (D.floorStep > 0) == (bg == "snow"))
            #expect((D.farKey != nil) == (bg == "snow"))   // 원경 캐시는 정지 층(눈 승강장)만
            _ = s
        }
        // 무도장 밖 눈 승강장(달리기 판): 없음
        let R = try Strip.Rig(native: true)
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 11, config: SnowStripTests.config())
        for _ in 0..<30 { _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: 0); sim.step() }
        _ = sim.debugSnowJump()
        for k in 0..<20 { sim.step(); let f = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60); #expect(f.depth == nil) }
    }

    /// 세기 0 의 렌더는 깃발 꺼짐(웹 경로)과 바이트까지 같다 — 새 유니폼 · 패스 · 전경 텍스처 · 배경별 덧(EX · 림 2색)이 값 0 에서 아무것도 바꾸지 않는다(배경 셋)
    @Test func offIsIdentical() throws {
        for bg in ["snow", "cross", "dojo"] {
            let P = try Pair(bg: bg)
            P.sim.apply(.dojo(.combo(0)))
            var last: (SimSnapshot, StageFrame, StageFrame)!
            for _ in 0..<40 { last = P.tick() }
            #expect(last.1.depth == nil)
            var f0 = last.1; f0.depth = nil
            #expect(try Self.render(P.A, last.0, last.1) == Self.render(P.A, last.0, f0))
            var fz = last.1; fz.depth = DepthFX()   // 전부 0 인 값(끔 쪽 장면에)
            #expect(try Self.render(P.A, last.0, fz) == Self.render(P.A, last.0, f0), "\(bg)")
            var fb = last.2; fb.depth = DepthFX()   // 켬 쪽 장면(광원 손봄)에 깊이 값 0 = depth nil
            var fn = last.2; fn.depth = nil
            #expect(try Self.render(P.B, last.0, fb) == Self.render(P.B, last.0, fn), "\(bg)")
        }
    }

    // MARK: 전 · 후

    @Test(.enabled(if: Strip.dump)) func beforeAfter() throws {
        var panels: [(M.Img, String, String)] = []
        let names = ["snow": "눈 승강장", "dojo": "무도장", "cross": "건널목"]
        for bg in ["snow", "dojo", "cross"] {
            let P = try Pair(bg: bg)
            P.sim.apply(.dojo(.combo(0)))
            var last: (SimSnapshot, StageFrame, StageFrame)!
            for _ in 0...18 { last = P.tick() }
            let (s, fa, fb) = last!
            for (R, f, tag) in [(P.A, fa, "전"), (P.B, fb, "후")] {
                let px = try Self.render(R, s, f), cx = Int(f.view.cameraX.rounded())
                let img = M.Img.from(SnowStripTests.crop(px, x0: cx, y0: 0, w: M.vw, h: M.H).px, w: M.vw, h: M.H).up(3, w: M.vw * 3, h: M.H * 3)
                let memo = tag == "전" ? "dojoDepth 0 (= 지금 · 웹 경로)" : "dojoDepth 1 (적정) — 실제 렌더러"
                panels.append((img, "\(names[bg]!) · \(tag)", memo))
            }
        }
        try M.sheet(panels, cols: 2, name: "dojo_depth_before_after", title: "무도장 깊이 · 조명 — 배경 셋 · 같은 프레임 전/후(3배)")
    }

    // MARK: 성능

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_BENCH"] == "1")) func bench() throws {
        for bg in ["snow", "dojo", "cross"] {
            var cpu: [Bool: [Double]] = [true: [], false: []], gpu: [Bool: [Double]] = [true: [], false: []]
            for round in 0..<6 {
                let on = round % 2 == 0
                let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = Double(M.vw); R.d.dojoDepth = on ? 1 : 0
                var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1
                let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 7, config: c)
                for _ in 0..<30 { sim.step() }
                if bg != "dojo" { sim.apply(.dojo(.background(bg))) }
                for _ in 0..<60 { sim.step() }
                var acc = 0.0, gacc = 0.0
                let N = 600
                for k in 0..<N {
                    if k % 150 == 0 { sim.apply(.dojo(.combo((k / 150) % 3))) }
                    let ev = sim.step(), s = sim.snapshot
                    let t0 = DispatchTime.now().uptimeNanoseconds
                    _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
                    let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                    var rf = RenderFrame(stage: f, atlas: R.content.sprites)
                    rf.applyHUD(R.d.hud.state, now: s.time)
                    let cb = try #require(R.q.makeCommandBuffer())
                    try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit()
                    acc += PerfBenchTests.ms(t0)
                    cb.waitUntilCompleted(); gacc += (cb.gpuEndTime - cb.gpuStartTime) * 1000
                }
                cpu[on]!.append(acc / Double(N)); gpu[on]!.append(gacc / Double(N))
            }
            let a = cpu[true]!.sorted()[1], b = cpu[false]!.sorted()[1], ga = gpu[true]!.sorted()[1], gb = gpu[false]!.sorted()[1]
            print(String(format: "[bench depth] %@ · CPU 켬 %.3f · 끔 %.3f (%+.3f) ms · GPU 켬 %.3f · 끔 %.3f (%+.3f) ms/프레임", bg, a, b, a - b, ga, gb, ga - gb))
        }
    }

    // MARK: 행인 그림(미술 점검)

    static func kname(_ k: PasserKind) -> String { ["우산", "롱코트 · 목도리", "후드 파카", "둘이 함께"][k.rawValue] }

    /// 행인 그림 한 장 → Img(배경 위 합성)
    static func passerImg(_ k: PasserKind, phase: Double, t: Double, bg: SIMD4<Float>) -> M.Img {
        let px = PasserArt.render(k, phase: phase, t: t, facing: 1, light: -1)
        var o = M.Img(w: PasserArt.W, h: PasserArt.H, bg)
        for i in 0..<(PasserArt.W * PasserArt.H) {
            let a = Float(px[i * 4 + 3]) / 255
            o.c[i] = SIMD4(Float(px[i * 4]) / 255, Float(px[i * 4 + 1]) / 255, Float(px[i * 4 + 2]) / 255, 0) + bg * (1 - a); o.c[i].w = 1
        }
        return o
    }

    @Test(.enabled(if: Strip.dump)) func passerSharp() throws {
        var panels: [(M.Img, String, String)] = []
        for k in PasserKind.allCases { for j in 0..<6 {
            let ph = Double(j) / 6 * 2 * .pi
            panels.append((Self.passerImg(k, phase: ph, t: Double(j) * 0.08, bg: SIMD4(0.2, 0.26, 0.42, 1)).up(3, w: PasserArt.W * 3, h: PasserArt.H * 3), "\(Self.kname(k)) \(j + 1)/6", ""))
        } }
        try M.sheet(panels, cols: 6, name: "passer_sharp_dbg", title: "행인 그림(선명 · 3배)")
    }

    /// 행인 변형 넷 × 걸음 프레임: 선명(흐리기 전 · 미술 점검 3배) · 장면 속 최종(실제 렌더러 · 3배) · 휴대폰 크기 1배 화면 전체
    @Test(.enabled(if: Strip.dump)) func passerVariants() throws {
        let P = try Pair(bg: "snow")
        var last: (SimSnapshot, StageFrame, StageFrame)!
        for _ in 0..<200 { last = P.tick() }   // 시작 행인 이벤트가 지나간 뒤(장면 안 행인은 아래에서 직접 넣는다)
        let (s, _, fb) = last!
        let cx = Int(fb.view.cameraX.rounded()), pw = PasserArt.W * 3, ph = PasserArt.H * 3
        let phases = [0.0, 0.25, 0.5, 0.75]
        var panels: [(M.Img, String, String)] = []
        for k in PasserKind.allCases {
            for (j, u) in phases.enumerated() {
                panels.append((Self.passerImg(k, phase: u * 2 * .pi, t: u * 0.7, bg: SIMD4(0.2, 0.26, 0.42, 1)).up(3, w: pw, h: ph), "\(Self.kname(k)) · 선명 \(j + 1)", "흐리기 전(무대 픽셀)"))
            }
            for (j, u) in phases.enumerated() {
                var f = fb, D = try #require(f.depth)
                var C = FgCanvas(w: M.vw, h: M.H)
                C.blit(PasserArt.render(k, phase: u * 2 * .pi, t: u * 0.7, facing: 1, light: -1), sw: PasserArt.W, sh: PasserArt.H, ox: M.vw - 24 - PasserArt.footX, oy: 290 - PasserArt.footY, alpha: 0.95)
                Self.setFg(&D, C, x0: cx); D.fgBlur = DojoDepth.blurR
                f.depth = D
                let px = try Self.render(P.B, s, f)
                let img = M.Img.from(SnowStripTests.crop(px, x0: cx + M.vw - PasserArt.W, y0: M.H - PasserArt.H, w: PasserArt.W, h: PasserArt.H).px, w: PasserArt.W, h: PasserArt.H)
                panels.append((img.up(3, w: pw, h: ph), "\(Self.kname(k)) · 장면 \(j + 1)", "흐림 \(DojoDepth.blurR)px → 24단 디더"))
                if j == 3 {   // 휴대폰 크기 1배(보이는 폭 198 전체 — 마지막 프레임)
                    var o = M.Img(w: pw, h: ph, SIMD4(0.07, 0.07, 0.1, 1))
                    let full = M.Img.from(SnowStripTests.crop(px, x0: cx, y0: 0, w: M.vw, h: M.H).px, w: M.vw, h: M.H)
                    let ox = (pw - M.vw) / 2, oy = (ph - M.H) / 2
                    for y in 0..<M.H { for xx in 0..<M.vw { o.c[(oy + y) * pw + ox + xx] = full.c[y * M.vw + xx] } }
                    panels.append((o, "\(Self.kname(k)) · 1배", "휴대폰 화면 크기 그대로"))
                }
            }
        }
        try M.sheet(panels, cols: 9, name: "passerby_variants", title: "전경 행인 — 변형 넷 · 걸음 4프레임(선명 3배 · 장면 속 3배) · 휴대폰 1배")
    }

    /// 행인 비용: 그림 만들기(CPU) · 같은 프레임 행인 있음/없음 GPU(postFS 원판 탭 + 텍스처 올리기)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_BENCH"] == "1")) func benchPasser() throws {
        let N = 600
        var t0 = DispatchTime.now().uptimeNanoseconds, sink = 0
        for k in 0..<N { sink &+= Int(PasserArt.render(PasserKind(rawValue: k % 4)!, phase: Double(k) * 0.13, t: Double(k) / 60, facing: 1, light: -1)[4000]) }
        let cpu = PerfBenchTests.ms(t0) / Double(N)
        let P = try Pair(bg: "snow")
        var last: (SimSnapshot, StageFrame, StageFrame)!
        for _ in 0..<200 { last = P.tick() }
        let (s, _, fb) = last!
        func gpu(_ with: Bool) throws -> Double {
            var acc = 0.0
            for k in 0..<300 {
                var f = fb, D = try #require(f.depth)
                if with { var C = FgCanvas(w: M.vw, h: M.H); C.blit(PasserArt.render(.umbrella, phase: Double(k) * 0.13, t: 0, facing: 1, light: -1), sw: PasserArt.W, sh: PasserArt.H, ox: 150, oy: 152, alpha: 0.95)
                    Self.setFg(&D, C, x0: Int(f.view.cameraX)); D.fgBlur = DojoDepth.blurR }
                f.depth = D
                var rf = RenderFrame(stage: f, atlas: P.B.content.sprites); rf.applyHUD(P.B.d.hud.state, now: s.time)
                let cb = try #require(P.B.q.makeCommandBuffer()); try P.B.fr.encode(rf, targets: P.B.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
                acc += (cb.gpuEndTime - cb.gpuStartTime) * 1000
            }
            return acc / 300
        }
        for _ in 0..<2 { _ = try gpu(false); _ = try gpu(true) }   // GPU 시계 올리기
        var on: [Double] = [], off: [Double] = []
        for _ in 0..<5 { on.append(try gpu(true)); off.append(try gpu(false)) }
        let a = on.sorted()[2], b = off.sorted()[2]
        t0 = 0
        print(String(format: "[bench passer] 그림 CPU %.3f ms/프레임 · GPU 있음 %.3f · 없음 %.3f (%+.3f) ms (%d)", cpu, a, b, a - b, sink & 1))
    }

    static func setFg(_ D: inout DepthFX, _ C: FgCanvas, x0: Int) { D.fg = C.bytes; D.fgAt = [Double(x0), 0]; D.fgSize = [C.w, C.h]; D.fgVersion = 0 }
    /// 캔버스(미리 곱한 RGBA) → 배경 위 합성 Img
    static func canvasImg(_ C: FgCanvas, bg: SIMD4<Float>) -> M.Img {
        var o = M.Img(w: C.w, h: C.h, bg); let b = C.bytes
        for i in 0..<(C.w * C.h) { let a = Float(b[i * 4 + 3]) / 255
            o.c[i] = SIMD4(Float(b[i * 4]) / 255, Float(b[i * 4 + 1]) / 255, Float(b[i * 4 + 2]) / 255, 0) + bg * (1 - a); o.c[i].w = 1 }
        return o
    }
    /// 화면 크기 렌더 → 3배 · 휴대폰 1배(가운데 둔 같은 크기 칸)
    static func shot(_ R: Strip.Rig, _ s: SimSnapshot, _ f: StageFrame) throws -> (M.Img, M.Img) {
        let px = try render(R, s, f), cx = Int(f.view.cameraX.rounded())
        let one = M.Img.from(SnowStripTests.crop(px, x0: cx, y0: 0, w: M.vw, h: M.H).px, w: M.vw, h: M.H)
        var phone = M.Img(w: M.vw * 3, h: M.H * 3, SIMD4(0.07, 0.07, 0.1, 1))
        let ox = M.vw, oy = M.H
        for y in 0..<M.H { for x in 0..<M.vw { phone.c[(oy + y) * phone.w + ox + x] = one.c[y * M.vw + x] } }
        return (one.up(3, w: M.vw * 3, h: M.H * 3), phone)
    }

    /// 건널목 · 무도장 전/후(같은 프레임 · 3배 + 휴대폰 1배). 건널목은 전차가 지나며 경보기가 들어온 순간 · 경보 전 순간 두 프레임
    @Test(.enabled(if: Strip.dump)) func bgBeforeAfter() throws {
        for (bg, name, title) in [("cross", "crosswalk_depth_before_after", "건널목"), ("dojo", "wooddojo_depth_before_after", "무도장")] {
            let P = try Pair(bg: bg)
            P.sim.apply(.dojo(.combo(0)))
            var picks: [(SimSnapshot, StageFrame, StageFrame, String)] = []
            var last: (SimSnapshot, StageFrame, StageFrame)!
            for _ in 0...18 { last = P.tick() }
            picks.append((last.0, last.1, last.2, "맞붙은 순간"))
            if bg == "cross" {   // 경보가 울리고 1.2초 뒤(경보기 들어옴 · 붉은빛)
                var bellAt: Int?
                for i in 0..<(60 * 40) {
                    last = P.tick()
                    if i % 150 == 0 { P.sim.apply(.dojo(.combo(i / 150 % 3))) }
                    if bellAt == nil, P.B.d.carry.cross?.state.bell == true { bellAt = i }
                    if let b = bellAt, i - b == 72 { picks.append((last.0, last.1, last.2, "전차 · 경보기")); break }
                }
            } else {
                for _ in 0..<90 { last = P.tick() }   // 노렌이 잦아들기 전
                picks.append((last.0, last.1, last.2, "1.5초 뒤"))
            }
            var panels: [(M.Img, String, String)] = []
            for (s, fa, fb, tag) in picks {
                let (a3, _) = try Self.shot(P.A, s, fa), (b3, b1) = try Self.shot(P.B, s, fb)
                panels += [(a3, "\(title) · 전 · \(tag)", "dojoDepth 0 (= 웹 경로)"), (b3, "\(title) · 후 · \(tag)", "dojoDepth 1 — 실제 렌더러"), (b1, "\(title) · 후 · 휴대폰 1배", "화면 크기 그대로")]
            }
            try M.sheet(panels, cols: 3, name: name, title: "\(title) 깊이 · 조명 — 같은 프레임 전/후(3배) · 휴대폰 1배")
        }
    }

    /// 새 전경 그림(선명 — 미술 점검 3배 · 장면 속 최종 3배): 억새 · 단풍잎 · 경보기(등 둘) · 기둥 + 줄 · 노렌
    @Test(.enabled(if: Strip.dump)) func fgArt() throws {
        let bgc = SIMD4<Float>(0.42, 0.26, 0.36, 1), bgw = SIMD4<Float>(0.22, 0.15, 0.1, 1)
        var panels: [(M.Img, String, String)] = []
        let cw = 100, ch = 140
        func cut(_ C: FgCanvas, _ b: SIMD4<Float>) -> M.Img { Self.canvasImg(C, bg: b).up(3, w: cw * 3, h: ch * 3) }
        for (j, t) in [0.0, 0.4, 0.8, 1.2].enumerated() {
            var C = FgCanvas(w: cw, h: ch)
            ForegroundArt.silverGrass(&C, x: 30, y: Double(ch) + 2, height: 70, t: t, seed: 3, sun: 1, alpha: 1)
            ForegroundArt.silverGrass(&C, x: 72, y: Double(ch) + 2, height: 46, t: t, seed: 8, sun: 1, alpha: 1)
            panels.append((cut(C, bgc), "억새 \(j + 1)/4", "흔들림 t=\(t)"))
        }
        do {
            var C = FgCanvas(w: cw, h: ch)
            for (i, a) in [0.0, 0.9, 1.8, 2.7].enumerated() { ForegroundArt.mapleLeaf(&C, cx: 24 + Double(i % 2) * 50, cy: 34 + Double(i / 2) * 60, r: 9, angle: a, hue: Double(i) / 3, alpha: 1) }
            panels.append((cut(C, bgc), "단풍잎(회전 넷)", ""))
        }
        for lit in [0, 1] {
            var C = FgCanvas(w: cw, h: ch * 2)
            ForegroundArt.crossingSignal(&C, x: 50, lit: lit, sun: 1, alpha: 1)
            let img = Self.canvasImg(C, bg: bgc)
            var top = M.Img(w: cw, h: ch); for y in 0..<ch { for x in 0..<cw { top.c[y * cw + x] = img.c[(y + 20) * cw + x] } }
            panels.append((top.up(3, w: cw * 3, h: ch * 3), "경보기 · \(lit == 0 ? "왼쪽" : "오른쪽") 등", "2.4Hz 번갈아"))
        }
        do {
            var C = FgCanvas(w: cw, h: ch)
            ForegroundArt.pillar(&C, side: -1, width: 14, warmSide: 1, alpha: 1)
            ForegroundArt.rope(&C, x: 26, length: 104, swing: 0.03, alpha: 1)
            panels.append((cut(C, bgw), "기둥 + 줄", "등롱 쪽 테"))
        }
        for (j, u) in [0.15, 0.6, 1.4].enumerated() {
            var C = FgCanvas(w: cw, h: ch)
            let drop = 34 * (1 - exp(-u / 0.22)), sw = 8 * exp(-u / 1.4)
            ForegroundArt.noren(&C, x: 18, drop: drop, sway: sw, t: u, alpha: 1)
            panels.append((cut(C, bgw), "노렌 \(j + 1)/3", "t=\(u)초"))
        }
        // 장면 속(실제 렌더러): 건널목 · 무도장 전경이 켜진 프레임에서 왼쪽 · 오른쪽 아래 부분
        for bg in ["cross", "dojo"] {
            let P = try Pair(bg: bg)
            var last: (SimSnapshot, StageFrame, StageFrame)!
            for _ in 0..<40 { last = P.tick() }
            let (_, b1) = try Self.shot(P.B, last.0, last.2)
            panels.append((b1, bg == "cross" ? "건널목 · 장면 속(1배)" : "무도장 · 장면 속(1배)", "흐림 2.2px → 24단 디더"))
            let (b3, _) = try Self.shot(P.B, last.0, last.2)
            var crop = M.Img(w: cw * 3, h: ch * 3)
            let y0 = bg == "cross" ? (M.H - ch) * 3 : 0
            for y in 0..<(ch * 3) { for x in 0..<(cw * 3) { crop.c[y * cw * 3 + x] = b3.c[(y0 + y) * b3.w + x] } }
            panels.append((crop, bg == "cross" ? "건널목 · 장면 속 왼쪽 아래(3배)" : "무도장 · 장면 속 왼쪽 위(3배)", ""))
        }
        try M.sheet(panels.map { p in
            if p.0.w == cw * 3 && p.0.h == ch * 3 { return p }
            var o = M.Img(w: cw * 3, h: ch * 3, SIMD4(0.07, 0.07, 0.1, 1))   // 휴대폰 1배 칸(가운데 자르기)
            let ox = (p.0.w - cw * 3) / 2, oy = (p.0.h - ch * 3) / 2
            for y in 0..<(ch * 3) { for x in 0..<(cw * 3) { o.c[y * cw * 3 + x] = p.0.c[(oy + y) * p.0.w + ox + x] } }
            return (o, p.1, p.2)
        }, cols: 6, name: "dojo_fg_art", title: "건널목 · 무도장 전경 그림 — 선명(3배) · 장면 속")
    }
}
