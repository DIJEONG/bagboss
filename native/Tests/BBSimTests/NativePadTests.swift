import Testing
import Foundation
@testable import BBSim
import BBContent

/// 직접 조작 패드(World+NativePad): 기술 버튼 · 기본기 · 수동 → 자동 복귀 · 입력 버퍼 · 맨손 숙이기 · 패드 보기
@Suite struct NativePadTests {
    typealias G = NativeGuardTests

    static func setup(_ ids: [String], foes: [String] = ["punk"], dx: [Double] = [26]) -> (Sim, World, [Actor], [Int]) {
        let (sim, w, F) = G.arena(foes, dx: dx)
        w.bag = []
        let uids = ids.enumerated().map { k, id -> Int in let i = NativeVFTests.give(w, id, uid: 9700 + k); return w.bag[i].uid }
        for a in F { a.e!.stun = 2; w.setAnim(a, "idle") }
        return (sim, w, F, uids)
    }

    /// 기술 버튼 → 그 기술이 나간다 · 수동 동안 자동 AI 는 쉰다
    @Test func skillPressFires() {
        let (sim, w, _, u) = Self.setup(["nv_flick", "nv_liver"])
        sim.apply(.pad(.skill(uid: u[1]), at: w.realTime))
        _ = sim.step()
        #expect(w.hero!.anim == "nv_liver" && w.manualT > 2)
        #expect(w.pad.active)
    }

    /// 기본기: 잽 → 크로스 번갈아 · 피해가 들어간다
    @Test func basicJabCross() {
        let (sim, w, F, _) = Self.setup([])
        var anims: [String] = [], hits = 0
        for k in 0..<60 {
            if k % 12 == 0 { sim.apply(.pad(.basic, at: w.realTime)) }
            for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero, h.target == F[0].id { hits += 1 } }
            if anims.last != w.hero!.anim { anims.append(w.hero!.anim) }
        }
        print("[패드 기본기] \(anims) 적중 \(hits)")
        #expect(anims.contains("jab") && anims.contains("cross") && hits >= 3)
    }

    /// 손을 떼고 2.5초가 지나면 다시 자동
    @Test func autoResumes() {
        let (sim, w, _, _) = Self.setup(["nv_flick"])
        sim.apply(.pad(.basic, at: w.realTime))
        for _ in 0..<60 { _ = sim.step() }
        #expect(w.pad.active)
        for _ in 0..<(60 * 2) { _ = sim.step() }
        #expect(!w.pad.active && w.manualT <= 0)
    }

    /// 동작 중에 누른 기술은 버퍼에 담겼다가 움직일 수 있게 되면 나간다
    @Test func bufferedPress() {
        let (sim, w, _, u) = Self.setup(["nv_liver", "nv_flick"])
        sim.apply(.pad(.skill(uid: u[0]), at: w.realTime)); _ = sim.step()
        #expect(w.hero!.anim == "nv_liver")
        var started = false
        // 리버 블로의 타격 전(준비 칸)에 플리커를 누른다 → 끊지 않고 기다렸다가
        sim.apply(.pad(.skill(uid: u[1]), at: w.realTime))
        for _ in 0..<40 { _ = sim.step(); if w.hero!.anim == "nv_flick" { started = true; break } }
        #expect(started)
    }

    /// 쭈그리기 아이템이 없어도 숙인다
    @Test func bareDuck() {
        let (sim, w, _, _) = Self.setup(["nv_flick"])
        #expect(w.duckSlot() < 0)
        sim.apply(.pad(.duck, at: w.realTime)); _ = sim.step()
        #expect(w.hero!.anim == "duck")
    }

    /// 패드 보기: 콤보 경로 기술이 앞(순서 번호) · 나머지 · 최대 6
    @Test func padViewOrder() {
        let (sim, w, _, _) = Self.setup(["nv_kneelift", "nv_slam", "nv_stamp", "nv_flick", "nv_cork", "nv_liver", "nv_roll"])
        _ = sim.step()
        let P = sim.snapshot.pad!
        print("[패드 보기] \(P.skills.map { "\($0.name)\($0.order.map { "#\($0)" } ?? "")" })")
        #expect(P.skills.count <= 6)
        let ordered = P.skills.compactMap(\.order)
        #expect(ordered == ordered.sorted() && (ordered.first ?? 1) == 1)
        #expect(P.skills.prefix(ordered.count).allSatisfy { $0.order != nil })
    }

    /// 뛰기: 질주(출발 칸 → 빠르게) · 떼면 미끄러져 선다
    @Test func runAndSkid() {
        let (sim, w, F, _) = Self.setup([], dx: [200])
        let H = w.hero!; F[0].x = w.AW1() - 4; H.x = w.AW0() + 20
        let x0 = H.x
        sim.apply(.pad(.run(1), at: w.realTime))
        var sprint = false
        for _ in 0..<30 { _ = sim.step(); if H.nvm.mode == 2 { sprint = true } }
        let ran = H.x - x0
        sim.apply(.pad(.move(1), at: w.realTime)); for _ in 0..<30 { _ = sim.step() }
        let walked = H.x - x0 - ran
        print("[패드 뛰기] 0.5초 뛰기 \(Int(ran))px · 0.5초 걷기 \(Int(walked))px")
        #expect(sprint && ran > walked * 1.5)
        sim.apply(.pad(.run(1), at: w.realTime)); for _ in 0..<20 { _ = sim.step() }
        sim.apply(.pad(.move(0), at: w.realTime))
        var skid = false
        for _ in 0..<20 { _ = sim.step(); if H.anim == "nv_skid" { skid = true } }
        #expect(skid)
    }

    /// 끌려온 적에게 기본기 = 어퍼컷(띄움)
    @Test func pulledUppercut() {
        let (sim, w, F, u) = Self.setup(["nv_dial"], dx: [120])
        F[0].e!.stun = 0
        sim.apply(.pad(.skill(uid: u[0]), at: w.realTime))
        for _ in 0..<45 { _ = sim.step(); if F[0].anim == "pulled" && abs(F[0].x - w.hero!.x) < 24 && w.hero!.anim != "nv_dial" { break } }
        for _ in 0..<20 where w.hero!.anim == "nv_dial" { _ = sim.step() }
        #expect(F[0].anim == "pulled" || w.liveSt(F[0]) == "Z")
        sim.apply(.pad(.basic, at: w.realTime))
        var up = false, launched = false
        for _ in 0..<30 { _ = sim.step(); if w.hero!.anim == "upper" { up = true }; if F[0].jug != nil { launched = true } }
        print("[패드 끌림 → 어퍼] 어퍼 \(up) 뜸 \(launched)")
        #expect(up && launched)
    }

    @Test func flagOff() {
        var c = G.config(); c.nativeMoves = false; c.nativeGuard = false
        let sim = Sim(data: G.base, seed: 1, config: c)
        _ = sim.step()
        #expect(sim.snapshot.pad == nil)
    }
}
