import Testing
import Foundation
@testable import BBSim
import BBContent

/// 네이티브 공방(docs/08 — 군중 공격권 · 가드/높이 · 가드 크래시 · 끼어들기 · 저스트 가드) 검사. 깃발(nativeMoves) 켠 쪽만 바뀐다.
/// BB_NV_STATS=1 이면 표본을 늘려 공방 전(nativeGuard 끔)/후 비교표를 tools/js/out/guard/balance.md 에 쓴다.
@Suite struct NativeGuardTests {
    static let base = SimRunTests.data
    static let on = base.variant(nativeMoves: true)
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func config(stage: Int = 0, guardOn: Bool = true, kit: String = "basic") -> SimConfig {
        var c = SimRunTests.harnessConfig(stage: stage, kit: kit); c.nativeMoves = true; c.nativeGuard = guardOn; c.autoSpecial = true
        return c
    }

    // MARK: 장면 만들기

    /// 첫 칸 싸움에서 적을 치우고 types 를 세운다(주인공 x 150 · 적은 오른쪽 dx 마다)
    static func arena(_ types: [String], dx: [Double], seed: UInt32 = 3, stage: Int = 0) -> (Sim, World, [Actor]) {
        let sim = Sim(data: on, seed: seed, config: config(stage: stage)), w = sim.w
        for _ in 0..<400 { sim.step(); if w.state == "fight" && w.legT > 2 { break } }
        w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9; w.maxHP = 9999; w.hp = 9999
        let H = w.hero!; H.x = 150; H.flip = false; w.setAnim(H, "idle"); w.nvInit(H)
        w.spawnWave(types, fromDoors: false)
        let F = w.foes()
        for (k, a) in F.enumerated() { a.x = 150 + dx[k]; a.flip = a.x > H.x; a.e!.hp = 999; a.e!.max = 999; w.nvInit(a); w.setAnim(a, "idle") }
        return (sim, w, F)
    }

    // MARK: 높이 · 가드 표

    @Test func heightGuardMatrix() {
        // 서서 막기: 상단 · 중단을 막고 하단에 진다 / 앉아 막기: 하단을 막고 상단은 흘리며 중단에 진다 / 잡기는 둘 다 무시
        #expect(NvHeight.high.blockedBy(1) && NvHeight.mid.blockedBy(1) && !NvHeight.low.blockedBy(1) && !NvHeight.grab.blockedBy(1))
        #expect(NvHeight.low.blockedBy(2) && !NvHeight.mid.blockedBy(2) && !NvHeight.high.blockedBy(2) && NvHeight.high.whiffs(2) && !NvHeight.mid.whiffs(2))
        #expect(NativeContent.heroHeight("jab") == .high && NativeContent.heroHeight("upper") == .mid && NativeContent.heroHeight("sweep") == .low && NativeContent.heroHeight("suplex") == .grab)
        #expect(NativeContent.foeHeight("sweep") == .low && NativeContent.foeHeight("nv_lowk") == .low && NativeContent.foeHeight("hbutt") == .mid && NativeContent.foeHeight("round") == .high)
        // 깃발 꺼짐 묶음엔 하단기 예고 무게가 없다(웹 FOE_W 그대로)
        #expect(Self.base.foeW["sweep"] == nil && Self.on.foeW["nv_lowk"] == "M" && Self.on.jwCue["nv_lowk"] == "lk_hit")
    }

