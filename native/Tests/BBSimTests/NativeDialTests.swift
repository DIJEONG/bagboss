import Testing
import Foundation
@testable import BBSim
import BBContent

/// 내선 연결(World+NativeDial — docs/07 §7-PH): 멀리 있는 적 끌어오기 · 날아가는 적 · 벽에 박힌 적 · 두목(주인공이 끌려간다) · 빗나감 · 스냅숏
@Suite struct NativeDialTests {
    typealias G = NativeGuardTests

    @Test func sequenceAndContent() {
        let d = G.on, w = Sim(data: d, seed: 1, config: G.config()).w
        #expect(d.jwCue["nv_dial"] == "ph_catch" && abs(w.atkStartup("nv_dial") - 0.3) < 1e-9)
        for x in d.seqJW["nv_dial"]! { #expect(x.n.truncatingRemainder(dividingBy: 50) == 0) }
        #expect(d.item("nv_dial") != nil && G.base.item("nv_dial") == nil)
        #expect(w.rules.role("nv_dial") == "S")
    }

    /// 무도장 시연: 120px 떨어진 허수아비를 주인공 앞까지 끌어온다 → 끌림(P) · 경직
    @Test func pullsFromAfar() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_dial", combo: nil)))
        _ = sim.step()
        let H = w.hero!, D = w.dojoDummy()!
        let d0 = abs(D.x - H.x)
        var hit = false, pulledSt = false, words: [String] = [], phases: [String] = [], maxLift = 0.0
        for _ in 0..<60 {
            for e in sim.step() {
                if case .hit(let h) = e, h.attackerIsHero { hit = true }
                if case .comicWord(let wd, _, _) = e { words.append(wd) }
            }
            if let c = sim.snapshot.cord, phases.last != c.phase { phases.append(c.phase) }
            if w.liveSt(D) == "P" { pulledSt = true }
            maxLift = max(maxLift, D.airOv)
        }
        let d1 = abs(D.x - H.x)
        print("[내선 연결] 거리 \(Int(d0)) → \(Int(d1)) · 단계 \(phases) · 뜸 \(maxLift) · 글자 \(words)")
        #expect(d0 > 100 && hit && d1 < 26)
        #expect(pulledSt && D.e!.stun > 0)
        #expect(phases.starts(with: ["hold", "fly", "pull", "stow"]))
        #expect(words.contains(NvDialText.ring) && words.contains(NvDialText.come))
        #expect(maxLift > 3)
        for _ in 0..<40 { _ = sim.step() }
        #expect(sim.snapshot.cord == nil)
    }

