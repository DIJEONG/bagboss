import Testing
import Foundation
@testable import BBSim

/// N5 모드 분포 대조(tools/js/extract/modetrace.mjs --runs → Fixtures/sim/modes_baseline.json):
/// 웹은 연출 난수도 같은 수열에서 뽑아 판이 갈라지므로 같은 씨앗 · 같은 조건으로 N판씩 돌려 평균을 표준오차로 맞댄다.
/// 지표: 타워 — 도달 층 · 걸린 초 · 처치 · 문밖 · 천장 · 부순 층 · 받은 피해 · 점수 / 보너스 — 결산 합계 · 차에 준 피해 · 타수 · 등급 점수.
/// BB_SIM_STATS=1 이면 표를 tools/js/out/sim/modes_compare.md 에 쓴다.
@Suite struct ModeStatsTests {
    struct BonusRow: Decodable { let g: String; let tk: Int; let total: Double; let dealt: Double; let hits: Double; let stage: Double; let t: Double }
    struct Row: Decodable {
        let seed: UInt32; let t: Double; let state: String; let hp: Double; let score: Double; let kills: Double; let tokens: Double; let dealt: Double; let taken: Double
        let floor: Double; let secs: Double; let outs: Double; let ceils: Double; let wrecks: Double; let bonus: BonusRow?
    }
    struct Set_: Decodable { let mode: String; let seconds: Double; let ot: Int?; let results: [Row] }
    struct File: Decodable { let sets: [String: Set_] }

    static func run(_ S: Set_, seed: UInt32) -> Row {
        var c = SimRunTests.harnessConfig(); c.mode = S.mode == "tower" ? .tower : .bonus; c.towerOT = S.ot ?? 0
        var m = SimMeta(); m.tower.ot = 6; c.initialMeta = m; c.harnessWarmup = true
        let sim = Sim(data: SimRunTests.data, seed: seed, config: c)
        var t = 0.0, br: BonusRow?
        for _ in 0..<Int(S.seconds * 60) {
            sim.step(); t += 1.0 / 60
            if br == nil, let B = sim.w.bn, let R = B.res {
                br = BonusRow(g: R.grade, tk: R.tokens, total: Double(R.total), dealt: B.dealt.rounded(), hits: Double(B.hits), stage: Double(B.car.stage), t: B.t)
            }
            if sim.state == "over" || (S.mode == "bonus" && sim.state == "transfer") { break }
        }
        let w = sim.w, T = w.tw
        return Row(seed: seed, t: t, state: w.state, hp: w.hp, score: Double(w.score), kills: Double(w.kills), tokens: Double(w.tokens), dealt: w.stats.dealt.rounded(), taken: w.stats.taken.rounded(),
                   floor: Double(T.map { $0.done ? 20 : $0.floor } ?? 0), secs: T.map { (w.time - $0.t0).rounded() } ?? 0, outs: Double(T?.outs ?? 0), ceils: Double(T?.ceilN ?? 0), wrecks: Double(T?.wrecks ?? 0), bonus: br)
    }
    static func ms(_ v: [Double]) -> (m: Double, s: Double) { SimStatsTests.ms(v) }

