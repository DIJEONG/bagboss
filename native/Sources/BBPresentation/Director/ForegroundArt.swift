import Foundation
import BBCore

// 무도장 깊이(docs/10 §10) — 카메라 앞 전경 층. 보이는 화면 크기 캔버스 하나(미리 곱한 RGBA)에 무대 픽셀로 직접 찍고,
// 렌더러가 통째로 흐린 뒤(초점보다 가까움) 24단 베이어로 자른다(픽셀 DOF). 시간은 게임 시간만(벽시계 없음).
//  · 눈 승강장: 행인(PasserArt)
//  · 건널목: 억새 덤불(아래 가장자리 · 바람에 흔들림 · 역광 금빛 테) · 가끔 큰 단풍잎 · 전차가 지날 때 건널목 경보기(가위표 + 붉은 등 둘이 번갈아)
//  · 무도장: 어두운 나무 기둥 가장자리 · 매달린 줄(아주 느린 흔들림) · 이벤트 때 위 가장자리 노렌이 흔들려 들어온다

struct FgCanvas {
    let w: Int, h: Int
    private(set) var px: [UInt8]   // 미리 곱한 RGBA(바로 텍스처로 — 변환 없음)
    private(set) var isEmpty = true
    init(w: Int, h: Int) { self.w = w; self.h = h; px = [UInt8](repeating: 0, count: w * h * 4) }

    /// 한 픽셀 덮기(알파 a — 색은 곱하기 전)
    mutating func put(_ x: Int, _ y: Int, _ c: (Double, Double, Double), _ a: Double) {
        guard x >= 0, y >= 0, x < w, y < h, a > 0 else { return }
        let i = (y * w + x) * 4, A = min(1, a), k = 1 - A
        px[i] = UInt8(min(255, c.0 * A * 255 + Double(px[i]) * k)); px[i + 1] = UInt8(min(255, c.1 * A * 255 + Double(px[i + 1]) * k))
        px[i + 2] = UInt8(min(255, c.2 * A * 255 + Double(px[i + 2]) * k)); px[i + 3] = UInt8(min(255, A * 255 + Double(px[i + 3]) * k))
        isEmpty = false
    }
    func alpha(_ x: Int, _ y: Int) -> Float { x >= 0 && y >= 0 && x < w && y < h ? Float(px[(y * w + x) * 4 + 3]) / 255 : 0 }
    /// 미리 곱한 RGBA 그림 덮기(왼쪽 위 ox · oy · 알파 배율)
    mutating func blit(_ src: [UInt8], sw: Int, sh: Int, ox: Int, oy: Int, alpha: Double) {
        let A = Float(alpha)
        for y in 0..<sh { let Y = oy + y; guard Y >= 0, Y < h else { continue }
            for x in 0..<sw { let X = ox + x; guard X >= 0, X < w else { continue }
                let s = (y * sw + x) * 4; guard src[s + 3] > 0 else { continue }
                let a = Float(src[s + 3]) / 255 * A, d = (Y * w + X) * 4, k = 1 - a
                for j in 0..<4 { px[d + j] = UInt8(min(255, Float(src[s + j]) * A + Float(px[d + j]) * k)) }
                isEmpty = false
            } }
    }
    var bytes: [UInt8] { px }
}

enum ForegroundArt {
    typealias C3 = (Double, Double, Double)
    static func mix(_ a: C3, _ b: C3, _ k: Double) -> C3 { let u = max(0, min(1, k)); return (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u) }
    static func h(_ i: Int, _ s: Int) -> Double { var g = SplitMix64(seed: UInt64(truncatingIfNeeded: i &* 7919 &+ s &* 104729 &+ 17)); return g.next() }

    // MARK: 해변

