import Testing
import Foundation
@testable import BBSim

/// K 락스텝(tools/js/extract/storytrace.mjs --lockstep → Fixtures/sim/story_lockstep.json):
/// 프롤로그(지하 복도 → 거리 → 케인 → 첫 칸 이후까지) · 무도장(콤보 시연 21 · 기술 20 · 반응 · 적 공격 · 기타 · 필살기 · 허수아비 바꾸기 · 커스텀 · 예시 가방 경로) ·
/// 오늘의 노선(날짜 시드 가방 · 매점 · 각인) — 규칙 난수 자리 순서와 30프레임마다 상태가 웹과 같아야 한다.
/// 웹 setTimeout 은 하네스가 시뮬레이션 실제 시간 예약으로 바꿨다(Swift World.schedule 과 같은 규칙).
@Suite struct StoryLockstepTests {
    typealias JV = LockstepTests.JV
    struct Run: Decodable {
        let seed: UInt32; let kind: String; let seconds: Double; let kit: String?; let speed: Double?; let script: Bool?
        let cmds: [[JV]]?; let dateKey: String; let lock: [[JV]]; let rt: [[JV]]
    }
    struct File: Decodable { let runs: [Run] }

    static func config(_ r: Run) -> SimConfig {
        var c = SimRunTests.harnessConfig(kit: r.kit ?? "basic"); c.harnessWarmup = true; c.traceRandom = true
        switch r.kind {
        case "prologue": c.prologue = true
        case "daily": c.daily = true; c.dateKey = r.dateKey
        case "dojo": c.mode = .dojo
        default: break
        }
        return c
    }
    static func f(_ x: Double, _ d: Int) -> String { let s = JSFormat.fixed(x, d); let v = Double(s)!; return v == v.rounded() ? String(Int(v)) : String(v) }
    /// storytrace.mjs extra() 와 같은 꼬리 칸
    static func extra(_ w: World) -> String {
        let bagIDs = w.bag.map(\.id).joined(separator: ",")
        if let P = w.pr {
            let doors = P.doors.keys.sorted().map { "\($0)\(P.doors[$0]!.st)" }.joined(separator: ",")
            return "P:\(JSFormat.fixed(P.x, 1)):\(P.wi):\(P.bag):\(P.out):\(doors):\(w.tapW.map { "W" + JSFormat.fixed($0.t, 2) } ?? "-"):\(bagIDs)"
        }
        if let C = w.cn { return "C:\(C.stage):\(JSFormat.fixed(C.t, 3))" }
        if let K = w.kn { return "K:\(K.ph):\(JSFormat.fixed(K.t, 3)):\(bagIDs)" }
        if w.demo {
            let S = w.dj?.seq, D = w.dojoDummy()
            let sq = S.map { "\($0.i)/\($0.steps.count):\(JSFormat.fixed($0.t, 3))" } ?? "-"
            let dd = D.map { "\(JSFormat.fixed($0.x, 2)):\($0.anim):\($0.jug.map { JSFormat.fixed($0.h, 2) } ?? "-")" } ?? "-"
            return "D:\(sq):\(dd)"
        }
        return "\(f(w.tr.ex, 1)):\(bagIDs)"
    }
    /// 무도장 대본 한 줄 → World 함수(웹 하네스 DJC 와 같게 직접 부른다)
    static func dojo(_ w: World, _ c: [JV]) {
        let name = c[1].description
        func int(_ k: Int) -> Int { Int(c[k].description) ?? 0 }
        switch name {
        case "combo": w.dojoCombo(int(2))
        case "hero": w.dojoHero(c[2].description, { if case .null = c[3] { return nil }; return Int(c[3].description) }())
        case "misc": w.dojoMisc(c[2].description)
        case "special": w.dojoSpc(c[2].description)
        case "react": w.dojoReact(c[2].description)
        case "foe": w.dojoFoe(c[2].description)
        case "customRun": w.dojoCustomRun()
        case "dummy": w.dojoSetDummy(c[2].description)
        case "demoBag": w.dojoDemoBag(int(2))
        case "bagRoute": w.dojoBagRoute(int(2))
        case "reset": w.dojoReset(24)
        default: Issue.record("모르는 무도장 명령 \(name)")
        }
    }

    @Test func lockstepStory() throws {
        let url = SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/story_lockstep.json")
        guard let d = try? Data(contentsOf: url) else { Issue.record("story_lockstep.json 없음"); return }
        let F = try JSONDecoder().decode(File.self, from: d)
        var report = ""
        for r in F.runs {
            let sim = Sim(data: SimRunTests.data, seed: r.seed, config: Self.config(r))
            sim.apply(.setSpeed(r.speed ?? 1.25))
            let cmds = r.cmds ?? []
            var ci = 0
            var samples: [[String]] = []
            for i in 0..<Int(r.seconds * 60) {
                sim.w.frameNo = i
                while ci < cmds.count && Int(cmds[ci][0].description) == i { Self.dojo(sim.w, cmds[ci]); ci += 1 }
                if r.script == true { for it in LockstepTests.script(sim, i) { sim.apply(it) } }
                if i % 30 == 0 { var s = LockstepTests.sample(sim.w, i); s[s.count - 1] = Self.extra(sim.w); samples.append(s) }
                sim.step()
                if sim.state == "over" || sim.state == "end" { break }
            }
            let rt = sim.w.rtLog ?? []
            var firstRT = -1
            for k in 0..<min(rt.count, r.rt.count) where !(rt[k].0 == Int(r.rt[k][0].description)! && rt[k].1 == r.rt[k][1].description) { firstRT = k; break }
            if firstRT < 0 && rt.count != r.rt.count { firstRT = min(rt.count, r.rt.count) }
            var firstS = -1
            for k in 0..<min(samples.count, r.lock.count) where samples[k] != r.lock[k].map(\.description) { firstS = k; break }
            if firstS < 0 && samples.count != r.lock.count { firstS = min(samples.count, r.lock.count) }
            report += "seed \(r.seed) \(r.kind) \(r.kit ?? "") \(Int(r.seconds))초: 난수 자리 \(rt.count)/\(r.rt.count) 처음 어긋남 \(firstRT)"
            if firstRT >= 0 {
                let lo = max(0, firstRT - 3)
                report += "\n  웹   \(r.rt[lo..<min(r.rt.count, firstRT + 4)].map { "\($0[0])·\($0[1])" })\n  Swift \(rt[lo..<min(rt.count, firstRT + 4)].map { "\($0.0)·\($0.1)" })"
            }
            report += "\n  상태 표본 \(samples.count)/\(r.lock.count) 처음 어긋남 \(firstS)"
            if firstS >= 0 && firstS < samples.count && firstS < r.lock.count {
                report += "\n  웹   \(r.lock[firstS].map(\.description))\n  Swift \(samples[firstS])"
                if firstS > 0 { report += "\n  (앞 표본 웹 \(r.lock[firstS - 1].map(\.description)))" }
            }
            report += "\n"
            #expect(firstRT == -1, "seed \(r.seed) \(r.kind): 규칙 난수 자리가 \(firstRT) 번째에서 어긋남")
            #expect(firstS == -1, "seed \(r.seed) \(r.kind): 상태 표본이 \(firstS) 번째에서 어긋남")
        }
        print(report)
        if ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil {
            try? report.write(to: SimStatsTests.root.appending(path: "tools/js/out/sim/story_lockstep.txt"), atomically: true, encoding: .utf8)
        }
    }
}
