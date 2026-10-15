import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 눈 승강장(docs/10) 눈으로 보기(BB_DUMP=1 일 때만) → tools/js/out/stage/
///   snow_still.png : 게임 화면 틀(새 배치 — 무대가 화면 63% · 보이는 폭 198px) 그대로 3배 · 장면만
///   snow_pano.png  : 무대 전체 480×270 2배(층 · 시차 점검)
///   snow_fight.png : 싸움 띠 — 달리기 발 눈보라 · 미끄러져 서기 눈 뿌림 · 쓰러짐 눈 터짐(칸 위 띠: 주황 달리기 · 빨강 미끄러짐 · 흰 쓰러짐/충격)
@Suite(.serialized) struct SnowStripTests {
    typealias Strip = NativeMoveStripTests
    static let out = Strip.root.appending(path: "tools/js/out/stage")
    static let vw = 198

    static func config() -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.nativeSnow = true; c.playSpeed = 1; c.autoSpecial = true
        return c
    }

    /// 장면 텍스처 읽기
    static func render(_ R: Strip.Rig, _ s: SimSnapshot, _ f: StageFrame) throws -> [UInt8] {
        var rf = RenderFrame(stage: f, atlas: R.content.sprites)
        rf.applyHUD(R.d.hud.state, now: s.time)
        let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
        return try R.fr.readBack(R.tg.output(for: rf), queue: R.q)
    }
    /// 장면 [x0, x0+w) × [y0, y0+h) 를 scale 배 nearest 로
    static func crop(_ px: [UInt8], x0: Int, y0: Int, w: Int, h: Int) -> Strip.Shot {
        var o = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let sx = max(0, min(479, x0 + x)), sy = max(0, min(269, y0 + y)), si = (sy * 480 + sx) * 4, d = (y * w + x) * 4
            o[d] = px[si]; o[d + 1] = px[si + 1]; o[d + 2] = px[si + 2]; o[d + 3] = 255
        } }
        return Strip.Shot(px: o, band: nil)
    }

    final class Run {
        let R: Strip.Rig, sim: Sim
        var k = 0
        init() throws {
            R = try Strip.Rig(native: true); R.d.camera.visibleWidth = Double(SnowStripTests.vw)
            sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 11, config: SnowStripTests.config())
            for _ in 0..<30 { tick() }
            _ = sim.debugSnowJump()
        }
        var events: [SimEvent] = []
        /// 조용히(누르기 없음 — 입김 띠의 서 있기 줄)
        var quiet = false
        @discardableResult func tick() -> (SimSnapshot, StageFrame) {
            let ev = sim.step(k % 20 == 0 && !quiet ? [SimIntent.tap(side: k % 60 < 30 ? 1 : -1, at: sim.clock)] : []), s = sim.snapshot
            events = ev
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60); k += 1
            return (s, f)
        }
    }

    @Test(.enabled(if: Strip.dump)) func still() throws {
        let r = try Run()
        var best: (SimSnapshot, StageFrame)?
        for _ in 0..<(60 * 12) {
            let (s, f) = r.tick()
            if s.state == "fight", s.actors.filter({ $0.isEnemy && !$0.hidden }).count >= 2, r.k > 60 * 8 { best = (s, f); break }
        }
        let (s, f) = try #require(best)
        let px = try Self.render(r.R, s, f)
        let cx = Int(f.view.cameraX.rounded())
        try Strip.sheet([Self.crop(px, x0: cx, y0: 0, w: Self.vw, h: 270)], cw: Self.vw, ch: 270, cols: 1, name: "../stage/snow_still_1x")
        try NativeGuardStripTests.sheet([Self.crop(px, x0: cx, y0: 0, w: Self.vw, h: 270)], cw: Self.vw, ch: 270, cols: 1, name: "../stage/snow_still", scale: 3)
        try NativeGuardStripTests.sheet([Self.crop(px, x0: 0, y0: 0, w: 480, h: 270)], cw: 480, ch: 270, cols: 1, name: "../stage/snow_pano", scale: 2)
        // 바닥 눈 4배(난간 밑 ~ 앞 모서리) — BB_SNOW_TAG 가 있으면 이름 뒤에 붙인다(전 · 후 비교)
        let tag = ProcessInfo.processInfo.environment["BB_SNOW_TAG"].map { "_" + $0 } ?? ""
        try NativeGuardStripTests.sheet([Self.crop(px, x0: cx, y0: 168, w: Self.vw, h: 100)], cw: Self.vw, ch: 100, cols: 1, name: "../stage/snow_floor_zoom" + tag, scale: 4)
        if !tag.isEmpty { try NativeGuardStripTests.sheet([Self.crop(px, x0: cx, y0: 0, w: Self.vw, h: 270)], cw: Self.vw, ch: 270, cols: 1, name: "../stage/snow_still" + tag, scale: 3) }
        print("[snow] 층별 사각형 \(SnowArt.shared.layers().map { $0.rects.count })")
        print("[snow] 사각형 \(SnowArt.shared.rectCount) · 배경 정점 \(f.backMesh.count / 10) · 앞 정점 \(f.mesh.count / 10) · camX \(cx)")
    }

    @Test(.enabled(if: Strip.dump)) func fight() throws {
        let r = try Run()
        var rows: [String: [Strip.Shot]] = [:]
        var active: (String, Int, Double, Double)?   // 종류 · 남은 칸 · 초점 x · y
        var lastAnim = "", lastG: Double?, lastX = 0.0
        for _ in 0..<(60 * 70) {
            let (s, f) = r.tick()
            guard let H = s.actors.first(where: { $0.isHero }) else { continue }
            if active == nil {
                let running = H.pose.anim == "walk" && (H.pose.runU ?? -1) > s.gameTime
                let plant = running && lastG.map { floor($0 * 2) != floor((H.pose.gph ?? 0) * 2) } == true
                let knock = r.events.compactMap { e -> (Double, Double)? in
                    if case let .fx(k, x, y, _) = e, k == "dust" { return (x, y) }; if case let .groundImpact(x, y, _) = e { return (x, y) }; return nil }.first
                if plant && abs(H.x - lastX) > 1.2 && (rows["run"]?.count ?? 0) == 0 { active = ("run", 6, H.x, H.y) }
                else if H.pose.anim == "nv_skid" && lastAnim != "nv_skid" && (rows["skid"]?.count ?? 0) == 0 { active = ("skid", 6, H.x, H.y) }
                else if let k = knock, k.0 > f.view.cameraX + 30, k.0 < f.view.cameraX + f.view.visibleWidth - 30, (rows["fall"]?.count ?? 0) == 0 { active = ("fall", 6, k.0, k.1) }
            }
            lastAnim = H.pose.anim; lastG = H.pose.gph; lastX = H.x
            if var a = active {
                if a.0 != "fall" { a.2 = H.x }
                let px = try Self.render(r.R, s, f)
                let cx = f.view.cameraX, x0 = max(Int(cx), min(Int(cx + f.view.visibleWidth) - 100, Int(a.2) - 50))
                var sh = Self.crop(px, x0: x0, y0: Int(a.3) - 72, w: 100, h: 90)
                sh.band = a.0 == "run" ? (255, 150, 40) : a.0 == "skid" ? (230, 60, 50) : (240, 240, 240)
                rows[a.0, default: []].append(sh)
                a.1 -= 1; active = a.1 > 0 ? a : nil
                for _ in 0..<3 { r.tick() }
            }
            if rows.count == 3 && active == nil { break }
        }
        print("[snow fight] " + rows.map { "\($0.key) \($0.value.count)" }.joined(separator: " · "))
        let shots = ["run", "skid", "fall"].flatMap { rows[$0] ?? [] }
        try NativeGuardStripTests.sheet(shots, cw: 100, ch: 90, cols: 6, name: "../stage/snow_fight", scale: 3)
    }
}

