import Foundation

// HUD 오버레이 그리기 목록 만들기 — 웹 drawUI(47) · drawDmg · drawHitFx(45) · drawComic · drawCut/drawCut0 · panel · letter · art(47) ·
// drawWipe(38) · drawCmdLog(33) · bossBar · hudPortrait · drawSpGauge(47) · pxText · outlined 를 줄 단위로 옮겼다.
// 순수 함수: HUDState(수명 · 자리) + HUDFrame(그 프레임의 GS 값) → OverlayList. 상태는 바꾸지 않는다(나이 · 물리는 HUDDirector 가 민다).
// 캔버스 상태가 프레임 안에서 이어지는 것까지(예: 'streak' 이 save 없이 lineCap='round' 를 남김) 그대로 따른다.
// 옮기지 않은 것(장면 미이식 · 표시 기회 없음): drawTowerTop · drawBonusHUD · drawDojoHUD · drawShowLamps · drawStory · 거리 연출(cine).

public enum HUDOverlay {
    static let uiInk = "#0e0d14"

    public static func build(_ s: HUDState, _ F: HUDFrame, art: HUDArt) -> OverlayList {
        var B = Builder(F: F, art: art, P: OverlayPainter(width: Int((F.vw * F.uis).rounded()), height: Int((F.h * F.uis).rounded()), atlas: art.atlas))
        if s.capRound { B.P.lineCap = .round }   // 웹 캔버스에 남아 있는 lineCap(HUDState.capRound)
        B.drawUI(s)
        return B.P.list
    }

    struct Builder {
        let F: HUDFrame
        let art: HUDArt
        var P: OverlayPainter
        var UIS: Double { F.uis }
        var VW: Double { F.vw }
        var H: Double { F.h }
        var W: Double { F.w }
        var skinAcc: String? { HUDArt.skinAcc[F.skin] }
        /// 네이티브 세로 배치: 화면 고정 HUD 배율 · 위 여백(HUDFrame.hudScale · hudTop) — nil 이면 웹 그대로(1 · 0).
        /// 위 여백은 노선도 HUD 일 때만(모드 HUD 는 제 자리 — 위에 SwiftUI 역 이름이 없다)
        var plainHUD: Bool { F.modes?.dojo == nil && F.modes?.bonus == nil && F.modes?.tower == nil && F.modes?.corridor == nil && !F.tower && !F.bonus }
        var hs: Double { F.hudScale ?? 1 }
        var top: Double { plainHUD ? F.hudTop ?? 0 : 0 }
        /// 화면 고정 HUD 의 논리 폭 · 높이(배율 1 이면 VW · H)
        var SW: Double { VW / hs }
        var SH: Double { H / hs }

        static func jsRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }
        static func easeO(_ u: Double) -> Double { 1 - pow(1 - min(1, max(0, u)), 3) }
        static func flo(_ v: Double) -> Int { Int(v.rounded(.down)) }

        // MARK: 글자(웹 pxText · outlined)

        mutating func pxText(_ x0: Double, _ y: Double, _ str: String, _ col: String) {
            P.fillStyle(col)
            var x = x0
            for ch in str {
                guard let g = art.glyph[String(ch)] else { x += 4; continue }
                for (j, r) in g.enumerated() { for (i, c) in r.enumerated() where c == "#" { P.fillRect(x + Double(i), y + Double(j), 1, 1) } }
                x += ch == "." ? 2 : Double((g.map(\.count).max() ?? 0) + 1)
            }
        }
        mutating func outlined(_ x: Double, _ y: Double, _ str: String, _ col: String) {
            for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { pxText(x + dx, y + dy, str, uiInk) }
            pxText(x, y, str, col)
        }

        // MARK: drawUI

        mutating func drawUI(_ s: HUDState) {
            P.setTransform(UIS, 0, 0, UIS, 0, 0); P.imageSmoothingEnabled = false
            guard F.on else { return }
            if F.bagSlow == true {   // 웹: 정리 중 표시 — 캡션에 가리지 않게 아래 가운데
                P.strokeStyle("rgba(110,232,220,.75)"); P.lineWidth = 2; P.strokeRect(1, 1, VW - 2, H - 2)   // 웹은 lineWidth · font 를 되돌리지 않는다
                let t = "정리 중 · 시간 느림"
                P.font = .galmuri9(10); let tw = P.measureText(t)
                P.fillStyle("rgba(8,20,24,.85)"); P.fillRect(VW / 2 - tw / 2 - 6, H - 48, tw + 12, 14)
                P.fillStyle("#8ff0e4"); P.textAlign = .center; P.textBaseline = .middle; P.fillText(t, VW / 2, H - 41)
                P.textAlign = .left; P.textBaseline = .alphabetic
            }
            if let C = F.modes?.cine { drawCine(s, C); return }   // 거리 연출: 레터박스 · 숫자/효과 · 하얀 빛 · 어둠만(ModeHUD)
            if F.lbox > 0.01 {
                let bh = Self.jsRound((F.modes?.corridor != nil ? 20 : 24) * F.lbox)
                P.fillStyle("#000"); P.fillRect(0, 0, VW, bh); P.fillRect(0, H - bh, VW, bh)
            }
            if hs != 1 { P.setTransform(UIS * hs, 0, 0, UIS * hs, 0, 0) }   // 네이티브 세로 배치: 화면 고정 HUD 만 작게
            if let D = F.modes?.dojo { drawDojoHUD(D) } else {   // 무도장: 노선도 · 체력 대신 동작 정보(ModeHUD)
            var x = 10.0; let y = 8.0 + top
            if let B = F.modes?.bonus { drawBonusHUD(B) } else if let T = F.modes?.tower { drawTowerTop(T) } else if let k = F.modes?.corridor { drawCorridorTop(k) }
            else if F.bonus || F.tower {
            } else {
                P.fillStyle(F.stageColor); P.fillRect(10, y + 3, Double(F.stops.count * 26 - 12), 2)
                for st in F.stops {
                    P.fillStyle(st.here ? "#ffb547" : st.passed ? "#4a5578" : (st.next && Self.flo(F.time * 3) % 2 != 0) ? "#ffb547" : "#e8eef8")
                    P.fillRect(x, y, 8, 8); P.fillStyle("#0c1224"); P.fillRect(x + 2, y + 2, 4, 4)
                    pxText(x - 1, y + 11, st.label, st.here || st.next ? "#ffb547" : "#8a93ad")
                    x += 26
                }
            }
            if !F.bonus && !F.tower && F.scoreOutside != true {
                let sc = String(F.score), pad = String(repeating: "0", count: max(0, 6 - sc.count)) + sc
                pxText(F.modes?.corridor != nil ? 140 : x + 4, y + 2, pad, "#f1ece0")
            }
            if !F.tower, let k = F.timeBar {
                let w = Double(F.stops.count * 26 - 12), nf = F.foesLeft
                P.fillStyle(uiInk); P.fillRect(9, y + 19, w + 2, 4)
                P.fillStyle(k < 0.25 && nf > 0 ? (Self.flo(F.time * 6) % 2 != 0 ? "#e8524a" : "#ffb547") : nf > 0 ? "#ffb547" : "#5fd08a")
                P.fillRect(10, y + 20, Self.jsRound(w * k), 2)
            }
            if F.modeBadge != false {
                let auto = !F.manual
                P.fillStyle(auto ? "rgba(124,198,255,.25)" : "rgba(255,181,71,.3)"); P.fillRect(SW - 58, 6 + top, 52, 13)
                pxText(SW - 52, 10 + top, auto ? "AUTO" : "MANUAL", auto ? "#7cc6ff" : "#ffb547")
            }
            hudPortrait(F.portrait, 6 + F.portraitDX, SH - 32, 24, hurt: F.hp / max(1, F.max) < 0.3)
            let blocks = Int((F.max / 10).rounded(.up))
            for k in 0..<max(0, blocks) {
                let kk = Double(k)
                let v = max(0, min(1, (F.hp - kk * 10) / 10)), lag = max(0, min(1, (F.lagH - kk * 10) / 10))
                P.fillStyle("#1d2a55"); P.fillRect(34 + kk * 7, SH - 12, 6, 5)
                if lag > 0 { P.fillStyle("#f3e3c2"); P.fillRect(34 + kk * 7, SH - 12, Self.jsRound(6 * lag), 5) }
                if v > 0 { P.fillStyle("#3d7bff"); P.fillRect(34 + kk * 7, SH - 12, Self.jsRound(6 * v), 5); P.fillStyle("#9cc4ff"); P.fillRect(34 + kk * 7, SH - 12, Self.jsRound(6 * v), 1) }
            }
            if let B = F.boss { bossBar(B) }
            }

            P.setTransform(UIS, 0, 0, UIS, -F.camX * UIS, 0)   // 무대 위 요소는 카메라를 따라
            if let L = F.modes?.lamps { drawShowLamps(L, sparks: F.modes?.lampSparks ?? []) }
            for a in F.foes {
                let bw = a.boss ? 30.0 : 16, ax = Self.jsRound(a.x - bw / 2), ay = a.y - 66
                if a.hp < a.max && !(a.boss && a.bossInfo) {
                    P.fillStyle("#120c16"); P.fillRect(ax - 1, ay - 1, bw + 2, 4)
                    P.fillStyle(a.boss ? "#e0a33a" : "#d8414a"); P.fillRect(ax, ay, Self.jsRound(bw * max(0, a.hp) / a.max), 2)
                }
                if let g = a.gd, g.count >= 5 { guardMeter(a.x, ay - 6, stance: Int(g[0]), m: g[1], since: g[2], crash: g[3] > 0) }
                if a.hasAction, let w = a.w, let hx = F.heroX, abs(a.x - hx) <= 56, let tt = a.tt, tt <= 0.6 {
                    let cx = Self.jsRound(a.x), cy = ay - 7, jw = tt <= F.justW, r = Self.jsRound(4 + 15 * min(1, tt / 0.6))
                    P.save(); P.globalAlpha = jw ? 1 : 0.85
                    P.strokeStyle(jw ? "#ffffff" : w == "H" ? "#ff5a44" : "#7cd4ff"); P.lineWidth = jw ? 2 : 1
                    P.beginPath(); P.arc(cx + 0.5, cy + 0.5, r, 0, 7); P.stroke()
                    if jw { P.globalAlpha = 0.35; P.fillStyle(w == "H" ? "#ff5a44" : "#ffffff"); P.beginPath(); P.arc(cx + 0.5, cy + 0.5, r + 3, 0, 7); P.fill() }
                    P.restore()
                }
                if a.hasAction {
                    let w = a.w ?? "L", x = Self.jsRound(a.x)
                    if w == "H" {
                        if Self.flo(F.time * 14) % 2 == 0 {
                            P.fillStyle(uiInk); P.fillRect(x - 5, ay - 13, 10, 10); P.fillStyle("#ff4a3a")
                            for dx in [-3.0, 1] { P.fillRect(x + dx, ay - 12, 2, 5); P.fillRect(x + dx, ay - 6, 2, 2) }
                        }
                    } else if w == "M" {
                        if Self.flo(F.time * 10) % 2 == 0 { P.fillStyle(uiInk); P.fillRect(x - 2, ay - 12, 5, 10); P.fillStyle("#ffd34a"); P.fillRect(x - 1, ay - 11, 3, 5); P.fillRect(x - 1, ay - 5, 3, 2) }
                    } else if Self.flo(F.time * 10) % 2 == 0 { P.fillStyle("#ffb547"); P.fillRect(x - 1, ay - 9, 2, 5); P.fillRect(x - 1, ay - 3, 2, 1) }
                }
            }
            if let g = F.heroGuard, g.count >= 5 { guardMeter(g[0], g[1] - 70, stance: Int(g[2]), m: g[3], since: g[4], crash: false, hero: true) }
            if let f = F.flash { pxText(W / 2 - 14, 40, f, "#ffb547") }
            if let d = F.duck, d.count >= 2 {
                let x = Self.jsRound(d[0]), y = d[1] - 92
                P.fillStyle("#ffb547"); for k in 0..<4 { let kk = Double(k); P.fillRect(x - 3 + kk, y + kk, 7 - 2 * kk, 1) }
                pxText(x - 8, y - 7, "DUCK", "#ffb547")
            }
            drawDmg(s)
            if F.fade > 0 { P.fillStyle(RGBA(0, 0, 0, F.fade)); P.fillRect(0, 0, W, H) }
        }

