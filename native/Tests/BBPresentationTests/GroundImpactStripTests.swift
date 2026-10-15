import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 네이티브 바닥 충격(철산고 · 도끼 꽂힘 — groundImpact + tsring) 띠(BB_DUMP=1) → tools/js/out/moves/ground_impact.png
///   줄: 객차(금속 판 — 눌린 자국 + 주름) · 무도장(나무 — 결 따라 갈라짐 + 나뭇조각) · 건널목(돌 — 균열 + 부스러기) · 눈(구덩이 — 균열 없음)
///   칸: 0 · 0.05 · 0.1 · 0.18 · 0.3 · 0.6 · 1.0 · 1.6초(4배). 주인공만 남기고 장면을 멈춘 채 같은 충격을 넣는다
@Suite(.serialized) struct GroundImpactStripTests {
    typealias Strip = NativeMoveStripTests

    static func row(_ kind: String) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = 198
        var c = SimConfig(); c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1
        if kind != "car" { c.mode = .dojo }
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 5, config: c)
        if kind == "cross" || kind == "snow" { sim.apply(.dojo(.background(kind))) }
        for k in 0..<90 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        var base = sim.snapshot
        base.actors = base.actors.filter { $0.isHero }
        guard var H = base.actors.first else { return [] }
        H.x = 200; H.flip = false; base.actors = [H]
        let ix = H.x + 36, iy = H.y
        let times = [0.0, 0.05, 0.1, 0.18, 0.3, 0.6, 1.0, 1.6]
        var shots: [Strip.Shot] = [], ti = 0
        let band: (UInt8, UInt8, UInt8) = kind == "car" ? (150, 160, 175) : kind == "dojo" ? (190, 130, 70) : kind == "cross" ? (120, 120, 120) : (200, 225, 255)
        for i in 0..<(60 * 2) {
            var s = base; s.gameTime += Double(i) / 60; s.time += Double(i) / 60
            let ev: [SimEvent] = i == 0 ? [.groundImpact(x: ix, y: iy, power: 2.0), .fx(kind: "tsring", x: ix, y: iy, dir: 1)] : []
            _ = R.d.apply(ev, snapshot: s, now: 2 + Double(i) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: 2 + Double(i) / 60)
            guard ti < times.count, Double(i) / 60 >= times[ti] - 1e-6 else { continue }
            ti += 1
            let px = try SnowStripTests.render(R, s, f)
            var sh = SnowStripTests.crop(px, x0: Int(ix) - 40, y0: Int(iy) - 24, w: 80, h: 34)
            if kind == "dojo" || kind == "cross" { for j in sh.px.indices where j % 4 != 3 { sh.px[j] = UInt8(min(255, Double(sh.px[j]) * 1.6)) } }   // 어두운 무도장 밝혀 보기
            sh.band = band
            shots.append(sh)
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func groundImpact() throws {
        var shots: [Strip.Shot] = []
        for k in ["car", "dojo", "cross", "snow"] { let r = try Self.row(k); print("[impact] \(k) \(r.count)"); shots += r }
        try NativeGuardStripTests.sheet(shots, cw: 80, ch: 34, cols: 8, name: "../moves/ground_impact", scale: 5)
    }
}
