// 유료 스킨 해금 캐시(bbn-skins) · 리더보드 점수 규칙(에이전트 O — 2단계 A)
import Foundation
import Testing
@testable import BBPersistence

@Suite struct EntitlementsTests {
    static let free: Set<String> = ["jw"], known: Set<String> = ["jw", "gala", "rain", "chicago"]

    @Test func 잠긴_스킨은_기본으로_돌린다() {
        let u = SkinUnlocks(owned: ["rain"])
        #expect(u.effectiveSkin(selected: "rain", free: Self.free, known: Self.known) == "rain")
        #expect(u.effectiveSkin(selected: "gala", free: Self.free, known: Self.known) == "jw")
        #expect(u.effectiveSkin(selected: "없는스킨", free: Self.free, known: Self.known) == "jw")
        #expect(u.effectiveSkin(selected: nil, free: Self.free, known: Self.known) == "jw")
        #expect(u.isUnlocked("jw", free: Self.free))
    }

    @Test func 캐시_저장_왕복_정렬() throws {
        let s = SaveStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("ent-\(UUID().uuidString).json"), debounce: 0)
        s.setSkinUnlocks(SkinUnlocks(owned: ["rain", "gala"]))
        #expect(s.string(forKey: SkinUnlocks.storageKey) == "[\"gala\",\"rain\"]")
        #expect(s.skinUnlocks().owned == ["gala", "rain"])
        #expect(SkinUnlocks.load(webJSON: "{깨짐").owned.isEmpty)
        #expect(SkinUnlocks.load(webJSON: nil).owned.isEmpty)
    }

    @Test func 타워_점수는_층이_먼저_같은_층이면_빠른_쪽() {
        let a = LeaderboardScore.tower(floor: 14, seconds: 251), b = LeaderboardScore.tower(floor: 14, seconds: 200), c = LeaderboardScore.tower(floor: 15, seconds: 9000)
        #expect(b > a); #expect(c > b)
        #expect(LeaderboardScore.decodeTower(a) == (14, 251))
        #expect(LeaderboardScore.tower(floor: 0, seconds: 10) == 0)
        #expect(LeaderboardScore.tower(floor: 3, seconds: 99999) == 30000)
    }

    @Test func 메타에서_올릴_기록() {
        var m = MetaState(); m.best.score = 48210.4
        var T = MetaState.TowerRecord(); T.best = 18; T.bestT = 0
        T.lv = ["0": .init(f: 20, t: 244), "2": .init(f: 14, t: 251)]; T.daily = ["2026-10-09": .init(f: 9, t: 120)]
        m.tower = T
        let b = LeaderboardScore.bests(m, dailyKey: "2026-10-09")
        #expect(b.runScore == 48210)
        #expect(b.tower == LeaderboardScore.tower(floor: 20, seconds: 244))
        #expect(b.dailyTower == LeaderboardScore.tower(floor: 9, seconds: 120))
        #expect(LeaderboardScore.bests(m, dailyKey: "2026-10-10").dailyTower == 0)
    }
}
