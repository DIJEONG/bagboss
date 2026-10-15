import Testing
import Foundation
import BBCore
import BBContent
import BBAnim
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 잡아 메치기 · 저먼 수플렉스 · 공중 잡아 꽂기 · 종착역 눈으로 보기(BB_DUMP=1 일 때만) → tools/js/out/moves/throw_<이름>_<태그>.png
///   무도장 단독 시연 — 허수아비를 **보이게** 둔다(잡힌 몸이 손 · 엉덩이를 따라가는지가 점검 대상). 2틱 간격 · 장면 픽셀 3배(UI 해상도).
///   띠: 회색 = 잡기 동작 중 · 주황 = 잡혀 있음(heldBy) · 흰색 = 큐(잡는 칸) · 빨강 = 놓는(꽂는) 틱 · 없음 = 앞뒤
///   태그: BB_THROW_TAG(기본 after) · 깃발: BB_THROW_NV=0 이면 깃발 꺼짐(웹 기준선)
///   수치 → throw_trace_<태그>.txt: 틱마다 손 ↔ 잡힌 몸통 거리(두 손) · 몸통끼리 거리 · 잡힌 골반 이동량(튐) · 몸 기울기
@Suite(.serialized) struct NativeThrowStripTests {
    typealias Strip = NativeMoveStripTests
    typealias G = NativeGuardStripTests
    static var tag: String { ProcessInfo.processInfo.environment["BB_THROW_TAG"] ?? "after" }
    static var nv: Bool { ProcessInfo.processInfo.environment["BB_THROW_NV"] != "0" }
    static let grabAnims: Set<String> = ["throw", "suplex", "spcHold", "spcLift", "spcSlam"]

    /// 선분 AB 와 점 P 거리
    static func segDist(_ P: SIMD2<Double>, _ A: SIMD2<Double>, _ B: SIMD2<Double>) -> Double {
        let d = B - A, l2 = (d * d).sum()
        let t = l2 > 0 ? max(0, min(1, ((P - A) * d).sum() / l2)) : 0
        let q = A + d * t - P; return (q * q).sum().squareRoot()
    }
    static func segSeg(_ A: SIMD2<Double>, _ B: SIMD2<Double>, _ C: SIMD2<Double>, _ D: SIMD2<Double>) -> Double {
        var m = Double.infinity
        for k in 0...8 { let t = Double(k) / 8; m = min(m, segDist(A + (B - A) * t, C, D), segDist(C + (D - C) * t, A, B)) }
        return m
    }

    struct Probe { var gapF = 0.0, gapB = 0.0, torso = 0.0, hips = SIMD2<Double>(0, 0), ang = 0.0, head = SIMD2<Double>(0, 0), hF = SIMD2<Double>(0, 0), hB = SIMD2<Double>(0, 0), neck = SIMD2<Double>(0, 0), hHips = SIMD2<Double>(0, 0) }
    /// 그린 관절 → 장면 좌표
    static func probe(_ R: Strip.Rig, _ s: SimSnapshot, hero: ActorID, foe: ActorID) -> Probe? {
        guard let a = s.actors.first(where: { $0.id == hero }), let b = s.actors.first(where: { $0.id == foe }),
              let ja = R.d.characters.drawnJoints(hero), let jb = R.d.characters.drawnJoints(foe) else { return nil }
        func W(_ v: SimSnapshot.ActorView, _ p: SIMD2<Double>) -> SIMD2<Double> { SIMD2(v.x + (v.flip ? -1 : 1) * p.x, v.y + p.y) }
        let hA = W(a, ja.hips), nA = W(a, ja.neck), hB = W(b, jb.hips), nB = W(b, jb.neck), headB = W(b, jb.head)
        var p = Probe()
        p.gapF = segDist(W(a, ja.handF), hB, headB); p.gapB = segDist(W(a, ja.handB), hB, headB)
        p.torso = segSeg(hA, nA, hB, nB); p.hips = hB; p.head = headB; p.neck = nB; p.hF = W(a, ja.handF); p.hB = W(a, ja.handB); p.hHips = hA
        let up = nB - hB; p.ang = atan2(up.x, -up.y) * 180 / .pi
        return p
    }

