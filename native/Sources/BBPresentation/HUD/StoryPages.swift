import Foundation

// 프롤로그 만화 페이지(웹 39-prologue.js storyArt · backView · storyPanel · drawStory + 47 drawCut 의 'story' 갈래).
// 원화 3칸(p1 열린 철문 · p2 비 오는 거리 · p3 지하철 입구)은 웹 pBuf 정수 연산 그대로(PixelArt) 구워 오버레이 아틀라스에 둔다(이미지 코덱 없음).
// 움직이는 덧그림(빛 먼지 · 비 · 가로등 · 초록 구형 등 빛) · 캡션 · 효과음 레터링은 그리기 목록. 칸 시각 P = [0, 2.1, 4.2], 6.6초부터 어두워짐.

extension HUDArt {
    /// 웹 storyArt(k) — 'p1' · 'p2' · 'p3'
    public func storyArt(_ k: String) -> OverlayAtlas.Entry? {
        atlas.entry("story|" + k) {
            let P = PixelArt(self, skin: "jw", shades: false)
            guard var b = StoryArt.make(k) else { return nil }
            P.shade(&b)
            return (b.W, b.H, P.rgba(b))
        }
    }
}

enum StoryArt {
    typealias S = PixelArt
    /// 웹 backView(b, x, y, s, coat, rim) — 뒷모습(정장 · 깃 · 넘긴 머리) + 한쪽 테두리 빛
    static func backView(_ b: inout PixelArt.Buf, _ x: Double, _ y: Double, _ s: Double, _ coat: String, _ rim: String?) {
        func P(_ pts: [(Double, Double)], _ c: String) { S.poly(&b, pts.map { (x + $0.0 * s, y + $0.1 * s) }, c) }
        P([(-7, -28), (7, -28), (8, -12), (5, -12), (4, 0), (1, 0), (0, -10), (-1, -10), (-2, 0), (-5, 0), (-6, -12), (-8, -12)], coat)
        P([(-3, -31), (3, -31), (2, -28), (-2, -28)], coat)
        S.ell(&b, x, y - 35 * s, 4.2 * s, 4.6 * s, "K"); S.ell(&b, x - 0.5 * s, y - 36.5 * s, 3.4 * s, 3.2 * s, "N")
        P([(-4, -29), (-2, -31), (0, -29), (2, -31), (4, -29), (0, -27)], "G")
        if let rim { for k in -28..<0 { S.set(&b, x + Double(S.jsRound((k > -12 ? 5 : 7.5) * s)), y + Double(k) * s, rim) } }
    }

