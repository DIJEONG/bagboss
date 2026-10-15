import Testing
import Foundation
@testable import BBSim

/// N5 모드 락스텝(tools/js/extract/modetrace.mjs --lockstep → Fixtures/sim/modes_lockstep.json):
/// 엘리베이터 타워(정시 · 야근 2~6 · 오늘의 타워 · 직접 조작 대본) · 보너스 차 부수기 — 규칙 난수 자리 순서와 30프레임마다 상태가 웹과 같아야 한다.
@Suite struct ModeLockstepTests {
    typealias JV = LockstepTests.JV
    struct Opts: Decodable { let script: Bool?; let speed: Double? }
    struct Run: Decodable { let seed: UInt32; let mode: String; let kit: String; let seconds: Double; let ot: Int; let daily: Bool; let opts: Opts?; let dateKey: String; let lock: [[JV]]; let rt: [[JV]] }
    struct File: Decodable { let runs: [Run] }

    static func config(_ r: Run) -> SimConfig {
        var c = SimRunTests.harnessConfig(kit: r.kit); c.harnessWarmup = true; c.traceRandom = true
        c.mode = r.mode == "tower" ? .tower : .bonus; c.towerOT = r.ot; c.daily = r.daily; c.dateKey = r.dateKey
        var m = SimMeta(); m.tower.ot = 6; c.initialMeta = m
        return c
    }
    static func extra(_ w: World) -> String {
        if let T = w.tw { return "\(T.floor):\(T.phase):\(JSFormat.fixed(T.pos, 1)):\(JSFormat.fixed(T.door, 2)):\(w.twWeight()):\(T.dark):\(T.outs):\(T.ceilN)" }
        if let B = w.bn { return "\(B.phase):\(JSFormat.fixed(B.hp, 1)):\(B.score):\(B.car.stage)" }
        return "-"
    }

    @Test func lockstepModes() throws {
        let url = SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/modes_lockstep.json")
        guard let d = try? Data(contentsOf: url) else { return }
        let F = try JSONDecoder().decode(File.self, from: d)
        var report = ""
        for r in F.runs {
            let sim = Sim(data: SimRunTests.data, seed: r.seed, config: Self.config(r))
            if let sp = r.opts?.speed { sim.apply(.setSpeed(sp)) }
            var samples: [[String]] = []
            for i in 0..<Int(r.seconds * 60) {
                sim.w.frameNo = i
                if r.opts?.script == true { for it in LockstepTests.script(sim, i) { sim.apply(it) } }
                if i % 30 == 0 { var s = LockstepTests.sample(sim.w, i); s[s.count - 1] = Self.extra(sim.w); samples.append(s) }
                sim.step()
                if sim.state == "over" || (r.mode == "bonus" && sim.state == "transfer") { break }
            }
            let rt = sim.w.rtLog ?? []
            var firstRT = -1
            for k in 0..<min(rt.count, r.rt.count) where !(rt[k].0 == Int(r.rt[k][0].description)! && rt[k].1 == r.rt[k][1].description) { firstRT = k; break }
            if firstRT < 0 && rt.count != r.rt.count { firstRT = min(rt.count, r.rt.count) }
            var firstS = -1
            for k in 0..<min(samples.count, r.lock.count) where samples[k] != r.lock[k].map(\.description) { firstS = k; break }
            if firstS < 0 && samples.count != r.lock.count { firstS = min(samples.count, r.lock.count) }
            report += "seed \(r.seed) \(r.mode) \(r.kit) 야근\(r.ot)\(r.daily ? " 오늘" : "") \(Int(r.seconds))초: 난수 자리 \(rt.count)/\(r.rt.count) 처음 어긋남 \(firstRT)"
            if firstRT >= 0 {
                let lo = max(0, firstRT - 3)
                report += "\n  웹   \(r.rt[lo..<min(r.rt.count, firstRT + 4)].map { "\($0[0])·\($0[1])" })\n  Swift \(rt[lo..<min(rt.count, firstRT + 4)].map { "\($0.0)·\($0.1)" })"
            }
            report += "\n  상태 표본 \(samples.count)/\(r.lock.count) 처음 어긋남 \(firstS)"
            if firstS >= 0 && firstS < samples.count && firstS < r.lock.count { report += "\n  웹   \(r.lock[firstS].map(\.description))\n  Swift \(samples[firstS])" }
            report += "\n"
            #expect(firstRT == -1, "seed \(r.seed): 규칙 난수 자리가 \(firstRT) 번째에서 어긋남")
            #expect(firstS == -1, "seed \(r.seed): 상태 표본이 \(firstS) 번째에서 어긋남")
        }
        print(report)
        if ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil {
            try? report.write(to: SimStatsTests.root.appending(path: "tools/js/out/sim/modes_lockstep.txt"), atomically: true, encoding: .utf8)
        }
    }
}