        /// 네이티브 공방(docs/08): 가드 게이지 — 머리 위 작은 방패 + 막대. 막을수록 금이 가고(⅔ · ⅓) 빨갛게 깜빡인다.
        /// 가드 중이거나 막은 지 1.5초 안 · 게이지가 덜 찬 동안만 보인다. 서서 막기 = 파랑 · 앉아 막기 = 방패를 낮게(막대 아래 점)
        mutating func guardMeter(_ x0: Double, _ y: Double, stance: Int, m: Double, since: Double, crash: Bool, hero: Bool = false) {
            if crash {   // 크래시 무방비: 깨진 방패 조각
                if Self.flo(F.time * 8) % 2 == 0 {
                    let x = Self.jsRound(x0)
                    P.fillStyle(uiInk); P.fillRect(x - 6, y - 1, 12, 5)
                    P.fillStyle("#ff8a6a"); P.fillRect(x - 5, y, 4, 3); P.fillRect(x + 1, y + 1, 4, 2); P.fillRect(x - 1, y - 1, 1, 2)
                }
                return
            }
            guard stance > 0 || since < 1.5 || m < 0.995 else { return }
            let w = 14.0, x = Self.jsRound(x0 - (w + 5) / 2), low = m < 0.34
            let blink = low && Self.flo(F.time * 9) % 2 == 0
            let fresh = since < 0.12
            // 방패 아이콘(4×5): 위는 평평 · 아래는 뾰족
            P.fillStyle(uiInk); P.fillRect(x - 1, y - 2, 6, 7)
            P.fillStyle(fresh ? "#ffffff" : stance == 2 ? "#ffd36a" : hero ? "#7cc6ff" : "#a8dcff")
            P.fillRect(x, y - 1, 4, 3); P.fillRect(x + 1, y + 2, 2, 2)
            P.fillStyle(uiInk); P.fillRect(x + 1, y, 2, 1)
            // 막대
            let bx = x + 5
            P.fillStyle(uiInk); P.fillRect(bx - 1, y - 1, w + 2, 4)
            P.fillStyle("#1d2a40"); P.fillRect(bx, y, w, 2)
            P.fillStyle(blink ? "#ff6a4a" : low ? "#ff9a7a" : fresh ? "#ffffff" : "#8fd3ff")
            P.fillRect(bx, y, Self.jsRound(w * max(0, min(1, m))), 2)
            // 금: ⅔ 아래 하나 · ⅓ 아래 둘(막대 위에 검은 사선)
            P.fillStyle(uiInk)
            if m < 0.67 { P.fillRect(bx + 9, y - 1, 1, 2); P.fillRect(bx + 10, y + 1, 1, 2) }
            if m < 0.34 { P.fillRect(bx + 4, y - 1, 1, 2); P.fillRect(bx + 3, y + 1, 1, 2) }
            if stance == 2 { P.fillStyle("#ffd36a"); P.fillRect(bx + Self.jsRound(w / 2) - 1, y + 3, 2, 1) }
        }

        // MARK: 초상 · 두목 막대 · 필살 게이지 · 기술 줄

        mutating func hudPortrait(_ artKey: String, _ x: Double, _ y: Double, _ sz: Double, hurt: Bool) {
            let src = art.cutArt(artKey, skin: F.skin, shades: F.shades)
            let cr = 36.0, sx = 14.0, sy = 6.0
            P.fillStyle(uiInk); P.fillRect(x - 2, y - 2, sz + 4, sz + 4)
            P.fillStyle(hurt && Self.flo(F.now * 1000 / 200) % 2 != 0 ? "#7a1a20" : "#2a3a6a"); P.fillRect(x, y, sz, sz)
            var yy = 0.0
            while yy < sz {
                var xx = Double(Self.flo(yy / 2) % 2)
                while xx < sz { P.fillStyle("rgba(255,255,255,.07)"); P.fillRect(x + xx, y + yy, 0.5, 0.5); xx += 2 }
                yy += 2
            }
            P.imageSmoothingEnabled = false
            if let src { P.drawImage(src, sx: sx, sy: sy, sw: cr, sh: cr, x, y, sz, sz) }
            P.fillStyle("#f1ece0"); P.fillRect(x - 1, y - 1, sz + 2, 0.5)
        }

        mutating func bossBar(_ B: HUDFrame.Boss) {
            let w = min(170, SW - 150), I = art.bossInfo[B.t] ?? art.bossInfo["boss"]!, x = Self.jsRound(SW - w - 14), y = SH - 15, k = max(0, B.hp) / B.max
            hudPortrait("face:" + B.t, x - 24, y - 6, 18, hurt: B.raged)
            P.font = .galmuri9(10); P.textBaseline = .alphabetic
            P.fillStyle(uiInk); P.fillText(I.n, x + 1, y - 1); P.fillStyle("#f1ece0"); P.fillText(I.n, x, y - 2)
            P.fillStyle(I.col); P.fillText(I.nick, x + P.measureText(I.n) + 6, y - 2)
            P.fillStyle(uiInk); P.fillRect(x - 1, y + 1, w + 2, 7); P.fillStyle("#2a1018"); P.fillRect(x, y + 2, w, 5)
            P.fillStyle("#f3e3c2"); P.fillRect(x, y + 2, Self.jsRound(w * B.lag), 5)
            P.fillStyle(B.raged ? (Self.flo(F.now * 1000 / 140) % 2 != 0 ? "#ff4a3a" : "#c8241c") : "#e0a33a"); P.fillRect(x, y + 2, Self.jsRound(w * k), 5)
            P.fillStyle("rgba(255,255,255,.35)"); P.fillRect(x, y + 2, Self.jsRound(w * k), 1)
            P.fillStyle(uiInk); P.fillRect(x + Self.jsRound(w / 2), y + 2, 1, 5)
        }

        mutating func drawSpGauge() {
            let blocks = (F.max / 10).rounded(.up), w = blocks * 7 - 1, y = SH - 19, x0 = 34.0, k = F.sp / 100, ready = k >= 1
            P.fillStyle(uiInk); P.fillRect(x0 - 1, y - 1, w + 2, 5); P.fillStyle("#3a2a10"); P.fillRect(x0, y, w, 3)
            P.fillStyle(ready ? (Self.flo(F.now * 1000 / 120) % 2 != 0 ? "#fff1a0" : "#ffb02a") : "#ffb547"); P.fillRect(x0, y, Self.jsRound(w * k), 3)
            pxText(x0 + w + 4, y - 1, ready ? "READY" : "SP", ready ? "#fff1a0" : "#c58a34")
        }