    static func make(_ k: String) -> PixelArt.Buf? {
        var b: PixelArt.Buf
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: String) { S.rect(&b, Double(x), Double(y), w, h, c) }
        func set(_ x: Int, _ y: Int, _ c: String) { S.set(&b, Double(x), Double(y), c) }
        func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: String) { S.line(&b, Double(x0), Double(y0), Double(x1), Double(y1), c) }
        switch k {
        case "p1":
            b = S.buf(224, 118); rect(0, 0, 224, 118, "D")
            for y in 0..<86 { for x in 0..<224 where ((x + y) & 3) == 0 { set(x, y, "d") } }                         // 녹색 복도 벽 · 망점
            rect(0, 86, 224, 32, "i"); for x in stride(from: 0, to: 224, by: 2) { set(x, 86, "x") }; rect(0, 14, 224, 4, "G"); rect(0, 15, 224, 1, "g")
            rect(118, 20, 52, 70, "N"); rect(122, 24, 44, 66, "a")
            for y in 24..<90 { for x in 122..<166 where y > 60 && ((x * 3 + y) % 7) == 0 { set(x, y, "h") } }       // 열린 철문 · 문틈 빛
            S.poly(&b, [(166, 24), (196, 16), (196, 98), (166, 90)], "K"); S.poly(&b, [(168, 26), (194, 19), (194, 95), (168, 88)], "d")
            S.poly(&b, [(122, 90), (166, 90), (224, 118), (60, 118)], "W")
            for y in 90..<118 { for x in 40..<224 where S.get(b, x, y) == "W" && ((x + y) & 1) != 0 && y > 98 { set(x, y, "i") } }
            backView(&b, 144, 90, 1.5, "K", "a"); rect(152, 66, 2, 14, "C"); rect(149, 78, 8, 3, "W"); rect(155, 78, 2, 2, "g")
        case "p2":
            b = S.buf(222, 118); for y in 0..<118 { rect(0, y, 222, 1, y < 40 ? "v" : y < 80 ? "V" : "v") }
            for (bx, bw, bh, c) in [(0, 48, 92, "q"), (46, 40, 104, "Q"), (86, 54, 86, "q"), (140, 44, 108, "Q"), (184, 38, 96, "q")] {
                rect(bx, 118 - bh, bw, bh, c); rect(bx, 118 - bh, bw, 3, "i")                                    // 브라운스톤 · 창 · 비상계단
                var wy = 118 - bh + 8
                while wy < 100 {
                    var wx = bx + 5
                    while wx < bx + bw - 6 { let lit = ((wx * 7 + wy * 3) % 5) < 2; rect(wx, wy, 5, 7, lit ? "t" : "N"); if lit { set(wx + 1, wy + 1, "h") }; wx += 10 }
                    wy += 14
                }
                var fy = 118 - bh + 14
                while fy < 96 { line(bx + bw - 14, fy, bx + bw - 2, fy, "N"); line(bx + bw - 14, fy, bx + bw - 2, fy + 14, "N"); fy += 14 }
            }
            rect(0, 100, 222, 18, "N"); for x in stride(from: 0, to: 222, by: 3) where ((x * 5) % 11) < 4 { line(x, 101, x, 101 + ((x * 7) % 12), "u") }   // 젖은 아스팔트 · 비친 창빛
            for rx in [30, 104, 176] { for y in stride(from: 102, to: 116, by: 2) { set(rx + ((y * 3) % 4), y, "y") } }
            rect(196, 40, 2, 62, "N"); rect(190, 36, 14, 4, "N"); S.ell(&b, 197, 42, 4, 2, "t")                   // 가로등
            rect(28, 82, 14, 18, "g"); rect(26, 80, 18, 3, "G"); for y in stride(from: 84, to: 98, by: 3) { line(29, y, 40, y, "G") }
            rect(36, 68, 2, 13, "C"); rect(32, 66, 9, 3, "W")                                                       // 장도리가 꽂힌 쓰레기통
            backView(&b, 128, 102, 1.25, "K", "u")
            S.poly(&b, [(123, -30 * 1.25 + 102), (133, -30 * 1.25 + 102), (131, -27 * 1.25 + 102), (125, -27 * 1.25 + 102)], "n")   // 깃 세운 뒷모습
        case "p3":
            b = S.buf(452, 112); for y in 0..<112 { rect(0, y, 452, 1, y < 50 ? "v" : "V") }
            for (bx, bw, bh) in [(0, 70, 60), (60, 50, 80), (330, 60, 70), (390, 62, 90)] {
                rect(bx, 112 - bh, bw, bh, "N")
                var wy = 112 - bh + 6
                while wy < 96 { var wx = bx + 4; while wx < bx + bw - 5 { if ((wx + wy) % 4) == 0 { rect(wx, wy, 4, 5, "t") }; wx += 9 }; wy += 12 }
            }
            rect(0, 96, 452, 16, "G"); for x in stride(from: 0, to: 452, by: 16) { set(x, 96, "g") }               // 보도
            rect(166, 70, 120, 42, "K")
            for k2 in 0..<6 { let yy = 74 + k2 * 6, ins = k2 * 7; rect(170 + ins, yy, 112 - ins * 2, 5, k2 % 2 != 0 ? "g" : "W"); rect(170 + ins, yy + 5, 112 - ins * 2, 1, "G") }   // 타일 계단
            rect(206, 104, 40, 8, "t"); for x in stride(from: 208, to: 246, by: 2) { set(x, 103, "y") }
            for sx in [160, 286] { rect(sx, 58, 6, 42, "N"); for y in stride(from: 60, to: 98, by: 6) { line(sx, y, sx + 5, y + 4, "G") } }   // 철제 난간
            for gx in [148, 304] {
                rect(gx - 1, 36, 3, 62, "N"); S.ell(&b, Double(gx), 30, 7, 7, "e"); S.ell(&b, Double(gx - 2), 28, 2.5, 2.5, "h"); rect(gx - 3, 37, 7, 2, "N")   // 초록 구형 등
            }
            rect(176, 40, 100, 16, "K"); rect(178, 42, 96, 12, "N")                                                  // 간판(글자는 덧그림)
            backView(&b, 226, 94, 1.0, "K", "t")
        default: return nil
        }
        return b
    }
}

extension HUDOverlay.Builder {
    /// 웹 drawCut 의 'story' 갈래 — 좁은 화면(VW < W)이면 바탕을 칠하고 줄여서 가운데에
    mutating func drawStoryCut(_ t: Double) {
        let cs = VW / W
        P.save()
        if cs < 1 {
            P.fillStyle("#14121c"); P.fillRect(0, 0, VW, H)
            P.setTransform(UIS * cs, 0, 0, UIS * cs, 0, UIS * (H - H * cs) / 2)
        }
        drawStory(t)
        P.restore()
    }

