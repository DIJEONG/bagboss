import Testing
@testable import BBHaptics
import BBSim

@Suite struct HapticPlannerTests {
    func hit(crit: Bool = false, big: Bool = false, heroHit: Bool = false, knock: Bool = false, react: String? = nil, weight: HitWeight = .light) -> SimEvent {
        var h = HitInfo(attacker: 0, target: 1, damage: 10, reaction: "hit"); h.crit = crit; h.bigCrit = big; h.heroWasHit = heroHit
        h.attackerIsHero = !heroHit; h.knock = knock; h.reactOpt = react; h.weight = weight
        return .hit(h)
    }

    @Test("웹 규칙: 넉백 · 치명 · 띄우기만 진동(무게 H 라도 넉백이 아니면 없음)") func webBuzzRule() {
        var p = HapticPlanner()
        #expect(p.plan([hit(weight: .heavy)], now: 0).isEmpty)                 // 다리걸기 · 도끼 차기(H, 넉백 아님)
        #expect(!p.plan([hit(knock: true)], now: 1).isEmpty)                    // 앞차기(넉백)
        #expect(!p.plan([hit(react: "launch")], now: 2).isEmpty)                // 어퍼(띄우기)
        #expect(p.plan([hit(crit: true, big: true)], now: 3).first?.intensity == 0.85)
    }

    @Test func plainHitsAreSilent() {
        var p = HapticPlanner()
        #expect(p.plan([hit()], now: 0).isEmpty)          // 웹도 보통 타격엔 buzz 를 안 부른다
    }

    @Test func heavierEventWinsInOneTick() {
        var p = HapticPlanner()
        let r = p.plan([hit(crit: true), .bossAppear(actor: 3)], now: 0)
        #expect(r.first?.intensity == 1)                  // 두목 등장이 치명타보다 무겁다
    }

    @Test func coalescesWithin45ms() {
        var p = HapticPlanner()
        #expect(!p.plan([.heroHurt(weight: .medium)], now: 1.0).isEmpty)
        #expect(p.plan([.heroHurt(weight: .medium)], now: 1.03).isEmpty)
        #expect(!p.plan([.heroHurt(weight: .medium)], now: 1.06).isEmpty)
    }

    @Test func settingsRespected() {
        var p = HapticPlanner(); p.settings.enabled = false
        #expect(p.plan([.specialUsed], now: 0).isEmpty)
        var q = HapticPlanner(); q.settings.heroHurtScale = 0.5; q.settings.richTails = false
        let r = q.plan([.heroHurt(weight: .heavy)], now: 0)
        #expect(abs(r[0].intensity - 0.475) < 1e-9 && r[0].tail == 0)
    }

    @Test("KA-BOOM! 글자 = buzz(50) · 0.5초 간격(comicReset 이면 바로)") func kaboom() {
        var p = HapticPlanner()
        #expect(!p.plan([.comicWord(word: "KA-BOOM!", x: 0, y: 0)], now: 0).isEmpty)
        #expect(p.plan([.comicWord(word: "KA-BOOM!", x: 0, y: 0)], now: 0.2).isEmpty)
        #expect(!p.plan([.comicReset, .comicWord(word: "KA-BOOM!", x: 0, y: 0)], now: 0.3).isEmpty)
    }
}
