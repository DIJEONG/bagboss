import Testing
import Foundation
@testable import BBSim
import BBContent

/// 무도장 · 이동 다듬기(docs/07 I8 · I9 · I10 · §5-4) — 깃발(nativeMoves) 켠 쪽만 바뀌고, 꺼진 쪽은 웹 그대로(StoryLockstepTests 무도장 판)
@Suite struct DojoNativeTests {
    static func dojo(_ on: Bool, seed: UInt32 = 5) -> Sim {
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = on; c.skipTalks = true; c.playSpeed = 1; c.trackDrawnPose = true
        let sim = Sim(data: on ? SimRunTests.data.variant(nativeMoves: true) : SimRunTests.data, seed: seed, config: c)
        for _ in 0..<30 { sim.step() }
        return sim
    }
    static func run(_ sim: Sim, _ ticks: Int, _ f: (Int) -> Void = { _ in }) { for i in 0..<ticks { sim.step(); f(i) } }

    // MARK: I8 체력

    @Test func dojoHeroNeverDies() {
        let sim = Self.dojo(true), w = sim.w
        sim.apply(.dojo(.demoBag(0)))
        #expect(w.maxHP == 9999 && w.hp == 9999)   // renderBag 뒤에도 9999
        sim.apply(.dojo(.special("fist"))); Self.run(sim, 60 * 7)
        for _ in 0..<30 { sim.apply(.dojo(.foe("bat"))); Self.run(sim, 60 * 3) }
        #expect(!w.hero!.dead && sim.state == "fight" && w.hp >= w.maxHP * 0.5)
        // 억지로 쓰러뜨려도 다음 명령에서 일어난다
        w.hp = 0; w.hero!.dead = true; Self.run(sim, 5)
        #expect(!w.hero!.dead && sim.state == "fight" && w.hp == 9999)
        w.hero!.dead = true; w.setState("over")
        sim.apply(.dojo(.hero("kick", combo: nil))); Self.run(sim, 60 * 2)
        #expect(!w.hero!.dead && sim.state == "fight")
    }

    @Test func flagOffKeepsWebHP() {
        let sim = Self.dojo(false), w = sim.w
        sim.apply(.dojo(.demoBag(0)))
        #expect(w.maxHP == w.heroMax())   // 웹 그대로(renderBag → heroMax)
    }

    // MARK: 커스텀 콤보 16단(웹 CC_MAX 8 → NativeContent.dojoCCMax)

    /// 커스텀 콤보 한 번 끝까지: (결과 글 · 단계별 결과 · 끝난 틱)
    static func runCustom(_ sim: Sim, _ L: [String]) -> (String?, [String]?, Int) {
        sim.apply(.dojo(.setCustom(L))); sim.apply(.dojo(.customRun))
        var res: String?, n = 0
        while n < 60 * 120 && res == nil { for e in sim.step() { if case .dojoResult(let t) = e { res = t } }; n += 1 }
        return (res, sim.snapshot.dojo?.ccRes, n)
    }
    static func longCombo(_ w: World, _ n: Int) -> [String] {
        let pal = ["punch:0", "punch:1", "punch:2", "punch:3", "kick", "elbow", "knee", "upper", "round"].filter { v in w.sd.dojoMoves.contains { $0.1 == v } }
        return (0..<n).map { pal[$0 % pal.count] }
    }

    @Test func custom16Runs() {
        let sim = Self.dojo(true), w = sim.w
        #expect(w.sd.ccMax == NativeContent.dojoCCMax && NativeContent.dojoCCMax == 16)
        let L = Self.longCombo(w, 20)
        sim.apply(.dojo(.setCustom(L)))
        #expect(sim.snapshot.dojo?.cc == Array(L.prefix(16)))   // 17번째부터 잘린다
        let (res, cr, ticks) = Self.runCustom(sim, Array(L.prefix(16)))
        #expect(res?.hasPrefix("16타 중") == true)
        #expect(cr?.count == 16 && sim.snapshot.dojo?.seq == nil)
        #expect(ticks < 60 * 100)
        // 16단 재생 중 단계 번호가 끝까지 간다(마지막 단계도 실행)
        let again = Self.dojo(true); var maxI = 0
        again.apply(.dojo(.setCustom(Array(L.prefix(16))))); again.apply(.dojo(.customRun))
        for _ in 0..<(60 * 100) { again.step(); if let q = again.snapshot.dojo?.seq { maxI = max(maxI, q.i) } else if maxI > 0 { break } }
        #expect(maxI == 16)
    }

    @Test func custom16Deterministic() {
        let a = Self.dojo(true, seed: 9), b = Self.dojo(true, seed: 9)
        let L = Self.longCombo(a.w, 16)
        let ra = Self.runCustom(a, L), rb = Self.runCustom(b, L)
        #expect(ra.0 == rb.0 && ra.1 == rb.1 && ra.2 == rb.2)
    }