        mutating func drawCmdLog(_ L: [CmdView], cut: Bool) {
            guard !L.isEmpty, !cut else { return }
            let x0 = 8.0, y0 = (F.bonus ? 50.0 : 36) + top, rh = 15.0
            P.save(); P.font = .galmuri9(10); P.textBaseline = .middle
            for (k, e) in L.enumerated() {
                let age = e.age
                if age > 4 + 0.5 { continue }
                let a = age > 4 ? 1 - (age - 4) / 0.5 : 1, slide = max(0, 1 - age / 0.12) * 24, y = y0 + Double(k) * rh, x = x0 - slide
                let w = P.measureText(e.name).rounded(.up) + 10
                P.globalAlpha = a * (k == 0 ? 1 : 0.88 - Double(k) * 0.08)
                P.fillStyle(e.sp ? "rgba(60,40,6,.85)" : "rgba(10,8,18,.72)"); P.fillRect(x, y, w, rh - 2)
                P.fillStyle(e.sp ? "#ffd34a" : (e.fam.flatMap { art.famColor[$0] } ?? "#9a94b4")); P.fillRect(x, y, 2, rh - 2)
                P.fillStyle(e.sp ? "#ffe27a" : e.crit ? "#ff7a5c" : e.link ? "#7dffa0" : "#f1ece0"); P.fillText(e.name, x + 6, y + 6.5)
                if age < 0.15 { P.globalAlpha = (1 - age / 0.15) * 0.6; P.fillStyle("#ffffff"); P.fillRect(x, y, w, rh - 2) }
            }
            P.restore()
        }

        // MARK: drawDmg

        mutating func drawDmg(_ s: HUDState) {
            P.setTransform(UIS * hs, 0, 0, UIS * hs, 0, 0)
            if F.on && F.hero && F.modes?.cine == nil && F.modes?.dojo == nil { drawSpGauge() }
            if F.on && F.hero { drawCmdLog(s.cmdLog, cut: s.cut != nil) }
            let vz = F.on ? F.viewZ : 1, zx = (F.viewC.first ?? 0.5) * W, zy = (F.viewC.count > 1 ? F.viewC[1] : 0.5) * H
            let shv = F.on ? F.shv : 0
            P.setTransform(UIS * vz, 0, 0, UIS * vz, UIS * (zx - F.camX - zx * vz + shv * vz), UIS * (zy - zy * vz))   // 화면 줌과 같은 변환
            for c in s.critFx {
                let k = 1 - c.t / 0.16; if k <= 0 { continue }
                let L = (c.big ? 34 : 24) * k + 6, th = c.big ? 3.0 : 2
                for (ang, col) in [(-0.62, "#fff6d8"), (0.62, "#ffcf4a")] {
                    let dx = cos(ang) * L, dy = sin(ang) * L; P.fillStyle(col)
                    var q = -1.0
                    while q <= 1 { P.fillRect(Self.jsRound(c.x + dx * q), Self.jsRound(c.y + dy * q), th, th); q += 0.04 }
                }
                if c.big && !F.noFlash { P.fillStyle(RGBA(1, 246 / 255, 216 / 255, k * 0.35)); P.fillRect(0, 0, W, H) }
            }
            drawHitFx(s.hitFx)
            drawComic(s)
            for d in F.doze where d.count >= 3 {
                let ph = d[2]
                P.globalAlpha = 1 - ph; pxText(Self.jsRound(d[0] + 4 + ph * 6), Self.jsRound(d[1] - 50 - ph * 12), "Z", "#cfe8ff"); P.globalAlpha = 1
            }
            func ease(_ u: Double) -> Double { pow(1 - min(1, max(0, u)), 3) }
            for p in s.pops {
                let S = art.dstyle[p.style] ?? art.dstyle["hit"]!, str = p.text, sc = Double(S.s), dk = F.dmgScale ?? 1   // dk: 네이티브 피해 숫자 크기(글자 · 간격 · 층 높이 모두)
                let pop = (p.counter ? p.pop : 1 + (p.style == "crit" ? 0.7 : 1) * ease(p.age / 0.14)) * dk
                let rise = p.counter ? p.rise : (-10 * (1 - exp(-p.age * 12)) - (p.age > 0.7 ? (p.age - 0.7) * 26 : 0)) * p.riseK, alpha = p.age > p.life - 0.3 ? max(0, (p.life - p.age) / 0.3) : 1
                let adv = 5 * sc - 1, gh = 7 * sc + 2, w = Double(str.count) * adv * pop
                let x0 = max(F.camX + 3, min(F.camX + VW - 3 - w, p.x + p.vx * min(p.age, 0.3) - w / 2)) + p.jolt
                let base = p.y - Double(p.stack) * (7 * sc + 3) * dk + rise + gh * dk, y0 = base - gh * pop
                P.globalAlpha = alpha
                var x = x0
                for ch in str {
                    if let gl = art.dGlyph(ch, p.style) { P.drawImage(gl, x, y0, Double(gl.w) * pop, Double(gl.h) * pop) }
                    x += adv * pop
                }
                if let tg = p.tag, p.tagT > 0 { let lw = Double(tg.count) * 4; P.globalAlpha = alpha * min(1, p.tagT / 0.15); outlined(Self.jsRound(x0 + w / 2 - lw / 2), y0 + gh * pop + 2, tg, "#ffe27a"); P.globalAlpha = alpha }   // 네이티브: 칸 밑 'N HIT'
                if let l = p.label, p.age > 0.04 { let lw = Double(l.count) * 4; outlined(Self.jsRound(x0 + w / 2 - lw / 2), y0 - 8, l, p.labelCol ?? "#ffcf4a") }
                if p.style == "crit" && p.age < 0.12 {
                    P.fillStyle("rgba(255,240,200,.9)")
                    for k in 0..<8 { let a = Double(k) * .pi / 4, r = 10 + p.age * 120; P.fillRect(Self.jsRound(x0 + w / 2 + cos(a) * r), Self.jsRound(y0 + 10 + sin(a) * r * 0.6), 2, 2) }
                }
                P.globalAlpha = 1
            }
            P.setTransform(UIS * hs, 0, 0, UIS * hs, 0, 0)
            if let C = F.combo, C.n >= 2, C.since < C.win {
                let n = String(C.n), big = C.n >= 5, st = big ? "crit" : "hit", pop = 1 + (big ? 0.5 : 1) * ease(C.since / 0.16)
                let xr = SW - 12, BASE = 54.0 + top, HIT_X = xr - 18, HIT_Y = BASE - 6, SUM_Y = BASE + 4, BAR_Y = BASE + 12, BAR_W = 50.0
                if let g0 = art.dGlyph("0", st) {
                    let gw = Double(g0.w - 1) * pop, gh = Double(g0.h) * pop, w = Double(n.count) * gw
                    var x = HIT_X - 3 - w; let y = BASE - gh + 1
                    for ch in n { if let gl = art.dGlyph(ch, st) { P.drawImage(gl, x, y, Double(gl.w) * pop, gh) }; x += gw }
                }
                outlined(HIT_X, HIT_Y, "HIT", big ? "#ff7a4a" : "#ffd77a")
                if C.n >= 3 && C.dmg != 0 { let t = String(C.dmg); outlined(xr - Double(t.count) * 4 + 1, SUM_Y, t, "#f1ece0") }
                let k = max(0, 1 - C.since / C.win)
                P.fillStyle(uiInk); P.fillRect(xr - BAR_W, BAR_Y, BAR_W, 3); P.fillStyle(big ? "#ff7a4a" : "#ffd77a"); P.fillRect(xr - BAR_W + 1, BAR_Y + 1, Self.jsRound((BAR_W - 2) * k), 1)
            }
            if hs != 1 { P.setTransform(UIS, 0, 0, UIS, 0, 0) }   // 문 전환 · 컷인은 무대 전체 그대로
            if let w = s.wipe { drawWipe(w) }
            if let c = s.cut { if c.k == "story" { drawStoryCut(c.t) } else { drawCut(c) } }
            if let t = F.modes?.story { drawStoryCut(t) }
        }

        // MARK: HITFX

        mutating func drawHitFx(_ list: [HitFx]) {
            for e in F.stagger where e.count >= 3 {   // 휘청: 머리 위로 도는 별 셋
                let cx = e[0], cy = e[1], T = e[2]
                P.save()
                for k in 0..<3 {
                    let th = T + Double(k) * 2.094, x = Self.jsRound(cx + cos(th) * 8), y = Self.jsRound(cy + sin(th) * 2.5), back = sin(th) < 0
                    P.globalAlpha = back ? 0.45 : 1; P.fillStyle(back ? "#b89a3a" : "#ffe27a"); P.fillRect(x - 1, y, 3, 1); P.fillRect(x, y - 1, 1, 3)
                }
                P.restore()
            }
            if let B = F.bossBreak {
                let w = 44.0, x = B.x - w / 2, y = B.y - 96
                P.save(); P.fillStyle(uiInk); P.fillRect(x - 1, y - 1, w + 2, 6); P.fillStyle("#ffd36a"); P.fillRect(x, y, Self.jsRound(w * B.k), 4)
                P.font = .galmuri11(9, bold: true); P.textAlign = .center
                P.fillStyle(uiInk); P.fillText("무너짐", B.x + 1, y - 3); P.fillStyle("#ffd36a"); P.fillText("무너짐", B.x, y - 4); P.restore()
            }
            if let T = F.tapW {
                let u = min(1, T.t / 1.5), x = T.x, y = T.y - 34, Rr = 30 - 20 * u
                P.save(); P.strokeStyle("#ffd36a"); P.lineWidth = 2; P.beginPath(); P.arc(x, y, Rr, 0, 7); P.stroke()
                P.strokeStyle("rgba(255,255,255,.65)"); P.lineWidth = 1; P.beginPath(); P.arc(x, y, 9, 0, 7); P.stroke()
                P.font = .galmuri11(11, bold: true); P.textAlign = .center; P.fillStyle(uiInk); P.fillText("탭!", x + 1, y - Rr - 5); P.fillStyle("#ffd36a"); P.fillText("탭!", x, y - Rr - 6); P.restore()
            }
            for p in list { drawOne(p) }
            P.globalAlpha = 1
        }

