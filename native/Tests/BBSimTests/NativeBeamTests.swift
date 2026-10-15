import Testing
import Foundation
@testable import BBSim
import BBContent
@testable import BBAnim

/// 야근 광선(nv_beam) — docs/07 §7-BM: 큐 · 다단 · 마지막 한 방 · 꿰뚫기 · 위로 꺾기 · 소품 · 끊김 · 깃발 꺼짐
@Suite struct NativeBeamTests {
    typealias G = NativeGuardTests

    @Test func sequenceAndCue() {
        let d = G.on, w = Sim(data: d, seed: 1, config: G.config()).w
        #expect(d.jwCue["nv_beam"] == "bm_fire")
        let s = d.seqJW["nv_beam"]!
        #expect(s.reduce(0) { $0 + $1.n } == 1000)
        #expect(abs(w.atkStartup("nv_beam") - 0.25) < 1e-9)
        let endAt = s.prefix { $0.pose != "bm_end" }.reduce(0) { $0 + $1.n }
        #expect(endAt == 650)   // 유지 0.35초 뒤 마지막 한 방
        for x in s { #expect(x.n.truncatingRemainder(dividingBy: 50) == 0) }
        for (k, p) in NativeMoves.bmPoses { #expect(abs(p.h!.x) <= 4 && abs(p.h!.y) <= 4, Comment(rawValue: k)) }
        #expect(d.item("nv_beam")?.reach == 150 && G.on.game.items.ordered.contains { $0.key == "nv_beam" })
    }

    struct Solo { var hits: [HitInfo] = [], phases: [String] = [], dummyDX = 0.0, words: [String] = [], snapBeam = false }
    static func solo(prep: ((Sim) -> Void)? = nil) -> Solo {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_beam", combo: nil)))
        _ = sim.step(); prep?(sim)
        var R = Solo(); let d0 = w.dojoDummy()!.x
        for _ in 0..<(60 * 3) {
            for e in sim.step() {
                if case .hit(let h) = e, h.attackerIsHero { R.hits.append(h) }
                if case .comicWord(let wd, _, _) = e { R.words.append(wd) }
            }
            let ph = w.nvBeam.map { "\($0.phase)" } ?? "-"
            if R.phases.last != ph { R.phases.append(ph) }
            if sim.snapshot.beam != nil { R.snapBeam = true }
            R.dummyDX = max(R.dummyDX, (w.dojoDummy()!.x - d0) * w.hero!.f)
        }
        return R
    }

    @Test func soloMultiHitAndBlast() {
        let R = Self.solo()
        print("[광선] 단계 \(R.phases) · 적중 \(R.hits.map { "\($0.damage)/\($0.reaction)" }) · 날아간 거리 \(R.dummyDX)")
        #expect(R.phases == ["-", "charge", "fire", "fade", "-"])
        #expect(R.hits.count >= 6)                                   // 첫 타 + 다단 + 마지막 한 방
        #expect(R.hits.last?.reaction == "rBlast")                   // 마지막 한 방: 일직선으로 날린다
        #expect(R.hits.dropFirst().dropLast().allSatisfy { $0.damage < R.hits.last!.damage })   // 다단은 작게
        #expect(R.dummyDX > 60)
        #expect(R.snapBeam && R.words.contains(NvBeamText.fire))
    }

    /// 앞에 늘어선 적을 모두 꿰뚫는다
    @Test func piercesLine() {
        let (sim, w, F) = G.arena(["punk", "punk"], dx: [40, 90])
        let i = NativeVFTests.give(w, "nv_beam", uid: 9831)
        for a in F { w.setAnim(a, "idle"); a.e!.stun = 3 }   // 막기 · 공격 없이 서 있게(꿰뚫기만 본다)
        w.useSkill(i, F[0], true)
        var hit: [ActorID: Int] = [:]
        for _ in 0..<70 { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero { hit[h.target, default: 0] += 1 } } }
        print("[광선 꿰뚫기] \(hit)")
        #expect(F.allSatisfy { (hit[$0.id] ?? 0) >= 3 })
    }

    /// 떠 있는 대상이면 위로 꺾어 쏜다
    @Test func anglesUpAtAirborne() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_beam", combo: nil))); _ = sim.step()
        let D = w.dojoDummy()!, H = w.hero!
        D.x = H.x + H.f * 70; w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 260
        var ang: Double?
        for _ in 0..<40 { _ = sim.step(); if let B = w.nvBeam, B.phase == .fire { ang = B.ang; break } }
        #expect((ang ?? 0) > 0.2)
    }

    /// 광선이 지나가면 무도장 소품을 깬다
    @Test func breaksProps() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_beam", combo: nil))); _ = sim.step()
        let D = w.dojoDummy()!, f = w.hero!.f
        sim.apply(.dojo(.objSet([DojoObjSpec(kind: "shoji", x: D.x - f * 30)])))   // 허수아비 앞(주인공 쪽) 장지문 — 날아온 몸이 아니라 광선이 깬다
        for _ in 0..<60 { _ = sim.step() }
        #expect(sim.snapshot.dojo!.objs.first?.broken == true)
    }

    /// 주인공이 다른 동작으로 끊기면 광선도 바로 사라진다
    @Test func interruptedFades() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_beam", combo: nil)))
        for _ in 0..<20 { _ = sim.step() }
        #expect(w.nvBeam?.phase == .fire)
        w.setAnim(w.hero!, "idle")
        for _ in 0..<15 { _ = sim.step() }
        #expect(w.nvBeam == nil && sim.snapshot.beam == nil)
    }

    @Test func flagOff() {
        #expect(G.base.item("nv_beam") == nil && G.base.poses["bm_fire"] == nil && G.base.seqJW["nv_beam"] == nil)
        #expect(G.on.item("nv_beam") != nil && G.on.poses["bm_fire"] != nil)
    }
}