    @Test func custom8StillWorksAndFlagOffKeeps8() {
        // 예전 8단 콤보는 그대로 · 깃발 꺼지면 웹 CC_MAX(8)로 잘린다
        let on = Self.dojo(true), off = Self.dojo(false)
        let L8 = Self.longCombo(on.w, 8)
        let r = Self.runCustom(on, L8)
        #expect(r.0?.hasPrefix("8타 중") == true && r.1?.count == 8)
        #expect(off.w.sd.ccMax == 8)
        off.apply(.dojo(.setCustom(Self.longCombo(on.w, 16))))
        #expect(off.snapshot.dojo?.cc.count == 8)
    }

    // MARK: I9 단독 시연 조건

    /// 기술 시연 한 번: 허수아비가 맞은 횟수
    static func hits(_ sim: Sim, _ cmd: DojoCommand, ticks: Int = 60 * 4) -> Int {
        let w = sim.w; var n = 0
        sim.apply(.dojo(cmd))
        Self.run(sim, ticks) { _ in if let D = w.dojoDummy(), D.e!.hp < 99999 - 1e-6 { n += 1; D.e!.hp = 99999 } }
        return n
    }

    @Test func soloDemosConnect() {
        let on = Self.dojo(true), off = Self.dojo(false)
        #expect(Self.hits(off, .hero("stomp", combo: nil)) == 0)   // 웹: 누운 허수아비에 헛침
        #expect(Self.hits(on, .hero("stomp", combo: nil)) >= 1)
        #expect(Self.hits(off, .hero("cycle", combo: nil)) == 0)   // 웹: 서 있는 상대에 헛침
        #expect(Self.hits(on, .hero("cycle", combo: nil)) >= 1)
        #expect(Self.hits(on, .misc("polespin")) >= 1)
        #expect(Self.hits(on, .misc("hangkick")) >= 1)
        #expect(Self.hits(on, .hero("fkick", combo: nil)) >= 1)
    }

    @Test func soloDemoPlacement() {
        let sim = Self.dojo(true), w = sim.w
        sim.apply(.dojo(.misc("polespin")))
        let H = w.hero!, D = w.dojoDummy()!
        let pole = w.sd.djPoles.min { abs($0 - H.x) < abs($1 - H.x) }!
        #expect(abs(H.x - pole) <= 5 && abs(D.x - H.x) >= 20 && H.anim == "polespin")
        sim.apply(.dojo(.misc("hangkick")))
        #expect(w.data.strapX.contains(H.x) && abs(D.x - H.x) >= 20 && H.anim == "hangkick")
        // 날아차기: 뒷걸음 없이 바로(시작 0.1초 안 주인공이 허수아비에서 멀어지지 않는다)
        sim.apply(.dojo(.hero("fkick", combo: nil))); let d0 = abs(D.x - H.x)
        Self.run(sim, 6); #expect(abs(D.x - H.x) <= d0 + 0.5)
        // 반응: 40px · 꽂기는 높이에서
        sim.apply(.dojo(.react("rSpike")))
        #expect(abs(D.x - H.x) == 40 && D.airOv > 0 && D.spike != nil)
        Self.run(sim, 40); #expect(D.spike == nil && D.airOv == 0)
        sim.apply(.dojo(.react("fall"))); #expect(abs(D.x - H.x) == 40)
    }

    // MARK: I10 이동 — 질주 뒤에는 늘 미끄러져 선다

    @Test func sprintAlwaysSkids() {
        for dx in [100.0, 120, 140, 150, 170, 200] {
            let sim = Self.dojo(true), w = sim.w
            sim.apply(.dojo(.reset))
            let H = w.hero!, D = w.dojoDummy()!; D.x = 250 + dx; w.face(D, H.x)
            sim.apply(.dojo(.hero("kick", combo: nil)))
            var modes: [Int] = [], skidTicks = 0, walkAfterSprint = false, sprintAgain = false, prev = 0, sawSkid = false, cue = false
            Self.run(sim, 150) { _ in
                let m = H.nvm.mode
                if m != prev { modes.append(m) }
                if prev == 2 && m == 1 { walkAfterSprint = true }
                if sawSkid && m == 2 { sprintAgain = true }
                if m == 3 { skidTicks += 1; sawSkid = true }
                if D.e!.hp < 99999 { cue = true }
                prev = m
            }
            #expect(modes.contains(2), "\(dx): 질주 \(modes)")
            #expect(!walkAfterSprint, "\(dx): 질주→걷기로 바로 떨어짐 \(modes)")
            #expect(skidTicks >= 6, "\(dx): 미끄러짐 \(skidTicks)틱")
            #expect(!sprintAgain, "\(dx): 미끄러진 뒤 다시 질주 \(modes)")
            #expect(cue, "\(dx): 공격이 들어가지 않음")
        }
    }

    // MARK: §5-4 경직

    @Test func counterStunsShorter() {
        func maxHS(_ id: String) -> Int {
            let sim = Self.dojo(true), w = sim.w; var n = 0
            sim.apply(.dojo(.hero(id, combo: nil))); Self.run(sim, 120) { _ in if w.hero!.hs > 0 { n += 1 } }
            return n
        }
        let roll = maxHS("nv_roll"), flick = maxHS("nv_flick")
        print("경직 틱: nv_roll \(roll) · nv_flick \(flick)")
        #expect(roll > 0 && roll <= 30 && flick <= 18)
    }
}
