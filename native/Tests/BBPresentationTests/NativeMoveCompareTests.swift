import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 새 기술 ↔ 기존 기술 나란히(감독 피드백: 실루엣 · 리듬이 한눈에 구분되는가) — BB_DUMP=1 일 때만
/// tools/js/out/moves/compare_<이름>.png: 윗줄 = 기존(깃발 꺼짐 · 웹 동작) · 아랫줄 = 새 동작(깃발 켜짐), 같은 간격(3틱 = 게임 애니 한 칸)으로 무도장 단독 시연.
/// 칸 위 띠: 흰색 = 타격 자세(큐) · 회색 = 동작 중 · 파랑 = 숄더 롤 흘리기 구간(SLIP 판정 자세)
@Suite(.serialized) struct NativeMoveCompareTests {
    typealias Strip = NativeMoveStripTests

    func frames(native: Bool, _ cmd: DojoCommand, anim: String, n: Int) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: native)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = native; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: native), seed: 3, config: c)
        sim.apply(.dojo(.zoom(2)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        // 동작만 본다: 허수아비는 숨기고(카메라 가운데 맞추기용으로 30px 앞에) 주인공에게 동작만 요청 — 타격 섬광 · 숫자 없이 실루엣 비교
        sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true
        _ = cmd
        var shots: [Strip.Shot] = [], started = true
        for _ in 0..<0 { let s = sim.snapshot; var sh = try R.shot(s, R.d.frame(s, dt: 0, now: 0.66), cw: 150, ch: 170, band: nil, ds: 2, dx: 40); for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.9)) }; shots.append(sh) }
        for k in 40..<(40 + 60 * 3) where true {
            if k == 41 { _ = sim.w.requestAction(sim.w.hero!, anim, ActionReq(cue: sim.w.data.jwCue[anim]) { _ in }) }   // 첫 칸은 서기(대기 자세)
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            let H = w.hero!
            if H.anim == anim { started = true }
            guard started, (k - 40) % 3 == 0 else { continue }
            let cue = w.data.jwCue[anim]
            let band: (UInt8, UInt8, UInt8)? = H.anim != anim ? nil : H.pose == cue ? (255, 255, 255) : w.nvSlipPose(H) ? (80, 150, 255) : (120, 120, 140)
            var sh = try R.shot(s, f, cw: 150, ch: 170, band: band, ds: 2, dx: 40)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.9)) }   // 어두운 무도장 바닥에서 검은 양복이 보이게 밝힌다
            shots.append(sh)
            if shots.count >= n { break }
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func compare() throws {
        let n = 14
        let pairs: [(String, (DojoCommand, String), (DojoCommand, String))] = [
            ("jab_flick", (.hero("punch", combo: 0), "jab"), (.hero("nv_flick", combo: nil), "nv_flick")),
            ("cross_roll", (.hero("punch", combo: 1), "cross"), (.hero("nv_roll", combo: nil), "nv_roll")),
            ("upper", (.hero("upper", combo: nil), "upper"), (.hero("upper", combo: nil), "upper")),
        ]
        for (name, a, b) in pairs {
            var top = try frames(native: false, a.0, anim: a.1, n: n), bot = try frames(native: true, b.0, anim: b.1, n: n)
            let blank = Strip.Shot(px: [UInt8](repeating: 24, count: 150 * 170 * 4), band: nil)
            while top.count < n { top.append(blank) }; while bot.count < n { bot.append(blank) }
            try Strip.sheet(top + bot, cw: 150, ch: 170, cols: n, name: "compare_" + name)
        }
    }
    /// 플리커 장착 대기(감독 피드백: 플리커 뒤 손이 덜덜 떨리며 이상한 자세) — 2틱 간격 28칸: 플리커 → 낮은 손 대기 → 허수아비가 다가와 실전처럼 서기/걷기
    @Test(.enabled(if: Strip.dump)) func flickIdle() throws {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(2)))
        sim.w.bag.append(sim.w.newItem("nv_flick"))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true
        var shots: [Strip.Shot] = []
        for k in 40..<400 {
            if k == 41 { _ = sim.w.requestAction(sim.w.hero!, "nv_flick", ActionReq(cue: sim.w.data.jwCue["nv_flick"]) { _ in }) }
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard (k - 40) % 2 == 0, k >= 70 else { continue }
            let H = sim.w.hero!
            print("k\(k) anim=\(H.anim) pose=\(H.pose)")
            var sh = try R.shot(s, f, cw: 150, ch: 170, band: nil, ds: 2, dx: 40)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.9)) }
            shots.append(sh)
            if shots.count >= 28 { break }
        }
        try Strip.sheet(shots, cw: 150, ch: 170, cols: 14, name: "flick_idle")
    }

    /// 실전 질주(지하철 판 · 깃발 켜짐): 주인공이 적 사이를 달려가는 칸만(주황 띠 = 질주 · 노랑 = 출발 · 빨강 = 미끄러져 서기), 2틱 간격 → run_fight.png
    @Test(.enabled(if: Strip.dump)) func runInGame() throws {
        let R = try Strip.Rig(native: true)
        let sim = Sim(data: Strip.base, seed: 31, config: Strip.config(true))
        var shots: [Strip.Shot] = [], tail = 0
        for k in 0..<(60 * 90) {
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard k % 2 == 0 else { continue }
            let H = w.hero!, sprint = H.anim == "walk" && H.runU > w.gameTime
            let band: (UInt8, UInt8, UInt8)? = H.anim == "nv_go" ? (255, 230, 60) : H.anim == "nv_skid" ? (230, 60, 50) : sprint ? (255, 140, 40) : nil
            if band != nil { tail = 2 } else if tail > 0 { tail -= 1 } else { continue }
            var sh = try R.shot(s, f, cw: 160, ch: 130, band: band)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.7)) }
            shots.append(sh)
            if shots.count >= 40 { break }
        }
        try Strip.sheet(shots, cw: 160, ch: 130, cols: 10, name: "run_fight")
    }
}
