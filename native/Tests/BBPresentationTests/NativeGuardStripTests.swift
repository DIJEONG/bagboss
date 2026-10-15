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

/// 네이티브 공방(docs/08) 눈으로 보기 — 실제 판 → StageDirector → 장면 + HUD(앱과 같은 경로)를 잘라 붙인다. BB_DUMP=1 일 때만 → tools/js/out/guard/
///  poses(가드 · 막는 순간 · 크래시 · 도발 · 끼어들기 예고 · 로킥 — 1× · 2×) · block(막기 순간들) · crash(가드 크래시 연속) · crowd(군중 자리 — 0.5초 간격)
///  · hero(주인공 가드) · cutin(끼어들기 예고 → 공격). 칸 위 띠: 파랑 막기 · 노랑 흘림 · 빨강 크래시 · 주황 끼어들기 · 흰 저스트
@Suite(.serialized) struct NativeGuardStripTests {
    static let root = NativeMoveStripTests.root
    static let out = root.appending(path: "tools/js/out/guard")
    static var dump: Bool { ProcessInfo.processInfo.environment["BB_DUMP"] == "1" }
    typealias Shot = NativeMoveStripTests.Shot

    /// 무대 점(cx, cy — 장면 좌표)을 가운데로 cw×ch 를 잘라낸다(ds = UI 픽셀 몇 개를 한 픽셀로: 3 = 장면 1배, 2 = 1.5배)
    static func shot(_ R: NativeMoveStripTests.Rig, _ s: SimSnapshot, _ f: StageFrame, cx: Double, cy: Double, cw: Int, ch: Int, ds: Int, band: (UInt8, UInt8, UInt8)?) throws -> Shot {
        var rf = RenderFrame(stage: f, atlas: R.content.sprites)
        rf.applyHUD(R.d.hud.state, now: s.time)
        let F = R.d.hud.frame(s, view: f.view, shake: f.shake)
        let list = HUDOverlay.build(R.d.hud.state, F, art: R.art)
        let ui = try R.ov.render(list, atlas: R.art.atlas, queue: R.q)
        let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
        let scene = try R.fr.readBack(R.tg.output(for: rf), queue: R.q)
        let W = list.width, Hh = list.height, v = f.view
        let hp = v.toView(SIMD2(cx, cy)) * SIMD2(Double(W), Double(Hh))
        let CW = cw * ds, CH = ch * ds
        let x0 = max(0, min(W - CW, Int(hp.x) - CW / 2)), y0 = max(0, min(Hh - CH, Int(hp.y) - CH / 2))
        var px = [UInt8](repeating: 255, count: cw * ch * 4)
        for y in 0..<ch { for x in 0..<cw {
            var acc = [0.0, 0.0, 0.0]
            for yy in 0..<ds { for xx in 0..<ds {
                let ux = x0 + x * ds + xx, uy = y0 + y * ds + yy
                let sp = v.toScene(SIMD2((Double(ux) + 0.5) / Double(W), (Double(uy) + 0.5) / Double(Hh)))
                let sx = max(0, min(479, Int(sp.x))), sy = max(0, min(269, Int(sp.y))), si = (sy * 480 + sx) * 4, o = (uy * W + ux) * 4
                let a = Double(ui[o + 3]) / 255
                for c in 0..<3 { acc[c] += min(255, Double(scene[si + c]) * (1 - a) + Double(ui[o + c]) * a) }
            } }
            let d = (y * cw + x) * 4
            for c in 0..<3 { px[d + c] = UInt8(acc[c] / Double(ds * ds)) }
        } }
        return Shot(px: px, band: band)
    }

