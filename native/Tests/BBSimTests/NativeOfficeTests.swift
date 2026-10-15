import Testing
import Foundation
@testable import BBSim
import BBContent
@testable import BBAnim

/// 직장인 세 기술 — docs/07 §7-OF: 큐 타이밍 · 서류가방 내려찍기(바닥 튕김 · 다시 띄움) · 결재 쌍장(벽에 박힘 · 붙어 있는 동안 추가타) ·
/// 멱살 박치기(2타 · 묶음 · 어질어질 · 가드 무시) · 실전 벽 · 깃발 꺼짐.
@Suite struct NativeOfficeTests {
    typealias G = NativeGuardTests

    @Test func sequencesAndCues() {
        let d = G.on, w = Sim(data: d, seed: 1, config: G.config()).w
        #expect(d.jwCue["nv_slam"] == "cs_hit" && d.jwCue["nv_stamp"] == "ss_hit" && d.jwCue["nv_headbutt"] == "hb_hit2")
        #expect(abs(w.atkStartup("nv_slam") - 0.3) < 1e-9 && abs(w.atkStartup("nv_stamp") - 0.2) < 1e-9 && abs(w.atkStartup("nv_headbutt") - 0.5) < 1e-9)
        for id in ["nv_slam", "nv_stamp", "nv_headbutt"] {
            let s = d.seqJW[id]!
            for x in s { #expect(x.n.truncatingRemainder(dividingBy: 50) == 0, Comment(rawValue: id)) }
            #expect(d.item(id) != nil && G.on.game.items.ordered.contains { $0.key == id })
        }
        let hb = d.seqJW["nv_headbutt"]!
        #expect(hb.prefix { $0.pose != "hb_hit1" }.reduce(0) { $0 + $1.n } == 300)   // 1타 0.3초 · 2타 0.5초
        for (k, p) in NativeMoves.ofPoses { #expect(abs(p.h!.x) <= 4 && abs(p.h!.y) <= 4, Comment(rawValue: k)) }
        #expect(NativeContent.heroHeight("nv_headbutt") == .grab && NativeContent.heroHeight("nv_slam") == .mid)
    }

    struct Solo {
        var hits: [HitInfo] = [], words: [String] = [], fx: [String] = [], maxJug = 0.0, bounceJug = 0.0, dummyDX = 0.0
        var wallTicks = 0, wallAt = -1, minStun = 99.0, bounced = false
    }
    static func solo(_ id: String, prep: ((Sim) -> Void)? = nil, ticks: Int = 60 * 3) -> Solo {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero(id, combo: nil)))
        _ = sim.step(); prep?(sim)
        var R = Solo(); let d0 = w.dojoDummy()!.x
        var lastGB = false
        for i in 0..<ticks {
            for e in sim.step() {
                if case .hit(let h) = e, h.attackerIsHero { R.hits.append(h) }
                if case .comicWord(let wd, _, _) = e { R.words.append(wd) }
                if case .fx(let k, _, _, _) = e, k.hasPrefix("nv_") || k == "tsring" || k == "wallImpact" { R.fx.append(k) }
            }
            let D = w.dojoDummy()!
            R.maxJug = max(R.maxJug, D.jug?.h ?? 0)
            if let J = D.jug { if J.gb && !lastGB { R.bounced = true }; lastGB = J.gb; if J.gb { R.bounceJug = max(R.bounceJug, J.h) } }
            R.dummyDX = max(R.dummyDX, (D.x - d0) * w.hero!.f)
            if D.nvHold?.phase == "wall" { R.wallTicks += 1; if R.wallAt < 0 { R.wallAt = i } }
        }
        return R
    }

    /// 서류가방 내려찍기: 서 있는 허수아비도 바닥에 꽂혀 높이 튀어 오른다
    @Test func slamGroundBounce() {
        let R = Self.solo("nv_slam")
        print("[내려찍기] 적중 \(R.hits.map { "\($0.damage)/\($0.reaction)" }) · 튕김 높이 \(R.bounceJug) · 효과 \(R.fx) · 글자 \(R.words)")
        #expect(R.hits.count == 1 && R.hits[0].reaction == "launch")
        #expect(R.bounced && R.bounceJug > 30)                    // 바닥에 꽂혀 다시 뜬다(다시 띄우기)
        #expect(R.fx.contains("nv_slam") && R.fx.contains("tsring"))
        #expect(R.words.contains(NvOfficeText.slam) && R.words.contains(NvOfficeText.bounce))
    }

