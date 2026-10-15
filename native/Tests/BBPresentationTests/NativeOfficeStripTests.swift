import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 직장인 세 기술(BB_DUMP=1 일 때만) → tools/js/out/moves/office_*.png
///   office_slam · office_stamp · office_head = 무도장 단독(무대만 — 넓게) / office_*_body = 주인공 온몸 확대(허수아비 숨김)
///   띠: 흰색 = 큐 칸 · 노랑 = 1타(hb_hit1) · 회색 = 그 밖
@Suite(.serialized) struct NativeOfficeStripTests {
    typealias Strip = NativeMoveStripTests

    static func band(_ w: World, _ anim: String) -> (UInt8, UInt8, UInt8)? {
        let H = w.hero!
        guard H.anim == anim else { return (60, 60, 70) }
        if H.pose == w.data.jwCue[anim] { return (255, 255, 255) }
        if H.pose == "hb_hit1" { return (255, 220, 80) }
        return (120, 120, 140)
    }

    func frames(_ anim: String, times: [Double], cw: Int, ch: Int, ds: Int, dx: Int, dy: Int, zoom: Double, body: Bool = false, bright: Double = 1.0,
                prep: ((Sim) -> Void)? = nil) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(zoom)))
        sim.apply(.dojo(.crit(false)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        if body { sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true }
        var shots: [Strip.Shot] = [], start: Int?
        let want = times.map { Int(($0 * 60).rounded()) }
        for k in 40..<(40 + 60 * 5) {
            if k == 41 {
                if body { _ = sim.w.requestAction(sim.w.hero!, anim, ActionReq(cue: sim.w.data.jwCue[anim], wpn: sim.w.item(anim)?.wpn) { _ in }) }
                else { sim.apply(.dojo(.hero(anim, combo: nil))); _ = sim.step(); prep?(sim) }
            }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if start == nil && w.hero.anim == anim { start = k }
            guard let st = start else { continue }
            for _ in want.filter({ $0 == k - st }) {
                var sh = try R.shot(s, f, cw: cw, ch: ch, band: Self.band(w, anim), ds: ds, dx: dx, dy: dy, hud: false)
                if bright != 1 { for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * bright)) } }
                shots.append(sh)
            }
            if shots.count >= times.count { break }
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func slam() throws {
        let t = [0.05, 0.15, 0.25, 0.3, 0.35, 0.4, 0.45, 0.55, 0.7, 0.85, 1.0, 1.3]
        try Strip.sheet(try frames("nv_slam", times: t, cw: 260, ch: 170, ds: 2, dx: 60, dy: -10, zoom: 1.6), cw: 260, ch: 170, cols: 6, name: "office_slam")
    }
    /// 띄운 허수아비를 내려찍기
    @Test(.enabled(if: Strip.dump)) func slamAir() throws {
        let t = [0.15, 0.25, 0.3, 0.35, 0.4, 0.5, 0.6, 0.8]
        let s = try frames("nv_slam", times: t, cw: 260, ch: 170, ds: 2, dx: 60, dy: -10, zoom: 1.6) { sim in
            let w = sim.w, D = w.dojoDummy()!, H = w.hero!
            D.x = H.x + H.f * 26; w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 230
        }
        try Strip.sheet(s, cw: 260, ch: 170, cols: 4, name: "office_slam_air")
    }
    @Test(.enabled(if: Strip.dump)) func slamBody() throws {
        let t = [0.0, 0.1, 0.2, 0.3, 0.35, 0.45, 0.55, 0.7]
        try Strip.sheet(try frames("nv_slam", times: t, cw: 200, ch: 260, ds: 1, dx: 10, dy: 10, zoom: 1, body: true), cw: 200, ch: 260, cols: 8, name: "office_slam_body")
    }

    @Test(.enabled(if: Strip.dump)) func stamp() throws {
        let t = [0.05, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.9, 1.1, 1.5]
        try Strip.sheet(try frames("nv_stamp", times: t, cw: 300, ch: 150, ds: 3, dx: 40, dy: -4, zoom: 1.0), cw: 300, ch: 150, cols: 4, name: "office_stamp")
    }
    /// 벽에 박힌 쪽 확대(벽 도장 · 미끄러짐 · 떨어짐)
    @Test(.enabled(if: Strip.dump)) func stampWall() throws {
        let t = [0.45, 0.55, 0.65, 0.75, 0.9, 1.1, 1.4, 1.9]
        try Strip.sheet(try frames("nv_stamp", times: t, cw: 220, ch: 140, ds: 2, dx: 50, dy: -6, zoom: 1.0), cw: 220, ch: 140, cols: 4, name: "office_stamp_wall")
    }
    /// 날림 추적 카메라(화면 전체 — 잘라내지 않는다): 무도장 확대 1 · 2 / 코크스크루(무도장 가운데에서)
    @Test(.enabled(if: Strip.dump)) func stampCamera() throws {
        let t = [0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.7]
        let a = try frames("nv_stamp", times: t, cw: 360, ch: 270, ds: 3, dx: 0, dy: 0, zoom: 1.0, prep: { sim in
            let w = sim.w, H = w.hero!, D = w.dojoDummy()!; H.x = 250; D.x = 272 })   // 가운데에서 — 벽까지 멀리
        let b = try frames("nv_stamp", times: t, cw: 360, ch: 270, ds: 3, dx: 0, dy: 0, zoom: 2.0)
        let c = try frames("nv_stamp", times: t, cw: 360, ch: 270, ds: 3, dx: 0, dy: 0, zoom: 2.0, prep: { sim in
            let w = sim.w, H = w.hero!, D = w.dojoDummy()!; H.x = 250; D.x = 272 })   // 확대 2 · 가운데에서 — 줌아웃하며 따라간다
        try Strip.sheet(a + b + c, cw: 360, ch: 270, cols: 8, name: "office_camera")
    }
    @Test(.enabled(if: Strip.dump)) func stampBody() throws {
        let t = [0.0, 0.1, 0.2, 0.25, 0.35, 0.5, 0.6]
        try Strip.sheet(try frames("nv_stamp", times: t, cw: 200, ch: 260, ds: 1, dx: 10, dy: 10, zoom: 1, body: true), cw: 200, ch: 260, cols: 7, name: "office_stamp_body")
    }

    @Test(.enabled(if: Strip.dump)) func head() throws {
        let t = [0.05, 0.15, 0.25, 0.3, 0.35, 0.45, 0.5, 0.55, 0.65, 0.8, 1.0, 1.3]
        try Strip.sheet(try frames("nv_headbutt", times: t, cw: 200, ch: 170, ds: 2, dx: 40, dy: -10, zoom: 2), cw: 200, ch: 170, cols: 6, name: "office_head")
    }
    @Test(.enabled(if: Strip.dump)) func headBody() throws {
        let t = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.75]
        try Strip.sheet(try frames("nv_headbutt", times: t, cw: 200, ch: 260, ds: 1, dx: 10, dy: 10, zoom: 1, body: true), cw: 200, ch: 260, cols: 8, name: "office_head_body")
    }

    // MARK: 내선 연결(World+NativeDial · NativeCordArt)
    @Test(.enabled(if: Strip.dump)) func dial() throws {
        let t = [0.05, 0.12, 0.17, 0.22, 0.27, 0.32, 0.38, 0.45, 0.52, 0.6, 0.7, 0.85]
        try Strip.sheet(try frames("nv_dial", times: t, cw: 300, ch: 150, ds: 2, dx: 70, dy: -6, zoom: 1.0), cw: 300, ch: 150, cols: 4, name: "office_dial")
    }
    /// 날아가는 허수아비를 끌어온다
    @Test(.enabled(if: Strip.dump)) func dialAir() throws {
        let t = [0.12, 0.2, 0.27, 0.32, 0.38, 0.45, 0.55, 0.7]
        let s = try frames("nv_dial", times: t, cw: 300, ch: 150, ds: 2, dx: 70, dy: -10, zoom: 1.0) { sim in
            let w = sim.w, D = w.dojoDummy()!, H = w.hero!
            w.jugHit(D, "launch", H.f, D, HitOpts(), 1); D.jug!.vy = 160; D.jug!.vx = H.f * 50; D.kb = D.jug!.vx
        }
        try Strip.sheet(s, cw: 300, ch: 150, cols: 4, name: "office_dial_air")
    }
    @Test(.enabled(if: Strip.dump)) func dialBody() throws {
        let t = [0.0, 0.1, 0.15, 0.3, 0.4, 0.5, 0.6, 0.7]
        try Strip.sheet(try frames("nv_dial", times: t, cw: 200, ch: 260, ds: 1, dx: 10, dy: 10, zoom: 1, body: true), cw: 200, ch: 260, cols: 8, name: "office_dial_body")
    }

    // MARK: 구두 슛(World+NativePunt)
    @Test(.enabled(if: Strip.dump)) func punt() throws {
        let t = [0.05, 0.15, 0.22, 0.27, 0.32, 0.4, 0.5, 0.6, 0.75, 0.9, 1.1, 1.4]
        try Strip.sheet(try frames("nv_punt", times: t, cw: 300, ch: 150, ds: 2, dx: 40, dy: -6, zoom: 1.0), cw: 300, ch: 150, cols: 4, name: "office_punt")
    }
    @Test(.enabled(if: Strip.dump)) func puntBody() throws {
        let t = [0.05, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.55, 0.65]
        try Strip.sheet(try frames("nv_punt", times: t, cw: 200, ch: 260, ds: 1, dx: 10, dy: 10, zoom: 1, body: true), cw: 200, ch: 260, cols: 10, name: "office_punt_body")
    }
}
