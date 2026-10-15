import Testing
import Foundation
@testable import BBSim

/// 개발용: BB_SIM_DEBUG=파일이름 이면 씨앗마다 최종 가방 · 콤보 수를 찍는다
@Suite struct SimDebugTests {
    @Test func dumpRuns() throws {
        guard let f = ProcessInfo.processInfo.environment["BB_SIM_DEBUG"] else { return }
        let B = try SimStatsTests.loadBaseline(f)
        for r in B.results.prefix(8) {
            let sim = Sim(data: SimRunTests.data, seed: r.seed, config: SimRunTests.harnessConfig(stage: B.stage, kit: B.kit))
            for _ in 0..<Int(B.seconds * 60) { sim.step(); if sim.state == "over" || sim.state == "end" { break } }
            let w = sim.w
            print("seed \(r.seed) combos \(w.stats.combos) links \(w.stats.links) state \(w.state) bag \(w.bag.map { "\($0.id)@\($0.x),\($0.y)r\($0.rot)" }.joined(separator: " ")) | stash \(w.stash.map(\.id))")
        }
    }
}

/// 개발용: BB_SIM_MANY=n 이면 긴 판(노선 0 · 기본 가방 · 480초)을 Swift 씨앗 n개로 돌려 평균 · 생존율을 찍는다(표본 크기 효과 확인)
@Suite struct SimManySeedsTests {
    @Test func manySeeds() {
        guard let n = Int(ProcessInfo.processInfo.environment["BB_SIM_MANY"] ?? "") else { return }
        var surv = 0, taken = 0.0, kills = 0.0, t = 0.0
        for s in 0..<n {
            let r = SimStatsTests.run(seed: UInt32(20000 + s), seconds: 480, stage: 0, kit: "basic")
            if r.state != "over" { surv += 1 }; taken += r.taken; kills += r.kills; t += r.t
        }
        print("씨앗 \(n): 생존율 \(Double(surv) / Double(n)) · 받은 피해 \(taken / Double(n)) · 처치 \(kills / Double(n)) · 끝 시각 \(t / Double(n))")
    }
}