        mutating func drawOne(_ p: HitFx) {
            let u = p.t / p.life
            if u >= 1 { return }
            let x = p.x, y = p.y, f = p.f ?? 1
            switch p.k {
            case "sig_ring":
                let R = (p.r ?? 0) * (0.2 + 0.8 * u)
                P.save(); P.globalAlpha = 1 - u; P.lineWidth = 3; P.strokeStyle("#fff6d0"); P.beginPath(); P.ellipse(x, y + 16, R, R * 0.32, 0, 0, 7); P.stroke()
                P.lineWidth = 2; P.strokeStyle(skinAcc ?? "#ffb347"); P.beginPath(); P.ellipse(x, y + 16, R * 0.68, R * 0.22, 0, 0, 7); P.stroke()
                for k in 0..<12 { let a = Double(k) / 12 * 6.283; P.beginPath(); P.moveTo(x + cos(a) * R * 0.45, y - 4 + sin(a) * R * 0.28); P.lineTo(x + cos(a) * R * 0.85, y - 4 + sin(a) * R * 0.5); P.stroke() }
                P.restore()
            case "sig_quake":
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#e0c89a"); P.lineWidth = 3
                for sd in [-1.0, 1] { for k in 0..<3 { let dx = sd * (10 + (p.r ?? 0) * u * (1 - Double(k) * 0.25)); P.beginPath(); P.arc(x + dx, y + 30, 8 + Double(k) * 4, .pi * 1.05, .pi * 1.95); P.stroke() } }
                P.restore()
            case "sig_burst":
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#ffd36a"); P.lineWidth = 2.5
                for k in 0..<14 { let a = Double(k) / 14 * 6.283 + 0.2, r0 = 6 + 20 * u, r1 = r0 + 18 * (1 - u) + 8; P.beginPath(); P.moveTo(x + cos(a) * r0, y + sin(a) * r0); P.lineTo(x + cos(a) * r1, y + sin(a) * r1); P.stroke() }
                P.restore()
            case "sig_pillar":
                let w = 22 * (1 - u) + 2
                P.save(); P.globalAlpha = 1 - u * u; P.fillStyle("#ffd36a"); P.fillRect(x - w / 2 - 2, y - 130, w + 4, 160); P.fillStyle("#fffbe8"); P.fillRect(x - w / 2, y - 130, w, 160); P.restore()
            case "sig_flash":
                P.save(); P.globalAlpha = 0.55 * (1 - u); P.fillStyle("#ffffff"); P.fillRect(x - 600, y - 400, 1200, 800); P.restore()
            case "sig_trail":
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#f1e6cf"); P.lineWidth = 2
                for k in 0..<7 { let yy = y - 24 + Double(k) * 8, L = (80 + Double(k % 3) * 20) * (1 - u * 0.5); P.beginPath(); P.moveTo(x - f * 12, yy); P.lineTo(x - f * (12 + L), yy); P.stroke() }
                P.restore()
            case "sig_stamp":
                let s0 = 1.9 - 0.9 * min(1, u * 5), al = u < 0.65 ? 1 : 1 - (u - 0.65) / 0.35
                P.save(); P.globalAlpha = al; P.translate(x, y - 26); P.rotate(-0.2); P.scale(s0, s0)
                P.strokeStyle("#d6453a"); P.lineWidth = 3; P.strokeRect(-24, -15, 48, 30); P.lineWidth = 1; P.strokeRect(-20, -11, 40, 22)
                P.fillStyle("#d6453a"); P.font = .galmuri11(13, bold: true); P.textAlign = .center; P.textBaseline = .middle; P.fillText("결재", 0, 1); P.restore()
            case "tsring", "axring":
                let ts = p.k == "tsring"
                let e = 1 - pow(1 - u, ts ? 2.2 : 2.4)
                P.save(); P.globalAlpha = 1 - u
                if ts {
                    P.strokeStyle("#ffe2a8"); P.lineWidth = 2.5; P.beginPath(); P.ellipse(x, y, 10 + 58 * e, 3 + 8 * e, 0, 0, 7); P.stroke()
                    P.strokeStyle("#c8905a"); P.lineWidth = 1.5; P.beginPath(); P.ellipse(x, y, 6 + 34 * e, 2 + 5 * e, 0, 0, 7); P.stroke()
                    P.globalAlpha = min(1, (1 - u) * 1.8)
                } else {
                    P.strokeStyle("#e8f6ff"); P.lineWidth = 2; P.beginPath(); P.ellipse(x, y, 8 + 40 * e, 2.5 + 7 * e, 0, 0, 7); P.stroke()
                    P.strokeStyle("#7fc4ff"); P.lineWidth = 1; P.beginPath(); P.ellipse(x, y, 5 + 24 * e, 1.5 + 4 * e, 0, 0, 7); P.stroke()
                    P.globalAlpha = min(1, (1 - u) * 1.6)
                }
                P.strokeStyle("#14121c"); P.lineWidth = 1.5
                for c in p.cr ?? [] {
                    var X = x, Y = y; P.beginPath(); P.moveTo(X, Y)
                    for k in 1...max(1, c.n) {
                        X += c.sd * (ts ? 7 + Double(k) * 4 : 6 + Double(k) * 3) * min(1, u * (ts ? 5 : 4))
                        Y += (k % 2 != 0 ? -1 : 1) * (ts ? 1.6 : 1.5) + c.a * 3; P.lineTo(X, Y)
                    }
                    P.stroke()
                }
                P.restore()
            case "chstar":
                let s = u < 0.25 ? u / 0.25 : 1 - (u - 0.25) / 0.75, L = 3 + 15 * s, w = max(1, Self.jsRound(2.4 * s))
                P.save(); P.globalAlpha = min(1, 1.8 * (1 - u)); P.fillStyle("#fffbe6")
                P.fillRect(Self.jsRound(x - L), Self.jsRound(y - w / 2), Self.jsRound(L * 2), w); P.fillRect(Self.jsRound(x - w / 2), Self.jsRound(y - L * 0.7), w, Self.jsRound(L * 1.4))
                P.fillStyle("#ffe27a"); P.fillRect(Self.jsRound(x - 2), Self.jsRound(y - 2), 4, 4); P.restore()
            case "swpuff":
                P.save(); P.fillStyle("#f1ede4")
                for b in p.b ?? [] {
                    P.globalAlpha = 0.22 * (1 - u) * (1 - u) * (u < 0.15 ? u / 0.15 : 1)
                    P.beginPath(); P.arc(x + b.dx + b.vx * u + (p.f ?? 1) * u * 8, y + b.dy - b.vy * u, b.r * (0.7 + u * 1.1), 0, 7); P.fill()
                }
                P.restore()
            case "xcspark":
                let al = 1 - u
                P.save(); P.globalAlpha = al; P.strokeStyle("#dff0ff"); P.lineWidth = 1
                for q in p.parts ?? [] { let L0 = (q.l ?? 0) * (0.4 + u * 0.9), a = q.a ?? 0; P.beginPath(); P.moveTo(x, y); P.lineTo(x + cos(a) * L0, y + sin(a) * L0 * 0.8 + u * 6); P.stroke() }
                P.fillStyle("#ffffff"); P.beginPath(); P.arc(x, y, 3 * (1 - u) + 1, 0, 7); P.fill()
                P.globalAlpha = al * 0.5; P.fillStyle("#8fc8ff"); P.beginPath(); P.arc(x, y, 7 * (1 - u) + 2, 0, 7); P.fill(); P.restore()
            case "cyw":
                let R0 = (p.r ?? 9) * (0.85 + 0.5 * u), a0 = p.t * 30 * f
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#ffe27a"); P.lineWidth = 2; P.beginPath(); P.arc(x, y, R0, 0, 7); P.stroke()
                P.strokeStyle("#fffbe8"); P.lineWidth = 1
                for k in 0..<6 { let a = a0 + Double(k) * .pi / 3; P.beginPath(); P.moveTo(x + cos(a) * R0 * 0.25, y + sin(a) * R0 * 0.25); P.lineTo(x + cos(a) * R0, y + sin(a) * R0); P.stroke() }
                P.globalAlpha = (1 - u) * 0.6; P.strokeStyle("#ffe27a")
                for k in 0..<3 { let yy = y - 5 + Double(k) * 5; P.beginPath(); P.moveTo(x - f * (R0 + 3), yy); P.lineTo(x - f * (R0 + 12 + Double(k) * 3), yy); P.stroke() }
                P.restore()
            case "cystar":
                let sc = (p.s ?? 1) * (u < 0.35 ? u / 0.35 : 1) * 9, al = 1 - max(0, (u - 0.4) / 0.6)
                P.save(); P.globalAlpha = al; P.translate(x, y); P.rotate(0.4); P.fillStyle("#ffe27a"); P.beginPath()
                for k in 0..<8 { let a = Double(k) * .pi / 4, r = k % 2 != 0 ? sc * 0.28 : sc; P.lineTo(cos(a) * r, sin(a) * r) }
                P.closePath(); P.fill(); P.fillStyle("#fffbe8"); P.fillRect(-1.5, -1.5, 3, 3); P.restore()
            case "axv":
                let w = 6 * (1 - u) + 1, y0 = p.y0 ?? y, y1 = p.y1 ?? y, yb = y0 + (y1 - y0) * min(1, u * 3)
                P.save(); P.globalAlpha = 1 - u * u
                P.fillStyle("#9fd8ff"); P.globalAlpha *= 0.55; P.fillRect(x - w / 2 - 4, y0, 1, yb - y0); P.fillRect(x + w / 2 + 3, y0, 1, yb - y0); P.globalAlpha = 1 - u * u
                P.fillStyle("#ffffff"); P.fillRect(x - w / 2, y0, w, yb - y0); P.fillStyle("#d8f0ff"); P.beginPath(); P.moveTo(x - w, yb); P.lineTo(x + w, yb); P.lineTo(x, yb + 8); P.closePath(); P.fill(); P.restore()
            case "sxpath":
                let prog = min(1, u * 1.7), N = 22.0, a0 = f > 0 ? 0 : Double.pi, dir: Double = f > 0 ? -1 : 1, r = p.r ?? 36
                P.save(); P.lineWidth = 3.5; P.setLineDash([5, 3])
                for (rr, col, al) in [(r + 5, "#d6453a", 0.7), (r, "#ff8a3a", 1), (r - 6, "#ffc06a", 0.6)] {
                    P.globalAlpha = al * (1 - max(0, (u - 0.6) / 0.4)); P.strokeStyle(col); P.beginPath()
                    var i = 0.0
                    while i <= N * prog { let a = a0 + dir * .pi * i / N, X = x + cos(a) * rr, Y = y + sin(a) * rr * 0.9; if i > 0 { P.lineTo(X, Y) } else { P.moveTo(X, Y) }; i += 1 }
                    P.stroke()
                }
                P.setLineDash([])
                let ah = a0 + dir * .pi * prog, hx = x + cos(ah) * r, hy = y + sin(ah) * r * 0.9
                P.globalAlpha = 1 - u; P.fillStyle("#ff6a3a"); P.beginPath(); P.arc(hx, hy, 3, 0, 7); P.fill(); P.restore()
            case "sxboom":
                let e = u < 0.25 ? u / 0.25 : 1, al = 1 - max(0, (u - 0.35) / 0.65)
                P.save(); P.globalAlpha = al; P.translate(x, y)
                for k in 0..<14 {
                    let a = Double(k) * .pi * 2 / 14 - .pi / 2, L = (k % 2 != 0 ? 22.0 : 34) * e, w = 0.13
                    P.fillStyle(k % 2 != 0 ? "#ff8a3a" : "#fff4e0"); P.beginPath(); P.moveTo(cos(a - w) * 6, sin(a - w) * 6); P.lineTo(cos(a) * L, sin(a) * L * 0.7); P.lineTo(cos(a + w) * 6, sin(a + w) * 6); P.closePath(); P.fill()
                }
                P.fillStyle("#d6453a"); P.beginPath(); P.ellipse(0, 0, 8 * e, 6 * e, 0, 0, 7); P.fill(); P.restore()
            case "sk_glint":
                P.save(); P.globalAlpha = 1 - u; P.fillStyle(p.c ?? "#ffd36a")
                for q in p.P ?? [] {
                    let r = (q.v ?? 0) * u, a = q.a ?? 0, X = x + cos(a) * r, Y = y + sin(a) * r * 0.7 - 14 * u, s = (q.s ?? 1) * (1 - u * 0.5)
                    P.fillRect(X - s, Y - 0.5, s * 2 + 1, 1); P.fillRect(X - 0.5, Y - s, 1, s * 2 + 1)
                }
                P.restore()
            case "sk_rain":
                P.save(); P.globalAlpha = (1 - u) * 0.9; P.strokeStyle("#8fd0ff"); P.lineWidth = 1
                for k in 0..<18 { let sx = x - 44 + Double((k * 37) % 88), sy = y - 50 + Double((k * 23) % 30) + u * 70; P.beginPath(); P.moveTo(sx, sy); P.lineTo(sx - 4, sy + 10); P.stroke() }
                P.restore()
            case "tapok":
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#fff6d0"); P.lineWidth = 3; P.beginPath(); P.arc(x, y, 10 + 40 * u, 0, 7); P.stroke(); P.restore()
            case "slash":
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#ffffff"); P.lineWidth = 4 * (1 - u) + 1; P.beginPath(); P.moveTo(x - 40, y - 26); P.lineTo(x + 40, y + 20); P.stroke()
                P.strokeStyle("#d6453a"); P.lineWidth = 1; P.beginPath(); P.moveTo(x - 38, y - 23); P.lineTo(x + 38, y + 22); P.stroke(); P.restore()
            case "pages":
                let t = p.t
                P.save(); P.globalAlpha = min(1, (p.life - t) / 0.5)
                for q in p.P ?? [] {
                    let vx = q.vx ?? 0, X = x + vx * t + (vx > 0 ? 1 : vx < 0 ? -1 : 0) * 46 * t * t, Y = y + (q.vy ?? 0) * t + 64 * t * t + sin(t * 7 + (q.ph ?? 0)) * 5
                    P.save(); P.translate(X, Y); P.rotate((q.r ?? 0) + (q.vr ?? 0) * t); P.fillStyle("#f1e6cf"); P.fillRect(-3, -4, 6, 8)
                    P.fillStyle("#2a2732"); P.fillRect(-2, -2, 4, 1); P.fillRect(-2, 0, 3, 1); P.fillRect(-2, 2, 4, 1); P.restore()
                }
                P.restore()
            case "crescent":
                let R = (p.r ?? 34) * (1 + 0.18 * u), T = (p.w ?? 13) * (1 - u * 0.75), N = 26, a0 = p.a0 ?? 0, a1 = p.a1 ?? 0
                func pt(_ a: Double, _ r: Double) -> (Double, Double) { let aa = f < 0 ? .pi - a : a; return (x + cos(aa) * r, y + sin(aa) * r) }
                for (k, col, al) in [(1.0, "#f0b890", 0.95), (0.7, skinAcc ?? "#5fe0b0", 0.95), (0.36, "#f6fffa", 1)] {
                    P.globalAlpha = (1 - u * u) * al; P.fillStyle(col); P.beginPath()
                    for i in 0...N { let a = a0 + (a1 - a0) * Double(i) / Double(N), q = pt(a, R); if i > 0 { P.lineTo(q.0, q.1) } else { P.moveTo(q.0, q.1) } }
                    for i in stride(from: N, through: 0, by: -1) { let sN = Double(i) / Double(N), a = a0 + (a1 - a0) * sN, q = pt(a, R - T * k * pow(sin(.pi * sN), 0.7)); P.lineTo(q.0, q.1) }
                    P.closePath(); P.fill()
                }
                P.globalAlpha = 1
            case "gdust":
                let e = 1 - pow(1 - u, 2.2)
                for q in p.puffs ?? [] {
                    let v = max(0, (u - q.d) / (1 - q.d)); if v <= 0 { continue }
                    let X = x + q.dx + q.vx * e, Y = y - 1.5 - q.rise * e, r = q.r * (0.55 + v * 1.1)
                    P.globalAlpha = (1 - v) * 0.5; P.fillStyle("#8f8476"); P.beginPath(); P.arc(X, Y, r, 0, 7); P.fill()
                    P.globalAlpha = (1 - v) * 0.35; P.fillStyle("#c9bca8"); P.beginPath(); P.arc(X - r * 0.25, Y - r * 0.3, r * 0.55, 0, 7); P.fill()
                }
                P.globalAlpha = 1
            case "twfall":
                for q in p.parts ?? [] {
                    let X = x + (q.vx ?? 0) * p.t, Y = min(222 - 1, y + (q.vy ?? 0) * p.t + 300 * p.t * p.t), s = q.s ?? 1
                    P.globalAlpha = 1 - u * 0.6; P.fillStyle(q.c ?? "#6e726d"); P.fillRect(Self.jsRound(X), Self.jsRound(Y), s, s)
                }
                P.globalAlpha = 1
            case "debris":
                for q in p.parts ?? [] {
                    let X = x + (q.vx ?? 0) * p.t, Y = min(y - 1, y - 2 - ((q.vy ?? 0) * p.t - 420 * p.t * p.t)), s = q.s ?? 1
                    P.globalAlpha = 1 - u; P.fillStyle("#4d443c"); P.fillRect(Self.jsRound(X), Self.jsRound(Y), s, s)
                }
                P.globalAlpha = 1
            case "crack":
                P.globalAlpha = (1 - u) * 0.8; P.strokeStyle("#16120f"); P.lineWidth = 1.2; P.beginPath()
                for (i, d) in (p.pts ?? []).enumerated() where d.count >= 2 { if i > 0 { P.lineTo(x + d[0], y + d[1]) } else { P.moveTo(x + d[0], y + d[1]) } }
                P.stroke(); P.globalAlpha = 1
            case "streak":
                let L = 1 - u, vx = p.vx ?? 0, vy = p.vy ?? 0
                P.strokeStyle(p.col ?? "#ffd34a"); P.globalAlpha = (1 - u * 0.5) * (p.a ?? 1); P.lineWidth = 1.8 * (1 - u * 0.5); P.lineCap = .round
                P.beginPath(); P.moveTo(x + vx * p.t, y + vy * p.t); P.lineTo(x + vx * (p.t + 0.065 * L), y + vy * (p.t + 0.065 * L)); P.stroke()
            case "flash":
                let r = (p.big == true ? 13.0 : 9) * (0.6 + u * 0.6)
                P.globalAlpha = 1 - u; P.strokeStyle("#ffffff"); P.lineWidth = 2 * (1 - u) + 0.6
                P.beginPath(); P.moveTo(x - r, y); P.lineTo(x + r, y); P.moveTo(x, y - r * 0.7); P.lineTo(x, y + r * 0.7); P.stroke()
            case "txt":
                P.save(); P.globalAlpha = 1 - max(0, (u - 0.6) / 0.4); P.font = .galmuri11(12, bold: true); P.textAlign = .center; P.lineJoin = .round; P.lineWidth = 3
                P.strokeStyle(uiInk); P.strokeText(p.text ?? "", x, y - u * 18); P.fillStyle(p.col ?? "#ffe27a"); P.fillText(p.text ?? "", x, y - u * 18); P.restore()
            case "fire":
                let r = 3 + (1 - u) * 4
                P.save(); P.globalAlpha = (1 - u) * 0.9; P.fillStyle(u < 0.3 ? "#fff2a0" : u < 0.6 ? "#ffaa3a" : "#e8422a"); P.beginPath(); P.arc(x + sin(p.t * 14 + x) * 2, y - u * 26, r, 0, .pi * 2); P.fill(); P.restore()
            case "smoke":
                if p.steam == true {
                    let r = 3 + u * 10
                    P.save(); P.globalAlpha = (1 - u) * 0.5; P.fillStyle("#e8eef4"); P.beginPath(); P.arc(x + sin(p.t * 4 + x) * 3, y - u * 30, r, 0, .pi * 2); P.fill(); P.restore()
                } else {
                    let r = 4 + u * 14
                    P.save(); P.globalAlpha = (1 - u) * 0.45; P.fillStyle(u < 0.2 ? "#3a3a40" : "#6a6a72"); P.beginPath(); P.arc(x + sin(p.t * 3 + x) * 4, y - u * 40, r, 0, .pi * 2); P.fill(); P.restore()
                }
            case "swirl":
                let a = 1 - u
                P.save(); P.translate(x, y); P.lineCap = .round
                for j in 0..<3 {
                    let jj = Double(j), rx = (p.big == true ? 74.0 : 58) - jj * 12, ry = 10 + jj * 3
                    let a0 = ((p.ph ?? 0) * 1.3 + jj * 2.1 + u * 5).truncatingRemainder(dividingBy: .pi * 2)
                    P.globalAlpha = a * (0.75 - jj * 0.2); P.lineWidth = 2.2 - jj * 0.5; P.strokeStyle(j > 0 ? "#cfe8ff" : "#ffffff")
                    P.beginPath(); P.ellipse(0, jj * 6, rx, ry, 0, a0, a0 + .pi * 1.1); P.stroke()
                }
                P.restore()
            case "wave":
                let r = 8 + 82 * Self.easeO(u)
                P.save(); P.globalAlpha = (1 - u) * 0.85; P.lineWidth = 3 * (1 - u) + 1; P.strokeStyle("#ffe2a0"); P.beginPath(); P.ellipse(x, y - 1, r, r * 0.16, 0, 0, .pi * 2); P.stroke()
                P.strokeStyle("#ffffff"); P.lineWidth = 1; P.beginPath(); P.ellipse(x, y - 1, r * 0.8, r * 0.13, 0, 0, .pi * 2); P.stroke(); P.restore()
            case "arc":
                let u2 = min(1, p.t / 0.08), a = 1 - u
                P.save(); P.translate(x, y); P.scale(f, 1); P.lineCap = .round
                func seg(_ a0: Double, _ a1: Double, _ rx: Double, _ ry: Double) {
                    for j in 0..<3 {
                        let jj = Double(j)
                        P.globalAlpha = a * (1 - jj * 0.3); P.lineWidth = 3.2 - jj; P.strokeStyle(j > 0 ? "#ffcf6a" : "#fffbe8")
                        P.beginPath(); P.ellipse(0, 0, rx - jj * 2, ry - jj * 0.6, 0, a0, a0 + (a1 - a0) * u2, a1 < a0); P.stroke()
                    }
                }
                if p.kind == "d" { seg(-1.9, 0.7, 26, 26) } else if p.kind == "h" { seg(.pi * 0.95, .pi * 2.05, 30, 9) } else { seg(.pi * 0.05, -.pi * 1.05, 30, 9) }
                P.restore()
            case "drop":
                P.globalAlpha = 1 - u; P.fillStyle(p.col ?? "#cfe8ff"); P.fillRect(x, y, 1.6, 1.6)
            case "burst":
                let e = 1 - pow(1 - u, 3), n = p.n ?? 14, r0 = p.r0 ?? 8, r1 = p.r1 ?? 44, red = p.red == true, gd = p.kind == "guard"   // gd: 가드 크래시(파랑 · 흰)
                P.save(); P.translate(x, y); P.lineCap = .round
                for j in 0..<n {
                    let a = Double(j) / Double(n) * .pi * 2 + (j % 2 != 0 ? 0.12 : 0), L = j % 2 != 0 ? 0.62 : 1.0
                    let ra = r0 + (r1 - r0) * e * 0.35, rb = r0 + (r1 - r0) * min(1, e * 1.3) * L
                    P.globalAlpha = (1 - u) * (j % 2 != 0 ? 0.7 : 1)
                    P.strokeStyle(gd ? (j % 3 != 0 ? "#9ad8ff" : "#ffffff") : red ? (j % 3 != 0 ? "#ff7a5a" : "#ffd2c4") : (j % 3 != 0 ? "#ffe27a" : "#ffffff"))
                    P.lineWidth = (j % 2 != 0 ? 1.4 : 2.8) * (1 - u * 0.55)
                    P.beginPath(); P.moveTo(cos(a) * ra, sin(a) * ra * 0.8); P.lineTo(cos(a) * rb, sin(a) * rb * 0.8); P.stroke()
                }
                P.globalAlpha = (1 - u) * 0.85; P.strokeStyle(gd ? "#e8f6ff" : red ? "#ffb4a2" : "#fff6d0"); P.lineWidth = 2 * (1 - u) + 0.4
                let rr = r0 + (r1 - r0) * e * 0.5
                P.beginPath(); P.ellipse(0, 0, rr, rr * 0.8, 0, 0, .pi * 2); P.stroke(); P.restore()
            case "gblock":   // 네이티브 공방: 막기 — 맞닿은 자리에 파랗고 흰 불꽃(바깥으로 튀는 선) + 때린 쪽을 향한 방패 호
                let big = p.big == true, red = p.red == true, n = big ? 9 : 7
                P.save(); P.translate(x, y); P.lineCap = .round
                for j in 0..<n {
                    let a = (Double(j) / Double(n) - 0.5) * 2.4 + .pi, L = (j % 2 == 0 ? 1.0 : 0.6) * (big ? 15 : 11)
                    let r0 = 2 + 4 * u, r1 = r0 + L * (0.4 + 0.6 * min(1, u * 3))
                    P.globalAlpha = 1 - u; P.strokeStyle(red ? (j % 2 == 0 ? "#ffb08a" : "#ffffff") : (j % 2 == 0 ? "#ffffff" : "#9ad8ff")); P.lineWidth = (j % 2 == 0 ? 1.8 : 1.2) * (1 - u * 0.5)
                    let dx = cos(a) * -f, dy = sin(a)
                    P.beginPath(); P.moveTo(dx * r0, dy * r0 * 0.9); P.lineTo(dx * r1, dy * r1 * 0.9); P.stroke()
                }
                if !red {   // 방패 호(가드 팔)
                    P.globalAlpha = (1 - u) * 0.9; P.strokeStyle("#e8f6ff"); P.lineWidth = big ? 2.6 : 2
                    let r = 9 + 3 * u
                    P.beginPath(); P.ellipse(f * 2, 0, r * 0.55, r, 0, f > 0 ? .pi * 0.6 : -.pi * 0.4, f > 0 ? .pi * 1.4 : .pi * 0.4); P.stroke()
                }
                P.globalAlpha = (1 - u); P.fillStyle("#ffffff"); P.fillRect(-1.5, -1.5, 3, 3)
                P.restore()
            case "gjust":   // 저스트 가드: 흰 고리 두 겹 + 섬광 십자
                let e = 1 - pow(1 - u, 2)
                P.save(); P.globalAlpha = 1 - u; P.strokeStyle("#ffffff"); P.lineWidth = 2.4 * (1 - u) + 0.6
                P.beginPath(); P.ellipse(x, y, 6 + 22 * e, (6 + 22 * e) * 0.85, 0, 0, .pi * 2); P.stroke()
                P.strokeStyle("#fff2a8"); P.lineWidth = 1.4; P.beginPath(); P.ellipse(x, y, 3 + 13 * e, (3 + 13 * e) * 0.85, 0, 0, .pi * 2); P.stroke()
                let r = 16 * (1 - u * 0.5)
                P.strokeStyle("#ffffff"); P.lineWidth = 2 * (1 - u) + 0.5
                P.beginPath(); P.moveTo(x - r, y); P.lineTo(x + r, y); P.moveTo(x, y - r * 0.8); P.lineTo(x, y + r * 0.8); P.stroke(); P.restore()
            case "gshatter":   // 가드 크래시: 깨진 방패 조각이 돌며 튄다(중력)
                P.save()
                for q in p.parts ?? [] {
                    let t = p.t, px = x + (q.vx ?? 0) * t, py = y + (q.vy ?? 0) * t + 210 * t * t, sz = (q.s ?? 1) + 1
                    let rot = (q.a ?? 0) + (q.l ?? 0) * t
                    P.globalAlpha = 1 - u * u
                    P.save(); P.translate(px, py); P.rotate(rot); P.fillStyle(q.c ?? "#cfe8ff"); P.fillRect(-sz / 2, -sz * 0.35, sz, sz * 0.7)
                    P.fillStyle("#2c4a7a"); P.fillRect(-sz / 2, sz * 0.2, sz, 0.6); P.restore()
                }
                P.restore()
            case "nv_alert":   // 끼어들기 예고: 머리 위 커다란 '!' + 들쭉날쭉한 별(맥박) — 탭 받아치기 기회
                let pulse = 1 + 0.18 * sin(p.t * 26), a0 = u < 0.8 ? 1 : (1 - u) / 0.2
                P.save(); P.translate(x, y); P.scale(pulse, pulse); P.globalAlpha = a0
                P.fillStyle("#ff4a3a"); P.beginPath()
                for k in 0..<16 { let a = Double(k) / 16 * .pi * 2, r = k % 2 == 0 ? 13.0 : 7.5; if k == 0 { P.moveTo(cos(a) * r, sin(a) * r) } else { P.lineTo(cos(a) * r, sin(a) * r) } }
                P.closePath(); P.fill()
                P.strokeStyle(uiInk); P.lineWidth = 1.2; P.stroke()
                P.fillStyle("#fff6d0"); P.fillRect(-1.5, -6, 3, 7); P.fillRect(-1.5, 3, 3, 3)
                P.restore()
            case "nv_ghost":   // 네이티브 막차 러시 잔상: 웅크린 몸 그림자(머리 · 몸통 · 앞뒤 다리), 남색 반투명으로 사라진다
                let sk = p.ph == 1 ? 1.0 : -1.0
                P.save(); P.translate(x, y); P.scale(f, 1); P.globalAlpha = (1 - u) * (p.a ?? 0.4); P.fillStyle("#2c4a7a"); P.strokeStyle("#2c4a7a"); P.lineCap = .round
                P.beginPath(); P.arc(4, -46 + sk, 4, 0, .pi * 2); P.fill()
                P.lineWidth = 9; P.beginPath(); P.moveTo(0, -24); P.lineTo(3, -39); P.stroke()
                P.lineWidth = 4; P.beginPath(); P.moveTo(-1, -22); P.lineTo(-7, -12); P.lineTo(-10, -1); P.moveTo(1, -22); P.lineTo(8, -12); P.lineTo(9, -1); P.stroke()
                P.lineWidth = 3.4; P.beginPath(); P.moveTo(4, -38); P.lineTo(9, -40 + 4 * sk); P.moveTo(2, -37); P.lineTo(8, -34 - 3 * sk); P.stroke()
                P.restore()
            case "nv_ghost_n":   // 굴러 올라가는 숫자의 '+N' 잔상: 옆으로 벗겨져 나가며 옅어진다(작게 · 반투명)
                P.save(); P.globalAlpha = 0.7 * (1 - u); P.font = .galmuri9(9); P.textAlign = .center; P.lineJoin = .round; P.lineWidth = 2.4
                let gx = x + f * 10 * u, gy = y - 6 * u
                P.strokeStyle(uiInk); P.strokeText(p.text ?? "", gx, gy); P.fillStyle("#fff6d8"); P.fillText(p.text ?? "", gx, gy); P.restore()
            case "ring":
                let e = 1 - pow(1 - u, 2), rr = 3 + (p.r1 ?? 14) * e
                P.save(); P.globalAlpha = (1 - u) * 0.8; P.strokeStyle("#ffe9a8"); P.lineWidth = 1.6 * (1 - u) + 0.4
                P.beginPath(); P.ellipse(x, y, rr, rr * 0.8, 0, 0, .pi * 2); P.stroke(); P.restore()
            default: break
            }
        }

