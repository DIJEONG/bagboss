// 저장 메타(MetaState) ↔ 규칙 메타(MetaRuleView = BBSim SimMeta 와 1:1) 왕복 · 웹 메타 진행 규칙(metaTick · showResult · dailyKit).
import Foundation
import Testing
@testable import BBPersistence

@Suite struct MetaRulesTests {
    /// 웹에서 실제로 한 판 돈 메타(타워 · 콤보 기록 등은 손으로 더한다)
    static func played() throws -> MetaState {
        var m = try decoded(MetaState.self, Fx.value("meta-played.json"))
        var T = MetaState.TowerRecord(); T.best = 14; T.bestT = 251; T.runs = 3; T.ot = 2
        T.lv = ["0": .init(f: 20, t: 251), "1": .init(f: 14, t: 190)]; T.daily = ["2026-10-09": .init(f: 9, t: 120)]
        T.extras = ["미래필드": "x"]
        m.tower = T; m.bonusBest = 21833
        m.cbook = ["c1": .init(n: 2, best: 7)]; m.combos = ["upper>punch>kick": .init(name: "기본 경로", ids: ["upper", "punch", "kick"], n: 5, best: 6)]
        m.spc = ["fist": 2]; m.bossScenes = ["boss": 1]; m.hints = ["move": 1, "bag": 1]; m.talks = ["intro": 1]; m.seenCut = ["spc:fist": 1]
        return m
    }

    @Test func 저장_규칙_저장_왕복이_그대로다() throws {
        let m = try Self.played()
        var back = m
        let changed = back.merge(m.ruleView())
        #expect(!changed)
        #expect(back == m)
        // JSON 으로도 같은 바이트
        #expect(try SaveStore.webJSONString(back) == SaveStore.webJSONString(m))
    }

    @Test func 규칙_저장_규칙_왕복이_그대로다() throws {
        var v = MetaRuleView()
        v.seenCut = ["spc:fist", "vs:boss"]; v.foes = ["thug": [12, 9], "boss": [1, 1]]; v.items = ["punch": 2, "kick": 1]
        v.links = ["L1"]; v.hints = ["move"]; v.talks = ["intro", "shop"]; v.spc = ["foot": 3]
        v.cbook = ["c2": [1, 4]]; v.combos = ["knee>throw": [2, 5]]; v.bossScenes = ["boss2": 2]; v.lines = [0, 1, 2]
        v.tower.best = 20; v.tower.bestT = 244; v.tower.runs = 4; v.tower.ot = 3
        v.tower.lv = [0: .init(f: 20, t: 244), 2: .init(f: 18, t: 300)]; v.tower.daily = ["2026-10-09": .init(f: 12, t: 200)]
        v.bonusBest = 30500
        v.daily = ["2026-10-09": 1500]; v.cseen = ["c9"]; v.comboNames = ["knee>throw": "접고 메치기"]
        var m = MetaState()
        let ch = m.merge(v); #expect(ch)
        #expect(m.ruleView() == v)
        // 새로 생긴 자유 콤보는 ids 를 키에서 되살린다
        #expect(m.combos?["knee>throw"]?.ids == ["knee", "throw"])
        #expect(m.combos?["knee>throw"]?.name == "접고 메치기" && m.daily["2026-10-09"] == 1500 && m.cseen == ["c9": 1])
        // 노선 열림은 best.stage 도 민다(웹 loadStage)
        #expect(m.best.stage == 2)
        // 저장 JSON 을 다시 읽어도 같다
        let again = MetaState.load(webJSON: try SaveStore.webJSONString(m))
        #expect(again.ruleView() == v)
    }

    @Test func 빈_규칙은_선택_필드를_만들지_않는다() throws {
        var m = MetaState()
        let ch = m.merge(MetaState().ruleView()); #expect(!ch)
        #expect(m.tower == nil && m.bonusBest == nil && m.hints == nil && m.cbook == nil)
        #expect(try encoded(m) == Fx.value("meta-default.json"))
    }

