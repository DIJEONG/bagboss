import Testing
import Foundation
@testable import BBSim

/// K 함수 픽스처(tools/js/extract/storytrace.mjs --fx → Fixtures/sim/story_fx.json):
/// TALK 대본 원문 · 대화 흐름(tkNext · tkPick 끼워 넣기 · 고른 값 · 줄 서기 · tkSkip) · talkOnce · 도움말 미루기 · HINTS 문구 · lampTick · doorTick · 스킨 미리보기
@Suite struct StoryFixtureTests {
    typealias JV = LockstepTests.JV
    nonisolated(unsafe) static let fx: [String: Any] = {
        let url = SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/story_fx.json")
        guard let d = try? Data(contentsOf: url), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }()
    /// 웹 TALK 줄(JSON) → TalkLine
    static func line(_ v: Any) -> TalkLine {
        let a = v as! [Any], who = a[0] as! String
        if who == "me" {
            return .choose((a[1] as! [Any]).map { o in
                let c = o as! [Any]
                return TalkChoice(c[0] as! String, (c[1] is NSNull) ? nil : line(c[1]), picked: c.count > 2 ? c[2] as? String : nil)
            })
        }
        return .say(who: who, text: a[1] as! String)
    }
    /// 웹 값(JSON) → 비교용 글(수는 소수 4자리까지 — JS toFixed 결과의 부동소수 꼬리를 지운다)
    static func cell(_ v: Any) -> String { if let n = v as? NSNumber, !(v is Bool) { return StoryLockstepTests.f(n.doubleValue, 4) }; return "\(v)" }
    static func world() -> World { Sim(data: SimRunTests.data, seed: 1, config: SimRunTests.harnessConfig()).w }

    @Test func talkScriptsMatchWeb() {
        guard let T = Self.fx["talk"] as? [String: Any] else { Issue.record("story_fx.json 없음"); return }
        for (k, v) in T {
            let web = (v as! [Any]).map(Self.line)
            let sw = TalkScripts.lines(k, bookName: k == "book" ? "하늘 난타" : nil)
            #expect(sw == web, "TALK.\(k) 대본이 웹과 다르다")
        }
        // talkSoon 열쇠 → 대본
        let w = Self.world()
        #expect(w.talkLines("st", nil) == TalkScripts.lines("starter"))
        #expect(w.talkLines("book1", "airrush")?.first == .say(who: "minnie", text: "호외요! <b>하늘 난타</b>, 콤보 도감 첫 완성이에요!"))
        // CAST
        #expect(w.sd.cast["saboo"]?.n == "사보" && w.sd.cast["me"]?.c == "#cfc6e6")
    }

    @Test func talkFlowMatchesWeb() {
        guard let F = Self.fx["flow"] as? [String: Any], let rows = F["flow"] as? [[Any]], let log = F["log"] as? [String] else { Issue.record("flow 없음"); return }
        let w = Self.world(), lines = (F["lines"] as! [Any]).map(Self.line)
        var out: [[String]] = [], got: [String] = []
        func snap(_ tag: String) {
            guard let T = w.talkRun else { out.append([tag, "-1", "0", "-"]); return }
            let cur: String
            if let c = T.choices { cur = c.map(\.text).joined(separator: "|") }
            else if case .say(let who, let text) = T.lines[T.i] { cur = "\(who):\(text)" } else { cur = "?" }
            out.append([tag, "\(T.i)", "\(T.lines.count)", cur])
        }
        w.talk("t1", lines) { _, p in got.append("done1:\(p ?? "null")") }; snap("start")
        w.talk("t2", [.say(who: "cond", text: "줄 선 대화")]) { _, p in got.append("done2:\(p ?? "null")") }; snap("queued")
        for a in F["actions"] as! [String] { if a == "next" { w.tkTap() } else { w.tkPick(Int(a.dropFirst(4))!) }; snap(a) }
        w.talk("t3", lines) { _, p in got.append("done3:\(p ?? "null")") }; w.tkNext(); w.tkPick(1); snap("pick1"); w.tkSkip(); snap("skip")
        let web = rows.map { $0.map { "\($0)" } }
        #expect(out == web, "대화 흐름이 웹과 다르다\n웹 \(web)\nSwift \(out)")
        #expect(got == log)
        // talkOnce: 건너뛰기(웹 자동 점검) → done 만 · 기록 없음 / 한 번 한 열쇠 → done 만
        if let once = Self.fx["once"] as? [String] {
            var L: [String] = []
            w.meta.talks = []; w.config.skipTalks = true; w.talkOnce("x1", [.say(who: "cond", text: "a")]) { _, _ in L.append("skip") }
            #expect(!w.meta.talks.contains("x1"))
            w.config.skipTalks = false; w.talkOnce("x2", [.say(who: "cond", text: "b")]) { _, _ in L.append("done") }; w.tkSkip()
            w.talkOnce("x2", [.say(who: "cond", text: "b")]) { _, _ in L.append("again") }
            #expect(L == once)
        }
    }