    /// 바닷풀 덤불(카메라 앞 모래 둔덕): 밑동(canvas x · 바닥 y) · 키 · 시간 · 씨앗 · 시간대(0 오후 · 1 노을 · 2 밤).
    ///   가늘고 긴 잎 12~18장이 밑에서 부채꼴로 · 끝이 바람 쪽으로 휜다 · 해 쪽 가장자리 밝은 테(오후 밀짚 · 노을 금빛 · 밤 푸른 달빛) · 밑동에 모래 둔덕
    static func duneGrass(_ C: inout FgCanvas, x bx: Double, y by: Double, height H: Double, t: Double, seed: Int, time: Int, alpha: Double) {
        guard H > 3, alpha > 0 else { return }
        let body: C3 = time == 0 ? (0.42, 0.44, 0.22) : time == 1 ? (0.16, 0.1, 0.12) : (0.05, 0.07, 0.09)
        let tip: C3 = time == 0 ? (0.72, 0.68, 0.42) : time == 1 ? (0.36, 0.2, 0.18) : (0.1, 0.13, 0.16)
        let rim: C3 = time == 0 ? (0.95, 0.88, 0.6) : time == 1 ? (1.0, 0.7, 0.36) : (0.55, 0.68, 0.95)
        let sand: C3 = time == 0 ? (0.78, 0.64, 0.44) : time == 1 ? (0.36, 0.22, 0.2) : (0.08, 0.09, 0.12)
        let gust = 0.6 + 0.4 * sin(t * 0.41 + Double(seed)), sun = 1.0
        // 밑동 둔덕(납작한 반원)
        for oy in 0..<5 { let w = Int(14 * sqrt(1 - Double(oy) / 5)); for ox in -w...w { C.put(Int(bx) + ox, Int(by) - oy, sand, alpha) } }
        let n = 12 + Int(h(seed, 3) * 7)
        for i in 0..<n {
            let side = (h(seed, i + 200) - 0.5) * 2, L = H * (0.55 + 0.45 * h(seed, i + 220))
            let ph = t * 1.6 + Double(seed) * 0.9 + Double(i) * 0.6, sw = (1.5 + L * 0.06) * gust * sin(ph) + L * 0.12
            let x0 = bx + side * 6
            var last = (Int.min, Int.min)
            let steps = Int(L * 1.4)
            for k in 0...steps {
                let u = Double(k) / Double(steps)
                let X = Int((x0 + side * L * 0.45 * u + sw * u * u).rounded()), Y = Int((by - 3 - L * u * (1 - 0.25 * u * abs(side))).rounded())
                if (X, Y) == last { continue }; last = (X, Y)
                C.put(X, Y, mix(body, tip, u), alpha)
                if u > 0.3 && C.alpha(X + Int(sun), Y) < 0.3 { C.put(X + Int(sun), Y, rim, alpha * 0.55 * u) }
            }
        }
    }

    // MARK: 건널목