    @Test func 합치기는_단조다() throws {
        var m = try Self.played()
        var v = m.ruleView()
        // 시뮬레이션이 더 적은 값을 들고 있어도(다른 판의 오래된 메타) 저장 값이 줄지 않는다
        v.foes = v.foes.mapValues { _ in [0, 0] }; v.tower.best = 1; v.tower.bestT = 999; v.tower.lv = [1: .init(f: 3, t: 50)]
        v.bonusBest = 10
        m.merge(v)
        let p = try Self.played()
        #expect(m.foes == p.foes)
        #expect(m.tower?.best == 14 && m.tower?.bestT == 251)
        #expect(m.tower?.lv?["1"] == p.tower?.lv?["1"])
        #expect(m.bonusBest == 21833)
        // 더 좋은 기록은 들어간다: 같은 층 더 짧은 시간 · 새 단계
        v.tower.lv = [1: .init(f: 14, t: 150)]; v.tower.ot = 4; v.tower.bestT = 200
        m.merge(v)
        #expect(m.tower?.lv?["1"]?.t == 150 && m.tower?.ot == 4 && m.tower?.bestT == 200)
        #expect(m.tower?.extras["미래필드"] == "x")
    }

    @Test func 누계와_가방_해금은_웹_metaTick_과_같다() {
        var m = MetaState(), snap: [String: Int] = [:]
        let a1 = m.addTally(["kills": 5, "crits": 10], snap: &snap); #expect(a1)
        let a2 = m.addTally(["kills": 5, "crits": 10], snap: &snap); #expect(!a2)    // 같은 값이면 더하지 않는다
        m.addTally(["kills": 8, "crits": 70, "footSet": 1], snap: &snap)
        #expect(m.tot.kills == 8 && m.tot.crits == 70 && m.tot.footSet == 1)
        let conds: [MetaState.KitCondition] = [.init(id: "crit", key: "crits", n: 60), .init(id: "foot", key: "footSet", n: 1), .init(id: "grap", key: "throws", n: 15)]
        #expect(m.kitProgress(conds[2]).ratio == 0)
        let u1 = m.unlockKits(conds); #expect(u1 == ["crit", "foot"])
        let u2 = m.unlockKits(conds); #expect(u2.isEmpty)
        #expect(m.kits == ["basic": 1, "crit": 1, "foot": 1])
        // 새 판: 스냅을 비우면 다시 0 부터 센다
        snap = [:]; m.addTally(["kills": 2], snap: &snap)
        #expect(m.tot.kills == 10)
        let s1 = m.visitStation("atl"), s2 = m.visitStation("atl"), s3 = m.visitStation(nil); #expect(s1 && !s2 && !s3)
    }

    @Test func 판_끝_기록은_웹_showResult_와_같다() {
        var m = MetaState()
        let b1 = m.recordRunEnd(score: 1200, dailyKey: nil); #expect(b1)
        let b2 = m.recordRunEnd(score: 900, dailyKey: "2026-10-09"); #expect(!b2)
        #expect(m.runs == 2 && m.best.score == 1200 && m.daily["2026-10-09"] == 900)
        m.recordRunEnd(score: 1500, dailyKey: "2026-10-09")
        #expect(m.daily["2026-10-09"] == 1500)
        m.resetHints(); #expect(m.hints == [:])
    }

    @Test func 오늘의_가방은_웹_dailyKit_과_같다() {
        // Fixtures/sim/modes_fx.json(웹 hashStr) 의 값
        #expect(DailyKey.hash("2026-01-01") == 2_049_302_883)
        #expect(DailyKey.kitIndex("2026-01-01", count: 6) == 3)   // KITS[3] = grap
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        #expect(DailyKey.today(d, calendar: cal) == "2026-03-07")
    }
}
