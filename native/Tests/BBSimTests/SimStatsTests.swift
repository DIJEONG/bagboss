import Testing
import Foundation
@testable import BBSim
import BBContent

/// 웹 기준선(tools/js/extract/simtrace.mjs → Fixtures/sim/baseline.json)과 '분포'로 비교한다(docs/06 §4-4).
/// 같은 씨앗 · 같은 조건(1노선 · 기본 가방 · 90초 · 자동 전투 · 매점/정리 자동)으로 N판 돌려 평균 · 표준편차를 맞댄다.
/// BB_SIM_STATS=1 이면 결과 표를 tools/js/out/sim/compare.md 에 쓴다.
@Suite struct SimStatsTests {
    struct Baseline: Decodable {
        let seconds: Double, stage: Int, kit: String
        let results: [Row]
        struct Row: Decodable {
            let seed: UInt32; let t: Double; let state: String; let ci: Int; let hp: Double; let score: Double; let kills: Double
            let dealt: Double; let taken: Double; let crits: Double; let maxCombo: Double; let links: Double
            let combos: Double?, walls: Double?, bowls: Double?, stag: Double?, flanks: Double?, tokens: Double?, onTime: Double?, outs: Double?, chits: Double?, justs: Double?
            let byCar: [Car?]?
        }
        struct Car: Decodable { let taken: Double; let dealt: Double; let kills: Double; let t: Double }
    }
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func loadBaseline(_ name: String = "baseline.json") throws -> Baseline {
        let url = root.appending(path: "native/Tests/Fixtures/sim/\(name)")
        return try JSONDecoder().decode(Baseline.self, from: Data(contentsOf: url))
    }

    struct Res { var t = 0.0, state = "", ci = 0, hp = 0.0, score = 0.0, kills = 0.0, dealt = 0.0, taken = 0.0, crits = 0.0, maxCombo = 0.0, links = 0.0
        var combos = 0.0, walls = 0.0, bowls = 0.0, stag = 0.0, flanks = 0.0, tokens = 0.0, onTime = 0.0, outs = 0.0, chits = 0.0, justs = 0.0
        var byCar: [Baseline.Car] = [] }

