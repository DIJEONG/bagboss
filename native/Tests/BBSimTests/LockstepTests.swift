import Testing
import Foundation
@testable import BBSim

/// 락스텝 대조(tools/js/extract/simtrace.mjs --lockstep → Fixtures/sim/lockstep.json):
/// 웹은 '규칙 자리'(Swift 가 난수를 쓰는 웹 줄)에서만 시드 수열을 쓰고 연출 난수는 다른 수열로 돌린다 →
/// 같은 씨앗이면 규칙 난수 소비 순서가 같아야 하고, 같은 판(30프레임마다 상태)이 나와야 한다.
/// 어긋나면 처음 어긋난 프레임 · 자리를 알려 준다(이식 버그 위치).
@Suite struct LockstepTests {
    struct File: Decodable { let runs: [Run] }
    struct Opts: Decodable { let autoSpc: Bool?; let speed: Double?; let script: Bool?; let bag: [[JV]]? }
    struct Run: Decodable { let seed: UInt32; let kit: String; let stage: Int?; let seconds: Double; let opts: Opts?; let lock: [[JV]]; let rt: [[JV]] }
    enum JV: Decodable, CustomStringConvertible {
        case n(Double), s(String), b(Bool), null
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if c.decodeNil() { self = .null } else if let x = try? c.decode(Double.self) { self = .n(x) } else if let x = try? c.decode(Bool.self) { self = .b(x) } else { self = .s(try c.decode(String.self)) }
        }
        var description: String { switch self { case .n(let x): return x == x.rounded() ? String(Int(x)) : String(x); case .s(let s): return s; case .b(let b): return "\(b)"; case .null: return "null" } }
    }

    /// 웹 simtrace 대본과 같은 직접 조작(프레임 i 시작에)
    static func script(_ sim: Sim, _ i: Int) -> [SimIntent] {
        let w = sim.w
        guard w.on, let H = w.hero, !H.dead else { return [] }
        var out: [SimIntent] = []
        func F() -> [Actor] { stableSortD(w.ents.filter { $0.e != nil && !$0.dead }) { abs($0.x - H.x) - abs($1.x - H.x) } }
        // 웹은 차례로 바로 부른다 — 앞 의도의 결과를 보고 다음을 정하므로 여기서도 하나씩 적용한다
        if i % 37 == 0, let f = F().first { sim.apply(.tap(side: f.x >= H.x ? 1 : -1, at: sim.clock)) }
        if i % 211 == 0 { sim.apply(.duck(at: sim.clock)) }
        if i % 97 == 0 { sim.apply(.special) }
        if i % 53 == 0, let A = F().first(where: { $0.action != nil && !$0.action!.fired && w.data.foeW[$0.anim] != nil && abs($0.x - H.x) < 46 }) { sim.apply(.tap(side: A.x >= H.x ? 1 : -1, at: sim.clock)) }
        return out
    }
    static func sample(_ w: World, _ i: Int) -> [String] {
        func f(_ x: Double, _ d: Int) -> String { let s = JSFormat.fixed(x, d); let v = Double(s)!; return v == v.rounded() ? String(Int(v)) : String(v) }
        let foes = w.ents.filter { $0.e != nil && !$0.dead }.map { "\($0.e!.t)@\(JSFormat.fixed($0.x, 1)):\($0.anim):\(jsRoundI($0.e!.hp))" }.joined(separator: " ")
        return ["\(i)", w.state, "\(w.ci)", f(w.time, 3), f(w.hp, 2), "\(w.score)", "\(w.kills)", f(w.hero.x, 2), w.hero.anim, w.combo == 0 && w.lastHit == nil ? "null" : "\(w.combo)", foes, f(w.tr.ex, 1)]
    }

    @Test func lockstepAgainstWeb() throws {
        let url = SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/lockstep.json")
        guard let d = try? Data(contentsOf: url) else { return }
        let F = try JSONDecoder().decode(File.self, from: d)
        var report = ""
        for r in F.runs {
            var c = SimRunTests.harnessConfig(stage: r.stage ?? 0, kit: r.kit); c.harnessWarmup = true; c.traceRandom = true
            if r.opts?.autoSpc == true { c.autoSpecial = true }
            if let sp = r.opts?.speed { c.playSpeed = sp }
            if let bg = r.opts?.bag { c.customBag = bg.map { BagItem(id: $0[0].description, uid: 0, x: Int($0[1].description)!, y: Int($0[2].description)!, rot: Int($0[3].description)!) } }
            let sim = Sim(data: SimRunTests.data, seed: r.seed, config: c)
            var samples: [[String]] = []
            for i in 0..<Int(r.seconds * 60) {
                if r.opts?.script == true { for it in Self.script(sim, i) { sim.apply(it) } }
                if i % 30 == 0 { samples.append(Self.sample(sim.w, i)) }
                sim.step()
                if sim.state == "over" || sim.state == "end" { break }
            }
            let rt = sim.w.rtLog ?? []
            var firstRT = -1
            for k in 0..<min(rt.count, r.rt.count) where !(rt[k].0 == Int(r.rt[k][0].description)! && rt[k].1 == r.rt[k][1].description) { firstRT = k; break }
            if firstRT < 0 && rt.count != r.rt.count { firstRT = min(rt.count, r.rt.count) }
            var firstS = -1
            for k in 0..<min(samples.count, r.lock.count) where samples[k] != r.lock[k].map(\.description) { firstS = k; break }
            report += "seed \(r.seed) \(r.kit) 노선\(r.stage ?? 0) \(Int(r.seconds))초: 난수 자리 \(rt.count)/\(r.rt.count) 처음 어긋남 \(firstRT)"
            if firstRT >= 0 {
                let lo = max(0, firstRT - 3)
                report += "\n  웹   \(r.rt[lo..<min(r.rt.count, firstRT + 4)].map { "\($0[0])·\($0[1])" })\n  Swift \(rt[lo..<min(rt.count, firstRT + 4)].map { "\($0.0)·\($0.1)" })"
            }
            report += "\n  상태 표본 \(samples.count)/\(r.lock.count) 처음 어긋남 \(firstS)"
            if firstS >= 0 { report += "\n  웹   \(r.lock[firstS].map(\.description))\n  Swift \(samples[firstS])" }
            report += "\n"
            #expect(firstRT == -1, "seed \(r.seed): 규칙 난수 자리가 \(firstRT) 번째에서 어긋남")
            #expect(firstS == -1, "seed \(r.seed): 상태 표본이 \(firstS) 번째에서 어긋남")
        }
        print(report)
        if ProcessInfo.processInfo.environment["BB_SIM_STATS"] != nil {
            try? report.write(to: SimStatsTests.root.appending(path: "tools/js/out/sim/lockstep.txt"), atomically: true, encoding: .utf8)
        }
    }
}

