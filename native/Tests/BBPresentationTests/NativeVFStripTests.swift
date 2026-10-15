import Testing
import Foundation
import ImageIO
import CoreGraphics
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 버추어 파이터 참고 두 기술 ↔ 참고 영상(30fps) 키 프레임 나란히(BB_DUMP=1 일 때만) → tools/js/out/moves/kneelift.png · duckup.png
///   1줄 = 참고 영상 프레임(축소 — BB_VF_REF 폴더, 기본 = 작업 폴더 ref3k · ref3b. 없으면 줄을 뺀다)
///   2줄 = 우리 동작만(허수아비 숨김) · 3줄 = 무도장 단독 시연(허수아비가 맞고 뜬다) — 각 칸은 참고 프레임과 같은 시각(동작 시작 기준)
///   띠: 흰색 = 큐(타격) 칸 · 노랑 = 1타(du_jab) · 파랑 = 무릎 멈칫(kl_hold*) · 회색 = 그 밖
@Suite(.serialized) struct NativeVFStripTests {
    typealias Strip = NativeMoveStripTests
    static let cw = 150, ch = 170

    static var refRoot: String {
        ProcessInfo.processInfo.environment["BB_VF_REF"] ?? "/private/tmp/claude-501/-Users-dijeong-bigboss/aae64e53-4650-4452-bc5f-d9f4f8bddeb1/scratchpad"
    }

    static func band(_ w: World, _ anim: String) -> (UInt8, UInt8, UInt8)? {
        let H = w.hero!
        guard H.anim == anim else { return nil }
        if H.pose == w.data.jwCue[anim] { return (255, 255, 255) }
        if H.pose == "du_jab" { return (255, 220, 80) }
        if H.pose.hasPrefix("kl_hold") { return (80, 150, 255) }
        return (120, 120, 140)
    }