    static func sheet(_ shots: [Shot], cw: Int, ch: Int, cols: Int, name: String, scale: Int = 1) throws {
        guard !shots.isEmpty else { Issue.record("\(name): 칸 없음"); return }
        let rows = (shots.count + cols - 1) / cols, gap = 6, bandH = 8
        let W0 = cols * (cw + gap) + gap, H0 = rows * (ch + bandH + gap) + gap
        var px = [UInt8](repeating: 24, count: W0 * H0 * 4)
        for i in stride(from: 3, to: px.count, by: 4) { px[i] = 255 }
        for (k, s) in shots.enumerated() {
            let ox = gap + (k % cols) * (cw + gap), oy = gap + (k / cols) * (ch + bandH + gap)
            if let b = s.band { for y in 0..<bandH - 2 { for x in 0..<cw { let d = ((oy + y) * W0 + ox + x) * 4; px[d] = b.0; px[d + 1] = b.1; px[d + 2] = b.2 } } }
            for y in 0..<ch { for x in 0..<cw {
                let s0 = (y * cw + x) * 4, d = ((oy + bandH + y) * W0 + ox + x) * 4
                px[d] = s.px[s0]; px[d + 1] = s.px[s0 + 1]; px[d + 2] = s.px[s0 + 2]
            } }
        }
        // 정수 배율로 키우기(실제 화면 크기 감)
        let W = W0 * scale, H = H0 * scale
        var big = [UInt8](repeating: 0, count: W * H * 4)
        for y in 0..<H { for x in 0..<W { let s0 = ((y / scale) * W0 + x / scale) * 4, d = (y * W + x) * 4; for c in 0..<4 { big[d + c] = px[s0 + c] } } }
        let url = out.appending(path: name + ".png")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let ctx = CGContext(data: &big, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[guard] \(name): \(shots.count)칸 → \(url.path)")
    }

    static func config(stage: Int = 0, seedKit: String = "basic") -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.playSpeed = 1; c.stage = stage; c.kit = seedKit
        return c
    }

    // MARK: 포즈(실제 칸 · 1× / 2×)