    @Test func blockCrashAndWhiff() {
        let (_, w, F) = Self.arena(["punk"], dx: [22]), H = w.hero!, A = F[0]
        // 서서 막기 vs 상단 연타 → 막힌다(칩 25%만) → 게이지가 0 이면 크래시
        w.setAnim(A, "nv_gdH"); A.nvg.stance = 1
        let meter0 = A.nvg.meter
        H.anim = "jab"
        w.damage(H, A, 8)
        #expect(A.e!.hp == 999 - 3, Comment(rawValue: "칩 \(A.e!.hp)"))   // jsRound(8 × 0.4)
        #expect(A.nvg.meter < meter0 && w.stats.nvg.blocks == 1 && A.anim == "nv_gdHb")
        var n = 0
        while w.stats.nvg.crashes == 0 && n < 12 { w.time += 0.05; w.setAnim(A, "nv_gdH"); H.anim = "jab"; w.damage(H, A, 8); n += 1 }
        #expect(w.stats.nvg.crashes == 1 && A.anim == "nv_gcrash" && w.time < A.nvg.crashUntil && A.e!.stun > 1)
        // 무방비: 다음 타격은 치명(×1.25 · 막지 않는다)
        let hp1 = A.e!.hp; H.anim = "jab"; w.damage(H, A, 8)
        #expect(hp1 - A.e!.hp == 10)   // jsRound(8 × 1.3)
        // 하단은 서서 막기를 뚫는다
        let (_, w2, F2) = Self.arena(["punk"], dx: [22]), H2 = w2.hero!, B = F2[0]
        w2.setAnim(B, "nv_gdH"); B.nvg.stance = 1; H2.anim = "sweep"; w2.damage(H2, B, 8)
        #expect(B.e!.hp == 999 - 8 && w2.stats.nvg.blocks == 0)
        // 앉아 막기: 상단은 숙여 흘리고(피해 0) · 중단(어퍼)은 맞는다
        let (_, w3, F3) = Self.arena(["punk"], dx: [22]), H3 = w3.hero!, C = F3[0]
        w3.setAnim(C, "nv_gdL"); C.nvg.stance = 2; H3.anim = "hook"; w3.damage(H3, C, 8)
        #expect(C.e!.hp == 999 && w3.stats.nvg.whiffs == 1)
        w3.time += 0.1; w3.setAnim(C, "nv_gdL"); H3.anim = "upper"; w3.damage(H3, C, 8)
        #expect(C.e!.hp < 999)
        // 등 뒤에서는 막지 못한다
        let (_, w4, F4) = Self.arena(["punk"], dx: [22]), H4 = w4.hero!, D = F4[0]
        w4.setAnim(D, "nv_gdH"); D.nvg.stance = 1; D.flip = false; H4.anim = "jab"; w4.damage(H4, D, 8)
        #expect(D.e!.hp == 991)
    }

    @Test func heroGuardsAndJustGuard() {
        let (sim, w, F) = Self.arena(["punk"], dx: [24]), H = w.hero!, A = F[0]
        // 주인공 서서 막기 vs 적 상단 → 막힘(피해 0) · 막은 직후 받아치기 조건
        w.setAnim(H, "nv_gdH"); H.nvg.stance = 1; A.lastMove = "jab"; A.anim = "jab"
        let hp0 = w.hp
        w.damage(A, H, 9)
        #expect(w.hp == hp0 && w.stats.nvg.heroBlocks == 1 && H.anim == "nv_gdHb")
        #expect(w.condOK("counter", H, A, F))
        // 하단 로킥은 서서 막기를 뚫는다
        w.setAnim(H, "nv_gdH"); A.lastMove = "nv_lowk"; w.damage(A, H, 9)
        #expect(w.hp < hp0 && w.stats.nvg.lowBeats == 1)
        // 저스트 가드: 가드 중 적이 치려는 순간 그쪽을 누르면 받아치기
        w.hp = 9999; w.setAnim(H, "nv_gdH"); w.time += 1; H.nvg.blockAt = -9
        A.action = nil; w.setAnim(A, "idle"); w.foeStrike(A, "jab")
        var guardN = 0
        while let tt = w.timeToCue(A), tt > w.justW() && guardN < 60 { w.stepAnim(); guardN += 1 }
        #expect(A.action != nil && !(A.action!.fired))
        w.manual(1)
        #expect(w.stats.nvg.justGuards == 1 && w.stats.justs == 1 && A.action == nil)
        _ = sim
    }

