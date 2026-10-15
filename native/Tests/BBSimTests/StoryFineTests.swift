import Testing
import Foundation
@testable import BBSim

/// 세밀 비교(디버그): BB_STORY_FINE="seed kind kit from to [script]" 이면 storytrace.mjs --fine 과 같은 프레임별 값을 tools/js/out/sim/story_fine_swift.txt 에 쓴다.
/// 웹 쪽: node tools/js/extract/storytrace.mjs --fine seed kind kit 초 from to [script] --fine-out <파일>
@Suite struct StoryFineTests {
    @Test func fineWindow() throws {
        guard let spec = ProcessInfo.processInfo.environment["BB_STORY_FINE"] else { return }
        let p = spec.split(separator: " ").map(String.init)
        let seed = UInt32(p[0])!, kind = p[1], kit = p[2], from = Int(p[3])!, to = Int(p[4])!, script = p.count > 5 && p[5] == "script"
        let D = try JSONDecoder().decode(StoryLockstepTests.File.self, from: Data(contentsOf: SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/story_lockstep.json")))
        let cmds = D.runs.first { $0.kind == "dojo" }?.cmds ?? []
        let r = StoryLockstepTests.Run(seed: seed, kind: kind, seconds: Double(to) / 60 + 1, kit: kit, speed: nil, script: script, cmds: kind == "dojo" ? cmds : nil, dateKey: D.runs.first { $0.kind == "daily" }?.dateKey ?? "", lock: [], rt: [])
        let sim = Sim(data: SimRunTests.data, seed: seed, config: StoryLockstepTests.config(r))
        sim.apply(.setSpeed(1.25))
        var out = ""; var ci = 0
        func f(_ x: Double, _ d: Int) -> String { StoryLockstepTests.f(x, d) }
        for i in 0...to {
            sim.w.frameNo = i
            while ci < cmds.count && kind == "dojo" && Int(cmds[ci][0].description) == i { StoryLockstepTests.dojo(sim.w, cmds[ci]); ci += 1 }
            if script { for it in LockstepTests.script(sim, i) { sim.apply(it) } }
            if i >= from {
                let H = sim.w.hero!
                let foes = sim.w.ents.filter { $0.e != nil }.map { a in [a.e!.t, f(a.x, 3), a.anim, a.pose, f(a.kb, 3), a.jug.map { f($0.vx, 3) } ?? ""].joined(separator: ",") }.joined(separator: " | ")
                out += "[\(i), \(f(H.x, 3)), \(H.anim), \(H.pose), \(H.si), \(H.hold), \(f(sim.w.time, 4)), \(f(sim.w.acc, 4)), \(f(H.dash, 3)), \(f(H.dashT, 3)), \(f(H.kb, 3)), \(foes)]\n"
            }
            sim.step()
        }
        try out.write(to: SimStatsTests.root.appending(path: "tools/js/out/sim/story_fine_swift.txt"), atomically: true, encoding: .utf8)
    }
}
