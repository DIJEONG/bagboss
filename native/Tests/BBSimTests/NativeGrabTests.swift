import Testing
import Foundation
import BBAnim
@testable import BBSim
import BBContent

/// 잡아 메치기 · 수플렉스 다듬기(docs/07 §7-T, World+NativeGrab) — 깃발 켜짐만 바뀐다(꺼짐은 웹 그대로: StoryLockstepTests 무도장 판 · ActionAuditTests)
@Suite struct NativeGrabTests {
    /// 잡힌 몸 몸통 가운데(키 포즈 기준 — 그리기 상태를 건드리지 않는다)
    static func torso(_ w: World, _ a: Actor) -> SIMD2<Double> {
        let P = w.data.animTables.poses[a.pose] ?? Pose()
        let (j, _) = solveJoints(P, rig: w.data.heroRig, input: JointInput(tilt: a.tilt, airOv: a.airOv + (a.jug?.h ?? 0), walkResidual: nil, weaponSprite: nil))
        let m = (j.hips + j.neck) / 2
        return SIMD2(a.x + a.f * m.x, a.y + m.y)
    }
    struct Track { var grabbed = false, released = false, relJump = 0.0, maxJump = 0.0, landX = 0.0, heroX = 0.0, inside = true, cueTicks: [Int] = [], grabTick: Int? = nil }
    /// 무도장 단독 시연 한 번: 놓는 틱 몸통 이동 · 잡혀 있는 동안 틱당 최대 이동 · 벽 안
    static func demo(_ on: Bool, _ cmd: DojoCommand, setup: ((World) -> Void)? = nil) -> (Track, [String]) {
        let sim = DojoNativeTests.dojo(on), w = sim.w
        if let setup { setup(w) } else { sim.apply(.dojo(cmd)) }
        var T = Track(), prev: SIMD2<Double>?, wasHeld = false, log: [String] = []
        for i in 0..<(60 * 5) {
            sim.step()
            guard let D = w.dojoDummy(), let H = w.hero else { continue }
            let held = D.heldBy != nil, c = torso(w, D)
            if let p = prev, held || wasHeld {
                let d = ((c - p) * (c - p)).sum().squareRoot()
                if wasHeld && !held { T.relJump = d; T.released = true; T.landX = D.x; T.heroX = H.x } else if held && wasHeld { T.maxJump = max(T.maxJump, d) }
            }
            if held { T.grabbed = true; if T.grabTick == nil { T.grabTick = i } }
            if D.x < w.AW0() - 2.01 || D.x > w.AW1() + 2.01 { T.inside = false }
            if H.pose == "gr_throw" || H.pose == "sx_slam" { T.cueTicks.append(i) }
            log.append("\(i) \(H.anim)/\(H.pose) \(D.anim)/\(D.pose) x\(D.x) a\(D.airOv)")
            prev = c; wasHeld = held
        }
        return (T, log)
    }

    @Test func releaseNoTeleport() {
        for cmd: DojoCommand in [.hero("throw", combo: nil), .hero("suplex", combo: nil), .combo(15)] {
            let (web, _) = Self.demo(false, cmd), (nv, _) = Self.demo(true, cmd)
            #expect(web.grabbed && web.released && nv.grabbed && nv.released, "\(cmd)")
            #expect(web.relJump > 40, "\(cmd) 웹: 놓는 틱 순간 이동 \(web.relJump)")   // 기준선: 머리 위 → 바닥 50px 넘게
            #expect(nv.relJump < 8, "\(cmd) 네이티브: 놓는 틱 이동 \(nv.relJump)")
            #expect(nv.maxJump < 30, "\(cmd) 네이티브: 잡혀 있는 동안 틱당 최대 \(nv.maxJump)")   // 호(빠른 내리꽂기)도 틱당 30px 아래
            #expect(abs((nv.landX - nv.heroX) - (web.landX - web.heroX)) < 0.01, "\(cmd) 떨어지는 자리는 웹과 같다")
            let cw = (web.cueTicks.first ?? -1) - (web.grabTick ?? 0), cn = (nv.cueTicks.first ?? -1) - (nv.grabTick ?? 0)
            #expect(cw == cn, "\(cmd) 잡기 → 꽂기 틱 수 같음 \(cw) \(cn)")
        }
    }