    @Test func heroReadsGuardAndSwitchesHeight() {
        let (_, w, F) = Self.arena(["punk"], dx: [24]), A = F[0]
        w.bag = [Item(id: "punch", uid: 901, tier: 1, opt: nil), Item(id: "sweep", uid: 902, tier: 1, opt: nil), Item(id: "throw", uid: 903, tier: 1, opt: nil)]
        for (k, b) in w.bag.enumerated() { b.x = k * 3; b.y = 0 }; w.renderBag()
        for b in w.bag { b.t = 99 }
        let iP = w.bag.firstIndex { $0.id == "punch" }!, iS = w.bag.firstIndex { $0.id == "sweep" }!, iT = w.bag.firstIndex { $0.id == "throw" }!
        // 서서 막는 상대: 하단 · 잡기를 고르고 상단 주먹은 덜 고른다 — 상단이 막힌 직후면 더 덜
        w.setAnim(A, "nv_gdH"); A.nvg.stance = 1
        #expect(w.nvHeightWeight(iS, A) > 2 && w.nvHeightWeight(iT, A) > 2 && w.nvHeightWeight(iP, A) < 1)
        A.nvg.blockAt = w.time; A.nvg.blockH = NvHeight.high.rawValue
        #expect(w.nvHeightWeight(iP, A) <= 0.3)
        // 앉아 막는 상대: 주먹 콤보는 어퍼(중단)로 바꿔 친다 · 하단은 덜
        w.setAnim(A, "nv_gdL"); A.nvg.stance = 2
        #expect(w.nvHeightWeight(iS, A) < w.nvHeightWeight(iP, A) && w.nvHeightWeight(iP, A) > 2)
        let sw0 = w.stats.nvg.heightSwitches
        w.useSkill(iP, A, false)
        #expect(w.hero.anim == "upper" || w.hero.queue.last?.anim == "upper")
        #expect(w.stats.nvg.heightSwitches == sw0 + 1)
    }

    // MARK: 군중

    /// 실전 몇 판: 쪽마다 공격권 ≤ 한도 · 공격은 공격권 주인(또는 끼어들기)만 · 대기 자리는 겹치지 않는다 · 넘김 숨 고르기
    @Test func crowdTokensSlotsHandoff() {
        var strikes = 0, bad = 0, slotDup = 0, grants = 0, quick = 0
        for (seed, stage) in [(5, 0), (6, 1), (7, 3)] as [(UInt32, Int)] {
            let sim = Sim(data: Self.on, seed: seed, config: Self.config(stage: stage)), w = sim.w
            var lastRel: [Int: Double] = [:], had: [ActorID: Bool] = [:]
            for _ in 0..<(90 * 60) {
                sim.step()
                guard let H = w.hero, !H.dead, w.state == "fight", w.spc == nil else { continue }
                let F = w.foes().filter(w.nvCrowdFoe), cap = w.nvTokenCap()
                for s in [-1.0, 1.0] {
                    let side = F.filter { ($0.x >= H.x ? 1.0 : -1.0) == s }
                    let used = side.filter { $0.nvg.tok }.reduce(0) { $0 + min(cap, w.nvTokenCost($1)) }
                    #expect(used <= cap, Comment(rawValue: "쪽 \(s) 공격권 \(used) > \(cap)"))
                    // 자리를 잡고 가드를 올린 대기 적끼리는 겹치지 않는다(12px 이상 — 0.5px 허용: 주인공이 스텝 인 하는 틱에 자리가 다시 잡히며
                    // 11.9px 로 한 틱 스치는 경우가 있다. 무릎 올려치기 · 파고들어 올려치기 아이템이 상점 굴림을 바꿔 씨앗 5 판에서 드러남 — docs/07 §7-VF)
                    let settled = side.filter { !$0.nvg.tok && w.nvIsGuardAnim($0.anim) }.map(\.x).sorted()
                    for i in settled.indices.dropFirst() where settled[i] - settled[i - 1] < 11.5 { slotDup += 1 }
                }
                for a in F {
                    if a.windup == w.time { strikes += 1; if !a.nvg.tok && a.nvg.cut != 3 { bad += 1 } }
                    let was = had[a.id] ?? false
                    if was && !a.nvg.tok { lastRel[a.nvg.tokSide < 0 ? 0 : 1] = w.time }
                    if !was && a.nvg.tok { grants += 1; if let r = lastRel[a.nvg.tokSide < 0 ? 0 : 1], w.time - r < 0.14 { quick += 1 } }
                    had[a.id] = a.nvg.tok
                }
            }
        }
        #expect(strikes > 30)
        #expect(bad == 0, Comment(rawValue: "공격권 없이 친 적 \(bad)/\(strikes)"))
        #expect(slotDup == 0)
        #expect(grants > 20 && quick == 0, Comment(rawValue: "넘김 \(grants) · 숨 고르기 없이 \(quick)"))
    }

