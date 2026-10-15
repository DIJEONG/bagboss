import Testing
import Foundation
@testable import BBSim
import BBContent
@testable import BBAnim

/// 무릎 올려치기(nv_kneelift) · 파고들어 올려치기(nv_duckup) — docs/07 §7-VF: 큐 타이밍 · 타격 수 · 띄움 · 조건 · 깃발 꺼짐 불변 · 결정성 · 밸런스.
/// BB_NV_STATS=1 이면 밸런스(가방에 두 기술 없음 ↔ 있음, D · 4 · 7 노선) 표를 tools/js/out/moves/vf_balance.md 에 쓴다.
@Suite struct NativeVFTests {
    typealias G = NativeGuardTests

    /// 기술을 가방에 넣는다(쿨다운 찬 채)
    static func give(_ w: World, _ id: String, uid: Int) -> Int {
        let it = Item(id: id, uid: uid, tier: 1, opt: nil)
        if let p = w.findSpot(it) { it.x = p.x; it.y = p.y; it.rot = p.rot } else { it.x = 0; it.y = 0 }
        w.bag.append(it); w.renderBag(); it.t = 99
        return w.bag.firstIndex { $0 === it }!
    }

    // MARK: 큐 타이밍(시퀀스 표)

    @Test func cueTiming() {
        let d = G.on, w = Sim(data: d, seed: 1, config: G.config()).w
        #expect(d.jwCue["nv_kneelift"] == "kl_hit" && d.jwCue["nv_duckup"] == "du_up")
        #expect(abs(w.atkStartup("nv_kneelift") - 0.1) < 1e-9)   // 영상 f7 → f9(끌어올림 → 타격 ≈ 0.1초)
        #expect(abs(w.atkStartup("nv_duckup") - 0.3) < 1e-9)     // 참고 u_000 → u_009(0.3초)
        let du = d.seqJW["nv_duckup"]!, kl = d.seqJW["nv_kneelift"]!
        let jabAt = du.prefix { $0.pose != "du_jab" }.reduce(0) { $0 + $1.n }
        #expect(jabAt == 150)                                    // 1타: 참고 u_005(0.17초)
        #expect(kl.reduce(0) { $0 + $1.n } == 850 && du.reduce(0) { $0 + $1.n } == 800)
        // 무릎을 든 칸(타격 · 솟음 · 버팀) = 0.3초(영상 f9~16 — 2026-10-13 재분석)
        #expect(kl.filter { ["kl_hit", "kl_lift", "kl_hold"].contains($0.pose) }.reduce(0) { $0 + $1.n } == 300)
        for s in kl + du { #expect(s.n.truncatingRemainder(dividingBy: 50) == 0) }   // 20fps 칸 배수
        // 머리 보정은 작게(목 점검)
        for (k, p) in NativeMoves.vfPoses { #expect(abs(p.h!.x) <= 4 && abs(p.h!.y) <= 4, Comment(rawValue: k)) }
    }

    // MARK: 무도장 단독 시연

    struct Solo { var hits: [HitInfo] = [], ticks: [Int] = [], poses: [String] = [], maxJug = 0.0, maxHeroAir = 0.0, heroDX = 0.0, cueTick = -1, jabTick = -1, dummyDX = 0.0, maxRoll = 0.0 }
    static func solo(_ id: String) -> Solo {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero(id, combo: nil)))
        var R = Solo(); let x0 = w.hero!.x, d0 = w.dojoDummy()!.x
        for i in 0..<(60 * 3) {
            for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero, h.attackerAnim == id { R.hits.append(h); R.ticks.append(i) } }
            let H = w.hero!, D = w.dojoDummy()!
            if H.anim == id {
                if R.poses.last != H.pose { R.poses.append(H.pose) }
                R.maxHeroAir = max(R.maxHeroAir, w.data.poses[H.pose]?.air ?? 0)
                R.heroDX = max(R.heroDX, (H.x - x0) * H.f)
                if H.pose == w.data.jwCue[id] && R.cueTick < 0 { R.cueTick = i }
                if H.pose == "du_jab" && R.jabTick < 0 { R.jabTick = i }
            }
            R.maxJug = max(R.maxJug, D.jug?.h ?? 0)
            R.dummyDX = max(R.dummyDX, (D.x - d0) * w.hero!.f); R.maxRoll = max(R.maxRoll, abs(D.jug?.roll ?? 0))
        }
        return R
    }

    @Test func kneeliftSolo() {
        let R = Self.solo("nv_kneelift"), U = Self.solo("upper")
        print("[무릎] 자세 \(R.poses) · 적중 \(R.hits.map(\.damage)) · 허수아비 최고 \(R.maxJug)px(어퍼컷 \(U.maxJug)) · 반응 \(R.hits.map(\.reaction))")
        // 2026-10-13 영상 재분석: 주인공은 거의 제자리에서 작게 뛰며 무릎을 든 채 버티고, 상대는 접혔다 눕혀져 뒤 대각선 위로 길게 날아간다
        #expect(R.poses.prefix(5) == ["kl_set", "kl_drive", "kl_hit", "kl_lift", "kl_hold"])
        #expect(R.hits.count == 1 && R.hits[0].reactOpt == "launch" && R.hits[0].reaction == "launch")
        #expect(R.maxHeroAir >= 16 && R.maxHeroAir < R.maxJug)  // 무릎을 꽂으며 솟는다(감독 확정 air 16 · 솟음 10 · 버팀 12) · 상대보다는 낮게
        #expect(R.maxJug >= 30 && R.maxJug <= 45)                 // 상대 골반이 주인공 머리 높이쯤(영상 f14~18)
        #expect(R.dummyDX >= 75)                                  // 높이보다 멀리 — 뒤로 길게 날아간다
        #expect(R.maxRoll >= 0.06)                                // 몸을 눕힌다(kv_lay + 몸 전체 회전)
        #expect(R.heroDX >= 4 && R.heroDX <= 14)                  // 반 걸음만 들어간다
    }

    /// 무릎 날림 중 다시 맞으면 눕힘 · 느린 가로 감쇠를 풀고 보통 공중 규칙으로(공중 콤보가 이어진다)
    @Test func kneeFlyRehit() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_kneelift", combo: nil)))
        var J: Jug?
        for _ in 0..<60 { _ = sim.step(); if let j = w.dojoDummy()!.jug, j.nvRollT != nil, j.roll < -0.03 { J = j; break } }
        guard let J, let D = w.dojoDummy() else { Issue.record("무릎 날림이 없다"); return }
        #expect(J.up == "kv_lay" && J.nvKeep == World.nvKneeKeep)
        w.jugHit(D, "launch", w.hero!.f, w.hero!, HitOpts(), 1)
        #expect(J.nvKeep == nil && J.nvRollT == 0)
        for _ in 0..<30 { _ = sim.step() }
        #expect(D.jug == nil || abs(D.jug!.roll) < 0.01)
    }

    @Test func duckupSoloTwoHits() {
        let R = Self.solo("nv_duckup")
        print("[파고들기] 자세 \(R.poses) · 적중 \(R.hits.map(\.damage)) 틱 \(R.ticks) · 반응 \(R.hits.map(\.reaction)) · 내디딤 \(R.heroDX)px · 허수아비 최고 \(R.maxJug)px")
        #expect(R.poses.prefix(6) == ["du_step", "du_sink", "du_jab", "du_jab_ft", "du_rise", "du_up"])
        #expect(R.hits.count == 2)
        guard R.hits.count == 2 else { return }
        #expect(R.hits[0].damage < R.hits[1].damage)              // 1타 작게 · 2타 크게
        #expect(R.hits[0].reactOpt == "body" && !R.hits[0].airborne)
        #expect(R.hits[1].reactOpt == "launch" && R.hits[1].airborne)
        #expect(R.ticks[1] - R.ticks[0] >= 8 && R.ticks[1] - R.ticks[0] <= 14)   // 1타 → 2타 = 0.15초 + 1타 경직 1칸(참고 u_006 → u_010 ≈ 0.13초)
        #expect(R.heroDX >= 10)                                    // 크게 내디뎌 파고든다
        #expect(R.maxHeroAir <= 1)                                 // 바닥을 떠나지 않는다(승천권과 다른 실루엣)
        #expect(R.maxJug > 30)
    }

    // MARK: 조건 · 막기

    @Test func groundCondition() {
        let (sim, w, F) = G.arena(["punk"], dx: [30]), H = w.hero!, A = F[0]
        _ = sim
        #expect(w.condOK("nv_ground", H, A, F))
        A.x = H.x + 60; #expect(!w.condOK("nv_ground", H, A, F))
        A.x = H.x + 30; w.jugHit(A, "launch", 1, H, HitOpts(), 1); #expect(!w.condOK("nv_ground", H, A, F))
        // 깃발 꺼짐(웹 규칙)엔 이 조건이 없다
        let off = Sim(data: SimRunTests.data, seed: 3, config: SimRunTests.harnessConfig()).w
        #expect(off.item("nv_duckup") == nil)
    }

    // MARK: 깃발 꺼짐 · 결정성

    @Test func flagOffAbsent() {
        let off = SimRunTests.data
        for id in ["nv_kneelift", "nv_duckup"] {
            #expect(off.item(id) == nil && off.seqJW[id] == nil && off.jwCue[id] == nil && off.atkFeel[id] == nil)
            #expect(G.on.item(id) != nil && G.on.seqJW[id] != nil)
        }
        for p in ["kl_hit", "kl_hold", "du_jab", "du_up"] { #expect(off.poses[p] == nil && G.on.poses[p] != nil) }
        #expect(Array(G.on.game.items.ordered.map(\.key).prefix(off.game.items.count)) == off.game.items.ordered.map(\.key))
        var c = SimConfig(); c.mode = .dojo
        #expect(!Sim(data: off, seed: 5, config: c).w.sd.dojoHero.contains { $0.id == "nv_kneelift" || $0.id == "nv_duckup" })
        var c2 = SimConfig(); c2.mode = .dojo; c2.nativeMoves = true
        let on = Sim(data: G.on, seed: 5, config: c2).w.sd.dojoHero
        #expect(on.contains { $0.id == "nv_kneelift" } && on.contains { $0.id == "nv_duckup" })
    }

    @Test func deterministic() {
        func run() -> (Int, Double, [String: Int]) {
            let sim = Sim(data: G.on, seed: 41, config: G.config(stage: 1))
            _ = Self.give(sim.w, "nv_kneelift", uid: 9811); _ = Self.give(sim.w, "nv_duckup", uid: 9812)
            var used: [String: Int] = [:]
            for _ in 0..<(60 * 80) { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero, h.attackerAnim.hasPrefix("nv_") { used[h.attackerAnim, default: 0] += 1 } } }
            return (sim.snapshot.kills, sim.snapshot.hp, used)
        }
        let a = run(), b = run()
        #expect(a.0 == b.0 && a.1 == b.1 && a.2 == b.2)
        print("[VF] 4 노선 80초: 처치 \(a.0) · 적중 \(a.2)")
        #expect((a.2["nv_kneelift"] ?? 0) + (a.2["nv_duckup"] ?? 0) > 0)
    }

    // MARK: 밸런스(가방에 두 기술 없음 ↔ 있음)

    struct Res { var alive = 0.0, kills = 0.0, taken = 0.0, ci = 0.0, knee = 0.0, duck = 0.0 }
    static func run(seed: UInt32, seconds: Double, stage: Int, add: Bool) -> Res {
        let sim = Sim(data: G.on, seed: seed, config: G.config(stage: stage))
        let one = ProcessInfo.processInfo.environment["BB_VF_ONLY"]   // 한 기술만(조정용): nv_kneelift · nv_duckup
        if add && one != "nv_duckup" { _ = give(sim.w, "nv_kneelift", uid: 9811) }
        if add && one != "nv_kneelift" { _ = give(sim.w, "nv_duckup", uid: 9812) }
        var r = Res()
        for _ in 0..<Int(seconds * 60) {
            for e in sim.step() { if case .skillUsed(_, let anim, _) = e { if anim == "nv_kneelift" { r.knee += 1 }; if anim == "nv_duckup" { r.duck += 1 } } }
            if sim.state == "over" || sim.state == "end" { break }
        }
        let s = sim.snapshot
        r.alive = s.hp > 0 ? 1 : 0; r.kills = Double(s.kills); r.taken = s.stats.taken; r.ci = Double(s.car)
        return r
    }

    @Test func balance() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let sets0: [(String, Int, Double, Int)] = big
            ? [("D 노선 240초", 40, 240, 0), ("4 노선 240초", 40, 240, 1), ("7 노선 240초", 40, 240, 3)]
            : [("4 노선 120초", 6, 120, 1)]
        let only = ProcessInfo.processInfo.environment["BB_VF_STAGE"].flatMap(Int.init)   // 한 노선만(조정용)
        let nOv = ProcessInfo.processInfo.environment["BB_VF_N"].flatMap(Int.init)   // 판 수 바꾸기(조정용)
        let sets = (only.map { st in sets0.filter { $0.3 == st } } ?? sets0).map { ($0.0, nOv ?? $0.1, $0.2, $0.3) }
        var md = "| 묶음 | 지표 | 두 기술 없음 | 두 기술 있음 | 차 |\n|---|---|---:|---:|---:|\n"
        var use = "| 묶음 | 무릎 올려치기 씀/판 | 파고들어 올려치기 씀/판 |\n|---|---:|---:|\n"
        for (name, n, sec, st) in sets {
            var A: [Res] = [], B: [Res] = []
            for k in 0..<n { let seed = UInt32(9100 + k * 17); A.append(Self.run(seed: seed, seconds: sec, stage: st, add: false)); B.append(Self.run(seed: seed, seconds: sec, stage: st, add: true)) }
            func m(_ R: [Res], _ f: (Res) -> Double) -> Double { R.map(f).reduce(0, +) / Double(R.count) }
            for (key, f) in [("생존율", { (r: Res) in r.alive }), ("처치", { $0.kills }), ("받은 피해", { $0.taken }), ("도달 칸", { $0.ci })] as [(String, (Res) -> Double)] {
                let a = m(A, f), b = m(B, f)
                md += "| \(name) (\(n)판) | \(key) | \(String(format: "%.2f", a)) | \(String(format: "%.2f", b)) | \(String(format: key == "생존율" ? "%+.0f pp" : "%+.2f", key == "생존율" ? (b - a) * 100 : b - a)) |\n"
                if !big && key == "생존율" { #expect(abs(b - a) <= 0.34) }
            }
            use += "| \(name) | \(String(format: "%.1f", m(B) { $0.knee })) | \(String(format: "%.1f", m(B) { $0.duck })) |\n"
            #expect(B.contains { $0.knee > 0 } || B.contains { $0.duck > 0 })
        }
        print(md); print(use)
        if big {
            let url = G.root.appending(path: "tools/js/out/moves/vf_balance.md")
            try (md + "\n" + use).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