extension SnowStripTests {
    /// 눈 효과 계기(발자국 · 입자 수 · 걷기 위상) — 점검용 출력
    @Test(.enabled(if: Strip.dump)) func counters() throws {
        let r = try Run()
        var maxMarks = 0, maxParts = 0, gphSeen = 0, runSeen = 0, skids = 0, anims: [String: Int] = [:]
        for _ in 0..<(60 * 30) {
            let (s, _) = r.tick()
            maxMarks = max(maxMarks, r.R.d.snow.marks.count); maxParts = max(maxParts, r.R.d.snow.parts.count)
            if let H = s.actors.first(where: { $0.isHero }) { if H.pose.gph != nil { gphSeen += 1 }; if (H.pose.runU ?? -1) > s.gameTime { runSeen += 1; anims[H.pose.anim, default: 0] += 1 }; if H.pose.anim == "nv_skid" { skids += 1 } }
        }
        print("[snow counters] 자국 최대 \(maxMarks) · 입자 최대 \(maxParts) · gph 틱 \(gphSeen) · runU 틱 \(runSeen) · 미끄러짐 틱 \(skids) · 질주 중 동작 \(anims)")
    }
}

extension SnowStripTests {
    /// 카메라 자리 셋(왼쪽 끝 · 가운데 · 오른쪽 끝) — 시차 층이 어디서나 깊이를 보이는지
    @Test(.enabled(if: Strip.dump)) func views() throws {
        let r = try Run()
        for _ in 0..<(60 * 3) { r.tick() }
        var shots: [Strip.Shot] = []
        for hx in [30.0, 240, 450] {
            var last: (SimSnapshot, StageFrame)?
            for _ in 0..<150 { r.sim.w.hero.x = hx; r.sim.w.maxHP = 9999; r.sim.w.hp = 9999; for e in r.sim.w.foes() { e.x = hx + (hx > 240 ? -40 : 40); e.e?.stun = 1 }; last = r.tick() }
            let (s, f) = last!
            let px = try Self.render(r.R, s, f)
            shots.append(Self.crop(px, x0: Int(f.view.cameraX.rounded()), y0: 0, w: Self.vw, h: 270))
        }
        try NativeGuardStripTests.sheet(shots, cw: Self.vw, ch: 270, cols: 3, name: "../stage/snow_views", scale: 2)
    }
}

