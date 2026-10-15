import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 네이티브 동작 개편(SimConfig.nativeMoves) 눈으로 보기 — 실제 판 → StageDirector → 장면 렌더 + HUD 오버레이(앱과 같은 경로)를
/// 주인공 둘레로 잘라 연속 이미지로 붙인다. BB_DUMP=1 일 때만 → tools/js/out/moves/<이름>.png
///   rush(네이티브 막차 러시) · rush_web(웹 규칙 러시 — 비교) · move(출발 · 질주 · 미끄러져 서기 · 스텝 인) · tech_<기술>(새 복싱 기술 5종)
/// 칸 위 색 띠: 이동 상태(노랑 출발 · 주황 질주 · 빨강 미끄러짐 · 파랑 스텝 인 · 초록 걷기) / 기술 칸은 흰 띠 = 타격 자세
@Suite(.serialized) struct NativeMoveStripTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let out = root.appending(path: "tools/js/out/moves")
    static let base: SimData = try! SimData.bundled()
    static var dump: Bool { ProcessInfo.processInfo.environment["BB_DUMP"] == "1" }

    /// 장면 + UI 를 앱과 같은 줌으로 합성하고(UI 3배 해상도) 주인공 둘레 cw×ch 를 잘라낸다
    struct Shot { var px: [UInt8]; var band: (UInt8, UInt8, UInt8)? }
    final class Rig {
        let content: SceneContent, d: StageDirector, art: HUDArt, fr: FrameRenderer, ov: OverlayRenderer, tg: FrameRenderer.Targets, q: MTLCommandQueue
        init(native: Bool) throws {
            let store = try ContentStore.bundled(), data = NativeMoveStripTests.base.variant(nativeMoves: native)
            content = try SceneContent.bundled()
            d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
            art = try HUDArt(store: store); d.hud.art = art; d.hud.playSpeed = 1
            let device = MTLCreateSystemDefaultDevice()!
            q = device.makeCommandQueue()!; fr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()); ov = try OverlayRenderer(device: device)
            tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        }
        func shot(_ s: SimSnapshot, _ f: StageFrame, cw: Int, ch: Int, band: (UInt8, UInt8, UInt8)?, ds: Int = 2, dx: Int = 0, dy: Int = 0, hud: Bool = true) throws -> Shot {
            var rf = RenderFrame(stage: f, atlas: content.sprites)
            rf.applyHUD(d.hud.state, now: s.time)
            let F = d.hud.frame(s, view: f.view, shake: f.shake)
            let list = HUDOverlay.build(d.hud.state, F, art: art)
            let ui = try ov.render(list, atlas: art.atlas, queue: q)
            let cb = q.makeCommandBuffer()!; try fr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
            let scene = try fr.readBack(tg.output(for: rf), queue: q)
            let W = list.width, Hh = list.height, v = f.view
            let H = s.actors.first { $0.isHero }!
            let hp = v.toView(SIMD2(H.x, H.y - 30)) * SIMD2(Double(W), Double(Hh))
            // 잘라낼 창(UI 픽셀) = 출력 cw×ch 의 ds 배 — ds×ds 평균으로 줄인다
            let CW = cw * ds, CH = ch * ds
            let x0 = max(0, min(W - CW, Int(hp.x) + dx * ds - CW / 2)), y0 = max(0, min(Hh - CH, Int(hp.y) + dy * ds - CH * 3 / 5))
            var px = [UInt8](repeating: 255, count: cw * ch * 4)
            for y in 0..<ch { for x in 0..<cw {
                var acc = [0.0, 0.0, 0.0]
                for yy in 0..<ds { for xx in 0..<ds {
                    let ux = x0 + x * ds + xx, uy = y0 + y * ds + yy
                    let sp = v.toScene(SIMD2((Double(ux) + 0.5) / Double(W), (Double(uy) + 0.5) / Double(Hh)))
                    let sx = max(0, min(479, Int(sp.x))), sy = max(0, min(269, Int(sp.y))), si = (sy * 480 + sx) * 4, o = (uy * W + ux) * 4
                    let a = hud ? Double(ui[o + 3]) / 255 : 0   // hud false: 무대만(피해 숫자 · 글자 없이 — 동작 확인용)
                    for c in 0..<3 { acc[c] += min(255, Double(scene[si + c]) * (1 - a) + Double(ui[o + c]) * a) }
                } }
                let d = (y * cw + x) * 4
                for c in 0..<3 { px[d + c] = UInt8(acc[c] / Double(ds * ds)) }
            } }
            return Shot(px: px, band: band)
        }
    }

    /// 격자로 붙여 PNG
    static func sheet(_ shots: [Shot], cw: Int, ch: Int, cols: Int, name: String) throws {
        guard !shots.isEmpty else { Issue.record("\(name): 칸 없음"); return }
        let rows = (shots.count + cols - 1) / cols, gap = 6, bandH = 8
        let W = cols * (cw + gap) + gap, H = rows * (ch + bandH + gap) + gap
        var px = [UInt8](repeating: 24, count: W * H * 4)
        for i in stride(from: 3, to: px.count, by: 4) { px[i] = 255 }
        for (k, s) in shots.enumerated() {
            let ox = gap + (k % cols) * (cw + gap), oy = gap + (k / cols) * (ch + bandH + gap)
            if let b = s.band { for y in 0..<bandH - 2 { for x in 0..<cw { let d = ((oy + y) * W + ox + x) * 4; px[d] = b.0; px[d + 1] = b.1; px[d + 2] = b.2 } } }
            for y in 0..<ch { for x in 0..<cw {
                let s0 = (y * cw + x) * 4, d = ((oy + bandH + y) * W + ox + x) * 4
                px[d] = s.px[s0]; px[d + 1] = s.px[s0 + 1]; px[d + 2] = s.px[s0 + 2]
            } }
        }
        let url = out.appending(path: name + ".png")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[moves] \(name): \(shots.count)칸 → \(url.path)")
    }

    static func config(_ native: Bool, bag: [BagItem]? = nil) -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = native; c.customBag = bag; c.playSpeed = 1
        return c
    }

    // MARK: 막차 러시

    func rush(_ native: Bool, name: String, seed: UInt32) throws {
        let R = try Rig(native: native)
        let sim = Sim(data: Self.base, seed: seed, config: Self.config(native))
        var shots: [Shot] = [], started = false, endAt: Int?
        for k in 0..<(60 * 40) {
            let w = sim.w
            if !started && w.state == "fight" && w.time > 3 + Double(seed % 9) && w.foes().filter({ !w.isDown($0) }).count >= 2 && w.spc == nil && w.cut == nil {
                w.sp = 100; started = w.trySpecial()
            }
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if started && w.cut == nil && k % 4 == 0 { shots.append(try R.shot(s, f, cw: 420, ch: 300, band: w.spc?.fin == true ? (255, 220, 90) : w.spc != nil ? (255, 140, 40) : nil)) }
            if started && w.spc == nil && w.cut == nil && endAt == nil { endAt = k + 30 }
            if let e = endAt, k >= e { break }
        }
        try Self.sheet(shots, cw: 420, ch: 300, cols: 6, name: name)
    }
    @Test(.enabled(if: dump)) func rushStrip() throws { try rush(true, name: "rush", seed: 12) }
    @Test(.enabled(if: dump)) func rushWebStrip() throws { try rush(false, name: "rush_web", seed: 12) }

    // MARK: 이동

    @Test(.enabled(if: dump)) func moveStrip() throws {
        let R = try Rig(native: true)
        let sim = Sim(data: Self.base, seed: 31, config: Self.config(true))
        var shots: [Shot] = [], prev: [Shot] = [], tail = 0
        for k in 0..<(60 * 60) {
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard k % 2 == 0 else { continue }
            let H = w.hero!, sprint = H.anim == "walk" && H.runU > w.gameTime
            let band: (UInt8, UInt8, UInt8)? = H.anim == "nv_go" ? (255, 230, 60) : H.anim == "nv_skid" || H.anim == "nv_skidEnd" ? (230, 60, 50) : H.anim == "nv_step" ? (80, 150, 255)
                : sprint ? (255, 140, 40) : H.anim == "walk" ? (90, 200, 100) : nil
            let key = H.anim == "nv_go" || H.anim == "nv_skid" || H.anim == "nv_skidEnd" || H.anim == "nv_step"
            let shot = try R.shot(s, f, cw: 300, ch: 270, band: band)
            if key { if tail == 0 { shots += prev.suffix(2) }; shots.append(shot); tail = 4 }
            else if tail > 0 { shots.append(shot); tail -= 1 }
            prev.append(shot); if prev.count > 3 { prev.removeFirst() }
            if shots.count >= 48 { break }
        }
        try Self.sheet(shots, cw: 300, ch: 270, cols: 8, name: "move")
    }

    // MARK: 새 기술

    @Test(.enabled(if: dump)) func techniqueStrips() throws {
        for (id, anim) in [("nv_flick", "nv_flick"), ("nv_liver", "nv_liver"), ("nv_cork", "nv_cork"), ("upper", "upper"), ("nv_roll", "nv_roll")] {
            let R = try Rig(native: true)
            let bag = [BagItem(id: id, uid: 1, x: 0, y: 0), BagItem(id: "duck", uid: 2, x: 5, y: 3)]
            let sim = Sim(data: Self.base, seed: 77, config: Self.config(true, bag: bag))
            var shots: [Shot] = [], uses = 0, tail = 0, was = false
            for k in 0..<(60 * 90) {
                let ev = sim.step(), s = sim.snapshot, w = sim.w
                _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                let on = w.hero.anim == anim
                if on && !was { uses += 1 }
                was = on
                guard uses >= 2, k % 2 == 0 else { continue }   // 두 번째 쓸 때부터(첫 번은 거리 재기)
                let hit = w.hero.pose == data(w).jwCue[anim]
                if on { shots.append(try R.shot(s, f, cw: 330, ch: 270, band: hit ? (255, 255, 255) : (120, 120, 140))); tail = 5 }
                else if tail > 0 { shots.append(try R.shot(s, f, cw: 330, ch: 270, band: nil)); tail -= 1; if tail == 0 && uses >= 3 { break } }
                if shots.count >= 30 { break }
            }
            try Self.sheet(shots, cw: 330, ch: 270, cols: 6, name: "tech_\(id)")
        }
    }
    func data(_ w: World) -> SimData { w.data }
}
