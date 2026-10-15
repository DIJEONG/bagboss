import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 야근 광선(BB_DUMP=1 일 때만) → tools/js/out/moves/beam.png(무도장 단독 · 무대만 — 넓게) · beam_body.png(주인공 온몸 확대) · beam_air.png(띄운 적을 위로 꺾어 쏘기 · 소품)
@Suite(.serialized) struct NativeBeamStripTests {
    typealias Strip = NativeMoveStripTests

    /// 동작 시작부터 times(초)마다 한 칸. prep = 시작 직전에 할 일(띄우기 · 소품)
    func frames(times: [Double], cw: Int, ch: Int, ds: Int, dx: Int, dy: Int, zoom: Double, hideDummy: Bool = false, bright: Double = 1,
                prep: ((Sim) -> Void)? = nil) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(zoom)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        var shots: [Strip.Shot] = [], start: Int?
        let want = times.map { Int(($0 * 60).rounded()) }
        for k in 40..<(40 + 60 * 4) {
            if k == 41 {
                sim.apply(.dojo(.hero("nv_beam", combo: nil)))
                if hideDummy { _ = sim.step(); sim.w.dojoDummy()!.hidden = true }
                prep?(sim)
            }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if start == nil && w.hero.anim == "nv_beam" { start = k }
            guard let st = start else { continue }
            for _ in want.filter({ $0 == k - st }) {
                let band: (UInt8, UInt8, UInt8)? = w.hero.pose == "bm_fire" ? (255, 255, 255) : s.beam?.phase == "fire" ? (80, 230, 210) : (120, 120, 140)
                var sh = try R.shot(s, f, cw: cw, ch: ch, band: band, ds: ds, dx: dx, dy: dy, hud: false)
                if bright != 1 { for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * bright)) } }
                shots.append(sh)
            }
            if shots.count >= times.count { break }
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func beam() throws {
        let t = [0.05, 0.15, 0.25, 0.27, 0.32, 0.4, 0.5, 0.6, 0.66, 0.7, 0.8, 1.0]
        try Strip.sheet(try frames(times: t, cw: 340, ch: 150, ds: 2, dx: 90, dy: 4, zoom: 1.4), cw: 340, ch: 150, cols: 4, name: "beam")
    }

    @Test(.enabled(if: Strip.dump)) func beamBody() throws {
        let t = [0.0, 0.1, 0.2, 0.26, 0.4, 0.6, 0.7, 0.85]
        try Strip.sheet(try frames(times: t, cw: 200, ch: 200, ds: 1, dx: 30, dy: -30, zoom: 2, hideDummy: true, bright: 1.3), cw: 200, ch: 200, cols: 8, name: "beam_body")
    }

    /// 떠 있는 허수아비(띄운 채) — 위로 꺾어 쏜다 · 허수아비 뒤 유리 부스
    @Test(.enabled(if: Strip.dump)) func beamAir() throws {
        let t = [0.26, 0.35, 0.5, 0.66, 0.8]
        let air = try frames(times: t, cw: 340, ch: 170, ds: 2, dx: 90, dy: 0, zoom: 1.4) { sim in
            let w = sim.w, D = w.dojoDummy()!
            D.x = w.hero!.x + w.hero!.f * 60
            w.jugHit(D, "launch", w.hero!.f, D, HitOpts(), 1); D.jug!.vy = 330
        }
        let obj = try frames(times: t, cw: 340, ch: 170, ds: 2, dx: 90, dy: 0, zoom: 1.4) { sim in
            let D = sim.w.dojoDummy()!, f = sim.w.hero!.f
            sim.apply(.dojo(.objSet([DojoObjSpec(kind: "glass", x: D.x + f * 50), DojoObjSpec(kind: "shoji", x: D.x + f * 90)])))
        }
        try Strip.sheet(air + obj, cw: 340, ch: 170, cols: t.count, name: "beam_air")
    }
}