        // MARK: 만화(웹 drawComic)

        static func comicPop(_ t: Double) -> Double { t < 0.09 ? 0.45 + 0.75 * (t / 0.09) : t < 0.18 ? 1.2 - 0.2 * ((t - 0.09) / 0.09) : 1 }

        mutating func drawComic(_ s: HUDState) {
            enum Item { case word(HUDState.ComicWord), bubble(HUDState.Bubble) }
            let items: [(Int, Item)] = (s.words.map { ($0.id, Item.word($0)) } + s.bubbles.map { ($0.id, Item.bubble($0)) }).sorted { $0.0 < $1.0 }
            for (_, it) in items {
                switch it {
                case .word(let c):
                    let sc = Self.comicPop(c.age)
                    P.globalAlpha = c.age > c.life - 0.25 ? max(0, (c.life - c.age) / 0.25) : 1
                    if c.age > 0.2 { P.globalAlpha *= 0.9 }
                    P.save(); P.translate(c.x, c.y); P.rotate(c.rot); P.scale(sc, sc)
                    P.font = .comic(14)
                    let tw = P.measureText(c.word), R = tw * 0.58 + 9
                    func star(_ f: Double) {
                        P.beginPath()
                        for k in 0..<26 {
                            let a = Double(k) / 26 * .pi * 2, r = (k % 2 != 0 ? 0.7 : 1) * R * f * (k % 6 == 0 ? 1.14 : 1)
                            let px = cos(a) * r, py = sin(a) * r * 0.6
                            if k > 0 { P.lineTo(px, py) } else { P.moveTo(px, py) }
                        }
                        P.closePath()
                    }
                    star(1); P.fillStyle("#ffe24a"); P.fill(); P.lineWidth = 1.4; P.strokeStyle(uiInk); P.stroke()
                    star(0.74); P.fillStyle("#ff8a2a"); P.fill()
                    P.textAlign = .center; P.textBaseline = .middle; P.lineJoin = .round
                    P.fillStyle("#3a0a0a"); P.fillText(c.word, 1.8, 2.2); P.lineWidth = 3.2; P.strokeStyle(uiInk); P.strokeText(c.word, 0, 0)
                    P.fillGradient(y0: -6, y1: 6, "#fff6c8", "#e8322a"); P.fillText(c.word, 0, 0)
                    P.restore()
                case .bubble(let c):
                    let sc = Self.comicPop(c.age)
                    P.globalAlpha = c.age > c.life - 0.25 ? max(0, (c.life - c.age) / 0.25) : 1
                    P.font = .galmuri9(10)
                    let tw = P.measureText(c.text), w = tw + 16, h = 18.0
                    let vx0 = F.camX, vx1 = vx0 + VW
                    let bx = max(vx0 + 4, min(vx1 - w - 4, c.x - w / 2)), by = c.y - 104, mx = bx + w / 2, my = by + h / 2
                    let hx = max(bx + 6, min(bx + w - 6, c.x)), hy = c.y - 72
                    P.save(); P.translate(mx, my); P.scale(sc, sc); P.translate(-mx, -my)
                    func body() {
                        P.beginPath()
                        if c.kind == "speech" {
                            let r = 8.0
                            P.moveTo(bx + r, by); P.arcTo(bx + w, by, bx + w, by + h, r); P.arcTo(bx + w, by + h, bx, by + h, r); P.arcTo(bx, by + h, bx, by, r); P.arcTo(bx, by, bx + w, by, r); P.closePath()
                            P.moveTo(hx - 4, by + h - 1); P.lineTo(hx + 3, by + h - 1); P.lineTo(hx + 1, hy); P.closePath()
                        } else if c.kind == "shout" {
                            let n = 24
                            for k in 0..<n {
                                let t = Double(k) / Double(n) * .pi * 2, f = k % 2 != 0 ? 1 : 1.28
                                let px = mx + cos(t) * (w / 2 + 2) * f, py = my + sin(t) * (h / 2 + 2) * f
                                if k > 0 { P.lineTo(px, py) } else { P.moveTo(px, py) }
                            }
                            P.closePath()
                            P.moveTo(hx - 3, by + h + 1); P.lineTo(hx + 3, by + h + 1); P.lineTo(hx - 2, hy); P.closePath()
                        } else {
                            for k in 0..<11 {
                                let t = Double(k) / 11 * .pi * 2, cxp = mx + cos(t) * w / 2 * 0.9, cyp = my + sin(t) * h / 2 * 0.92
                                P.moveTo(cxp + 6.5, cyp); P.arc(cxp, cyp, 6.5, 0, .pi * 2)
                            }
                            P.moveTo(mx + w / 2 - 2, my); P.ellipse(mx, my, w / 2 - 2, h / 2, 0, 0, .pi * 2)
                            P.moveTo(hx + 2.4, hy - 8); P.arc(hx, hy - 8, 2.4, 0, .pi * 2)
                            P.moveTo(hx + 1.4, hy - 2.5); P.arc(hx - 1, hy - 2.5, 1.4, 0, .pi * 2)
                        }
                    }
                    body(); P.lineWidth = 2; P.strokeStyle(uiInk); P.stroke(); body(); P.fillStyle(c.kind == "shout" ? "#fff7d0" : "#ffffff"); P.fill()
                    P.fillStyle(uiInk); P.textAlign = .center; P.textBaseline = .middle; P.fillText(c.text, mx, my + 0.5); P.restore()
                }
                P.globalAlpha = 1
            }
        }

