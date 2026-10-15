import Testing
import Foundation
import BBCore
import BBContent
import BBAnim
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 자세 편집기 보기 회전(웹 skinPv.view — 17-light-frame P.spin += view/360): 스튜디오 주인공이 실제로 돈다.
/// BB_DUMP=1 이면 tools/js/out/moves/pose_view.png(0° · 45° · 90° · 180°)
@Suite(.serialized) struct PoseViewSpinTests {
    typealias Strip = NativeMoveStripTests

    func shot(view v: Double, pose: String = "kl_hit", cw: Int = 150, ch: Int = 170, ds: Int = 2, zoom: Int = 1) throws -> Strip.Shot {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        for k in 0..<30 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        sim.apply(.skinPreview(.open)); sim.apply(.skinPreview(.fixed(pose))); sim.apply(.skinPreview(.view(v))); sim.apply(.skinPreview(.z1(true)))
        var out: Strip.Shot?
        for k in 30..<90 {
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if k == 89 { out = try R.shot(s, f, cw: cw, ch: ch, band: nil, ds: ds, dx: 0, dy: -30) }
        }
        guard zoom > 1, let o = out else { return out! }
        // 확대(최근접 — 얼굴 픽셀 점검용)
        var px = [UInt8](repeating: 255, count: cw * zoom * ch * zoom * 4)
        for y in 0..<ch * zoom { for x in 0..<cw * zoom { for c in 0..<4 { px[(y * cw * zoom + x) * 4 + c] = o.px[((y / zoom) * cw + x / zoom) * 4 + c] } } }
        return Strip.Shot(px: px, band: nil)
    }

    /// 몸 전체 기울기(roll) 방향 확인 — 덮어쓰기 층으로 kl_hit 에 roll 을 넣어 그린다(BB_DUMP=1 → pose_roll.png: 0 · +20° · −20°)
    @Test(.enabled(if: Strip.dump)) func rollSign() throws {
        let base = Strip.base.variant(nativeMoves: true).poses["kl_hit"]!
        var shots: [Strip.Shot] = []
        for deg in [0.0, 20, -20] {
            var P = base; P.roll = deg == 0 ? nil : deg / 360
            PoseOverrides.set("kl_hit", deg == 0 ? nil : P)
            defer { PoseOverrides.set("kl_hit", nil) }
            shots.append(try shot(view: 0))
        }
        try Strip.sheet(shots, cw: 150, ch: 170, cols: 3, name: "pose_roll")
    }

    /// 얼굴이 몸 회전을 따라가는지(BB_DUMP=1 → pose_face.png: 보기 0 · 30 · 60 · 90 · 135 · 180° + kl_hold2)
    @Test(.enabled(if: Strip.dump)) func faceFollowsSpin() throws {
        var shots: [Strip.Shot] = []
        for v in [0.0, 30, 60, 90, 135, 180] { shots.append(try shot(view: v, pose: "kl_set", cw: 100, ch: 120, ds: 1, zoom: 2)) }
        shots.append(try shot(view: 0, pose: "kl_hold2", cw: 100, ch: 120, ds: 1, zoom: 2))
        try Strip.sheet(shots, cw: 200, ch: 240, cols: 4, name: "pose_face")
    }

    /// 고개(hn · hy) 방향 확인(BB_DUMP=1 → pose_head.png: 기본 · 숙임 +40 · 젖힘 −40 · 돌림 +60 · 돌림 −60)
    @Test(.enabled(if: Strip.dump)) func headSign() throws {
        let base = Strip.base.variant(nativeMoves: true).poses["kl_set"]!
        var shots: [Strip.Shot] = []
        for (n, y) in [(0.0, 0.0), (40, 0), (-40, 0), (0, 60), (0, -60)] {
            var P = base; P.hn = n == 0 ? nil : n; P.hy = y == 0 ? nil : y
            PoseOverrides.set("kl_set", P)
            defer { PoseOverrides.set("kl_set", nil) }
            shots.append(try shot(view: 0, pose: "kl_set", cw: 100, ch: 120, ds: 1, zoom: 2))
        }
        try Strip.sheet(shots, cw: 200, ch: 240, cols: 5, name: "pose_head")
    }

    @Test func viewRotates() throws {
        let a = try shot(view: 0), b = try shot(view: 90)
        let diff = zip(a.px, b.px).filter { $0 != $1 }.count
        print("[보기 회전] 0° ↔ 90° 다른 바이트 \(diff)")
        #expect(diff > 500)   // 돌린 만큼 그림이 달라진다(전에는 0 — 값이 렌더까지 안 갔다)
        if Strip.dump { try Strip.sheet([a, try shot(view: 45), b, try shot(view: 180)], cw: 150, ch: 170, cols: 4, name: "pose_view") }
    }
}