    /// 떠 있는 허수아비: 빠르게 내리꽂혀 튕긴다(공중 콤보 잇기)
    @Test func slamAirSpike() {
        let R = Self.solo("nv_slam") { sim in
            let w = sim.w, D = w.dojoDummy()!, H = w.hero!
            D.x = H.x + H.f * 24; w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 230
        }
        print("[내려찍기 공중] 적중 \(R.hits.map { "\($0.damage)/\($0.reaction)/\($0.airborne)" }) · 튕김 높이 \(R.bounceJug)")
        #expect(R.hits.contains { $0.airborne })
        #expect(R.bounced && R.bounceJug > 30)
    }

    /// 결재 쌍장: 무도장 오른쪽 벽까지 날아가 박혀 붙어 있다가 떨어진다
    @Test func stampWallSplat() {
        let R = Self.solo("nv_stamp")
        print("[쌍장] 적중 \(R.hits.map { "\($0.damage)/\($0.reaction)" }) · 날아간 거리 \(R.dummyDX) · 벽에 붙은 틱 \(R.wallTicks)(\(R.wallAt)) · 효과 \(R.fx) · 글자 \(R.words)")
        #expect(R.hits.first?.reaction == "rBlast")
        #expect(R.wallAt > 0 && R.wallTicks >= Int(World.nvStampStick) - 1)
        #expect(R.fx.contains("nv_stamp") && R.fx.contains("nv_stampWall") && R.fx.contains("wallImpact"))
        #expect(R.words.contains(NvOfficeText.stamp) && R.words.contains("벽꿍!"))
    }

    /// 벽에 박혀 있는 동안 더 때릴 수 있다(맞아도 붙어 있다)
    @Test func stampWallFollowUp() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_stamp", combo: nil)))
        var stuck: Int?
        for i in 0..<120 { _ = sim.step(); if w.dojoDummy()!.nvHold?.phase == "wall" { stuck = i; break } }
        #expect(stuck != nil)
        let D = w.dojoDummy()!, H = w.hero!
        let hp0 = D.e!.hp
        H.x = D.x - 20; w.setAnim(H, "idle")
        w.damage(H, D, 5, HitOpts())
        _ = sim.step()
        #expect(D.e!.hp < hp0 && D.nvHold?.phase == "wall")
    }

    /// 실전: 객차 끝 벽 앞에서 쌍장 → 벽에 박힌다
    @Test func stampArenaWall() {
        let (sim, w, F) = G.arena(["punk"], dx: [24])
        let H = w.hero!, T = F[0]
        H.x = w.AW1() - 90; H.flip = false; T.x = H.x + 22; T.e!.stun = 3; w.setAnim(T, "idle")
        let i = NativeVFTests.give(w, "nv_stamp", uid: 9841)
        w.useSkill(i, T, true)
        var wall = false
        for _ in 0..<90 { _ = sim.step(); if T.nvHold?.phase == "wall" { wall = true; break } }
        #expect(wall)
    }

    /// 멱살 박치기: 2타(작게 · 크게) · 두 번째에 어질어질(rElbow) · 묶음
    @Test func headbuttTwoHits() {
        let R = Self.solo("nv_headbutt")
        print("[박치기] 적중 \(R.hits.map { "\($0.damage)/\($0.reaction)" }) · 효과 \(R.fx) · 글자 \(R.words)")
        #expect(R.hits.count == 2)
        #expect(R.hits.first?.reaction == "hit" && R.hits.last?.reaction == "rElbow")
        #expect(R.hits[0].damage < R.hits[1].damage)
        #expect(R.fx.filter { $0 == "nv_head" }.count == 2 && R.fx.contains("nv_daze"))
        #expect(R.words.contains(NvOfficeText.head2))
    }

    /// 박치기는 잡기 — 막고 있는 적에게도 들어간다
    @Test func headbuttIgnoresGuard() {
        let (sim, w, F) = G.arena(["nv_spar"], dx: [20])
        let T = F[0]
        let i = NativeVFTests.give(w, "nv_headbutt", uid: 9851)
        w.setAnim(T, "nv_gdH"); T.nvg.stance = 1
        w.useSkill(i, T, true)
        var hits = 0
        for _ in 0..<60 { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero, h.target == T.id { hits += 1 } } }
        #expect(hits >= 1)
    }

    @Test func flagOff() {
        for id in ["nv_slam", "nv_stamp", "nv_headbutt"] {
            #expect(G.base.item(id) == nil && G.base.seqJW[id] == nil)
            #expect(G.on.item(id) != nil)
        }
        #expect(G.base.poses["cs_hit"] == nil && G.on.poses["cs_hit"] != nil)
    }
}
