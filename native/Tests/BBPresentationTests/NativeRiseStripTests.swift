import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 퇴근 승천권 눈으로 보기(BB_DUMP=1 일 때만) → tools/js/out/moves/
///   rising.png      : 윗줄 = 동작만(허수아비 숨김, 3틱 = 애니 한 칸) · 아랫줄 = 무도장 단독 시연(허수아비가 맞고 뜬다)
///                     띠: 파랑 = 무적(웅크림 · 솟구침) · 노랑 = 상단 빗나감(오름 · 꼭대기) · 흰색 = 타격 칸 · 빨강 = 착지 빈틈 · 회색 = 그 밖
///   rising_zoom.png : 동작만 3배(UI 해상도 그대로) — 관절 튐 · 회전 확인용
///   rising_roof.png : 지하철 판 지붕 뚫기 — 꼭대기 처치 → 천장 구멍 · 빛줄기 · 파편 → 1.9초 뒤 '…쿵'
@Suite(.serialized) struct NativeRiseStripTests {
    typealias Strip = NativeMoveStripTests
    typealias G = NativeGuardStripTests

    static func band(_ w: World) -> (UInt8, UInt8, UInt8)? {
        let H = w.hero!
        guard H.anim == "nv_rise" else { return nil }
        if World.nvRiseInvulnPoses.contains(H.pose) { return (80, 150, 255) }
        if H.pose == "rs_apex" { return (255, 255, 255) }
        if World.nvRiseHighPoses.contains(H.pose) { return (255, 220, 80) }
        if World.nvRiseRecovPoses.contains(H.pose) { return (230, 70, 60) }
        return (120, 120, 140)
    }

