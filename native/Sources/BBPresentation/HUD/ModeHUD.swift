import Foundation

// 모드별 HUD 그리기 — 웹 줄 단위 이식(HUDOverlay.Builder 확장). 입력은 HUDFrame.modes(HUDModes).
//   drawTowerTop(24-tower) · drawBonusHUD(43-fx-smoke) · drawDojoHUD(47) · 복도 'B2 CORRIDOR'(47 drawUI) ·
//   거리 연출 갈래(47 drawUI: 레터박스 22 → drawDmg → 하얀 빛 → 어둠) · drawShowLamps(29-combat-flow, 원형 그라디언트)
// 부르는 자리는 HUDDraw.drawUI(모드 갈래 · 레터박스 높이 · 점수 자리 · 전구) · drawDmg(필살 게이지 조건 · 만화 페이지).

extension HUDOverlay.Builder {
    var modes: HUDModes? { F.modes }
    func KE(_ ko: String, _ en: String) -> String { (F.modes?.en ?? false) ? en : ko }
    static func pad(_ v: Int, _ n: Int) -> String { let s = String(v); return String(repeating: "0", count: max(0, n - s.count)) + s }

    // MARK: 타워(웹 drawTowerTop) — 층 · 이름 · 단계/오늘 배지 · 정원 칸 · 최고 기록 · 시간 · 정원 초과 띠 · 작업 막대

    mutating func drawTowerTop(_ T: HUDModes.Tower) {
        let wt = T.weight, LIM = T.limit, over = wt > LIM, blink = Self.flo(F.time * 4) % 2 != 0
        P.save(); P.textBaseline = .top; P.fillStyle("rgba(8,6,14,.72)"); P.fillRect(5, 5, 132, 33)
        P.font = .galmuri11(14, bold: true); P.fillStyle("#ffd34a"); let fl = "\(T.floor)F"; P.fillText(fl, 10, 8); let fw = P.measureText(fl)
        P.font = .galmuri9(10); P.fillStyle("#e9e4f7"); P.fillText(T.name, 15 + fw, 11)
        if T.daily || T.ot != 0 {
            let nw = P.measureText(T.name), tg = T.daily ? KE("오늘", "DAILY") : KE("야근\(T.ot)", "OT\(T.ot)")
            P.fillStyle(T.daily ? "#ffd34a" : "#ff7a5c"); P.fillRect(19 + fw + nw, 10, P.measureText(tg) + 6, 12); P.fillStyle("#2a1a10"); P.fillText(tg, 22 + fw + nw, 11)
        }
        P.fillStyle(over ? (blink ? "#ff6a5a" : "#ffd0c0") : "#a99fc2"); P.fillText(KE("정원", "Load"), 10, 25)
        let n = max(LIM, min(12, wt))
        for k in 0..<max(0, n) {
            P.fillStyle(k >= LIM ? (blink ? "#ff5a4a" : "#7a2420") : k < wt ? (over ? "#ff8a5a" : "#ffd34a") : "#2a2440"); P.fillRect(38 + Double(k) * 7, 27, 5, 6)
        }
        P.fillStyle(over ? "#ff8a7a" : "#cfc6e6"); P.fillText("\(wt)/\(LIM)", 40 + Double(n) * 7, 25)
        let secs = T.secs, tm = "\(secs / 60):\(Self.pad(secs % 60, 2))"
        P.textAlign = .right; P.fillStyle("rgba(8,6,14,.6)")
        let rt = "\(KE("최고", "BEST")) \(T.best)F · \(tm)", rw = P.measureText(rt)
        P.fillRect(SW - rw - 10, 22, rw + 6, 13); P.fillStyle("#cfc6e6"); P.fillText(rt, SW - 7, 24); P.textAlign = .left
        if over && T.hold {
            let t = KE("정원 초과 — 문이 열린 동안 밖으로 날려요", "Over capacity — throw them out while the doors are open"), w = P.measureText(t)
            P.fillStyle(blink ? "rgba(150,24,18,.88)" : "rgba(110,18,14,.88)"); P.fillRect(SW / 2 - w / 2 - 6, 44, w + 12, 15); P.fillStyle("#ffe0d0"); P.fillText(t, SW / 2 - w / 2, 47)
        }
        for a in T.workers where a.count >= 4 {
            let bx = Self.jsRound(a[0] - F.camX - 10), by = a[1] - 78
            P.fillStyle("#120c16"); P.fillRect(bx - 1, by - 1, 22, 5); P.fillStyle(a[3] != 0 ? "#ffd34a" : "#7cd4ff"); P.fillRect(bx, by, Self.jsRound(20 * min(1, a[2])), 3)
        }
        P.restore()
    }