        // MARK: 문 전환(웹 drawWipe)

        mutating func drawWipe(_ Wp: WipeView) {
            let T = 0.5, u = Wp.t / T
            if Wp.t >= T { return }
            let close = u < 0.4 ? Self.easeO(u / 0.4) : u < 0.6 ? 1 : 1 - Self.easeO((u - 0.6) / 0.4), half = VW / 2 * close
            for side in [0, 1] {
                let x0 = side == 1 ? VW - half : 0
                P.fillStyle("#3a3f4e"); P.fillRect(x0, 0, half, H); P.fillStyle("#22242e"); P.fillRect(side == 1 ? x0 : x0 + half - 4, 0, 4, H)
                if half > 40 {
                    let wx = side == 1 ? x0 + 18 : x0 + half - 58
                    P.fillStyle(uiInk); P.fillRect(wx, 60, 40, 64); P.fillStyle("#6a7898"); P.fillRect(wx + 3, 63, 34, 58); P.fillStyle("rgba(255,255,255,.25)"); P.fillRect(wx + 5, 65, 6, 40)
                }
            }
            if close > 0.85, let label = Wp.label {
                P.font = .galmuri11(12, bold: true); P.textAlign = .center
                P.fillStyle(uiInk); P.fillText(label, VW / 2 + 1, H / 2 + 1); P.fillStyle("#ffe27a"); P.fillText(label, VW / 2, H / 2); P.textAlign = .left
            }
        }