    /// 벽 쪽으로 메치기 · 벽 쪽 뒤로 수플렉스: 잡힌 몸 · 떨어지는 자리가 벽 안
    @Test func wallKeepsVictimInside() {
        for (id, toWall) in [("throw", true), ("suplex", false)] {
            let (t, _) = Self.demo(true, .reset) { w in
                guard let H = w.hero, let D = w.dojoDummy() else { return }
                w.bag = [w.dojoItem(id, 9900, t: 99, tier: 2)]
                if toWall { H.x = w.AW1() - 20; H.flip = false; D.x = w.AW1() - 2 } else { H.x = w.AW0() + 8; H.flip = false; D.x = H.x + 18 }
                D.flip = true; w.useSkill(0, D, true)
            }
            #expect(t.grabbed && t.released && t.inside, "\(id)")
            #expect(t.relJump < 8, "\(id) 벽에서도 순간 이동 없음 \(t.relJump)")
        }
    }

    /// 들어 올린 채 주인공이 맞으면(동작이 끊기면) 놓친 몸이 떨어진다 — 웹은 한 틱에 바닥으로
    @Test func interruptedHoldDrops() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("throw", combo: nil)))
        var n = 0
        while n < 300, w.hero.pose != "gr_lift" || (w.dojoDummy()?.airOv ?? 0) < 12 { sim.step(); n += 1 }
        guard let D = w.dojoDummy(), D.heldBy != nil else { Issue.record("들기까지 못 감"); return }
        let a0 = D.airOv
        w.setAnim(w.hero, "hit"); sim.step()
        #expect(D.heldBy == nil && D.anim == "fall" && D.airOv > a0 * 0.6, "한 틱에 떨어지지 않는다 \(a0) → \(D.airOv)")
        var t = 0; while D.airOv > 0 && t < 60 { sim.step(); t += 1 }
        #expect(D.airOv == 0 && t > 3 && t < 30, "몇 틱에 걸쳐 바닥으로 \(t)")
    }

    /// 같은 씨앗 두 번 = 같은 자리(결정적)
    @Test func deterministic() {
        let (_, a) = Self.demo(true, .hero("throw", combo: nil)), (_, b) = Self.demo(true, .hero("throw", combo: nil))
        #expect(a == b)
    }

    /// 막는 상대도 잡힌다(잡기 높이는 가드를 무시) · 떨어진 자리 옆 적은 함께 쓰러진다
    @Test func beatsGuardAndSplashes() {
        let (sim, w, F) = NativeGuardTests.arena(["punk", "punk"], dx: [22, 52]), A = F[0], B = F[1]
        w.bag = [Item(id: "throw", uid: 903, tier: 1, opt: nil)]; w.bag[0].x = 0; w.bag[0].y = 0; w.renderBag(); w.bag[0].t = 99
        w.setAnim(A, "nv_gdH"); A.nvg.stance = 1
        let hp0 = A.e!.hp, hpB = B.e!.hp
        w.useSkill(0, A, true)
        var held = false
        for _ in 0..<(60 * 2) { sim.step(); if A.heldBy != nil { held = true } }
        #expect(held && A.e!.hp < hp0, "막는 상대 잡아 메침")
        #expect(B.e!.hp < hpB, "떨어진 자리(30px) 옆 적(22px 떨어짐)도 휘말림")
    }

    // MARK: 2차(벽꿍 · 회복)

    /// 실전 판(벽 앞 / 트인 곳)에서 한 번 메친다 — (준 피해, 주인공 경직 칸, 맞은 적 경직 칸, 벽꿍 수, 틱마다 기록)
    struct Throw { var dmg = 0.0, heroHs = 0, foeHs = 0, walls = 0, inside = true, landDX = 0.0, minGap = 99.0, wallTicks = 0, log: [String] = [] }
    static func arenaThrow(_ id: String, wall: Bool, tune: Bool = true, seed: UInt32 = 3) -> Throw {
        let (sim, w, F) = NativeGuardTests.arena(["punk"], dx: [18], seed: seed), A = F[0], H = w.hero!
        w.nvGrabTune = tune; H.dash = 0; H.dashT = 0; H.kb = 0
        let back = id == "suplex"
        if wall { H.x = w.AW1() - 22; H.flip = back; A.x = back ? H.x - 18 : H.x + 18; A.flip = !back }
        else { H.x = 200; H.flip = false; A.x = 218; A.flip = true }
        w.bag = [Item(id: id, uid: 903, tier: 1, opt: nil)]; w.bag[0].x = 0; w.bag[0].y = 0; w.renderBag(); w.bag[0].t = 99
        let hp0 = A.e!.hp, walls0 = w.stats.walls
        w.useSkill(0, A, true)
        var T = Throw(), wasHeld = false, released = false
        for i in 0..<(60 * 3) {
            sim.step()
            if (A.heldBy != nil || A.nvHold != nil || A.jug != nil), A.x < w.AW0() - 2.01 || A.x > w.AW1() + 2.01 { T.inside = false }
            if A.nvHold?.phase == "wall" { T.wallTicks += 1 }
            if wasHeld && A.heldBy == nil && !released { released = true; T.heroHs = H.hs; T.foeHs = A.hs; T.dmg = hp0 - A.e!.hp }
            if released && A.jug == nil && A.nvHold == nil && T.landDX == 0 && i > 0 && (A.anim == "jland" || data(A)) { T.landDX = abs(A.x - (wall ? (H.f > 0) != back ? w.AW1() : w.AW0() : A.x)) }
            if released && A.anim == "jland" && T.minGap == 99 { T.minGap = abs(A.x - H.x) }   // 벽에서 미끄러져 바닥에 닿는 순간 주인공과의 거리   // 누워 있는 동안
            wasHeld = A.heldBy != nil
            T.log.append("\(i) \(A.x) \(A.airOv) \(A.pose) \(H.x) \(H.anim)/\(H.pose) kb\(H.kb) d\(H.dash)")
        }
        T.walls = w.stats.walls - walls0
        return T
    }
    static func data(_ a: Actor) -> Bool { a.anim == "rSlam" || a.anim == "getup" }

    @Test func wallBounce() {
        for id in ["throw", "suplex"] {
            let open = Self.arenaThrow(id, wall: false), wall = Self.arenaThrow(id, wall: true)
            #expect(open.walls == 0 && wall.walls == 1, "\(id) 벽꿍 한 번")
            #expect(wall.inside, "\(id) 잡힌 몸 · 벽꿍 · 미끄러짐 내내 벽 안")
            #expect(wall.wallTicks >= 4 && wall.wallTicks <= 6, "\(id) 벽에 붙어 있는 틱 \(wall.wallTicks)")
            #expect(wall.dmg >= open.dmg * 1.15 && wall.dmg <= open.dmg * 1.25 + 1, "\(id) 피해 +20%: \(open.dmg) → \(wall.dmg)")
            #expect(wall.landDX > 4 && wall.landDX < 24, "\(id) 벽 밑에 눕는다 \(wall.landDX)")
            #expect(wall.minGap >= 22 && wall.minGap < 99, "\(id) 바닥에 닿을 때 주인공과 거리 \(wall.minGap)")
        }
        let a = Self.arenaThrow("throw", wall: true), b = Self.arenaThrow("throw", wall: true)
        #expect(a.log == b.log, "벽꿍 결정적")
    }

    /// 회복: 주인공 경직만 1.7(1.6) → nvThrowRecK(1.5) 배율 — 맞은 적 경직은 그대로 · 주인공이 실제로 빨리 풀린다
    @Test func recoveryShorter() {
        for id in ["throw", "suplex"] {
            let off = Self.arenaThrow(id, wall: false, tune: false), on = Self.arenaThrow(id, wall: false)
            let k = World.nvThrowRecK / (id == "throw" ? 1.7 : 1.6)
            #expect(off.heroHs > 0 && abs(Double(on.heroHs) - (Double(off.heroHs) * k).rounded()) <= 1, "\(id) 주인공 경직 \(off.heroHs) → \(on.heroHs)")
            #expect(on.foeHs == off.foeHs, "\(id) 맞은 적 경직 그대로 \(off.foeHs)")
            #expect(on.dmg == off.dmg)
            #expect(on.heroHs < off.heroHs)
        }
    }

    // MARK: 밸런스(2차 다듬기 끔 ↔ 켬 — 가방에 잡아 메치기 · 수플렉스)

    struct Bal { var alive = 0.0, kills = 0.0, taken = 0.0, ci = 0.0, thr = 0.0, walls = 0.0 }
    static func balRun(seed: UInt32, seconds: Double, stage: Int, tune: Bool) -> Bal {
        let sim = Sim(data: NativeGuardTests.on, seed: seed, config: NativeGuardTests.config(stage: stage)), w = sim.w
        w.nvGrabTune = tune
        let part = ProcessInfo.processInfo.environment["BB_GRAB_PART"] ?? ""
        if part == "rec" { w.nvGrabWall = false } else if part == "wall" { w.nvGrabRec = false } else if part == "none" { w.nvGrabWall = false; w.nvGrabRec = false }   // none = 보이는 것만(잡음 크기)
        for (k, id) in ["throw", "suplex"].enumerated() {
            let it = Item(id: id, uid: 9811 + k, tier: 1, opt: nil)
            if let p = w.findSpot(it) { it.x = p.x; it.y = p.y; it.rot = p.rot } else { it.x = 0; it.y = 0 }
            w.bag.append(it); w.renderBag(); it.t = 99
        }
        for _ in 0..<Int(seconds * 60) { sim.step(); if sim.state == "over" || sim.state == "end" { break } }
        let s = sim.snapshot
        return Bal(alive: s.hp > 0 ? 1 : 0, kills: Double(s.kills), taken: s.stats.taken, ci: Double(s.car), thr: Double(w.stats.throws_), walls: Double(w.stats.walls))
    }

    @Test func balance() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let sets: [(String, Int, Double, Int)] = big
            ? (ProcessInfo.processInfo.environment["BB_GRAB_N"].flatMap(Int.init).map { n in [("4 노선 240초", n, 240.0, 1), ("7 노선 240초", n, 240.0, 3)] }
               ?? [("D 노선 240초", 40, 240, 0), ("4 노선 240초", 40, 240, 1), ("7 노선 240초", 40, 240, 3)])
            : [("4 노선 90초", 4, 90, 1)]
        var md = "| 묶음 | 지표 | 2차 끔 | 2차 켬 | 차 |\n|---|---|---:|---:|---:|\n"
        var use = "| 묶음 | 메치기·수플렉스/판(끔) | (켬) | 벽꿍·벽에 부딪힘/판(끔) | (켬) |\n|---|---:|---:|---:|---:|\n"
        for (name, n, sec, st) in sets {
            var A: [Bal] = [], B: [Bal] = []
            for k in 0..<n { let seed = UInt32(9100 + k * 17); A.append(Self.balRun(seed: seed, seconds: sec, stage: st, tune: false)); B.append(Self.balRun(seed: seed, seconds: sec, stage: st, tune: true)) }
            func m(_ R: [Bal], _ f: (Bal) -> Double) -> Double { R.map(f).reduce(0, +) / Double(R.count) }
            for (key, f) in [("생존율", { (r: Bal) in r.alive }), ("처치", { $0.kills }), ("받은 피해", { $0.taken }), ("도달 칸", { $0.ci })] as [(String, (Bal) -> Double)] {
                let a = m(A, f), b = m(B, f)
                md += "| \(name) (\(n)판) | \(key) | \(String(format: "%.2f", a)) | \(String(format: "%.2f", b)) | \(String(format: key == "생존율" ? "%+.0f pp" : "%+.2f", key == "생존율" ? (b - a) * 100 : b - a)) |\n"
                if !big && key == "생존율" { #expect(abs(b - a) <= 0.5) }
            }
            use += "| \(name) | \(String(format: "%.1f", m(A) { $0.thr })) | \(String(format: "%.1f", m(B) { $0.thr })) | \(String(format: "%.2f", m(A) { $0.walls })) | \(String(format: "%.2f", m(B) { $0.walls })) |\n"
        }
        print(md); print(use)
        if big {
            let tag = ProcessInfo.processInfo.environment["BB_GRAB_PART"].map { "_" + $0 } ?? ""
            let url = NativeGuardTests.root.appending(path: "tools/js/out/moves/throw_balance\(tag).md")
            try (md + "\n" + use).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