    static func compare(_ name: String, _ S: Set_) -> (md: String, z: [String: Double]) {
        // Swift 는 웹 씨앗(BB_SIM_STATS=1 이면 다른 씨앗 하나씩 더 — 2배 표본)
        let more = ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil
        let sw = S.results.map { Self.run(S, seed: $0.seed) } + (more ? S.results.map { Self.run(S, seed: $0.seed &+ 50_000) } : [])
        let web = S.results
        var metrics: [(String, (Row) -> Double?)] = [("score", { $0.score }), ("kills", { $0.kills }), ("dealt", { $0.dealt }), ("taken", { $0.taken }), ("tokens", { $0.tokens })]
        if S.mode == "tower" {
            metrics = [("floor", { $0.floor }), ("secs", { $0.secs }), ("outs", { $0.outs }), ("ceils", { $0.ceils }), ("wrecks", { $0.wrecks })] + metrics
        } else {
            let gp: [String: Double] = ["S": 5, "A": 4, "B": 3, "C": 2, "D": 1]
            metrics = [("bonus total", { $0.bonus?.total }), ("bonus dealt", { $0.bonus?.dealt }), ("bonus hits", { $0.bonus?.hits }), ("car stage", { $0.bonus?.stage }),
                       ("grade(S=5…D=1)", { $0.bonus.map { gp[$0.g] ?? 0 } }), ("tokens(bonus)", { $0.bonus.map { Double($0.tk) } })] + metrics
        }
        var md = "## \(name) — \(S.mode)\(S.ot.map { " 야근 \($0)" } ?? "") · 웹 \(web.count)판 · Swift \(sw.count)판\n\n| 지표 | 웹 평균 ± 표준편차 | Swift 평균 ± 표준편차 | z |\n|---|---:|---:|---:|\n"
        var z: [String: Double] = [:]
        for (n, f) in metrics {
            let a = ms(web.compactMap(f)), b = ms(sw.compactMap(f))
            let se = (a.s * a.s / Double(max(1, web.count)) + b.s * b.s / Double(max(1, sw.count))).squareRoot()
            let zz = se > 1e-6 ? (b.m - a.m) / se : (abs(b.m - a.m) < 1e-9 ? 0 : 99)
            z[n] = zz
            md += String(format: "| %@ | %.2f ± %.2f | %.2f ± %.2f | %+.2f |\n", n, a.m, a.s, b.m, b.s, zz)
        }
        let topW = web.filter { $0.floor >= 20 && $0.state == "over" && $0.hp > 0 }.count, topS = sw.filter { $0.floor >= 20 && $0.state == "over" && $0.hp > 0 }.count
        if S.mode == "tower" { md += String(format: "| 꼭대기 돌파 | %d/%d | %d/%d | |\n", topW, web.count, topS, sw.count) }
        return (md + "\n", z)
    }

    @Test func modesDistributionMatchesWeb() throws {
        guard let d = try? Data(contentsOf: SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/modes_baseline.json")) else { return }
        let F = try JSONDecoder().decode(File.self, from: d)
        var md = "# N5 모드 통계 대조 — 웹 modetrace ↔ Swift BBSim\n\n자동 전투 · 매점 첫 카드 · 정리 바로 출발 · 게임 속도 1.25(웹 startTower/jumpTo 그대로) · 렌더 없음.\n\n"
        for name in F.sets.keys.sorted() {
            let (m, z) = Self.compare(name, F.sets[name]!)
            md += m
            for (k, v) in z { #expect(abs(v) < 3.5, "\(name) \(k) z=\(v)") }
        }
        print(md)
        if ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil {
            let out = SimStatsTests.root.appending(path: "tools/js/out/sim")
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try? md.write(to: out.appending(path: "modes_compare.md"), atomically: true, encoding: .utf8)
        }
    }

    /// 모드 기본 동작(기준선 없이도): 타워는 층을 오르고 결과를 남기며 메타 기록이 바뀐다 · 보너스는 결산 뒤 환승으로 넘어간다
    @Test func towerAndBonusSmoke() throws {
        var c = SimRunTests.harnessConfig(); c.mode = .tower
        let sim = Sim(data: SimRunTests.data, seed: 77, config: c)
        var ended: TowerResult?, floors = Set<Int>()
        for _ in 0..<(400 * 60) {
            for e in sim.step() { if case .towerEnded(let r) = e { ended = r }; if case .towerFloor(let f) = e { floors.insert(f) } }
            if sim.state == "over" { break }
        }
        let snap = sim.snapshot
        #expect(snap.tower != nil)
        #expect(floors.count >= 2)
        let r = try #require(ended)
        #expect(sim.meta.tower.runs == 1 && sim.meta.tower.best >= r.floor && sim.meta.tower.lv[0] != nil)
        if r.win { #expect(sim.meta.tower.ot == 1 && r.unlocked == 1) }

        var cb = SimRunTests.harnessConfig(); cb.mode = .bonus
        let sb = Sim(data: SimRunTests.data, seed: 5, config: cb)
        var res: BonusResult?
        var sawCar = false
        for _ in 0..<(60 * 60) {
            for e in sb.step() { if case .bonusEnded(let R) = e { res = R } }
            if let B = sb.snapshot.bonus { sawCar = sawCar || B.car.x == 330; #expect(sb.snapshot.actors.contains { $0.hidden && $0.isEnemy } || B.phase == "owner") }
            if sb.state == "transfer" { break }
        }
        #expect(sawCar)
        let R = try #require(res)
        #expect(sb.meta.bonusBest == R.total)
        #expect(sb.state == "transfer")
    }
}
