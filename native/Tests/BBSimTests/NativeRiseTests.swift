import Testing
import Foundation
@testable import BBSim
import BBContent

/// 퇴근 승천권(nv_rise — docs/07 §7-R · docs/08 §8): 동작 · 타격 · 무적 · 막기 되받아치기 · 대공 · 지붕 뚫기 · 깃발 꺼짐 불변.
/// BB_NV_STATS=1 이면 밸런스(가방에 승천권 없음 ↔ 있음, D · 4 · 7 노선) 표를 tools/js/out/moves/rise_balance.md 에 쓴다.
@Suite struct NativeRiseTests {
    typealias G = NativeGuardTests

    /// 승천권을 가방에 넣는다(쿨다운 찬 채)
    static func give(_ w: World) -> Int {
        let it = Item(id: "nv_rise", uid: 9801, tier: 1, opt: nil)
        if let p = w.findSpot(it) { it.x = p.x; it.y = p.y; it.rot = p.rot } else { it.x = 0; it.y = 0 }   // 빈자리(없으면 겹쳐 둔다 — 규칙은 칸 겹침을 보지 않는다)
        w.bag.append(it); w.renderBag(); it.t = 99
        return w.bag.firstIndex { $0 === it }!
    }

    // MARK: 동작 · 타격(무도장 단독 시연)