extension SnowStripTests {
    /// 입김 띠(6배 · 입가) — 두 번째 연출기에 그 인물만 넣어(장면은 멈춘 채 시계만 흐른다) 다른 인물 · 타격 번쩍임 없이 본다
    ///   1줄 서 있기 숨(가로등 밑 · 0.1초 간격) · 2줄 같은 숨(가로등 사이 어둠) · 3줄 달리기 짧은 김(두 발 디딤마다) · 4줄 연타 끝 헐떡임(0.25초 간격 2초)
    @Test(.enabled(if: Strip.dump)) func breath() throws {
        let r = try Run()
        let R2 = try Strip.Rig(native: true); R2.d.camera.visibleWidth = Double(Self.vw)
        var rows: [String: [Strip.Shot]] = [:]
        var k2 = 0
        func feed(_ s: SimSnapshot, _ ev: [SimEvent]) -> (SimSnapshot, StageFrame) {
            _ = R2.d.apply(ev, snapshot: s, now: Double(k2) / 60)
            let f = R2.d.frame(s, dt: 1.0 / 60, now: Double(k2) / 60); k2 += 1
            return (s, f)
        }
        func shot(_ px: [UInt8], _ A: SimSnapshot.ActorView, band: (UInt8, UInt8, UInt8)) -> Strip.Shot {
            let fl: Double = A.flip ? -1 : 1
            var sh = Self.crop(px, x0: Int(A.x + fl * 18) - 21, y0: Int(A.y) - 52, w: 42, h: 26)
            sh.band = band
            return sh
        }
        func fresh(_ id: ActorID) -> Bool { R2.d.snow.breaths.contains { $0.id == id && $0.age < 0.02 } }
        // 1) 싸움을 돌려 서 있는 적 하나(자세 · 생김새)와 그때 장면을 얻는다
        var idleView: SimSnapshot.ActorView?, idleBase: SimSnapshot?
        for _ in 0..<(60 * 90) {
            let (s0, _) = r.tick()
            if let E = s0.actors.first(where: { $0.isEnemy && !$0.hidden && $0.pose.anim == "idle" && !$0.flip }) { idleView = E; idleBase = s0; break }
        }
        // 2) 서 있기: 서 있는 적을 둘 복제 — 가로등 밑(밝다) · 가로등 사이(어둡다)
        if var E = idleView, let base = idleBase {
            var lit = 0, dark = 0
            for i in 0..<(60 * 14) {
                var s = base; s.gameTime += Double(i) / 60; s.time += Double(i) / 60; s.combo = 0
                E.id = 9001; E.x = SnowGeo.lamps[1] - 4; E.y = 222; E.hp = 10; E.hidden = false
                var D = E; D.id = 9002; D.x = SnowGeo.lamps[1] - 70
                s.actors = [E, D]
                let (s2, f2) = feed(s, [])
                if lit == 0 && rows["idle"] == nil && fresh(9001) { lit = 8 }
                if dark == 0 && rows["dark"] == nil && fresh(9002) { dark = 8 }
                if (lit > 0 || dark > 0) && (lit == 8 || dark == 8 || i % 6 == 0) {
                    let px = try Self.render(R2, s2, f2)
                    if lit > 0 { rows["idle", default: []].append(shot(px, E, band: (255, 200, 120))); lit -= 1 }
                    if dark > 0 { rows["dark", default: []].append(shot(px, D, band: (90, 110, 200))); dark -= 1 }
                }
                if rows["idle"]?.count == 8 && rows["dark"]?.count == 8 { break }
            }
            // 3) 달리기: 주인공을 가로등 사이 → 밑으로 달리게 한다(질주 걸음 — 보폭 위상 66px 에 한 바퀴 · 두 발 디딤마다 김)
            if var H = base.actors.first(where: { $0.isHero }) {
                H.x = 150; H.flip = false; H.hidden = false
                var g = 0.0, left = 0
                for i in 0..<(60 * 4) {
                    var s = base; s.gameTime += 20 + Double(i) / 60; s.time += 20 + Double(i) / 60; s.combo = 0
                    H.x += 96.0 / 60; g += 96.0 / 60 / 66
                    H.pose.anim = "walk"; H.pose.runU = s.gameTime + 9; H.pose.legRun = true; H.pose.gph = g
                    s.actors = [H]
                    let (s2, f2) = feed(s, [])
                    if left == 0 && rows["run"] == nil && H.x > 200 && fresh(H.id) { left = 8 }
                    if left > 0 && (left == 8 || i % 4 == 0) { rows["run", default: []].append(shot(try Self.render(R2, s2, f2), H, band: (255, 150, 40))); left -= 1 }
                    if rows["run"]?.count == 8 { break }
                }
                // 4) 연타 끝 헐떡임: 같은 주인공을 가로등 밑에 서 있게(서 있는 자세) 두고 연타 끝(comboEnded)을 넣는다 → 0.25초 간격 2초
                H.pose = E.pose; H.x = SnowGeo.lamps[0] + 2; H.flip = false
                for i in 0..<(60 * 3) {
                    var s = base; s.gameTime += 40 + Double(i) / 60; s.time += 40 + Double(i) / 60; s.combo = 0
                    s.actors = [H]
                    let (s2, f2) = feed(s, i == 20 ? [.comboEnded(count: 5, total: 5)] : [])
                    if i >= 20 && (i - 20) % 15 == 0 && (rows["pant"]?.count ?? 0) < 8 { rows["pant", default: []].append(shot(try Self.render(R2, s2, f2), H, band: (240, 120, 200))) }
                }
            }
        }
        print("[snow breath] " + rows.map { "\($0.key) \($0.value.count)" }.joined(separator: " · "))
        let shots = ["idle", "dark", "run", "pant"].flatMap { rows[$0] ?? [] }
        try NativeGuardStripTests.sheet(shots, cw: 42, ch: 26, cols: 8, name: "../stage/snow_breath", scale: 6)
    }
}