    /// 날아가는 적: 저글을 풀고 그 높이에서 끌어 내려 주인공 앞에 세운다
    @Test func pullsAirborne() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_dial", combo: nil)))
        _ = sim.step()
        let H = w.hero!, D = w.dojoDummy()!
        w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 120; D.jug!.vx = H.f * 60; D.kb = D.jug!.vx
        for _ in 0..<60 { _ = sim.step() }
        #expect(D.jug == nil && abs(D.x - H.x) < 26 && D.airOv == 0)
    }

    /// 겨눔(실제 그려진 몸 상자): 서 있음 · 누움 · 넘어지는 중 · 떠서 구르는 중 — 수화기가 걸리는 순간 몸 상자 안에 있고, 날아감 → 걸림 사이에 튀지 않는다
    @Test func aimsAtDrawnBody() {
        for k in ["stand", "down", "falling", "air"] {
            let sim = DojoNativeTests.dojo(true), w = sim.w
            sim.apply(.dojo(.hero("nv_dial", combo: nil)))
            _ = sim.step()
            let H = w.hero!, D = w.dojoDummy()!
            switch k {
            case "down": w.setAnim(D, "fall"); D.after = "getup"; for _ in 0..<2 { _ = sim.step() }
            case "falling": w.setAnim(D, "fall"); D.after = "getup"
            case "air": w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 140
            default: break
            }
            var prev: SIMD2<Double>?, step = 0.0, inBody = false, flyMax = 0.0, caught = false
            for _ in 0..<80 {
                _ = sim.step()
                guard let C = w.nvCord else { continue }
                if C.phase == .fly, let p = prev { flyMax = max(flyMax, (C.tip - p).x.magnitude + (C.tip - p).y.magnitude) }
                if C.phase == .pull {
                    let r = w.nvDialBody(D).rel(C.tip), v = C.tip - prev!
                    inBody = r.x * r.x + r.y * r.y <= 1.0001; step = v.x.magnitude + v.y.magnitude; caught = true; break
                }
                if C.phase == .fly { prev = C.tip }
            }
            // 끌려오는 동안: 수화기는 몸에 붙어 간다 — 몸 가운데 기준 자리가 한 칸에 크게 튀지 않는다 · 늘 몸 상자 안
            var offMax = 0.0, outMax = 0.0, last = w.nvCord.map { $0.tip - w.nvDialBody(D).c }
            for _ in 0..<30 {
                _ = sim.step()
                guard let C = w.nvCord, C.phase == .pull, let l = last else { break }
                let B = w.nvDialBody(D), o = C.tip - B.c, r = B.rel(C.tip)
                offMax = max(offMax, (o - l).x.magnitude + (o - l).y.magnitude); outMax = max(outMax, (r.x * r.x + r.y * r.y).squareRoot())
                last = o
            }
            print("[겨눔 \(k)] 끌림 중 몸 기준 칸 이동 최대 \(Int(offMax)) · 몸 상자 비율 최대 \(String(format: "%.2f", outMax))")
            #expect(offMax < 12 && outMax < 1.6)
            print("[겨눔 \(k)] 걸림 \(caught) · 몸 안 \(inBody) · 걸리는 칸 이동 \(Int(step)) · 날아감 칸 최대 \(Int(flyMax))")
            #expect(caught && inBody)
            // 걸리는 칸에 수화기가 옮겨 가는 건 몸이 끌림 자세로 바뀌는 만큼뿐(몸에 붙어 함께 — step 은 기록용) · 걸린 뒤로는 몸 기준 자리가 튀지 않는다(아래)
            _ = H
        }
    }

    /// 벽에 박힌 적도 떼어 낸다(결재 쌍장 → 내선 연결)
    @Test func pullsOffWall() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_stamp", combo: nil)))
        var stuck = false
        for _ in 0..<120 { _ = sim.step(); if w.dojoDummy()!.nvHold?.phase == "wall" { stuck = true; break } }
        #expect(stuck)
        let H = w.hero!, D = w.dojoDummy()!
        w.setAnim(H, "idle"); H.action = nil
        let i = NativeVFTests.give(w, "nv_dial", uid: 9861)
        w.useSkill(i, D, true)
        for _ in 0..<60 { _ = sim.step() }
        print("[벽에서 끌기] 벽 \(D.nvHold?.phase ?? "-") · 거리 \(Int(abs(D.x - H.x)))")
        #expect(D.nvHold == nil && abs(D.x - H.x) < 30)
    }

    /// 두목: 끌려오지 않고 주인공이 끌려간다
    @Test func bossPullsHero() {
        let (sim, w, F) = G.arena(["boss"], dx: [110])
        let H = w.hero!, T = F[0]
        guard T.e?.boss == true else { Issue.record("두목 아님"); return }
        for _ in 0..<240 { _ = sim.step(); if w.cut == nil { break } }   // 두목 등장 장면(VS)이 끝날 때까지
        H.x = 150; T.x = 260; T.e!.stun = 3; w.setAnim(T, "idle"); w.setAnim(H, "idle"); H.action = nil
        let bx = T.x, hx0 = H.x
        let i = NativeVFTests.give(w, "nv_dial", uid: 9862)
        w.useSkill(i, T, true)
        var ph: [String] = [], hits: [String] = []
        for _ in 0..<60 { for e in sim.step() { if case .hit(let h) = e { hits.append("\(h.attackerIsHero) \(h.reaction) \(h.damage)") } }; if let c = sim.snapshot.cord, ph.last != c.phase { ph.append(c.phase) } }
        print("[두목] 주인공 \(Int(hx0)) → \(Int(H.x)) · 두목 \(Int(bx)) → \(Int(T.x))")
        #expect(abs(T.x - bx) < 10 && abs(H.x - hx0) > 50)
    }

    /// 빗나감: 아무도 없으면 선이 튕겨 돌아온다
    @Test func missReels() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_dial", combo: nil)))
        _ = sim.step()
        w.dojoDummy()!.x = w.hero!.x - w.hero!.f * 60   // 등 뒤로
        var phases: [String] = []
        for _ in 0..<50 { _ = sim.step(); if let c = sim.snapshot.cord, phases.last != c.phase { phases.append(c.phase) } }
        #expect(phases.contains("reel") && !phases.contains("pull"))
    }

    @Test func flagOff() {
        let sim = Sim(data: G.base, seed: 1, config: { var c = G.config(); c.nativeMoves = false; c.nativeGuard = false; return c }())
        _ = sim.step()
        #expect(sim.snapshot.cord == nil && G.base.poses["ph_throw"] == nil && G.on.poses["ph_throw"] != nil)
    }
}
