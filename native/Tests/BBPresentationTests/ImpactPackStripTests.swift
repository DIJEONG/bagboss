import Testing
import Foundation
import BBCore
import BBContent
import BBAnim
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 타격감 묶음 띠(BB_DUMP=1 — docs/11) → tools/js/out/fx/
///   ko_finisher.png      실전 지하철 판 마지막 적 처치 — 처치 앞 0.05초 ~ 1.9초 시간 순(보이는 화면 그대로 · HUD 포함). 띠 노랑 슬로 · 빨강 정지 · 파랑 한 박자 · 회색 복귀
///   counter_punchin.png  받아치기 · 치명 펀치인 — 윗줄 보이는 화면(줌 · 기울기) · 아랫줄 맞은 몸 3배(찌그러짐), 1칸 = 1/60초
///   footdust_floors.png  객차 · 승강장(건널목) · 무도장 · 타워 · 눈 — 질주 디딤 → 미끄러져 서기 → 돌아서기 → 착지(3배)
///   heat_flash.png       무거운 타격 열기 + 불티 — 윗줄 보통 · 아랫줄 번쩍임 줄이기(4배)
@Suite(.serialized) struct ImpactPackStripTests {
    typealias Strip = NativeMoveStripTests
    static let vw = 198

    /// 보이는 화면 전체(장면 + HUD — 앱과 같은 크롭 · 줌 · 기울기) — 장면 해상도 칸
    static func view(_ R: Strip.Rig, _ s: SimSnapshot, _ f: StageFrame, band: (UInt8, UInt8, UInt8)?) throws -> Strip.Shot {
        var rf = RenderFrame(stage: f, atlas: R.content.sprites)
        rf.applyHUD(R.d.hud.state, now: s.time)
        let F = R.d.hud.frame(s, view: f.view, shake: f.shake)
        let list = HUDOverlay.build(R.d.hud.state, F, art: R.art)
        let ui = try R.ov.render(list, atlas: R.art.atlas, queue: R.q)
        let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
        let scene = try R.fr.readBack(R.tg.output(for: rf), queue: R.q)
        let W = list.width, Hh = list.height, v = f.view
        let cw = vw, ch = 270
        var px = [UInt8](repeating: 255, count: cw * ch * 4)
        for y in 0..<ch { for x in 0..<cw {
            // 장면: 보이는 뷰 점 → 무대(blitFS 와 같은 식 — 줌 · 기울기)
            let vp = SIMD2((Double(x) + 0.5) / Double(cw), (Double(y) + 0.5) / Double(ch))
            let sp = v.toScene(vp)
            let sx = max(0, min(479, Int(sp.x))), sy = max(0, min(269, Int(sp.y))), si = (sy * 480 + sx) * 4
            let ux = min(W - 1, Int(vp.x * Double(W))), uy = min(Hh - 1, Int(vp.y * Double(Hh))), o = (uy * W + ux) * 4
            let a = Double(ui[o + 3]) / 255, d = (y * cw + x) * 4
            for c in 0..<3 { px[d + c] = UInt8(min(255, Double(scene[si + c]) * (1 - a) + Double(ui[o + c]) * a)) }
        } }
        return Strip.Shot(px: px, band: band)
    }