    /// 억새 덤불: 밑동(canvas x · 바닥 y) · 키 · 시간 · 씨앗 · 해 쪽(+1 오른쪽).
    ///   밑에서 바깥으로 활처럼 휘는 잎 10여 장(어둡게) + 꼿꼿한 꽃대 3~5(키 H) · 꽃대 끝 이삭은 바람 아래쪽으로 늘어지는 은빛 털(역광이면 금빛)
    static func silverGrass(_ C: inout FgCanvas, x bx: Double, y by: Double, height H: Double, t: Double, seed: Int, sun: Double, alpha: Double) {
        guard H > 3, alpha > 0 else { return }
        let gust = 0.6 + 0.4 * sin(t * 0.37 + Double(seed))
        let leafC: C3 = (0.1, 0.085, 0.055), stemC: C3 = (0.16, 0.12, 0.07), plumeC: C3 = (0.7, 0.64, 0.54), gold: C3 = (0.99, 0.77, 0.42)
        func line(_ pts: [(Double, Double)], _ c: C3, _ a: Double, rim: Bool, thick: Int) {
            var last = (Int.min, Int.min)
            for (k, p) in pts.enumerated() { let X = Int(p.0.rounded()), Y = Int(p.1.rounded()); if (X, Y) == last { continue }; last = (X, Y)
                let u = Double(k) / Double(max(1, pts.count - 1))
                C.put(X, Y, c, a); if thick > 1 && u < 0.35 { C.put(X + 1, Y, c, a) }
                if rim && u > 0.25 && C.alpha(X + Int(sun), Y) < 0.3 { C.put(X + Int(sun), Y, gold, a * 0.5 * u) } }
        }
        // 잎: 밑동에서 양쪽으로 활처럼(끝이 처진다)
        let nl = 9 + Int(h(seed, 1) * 5)
        for i in 0..<nl {
            let side: Double = i % 2 == 0 ? -1 : 1, L = H * (0.4 + 0.3 * h(seed, i + 40)), spread = side * (0.35 + 0.6 * h(seed, i + 60))
            let ph = t * 1.5 + Double(seed) + Double(i) * 0.7, sw = (2 + H * 0.04) * gust * sin(ph)
            var pts: [(Double, Double)] = []
            let x0 = bx + (h(seed, i + 80) - 0.5) * 6
            for k in 0...Int(L * 1.6) { let u = Double(k) / (L * 1.6)
                pts.append((x0 + spread * L * u + sw * u * u, by - L * u * (1 - 0.55 * u * abs(spread)))) }
            line(pts, leafC, alpha, rim: true, thick: 2)
        }
        // 꽃대 + 이삭
        let ns = 3 + Int(h(seed, 2) * 3)
        for i in 0..<ns {
            let L = H * (0.75 + 0.25 * h(seed, i + 100)), lean = (h(seed, i + 120) - 0.5) * 0.35
            let ph = t * 1.3 + Double(seed) * 1.7 + Double(i) * 0.5, sw = (4 + H * 0.08) * gust * sin(ph)
            let x0 = bx + (h(seed, i + 140) - 0.5) * 8
            func at(_ u: Double) -> (Double, Double) { (x0 + lean * L * u + sw * u * u, by - L * u) }
            line(stride(from: 0.0, through: 0.72, by: 1 / (L * 1.6)).map(at), stemC, alpha, rim: true, thick: 1)
            // 이삭: 꽃대 끝 28% — 축 둘레로 바람 아래쪽(흔들림 쪽)으로 늘어지는 털 가닥
            let wind: Double = sw >= 0 ? 1 : -1, lit = wind == sun ? 1.0 : 0.6
            for k in 0..<Int(L * 0.28 * 1.4) {
                let u = 0.72 + Double(k) / (L * 1.4), (px, py) = at(u)
                let c = mix(plumeC, gold, 0.35 + 0.5 * lit * (u - 0.7) / 0.3)
                C.put(Int(px.rounded()), Int(py.rounded()), c, alpha)
                if k % 2 == 0 { for f in 1...(2 + Int(h(seed &+ k, i + 160) * 4)) {   // 털 가닥(아래 바깥으로)
                    let fx = px + wind * Double(f) * 0.9, fy = py + Double(f) * 0.7
                    C.put(Int(fx.rounded()), Int(fy.rounded()), mix(c, gold, 0.12 * Double(f)), alpha * (0.95 - 0.12 * Double(f))) } }
            }
        }
    }

