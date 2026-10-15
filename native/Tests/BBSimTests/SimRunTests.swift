import Testing
import Foundation
@testable import BBSim
import BBContent

/// 한 판 돌리기 · 결정성 · 기본 진행 확인
@Suite struct SimRunTests {
    static let data: SimData = try! SimData.bundled()

    /// 웹 simtrace 하네스와 같은 조건(게임 속도 1 · 매점/정리 자동 · 렌더 없음 = lastP 없음 · 대화 건너뜀)
    static func harnessConfig(stage: Int = 0, kit: String = "basic") -> SimConfig {
        var c = SimConfig(); c.playSpeed = 1; c.autoAdvance = true; c.trackDrawnPose = false; c.skipTalks = true; c.stage = stage; c.kit = kit
        return c
    }

    @Test func runsNinetySeconds() {
        let sim = Sim(data: Self.data, seed: 1001, config: Self.harnessConfig())
        var events = 0
        for _ in 0..<(90 * 60) { events += sim.step().count; if sim.state == "over" || sim.state == "end" { break } }
        let s = sim.snapshot
        #expect(s.kills > 0)
        #expect(s.stats.dealt > 0)
        #expect(events > 100)
    }

    /// 실제 앱 설정(게임 속도 1.25 · 그린 자세 추적 · 자동 넘김 없음)으로도 돈다 — 매점에서 멈추면 advance 로 넘긴다
    @Test func appConfigRuns() {
        let sim = Sim(data: Self.data, seed: 77, config: SimConfig())
        var shops = 0
        for _ in 0..<(150 * 60) {
            var intents: [SimIntent] = []
            if sim.state == "shop" { intents = [.shopPick(1)]; shops += 1 } else if sim.state == "arrange" { intents = [.advance] }
            sim.step(intents)
            if sim.state == "over" { break }
        }
        #expect(sim.snapshot.kills > 0)
        #expect(sim.snapshot.actors.contains { $0.isHero })
    }

    /// M: HUD 가 추정하던 값을 규칙이 내보낸다 — 승객 모델 번호 · 타격 세부 · 강제 만화 글자 · 스냅숏 값
    @Test func hudRealValues() {
        let sim = Sim(data: Self.data, seed: 1001, config: Self.harnessConfig())
        let s0 = sim.snapshot
        let pass = s0.actors.filter(\.isPassenger)
        #expect(!pass.isEmpty && pass.allSatisfy { $0.passModel != nil })
        #expect(pass.enumerated().allSatisfy { k, a in a.passModel == k % 3 })   // 웹 enterCar PASS_MODEL[k%3]
        #expect(s0.lagH == s0.hp && s0.comboWin >= 2.2 && s0.justW >= 0.16)
        var hits: [HitInfo] = [], resets = 0, details = 0
        for _ in 0..<(90 * 60) {
            for e in sim.step() {
                switch e { case .hit(let h): hits.append(h); case .comicReset: resets += 1; case .fxDetail: details += 1; default: break }
            }
        }
        let heroHits = hits.filter(\.attackerIsHero)
        #expect(!heroHits.isEmpty && heroHits.allSatisfy { !$0.attackerAnim.isEmpty && !$0.targetAnim.isEmpty && abs($0.dir) == 1 })
        #expect(hits.contains { $0.targetJugH > 0 })
        _ = resets; _ = details
    }

    @Test func sameSeedSameEvents() {
        func run() -> [String] {
            let sim = Sim(data: Self.data, seed: 4242, config: Self.harnessConfig())
            var out: [String] = []
            for _ in 0..<(40 * 60) { for e in sim.step() { out.append(String(describing: e)) } }
            out.append("\(sim.snapshot.score)|\(sim.snapshot.kills)|\(sim.snapshot.hp)")
            return out
        }
        let a = run(), b = run()
        #expect(a.count == b.count)
        #expect(a == b)
    }
}