    @Test func soloDemo() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_rise", combo: nil)))
        var poses: [String] = [], hits = 0, dmg = 0.0, maxAir = 0.0, maxJug = 0.0, cueTick = -1, landTick = -1, endTick = -1, k = 0
        DojoNativeTests.run(sim, 60 * 3) { i in
            let H = w.hero!, D = w.dojoDummy()!
            if H.anim == "nv_rise" { if poses.last != H.pose { poses.append(H.pose) }; maxAir = max(maxAir, w.data.poses[H.pose]?.air ?? 0) }
            if H.anim == "nv_rise" && H.pose == "rs_apex" && cueTick < 0 { cueTick = i }
            if H.pose == "rs_land" && landTick < 0 { landTick = i }
            if landTick > 0 && endTick < 0 && H.anim != "nv_rise" { endTick = i }
            if D.e!.hp < 99999 - 1e-6 { hits += 1; dmg += 99999 - D.e!.hp; D.e!.hp = 99999 }
            maxJug = max(maxJug, D.jug?.h ?? 0); k = i
        }
        _ = k
        print("[승천권] 자세 \(poses) · 적중 \(hits) · 피해 \(dmg) · 주인공 최고 \(maxAir)px · 허수아비 최고 \(maxJug)px · 큐 \(cueTick)틱 · 착지 \(landTick) → 끝 \(endTick)")
        #expect(poses.prefix(4) == ["rs_crouch", "rs_launch", "rs_rise", "rs_apex"])
        #expect(poses.contains("rs_land") && poses.contains("rs_rec"))
        #expect(hits == 3, Comment(rawValue: "적중 \(hits)"))
        #expect(maxAir >= 28 && maxAir <= 40)
        #expect(maxJug > 40)
        #expect(endTick - landTick >= 18)   // 착지 빈틈 0.3초 이상
        // 어퍼컷(같은 단계 · 같은 경로)과 총 피해 비교: ±40% 안
        let s2 = DojoNativeTests.dojo(true), w2 = s2.w
        s2.apply(.dojo(.hero("upper", combo: nil)))
        var up = 0.0
        DojoNativeTests.run(s2, 60 * 3) { _ in if let D = w2.dojoDummy(), D.e!.hp < 99999 - 1e-6 { up += 99999 - D.e!.hp; D.e!.hp = 99999 } }
        print("[승천권] 총 피해 \(dmg) ↔ 어퍼컷 \(up)")
        #expect(dmg >= up * 0.6 && dmg <= up * 1.4)
    }

    // MARK: 무적 · 높이

    @Test func invulnerableStartupAndHighWhiff() {
        let (_, w, F) = G.arena(["punk"], dx: [20]), H = w.hero!, A = F[0]
        _ = Self.give(w)
        A.flip = true; A.lastMove = "jab"; A.anim = "jab"
        let hp0 = w.hp
        for (pose, h, dodge) in [("rs_crouch", "jab", true), ("rs_launch", "upper", true), ("rs_rise", "jab", true), ("rs_rise", "upper", false), ("rs_apex", "hook", true), ("rs_land", "jab", false)] {
            H.anim = "nv_rise"; H.pose = pose; A.lastMove = h; A.e!.stun = 0
            let before = w.hp
            w.foeHit(A)
            #expect((w.hp == before) == dodge, Comment(rawValue: "\(pose) vs \(h)"))
            w.hp = hp0
        }
        #expect(w.stats.nvg.riseInvuln == 4)
        // 깃발 켜짐에서도 승천권이 아닐 땐 그대로 맞는다
        H.anim = "idle"; H.pose = "st0"; A.lastMove = "jab"; let b = w.hp; w.foeHit(A); #expect(w.hp < b)
    }

    // MARK: 막기 되받아치기

    @Test func reversalFromBlockStun() {
        var fired = 0, tried = 0
        for seed in UInt32(1)...24 {
            let (sim, w, F) = G.arena(["punk", "punk"], dx: [22, -24], seed: seed), H = w.hero!
            let i = Self.give(w)
            // 앞의 적 공격을 막은 순간(블록 경직) — 뒤에도 하나 붙어 있다(압박)
            w.setAnim(H, "nv_gdH"); H.nvg.stance = 1; F[0].lastMove = "jab"; F[0].anim = "jab"; F[0].flip = true
            w.damage(F[0], H, 9)
            #expect(H.anim == "nv_gdHb")
            tried += 1
            _ = w.nvHeroGuard(H, w.foes())
            if H.anim == "nv_rise" {
                fired += 1
                #expect(w.bag[i].t == 0 && !w.bag[i].opener)
                // 막기 한 번에 한 번만 굴린다
                #expect(w.stats.nvg.riseReversals == 1)
                // 출발 무적: 솟는 동안 적 공격이 빗나간다
                let hp0 = w.hp
                for _ in 0..<8 where World.nvRiseInvulnPoses.contains(H.pose) { F[1].e!.stun = 0; F[1].lastMove = "upper"; F[1].flip = false; w.foeHit(F[1]); sim.step() }
                #expect(w.hp == hp0)
                // 끝까지: 착지 빈틈은 가드로 끊지 않는다
                var guardInRecov = false
                for _ in 0..<90 { sim.step(); if World.nvRiseRecovPoses.contains(H.pose) && w.nvIsGuardAnim(H.anim) { guardInRecov = true } }
                #expect(!guardInRecov)
            } else {
                // 안 쓴 막기는 다시 굴리지 않는다
                let r0 = w.nvRiseRollAt
                _ = w.nvHeroGuard(H, w.foes())
                #expect(H.anim != "nv_rise" && w.nvRiseRollAt == r0)
            }
        }
        print("[승천권] 되받아치기 \(fired)/\(tried)")
        #expect(fired >= 6 && fired <= 20)   // 55% 언저리
        // 압박이 없으면(혼자 · 가벼운 공격) 쓰지 않는다
        let (_, w, F) = G.arena(["punk"], dx: [22]), H = w.hero!
        _ = Self.give(w)
        w.setAnim(H, "nv_gdH"); H.nvg.stance = 1; F[0].lastMove = "jab"; F[0].anim = "jab"; F[0].flip = true
        w.damage(F[0], H, 9); _ = w.nvHeroGuard(H, w.foes())
        #expect(H.anim != "nv_rise" && w.stats.nvg.riseReversals == 0)
    }

    @Test func antiAirCondition() {
        let (sim, w, F) = G.arena(["punk"], dx: [60]), H = w.hero!, A = F[0]
        w.bag = []; _ = Self.give(w); w.bag[0].t = -99   // 주인공이 먼저 쓰지 않게(조건만 본다)
        #expect(!w.condOK("nv_aa", H, A, F))
        A.flip = true; A.e!.cdT = -99; w.foeStrike(A, "fkick")
        var n = 0, ok = false
        while n < 120, A.anim == "fkick", let tt = w.timeToCue(A) { if tt <= 0.4 { ok = w.condOK("nv_aa", H, A, F); break }; sim.step(); n += 1 }
        #expect(A.anim == "fkick" && ok, Comment(rawValue: "\(A.anim) \(n) \(String(describing: w.timeToCue(A)))"))
    }

    // MARK: 지붕 뚫기

    /// 승천권을 쓰고 끝까지 돌린다 — 지붕 뚫기 이벤트 수
    static func riseOnce(_ sim: Sim, _ w: World, _ T: Actor, hp: Double) -> (roofs: [RoofBlast], thuds: Int, dead: Bool) {
        let H = w.hero!
        T.e!.hp = hp; T.e!.max = max(T.e!.max, hp); T.x = H.x + 18; T.flip = true; w.setAnim(T, "idle"); T.jug = nil; T.e!.stun = 2
        let i = w.bag.firstIndex { $0.id == "nv_rise" }!; w.bag[i].t = 99
        w.setAnim(H, "idle"); H.flip = false
        w.nvRiseGo(H, i, T)
        var roofs: [RoofBlast] = [], thuds = 0
        for _ in 0..<(60 * 3) { for e in sim.step() { if case .roofBlast(let r) = e { roofs.append(r) }; if case .roofThud = e { thuds += 1 } } }
        return (roofs, thuds, T.dead)
    }

    @Test func roofBlastOnlyOnKillWithCooldown() {
        let (sim, w, F) = G.arena(["punk", "punk", "punk"], dx: [200, 220, 240]), H = w.hero!
        _ = Self.give(w)
        for a in F { a.e!.stun = 99 }
        // 안 죽는 한 방: 지붕 뚫기 없음
        let r0 = Self.riseOnce(sim, w, F[0], hp: 999)
        #expect(r0.roofs.isEmpty && !r0.dead)
        // 꼭대기에서 쓰러뜨림 → 지붕 뚫기 1번 · 화면 위로 사라짐 · 1.9초 뒤 '…쿵'
        let r1 = Self.riseOnce(sim, w, F[1], hp: 12)
        #expect(r1.dead && r1.roofs.count == 1 && r1.thuds == 1, Comment(rawValue: "\(r1)"))
        #expect(r1.roofs.first?.kind == "car" && w.stats.nvg.roofBlasts == 1)
        #expect(!w.ents.contains { $0 === F[1] })   // 화면 밖으로 나가 지워졌다
        // 8초 안의 둘째 처치: 지붕 뚫기 없음(보통 띄워 쓰러뜨림)
        #expect(w.time - w.nvRoofAt < World.nvRoofGap)
        let r2 = Self.riseOnce(sim, w, F[2], hp: 12)
        #expect(r2.dead && r2.roofs.isEmpty && w.stats.nvg.roofBlasts == 1)
        // 간격이 지나면 다시
        let (sim3, w3, F3) = G.arena(["punk"], dx: [200])
        _ = Self.give(w3); F3[0].e!.stun = 99
        w3.nvRoofAt = w3.time - World.nvRoofGap - 0.1
        #expect(Self.riseOnce(sim3, w3, F3[0], hp: 12).roofs.count == 1)
        _ = H
    }

    @Test func roofBlastSkipsLivingBossButAllowsFinalDeath() {
        let (sim, w, F) = G.arena(["boss"], dx: [200]), B = F[0]
        _ = Self.give(w); B.e!.stun = 99
        #expect(B.e!.boss)
        #expect(Self.riseOnce(sim, w, B, hp: 999).roofs.isEmpty)
        w.nvRoofAt = -99
        let r = Self.riseOnce(sim, w, B, hp: 16)
        #expect(r.dead && r.roofs.count == 1, Comment(rawValue: "jw \(B.def.jw) cut \(String(describing: w.cut)) spc \(String(describing: w.spc)) roofAt \(w.nvRoofAt) t \(w.time) anim \(B.anim)"))
    }

    // MARK: 깃발 꺼짐 · 결정성

    @Test func flagOffUnaffected() {
        let off = SimRunTests.data
        #expect(off.item("nv_rise") == nil && off.seqJW["nv_rise"] == nil && off.jwCue["nv_rise"] == nil && off.poses["rs_apex"] == nil)
        #expect(G.on.item("nv_rise")?.cd == 6.5 && G.on.jwCue["nv_rise"] == "rs_apex")
        // 웹 아이템 순서 · 개수는 그대로(새 아이템은 뒤에)
        #expect(Array(G.on.game.items.ordered.map(\.key).prefix(off.game.items.count)) == off.game.items.ordered.map(\.key))
        // 깃발 끈 판: 승천권 기록 0
        let sim = Sim(data: off, seed: 77, config: SimRunTests.harnessConfig())
        for _ in 0..<(60 * 40) { sim.step() }
        let g = sim.snapshot.stats.nvg
        #expect(g.rises == 0 && g.roofBlasts == 0 && g.riseInvuln == 0)
    }

    @Test func deterministicWithRise() {
        func run() -> (NvGuardStats, Int, Double) {
            let sim = Sim(data: G.on, seed: 41, config: G.config(stage: 1))
            _ = Self.give(sim.w)
            for _ in 0..<(60 * 80) { sim.step() }
            return (sim.snapshot.stats.nvg, sim.snapshot.kills, sim.snapshot.hp)
        }
        let a = run(), b = run()
        #expect(a.0 == b.0 && a.1 == b.1 && a.2 == b.2)
        print("[승천권] 4 노선 80초: 씀 \(a.0.rises) · 되받아치기 \(a.0.riseReversals) · 대공 \(a.0.riseAntiAir) · 흘림 \(a.0.riseInvuln) · 지붕 \(a.0.roofBlasts)")
    }

    // MARK: 밸런스(가방에 승천권 없음 ↔ 있음)

    struct Res { var alive = 0.0, kills = 0.0, taken = 0.0, ci = 0.0; var g = NvGuardStats() }
    static func run(seed: UInt32, seconds: Double, stage: Int, rise: Bool) -> Res {
        let sim = Sim(data: G.on, seed: seed, config: G.config(stage: stage))
        if rise { _ = give(sim.w) }
        for _ in 0..<Int(seconds * 60) { sim.step(); if sim.state == "over" || sim.state == "end" { break } }
        let s = sim.snapshot
        return Res(alive: s.hp > 0 ? 1 : 0, kills: Double(s.kills), taken: s.stats.taken, ci: Double(s.car), g: s.stats.nvg)
    }

    @Test func balance() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let sets: [(String, Int, Double, Int)] = big
            ? [("D 노선 240초", 40, 240, 0), ("4 노선 240초", 40, 240, 1), ("7 노선 240초", 40, 240, 3)]
            : [("4 노선 120초", 6, 120, 1)]
        var md = "| 묶음 | 지표 | 승천권 없음 | 승천권 있음 | 차 |\n|---|---|---:|---:|---:|\n"
        var use = "| 묶음 | 씀/판 | 되받아치기/판 | 대공/판 | 무적으로 흘림/판 | 지붕 뚫기/판 |\n|---|---:|---:|---:|---:|---:|\n"
        for (name, n, sec, st) in sets {
            var A: [Res] = [], B: [Res] = []
            for k in 0..<n { let seed = UInt32(9100 + k * 17); A.append(Self.run(seed: seed, seconds: sec, stage: st, rise: false)); B.append(Self.run(seed: seed, seconds: sec, stage: st, rise: true)) }
            func m(_ R: [Res], _ f: (Res) -> Double) -> Double { R.map(f).reduce(0, +) / Double(R.count) }
            for (key, f) in [("생존율", { (r: Res) in r.alive }), ("처치", { $0.kills }), ("받은 피해", { $0.taken }), ("도달 칸", { $0.ci })] as [(String, (Res) -> Double)] {
                let a = m(A, f), b = m(B, f)
                md += "| \(name) (\(n)판) | \(key) | \(String(format: "%.2f", a)) | \(String(format: "%.2f", b)) | \(String(format: key == "생존율" ? "%+.0f pp" : "%+.2f", key == "생존율" ? (b - a) * 100 : b - a)) |\n"
                if !big && key == "생존율" { #expect(abs(b - a) <= 0.34) }
            }
            use += "| \(name) | \(String(format: "%.1f", m(B) { Double($0.g.rises) })) | \(String(format: "%.2f", m(B) { Double($0.g.riseReversals) })) | \(String(format: "%.2f", m(B) { Double($0.g.riseAntiAir) })) | \(String(format: "%.2f", m(B) { Double($0.g.riseInvuln) })) | \(String(format: "%.2f", m(B) { Double($0.g.roofBlasts) })) |\n"
            #expect(B.contains { $0.g.rises > 0 })
        }
        print(md); print(use)
        if big {
            let url = G.root.appending(path: "tools/js/out/moves/rise_balance.md")
            try (md + "\n" + use).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