    /// 큰 단풍잎(다섯 갈래 별 · 잎자루) — 가운데 cx · cy · 반지름 r · 각 a · 역광으로 비치는 붉은 주황
    static func mapleLeaf(_ C: inout FgCanvas, cx: Double, cy: Double, r: Double, angle: Double, hue: Double, alpha: Double) {
        guard alpha > 0 else { return }
        var pts: [(Double, Double)] = []
        for k in 0..<10 { let a = angle + Double(k) * .pi / 5 - .pi / 2, rr = k % 2 == 0 ? r : r * (k == 5 ? 0.3 : 0.48)
            pts.append((cx + cos(a) * rr, cy + sin(a) * rr)) }
        let base: C3 = mix((0.78, 0.18, 0.06), (0.92, 0.5, 0.1), hue), lit: C3 = mix((1, 0.42, 0.16), (1, 0.75, 0.3), hue)
        for y in Int(cy - r - 1)...Int(cy + r + 1) { for x in Int(cx - r - 1)...Int(cx + r + 1) {
            let X = Double(x) + 0.5, Y = Double(y) + 0.5
            var inside = false
            for i in 0..<10 { let a = pts[i], b = pts[(i + 1) % 10]
                if (a.1 > Y) != (b.1 > Y), X < a.0 + (Y - a.1) / (b.1 - a.1) * (b.0 - a.0) { inside.toggle() } }
            if inside { let d = hypot(X - cx, Y - cy) / r; C.put(x, y, mix(lit, base, d), alpha) }
        } }
        let sa = angle + .pi / 2   // 잎자루
        for k in 0..<Int(r * 0.7) { C.put(Int((cx + cos(sa) * (r * 0.3 + Double(k))).rounded()), Int((cy + sin(sa) * (r * 0.3 + Double(k))).rounded()), (0.35, 0.12, 0.05), alpha) }
    }

    /// 건널목 경보기(카메라 바로 앞 — 위가 화면 밖으로 잘린다): 노랑 · 검정 줄무늬 기둥 · 가위표 · 붉은 등 둘(lit: 0 왼쪽 · 1 오른쪽) · 종
    static func crossingSignal(_ C: inout FgCanvas, x px: Double, lit: Int, sun: Double, alpha: Double) {
        guard alpha > 0 else { return }
        let yel: C3 = (0.5, 0.4, 0.07), blk: C3 = (0.035, 0.035, 0.045), gold: C3 = (0.95, 0.7, 0.35)
        let X0 = Int(px.rounded())
        // 기둥(폭 7 · 비스듬한 줄무늬 — 역광이라 어둡게)
        for y in 70..<C.h { for dx in -3...3 { let st = ((y + dx * 1) / 6) % 2 == 0; C.put(X0 + dx, y, st ? yel : blk, alpha) }
            C.put(X0 + 3 * Int(sun) + Int(sun), y, gold, alpha * 0.45) }
        // 가위표 두 판(길이 60 · 폭 7 · ±32°)
        for sgn in [-1.0, 1.0] {
            let a = sgn * 0.56, ca = cos(a), sa = sin(a)
            for l in -30...30 { for w in -3...3 {
                let x = px + Double(l) * ca - Double(w) * sa, y = 56 + Double(l) * sa + Double(w) * ca
                C.put(Int(x.rounded()), Int(y.rounded()), (abs(l) / 7) % 2 == 0 ? yel : blk, alpha)
            } }
        }
        // 종(가위표 위) · 등 팔
        for y in 30..<40 { for x in -5...5 where Double(x * x) / 25 + Double((y - 40) * (y - 40)) / 100 <= 1 { C.put(X0 + x, y, blk, alpha) } }
        for x in -19...19 { for y in 92...94 { C.put(X0 + x, y, blk, alpha) } }
        // 등 둘: 갓(위 반원) · 몸 · 켜진 등은 밝은 붉은 원 + 빛무리
        for (k, ox) in [-14, 14].enumerated() {
            let cx = X0 + ox, cy = 102
            for y in -9...7 { for x in -8...8 {
                let d2 = Double(x * x + y * y)
                if d2 <= 64, y <= 0 || d2 <= 42 { C.put(cx + x, cy + y, blk, alpha) }
            } }
            if k == lit {
                for y in -11...11 { for x in -11...11 { let d = hypot(Double(x), Double(y))
                    if d <= 4.6 { C.put(cx + x, cy + y, d < 2.5 ? (1, 0.55, 0.42) : (1, 0.16, 0.1), alpha) }
                    else if d <= 11 { C.put(cx + x, cy + y, (1, 0.1, 0.06), alpha * 0.32 * (1 - (d - 4.6) / 6.4)) } } }
            } else {
                for y in -4...4 { for x in -4...4 where x * x + y * y <= 20 { C.put(cx + x, cy + y, (0.22, 0.03, 0.03), alpha) } }
            }
        }
    }