        // MARK: 컷인(웹 drawCut · drawCut0 · panel · letter · art)

        mutating func drawCut(_ C: CutView) {
            let cs = VW / W
            P.save()
            if cs < 1 {
                P.fillStyle("rgba(8,6,16,.62)"); P.fillRect(0, 0, VW, H)
                P.setTransform(UIS * cs, 0, 0, UIS * cs, 0, UIS * (H - H * cs) / 2)
            }
            drawCut0(C)
            P.restore()
        }

        mutating func panel(_ pts: [(Double, Double)], _ dx: Double, _ dy: Double, _ bg: [String], _ fn: (inout Builder, Double, Double) -> Void) {
            P.save(); P.translate(dx, dy); P.beginPath()
            for (i, p) in pts.enumerated() { if i > 0 { P.lineTo(p.0, p.1) } else { P.moveTo(p.0, p.1) } }
            P.closePath()
            P.save(); P.clip(); P.fillStyle(bg[0]); P.fillRect(0, 0, W, H); P.fillStyle(bg[1])
            // 망점: 자르기 밖은 어차피 안 보이니 다각형 bbox 안만 만든다(결과 같음)
            let xs = pts.map(\.0), ys = pts.map(\.1)
            let bx0 = (xs.min()! - 2), bx1 = xs.max()! + 2, by0 = ys.min()! - 2, by1 = ys.max()! + 2
            var y = 0.0
            while y < H {
                if y >= by0 && y <= by1 {
                    var x = Self.flo(y / 4) % 2 != 0 ? 2.0 : 0
                    while x < W { if x >= bx0 && x <= bx1 { P.fillRect(x, y, 1.3, 1.3) }; x += 4 }
                }
                y += 4
            }
            let mx = pts.reduce(0) { $0 + $1.0 } / Double(pts.count), my = pts.reduce(0) { $0 + $1.1 } / Double(pts.count)
            P.strokeStyle(bg[2]); P.lineWidth = 0.8
            for k in 0..<26 { let a = Double(k) / 26 * .pi * 2; P.beginPath(); P.moveTo(mx + cos(a) * 30, my + sin(a) * 30); P.lineTo(mx + cos(a) * 300, my + sin(a) * 300); P.stroke() }
            fn(&self, mx, my)
            P.restore()
            P.beginPath()
            for (i, p) in pts.enumerated() { if i > 0 { P.lineTo(p.0, p.1) } else { P.moveTo(p.0, p.1) } }
            P.closePath()
            P.lineWidth = 4; P.strokeStyle(uiInk); P.stroke(); P.lineWidth = 1.2; P.strokeStyle("#f1ece0"); P.stroke(); P.restore()
        }