    /// 많은 적(한쪽에 8명 · 양쪽 11명): 대기 적끼리 겹치지 않는다(몸 밀기 14px 근처 이상 — 자리 15px — 칸 끝을 넘으면 문 밖 근처에서 기다린다)
    @Test func crowdManyNoOverlap() {
        for hx in [150.0, 330.0] {
            let (sim, w, F) = Self.arena(["punk", "gear", "triad", "pick", "punk", "gear", "triad", "punk", "gear", "pick", "triad"], dx: [30, 50, 70, 90, 110, 130, 150, 170, -40, -60, -80], seed: 9)
            w.hero.x = hx; for (k, a) in F.enumerated() { a.x = hx + [30, 50, 70, 90, 110, 130, 150, 170, -40, -60, -80][k] }
            var worst = 999.0, settledN = 0
            for t in 0..<(14 * 60) {
                w.hero.hs = 99; w.hero.x = hx; sim.step(); w.hp = 9999   // 주인공을 세워 둔다(군중 자리만 본다)
                guard t > 6 * 60, let H = w.hero else { continue }
                for s in [-1.0, 1.0] {
                    let xs = w.foes().filter { ($0.x >= H.x ? 1.0 : -1.0) == s && !$0.nvg.tok && w.nvIsGuardAnim($0.anim) }.map(\.x).sorted()   // 자리를 잡고 가드를 올린 대기 적
                    settledN = max(settledN, xs.count)
                    for i in xs.indices.dropFirst() { worst = min(worst, xs[i] - xs[i - 1]) }
                }
            }
            #expect(settledN >= 4, Comment(rawValue: "x \(hx): 자리 잡은 대기 적 \(settledN)"))
            #expect(worst >= 13, Comment(rawValue: "x \(hx): 가장 가까운 대기 적 간격 \(worst)"))
        }
    }

    /// 같은 씨앗 → 같은 공방(결정성)
    @Test func deterministic() {
        func run() -> NvGuardStats { let sim = Sim(data: Self.on, seed: 77, config: Self.config()); for _ in 0..<(60 * 60) { sim.step() }; return sim.snapshot.stats.nvg }
        #expect(run() == run())
    }

    // MARK: 밸런스 · 측정

    struct Res { var alive = 0.0, kills = 0.0, taken = 0.0, dealt = 0.0, ci = 0.0, sec = 0.0, spc = 0.0; var g = NvGuardStats() }
    static func run(seed: UInt32, seconds: Double, stage: Int, guardOn: Bool, kit: String = "basic") -> Res {
        let sim = Sim(data: on, seed: seed, config: config(stage: stage, guardOn: guardOn, kit: kit))
        var n = 0, spc = 0.0
        for _ in 0..<Int(seconds * 60) { for e in sim.step() { if case .specialUsed = e { spc += 1 } }; n += 1; if sim.state == "over" || sim.state == "end" { break } }
        let s = sim.snapshot
        return Res(alive: s.hp > 0 ? 1 : 0, kills: Double(s.kills), taken: s.stats.taken, dealt: s.stats.dealt, ci: Double(s.car), sec: Double(n) / 60, spc: spc, g: s.stats.nvg)
    }