    /// 한 시연: 잡기 동작 앞 2칸 ~ 끝 뒤 tail 틱까지 step 틱마다
    func run(_ cmd: DojoCommand, native: Bool, step: Int = 2, tail: Int = 36, cw: Int = 210, ch: Int = 200, ds: Int = 2, setup: ((World) -> Void)? = nil) throws -> (shots: [Strip.Shot], zoom: [Strip.Shot], trace: [String]) {
        let R = try Strip.Rig(native: native)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = native; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: native), seed: 3, config: c)
        sim.apply(.dojo(.zoom(2)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        var shots: [Strip.Shot] = [], pre: [Strip.Shot] = [], trace: [String] = [], zoom: [Strip.Shot] = [], zpre: [Strip.Shot] = [], zleft = 0
        var started = false, left = tail, wasHeld = false, prevHips: SIMD2<Double>?
        for k in 40..<(40 + 60 * 9) {
            if k == 41 { setup?(sim.w); sim.apply(.dojo(cmd)) }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard let H = w.hero, let D = w.dojoDummy() else { continue }
            let on = Self.grabAnims.contains(H.anim), held = D.heldBy != nil || (D.anim == "held" && on)
            if on { started = true; left = tail } else if started { left -= 1 }
            if started && left <= 0 { break }
            let pr = Self.probe(R, s, hero: H.id, foe: D.id)
            let release = wasHeld && !held
            if let pr, started || on {
                let dh = prevHips.map { pr.hips - $0 } ?? .zero
                trace.append(String(format: "%4d %-8@ %-9@ | %-8@ %-6@ %@ dx %6.1f air %5.1f | 손F %5.1f 손B %5.1f 몸통 %5.1f | 골반 (%6.1f,%6.1f) Δ %5.1f 기울기 %6.1f%@",
                                    k, H.anim, H.pose, D.anim, D.pose, held ? "잡힘" : "    ", (D.x - H.x) * H.f, D.airOv, pr.gapF, pr.gapB, pr.torso,
                                    pr.hips.x, pr.hips.y, (dh * dh).sum().squareRoot(), pr.ang, release ? "  ← 놓음" : "")
                             + String(format: "  [손 (%.0f,%.0f)(%.0f,%.0f) 골반H (%.0f,%.0f) 피 목 (%.0f,%.0f) 머리 (%.0f,%.0f)]", pr.hF.x, pr.hF.y, pr.hB.x, pr.hB.y, pr.hHips.x, pr.hHips.y, pr.neck.x, pr.neck.y, pr.head.x, pr.head.y))
            }
            if let pr { prevHips = pr.hips }
            wasHeld = held
            let cue = w.data.jwCue[H.anim]
            let band: (UInt8, UInt8, UInt8)? = release ? (230, 60, 50) : !on ? nil : H.pose == cue ? (255, 255, 255) : held ? (255, 150, 40) : (120, 120, 140)
            // 확대(장면 픽셀 · HUD 없음): 잡기 3틱 전 ~ 놓은 뒤 24틱, 매 틱 아닌 2틱마다
            if held || release { zleft = 24 } else if zleft > 0 { zleft -= 1 }
            if (k - 41) % 2 == 0 || release {
                let zx = Int((H.x + D.x) / 2), zy = Int(H.y - 34)
                var z = try NativeRiseStripTests.scenePx(R, s, f, cx: zx, cy: zy, cw: 96, ch: 84); z.band = band
                for i in z.px.indices where i % 4 != 3 { z.px[i] = UInt8(min(255, Double(z.px[i]) * 1.8)) }
                if held || release || zleft > 0 { if zoom.isEmpty { zoom += zpre }; zoom.append(z) } else if zoom.isEmpty { zpre.append(z); if zpre.count > 2 { zpre.removeFirst() } }
            }
            let take = (k - 41) % step == 0 || release
            guard take else { continue }
            let cx = (H.x + D.x) / 2, cy = H.y - 40
            var sh = try G.shot(R, s, f, cx: cx, cy: cy, cw: cw, ch: ch, ds: ds, band: band)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.8)) }   // 어두운 무도장에서 검은 양복이 보이게
            if started { shots.append(sh) } else { pre.append(sh); if pre.count > 2 { pre.removeFirst() } }
            if started && shots.count == 1 { shots.insert(contentsOf: pre, at: 0) }
        }
        return (shots, zoom, trace)
    }

    static let cases: [(String, DojoCommand)] = [
        ("throw", .hero("throw", combo: nil)), ("suplex", .hero("suplex", combo: nil)),
        ("airthrow", .combo(15)), ("grap", .special("grap")),
    ]

    @Test(.enabled(if: Strip.dump)) func throwStrips() throws {
        var all: [String] = []
        for (name, cmd) in Self.cases {
            let r = try run(cmd, native: Self.nv, step: 3, tail: 30)
            try G.sheet(r.shots, cw: 210, ch: 200, cols: 10, name: "../moves/throw_\(name)_\(Self.tag)")
            try G.sheet(r.zoom, cw: 96, ch: 84, cols: 10, name: "../moves/throw_\(name)_\(Self.tag)_zoom", scale: 3)
            all.append("== \(name) (\(Self.nv ? "깃발 켜짐" : "깃발 꺼짐")) ==")
            all += r.trace
        }
        let url = G.out.appending(path: "../moves/throw_trace_\(Self.tag).txt")
        try all.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: 벽꿍(객차 끝 벽 · 타워 벽 · 눈 승강장 끝)

    /// 실전 판에서 벽 앞 22px 에 선 주인공이 벽 쪽 적을 메친다(back = 수플렉스로 뒤 벽에) — 장면 픽셀 3배(HUD 없음) · 2틱마다
    func wallRun(_ kind: String, back: Bool = false) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = 198
        var c = Strip.config(true); c.nativeSnow = kind == "snow"; if kind == "tower" { c.mode = .tower }
        let sim = Sim(data: Strip.base, seed: 7, config: c), w = sim.w
        var k = 0
        func tick() -> (SimSnapshot, StageFrame) { let ev = sim.step(), s = sim.snapshot; _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60); let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60); k += 1; return (s, f) }
        for _ in 0..<30 { _ = tick() }
        if kind == "snow" { _ = sim.debugSnowJump() }
        while k < 60 * 40, !(w.state == "fight" && w.legT > 1.5 && w.hero != nil && w.canAct(w.hero!)) { _ = tick() }
        guard let H = w.hero else { return [] }
        w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9; w.maxHP = 9999; w.hp = 9999
        w.spawnWave(["punk"], fromDoors: false)
        guard let F = w.foes().first else { return [] }
        let W = w.AW1()
        H.flip = back; H.x = back ? W - 18 : W - 22; F.x = back ? H.x - 18 : H.x + 18; F.flip = !back; F.e!.hp = 999; w.setAnim(H, "idle"); w.setAnim(F, "idle")
        let id = back ? "suplex" : "throw"
        w.bag = [Item(id: id, uid: 905, tier: 1, opt: nil)]; w.bag[0].x = 0; w.bag[0].y = 0; w.renderBag(); w.bag[0].t = 99
        w.useSkill(0, F, true)
        var shots: [Strip.Shot] = [], n = 0, seen = false
        while n < 150 {
            let (s, f) = tick(); n += 1
            if F.nvHold?.phase == "arc" { seen = true }   // 호(휘두름 · 넘기기)부터
            if seen && n % 6 == 0 { print("  \(kind) n\(n) H \(Int(H.x)) \(H.anim)/\(H.pose) F \(Int(F.x)) a\(Int(F.airOv)) j\(Int(F.jug?.h ?? -1)) \(F.anim)/\(F.pose) \(F.nvHold?.phase ?? "-")") }
            guard seen, n % 3 == 0 else { continue }
            let cx = Int((W - 28).rounded()), cy = Int(H.y - 34)
            var sh = try NativeRiseStripTests.scenePx(R, s, f, cx: cx, cy: cy, cw: 110, ch: 84)
            if kind != "car" { for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.5)) } }
            sh.band = F.nvHold?.phase == "wall" ? (230, 60, 50) : F.heldBy != nil ? (255, 150, 40) : (120, 120, 140)
            shots.append(sh)
            if shots.count >= 20 { break }   // 호 → 벽꿍 → 미끄러짐 → 착지 ~ 일어나기
        }
        print("[wall] \(kind) walls \(w.stats.walls) hero x \(H.x) foe x \(F.x) W \(W)")
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func wallStrips() throws {
        var all: [Strip.Shot] = []
        for (kind, back) in [("car", false), ("tower", false), ("snow", false), ("car", true)] { let r = try wallRun(kind, back: back); all += r; while all.count % 10 != 0 { all.append(Strip.Shot(px: [UInt8](repeating: 24, count: 110 * 84 * 4), band: nil)) } }
        try G.sheet(all, cw: 110, ch: 84, cols: 10, name: "../moves/throw_wall_\(Self.tag)_zoom", scale: 3)
    }

    /// 벽꿍 자국만(주인공만 남긴 정지 장면에 fx 'wallImpact' 를 넣는다) — 객차 · 무도장 · 타워 · 눈, 0 · 0.05 · 0.15 · 0.4 · 0.9 · 1.6초, 장면 픽셀 4배
    @Test(.enabled(if: Strip.dump)) func wallDecal() throws {
        var shots: [Strip.Shot] = []
        for kind in ["car", "dojo", "tower", "snow"] {
            let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = 198
            var c = Strip.config(true); c.nativeSnow = kind == "snow"; if kind == "tower" { c.mode = .tower }; if kind == "dojo" { c.mode = .dojo }
            let sim = Sim(data: Strip.base, seed: 7, config: c), w = sim.w
            for k in 0..<90 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
            if kind == "snow" { _ = sim.debugSnowJump(); for k in 0..<240 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) } }
            var base = sim.snapshot
            base.actors = base.actors.filter { $0.isHero }
            guard var H = base.actors.first else { continue }
            let W = w.AW1(); H.x = W - 40; H.flip = false; base.actors = [H]
            let iy = H.y - 22
            let times = [0.0, 0.05, 0.15, 0.4, 0.9, 1.6]
            var ti = 0
            for i in 0..<(60 * 2) {
                var s = base; s.gameTime += Double(i) / 60; s.time += Double(i) / 60
                let ev: [SimEvent] = i == 0 ? [.fx(kind: "wallImpact", x: W, y: iy, dir: 1)] : []
                _ = R.d.apply(ev, snapshot: s, now: 2 + Double(i) / 60)
                let f = R.d.frame(s, dt: 1.0 / 60, now: 2 + Double(i) / 60)
                guard ti < times.count, Double(i) / 60 >= times[ti] - 1e-6 else { continue }
                ti += 1
                var sh = try NativeRiseStripTests.scenePx(R, s, f, cx: Int(W) - 14, cy: Int(iy) + 8, cw: 48, ch: 40)
                if kind != "car" { for j in sh.px.indices where j % 4 != 3 { sh.px[j] = UInt8(min(255, Double(sh.px[j]) * 1.5)) } }
                shots.append(sh)
            }
        }
        try G.sheet(shots, cw: 48, ch: 40, cols: 6, name: "../moves/throw_wall_decal", scale: 5)
    }
}