    // MARK: 보너스(웹 drawBonusHUD) — 결산판(drawBonusResult)은 SwiftUI BonusBoardView

    static let carStages: [Double] = [0.88, 0.76, 0.64, 0.52, 0.40, 0.28, 0.16, 0]   // 웹 CAR_STAGES(= BBSim BonusCarRig.stages)
    static let gradeCol: [String: String] = ["S": "#ffd34a", "A": "#ff8a2a", "B": "#6ec6ff", "C": "#cfc6e6", "D": "#9a8a8a"]

    mutating func drawBonusHUD(_ B: HUDModes.Bonus) {
        let cx = SW / 2, left = max(0, B.left)
        pxText(10, 8, "BONUS STAGE", "#ffd34a"); pxText(10, 18, "SCORE " + Self.pad(Int(Self.jsRound(Double(B.score))), 7), "#f1ece0")
        let tcol = B.go && left < 5 && Self.flo(F.now * 1000 / 200) % 2 != 0 ? "#ff5a4a" : "#ffffff"
        letter(Self.pad(Int(left.rounded(.up)), 2), cx, 22, 20, tcol, 0)
        let w = min(170, SW - 80), x = cx - w / 2, y = 38.0, k = B.hp / B.max
        P.fillStyle(HUDOverlay.uiInk); P.fillRect(x - 1, y - 1, w + 2, 7); P.fillStyle("#2a1018"); P.fillRect(x, y, w, 5)
        P.fillStyle("#e0a33a"); P.fillRect(x, y, Self.jsRound(w * k), 5); P.fillStyle("rgba(255,255,255,.3)"); P.fillRect(x, y, Self.jsRound(w * k), 1)
        P.fillStyle(HUDOverlay.uiInk); for t in Self.carStages where t > 0 { P.fillRect(x + Self.jsRound(w * t), y, 1, 5) }
        pxText(x - 26, y, "CAR", "#cfc6e6")
        if let g = B.grade { letter(g, cx, SH / 2 - 10, 46, Self.gradeCol[g] ?? "#cfc6e6", -0.08) }
    }

    // MARK: 무도장(웹 drawDojoHUD) — 동작 정보 줄 · 속도/반복/확대

    mutating func drawDojoHUD(_ D: HUDModes.Dojo) {
        P.font = .galmuri9(10); P.textBaseline = .top; P.textAlign = .left
        let lw = (D.rows.map { P.measureText($0.first ?? "") }.max() ?? 0) + 6
        let tw = min(SW - 12, (D.rows.map { lw + P.measureText($0.count > 1 ? $0[1] : "") }.max() ?? 0) + 10)
        P.fillStyle("rgba(8,6,14,.72)"); P.fillRect(4, 4, tw, Double(D.rows.count) * 12 + 5)
        for (i, r) in D.rows.enumerated() where r.count >= 3 {
            P.fillStyle(r[2]); P.fillText(r[0], 9, 7 + Double(i) * 12); P.fillStyle("#ece6f8"); P.fillText(r[1], 9 + lw, 7 + Double(i) * 12)
        }
        let sw = P.measureText(D.status)
        P.fillStyle(D.paused ? "rgba(120,30,20,.85)" : "rgba(8,6,14,.72)"); P.fillRect(SW - sw - 14, SH - 18, sw + 10, 14)
        P.fillStyle(D.paused ? "#ffd0b8" : "#cfc6e6"); P.fillText(D.status, SW - sw - 9, SH - 15)
        P.textBaseline = .alphabetic
    }

    // MARK: 복도(웹 drawUI GS.prologue 갈래)

    mutating func drawCorridorTop(_ k: Double) {
        let y = 8.0
        pxText(10, y, "B2 CORRIDOR", "#9fd6a0")
        P.fillStyle(HUDOverlay.uiInk); P.fillRect(9, y + 9, 122, 4); P.fillStyle("#9fd6a0"); P.fillRect(10, y + 10, Self.jsRound(120 * k), 2)
    }