    func dojoFrames(solo: Bool, n: Int, cw: Int, ch: Int, ds: Int, step: Int, dy: Int = 0) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(2)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        if !solo { sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true }
        var shots: [Strip.Shot] = [], started = false, tail = 0
        for k in 40..<(40 + 60 * 4) {
            if k == 41 {
                if solo { sim.apply(.dojo(.hero("nv_rise", combo: nil))) }
                else { _ = sim.w.requestAction(sim.w.hero!, "nv_rise", ActionReq(cue: sim.w.data.jwCue["nv_rise"]) { _ in }) }
            }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if w.hero.anim == "nv_rise" { started = true; tail = 3 } else if started { tail -= 1 }
            guard (started && tail > 0) || k == 41, (k - 41) % step == 0 else { if started && tail <= 0 { break }; continue }
            var sh = try R.shot(s, f, cw: cw, ch: ch, band: Self.band(w), ds: ds, dx: solo ? 20 : 0, dy: dy)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.9)) }   // 어두운 무도장에서 검은 양복이 보이게
            shots.append(sh)
            if shots.count >= n { break }
        }
        return shots
    }

    @Test(.enabled(if: Strip.dump)) func rising() throws {
        let n = 22
        var top = try dojoFrames(solo: false, n: n, cw: 150, ch: 230, ds: 2, step: 3, dy: -40), bot = try dojoFrames(solo: true, n: n, cw: 150, ch: 230, ds: 2, step: 3, dy: -60)
        let blank = Strip.Shot(px: [UInt8](repeating: 24, count: 150 * 230 * 4), band: nil)
        while top.count < n { top.append(blank) }; while bot.count < n { bot.append(blank) }
        try Strip.sheet(top + bot, cw: 150, ch: 230, cols: n, name: "rising")
        let z = try dojoFrames(solo: false, n: 24, cw: 220, ch: 560, ds: 1, step: 2, dy: -120)
        try Strip.sheet(z, cw: 220, ch: 560, cols: 12, name: "rising_zoom")
    }

    /// 장면만(HUD 없이) 장면 픽셀 1:1 로 잘라낸다 — 픽셀 아트 점검용
    static func scenePx(_ R: Strip.Rig, _ s: SimSnapshot, _ f: StageFrame, cx: Int, cy: Int, cw: Int, ch: Int) throws -> Strip.Shot {
        var rf = RenderFrame(stage: f, atlas: R.content.sprites)
        rf.applyHUD(R.d.hud.state, now: s.time)
        let cb = R.q.makeCommandBuffer()!; try R.fr.encode(rf, targets: R.tg, into: cb); cb.commit(); cb.waitUntilCompleted()
        let scene = try R.fr.readBack(R.tg.output(for: rf), queue: R.q)
        var px = [UInt8](repeating: 0, count: cw * ch * 4)
        for y in 0..<ch { for x in 0..<cw {
            let sx = max(0, min(479, cx - cw / 2 + x)), sy = max(0, min(269, cy - ch / 2 + y)), si = (sy * 480 + sx) * 4, d = (y * cw + x) * 4
            for c in 0..<3 { px[d + c] = scene[si + c] }; px[d + 3] = 255
        } }
        return Strip.Shot(px: px, band: nil)
    }

    /// 종이 회오리(무도장 · 처치 없는 보통 쓰기) — 실제 화면 값(밝기 보정 없음 · HUD 포함) · 띠 = 자세
    @Test(.enabled(if: Strip.dump)) func risingPaper() throws {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        var shots: [Strip.Shot] = []
        for k in 0..<(40 + 60 * 3) {
            if k == 41 { sim.apply(.dojo(.hero("nv_rise", combo: nil))) }
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            guard (k >= 44 && k < 44 + 34) || (k >= 78 && k < 220 && k % 8 == 0), let H = sim.w.hero else { continue }
            // 밝기 보정 없이(실제 게임과 같은 값) · HUD(피해 숫자 · 섬광 · 글자) 포함 — 숫자 · 섬광이 주인공 · 용을 가리는지 보는 칸
            var sh = try G.shot(R, s, f, cx: H.x + 6, cy: H.y - 52, cw: 110 * 3, ch: 120 * 3, ds: 1, band: nil)
            sh.band = Self.band(sim.w); shots.append(sh)
        }
        try G.sheet(shots, cw: 330, ch: 360, cols: 13, name: "../moves/rising_paper")
    }

    /// 엘리베이터 타워(비상 해치) · 프롤로그 복도(천장 타일) 지붕 뚫기 — 장면 픽셀 4배(뚫은 뒤 0.15 · 0.5 · 1.5 · 3초)
    @Test(.enabled(if: Strip.dump)) func risingRoofVariants() throws {
        var out: [Strip.Shot] = []
        for kind in ["tower", "corridor"] {
            let R = try Strip.Rig(native: true)
            var c = Strip.config(true); if kind == "tower" { c.mode = .tower } else { c.prologue = true }
            let sim = Sim(data: Strip.base, seed: 7, config: c), w = sim.w
            var k = 0, at: Int?, got = 0
            while k < 60 * 70 && got < 4 {
                if let a = at, k - a > 90, w.stats.nvg.roofBlasts == 0 { at = nil }   // 처치가 안 됐으면 다시
                if at == nil, k > 120, w.state == "fight" || w.state == "corridor", let H = w.hero, w.canAct(H), let F = w.foes().first(where: { !w.isDown($0) && $0.jug == nil && $0.e?.boss != true && !$0.held }) {
                    w.maxHP = 9999; w.hp = 9999
                    F.x = H.x + (H.flip ? -18 : 18)
                    if !w.bag.contains(where: { $0.id == "nv_rise" }) { let it = w.newItem("nv_rise"); if let p = w.findSpot(it) { it.x = p.x; it.y = p.y }; w.bag.append(it); w.renderBag() }
                    if let i = w.bag.firstIndex(where: { $0.id == "nv_rise" }) { F.e!.hp = min(F.e!.hp, 10); w.bag[i].t = 99; w.nvRoofAt = -99; w.nvRiseGo(H, i, F); at = k }
                }
                let ev = sim.step(), s = sim.snapshot
                _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                if let a = at, w.stats.nvg.roofBlasts > 0, let h = R.d.hud.state.roofHoles.first, [9, 30, 90, 180].contains(k - a) {
                    let cy = kind == "tower" ? 100 : 40
                    out.append(try Self.scenePx(R, s, f, cx: Int(h.x), cy: cy, cw: 90, ch: 64)); got += 1
                }
                k += 1
            }
            print("[roof-variant] \(kind) blasts \(w.stats.nvg.roofBlasts) shots \(got) at \(String(describing: at)) rises \(w.stats.nvg.rises) nv \(w.nv)")
        }
        if !out.isEmpty { try G.sheet(out, cw: 90, ch: 64, cols: 4, name: "../moves/rising_roof_variants", scale: 4) }
    }

    /// 종이 낙하 길(다중 노출): 장마다 1/60초 점 궤적(색) + 0.1초마다 그 순간 그림 칸(앞 · 기울 · 모서리 · 뒤)을 찍는다 — 진자 호 · 멈칫 · 재주넘기가 보이게
    @Test(.enabled(if: Strip.dump)) func paperFall() throws {
        let W = 240, Hh = 170, gy = 160.0, cx = 120.0
        var P = RisePaper(actor: 1, f: 1, x: cx, y: gy); P.seed = 0x9A9E5
        var px = [UInt8](repeating: 0, count: W * Hh * 4)
        for i in 0..<(W * Hh) { px[i * 4] = 22; px[i * 4 + 1] = 20; px[i * 4 + 2] = 28; px[i * 4 + 3] = 255 }
        func put(_ x: Int, _ y: Int, _ c: (UInt8, UInt8, UInt8)) { guard x >= 0 && y >= 0 && x < W && y < Hh else { return }; let o = (y * W + x) * 4; px[o] = c.0; px[o + 1] = c.1; px[o + 2] = c.2 }
        for x in 0..<W { put(x, Int(gy), (90, 70, 50)) }
        let cols: [(UInt8, UInt8, UInt8)] = [(255, 120, 120), (120, 220, 255), (255, 220, 90), (150, 255, 150), (220, 150, 255), (255, 170, 80), (120, 160, 255)]
        var t = 0.0, k = 0
        while t < 3.2 {
            for sh in NativeRiseArt.paperSheets(P, at: t) where sh.id < 7 {
                let c = cols[sh.id % cols.count]
                let dim: (UInt8, UInt8, UInt8) = (c.0 / 3, c.1 / 3, c.2 / 3)
                put(Int(sh.x), Int(sh.y), dim)
                if k % 6 == 0 {   // 0.1초마다 그림 칸: 앞면 4×3 · 기울 2×3(기울기 방향으로) · 모서리 1px 가로선 · 뒷면 4×3 점무늬
                    let X = Int(sh.x), Y = Int(sh.y)
                    switch sh.frame {
                    case 2: for d in -2...2 { put(X + d, Y, c) }
                    case 1: for r in -1...1 { put(X + sh.lean * r, Y + r, c); put(X + 1 + sh.lean * r, Y + r, c) }
                    default: for r in -1...1 { for d in -2...1 { if sh.frame == 0 || (r + d) & 1 == 0 { put(X + d, Y + r, c) } } }
                    }
                }
            }
            t += 1.0 / 60; k += 1
        }
        let shot = Strip.Shot(px: px, band: nil)
        try G.sheet([shot], cw: W, ch: Hh, cols: 1, name: "../moves/paper_fall", scale: 4)
    }

    /// 굴러 올라가는 피해 숫자(네이티브): 윗줄 = 무도장 콤보 시연(펀치 연타) · 아랫줄 = 퇴근 승천권(5 → 10 → 꼭대기) — 실제 화면 값 · HUD 포함 · 2틱마다
    @Test(.enabled(if: Strip.dump)) func damageCounter() throws {
        var rows: [[Strip.Shot]] = []
        for which in 0..<2 {
            let R = try Strip.Rig(native: true)
            var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
            let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
            var shots: [Strip.Shot] = []
            for k in 0..<(40 + 60 * 4) {
                if k == 41 { sim.apply(.dojo(which == 0 ? .combo(0) : .hero("nv_rise", combo: nil))) }
                let ev = sim.step(), s = sim.snapshot
                _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                guard k >= 44, k % 3 == 0, shots.count < 40, let H = sim.w.hero else { continue }
                shots.append(try G.shot(R, s, f, cx: H.x + 30, cy: H.y - 52, cw: 300, ch: 300, ds: 1, band: Self.band(sim.w)))
            }
            rows.append(shots)
        }
        try G.sheet(rows[0] + rows[1], cw: 300, ch: 300, cols: 20, name: "../moves/dmg_counter")
    }

    @Test(.enabled(if: Strip.dump)) func risingRoof() throws {
        let R = try Strip.Rig(native: true)
        let sim = Sim(data: Strip.base, seed: 12, config: Strip.config(true)), w = sim.w
        var k = 0
        func tick() throws -> (SimSnapshot, StageFrame) {
            let ev = sim.step(), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60); k += 1
            return (s, R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60))
        }
        while !(w.state == "fight" && w.legT > 2) && k < 60 * 60 { _ = try tick() }
        // 무대 정리: 적을 치우고 주인공 앞에 하나(꼭대기 한 방에 쓰러질 체력) · 뒤에 하나(구경꾼)
        w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9; w.maxHP = 9999; w.hp = 9999
        let H = w.hero!; H.x = 200; H.flip = false; w.setAnim(H, "idle")
        w.spawnWave(["punk", "brute"], fromDoors: false)
        let F = w.foes(); F[0].x = 218; F[1].x = 150
        for a in F { a.flip = a.x > H.x; a.e!.stun = 9; w.setAnim(a, "idle") }
        F[0].e!.hp = 12; F[1].e!.hp = 999
        let it = Item(id: "nv_rise", uid: 9801, tier: 1, opt: nil); if let p = w.findSpot(it) { it.x = p.x; it.y = p.y }; w.bag.append(it); w.renderBag()
        for _ in 0..<6 { _ = try tick() }
        H.x = 200; F[0].x = 218; w.setAnim(H, "idle")
        w.nvRiseGo(H, w.bag.count - 1, F[0])
        var shots: [Strip.Shot] = [], zoom: [Strip.Shot] = [], game: [Strip.Shot] = [], paperShots: [Strip.Shot] = [], px1: [Strip.Shot] = []
        let hx = F[0].x
        for j in 0..<(60 * 3) {
            let (s, f) = try tick()
            for a in w.foes() where a !== F[0] { a.e!.stun = 9 }
            // 확대(장면 3배): 구멍 둘레 — 뚫는 순간은 촘촘히, 그 뒤 '…쿵'까지 성기게
            if (j >= 6 && j < 40 && j % 2 == 0) || (j >= 40 && j % 12 == 0) { zoom.append(try G.shot(R, s, f, cx: hx, cy: 150, cw: 220, ch: 170, ds: 1, band: Self.band(w) ?? (w.stats.nvg.roofBlasts > 0 ? (255, 150, 60) : nil))) }
            // 종이 회오리(장면 픽셀 3배 · 밝기 보정 없음): 솟구침 → 지붕 뚫기(몇 장 빨려 올라감) → 흩날려 떨어짐 · 빛줄기로 되돌아오는 장
            if j < 40 || (j < 150 && j % 6 == 0) { var sh = try Self.scenePx(R, s, f, cx: Int(H.x) + 10, cy: 168, cw: 110, ch: 112); sh.band = Self.band(w) ?? (w.stats.nvg.roofBlasts > 0 ? (255, 150, 60) : nil); paperShots.append(sh) }
            // 실제 게임 화면 크기(장면 1배 · 세로 화면의 보이는 폭 그대로)
            if [8, 10, 12, 14, 16, 20, 26, 40, 70, 120, 150, 179].contains(j) { px1.append(try Self.scenePx(R, s, f, cx: Int(hx), cy: 146, cw: 90, ch: 64)) }
            if [14, 20, 30, 60, 120, 170].contains(j) { game.append(try G.shot(R, s, f, cx: hx, cy: 150, cw: 360, ch: 230, ds: 3, band: nil)) }
            let dense = j < 60 ? 3 : 9   // 지붕 뚫기까지 촘촘히 · 그 뒤 '…쿵'까지 성기게
            guard j % dense == 0 else { continue }
            var sh = try R.shot(s, f, cw: 300, ch: 200, band: Self.band(w) ?? (w.stats.nvg.roofBlasts > 0 ? (255, 150, 60) : nil), ds: 2, dx: 0, dy: -24)
            for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.25)) }
            shots.append(sh)
        }
        try G.sheet(game, cw: 360, ch: 230, cols: 3, name: "../moves/rising_roof_game", scale: 2)
        try G.sheet(px1, cw: 90, ch: 64, cols: 6, name: "../moves/rising_roof_px", scale: 4)
        try G.sheet(paperShots, cw: 110, ch: 112, cols: 14, name: "../moves/rising_paper_roof", scale: 3)
        #expect(w.stats.nvg.roofBlasts == 1)
        try Strip.sheet(shots, cw: 300, ch: 200, cols: 8, name: "rising_roof")
        try Strip.sheet(zoom, cw: 220, ch: 170, cols: 6, name: "rising_roof_zoom")
    }
}
