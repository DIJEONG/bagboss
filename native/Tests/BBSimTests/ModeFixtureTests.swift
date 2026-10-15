import Testing
import Foundation
@testable import BBSim

/// N5 모드 순수 함수 대조(tools/js/extract/modetrace.mjs --fx → Fixtures/sim/modes_fx.json):
/// twSpawn 층 · 야근 배율 · 야근 단계 조건 · 오늘의 타워(날짜 시드 조건 · 탑승 순서 · 오늘의 가방) · bonusGrade · carHit 단계 문턱 · 부품 점수 · 파편 자리 · carBones
@Suite struct ModeFixtureTests {
    typealias JV = LockstepTests.JV
    struct Spawn: Decodable { let ot: Int, fl: Int, t: String, k: Int; let hp: Double, dmg: Double, cd: Double, cdT: Double, x: Double, z: Double, flip: Bool }
    struct OT: Decodable { let ot: Int, limit: Int, kit: Bool; let hpK: Double, dmgK: Double, bossK: Double, restK: Double; let black: [Int]; let w10: [String], w20: [String] }
    struct Daily: Decodable { let dk: String; let hash: UInt32; let kit: String; let mods: [String]; let limit: Int; let black: [Int]; let waves: [[String]] }
    struct Grade: Decodable { let hp: Double, t: Double, dealt: Double; let g: String, tk: Int, pts: Int; let left: Double, done: Bool, pct: Double, dps: Double }
    struct Stage: Decodable { let seq: [Double]; let rows: [[JV]]; let debris: [[JV]] }
    struct Bones: Decodable { let stage: Int; let dmgF: Double; let gone: [String]; let tilt: Double; let dentN: Int; let bones: [String: [Double?]] }
    struct File: Decodable { let spawn: [Spawn]; let ot: [OT]; let daily: [Daily]; let grade: [Grade]; let stages: [Stage]; let bones: [Bones] }