    /// 웹 storyPanel(x, y, w, h, art, cap, a, dx, dy, over)
    mutating func storyPanel(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ artKey: String, _ cap: String?, _ a: Double, _ dx: Double, _ dy: Double,
                             _ over: (inout HUDOverlay.Builder) -> Void) {
        P.save(); P.globalAlpha = a; P.translate(dx, dy)
        P.beginPath(); P.moveTo(x, y); P.lineTo(x + w, y); P.lineTo(x + w, y + h); P.lineTo(x, y + h); P.closePath()
        P.save(); P.clip()
        P.imageSmoothingEnabled = false
        if let e = art.storyArt(artKey) { P.drawImage(e, x, y, w, h) }
        over(&self)
        P.restore()
        P.lineWidth = 4; P.strokeStyle(HUDOverlay.uiInk); P.strokeRect(x, y, w, h); P.lineWidth = 1.2; P.strokeStyle("#f1ece0"); P.strokeRect(x + 0.6, y + 0.6, w - 1.2, h - 1.2)
        if let cap {
            P.font = .galmuri9(10); let tw = P.measureText(cap)
            P.fillStyle(HUDOverlay.uiInk); P.fillRect(x + 6, y + 6, tw + 12, 16); P.fillStyle("#f6e27a"); P.fillRect(x + 4, y + 4, tw + 12, 16)
            P.strokeStyle(HUDOverlay.uiInk); P.lineWidth = 1.5; P.strokeRect(x + 4, y + 4, tw + 12, 16)
            P.fillStyle("#1a1206"); P.textBaseline = .middle; P.fillText(cap, x + 10, y + 12.5)
        }
        P.restore()
    }

    /// 웹 drawStory(C) — t = 컷 진행 초
    mutating func drawStory(_ t: Double) {
        let Pt = [0, 2.1, 4.2]
        func al(_ k: Int) -> Double { max(0, min(1, (t - Pt[k]) / 0.3)) }
        func sl(_ k: Int) -> Double { 1 - Self.easeO((t - Pt[k]) / 0.35) }
        func jm(_ a: Double, _ m: Double) -> Double { a.truncatingRemainder(dividingBy: m) }   // JS %
        P.fillStyle("#14121c"); P.fillRect(0, 0, W, H); P.fillStyle("rgba(255,255,255,.03)")   // 원고지 망점
        var yy = 0.0
        while yy < H { var xx = Double(Self.flo(yy / 4) % 2) * 2; while xx < W { P.fillRect(xx, yy, 1, 1); xx += 4 }; yy += 4 }
        if t >= Pt[0] {
            storyPanel(14, 16, 224, 118, "p1", "철문 너머는 바깥이었다.", al(0), -sl(0) * 240, 0) { B in
                for k in 0..<14 {   // 빛 속 먼지
                    let kk = Double(k), px = 150 + jm(kk * 29 + t * 12, 70), py = 40 + jm(kk * 17 + t * 9, 70)
                    B.P.fillStyle(RGBA(1, 1, 240 / 255, 0.35 + 0.3 * sin(t * 3 + kk))); B.P.fillRect(px, py, 1, 1)
                }
                if t > 0.5 { B.letter("끼이익", 200, 34, 10, "#cfe8d0", -0.1) }
            }
        }
        if t >= Pt[1] {
            storyPanel(244, 16, 222, 118, "p2", "비. 장도리는 쓰레기통에 버렸다.", al(1), sl(1) * 240, 0) { B in
                B.P.strokeStyle("rgba(170,200,255,.5)"); B.P.lineWidth = 0.8
                for k in 0..<46 {   // 비
                    let kk = Double(k), rx = 244 + jm(kk * 37 + t * 120, 230), ry = 16 + jm(kk * 53 + t * 240, 118)
                    B.P.beginPath(); B.P.moveTo(rx, ry); B.P.lineTo(rx - 3, ry + 9); B.P.stroke()
                }
                B.P.fillStyle(RGBA(1, 231 / 255, 168 / 255, 0.18 + 0.1 * sin(t * 9))); B.P.beginPath(); B.P.arc(441, 58, 14, 0, .pi * 2); B.P.fill()
                if t > Pt[1] + 0.4 { B.letter("클랭!", 300, 86, 13, "#ffd34a", -0.15) }
                B.letter("쏴아아", 420, 118, 9, "#a8c4ff", -0.05)
            }
        }
        if t >= Pt[2] {
            storyPanel(14, 140, 452, 114, "p3", "가장 가까운 지하철역 — 애틀랜틱 애비뉴.", al(2), 0, sl(2) * 120) { B in
                for gx in [162.0, 318] {
                    let a0 = 0.55 + 0.15 * sin(t * 4)
                    B.P.fillRadial(gx, 170, 1, 26, "rgba(110,232,122,\(a0))", "rgba(110,232,122,0)")
                }
                B.P.font = .galmuri11(12, bold: true); B.P.textAlign = .center; B.P.fillStyle("#ffffff"); B.P.fillText("SUBWAY", 240, 190)
                B.P.font = .galmuri9(10); B.P.fillStyle("#ff9a4a"); B.P.fillText("● D", 212, 206); B.P.fillStyle("#cfc6e6"); B.P.fillText("Atlantic Av", 258, 206); B.P.textAlign = .left
                if t > Pt[2] + 0.5 { B.letter("저벅", 300, 232, 10, "#e9e4f7", -0.08) }
            }
        }
        if t > 6.6 { P.fillStyle(RGBA(0, 0, 0, min(1, (t - 6.6) / 0.5))); P.fillRect(0, 0, W, H) }
    }
}