    /// 동작 시작부터 times(초)마다 한 칸 — solo = 무도장 단독 시연(허수아비 맞음), 아니면 동작만
    func frames(_ anim: String, solo: Bool, times: [Double], cw: Int = cw, ch: Int = ch, ds: Int = 2, dy: Int = -6) throws -> [Strip.Shot] {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(2)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        if !solo { sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true }
        var shots: [Strip.Shot] = [], start: Int?
        let want = times.map { Int(($0 * 60).rounded()) }
        for k in 40..<(40 + 60 * 4) {
            if k == 41 {
                if solo { sim.apply(.dojo(.hero(anim, combo: nil))) }
                else { _ = sim.w.requestAction(sim.w.hero!, anim, ActionReq(cue: sim.w.data.jwCue[anim]) { _ in }) }
            }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if start == nil && w.hero.anim == anim { start = k }
            guard let st = start, want.contains(k - st) else { continue }
            for _ in want.filter({ $0 == k - st }) {
                var sh = try R.shot(s, f, cw: cw, ch: ch, band: Self.band(w, anim), ds: ds, dx: (solo ? 46 : 40) + (ds == 1 ? 40 : 0), dy: dy)
                for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.9)) }   // 어두운 무도장에서 검은 양복이 보이게
                shots.append(sh)
            }
            if shots.count >= times.count { break }
        }
        return shots
    }

    /// 참고 프레임(PNG — 보기용 축소라 이미지 코덱을 거쳐도 된다)을 칸 크기로 줄인다
    static func ref(_ path: String) -> Strip.Shot? {
        guard let src = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        var px = [UInt8](repeating: 24, count: cw * ch * 4)
        let ctx = CGContext(data: &px, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: cw * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: cw, height: ch))
        let s = min(Double(cw) / Double(img.width), Double(ch) / Double(img.height))
        let w = Double(img.width) * s, h = Double(img.height) * s
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: (Double(cw) - w) / 2, y: (Double(ch) - h) / 2, width: w, height: h))
        return Strip.Shot(px: px, band: (60, 60, 70))
    }

    func sheet(_ anim: String, name: String, refs: [String], times: [Double]) throws {
        var rows: [Strip.Shot] = []
        let blank = Strip.Shot(px: [UInt8](repeating: 24, count: Self.cw * Self.ch * 4), band: nil)
        let R = refs.compactMap { Self.ref(Self.refRoot + "/" + $0) }
        if R.count == refs.count { rows += R } else { print("[vf] 참고 프레임 없음(\(Self.refRoot)) — 참고 줄 생략") }
        var a = try frames(anim, solo: false, times: times), b = try frames(anim, solo: true, times: times)
        while a.count < times.count { a.append(blank) }; while b.count < times.count { b.append(blank) }
        rows += a + b
        try Strip.sheet(rows, cw: Self.cw, ch: Self.ch, cols: times.count, name: name)
        // 확대(UI 해상도 그대로 · 동작만) — 관절 · 실루엣 확인용
        let z = try frames(anim, solo: false, times: times, cw: 200, ch: 300, ds: 1, dy: anim == "nv_kneelift" ? -70 : -6)   // 무릎: 솟은 머리가 잘리지 않게 창을 올린다
        try Strip.sheet(z, cw: 200, ch: 300, cols: 7, name: name + "_zoom")
    }

    /// 무릎 올려치기(2026-10-13 재분석): 참고 영상 24fps rec2/f — f9(0.375초) 타격 ↔ 우리 큐(0.1초). f7~8 끌어올림 · f10~16 무릎 든 채 · f17~24 내림 · 내디딤
    @Test(.enabled(if: Strip.dump)) func kneelift() throws {
        let fs = [7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24]
        try sheet("nv_kneelift", name: "kneelift", refs: fs.map { String(format: "rec2/f/f%04d_%.3f.png", $0, Double($0) / 24) },
                  times: fs.map { max(0, Double($0) / 24 - 0.375 + 0.1) })
    }

    /// 무릎 올려치기 넓게(무도장 단독 · 무대만 — 피해 숫자 없이): 상대가 접혔다 눕혀 날아가는 궤적까지 → kneelift_fly.png
    @Test(.enabled(if: Strip.dump)) func kneeliftFly() throws {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(1.4)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        let times = [0.0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2]
        let want = times.map { Int(($0 * 60).rounded()) }
        var shots: [Strip.Shot] = [], start: Int?
        for k in 40..<(40 + 60 * 4) {
            if k == 41 { sim.apply(.dojo(.hero("nv_kneelift", combo: nil))) }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if start == nil && w.hero.anim == "nv_kneelift" { start = k }
            guard let st = start, want.contains(k - st) else { continue }
            var sh = try R.shot(s, f, cw: 320, ch: 150, band: Self.band(w, "nv_kneelift"), ds: 2, dx: 70, dy: 2, hud: false)
            shots.append(sh)
            if shots.count >= times.count { break }
        }
        try Strip.sheet(shots, cw: 320, ch: 150, cols: 7, name: "kneelift_fly")
    }

    /// 무릎 올려치기 주인공 온몸 확대(무대만) — 영상 f7~24 와 같은 시각 → kneelift_body.png
    @Test(.enabled(if: Strip.dump)) func kneeliftBody() throws {
        let R = try Strip.Rig(native: true)
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 3, config: c)
        sim.apply(.dojo(.zoom(1)))
        for k in 0..<40 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60) }
        sim.w.dojoReset(30); sim.w.dojoDummy()!.hidden = true
        let fs = [7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24]
        let want = fs.map { Int((max(0, Double($0) / 24 - 0.375 + 0.1) * 60).rounded()) }
        var shots: [Strip.Shot] = [], start: Int?
        for k in 40..<(40 + 60 * 3) {
            if k == 41 { _ = sim.w.requestAction(sim.w.hero!, "nv_kneelift", ActionReq(cue: "kl_hit") { _ in }) }
            let ev = sim.step(), s = sim.snapshot, w = sim.w
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            if start == nil && w.hero.anim == "nv_kneelift" { start = k }
            guard let st = start else { continue }
            for _ in want.filter({ $0 == k - st }) {
                var sh = try R.shot(s, f, cw: 200, ch: 260, band: Self.band(w, "nv_kneelift"), ds: 1, dx: 10, dy: 10, hud: false)
                for i in sh.px.indices where i % 4 != 3 { sh.px[i] = UInt8(min(255, Double(sh.px[i]) * 1.6)) }
                shots.append(sh)
            }
            if shots.count >= fs.count { break }
        }
        var rows = fs.compactMap { Self.ref(Self.refRoot + String(format: "/rec2/f/f%04d_%.3f.png", $0, Double($0) / 24)) }.map { r -> Strip.Shot in r }
        if rows.count != fs.count { rows = [] }
        try Strip.sheet(shots, cw: 200, ch: 260, cols: 6, name: "kneelift_body")
    }

    /// 파고들어 올려치기: 참고 u_000(내디딤 시작) 기준 — u_005~006 1타 · u_009~010 어퍼컷 · u_012~017 가라앉음 · u_017~025 회복
    @Test(.enabled(if: Strip.dump)) func duckup() throws {
        let us = [0, 2, 4, 5, 6, 8, 9, 10, 11, 12, 14, 17, 20, 25]
        try sheet("nv_duckup", name: "duckup", refs: us.map { String(format: "ref3b/u_%03d.png", $0) }, times: us.map { Double($0) / 30 })
    }

    /// 기존 니킥(웹 knee) 확대 — 실루엣 비교용
    @Test(.enabled(if: Strip.dump)) func kneeWeb() throws {
        let z = try frames("knee", solo: false, times: (0..<7).map { Double($0) / 20 }, cw: 200, ch: 300, ds: 1)
        try Strip.sheet(z, cw: 200, ch: 300, cols: 7, name: "knee_web_zoom")
    }
}