    static func load() -> File? {
        guard let d = try? Data(contentsOf: SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/modes_fx.json")) else { return nil }
        return try? JSONDecoder().decode(File.self, from: d)
    }
    static func towerSim(ot: Int = 0, seed: UInt32 = 1) -> Sim {
        var c = SimRunTests.harnessConfig(); c.mode = .tower; c.towerOT = ot
        var m = SimMeta(); m.tower.ot = 6; c.initialMeta = m
        return Sim(data: SimRunTests.data, seed: seed, config: c)
    }
    static func near(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps * max(1, abs(b)) }

    @Test func spawnScaling() throws {
        guard let F = Self.load() else { return }
        var bad = 0
        for ot in Set(F.spawn.map(\.ot)).sorted() {
            let sim = Self.towerSim(ot: ot), w = sim.w
            let T = try #require(w.tw)
            if let o = F.ot.first(where: { $0.ot == ot }) {
                #expect(T.limit == o.limit && T.kit == o.kit && Self.near(T.hpK, o.hpK) && Self.near(T.dmgK, o.dmgK) && Self.near(T.bossK, o.bossK) && T.restK == o.restK, "야근 \(ot) 배율")
                #expect(T.blackSet.sorted() == o.black, "야근 \(ot) 정전 층")
                #expect(T.waves[10] == o.w10 && T.waves[20] == o.w20, "야근 \(ot) 두목 층")
            }
            for s in F.spawn where s.ot == ot {
                T.floor = s.fl; w.ents = [w.hero]; w.cut = nil
                w.twSpawn(s.t, s.k)
                let a = w.ents.last!, e = a.e!
                let ok = e.hp == s.hp && e.dmg == s.dmg && Self.near(e.cd, s.cd) && Self.near(e.cdT, s.cdT) && a.x == s.x && a.z == s.z && a.flip == s.flip
                if !ok { bad += 1; if bad < 6 { print("twSpawn 어긋남 \(s) ↔ hp \(e.hp) dmg \(e.dmg) cd \(e.cd) cdT \(e.cdT) x \(a.x) z \(a.z)") } }
            }
        }
        #expect(bad == 0, "twSpawn \(bad)건 어긋남 / \(F.spawn.count)")
    }

    @Test func dailyTower() throws {
        guard let F = Self.load() else { return }
        let w = Self.towerSim().w
        for d in F.daily {
            #expect(World.hashStr(d.dk) == d.hash, "hashStr \(d.dk)")
            let kits = w.data.game.kits
            #expect(kits[Int(d.hash % UInt32(kits.count))].id == d.kit, "오늘의 가방 \(d.dk)")
            let T = w.twSetup(daily: d.dk, ot: 0)
            #expect(T.mods.map { w.twd.mods[$0].id ?? "" } == d.mods, "조건 \(d.dk)")
            #expect(T.limit == d.limit, "정원 \(d.dk)")
            #expect(T.blackSet.sorted() == d.black, "정전 층 \(d.dk)")
            #expect(Array(T.waves[1...]) == d.waves, "탑승 순서 \(d.dk)")
        }
    }

    @Test func bonusGrade() {
        guard let F = Self.load() else { return }
        for g in F.grade {
            let r = BonusCarRig.grade(hp: g.hp, max: 460, t: g.t, dur: 30, dealt: g.dealt)
            #expect(r.grade == g.g && r.tokens == g.tk && r.points == g.pts && Self.near(r.left, g.left) && r.done == g.done && Self.near(r.pct, g.pct) && Self.near(r.dps, g.dps), "bonusGrade \(g)")
        }
    }

    @Test func carStages() {
        guard let F = Self.load() else { return }
        for s in F.stages {
            var c = SimRunTests.harnessConfig(); c.mode = .bonus
            let sim = Sim(data: SimRunTests.data, seed: 3, config: c), w = sim.w
            guard let B = w.bn else { Issue.record("보너스가 안 열림"); return }
            B.phase = "go"
            for (i, loss) in s.seq.enumerated() {
                w.combo = i % 25; w.carHit(loss)
                let r = s.rows[i]
                let mine: [String] = ["\(B.car.stage)", "\(B.score)", "\(B.hitPts)", "\(B.partPts)", JSFormat.fixed(B.hp, 3), B.car.gone.sorted().joined(separator: ","), "\(B.car.debris.count)", JSFormat.fixed(B.car.tilt, 3), "\(B.alarm)", "\(B.fire)"]
                let web = r.enumerated().map { j, v -> String in
                    if case .null = v { return "false" }
                    if j == 4 || j == 7, case .n(let x) = v { return JSFormat.fixed(x, 3) }
                    return v.description
                }
                #expect(mine == web, "carHit \(s.seq.prefix(3))… \(i): 웹 \(web) ↔ Swift \(mine)")
            }
            for (k, d) in s.debris.enumerated() where k < B.car.debris.count {
                let m = B.car.debris[k]
                let vals = d.dropFirst().map { if case .n(let x) = $0 { return x }; return .nan }
                #expect(m.key == d[0].description && abs(m.x - vals[0]) < 1e-3 && abs(m.y - vals[1]) < 1e-3 && abs(m.z - vals[2]) < 1e-3 && abs(m.th - vals[3]) < 1e-4, "파편 \(d) ↔ \(m)")
            }
        }
    }

    @Test func carBones() {
        guard let F = Self.load() else { return }
        for b in F.bones {
            let B = BonusCarRig.bones(stage: b.stage, dmgF: b.dmgF, gone: Set(b.gone), tilt: b.tilt)
            #expect(BonusCarRig.dentN(b.dmgF) == b.dentN, "dentN \(b.dmgF)")
            #expect(Set(B.keys) == Set(b.bones.keys), "뼈 목록 \(b.stage): \(Set(B.keys).symmetricDifference(Set(b.bones.keys)))")
            for (k, v) in b.bones {
                guard let m = B[k] else { continue }
                let ok = abs(m.x - v[0]!) < 1e-5 && abs(m.y - v[1]!) < 1e-5 && abs(m.z - v[2]!) < 1e-5 && abs(m.th - v[3]!) < 1e-5 && (v[4] == nil ? m.sy == nil : abs((m.sy ?? -9) - v[4]!) < 1e-5)
                #expect(ok, "carBones \(b.stage) \(k): 웹 \(v) ↔ \(m)")
            }
        }
    }
}