    @Test(.enabled(if: dump)) func poseStrip() throws {
        let R = try NativeMoveStripTests.Rig(native: true)
        let sim = Sim(data: NativeMoveStripTests.base, seed: 5, config: Self.config()), w = sim.w
        for k in 0..<600 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); if w.state == "fight" && w.legT > 1.5 { break } }
        w.ents = w.ents.filter { $0.e == nil && !$0.pass }; w.nextWaveAt = 1e9   // 승객도 치운다(겹쳐 보이지 않게)
        let H = w.hero!
        H.x = 150; H.flip = false; w.setAnim(H, "idle")
        w.spawnWave(["punk"], fromDoors: false)
        let A = w.foes()[0]; A.x = 192; A.flip = true; A.z = 2
        var shots1: [Shot] = [], shots2: [Shot] = []
        let anims: [(String, String, Int)] = [("idle", "평소(비교)", 2), ("nv_gdH", "서서 막기", 2), ("nv_gdHb", "막는 순간", 1), ("nv_gdL", "앉아 막기", 2), ("nv_gdLb", "앉아 막는 순간", 1),
                                             ("nv_gcrash", "크래시", 1), ("nv_gcrash", "크래시 2", 5), ("nv_taunt1", "도발 손짓", 4), ("nv_taunt2", "도발 덤벼", 2),
                                             ("nv_stomp", "끼어들기 예고", 1), ("nv_stomp", "구르기", 5), ("nv_lowk", "로킥", 4)]
        var t = 0
        for (anim, _, adv) in anims {
            w.setAnim(A, anim); A.after = nil
            for _ in 0..<adv { w.advance(A) }
            for _ in 0..<14 { w.gameTime += 1.0 / 60; _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(700 + t) / 60); t += 1 }   // 그리기 블렌드는 게임 시계로 섞인다
            let s = sim.snapshot, f = R.d.frame(s, dt: 1.0 / 60, now: Double(700 + t) / 60)
            if let v = s.actors.first(where: { $0.id == A.id }) { print("[pose] \(anim) → \(v.pose.anim)/\(v.pose.pose) prev \(v.pose.prev ?? "-") k \(v.pose.k ?? -1)/\(v.pose.phaseN ?? -1) x \(v.x) hidden \(v.hidden) has \(w.data.animTables.poses[v.pose.pose] != nil)") }
            shots1.append(try Self.shot(R, s, f, cx: (H.x + A.x) / 2, cy: A.y - 30, cw: 110, ch: 84, ds: 3, band: nil))
            shots2.append(try Self.shot(R, s, f, cx: A.x + 6, cy: A.y - 30, cw: 120, ch: 120, ds: 2, band: nil))
        }
        // 주인공 가드
        for anim in ["nv_gdH", "nv_gdL", "nv_gcrash"] {
            w.setAnim(A, "idle"); w.setAnim(H, anim); H.after = nil; if anim == "nv_gcrash" { w.advance(H) }
            for _ in 0..<14 { w.gameTime += 1.0 / 60; _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(700 + t) / 60); t += 1 }   // 그리기 블렌드는 게임 시계로 섞인다
            let s = sim.snapshot, f = R.d.frame(s, dt: 1.0 / 60, now: Double(700 + t) / 60)
            shots1.append(try Self.shot(R, s, f, cx: (H.x + A.x) / 2, cy: H.y - 30, cw: 110, ch: 84, ds: 3, band: (120, 200, 255)))
            shots2.append(try Self.shot(R, s, f, cx: H.x, cy: H.y - 30, cw: 120, ch: 120, ds: 2, band: (120, 200, 255)))
        }
        try Self.sheet(shots1, cw: 110, ch: 84, cols: 5, name: "poses_1x", scale: 3)
        try Self.sheet(shots2, cw: 120, ch: 120, cols: 5, name: "poses_2x")
        try Self.sheet(Array(shots2.prefix(8)), cw: 120, ch: 120, cols: 4, name: "poses_zoom_a", scale: 2)
        try Self.sheet(Array(shots2.dropFirst(8)), cw: 120, ch: 120, cols: 4, name: "poses_zoom_b", scale: 2)
    }

    // MARK: 실전 — 막기 · 크래시 · 군중 · 주인공 가드 · 끼어들기

    struct Clip { var at: Int; var kind: String; var x: Double, y: Double }

    /// 한 판을 돌리며 사건(막기 · 크래시 …) 둘레 칸을 모은다 — 칸은 그 순간에 그린다(지난 칸을 나중에 그리면 HUD 효과가 섞인다) → 주인공 가운데로 자른다
    func capture(seed: UInt32, stage: Int = 0, seconds: Double = 70, kinds: Set<String>, before: Int, after: Int, every: Int = 2, maxClips: Int, cw: Int, ch: Int, ds: Int, name: String, cols: Int, scale: Int = 1) throws {
        let R = try NativeMoveStripTests.Rig(native: true)
        let sim = Sim(data: NativeMoveStripTests.base, seed: seed, config: Self.config(stage: stage)), w = sim.w
        var ring: [Shot] = [], shots: [Shot] = [], clips = 0, tail = 0, lastClip = -999
        for k in 0..<Int(seconds * 60) {
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            var band: (UInt8, UInt8, UInt8)?
            for e in ev {
                switch e {
                case .guardBlock(let g) where kinds.contains(g.heroBlocked ? "heroBlock" : g.whiff ? "whiff" : "block") || (g.just && kinds.contains("just")):
                    band = g.just ? (255, 255, 255) : g.whiff ? (255, 220, 90) : g.heroBlocked ? (120, 230, 255) : (110, 160, 255)
                case .guardCrash where kinds.contains("crash"): band = (230, 60, 50)
                case .fxDetail(let d) where d.kind == "nv_alert" && kinds.contains("cutin"): band = (255, 150, 40)
                default: break
                }
            }
            let H = w.hero!
            let start = band != nil && tail == 0 && clips < maxClips && k - lastClip > 90
            guard start || tail > 0 || k % every == 0 else { continue }
            let shot = try Self.shot(R, s, f, cx: H.x, cy: H.y - 30, cw: cw, ch: ch, ds: ds, band: band)
            if start { clips += 1; lastClip = k; tail = after; shots += ring; ring = []; shots.append(shot); continue }
            if tail > 0 { if k % every == 0 || band != nil { shots.append(shot) }; tail -= 1; if tail == 0 && clips >= maxClips { break }; continue }
            ring.append(shot); if ring.count > before { ring.removeFirst() }
        }
        try Self.sheet(shots, cw: cw, ch: ch, cols: cols, name: name, scale: scale)
    }

    @Test(.enabled(if: dump)) func blockStrip() throws {
        try capture(seed: 21, kinds: ["block", "whiff"], before: 3, after: 12, every: 3, maxClips: 4, cw: 200, ch: 120, ds: 2, name: "block", cols: 6, scale: 2)
    }
    @Test(.enabled(if: dump)) func crashStrip() throws {
        try capture(seed: 21, seconds: 120, kinds: ["crash"], before: 6, after: 36, every: 3, maxClips: 2, cw: 200, ch: 170, ds: 2, name: "crash", cols: 6, scale: 2)
    }
    @Test(.enabled(if: dump)) func heroGuardStrip() throws {
        try capture(seed: 33, stage: 1, seconds: 140, kinds: ["heroBlock"], before: 4, after: 14, every: 3, maxClips: 3, cw: 200, ch: 120, ds: 2, name: "hero", cols: 6, scale: 2)
    }
    @Test(.enabled(if: dump)) func cutInStrip() throws {
        try capture(seed: 21, seconds: 140, kinds: ["cutin"], before: 2, after: 52, every: 4, maxClips: 2, cw: 260, ch: 130, ds: 2, name: "cutin", cols: 5, scale: 2)
    }

    /// 군중 자리: 0.5초 간격 — 넓게(주인공 가운데)
    @Test(.enabled(if: dump)) func crowdStrip() throws {
        let R = try NativeMoveStripTests.Rig(native: true)
        let sim = Sim(data: NativeMoveStripTests.base, seed: 44, config: Self.config(stage: 1)), w = sim.w
        var shots: [Shot] = []
        for k in 0..<(60 * 80) {
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard k % 30 == 0, w.state == "fight", w.foes().count >= 3 else { continue }
            let tokens = w.foes().filter { $0.nvg.tok }.count
            shots.append(try Self.shot(R, s, f, cx: w.hero.x, cy: w.hero.y - 30, cw: 300, ch: 110, ds: 2, band: tokens >= 2 ? (255, 140, 40) : tokens == 1 ? (255, 220, 90) : nil))
            if shots.count >= 24 { break }
        }
        try Self.sheet(shots, cw: 300, ch: 110, cols: 4, name: "crowd")
    }

    /// 많은 적(11명) — 주인공을 세워 두고 군중 자리만 본다(오른쪽 칸 끝 근처 · 왼쪽 가운데)
    @Test(.enabled(if: dump)) func crowdManyStrip() throws {
        var shots: [Shot] = []
        for hx in [150.0, 330.0] {
            let R = try NativeMoveStripTests.Rig(native: true)
            let sim = Sim(data: NativeMoveStripTests.base, seed: 9, config: Self.config()), w = sim.w
            for k in 0..<600 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); if w.state == "fight" && w.legT > 2 { break } }
            w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9; w.maxHP = 9999
            w.spawnWave(["punk", "gear", "triad", "pick", "punk", "gear", "triad", "punk", "gear", "pick", "triad"], fromDoors: false)
            for (k, a) in w.foes().enumerated() { a.x = hx + [30, 50, 70, 90, 110, 130, 150, 170, -40, -60, -80][k]; a.e!.hp = 999 }
            for k in 0..<(12 * 60) {
                w.hero.hs = 99; w.hero.x = hx; w.hp = 9999
                let ev = sim.step(), s = sim.snapshot
                _ = R.d.apply(ev, snapshot: s, now: Double(700 + k) / 60)
                let f = R.d.frame(s, dt: 1.0 / 60, now: Double(700 + k) / 60)
                if k >= 4 * 60 && k % 60 == 0 { shots.append(try Self.shot(R, s, f, cx: hx, cy: w.hero.y - 30, cw: 340, ch: 100, ds: 2, band: hx > 200 ? (255, 140, 40) : nil)) }
            }
        }
        try Self.sheet(shots, cw: 340, ch: 100, cols: 2, name: "crowd_many", scale: 1)
    }
}