    @Test func hintDeferral() {
        guard let H = Self.fx["hint"] as? [[String: Any]], let texts = Self.fx["hints"] as? [String: [String]] else { Issue.record("hint 없음"); return }
        for row in H {
            let w = Self.world(), k = row["k"] as! String
            w.meta.hints = []
            switch k {
            case "cine": w.cn = CineRun()
            case "bonus": w.bonus = true
            case "pBag": w.pBag = true
            case "kane": w.kn = KaneRun(held: [])
            default: break
            }
            let r1 = w.hint("move"), had = w.meta.hints.contains("move"), r2 = w.hint("move"), r3 = w.hint("nope")
            #expect([r1, had, r2, r3] == [row["r1"] as! Bool, row["had"] as! Bool, row["r2"] as! Bool, row["r3"] as! Bool], "hint 미루기 \(k)")
        }
        let w = Self.world()
        for (k, v) in texts { #expect(w.sd.hints[k]?.0 == v[0] && w.sd.hints[k]?.1 == v[1], "HINTS.\(k)") }
        // 도움말 문구는 0.4초 뒤(웹 setTimeout(say, 400)) 4.2초 동안 스냅숏 hint 로
        let sim = Sim(data: SimRunTests.data, seed: 3, config: SimRunTests.harnessConfig())
        sim.w.meta.hints = []; _ = sim.w.hint("timer")
        for _ in 0..<20 { sim.step() }
        #expect(sim.snapshot.hint == nil)
        for _ in 0..<10 { sim.step() }
        #expect(sim.snapshot.hint?.key == "timer" && sim.snapshot.hint?.title == "시간제 운행")
        for _ in 0..<(60 * 5) { sim.step() }
        #expect(sim.snapshot.hint == nil)
    }

    @Test func lampTickMatchesWeb() {
        guard let rows = Self.fx["lamp"] as? [[Any]] else { Issue.record("lamp 없음"); return }
        let w = Self.world(); w.rndFixed = 0.5; w.fxFixed = 0.5
        w.startPrologue(); let P = w.pr!
        P.lamps = [60: CorrLamp(a: 0.3, v: 0), 260: CorrLamp(a: -0.2, v: 1.5)]
        var k = 0
        for i in 0..<90 {
            w.lampTick(1.0 / 60)
            if i % 10 == 9 {
                let r = rows[k].map { ($0 as! NSNumber).doubleValue }; k += 1
                let s = [P.lamps[60]!.a, P.lamps[60]!.v, P.lamps[260]!.a, P.lamps[260]!.v]
                for j in 0..<4 { #expect(abs(r[j] - s[j]) < 1e-8, "lampTick \(i) \(j): 웹 \(r[j]) Swift \(s[j])") }
            }
        }
        w.lampKick(100, 1.6)
        let kick = (rows.last as! [[NSNumber]]).map { ($0[0].intValue, $0[1].doubleValue) }
        let sk = P.lamps.keys.sorted().map { ($0, P.lamps[$0]!.v) }
        #expect(kick.map(\.0) == sk.map(\.0))
        for (a, b) in zip(kick, sk) { #expect(abs(a.1 - b.1) < 1e-8, "lampKick \(a.0)") }
    }

    @Test func doorTickMatchesWeb() {
        guard let D = Self.fx["door"] as? [[String: Any]] else { Issue.record("door 없음"); return }
        for c in D {
            let px = (c["px"] as! NSNumber).doubleValue, bag = c["bag"] as! Bool, cam = (c["cam"] as! NSNumber).doubleValue, rv = (c["rv"] as! NSNumber).doubleValue
            let w = Self.world(); w.rndFixed = rv; w.fxFixed = 0.5
            w.startPrologue(); let P = w.pr!
            P.x = px; P.bag = bag; P.bangT = 0.05; w.camX = cam
            #expect(w.viewW == (c["vw"] as! NSNumber).doubleValue)
            var rows: [[String]] = []
            for i in 0..<300 {
                w.doorTick(1.0 / 30)
                if i % 15 == 0 {
                    let doors = P.doors.keys.sorted().map { k in let d = P.doors[k]!; return "\(k):\(d.st):\(d.n.map(String.init) ?? "-"):\(d.n == nil && d.max == 0 ? "-" : String(d.max)):\(d.burst)" }.joined(separator: ",")
                    let foes = w.ents.filter { $0.e != nil }.map { "\($0.e!.t)@\(JSFormat.fixed($0.x, 2)):\($0.flip):\(JSFormat.fixed($0.e!.cdT, 2))" }.joined(separator: " ")
                    rows.append(["\(i)", doors, StoryLockstepTests.f(P.bangT!, 4), foes])
                }
            }
            let web = (c["rows"] as! [[Any]]).map { $0.map(Self.cell) }
            #expect(rows == web, "doorTick px \(px) rv \(rv)\n웹 \(web.prefix(6))\nSwift \(rows.prefix(6))")
        }
    }

    @Test func skinPreviewMatchesWeb() {
        guard let S = Self.fx["skinPv"] as? [String: Any], let rows = S["rows"] as? [[Any]] else { Issue.record("skinPv 없음"); return }
        let sim = Sim(data: SimRunTests.data, seed: 5, config: SimRunTests.harnessConfig()); let w = sim.w
        w.rndFixed = 0.5; w.fxFixed = 0.5
        sim.apply(.skinPreview(.open))
        #expect(w.skinPv?.cx == (S["cx"] as! NSNumber).doubleValue)
        let H = w.hero!; var acc = 0.0, k = 0
        let step = 1 / w.animFps
        for i in 0..<600 {
            acc += 1.0 / 60; var n = 0
            while acc >= step && n < 8 { acc -= step; n += 1; w.stepAnim() }
            w.gameUpdate(1.0 / 60); if acc > step { acc = 0 }
            if i % 15 == 14 {
                let r = rows[k].map(Self.cell); k += 1
                let sw = ["\(i)", StoryLockstepTests.f(H.x, 3), StoryLockstepTests.f(H.y, 3), H.anim, H.flip ? "1" : "0", StoryLockstepTests.f(w.skinPv!.spin, 4), "\(w.skinPv!.ph)", StoryLockstepTests.f(w.camZ, 3)]
                #expect(sw == r, "skinPv \(i): 웹 \(r) Swift \(sw)")
            }
        }
        sim.apply(.skinPreview(.close)); #expect(w.skinPv == nil && !H.hidden)
    }
}
