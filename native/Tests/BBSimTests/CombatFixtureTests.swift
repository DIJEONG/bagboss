import Testing
import Foundation
@testable import BBSim
import BBContent

/// 웹 전투 규칙 함수 픽스처(tools/js/extract/combatfx.mjs → Fixtures/sim/combat.json) 대조.
/// 웹은 Math.random=0.5 고정 — Swift 도 rndFixed=0.5 (난수 소비 횟수가 달라도 같은 값).
@Suite struct CombatFixtureTests {
    nonisolated(unsafe) static let fx: [String: Any] = {
        let url = SimStatsTests.root.appending(path: "native/Tests/Fixtures/sim/combat.json")
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }()
    static func list(_ k: String) -> [[String: Any]] { fx[k] as! [[String: Any]] }

    static func world() -> World {
        var c = SimRunTests.harnessConfig(); c.autoAdvance = false
        let w = World(data: SimRunTests.data, seed: 1, config: c)
        w.rndFixed = 0.5; w.startRun()
        return w
    }
    static func reset(_ w: World) {
        let H = w.hero!
        w.ents = [H]; H.x = 200; H.flip = false; H.anim = "idle"; H.si = 0; H.action = nil; H.queue = []; H.hs = 0; H.kb = 0; H.dead = false; H.jug = nil
        w.spc = nil; w.cut = nil; w.croute = nil; w.combo = 0; w.lastHit = nil; w.time = 10; w.sp = 0; w.score = 0; w.bossBreak = nil; w.hp = w.maxHP; w.slowT = 0
        w.stats = RunStats(); w.curSrc = nil; w.ci = 0; w.stageIdx = 0; w.hurtAt = nil; w.freeze = 0; w.shots = []; w.items = []
    }
    static func spawn(_ w: World, _ t: String, _ dx: Double) -> Actor {
        w.spawnWave([t], fromDoors: false); w.cut = nil
        let T = w.ents.last!; T.x = 200 + dx; T.flip = dx > 0; T.anim = "idle"; T.si = 0; T.hs = 0; T.kb = 0
        return T
    }
    static func opts(_ o: [String: Any]) -> HitOpts {
        var h = HitOpts()
        h.crit = o["crit"] as? Bool ?? false; h.bigCrit = o["bigCrit"] as? Bool ?? false; h.knock = o["knock"] as? Bool ?? false
        h.back = o["back"] as? Bool ?? false; h.blast = o["blast"] as? Bool ?? false; h.counter = o["counter"] as? Bool ?? false
        h.just = o["just"] as? Bool ?? false; h.splash = o["splash"] as? Bool ?? false; h.react = o["react"] as? String
        return h
    }
    static func r4(_ x: Double) -> Double { jsRound(x * 1e4) / 1e4 }
    static func num(_ a: Any?) -> Double? { (a as? NSNumber)?.doubleValue }
    static func close(_ a: Double?, _ b: Any?, _ tol: Double = 2e-4) -> Bool {
        if a == nil { return b == nil || b is NSNull }
        guard let bb = num(b) else { return false }
        return abs(r4(a!) - bb) <= tol
    }