    @Test func balanceHolds() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let sets: [(String, Int, Double, Int, String)] = big
            ? [("D 노선 240초", 40, 240, 0, "basic"), ("4 노선 240초", 30, 240, 1, "basic"), ("7 노선 240초", 30, 240, 3, "basic"), ("D 노선 잡기 180초", 24, 180, 0, "grap"), ("D 노선 발 180초", 24, 180, 0, "foot")]
            : [("D 노선 120초", 8, 120, 0, "basic"), ("4 노선 120초", 6, 120, 1, "basic")]
        var md = "| 묶음 | 지표 | 공방 전 | 공방 후 | z |\n|---|---|---:|---:|---:|\n"
        var gmd = "| 묶음 | 동시 공격자(평균 · 최대) 전 → 후 | 막기/분(적 · 주인공) | 가드 크래시/분(적 · 주인공) | 높이 바꾸기/분 | 교환 간격(초) | 끼어들기/분 | 페인트 · 도발/분 | 저스트 가드 |\n|---|---|---:|---:|---:|---:|---:|---:|---:|\n"
        let only = ProcessInfo.processInfo.environment["BB_NV_ONLY"]   // 개발용: 이름 앞부분으로 묶음 하나만
        for (name, n, sec, st, kit) in sets where only == nil || name.hasPrefix(only!) {
            var A: [Res] = [], B: [Res] = []
            for k in 0..<n { let seed = UInt32(9100 + k * 17); A.append(Self.run(seed: seed, seconds: sec, stage: st, guardOn: false, kit: kit)); B.append(Self.run(seed: seed, seconds: sec, stage: st, guardOn: true, kit: kit)) }
            for (key, f) in [("처치", \Res.kills), ("받은 피해", \Res.taken), ("준 피해", \Res.dealt), ("생존율", \Res.alive), ("도달 칸", \Res.ci), ("필살기", \Res.spc)] as [(String, KeyPath<Res, Double>)] {
                let a = A.map { $0[keyPath: f] }, b = B.map { $0[keyPath: f] }
                func ms(_ v: [Double]) -> (Double, Double) { let m = v.reduce(0, +) / Double(v.count); return (m, sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(1, v.count - 1)))) }
                let (am, asd) = ms(a), (bm, bsd) = ms(b)
                let se = sqrt((asd * asd + bsd * bsd) / Double(n)), z = se > 0 ? (bm - am) / se : 0
                md += "| \(name) (\(n)판) | \(key) | \(String(format: "%.2f ± %.2f", am, asd)) | \(String(format: "%.2f ± %.2f", bm, bsd)) | \(String(format: "%+.2f", z)) |\n"
                if big { continue }   // 큰 표본은 기록용(감독 확인 — docs/08 §6)
                if key == "생존율" { #expect(abs(bm - am) <= 0.3, Comment(rawValue: "\(name) \(key) \(am) → \(bm)")) }
                else if key == "처치" || key == "받은 피해" { #expect(abs(bm - am) <= max(8, am * (key == "처치" ? 0.25 : 0.6)), Comment(rawValue: "\(name) \(key) \(am) → \(bm)")) }
            }
            let mins = B.reduce(0) { $0 + $1.sec } / 60, minsA = A.reduce(0) { $0 + $1.sec } / 60
            func sum(_ R: [Res], _ f: (NvGuardStats) -> Double) -> Double { R.reduce(0) { $0 + f($1.g) } }
            let atkA = sum(A, { $0.atkSum }) / max(1, sum(A, { $0.atkTicks })), atkB = sum(B, { $0.atkSum }) / max(1, sum(B, { $0.atkTicks }))
            let mxA = A.map { $0.g.atkMax }.max() ?? 0, mxB = B.map { $0.g.atkMax }.max() ?? 0
            let ex = sum(B, { Double($0.exchanges) })
            let pileA = sum(A, { $0.atkPile }) / max(1, sum(A, { $0.atkBusy })), pileB = sum(B, { $0.atkPile }) / max(1, sum(B, { $0.atkBusy }))
            gmd += "| \(name) | \(String(format: "%.2f", atkA)) · \(mxA) (몰매 \(Int(pileA * 100))%) → \(String(format: "%.2f", atkB)) · \(mxB) (몰매 \(Int(pileB * 100))%) | "
            gmd += "\(String(format: "%.1f · %.1f", sum(B, { Double($0.blocks) }) / mins, sum(B, { Double($0.heroBlocks) }) / mins)) | "
            gmd += "\(String(format: "%.2f · %.2f", sum(B, { Double($0.crashes) }) / mins, sum(B, { Double($0.heroCrashes) }) / mins)) | "
            gmd += "\(String(format: "%.1f", sum(B, { Double($0.heightSwitches) }) / mins)) | \(String(format: "%.1f", ex > 0 ? mins * 60 / ex : 0)) | "
            gmd += "\(String(format: "%.2f", sum(B, { Double($0.cutIns) }) / mins)) | \(String(format: "%.1f · %.1f", sum(B, { Double($0.feints) }) / mins, sum(B, { Double($0.taunts) }) / mins)) | \(Int(sum(B, { Double($0.justGuards) }))) |\n"
            _ = minsA
            #expect(atkB <= atkA + 0.05, Comment(rawValue: "\(name) 동시 공격자 \(atkA) → \(atkB)"))
            #expect(sum(B, { Double($0.blocks) }) > 0 && sum(B, { Double($0.crashes) }) > 0, Comment(rawValue: "\(name) 막기 · 크래시가 나와야 한다"))
        }
        print(md); print(gmd)
        if big {
            let url = Self.root.appending(path: "tools/js/out/guard/balance.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (md + "\n" + gmd).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// 개발용: 한 판을 돌려 주인공이 맞은 공격 · 공방 기록을 찍는다(BB_NV_DEBUG=1)
@Suite struct NativeGuardDebug {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_NV_DEBUG"] == "1")) func dump() {
        for guardOn in [false, true] {
            var hurt: [String: (n: Int, dmg: Double)] = [:]
            var tot = NvGuardStats(), kills = 0, taken = 0.0
            for seed in [9100, 9117, 9134, 9151] as [UInt32] {
                let sim = Sim(data: NativeGuardTests.on, seed: seed, config: NativeGuardTests.config(stage: 0, guardOn: guardOn))
                let w = sim.w
                for _ in 0..<(120 * 60) {
                    let hp0 = w.hp
                    let ev = sim.step()
                    for e in ev { if case .hit(let h) = e, h.heroWasHit, let a = w.ents.first(where: { $0.id == h.attacker }) {
                        let k = (a.lastMove ?? "?") + (a.nvg.cut > 0 ? "·끼어들기" : a.nvg.tok ? "·토큰" : "·대기")
                        hurt[k, default: (0, 0)].n += 1; hurt[k, default: (0, 0)].dmg += Double(h.damage) } }
                    _ = hp0
                    if sim.state == "over" { break }
                }
                let st = w.stats.nvg
                tot.blocks += st.blocks; tot.heroBlocks += st.heroBlocks; tot.crashes += st.crashes; tot.heroCrashes += st.heroCrashes; tot.lowBeats += st.lowBeats
                tot.cutIns += st.cutIns; tot.whiffs += st.whiffs; tot.pierces += st.pierces; tot.grants += st.grants; tot.atkSum += st.atkSum; tot.atkTicks += st.atkTicks
                kills += w.kills; taken += w.stats.taken
            }
            print("== guard \(guardOn): kills \(kills) taken \(taken) atk \(tot.avgAttackers)")
            print("   blocks \(tot.blocks) heroBlocks \(tot.heroBlocks) crash \(tot.crashes) heroCrash \(tot.heroCrashes) lowBeats \(tot.lowBeats) cut \(tot.cutIns) whiff \(tot.whiffs) pierce \(tot.pierces) grants \(tot.grants)")
            for (k, v) in hurt.sorted(by: { $0.value.dmg > $1.value.dmg }) { print("   \(k): \(v.n)회 \(Int(v.dmg))") }
        }
    }
}

extension NativeGuardDebug {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_NV_DEBUG"] == "1")) func spacing() {
        for stage in [0, 1] {
            var ticks = 0, stack = 0, waitN = 0, waitD = 0.0, atSlot = 0, guardN = 0, hist = [Int](repeating: 0, count: 8)
            let sim = Sim(data: NativeGuardTests.on, seed: 44, config: NativeGuardTests.config(stage: stage)), w = sim.w
            for _ in 0..<(120 * 60) {
                sim.step(); guard let H = w.hero, w.state == "fight" else { continue }
                let F = w.foes().filter { w.nvCrowdFoe($0) && !$0.nvg.tok && $0.nvg.cut == 0 }
                if F.count < 2 { continue }
                ticks += 1
                for s in [-1.0, 1.0] {
                    let side = F.filter { ($0.x >= H.x ? 1.0 : -1.0) == s }.map { abs($0.x - H.x) }.sorted()
                    for i in 1..<max(1, side.count) where side[i] - side[i - 1] < 10 { stack += 1 }
                }
                for a in F { waitN += 1; let d = abs(a.x - H.x); waitD += d; hist[min(7, Int(d / 16))] += 1; if abs(d - a.nvg.slot) < 8 { atSlot += 1 }; if w.nvGuardOf(a) > 0 { guardN += 1 } }
            }
            print("stage \(stage): ticks \(ticks) stack/tick \(Double(stack) / Double(max(1, ticks))) waitDist \(waitD / Double(max(1, waitN))) atSlot \(Double(atSlot) / Double(max(1, waitN))) guarding \(Double(guardN) / Double(max(1, waitN))) hist16 \(hist)")
        }
    }
}

extension NativeGuardDebug {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_NV_DEBUG"] == "1")) func heroTime() {
        for g in [false, true] {
            var cat: [String: Int] = [:], hitsBlocked = 0, kills = 0, uses = 0, totTicks = 0
            for seed in [9100, 9117, 9134, 9151, 9168, 9185] as [UInt32] {
                let sim = Sim(data: NativeGuardTests.on, seed: seed, config: NativeGuardTests.config(stage: 0, guardOn: g)), w = sim.w
                for _ in 0..<(240 * 60) {
                    let ev = sim.step()
                    for e in ev { if case .skillUsed = e { uses += 1 } }
                    guard w.state == "fight", !w.foes().isEmpty, let H = w.hero else { continue }
                    totTicks += 1
                    let a = H.anim
                    let k = a == "walk" ? (H.runU > w.gameTime ? "run" : "walk") : a == "idle" ? "idle" : a.hasPrefix("nv_gd") ? "guard" : w.data.reacts.contains(a) || w.data.falls.contains(a) ? "hurt" : a.hasPrefix("nv_") && !["nv_flick","nv_liver","nv_cork","nv_roll"].contains(a) ? "move:" + a : "act"
                    cat[k, default: 0] += 1
                }
                hitsBlocked += w.stats.nvg.blocks; kills += w.kills
            }
            print("guard \(g) kills \(kills) uses \(uses) blocks \(hitsBlocked)")
            for (k, v) in cat.sorted(by: { $0.value > $1.value }) { print("   \(k) \(String(format: "%.1f%%", 100 * Double(v) / Double(totTicks)))") }
        }
    }
}

