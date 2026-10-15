import Testing
@testable import BBSim

/// 네이티브 무도장: 시연은 직접 누름 치명 보너스(+10%) 없이 — 기본 8% 언저리(감독 피드백 2026-10-14)
@Suite struct DojoCritTests {
    @Test func dojoCritRateIsBase() {
        var n = 0, c = 0
        for seed in 0..<150 {
            let sim = DojoNativeTests.dojo(true, seed: UInt32(seed))
            sim.apply(.dojo(.hero("kick", combo: nil)))
            for _ in 0..<90 { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero { n += 1; if h.crit { c += 1 } } } }
        }
        let r = Double(c) / Double(max(1, n))
        print("[무도장 치명] \(c)/\(n) = \(r)")
        #expect(n >= 140 && r < 0.13)   // 보너스가 붙으면 18% 언저리
    }

    /// '치명 끄기': 확률 · '항상 치명'(코크스크루) 모두 치명 없음 · 다시 켜면 돌아온다
    @Test func critOff() {
        var n = 0, c = 0
        for (k, id) in ["kick", "nv_cork", "nv_kneelift"].enumerated() {
            for seed in 0..<30 {
                let sim = DojoNativeTests.dojo(true, seed: UInt32(seed + k * 100))
                sim.apply(.dojo(.crit(false))); sim.apply(.dojo(.hero(id, combo: nil)))
                for _ in 0..<90 { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero { n += 1; if h.crit { c += 1 } } } }
                #expect(sim.snapshot.dojo?.crit == false)
            }
        }
        #expect(n >= 80 && c == 0)
        let sim = DojoNativeTests.dojo(true)
        sim.apply(.dojo(.crit(false))); sim.apply(.dojo(.crit(true))); sim.apply(.dojo(.hero("nv_cork", combo: nil)))
        var on = 0
        for _ in 0..<90 { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero, h.crit { on += 1 } } }
        #expect(on >= 1)   // 코크스크루는 '항상 치명'
    }
}