    @Test func reactKeyAndDeathOf() {
        let w = Self.world()
        var bad = 0
        for r in Self.list("reactKey") {
            let att = w.mkActor(.hero(), x: 0); att.anim = r["anim"] as! String
            let rk = w.reactKey(att, Self.opts(r["o"] as! [String: Any]))
            if rk != r["rk"] as! String { bad += 1; if bad < 5 { Issue.record("reactKey \(r) → \(rk)") } }
        }
        for r in Self.list("deathOf") { #expect(w.deathOf(r["rk"] as! String) == r["d"] as! String) }
        #expect(bad == 0)
    }

    @Test func legDurAtkStartupHitTier() {
        let w = Self.world()
        let ld = Self.fx["legDur"] as! [[Double]]
        for (si, st) in w.data.game.stages.enumerated() { for (k, L) in st.line.enumerated() { #expect(w.legDur(L) == ld[si][k]) } }
        for r in Self.list("atkStartup") { #expect(Self.close(w.atkStartup(r["a"] as! String), r["t"]), "\(r)") }
        var bad = 0
        for r in Self.list("hitTier") {
            let a = r["a"] as! String, rk = r["rk"] as! String, o = Self.opts(r["o"] as! [String: Any])
            if w.hitTier(a, o, rk) != (r["n"] as! Int) || w.hitKind(a, rk == "rSlam") != r["k"] as! String { bad += 1 }
        }
        #expect(bad == 0)
    }

    @Test func spawnWaveScaling() {
        let w = Self.world()
        for r in Self.list("spawn") {
            Self.reset(w); w.ci = r["ci"] as! Int; w.stageIdx = r["sg"] as! Int; w.hero.x = Self.num(r["hx"])!
            let n0 = w.ents.count
            w.spawnWave(["punk", "heavy", "rusher", "guard"], fromDoors: r["fromDoors"] as! Bool); w.cut = nil
            let got = Array(w.ents[n0...]), want = r["ents"] as! [[String: Any]]
            #expect(got.count == want.count)
            for (a, e) in zip(got, want) {
                let ok = a.e!.t == e["t"] as! String && Self.close(a.e!.hp, e["hp"]) && Self.close(a.e!.dmg, e["dmg"]) && Self.close(a.e!.cd, e["cd"]) && Self.close(a.e!.cdT, e["cdT"])
                    && Self.close(a.x, e["x"]) && Self.close(a.z, e["z"]) && a.flip == e["flip"] as! Bool && a.remap == e["remap"] as! Int
                #expect(ok, "spawn \(r["ci"]!) \(r["sg"]!) \(r["hx"]!) \(e) ↔ hp \(a.e!.hp) dmg \(a.e!.dmg) x \(a.x) z \(a.z) flip \(a.flip)")
            }
        }
    }

    @Test func timeToCuePerFrame() {
        let w = Self.world()
        for r in Self.list("ttc") {
            Self.reset(w); let T = Self.spawn(w, r["t"] as! String, 30); w.engageT = nil
            w.foeStrike(T, r["mv"] as! String)
            let rows = r["rows"] as! [[Any]]
            var got: [[Any]] = [], n = 0
            while let A = T.action, !A.fired, n < 200 { got.append([T.anim, T.si, T.hold, w.timeToCue(T) as Any]); w.advance(T); n += 1 }
            #expect(got.count == rows.count, "ttc \(r["t"]!) \(r["mv"]!): 칸 수 \(got.count) ↔ \(rows.count)")
            for (g, e) in zip(got, rows) {
                let ok = g[0] as! String == e[0] as! String && g[1] as! Int == e[1] as! Int && g[2] as! Int == e[2] as! Int && Self.close(g[3] as? Double, e[3])
                if !ok { Issue.record("ttc \(r["t"]!) \(r["mv"]!) \(g) ↔ \(e)"); break }
            }
        }
    }

    @Test func damageOutcomes() {
        let w = Self.world()
        var bad = 0, n = 0
        for r in Self.list("damage") {
            Self.reset(w); let T = Self.spawn(w, r["et"] as! String, 20)
            if r["low"] as! Bool { T.e!.hp = 3 }
            let H = w.hero!
            if r["air"] as! Bool { H.anim = "upper"; var o = HitOpts(); o.react = "launch"; w.jugHit(T, "launch", 1, H, o, 1); T.jug!.h = 20; T.hs = 0; H.hs = 0; w.time = 10.5 }
            H.anim = r["a"] as! String
            w.damage(H, T, 10, Self.opts(r["o"] as! [String: Any]))
            let e = r["r"] as! [String: Any]; n += 1
            var diffs: [String] = []
            func chk(_ k: String, _ ok: Bool, _ v: Any?) { if !ok { diffs.append("\(k) \(v ?? "nil")↔\(e[k] ?? "nil")") } }
            chk("hp", Self.close(T.e!.hp, e["hp"]), T.e!.hp); chk("anim", T.anim == e["anim"] as! String, T.anim); chk("pose", T.pose == e["pose"] as! String, T.pose)
            chk("after", (T.after ?? "") == ((e["after"] as? String) ?? ""), T.after); chk("kb", Self.close(T.kb, e["kb"], 2e-3), T.kb); chk("hs", T.hs == e["hs"] as! Int, T.hs)
            chk("stun", Self.close(T.e!.stun, e["stun"]), T.e!.stun); chk("dead", T.dead == e["dead"] as! Bool, T.dead); chk("hhs", H.hs == e["hhs"] as! Int, H.hs)
            chk("hx", Self.close(H.x, e["hx"]), H.x); chk("combo", w.combo == e["combo"] as! Int, w.combo); chk("score", w.score == e["score"] as! Int, w.score)
            chk("sp", Self.close(w.sp, e["sp"]), w.sp); chk("freeze", w.freeze == e["freeze"] as! Int, w.freeze); chk("slowT", Self.close(w.slowT, e["slowT"]), w.slowT)
            if let ej = e["jug"] as? [String: Any] {
                if let J = T.jug { chk("jug.vy", Self.close(J.vy, ej["vy"], 2e-3), J.vy); chk("jug.vx", Self.close(J.vx, ej["vx"], 2e-3), J.vx); chk("jug.n", J.n == ej["n"] as! Int, J.n) }
                else { diffs.append("jug 없음") }
            } else if T.jug != nil { diffs.append("jug 있음") }
            if !diffs.isEmpty { bad += 1; if bad <= 12 { Issue.record("damage \(r["et"]!) low:\(r["low"]!) air:\(r["air"]!) \(r["a"]!) \(r["o"]!): \(diffs.joined(separator: ", "))") } }
        }
        #expect(n > 3000)
        #expect(bad == 0, "damage 불일치 \(bad)/\(n)")
    }

    @Test func heroHurt() {
        let w = Self.world()
        for r in Self.list("hurt") {
            Self.reset(w); let T = Self.spawn(w, "punk", 20); let mv = r["mv"] as! String; T.anim = mv; T.lastMove = mv
            let H = w.hero!
            w.damage(T, H, 8, Self.opts(r["o"] as! [String: Any]))
            let e = r["r"] as! [String: Any]
            let ok = Self.close(w.hp, e["hp"]) && H.anim == e["anim"] as! String && Self.close(H.kb, e["kb"], 2e-3) && H.hs == e["hs"] as! Int && T.hs == e["ths"] as! Int && Self.close(w.sp, e["sp"])
            #expect(ok, "hurt \(mv) \(r["o"]!): hp \(w.hp) anim \(H.anim) kb \(H.kb) hs \(H.hs)/\(T.hs) sp \(w.sp) ↔ \(e)")
        }
    }

    @Test func juggleTrajectories() {
        let w = Self.world()
        for r in Self.list("jug") {
            Self.reset(w); let heavy = r["heavy"] as! Bool, second = r["second"] as! Bool, rk = r["rk"] as! String
            let T = Self.spawn(w, heavy ? "heavy" : "punk", 20), H = w.hero!; H.anim = "upper"
            var o = HitOpts(); o.react = "launch"; w.jugHit(T, rk, 1, H, o, heavy ? 0.35 : 1)
            var got: [[Any]] = []
            var i = 0
            while i < 300 && T.jug != nil {
                if second && i == 12 { H.anim = "kick"; var k = HitOpts(); k.knock = true; w.jugHit(T, "rKick", 1, H, k, 1) }
                w.jugStep(T, 1.0 / 60)
                if i % 3 == 0 || T.jug == nil { got.append([i, T.jug.map { $0.h } as Any, T.jug.map { $0.vy } as Any, T.pose, T.airOv, T.kb, T.anim]) }
                i += 1
            }
            let rows = r["rows"] as! [[Any]]
            #expect(got.count == rows.count, "jug \(rk) heavy:\(heavy) second:\(second): 행 \(got.count) ↔ \(rows.count)")
            for (g, e) in zip(got, rows) {
                let ok = g[0] as! Int == e[0] as! Int && Self.close(g[1] as? Double, e[1], 2e-3) && Self.close(g[2] as? Double, e[2], 2e-3) && g[3] as! String == e[3] as! String
                    && Self.close(g[4] as? Double, e[4], 2e-3) && Self.close(g[5] as? Double, e[5], 2e-3) && g[6] as! String == e[6] as! String
                if !ok { Issue.record("jug \(rk) heavy:\(heavy) second:\(second) \(g) ↔ \(e)"); break }
            }
        }
    }

    @Test func trainIntegration() {
        let w = Self.world()
        for r in Self.list("train") {
            Self.reset(w); w.state = "fight"; w.leg = 0; w.legStart = 0; w.qi = 0; w.quickStop = nil; w.qDwell = nil; w.arriving = false; w.expr = false; w.prevEx = nil
            w.tr = TrainState(); w.tr.door = 1; w.departT = 0; w.doorWant = false; w.press = 0
            let sc = r["sc"] as! String
            if sc == "depart" { w.departT = 2.2; w.doorWant = true }
            if sc == "brake" { w.tr.v = 700; w.tr.phase = "brake"; w.tr.ex = 5000; w.tr.stopAt = 6100; w.tr.door = 0; w.legStart = 3000; w.qi = 9 }
            if sc == "cruise" { w.tr.v = 300; w.tr.phase = "accel"; w.tr.ex = 100; w.tr.door = 0; w.qi = 9 }
            let rows = r["rows"] as! [[Any]]
            #expect(rows.count == 60)
            var k = 0
            for i in 0..<900 {
                w.trainUpdate(1.0 / 60)
                if i % 15 == 0 {
                    let e = rows[k]; k += 1
                    let ok = Self.close(w.tr.v, e[1], 2e-3) && Self.close(w.tr.a, e[2], 2e-3) && Self.close(w.tr.ex, e[3], 2e-2) && w.tr.phase == e[4] as! String
                        && Self.close(w.tr.door, e[5], 2e-3) && Self.close(w.tr.joint, e[6], 2e-2) && Self.close(w.tr.jolt, e[7], 2e-3) && Self.close(w.press, e[8], 2e-3)
                    if !ok { Issue.record("train \(sc) [\(i), \(w.tr.v), \(w.tr.a), \(w.tr.ex), \(w.tr.phase), \(w.tr.door), \(w.tr.joint), \(w.tr.jolt), \(w.press)] ↔ \(e)"); break }
                }
            }
        }
    }
}
