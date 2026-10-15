import Testing
import Foundation
@testable import BBSim
import BBContent

/// 구두 슛(World+NativePunt — docs/07 §7-PK): 쓰러진 적만 · 낮고 길게 · 구른다 · 볼링 · 콤보 경로 · 깃발 꺼짐
@Suite struct NativePuntTests {
    typealias G = NativeGuardTests

    @Test func sequenceAndContent() {
        let d = G.on, w = Sim(data: d, seed: 1, config: G.config()).w
        #expect(d.jwCue["nv_punt"] == "pk_hit" && abs(w.atkStartup("nv_punt") - 0.25) < 1e-9)
        for x in d.seqJW["nv_punt"]! { #expect(x.n.truncatingRemainder(dividingBy: 50) == 0) }
        #expect(d.item("nv_punt")?.cond == "down" && G.base.item("nv_punt") == nil && G.base.poses["pk_hit"] == nil)
        #expect(w.rules.role("nv_punt") == "L" && NativeContent.heroHeight("nv_punt") == .low)
    }

    /// 무도장 시연: 누운 허수아비를 차 → 낮게(높이 ≤ 22) 멀리(≥ 70px) · 한 바퀴 구른다
    @Test func lowLongTumble() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero("nv_punt", combo: nil)))
        _ = sim.step()
        let D = w.dojoDummy()!, H = w.hero!
        #expect(w.isFalling(D))
        let x0 = D.x
        var maxH = 0.0, react = "", words: [String] = [], roll0: Double?, roll1 = 0.0
        for _ in 0..<120 {
            for e in sim.step() {
                if case .hit(let h) = e, h.attackerIsHero { react = h.reaction }
                if case .comicWord(let wd, _, _) = e { words.append(wd) }
            }
            if let J = D.jug { maxH = max(maxH, J.h); if roll0 == nil { roll0 = J.roll }; roll1 = J.roll }
        }
        let dx = (D.x - x0) * H.f
        print("[구두 슛] 반응 \(react) · 거리 \(Int(dx)) · 최고 높이 \(Int(maxH)) · 구름 \(roll1 - (roll0 ?? 0)) · 글자 \(words)")
        #expect(react == "rKick")
        #expect(dx > 70 && maxH > 5 && maxH < 22)
        #expect(abs(roll1 - (roll0 ?? 0)) > 0.5)
        #expect(words.contains(NvPuntText.kick))
        #expect(!words.contains("WHAM!"))   // 기본 타격 글자는 겹치지 않는다
    }

    /// 서 있는 적에겐 쓰지 않는다(조건 down)
    @Test func onlyDowned() {
        let (_, w, F) = G.arena(["punk"], dx: [24])
        #expect(!w.condOK("down", w.hero!, F[0], F))
    }

    /// 실전: 쓰러진 적을 차면 낮게 굴러가며 서 있는 다른 적을 볼링으로 넘어뜨린다
    @Test func bowlsOthers() {
        let (sim, w, F) = G.arena(["punk", "punk"], dx: [20, 80])
        let H = w.hero!, A = F[0], B = F[1]
        w.setAnim(A, "fall"); A.after = "getup"; B.e!.stun = 3
        for _ in 0..<12 { _ = sim.step() }
        let i = NativeVFTests.give(w, "nv_punt", uid: 9871)
        w.useSkill(i, A, true)
        var bowled = false
        for _ in 0..<90 { for e in sim.step() { if case .comicWord(let wd, _, _) = e, wd == "볼링!" { bowled = true } } }
        print("[구두 슛 볼링] \(bowled) · B \(B.anim) · H \(Int(H.x)) A \(Int(A.x)) B \(Int(B.x))")
        #expect(bowled)
    }

    /// 콤보 경로: 다리걸기(T) → 구두 슛(D 입력 · K 결과) → 내선 연결 → 어퍼컷 = 도감 '킥오프'
    @Test func kickoffRoute() {
        let w = Sim(data: G.on, seed: 1, config: G.config()).w
        #expect(w.rules.fits(w.rules.stateIn("nv_punt"), "T") && w.rules.nextState("nv_punt", "T") == "K")
        #expect(w.rules.fits(w.rules.stateIn("nv_dial"), "K"))
        #expect(w.rules.recipe(["sweep", "nv_punt", "nv_dial", "upper"])?.name == "킥오프")
    }
}