        mutating func letter(_ txt: String, _ x: Double, _ y: Double, _ size: Double, _ fill: String, _ rot: Double = -0.06) {
            P.save(); P.translate(x, y); P.rotate(rot); P.font = .comic(size); P.textAlign = .center; P.textBaseline = .middle; P.lineJoin = .round
            P.fillStyle(uiInk); P.fillText(txt, 2.2, 2.6); P.lineWidth = size * 0.22; P.strokeStyle(uiInk); P.strokeText(txt, 0, 0)
            P.fillGradient(y0: -size / 2, y1: size / 2, "#fffbe0", fill); P.fillText(txt, 0, 0); P.restore()
        }

        mutating func drawArt(_ k: String, _ x: Double, _ y: Double, _ s: Double, _ flip: Bool = false) {
            guard let c = art.cutArt(k, skin: F.skin, shades: F.shades) else { return }
            P.save(); P.imageSmoothingEnabled = false
            let w = Double(c.w) * s, h = Double(c.h) * s
            if flip { P.translate(x + w, y); P.scale(-1, 1); P.drawImage(c, 0, 0, w, h) } else { P.drawImage(c, x, y, w, h) }
            P.restore()
        }

        mutating func drawCut0(_ C: CutView) {
            let u = C.t / max(1e-6, C.dur), out = max(0, (u - 0.86) / 0.14), sh = 0.0   // 흔들림(u<.12 무작위)은 0 — 웹 캡처도 Math.random=.5 로 맞춘다
            P.fillStyle(RGBA(8 / 255, 6 / 255, 16 / 255, 0.62 * (1 - out))); P.fillRect(0, 0, W, H); P.globalAlpha = 1 - out
            func e(_ k: Double) -> Double { Self.easeO((C.t - k * 0.07) / 0.22) }
            if C.k == "spc", let S = art.spc[C.kind ?? "fist"] {
                panel([(14, 54), (176, 46), (164, 206), (6, 212)], -(1 - e(0)) * 260 + sh, 0, ["#1d2650", "#2c3a78", "rgba(255,255,255,.08)"]) { B, mx, my in B.drawArt("eyes:hero", mx - 96, my - 36, 2) }
                panel([(184, 40), (318, 48), (306, 214), (172, 206)], 0, -(1 - e(1)) * 280, ["#ffcf4a", "#ffb02a", "rgba(255,255,255,.35)"]) { B, mx, my in B.letter(S.n, mx, my - 8, 30, "#e8322a"); B.letter(S.en, mx, my + 24, 11, "#3a1a08", -0.04) }
                let shoe = S.art == "shoe:x"
                panel([(326, 44), (474, 52), (470, 214), (314, 206)], (1 - e(2)) * 260 - sh, 0, ["#4a1020", "#6a1830", "rgba(255,200,120,.12)"]) { B, mx, my in B.drawArt(S.art, mx - (shoe ? 64 : 56), my - (shoe ? 48 : 56), 2, C.kind == "foot") }
            }
            if C.k == "vs" || C.k == "rage" {
                let bt = C.boss ?? "boss", I = art.bossInfo[bt] ?? art.bossInfo["boss"]!
                if C.k == "vs" {
                    let e1 = Self.easeO(C.t / 0.25), e2 = Self.easeO((C.t - 0.08) / 0.25)
                    panel([(0, 36), (250, 36), (214, 232), (0, 232)], -(1 - e1) * 260 + sh, 0, ["#1d2650", "#2c3a78", "rgba(255,255,255,.08)"]) { B, _, _ in B.drawArt("face:hero", 30, 70, 2.4) }
                    panel([(262, 36), (480, 36), (480, 232), (226, 232)], (1 - e2) * 260 - sh, 0, ["#2a0e14", I.col, "rgba(255,255,255,.1)"]) { B, _, _ in B.drawArt("face:" + bt, 300, 70, 2.4, true) }
                    if C.t > 0.2 { letter("VS", 240, 128, 42, "#ff8a2a", -0.12) }
                    if C.t > 0.3 {
                        let yy = 208.0
                        P.fillStyle(I.col); P.fillRect(250, yy, 230, 22); P.fillStyle(uiInk); P.fillRect(250, yy + 22, 230, 3)
                        letter(I.n, 360, yy + 10, 15, "#ffffff", 0); letter(I.nick, 360, yy - 10, 9, "#ffe27a", 0)
                    }
                    if C.t > 0.45 { letter(art.bossLines[bt] ?? "", 128, 214, 12, "#ffe27a", -0.03) }
                } else {
                    let e1 = Self.easeO(C.t / 0.2)
                    panel([(0, 84), (480, 74), (480, 180), (0, 190)], -(1 - e1) * 480 + sh, 0, ["#2a0a0e", "#7a1018", "rgba(255,120,80,.18)"]) { B, mx, my in B.drawArt("rage:" + bt, mx - 144, my - 54, 3) }
                    if C.t > 0.25 { letter(I.rage, 360, 196, 15, "#ff6a4a", -0.04) }
                }
            }
            P.globalAlpha = 1
        }
    }
}