    static func run(seed: UInt32, seconds: Double, stage: Int, kit: String) -> Res {
        let sim = Sim(data: SimRunTests.data, seed: seed, config: SimRunTests.harnessConfig(stage: stage, kit: kit))
        var t = 0.0
        var car: [(taken: Double, dealt: Double, kills: Double, t: Double, t0: Double, d0: Double, k0: Double)] = []
        for _ in 0..<Int(seconds * 60) {
            do { let w = sim.w; while car.count <= w.ci { car.append((0, 0, 0, 0, w.stats.taken, w.stats.dealt, Double(w.kills))) }
                 car[w.ci].taken = (w.stats.taken - car[w.ci].t0).rounded(); car[w.ci].dealt = (w.stats.dealt - car[w.ci].d0).rounded(); car[w.ci].kills = Double(w.kills) - car[w.ci].k0; car[w.ci].t += 1.0 / 60 }
            sim.step(); t += 1.0 / 60
            if sim.state == "over" || sim.state == "end" { break }
        }
        let s = sim.snapshot, st = s.stats
        return Res(t: t, state: s.state, ci: s.car, hp: s.hp, score: Double(s.score), kills: Double(s.kills), dealt: st.dealt.rounded(), taken: st.taken.rounded(),
                   crits: Double(st.crits), maxCombo: Double(st.maxCombo), links: Double(st.links), combos: Double(st.combos), walls: Double(st.walls), bowls: Double(st.bowls),
                   stag: Double(st.stag), flanks: Double(st.flanks), tokens: Double(s.tokens), onTime: Double(st.onTime), outs: Double(st.outs), chits: Double(st.chits), justs: Double(st.justs),
                   byCar: car.map { Baseline.Car(taken: $0.taken, dealt: $0.dealt, kills: $0.kills, t: $0.t) })
    }
    static func ms(_ v: [Double]) -> (m: Double, s: Double) {
        let m = v.reduce(0, +) / Double(max(1, v.count))
        let s = (v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(1, v.count))).squareRoot()
        return (m, s)
    }

    /// 표 한 줄: 이름 · 웹 평균±표준편차 · Swift 평균±표준편차 · 차이(%)
    static func table(_ web: [Baseline.Row], _ sw: [Res]) -> (String, [String: Double]) {
        let rows: [(String, (Baseline.Row) -> Double?, (Res) -> Double)] = [
            ("t(끝)", { $0.t }, { $0.t }), ("kills", { $0.kills }, { $0.kills }), ("dealt", { $0.dealt }, { $0.dealt }), ("taken", { $0.taken }, { $0.taken }),
            ("score", { $0.score }, { $0.score }), ("maxCombo", { $0.maxCombo }, { $0.maxCombo }), ("reached car(ci)", { Double($0.ci) }, { Double($0.ci) }),
            ("hp(끝)", { $0.hp }, { $0.hp }), ("crits", { $0.crits }, { $0.crits }), ("links", { $0.links }, { $0.links }), ("combos", { $0.combos }, { $0.combos }),
            ("walls", { $0.walls }, { $0.walls }), ("bowls", { $0.bowls }, { $0.bowls }), ("stag", { $0.stag }, { $0.stag }), ("flanks", { $0.flanks }, { $0.flanks }),
            ("tokens", { $0.tokens }, { $0.tokens }), ("onTime", { $0.onTime }, { $0.onTime }), ("outs", { $0.outs }, { $0.outs }), ("chits", { $0.chits }, { $0.chits }),
        ]
        var md = "| 지표 | 웹 평균 ± 표준편차 | Swift 평균 ± 표준편차 | 차이 |\n|---|---:|---:|---:|\n"
        var diffs: [String: Double] = [:]
        for (n, fw, fs) in rows {
            let a = ms(web.compactMap(fw)), b = ms(sw.map(fs))
            let d = a.m != 0 ? (b.m - a.m) / abs(a.m) * 100 : 0
            diffs[n] = d
            md += String(format: "| %@ | %.2f ± %.2f | %.2f ± %.2f | %+.1f%% |\n", n, a.m, a.s, b.m, b.s, d)
        }
        let nc = max(web.map { $0.byCar?.count ?? 0 }.max() ?? 0, sw.map { $0.byCar.count }.max() ?? 0)
        if nc > 0 && web.contains(where: { $0.byCar != nil }) {
            md += "\n| 칸 | 웹 받은 피해 | Swift 받은 피해 | 웹 준 피해 | Swift 준 피해 | 웹 처치 | Swift 처치 | 웹 시간 | Swift 시간 | 도달(웹/Swift) |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
            for c in 0..<nc {
                let wc = web.compactMap { r -> Baseline.Car? in guard let b = r.byCar, b.count > c else { return nil }; return b[c] }, sc = sw.compactMap { $0.byCar.count > c ? $0.byCar[c] : nil }
                func m(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.reduce(0, +) / Double(a.count) }
                md += String(format: "| %d | %.1f | %.1f | %.1f | %.1f | %.2f | %.2f | %.1f | %.1f | %d/%d |\n", c, m(wc.map(\.taken)), m(sc.map(\.taken)), m(wc.map(\.dealt)), m(sc.map(\.dealt)),
                              m(wc.map(\.kills)), m(sc.map(\.kills)), m(wc.map(\.t)), m(sc.map(\.t)), wc.count, sc.count)
            }
            md += "\n"
        }
        let survW = Double(web.filter { $0.state != "over" }.count) / Double(web.count), survS = Double(sw.filter { $0.state != "over" }.count) / Double(sw.count)
        md += String(format: "| 생존율 | %.0f%% | %.0f%% | |\n", survW * 100, survS * 100)
        return (md, diffs)
    }

    static let files = ["baseline.json", "baseline_long.json", "baseline_grap.json", "baseline_foot.json", "baseline_link.json", "baseline_stage2.json"]

    /// 핵심 지표의 평균 차이를 표준오차로 잰다(z) — 표본이 적은 판(다 죽는 가방)에서도 우연과 치우침을 가른다
    static func zScores(_ web: [Baseline.Row], _ sw: [Res]) -> [String: Double] {
        let core: [(String, (Baseline.Row) -> Double, (Res) -> Double)] = [("kills", { $0.kills }, { $0.kills }), ("dealt", { $0.dealt }, { $0.dealt }),
            ("taken", { $0.taken }, { $0.taken }), ("score", { $0.score }, { $0.score }), ("maxCombo", { $0.maxCombo }, { $0.maxCombo }), ("t", { $0.t }, { $0.t })]
        var z: [String: Double] = [:]
        for (n, fw, fs) in core {
            let a = ms(web.map(fw)), b = ms(sw.map(fs))
            let se = (a.s * a.s / Double(web.count) + b.s * b.s / Double(sw.count)).squareRoot()
            z[n] = se > 1e-6 ? (b.m - a.m) / se : 0
        }
        return z
    }

    static func compare(_ file: String) throws -> (md: String, diffs: [String: Double], z: [String: Double])? {
        guard let B = try? Self.loadBaseline(file) else { return nil }
        let sw = B.results.map { Self.run(seed: $0.seed, seconds: B.seconds, stage: B.stage, kit: B.kit) }
        let (md, diffs) = Self.table(B.results, sw)
        let z = Self.zScores(B.results, sw)
        let zs = z.keys.sorted().map { String(format: "%@ %+.2f", $0, z[$0]!) }.joined(separator: " · ")
        let head = "## \(file) — 노선 \(B.stage) · 가방 \(B.kit) · \(Int(B.seconds))초 · 씨앗 \(B.results.count)개\n\n"
        return (head + md + "\n평균 차이 / 표준오차(z): " + zs + "\n\n", diffs, z)
    }

    /// 기본은 90초 기준선만(빠름). BB_SIM_STATS=1 이면 전부 + 표 파일
    @Test(arguments: files) func distributionMatchesWeb(_ file: String) throws {
        let full = ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil
        if !full && file != "baseline.json" { return }
        guard let (md, diffs, z) = try Self.compare(file) else { return }   // 기준선이 아직 없으면 건너뜀
        if full { print(md) }
        // 핵심 지표: 평균 차이가 표준오차 3.5배 안(치우침 없음) — 90초 기준선은 평균 15% 안도 함께
        for (k, v) in z { #expect(abs(v) < 3.5, "\(file) \(k) z=\(v)") }
        if file == "baseline.json" { for k in ["kills", "dealt", "score", "maxCombo"] { #expect(abs(diffs[k]!) < 15, "\(file) \(k) 차이 \(diffs[k]!)%") } }
    }

    /// BB_SIM_STATS=1: 모든 기준선 표를 한 파일로(tools/js/out/sim/compare.md)
    @Test func writeCompareReport() throws {
        guard ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil else { return }
        var md = "# 시뮬레이션 통계 대조 — 웹 simtrace ↔ Swift BBSim\n\n"
        md += "같은 씨앗 · 같은 조건(자동 전투 · 직접 조작 없음 · 매점 첫 카드/정리 바로 출발 · 게임 속도 1 · 렌더 없음). 웹은 연출 난수도 같은 수열에서 뽑아 판이 갈라지므로 '분포'로 맞댄다.\n"
        md += "같은 판(락스텝)은 LockstepTests(웹 규칙 자리만 시드 수열) — 28판 전부 프레임 단위 일치.\n\n"
        for f in Self.files { if let (m, _, _) = try Self.compare(f) { md += m } }
        let out = Self.root.appending(path: "tools/js/out/sim")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try md.write(to: out.appending(path: "compare.md"), atomically: true, encoding: .utf8)
    }
}