    // MARK: 무도장

    /// 어두운 나무 기둥 가장자리(화면 가장자리 side 쪽 · 보이는 폭 w) · 결 · 등롱 쪽 따뜻한 테
    static func pillar(_ C: inout FgCanvas, side: Double, width w: Int, warmSide: Double, alpha: Double) {
        guard w > 0, alpha > 0 else { return }
        let x0 = side > 0 ? C.w - w : 0
        for y in 0..<C.h { for i in 0..<w {
            let x = x0 + i, grain = (h(x, 3) < 0.25 ? 0.012 : 0) + 0.008 * sin(Double(y) * 0.07 + Double(x) * 1.3)
            var c: C3 = (0.075 + grain, 0.042 + grain * 0.6, 0.025)
            let inner = side > 0 ? i == 0 : i == w - 1   // 화면 안쪽 모서리
            if inner && warmSide == -side { c = mix(c, (0.55, 0.3, 0.12), 0.55) } else if inner { c = mix(c, (0.25, 0.3, 0.42), 0.35) }
            C.put(x, y, c, alpha)
        } }
    }

    /// 매달린 줄(땋은 무늬 · 끝 술) — 위 끝 x · 길이 · 흔들림 각
    static func rope(_ C: inout FgCanvas, x: Double, length L: Double, swing: Double, alpha: Double) {
        guard alpha > 0 else { return }
        let a: C3 = (0.3, 0.2, 0.1), b: C3 = (0.17, 0.1, 0.05)
        for y in 0..<Int(L) { let u = Double(y) / L, cx = x + sin(swing) * Double(y)
            for dx in -1...1 { let tw = ((y + dx * 2) / 2) % 2 == 0; C.put(Int(cx.rounded()) + dx, y, tw ? a : b, alpha) } }
        let ex = x + sin(swing) * L
        for y in 0..<10 { for dx in -3...3 where (dx + y) % 2 == 0 || abs(dx) < 2 { C.put(Int(ex.rounded()) + dx + (y > 6 ? (dx > 0 ? 1 : -1) : 0), Int(L) + y, b, alpha * (1 - Double(y) / 14)) } }
    }

    /// 노렌(위 가장자리): 세 폭(폭 20 · 사이 1) · 아래로 내려온 길이 drop · 흔들림 sw(아래 끝 가로 밀림) · 가운데 폭 흰 문장
    static func noren(_ C: inout FgCanvas, x x0: Double, drop: Double, sway sw: Double, t: Double, alpha: Double) {
        guard drop > 0.5, alpha > 0 else { return }
        let cloth: C3 = (0.06, 0.08, 0.19), fold: C3 = (0.04, 0.05, 0.13), crest: C3 = (0.72, 0.7, 0.64)
        for p in 0..<3 {
            let px0 = x0 + Double(p) * 21, ph = Double(p) * 0.9
            for y in 0..<Int(drop) {
                let u = Double(y) / max(1, drop), off = (sw * sin(t * 2.2 + ph) + sw * 0.6) * pow(u, 1.5)
                for i in 0..<20 {
                    let X = Int((px0 + Double(i) + off).rounded())
                    var c = i % 7 == 3 ? fold : cloth
                    if p == 1 { let dx = Double(i) - 9.5, dy = Double(y) - (drop - 14); let d = hypot(dx, dy); if d > 3.5 && d < 5.5 { c = crest } }
                    C.put(X, y, c, alpha)
                }
            }
        }
        for x in Int(x0 - 2)..<Int(x0 + 65) { C.put(x, 0, (0.2, 0.13, 0.07), alpha) }   // 위 막대
    }
}