/// 세밀 대조(개발용): BB_FINE=파일(simtrace.mjs --fine 결과) 이면 그 구간을 프레임마다 맞대고 처음 어긋난 곳을 찍는다
@Suite struct LockstepFineTests {
    static func n(_ x: Double, _ d: Int) -> String { let v = Double(JSFormat.fixed(x, d))!; return v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : "\(v)" }
    static func row(_ w: World, _ i: Int) -> [String] {
        let H = w.hero!
        let foes = w.ents.filter { $0.e != nil && !$0.dead }.map { a in
            [a.e!.t, n(a.x, 3), a.anim, a.pose, "\(a.si)", "\(a.hold)", "\(a.hs)", n(a.e!.hp, 1), n(a.e!.cdT, 3), n(a.e!.stun, 3), a.jug.map { n($0.h, 2) } ?? "", n(a.kb, 2)].joined(separator: ",")
        }.joined(separator: " | ")
        return ["\(i)", n(w.time, 4), n(w.slowT, 4), n(w.spcTime, 4), n(w.acc, 4), "\(w.freeze)", H.anim, H.pose, "\(H.si)", "\(H.hold)", "\(H.hs)", n(H.x, 3), n(w.sp, 2), "\(w.score)", foes]
    }
    @Test func fineWindow() throws {
        guard let p = ProcessInfo.processInfo.environment["BB_FINE"] else { return }
        struct F: Decodable { let seed: UInt32; let kit: String; let seconds: Double; let from: Int; let to: Int; let fine: [[LockstepTests.JV]] }
        let f = try JSONDecoder().decode(F.self, from: Data(contentsOf: URL(fileURLWithPath: p)))
        var c = SimRunTests.harnessConfig(kit: f.kit); c.harnessWarmup = true; c.traceRandom = true
        let sim = Sim(data: SimRunTests.data, seed: f.seed, config: c)
        var k = 0, prev: [String] = [], prevW: [String] = []
        for i in 0...f.to {
            if i >= f.from {
                let mine = Self.row(sim.w, i), web = f.fine[k].map(\.description); k += 1
                if mine != web {
                    print("처음 어긋남 프레임 \(i)\n  웹 이전  \(prevW)\n  Sw 이전  \(prev)\n  웹   \(web)\n  Swift \(mine)")
                    for (j, (a, b)) in zip(web, mine).enumerated() where a != b { print("  필드 \(j): 웹 \(a) ↔ Swift \(b)") }
                    return
                }
                prev = mine; prevW = web
            }
            sim.step()
        }
        print("구간 \(f.from)…\(f.to) 모두 같음")
    }
}