    // MARK: 거리 연출(웹 drawUI GS.cine 갈래 — 다른 HUD 없이 레터박스 · 숫자/효과 · 하얀 빛 · 어둠)

    mutating func drawCine(_ s: HUDState, _ C: HUDModes.Cine) {
        let bh = 22.0
        P.fillStyle("#000"); P.fillRect(0, 0, VW, bh); P.fillRect(0, H - bh, VW, bh)
        drawDmg(s)
        if C.flash > 0 { P.fillStyle(RGBA(234 / 255, 1, 236 / 255, C.flash)); P.fillRect(0, 0, VW, H) }
        if C.fade > 0 { P.fillStyle(RGBA(0, 0, 0, C.fade)); P.fillRect(0, 0, VW, H) }
    }

    // MARK: 쇼 칸 전구(웹 drawShowLamps — 무대 좌표 변환 안에서)

    mutating func drawShowLamps(_ L: [[Double]], sparks: [HitFx] = []) {
        let y = 140.0 + 6
        for e in L where e.count >= 2 {
            let x = e[0], k = e[1]
            if k > 0.25 {
                P.fillRadial(x, y + 3, 0, k > 1.4 ? 22 : 12 * k, k > 1.4 ? "rgba(255,255,240,.9)" : "rgba(255,224,160,.55)", "rgba(255,200,120,0)")
            }
            P.fillStyle("#1a1610"); P.fillRect(x - 6, y - 2, 12, 3); P.fillStyle("#4a4232"); P.fillRect(x - 6, y - 2, 12, 1)
            P.fillStyle(k > 1.4 ? "#ffffff" : k > 0.6 ? "#ffe9b0" : k > 0.25 ? "#b08a50" : "#3a3024"); P.fillRect(x - 3, y + 1, 6, 3)
        }
        for p in sparks { drawOne(p) }
        P.globalAlpha = 1
    }
}

extension OverlayPainter {
    /// 원형 그라디언트로 원 채우기(웹 createRadialGradient(x,y,r0, x,y,r1) + fillRect 가 원을 다 품는 경우).
    /// r1 밖은 바깥 색(투명)이라 그리지 않는다. 부채꼴 삼각형 — 반지름 방향 선형 보간(정점 색)은 캔버스 원형 그라디언트와 같다(64조각).
    public mutating func fillRadial(_ cx: Double, _ cy: Double, _ r0: Double, _ r1: Double, _ c0s: String, _ c1s: String) {
        guard r1 > r0 else { return }
        let a = st.alpha, c0 = RGBA(css: c0s), c1 = RGBA(css: c1s), m = st.m, w = OverlayAtlas.whiteUV
        let n = 64
        func v(_ out: inout [Float], _ x: Double, _ y: Double, _ c: RGBA) {
            let p = m.apply(x, y)
            out += [Float(p.x), Float(p.y), Float(w.x), Float(w.y), Float(c.r), Float(c.g), Float(c.b), Float(c.a * a), 0]
        }
        list.push(.direct, clipped: st.clipped) { out in
            for i in 0..<n {
                let t0 = Double(i) / Double(n) * 2 * .pi, t1 = Double(i + 1) / Double(n) * 2 * .pi
                let (o0x, o0y, o1x, o1y) = (cx + cos(t0) * r1, cy + sin(t0) * r1, cx + cos(t1) * r1, cy + sin(t1) * r1)
                if r0 > 0 {
                    let (i0x, i0y, i1x, i1y) = (cx + cos(t0) * r0, cy + sin(t0) * r0, cx + cos(t1) * r0, cy + sin(t1) * r0)
                    v(&out, cx, cy, c0); v(&out, i0x, i0y, c0); v(&out, i1x, i1y, c0)
                    v(&out, i0x, i0y, c0); v(&out, o0x, o0y, c1); v(&out, o1x, o1y, c1)
                    v(&out, i0x, i0y, c0); v(&out, o1x, o1y, c1); v(&out, i1x, i1y, c0)
                } else {
                    v(&out, cx, cy, c0); v(&out, o0x, o0y, c1); v(&out, o1x, o1y, c1)
                }
            }
        }
    }
}