    static func config(stage: Int = 0) -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.nativeGuard = true; c.playSpeed = 1; c.stage = stage
        return c
    }

    final class Live {
        let R: Strip.Rig, sim: Sim
        var k = 0
        var events: [SimEvent] = []
        init(seed: UInt32) throws {
            R = try Strip.Rig(native: true); R.d.camera.visibleWidth = Double(ImpactPackStripTests.vw)
            sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: seed, config: ImpactPackStripTests.config())
        }
        @discardableResult func tick(low: Bool = false) -> (SimSnapshot, StageFrame) {
            if low && k % 90 == 0 { sim.debugLowFoes(8) }
            let ev = sim.step(k % 20 == 0 ? [SimIntent.tap(side: k % 60 < 30 ? 1 : -1, at: sim.clock)] : []), s = sim.snapshot
            events = ev
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60); k += 1
            return (s, f)
        }
    }

    @Test(.enabled(if: Strip.dump)) func koFinisher() throws {
        let L = try Live(seed: 31)
        // 처치 앞 3틱을 늘 쥐고 간다
        var ring: [(SimSnapshot, StageFrame)] = []
        var fire: KOFinisher?
        for _ in 0..<(60 * 120) {
            let r = L.tick(low: true); ring.append(r); if ring.count > 4 { ring.removeFirst() }
            if let K = L.events.compactMap({ if case .koFinisher(let K) = $0 { return K }; return nil }).first { fire = K; break }
        }
        guard fire != nil else { Issue.record("KO 마무리 없음"); return }
        var shots: [Strip.Shot] = [try Self.view(L.R, ring[0].0, ring[0].1, band: (90, 90, 90))]
        let times = [0.0, 0.1, 0.2, 0.3, 0.4, 0.45, 0.55, 0.7, 0.9, 1.1, 1.3, 1.5, 1.7, 1.9]
        var ti = 0
        let t0 = L.k - 1
        if let last = ring.last { shots.append(try Self.view(L.R, last.0, last.1, band: (240, 200, 60))); ti = 1 }
        while ti < times.count {
            let (s, f) = L.tick()
            let u = Double(L.k - 1 - t0) / 60
            guard u >= times[ti] - 1e-6 else { continue }
            let band: (UInt8, UInt8, UInt8) = u < 0.4 ? (240, 200, 60) : u < 0.48 ? (230, 70, 60) : u < 1.38 ? (90, 140, 230) : (150, 150, 150)
            shots.append(try Self.view(L.R, s, f, band: band)); ti += 1
        }
        try NativeGuardStripTests.sheet(shots, cw: Self.vw, ch: 270, cols: 8, name: "../fx/ko_finisher", scale: 1)
    }

    @Test(.enabled(if: Strip.dump)) func counterPunchIn() throws {
        let L = try Live(seed: 23)
        var found: (ActorID, Int)?
        for _ in 0..<(60 * 90) {
            L.tick()
            for case let .hit(h) in L.events where h.attackerIsHero && (h.counter || h.crit) && !h.dead && L.R.d.feel.punch != nil && L.R.d.feel.ko == nil {
                found = (h.target, L.k - 1)
            }
            if found != nil { break }
        }
        guard let (tid, _) = found else { Issue.record("받아치기 · 치명 없음"); return }
        var top: [Strip.Shot] = [], bot: [Strip.Shot] = []
        let s0 = L.sim.snapshot
        for i in 0..<16 {
            let (s, f): (SimSnapshot, StageFrame)
            if i == 0 { s = s0; f = L.R.d.frame(s0, dt: 0, now: Double(L.k) / 60) } else { (s, f) = L.tick() }
            let band: (UInt8, UInt8, UInt8) = i < 2 ? (240, 90, 60) : i < 5 ? (240, 200, 60) : (120, 120, 120)
            print(String(format: "[punch] %d 줌 %.3f 기울기 %.2f° 찌그러짐 %.2f", i, f.view.zoom, f.view.roll * 180 / .pi, L.R.d.feel.squash[tid].map { ImpactFeel.squashAmt(L.R.d.feel.t - $0.t) } ?? 0))
            if i % 2 == 0 || i < 6 {
                top.append(try Self.view(L.R, s, f, band: band))
                let T = s.actors.first { $0.id == tid } ?? s.actors.first { $0.isHero }!
                let px = try SnowStripTests.render(L.R, s, f)
                var sh = SnowStripTests.crop(px, x0: Int(T.x) - 30, y0: Int(T.y) - 62, w: 60, h: 66); sh.band = band
                bot.append(sh)
            }
        }
        try NativeGuardStripTests.sheet(top, cw: Self.vw, ch: 270, cols: top.count, name: "../fx/counter_punchin", scale: 1)
        try NativeGuardStripTests.sheet(bot, cw: 60, ch: 66, cols: bot.count, name: "../fx/counter_punchin_body", scale: 3)
    }

    /// 주인공만 남긴 무대에서 질주 → 미끄러짐 → 돌아서기 → 점프 착지를 흉내(스냅숏을 직접 민다)
    static func dustRow(_ kind: String) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = 198
        var c = SimConfig(); c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1
        if kind == "tower" { c.mode = .tower } else if kind != "car" { c.mode = .dojo }
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 5, config: c)
        if kind == "cross" || kind == "snow" { sim.apply(.dojo(.background(kind))) }
        for k in 0..<120 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        var base = sim.snapshot
        guard var H = base.actors.first(where: { $0.isHero }) else { return [] }
        let floorY = H.y
        H.x = 150; H.flip = false
        base.actors = [H]
        var shots: [Strip.Shot] = []
        let band: (UInt8, UInt8, UInt8) = kind == "car" ? (150, 160, 175) : kind == "cross" ? (130, 130, 130) : kind == "dojo" ? (190, 130, 70) : kind == "tower" ? (100, 100, 110) : (200, 225, 255)
        var x = 150.0, gph = 0.0, air = 0.0, vy = 0.0
        for i in 0..<96 {
            var s = base; s.gameTime += Double(i) / 60; s.time += Double(i) / 60
            var A = H
            if i < 36 { x += 2.5; gph += 2.5 / 48; A.pose = ActorPose(anim: "walk", pose: "st0"); A.pose.runU = s.gameTime + 1; A.pose.gph = gph }   // 질주
            else if i < 48 { x += 2.5 * Double(48 - i) / 12; A.pose = ActorPose(anim: "nv_skid", pose: "nv_skid0") }                                   // 미끄러져 서기
            else if i < 52 { A.pose = ActorPose(anim: "nv_skidEnd", pose: "nv_skid1") }
            else if i < 60 { A.pose = ActorPose(anim: "idle", pose: "st0"); A.flip = i >= 54 }                                                       // 돌아서기
            else {                                                                                                                             // 제자리 점프 → 착지
                if i == 62 { vy = -150 }
                vy += 600 / 60; air = max(0, air - vy / 60); if air == 0 { vy = 0 }
                A.flip = true; A.pose = ActorPose(anim: "idle", pose: "st0"); A.airOv = air
            }
            A.x = x; A.y = floorY
            s.actors = [A]
            _ = R.d.apply([], snapshot: s, now: 3 + Double(i) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: 3 + Double(i) / 60)
            guard [6, 14, 22, 30, 37, 40, 44, 50, 55, 58, 66, 74, 80, 86].contains(i) else { continue }
            if i == 40 { print("[footdust] \(kind) 먼지 \(R.d.feel.dust.puffs.count) · 정점 \(R.d.feel.dust.mesh().count / 10)") }
            let px = try SnowStripTests.render(R, s, f)
            var sh = SnowStripTests.crop(px, x0: Int(x) - 34, y0: Int(floorY) - 40, w: 68, h: 46)
            if kind == "dojo" || kind == "cross" || kind == "tower" { for j in sh.px.indices where j % 4 != 3 { sh.px[j] = UInt8(min(255, Double(sh.px[j]) * 1.5)) } }
            sh.band = band
            shots.append(sh)
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func footDust() throws {
        var shots: [Strip.Shot] = []
        for k in ["car", "cross", "dojo", "tower", "snow"] { let r = try Self.dustRow(k); print("[footdust] \(k) \(r.count)"); shots += r }
        try NativeGuardStripTests.sheet(shots, cw: 68, ch: 46, cols: 14, name: "../fx/footdust_floors", scale: 3)
        // 확대(발밑 6배 — 질주 디딤 · 미끄러짐 칸만)
        let zoom = shots.enumerated().filter { [2, 3, 5, 6].contains($0.offset % 14) }.map { sh -> Strip.Shot in
            var o = [UInt8](repeating: 0, count: 40 * 16 * 4)
            for y in 0..<16 { for x in 0..<40 { let si = ((y + 28) * 68 + x + 4) * 4, d = (y * 40 + x) * 4; for c in 0..<4 { o[d + c] = sh.element.px[si + c] } } }
            return Strip.Shot(px: o, band: sh.element.band)
        }
        try NativeGuardStripTests.sheet(zoom, cw: 40, ch: 16, cols: 4, name: "../fx/footdust_zoom", scale: 8)
    }

    @Test(.enabled(if: Strip.dump)) func heatFlash() throws {
        var shots: [Strip.Shot] = []
        for noFlash in [false, true] {
            let L = try Live(seed: 7)
            L.R.d.hud.noFlash = noFlash
            var s = L.sim.snapshot
            for _ in 0..<(60 * 8) { (s, _) = L.tick(); if s.actors.contains(where: { $0.isEnemy && $0.hp > 0 && !$0.hidden }) && s.state == "fight" { break } }
            for _ in 0..<40 { (s, _) = L.tick() }
            guard var H = s.actors.first(where: { $0.isHero }), var T = s.actors.first(where: { $0.isEnemy && $0.hp > 0 && !$0.hidden }) else { Issue.record("적 없음"); return }
            H.x = 200; H.flip = false; T.x = 226; T.flip = true; T.pose = ActorPose(anim: "idle", pose: "st0")
            var base = s; base.actors = [H, T]
            var h = HitInfo(attacker: H.id, target: T.id, damage: 30, reaction: "hit"); h.knock = true; h.attackerIsHero = true; h.dir = 1; h.attackerAnim = "kick"
            let times = [0.0, 0.02, 0.05, 0.08, 0.12, 0.16, 0.2, 0.28, 0.4, 0.55]
            var ti = 0
            for i in 0..<40 {
                var q = base; q.gameTime += Double(i) / 60; q.time += Double(i) / 60
                _ = L.R.d.apply(i == 0 ? [.hit(h)] : [], snapshot: q, now: 100 + Double(i) / 60)
                let f = L.R.d.frame(q, dt: 1.0 / 60, now: 100 + Double(i) / 60)
                guard ti < times.count, Double(i) / 60 >= times[ti] - 1e-6 else { continue }
                ti += 1
                let px = try SnowStripTests.render(L.R, q, f)
                var sh = SnowStripTests.crop(px, x0: Int(T.x) - 24, y0: Int(T.y) - 70, w: 48, h: 74)
                sh.band = noFlash ? (120, 120, 160) : (240, 120, 50)
                shots.append(sh)
            }
        }
        try NativeGuardStripTests.sheet(shots, cw: 48, ch: 74, cols: 10, name: "../fx/heat_flash", scale: 4)
    }
}
