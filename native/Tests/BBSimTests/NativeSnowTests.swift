import Testing
import Foundation
@testable import BBSim
import BBContent

/// 눈 승강장(docs/10): 붙잡힘 → 웨이브 → 다시 타기 · 바깥 규칙(문 · 손잡이 · 지붕) · 결정성 · 깃발 꺼짐 불변
@Suite struct NativeSnowTests {
    static let data = try! SimData.bundled().variant(nativeMoves: true)

    static func config(snow: Bool = true, seed: UInt32 = 0) -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.nativeSnow = snow; c.playSpeed = 1; c.autoSpecial = true
        return c
    }

    /// 눈 구간으로 바로 가서 끝날 때까지 — (붙잡힌 틱 · 붙잡힌 동안 열차 최고 속도 · 풀린 틱 · 처치 수 · 마지막 상태 해시)
    static func runLeg(seed: UInt32) -> (held: Int, vmax: Double, release: Int?, kills: Int, sig: String) {
        let sim = Sim(data: data, seed: seed, config: config())
        for _ in 0..<30 { sim.step() }
        #expect(sim.debugSnowJump())
        var held = 0, vmax = 0.0, rel: Int?
        for k in 0..<(60 * 240) {
            sim.step(k % 20 == 0 ? [SimIntent.tap(side: k % 60 < 30 ? 1 : -1, at: sim.clock)] : [])
            let s = sim.snapshot
            if s.snowStage != nil { held += 1; vmax = max(vmax, s.trainSpeed); #expect(!s.actors.contains { $0.isPassenger }) }
            else if rel == nil && held > 0 { rel = k }
            if let r = rel, k > r + 120 { break }
            if s.state == "over" { break }
        }
        let s = sim.snapshot
        return (held, vmax, rel, s.kills, "\(s.kills)|\(s.score)|\(Int(s.hp))|\(s.state)|\(s.car)")
    }

    @Test func holdFightRelease() {
        let a = Self.runLeg(seed: 11)
        print("[눈 승강장] 붙잡힘 \(a.held)틱 · 열차 최고 \(a.vmax) · 풀림 \(String(describing: a.release)) · 처치 \(a.kills) · \(a.sig)")
        #expect(a.held > 60 * 10)            // 웨이브를 승강장에서 싸웠다
        #expect(a.vmax == 0)                 // 붙잡힌 동안 열차는 서 있다
        #expect(a.release != nil)            // 다 쓰러뜨리면 다시 탄다
        let b = Self.runLeg(seed: 11)
        #expect(a.sig == b.sig && a.held == b.held)   // 결정적
    }

    @Test func outdoorRules() {
        let sim = Sim(data: Self.data, seed: 5, config: Self.config()), w = sim.w
        for _ in 0..<30 { sim.step() }
        #expect(sim.debugSnowJump())
        w.tr.door = 1
        #expect(!w.doorOpenAt(129))                 // 문이 없다
        #expect(w.nvRoofSpot().kind == "open")      // 지붕이 없다
    }

    @Test func flagOffNoSnow() {
        let sim = Sim(data: Self.data, seed: 5, config: Self.config(snow: false))
        for _ in 0..<30 { sim.step() }
        #expect(!sim.debugSnowJump())
        var c = Self.config(snow: false); c.stage = 3
        let s2 = Sim(data: Self.data, seed: 3, config: c)
        for _ in 0..<(60 * 120) { s2.step(); #expect(s2.snapshot.snowStage == nil); if s2.snapshot.car >= 2 { break } }
    }
}
