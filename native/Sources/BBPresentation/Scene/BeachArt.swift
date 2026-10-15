import Foundation
import BBCore
import BBContent

// 해변 도장(docs/12) 정지 그림 — 코니아일랜드 해변(D · F · N · Q 종점 Stillwell Av 앞). 무도장 배경 'beach'(오후) · 'beach_dusk'(노을) · 'beach_night'(밤).
// 눈 승강장(SnowArt)과 같은 길: 스프라이트가 아니라 무대 픽셀(G-버퍼 3D 층 1px 쿼드) → 무대 조명 · 팔레트 6단 램프 · 베이어 디더를 그대로 받는다.
//  · 층(뒤 → 앞) · 시차 p:
//      하늘(해 · 달 · 구름 · 별) 0 · 먼 해안(서쪽 곶 — 파라슈트 점프 · 원더휠 · 사이클론 · 베라자노 다리 · 수평선 배) 0.06
//      [바다 — 움직이는 층: BeachFx.seaMesh(줄마다 시차 0.04 → 0.9 · 물결 · 반짝임 길 · 부서지는 파도)]
//      모래사장 1(파라솔 · 감시탑 · 수건 · 아이스박스 · 모래성 · 해초 줄 · 조개) — [젖은 모래 · 밀려오는 물 · 자국: BeachFx]
//  · 시간대마다 하늘 · 먼 해안 · 그림자 방향 · 밤 불빛이 다르다(층은 시간대별로 한 번 그려 둔다)
//  · 파라솔 기둥 · 감시탑 다리 = 무도장 기둥 자리(DJ_POLES 96 · 384) → 기둥 회전차기가 그대로 쓰인다

/// 해변 시간대(무도장 배경 이름에서)
public enum BeachTime: Int, Sendable, CaseIterable {
    case day, dusk, night
    /// 무도장 배경 이름 → 시간대(해변이 아니면 nil)
    public static func of(_ bg: String?) -> BeachTime? {
        switch bg {
        case "beach": return .day
        case "beach_dusk": return .dusk
        case "beach_night": return .night
        default: return nil
        }
    }
    /// 바다 · 반짝임 재질
    var seaMat: Int { self == .dusk ? NativePalette.SEAD : NativePalette.SEA }
}

/// 해변 기준선(장면 픽셀)
public enum BeachGeo {
    public static let W = 480, H = 270
    /// 수평선 · 물가(파도가 빠졌을 때 물이 끝나는 줄 — 그 아래는 모래)
    public static let horizon = 132, shore = 198
    /// 물가선(열마다 — 모래가 시작하는 y · 파도가 빠진 물 끝): 직선이 아니라 파도가 깎은 해변 첨각(둥근 만 · 바다 쪽 뿔이 30~40px 마다)과
    /// 느린 굴곡이 겹친다(195~202). 바다 · 모래 · 밀려오는 물 · 젖은 띠가 모두 이 줄을 따른다
    public static let shoreLine: [Int] = (0..<W).map { x in
        let X = Double(x)
        let wander = 2.6 * (SnowPaint.n1(X / 61, 231) - 0.5) * 2 + 0.8 * (SnowPaint.n1(X / 17, 232) - 0.5) * 2
        let period = 34 + 8 * SnowPaint.n1(X / 90, 233), cusp = 2.6 * pow(abs(sin(.pi * X / period)), 0.7) - 1.6   // 뿔(0 근처)은 바다 쪽 · 만은 모래 쪽
        return max(195, min(202, shore + Int((wander + cusp).rounded())))
    }
    /// 등대 등실(먼 해안 층 x · y — 장면 x = x + 0.94·camX)
    static let lighthouse = (x: 118, y: horizon - 13)
    /// 방파제(돌 그로인): 물가에서 바다로 뻗는다 — 기준 카메라(camX 185)에서 화면 오른쪽(장면 x 330~346), 멀어질수록 화면 가운데 쪽으로
    static let jetty = (x0: 344.0, x1: 336.0, uTip: 0.76, refCam: 185.0)
    /// 파라솔 기둥 · 감시탑 다리(= DJ_POLES)
    public static let umbrellaX = 96.0, towerX = 384.0
    /// 해(달) 자리(하늘 층 — 화면에 붙어 있다: 장면 x = 이 값 + camX)
    static func sun(_ t: BeachTime) -> (x: Double, y: Double, r: Double) {
        switch t {
        case .day: return (150, 50, 6)
        case .dusk: return (128, 121, 11)
        case .night: return (140, 44, 7)
        }
    }
    /// 하늘 · 배경 깊이(GL z) — 인물(≈0.16)보다 늘 뒤
    static let zBack = 0.985
}

/// 모래 바닥 값(정지 그림 · 자국 · 젖은 모래가 같은 값을 쓴다 — 이음매 없이)
///   단 단위 s(SAND 램프 0..5) → 발광 = (s + 0.5)/6 × 시간대 배율 − 기준. 톤 FT 로 해 · 하늘 · 장면 빛을 받는다
struct BeachFloor: @unchecked Sendable {
    static let table = BeachFloor()
    static let FT: Float = 0.32
    /// 바닥 층 깊이(0.2 — 긴 그림자 · 땅 반짝이 갈래(셰이더 0.18~0.36)를 받는다 · 소품은 0.1 이라 그림자가 얹히지 않는다)
    static let D: Float = 0.2
    static let y0 = BeachGeo.shore - 4, rows = BeachGeo.H - y0
    private let s: [Float]

    init() {
        let W = BeachGeo.W
        typealias P = SnowPaint
        var t = [Float](repeating: .nan, count: W * Self.rows)
        func ss(_ a: Double, _ b: Double, _ x: Double) -> Double { let u = max(0, min(1, (x - a) / (b - a))); return u * u * (3 - 2 * u) }
        // 바람 물결(마른 모래 — 가로로 길고 잘게 물결치는 줄 · 마디마다 끊긴다): y 기준 · 진폭 · 씨앗
        let ripples: [(Double, Double, UInt64)] = [(236, 0.8, 91), (241, 1.0, 92), (246, 0.9, 93), (251, 1.1, 94), (257, 1.0, 95), (263, 1.2, 96)]
        for x in 0..<W {
            let X = Double(x)
            for y in Self.y0..<BeachGeo.H {
                let Y = Double(y), u = (Y - Double(BeachGeo.shore)) / Double(BeachGeo.H - BeachGeo.shore)
                // 바탕: 물가 쪽(뒤)은 물기가 남아 조금 짙고 → 앞으로 밝은 마른 모래 → 맨 앞은 다시 살짝 그늘(카메라 쪽 둔덕)
                var v = 2.4 + 1.3 * ss(0.02, 0.45, u) - 0.35 * ss(0.85, 1.0, u)
                // 넓은 얼룩(아주 느린 2차원 잡음) + 잔 얼룩
                v += 0.5 * (P.n2(X / 34, Y / 7, 101) - 0.5) + 0.22 * (P.n2(X / 9, Y / 3, 102) - 0.5)
                // 다져진 길(인물이 가장 많이 걷는 줄 — 살짝 짙고 매끈)
                let path = ss(212, 216, Y) * (1 - ss(229, 234, Y))
                v -= 0.35 * path
                v = (v * 8).rounded() / 8
                // 바람 물결(길 밖): 윗줄 한 단 밝게 · 아랫줄 한 단 그늘
                if path < 0.5 {
                    for (ry, amp, sd) in ripples {
                        let on = P.n1(X / 19 + Double(sd) * 2.7, sd) - 0.38
                        guard on > 0 else { continue }
                        let yy = (ry + amp * sin(X * 0.09 + Double(sd)) + 0.5 * sin(X * 0.23 + Double(sd) * 2)).rounded()
                        if abs(Y - yy) < 0.5 { v += 0.75 } else if abs(Y - yy - 1) < 0.5 { v -= on > 0.15 ? 0.75 : 0.4 }
                    }
                }
                // 잔모래 알갱이(낱 픽셀 반 단 — 손으로 찍은 질감)
                let g = P.h(x, y, 103)
                if g < 0.035 { v += 0.5 } else if g > 0.975 { v -= 0.5 }
                t[(y - Self.y0) * W + x] = Float(v)
            }
        }
        s = t
    }

    @inline(__always) func step(_ x: Int, _ y: Int) -> Float? {
        guard x >= 0, x < BeachGeo.W, y >= Self.y0, y < BeachGeo.H else { return nil }
        let v = s[(y - Self.y0) * BeachGeo.W + x]
        return v.isNaN ? nil : v
    }
    /// 시간대 발광 배율 · 기준(밤엔 자국 무늬만 남게 낮춘다)
    static func emitK(_ t: BeachTime) -> (k: Float, base: Float) {
        switch t {
        case .day: return (0.84, 0.3)
        case .dusk: return (0.78, 0.3)
        case .night: return (0.32, 0.08)
        }
    }
    @inline(__always) static func emit(_ step: Float, _ t: BeachTime) -> Float { let e = emitK(t); return max(0, (step + 0.5) / 6 * e.k - e.base) }
    /// 바닥 픽셀(마른 모래)
    func px(_ x: Int, _ y: Int, _ t: BeachTime) -> SnowPx? {
        guard let v = step(x, y) else { return nil }
        return SnowPx(mat: UInt8(NativePalette.SAND), v: Self.emit(v, t), tone: Self.FT, d: Self.D, ny: 0.75)
    }
}

/// 해변 그림 전부(시간대마다 처음 한 번 — 앱은 뒤 스레드에서 미리 데운다)
public final class BeachArt: @unchecked Sendable {
    public static let shared = BeachArt()
    private let lock = NSLock()
    private var built: [BeachTime: [SnowLayer]] = [:]
    private var lastKey: [Int] = []
    private var lastMesh: [Float] = []

    public func warm(_ t: BeachTime = .day) { DispatchQueue.global(qos: .utility).async { _ = self.layers(t) } }

    func layers(_ t: BeachTime) -> [SnowLayer] {
        lock.lock(); defer { lock.unlock() }
        if let b = built[t] { return b }
        let b = BeachPaint.paint(t)
        built[t] = b
        return b
    }

    /// 이번 카메라의 배경 정점 전부(시간대 · 층 오프셋이 같으면 지난 것 그대로)
    public func mesh(_ t: BeachTime, camX: Double) -> [Float] {
        let L = layers(t)
        let key = [t.rawValue] + L.map { Int(((1 - $0.p) * camX).rounded()) }
        lock.lock(); defer { lock.unlock() }
        if key == lastKey { return lastMesh }
        var f: [Float] = []
        for l in L { f += l.mesh(camX: camX) }
        lastKey = key; lastMesh = f
        return f
    }
    public func rectCount(_ t: BeachTime) -> Int { layers(t).reduce(0) { $0 + $1.rects.count } }
}

// MARK: - 그리기

enum BeachPaint {
    typealias M = NativePalette
    typealias P = SnowPaint
    static let INK: UInt8 = 1, RED: UInt8 = 12, STEEL: UInt8 = 8
    static let SKYA = UInt8(M.SKYA), SKYD = UInt8(M.SKYD), NITE = UInt8(M.NITE), HAZE = UInt8(M.HAZE), FOAM = UInt8(M.FOAM), SUN = UInt8(M.SUN)
    static let SAND = UInt8(M.SAND), WOOD = UInt8(M.WOODP), DUNE = UInt8(M.DUNE), SOD = UInt8(M.SODIUM), LINE7 = UInt8(M.LINE7), TEAL = UInt8(M.TEAL), SNOW = UInt8(M.SNOW)
    static func L(_ s: Double) -> Float { P.L(s) }

    static func paint(_ t: BeachTime) -> [SnowLayer] {
        [SnowLayer(p: 0, z: 0.996, canvas: sky(t)), SnowLayer(p: 0.06, z: 0.995, canvas: far(t)),
         SnowLayer(p: 1, z: BeachGeo.zBack + 0.0005, canvas: sand(t))]
    }

    // MARK: 하늘

    /// 오후: 짙은 하늘색 → 수평선 옅은 빛 · 뭉게구름(아랫면 푸른 그늘) · 작은 흰 해
    /// 노을: 보라 → 자홍 → 주황 → 해 둘레 금빛 · 길게 늘어진 구름 띠(아랫면이 해빛에 달아오른다) · 큰 해가 수평선에 걸린다
    /// 밤: 짙은 남색 · 별 · 달(이지러진 얼룩) · 달빛 받는 얇은 구름 · 수평선 쪽 도시 빛무리(서쪽 곶 너머)
    static func sky(_ t: BeachTime) -> SnowCanvas {
        let H = BeachGeo.horizon + 2
        var C = SnowCanvas(w: BeachGeo.W, h: H)
        let sun = BeachGeo.sun(t)
        for y in 0..<H {
            let Y = Double(y), u = Y / Double(BeachGeo.horizon)
            for x in 0..<BeachGeo.W {
                let X = Double(x)
                let dx = X - sun.x, dy = Y - sun.y, dist = (dx * dx + dy * dy * 2.2).squareRoot()
                var v: Double, mat: UInt8
                switch t {
                case .day:
                    mat = SKYA
                    v = 0.18 + 0.5 * pow(u, 1.5) + 0.12 * exp(-dist / 40)
                case .dusk:
                    mat = SKYD
                    v = 0.1 + 0.6 * pow(u, 1.25) + 0.24 * exp(-dist / 70) + 0.12 * exp(-pow((Y - Double(BeachGeo.horizon) + 4) / 9, 2)) * exp(-abs(dx) / 160)
                case .night:
                    mat = NITE
                    v = 0.08 + 0.34 * pow(u, 1.8) + 0.12 * exp(-dist / 34)
                    if u > 0.82 { v += 0.06 * (u - 0.82) / 0.18 * exp(-X / 220) }   // 서쪽 곶 너머 도시 빛무리
                }
                v = (v * 24).rounded() / 24
                C[x, y] = SnowPx(mat: mat, v: Float(v), d: 0.99)
            }
        }
        // 구름
        switch t {
        case .day: cumulus(&C)
        case .dusk: duskStreaks(&C, sunX: sun.x)
        case .night: stars(&C); nightClouds(&C)
        }
        // 해 · 달 원판
        let r = sun.r
        for oy in -Int(r + 1)...Int(r + 1) { for ox in -Int(r + 1)...Int(r + 1) {
            let d = (Double(ox * ox + oy * oy)).squareRoot()
            guard d <= r + 0.3 else { continue }
            let x = Int(sun.x) + ox, y = Int(sun.y) + oy
            guard y < BeachGeo.horizon + 1 else { continue }   // 노을 해는 수평선에 걸린다(아래는 바다가 덮는다)
            switch t {
            case .day: C[x, y] = SnowPx(mat: SUN, v: d > r - 1 ? 0.88 : 0.97, d: 0.99)
            case .dusk:   // 아래로 갈수록 붉고 납작한 띠가 가로지른다(대기 굴절)
                let band = (y - Int(sun.y)) > 3 && (y - Int(sun.y)) % 3 == 0
                C[x, y] = SnowPx(mat: SUN, v: band ? 0.42 : d > r - 1 ? 0.6 : 0.76 - 0.12 * Float(max(0, oy)) / Float(r), d: 0.99)
            case .night:   // 달: 크림빛 · 바다(이지러진 얼룩) 셋 · 오른쪽 아래 가장자리 그늘
                let mare = P.n2(Double(x) / 3.2, Double(y) / 3.2, 111) > 0.62
                C[x, y] = SnowPx(mat: SNOW, v: d > r - 1 && ox + oy > 0 ? 0.78 : mare ? 0.84 : 0.97, d: 0.99)
            }
        } }
        return C
    }

    /// 오후 뭉게구름: 몇 덩이(바닥이 평평 · 위가 둥근) — 윗면 흰 빛 · 아래 푸른 그늘 · 가장자리 성긴 디더
    static func cumulus(_ C: inout SnowCanvas) {
        let clouds: [(Double, Double, Double, Double)] = [(34, 64, 30, 11), (118, 34, 38, 13), (186, 84, 26, 8), (300, 50, 40, 12), (420, 90, 34, 9)]
        for (i, c) in clouds.enumerated() {
            let (cx, base, w, hgt) = c
            for x in Int(cx - w - 4)...Int(cx + w + 4) {
                let X = Double(x), e = 1 - pow((X - cx) / w, 2)
                guard e > 0 else { continue }
                let top = base - hgt * (pow(e, 0.6) * (0.65 + 0.35 * P.n1(X / 9 + Double(i) * 5, 120 + UInt64(i))))
                for y in Int(top)...Int(base) {
                    let Y = Double(y), k = (Y - top) / max(1, base - top)
                    if y == Int(top) && P.h(x, y, 121) < 0.5 { continue }
                    let v: Float = k < 0.25 ? 0.95 : k < 0.6 ? 0.85 : 0.68
                    C[x, y] = SnowPx(mat: FOAM, v: v, d: 0.985)
                }
            }
        }
    }
    /// 노을 구름 띠: 가로로 길고 얇다 — 몸은 보랏빛 그늘(SKYD 낮은 단) · 아랫면은 해빛에 달아올라 주황 · 금빛(해 가까울수록)
    static func duskStreaks(_ C: inout SnowCanvas, sunX: Double) {
        let bands: [(Double, Double, Double, Double, UInt64)] = [(10, 150, 30, 3, 131), (90, 260, 50, 4, 132), (0, 110, 74, 2, 133), (150, 300, 90, 3, 134), (40, 200, 103, 2, 135), (170, 330, 112, 2, 136)]
        for (x0, x1, y0, th, sd) in bands {
            for x in Int(x0)..<Int(x1) {
                let X = Double(x), e = min(1, min(X - x0, x1 - X) / 24)
                let thick = th * e * (0.5 + P.n1(X / 14, sd)), yc = y0 + 2 * sin(X / 37 + Double(sd))
                guard thick > 0.6 else { continue }
                let near = exp(-abs(X - sunX) / 120)
                for y in Int(yc - thick)...Int(yc + thick * 0.5) {
                    let under = Double(y) >= yc + thick * 0.5 - 1
                    C[x, y] = SnowPx(mat: under ? SUN : SKYD, v: under ? Float(0.45 + 0.35 * near) : Float(0.22 + 0.1 * near), d: 0.985)
                }
            }
        }
    }
    /// 밤 별: 낱 픽셀(밝기 셋) — 수평선 가까이는 빛무리에 묻혀 드물다
    static func stars(_ C: inout SnowCanvas) {
        var g = SplitMix64(seed: 0x57A2)
        for _ in 0..<110 {
            let x = Int(g.next() * Double(BeachGeo.W)), y = Int(pow(g.next(), 1.4) * Double(BeachGeo.horizon - 18))
            let b = g.next()
            C[x, y] = SnowPx(mat: SNOW, v: b > 0.85 ? 0.95 : b > 0.5 ? 0.7 : 0.5, d: 0.99)
        }
    }
    /// 밤 구름: 얇은 띠 — 달 쪽 가장자리만 달빛
    static func nightClouds(_ C: inout SnowCanvas) {
        for (x0, x1, y0, sd) in [(150.0, 260.0, 58.0, 141 as UInt64), (10, 100, 96, 142), (60, 170, 78, 143)] {
            for x in Int(x0)..<Int(x1) {
                let X = Double(x), th = 2.5 * min(1, min(X - x0, x1 - X) / 20) * (0.4 + P.n1(X / 11, sd))
                guard th > 0.7 else { continue }
                for y in Int(y0 - th)...Int(y0 + th * 0.4) { C[x, y] = SnowPx(mat: HAZE, v: y == Int(y0 - th) ? 0.42 : 0.24, d: 0.985) }
            }
        }
    }

    // MARK: 먼 해안(서쪽 곶) — 파라슈트 점프 · 원더휠 · 사이클론 · 베라자노 다리 · 배

    static func far(_ t: BeachTime) -> SnowCanvas {
        var C = SnowCanvas(w: BeachGeo.W, h: BeachGeo.horizon + 4)
        let hz = BeachGeo.horizon
        // 실루엣 색: 오후 = 옅은 안개 파랑 · 노을 = 짙은 보랏빛(역광) · 밤 = 거의 검정 + 불빛
        let sil: SnowPx, silD: SnowPx
        switch t {
        case .day: sil = SnowPx(mat: HAZE, v: L(3.2), d: 0.96); silD = SnowPx(mat: HAZE, v: L(2.7), d: 0.96)
        case .dusk: sil = SnowPx(mat: SKYD, v: L(0.9), d: 0.96); silD = SnowPx(mat: SKYD, v: L(0.5), d: 0.96)
        case .night: sil = SnowPx(mat: NITE, v: L(1.2), d: 0.96); silD = SnowPx(mat: NITE, v: L(0.6), d: 0.96)
        }
        func lamp(_ x: Int, _ y: Int, _ m: UInt8 = SOD, _ v: Double = 3.6) { if t != .day { C[x, y] = SnowPx(mat: m, v: L(t == .night ? v : v - 1.2), d: 0.96) } }
        // 시차 0.06 이라 화면에 거의 붙어 있다 → 보이는 폭(≈200) 안에 모은다
        // 곶: 왼쪽 끝에서 오른쪽으로 낮아지며 바다로 들어간다(x 0..124) · 낮은 건물 · 나무 둔덕
        for x in 0..<124 {
            let X = Double(x), top = Double(hz) - 7 * pow(max(0, 1 - X / 124), 0.7) - 2 * P.n1(X / 6, 151) * (X < 110 ? 1 : 0)
            for y in Int(top)...hz { C[x, y] = y == Int(top) ? sil : silD }
            if x % 9 == 4 && X < 104 && P.h(x, 0, 152) < 0.6 { lamp(x, Int(top) + 2) }
        }
        // 파라슈트 점프(x 18 · 높이 40): 가는 철탑(위로 좁아짐) + 꼭대기 원형 테 · 살 12 — 오후엔 바랜 붉은 칠, 밤엔 테두리 불빛
        let pj = 18, pjTop = hz - 46
        let red = t == .day ? SnowPx(mat: RED, v: L(2.6), d: 0.958) : sil
        for y in pjTop...(hz - 4) {
            let k = Double(y - pjTop) / Double(hz - 4 - pjTop), w = 1 + Int(4 * k)
            C[pj - w, y] = red; C[pj + w, y] = red
            if (y - pjTop) % 4 == 0 { for xx in (pj - w)...(pj + w) { C[xx, y] = red } }
        }
        for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 10) {   // 꼭대기 우산 테(납작한 원)
            let x = pj + Int((cos(a) * 11).rounded()), y = pjTop + 1 + Int((sin(a) * 2.5).rounded())
            C[x, y] = red
            if Int(a / (.pi / 10)) % 2 == 0 { for k in 1...6 { C[pj + Int((cos(a) * Double(k) * 11 / 6).rounded()), pjTop + 1 + Int((sin(a) * Double(k) * 2.5 / 6).rounded()) - (k < 3 ? 1 : 0)] = red } }
            if t == .night { C[x, y] = SnowPx(mat: SOD, v: L(4.3), d: 0.958) }
        }
        C.rect(pj, pjTop - 5, 1, 5, red)
        if t != .day { C[pj, pjTop - 6] = SnowPx(mat: RED, v: L(t == .night ? 4.4 : 3.4), d: 0.958) }
        // 원더휠(x 54 · 지름 30): 테 둘(바깥 · 안) + 살 16 + 받침 A자 — 밤엔 살마다 다른 색 불빛(정지 — 깜빡임은 BeachFx)
        let wc = (54, hz - 22), wr = 15.0
        for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 40) {
            C[wc.0 + Int((cos(a) * wr).rounded()), wc.1 + Int((sin(a) * wr).rounded())] = sil
            C[wc.0 + Int((cos(a) * (wr - 4)).rounded()), wc.1 + Int((sin(a) * (wr - 4)).rounded())] = silD
        }
        for i in 0..<16 {
            let a = Double(i) * .pi / 8
            for k in 1..<Int(wr) where k % 2 == 0 || t != .night { C[wc.0 + Int((cos(a) * Double(k)).rounded()), wc.1 + Int((sin(a) * Double(k)).rounded())] = silD }
            if i % 2 == 0 { C.rect(wc.0 + Int((cos(a) * (wr + 1)).rounded()) - 1, wc.1 + Int((sin(a) * (wr + 1)).rounded()), 2, 2, sil) }   // 곤돌라
        }
        for k in 0..<(hz - wc.1) { C[wc.0 - k / 2, wc.1 + k] = sil; C[wc.0 + k / 2, wc.1 + k] = sil }
        // 코니아일랜드 등대(Sea Gate — 곶 끝 x 118): 가는 흰 탑 · 전망 난간 · 등실(밤 불빛 · 회전 빛줄기는 BeachFx · BeachScene)
        let lhX = BeachGeo.lighthouse.x, lhTop = BeachGeo.lighthouse.y
        let lhP = t == .day ? SnowPx(mat: WOOD, v: L(4.4), d: 0.958) : sil, lhD = t == .day ? SnowPx(mat: WOOD, v: L(3.0), d: 0.958) : silD
        for y in (lhTop + 3)...(hz - 1) { C[lhX, y] = lhP; C[lhX + 1, y] = lhD; if y > hz - 5 { C[lhX - 1, y] = lhD; C[lhX + 2, y] = lhD } }
        C.rect(lhX - 1, lhTop + 2, 4, 1, lhD); C.rect(lhX, lhTop, 2, 2, t == .day ? SnowPx(mat: INK, v: L(1.0), d: 0.958) : silD); C[lhX, lhTop - 1] = lhD
        // 사이클론 롤러코스터(x 74~110): 나무 골조 언덕 — 격자
        for x in 74..<110 {
            let X = Double(x - 74), top = hz - 4 - Int(16 * max(0, sin(X / 48 * .pi * 1.5 + 0.3)) * (1 - X / 70))
            C[x, top] = sil
            if x % 4 == 0 { for y in top...(hz - 2) { C[x, y] = silD } }
            if x % 8 == 2 { for k in 0..<min(8, hz - top) { C[x + k / 2, top + k] = silD } }
        }
        // 베라자노 다리(x 102 ~ 180 — 가장 멀다: 아주 옅게 · 탑 둘 · 늘어진 주 케이블 · 상판) — 노을 해가 두 탑 사이로 진다
        let bridge = SnowPx(mat: t == .day ? HAZE : silD.mat, v: t == .day ? L(3.9) : silD.v + 0.04, d: 0.97)
        let t1 = 116, t2 = 164, deck = hz - 5
        for tx in [t1, t2] { C.rect(tx, hz - 22, 1, 20, bridge); C.rect(tx + 2, hz - 22, 1, 20, bridge); C[tx + 1, hz - 22] = bridge }
        for x in 102...180 {
            C[x, deck] = bridge
            let cab: Double
            if x < t1 { cab = Double(hz - 22) + Double(t1 - x) * 0.55 }
            else if x > t2 + 2 { cab = Double(hz - 22) + Double(x - t2 - 2) * 0.55 }
            else { let u = Double(x - t1) / Double(t2 - t1); cab = Double(hz - 22) + 14 * 4 * u * (1 - u) }
            if cab < Double(deck) { C[x, Int(cab.rounded())] = bridge }
            if x % 3 == 0 && t == .night { lamp(x, deck, SOD, 3.0) }
        }
        // 수평선 배: 컨테이너선(x 184 · 길이 20) · 돛단배(x 140 — 다리 앞)
        let ship = t == .day ? SnowPx(mat: HAZE, v: L(2.4), d: 0.97) : silD
        C.rect(184, hz - 3, 20, 2, ship); C.rect(186, hz - 5, 15, 2, ship); C.rect(198, hz - 8, 4, 3, ship)
        for k in 0..<3 { C.rect(187 + k * 4, hz - 6, 3, 1, k % 2 == 0 ? (t == .day ? SnowPx(mat: RED, v: L(2.2), d: 0.97) : ship) : ship) }
        lamp(199, hz - 9, RED, 3.4); lamp(185, hz - 4, SOD, 3.0)
        for k in 0..<9 { C[140, hz - 3 - k] = ship; if k < 7 { C.rect(141, hz - 3 - k, max(0, 5 - k * 5 / 7), 1, t == .day ? SnowPx(mat: FOAM, v: L(4.4), d: 0.97) : ship) } }
        C.rect(137, hz - 2, 8, 1, ship)
        return C
    }

    // MARK: 모래사장(정지) — 바닥 · 파라솔 · 감시탑 · 수건 · 아이스박스 · 모래성 · 해초 줄 · 조개 · 그림자

    static func sand(_ t: BeachTime) -> SnowCanvas {
        var C = SnowCanvas(w: BeachGeo.W, h: BeachGeo.H)
        let F = BeachFloor.table
        // 모래는 물가선(열마다 굴곡 — BeachGeo.shoreLine)부터 — 그 위 줄은 바다(BeachFx.seaMesh)가 그린다(모래 층이 앞이라 겹치면 바다 위에 모래 띠가 남는다)
        for x in 0..<BeachGeo.W { for y in BeachGeo.shoreLine[x]..<BeachGeo.H { C[x, y] = F.px(x, y, t) } }
        func sandAt(_ x: Int, _ y: Int, _ d: Float, ny: Float = 0.75) -> SnowPx? {
            guard let v = F.step(x, y) else { return nil }
            return SnowPx(mat: SAND, v: BeachFloor.emit(v + d, t), tone: BeachFloor.FT, d: BeachFloor.D, ny: ny)
        }
        // 그림자 방향(해 반대쪽 · 장면 x 기준 — 해는 화면에 붙어 있어 무대 가운데 기준으로 근사): 오후 = 왼쪽 짧게 · 노을 = 오른쪽 길게 · 밤 = 없음
        let shDX: Double = t == .day ? -0.35 : t == .dusk ? 1.6 : 0
        func shadow(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ k: Float = 1) {
            guard t != .night else { return }
            for oy in -Int(ry)...Int(ry) { for ox in -Int(rx + 1)...Int(rx + 1) {
                let e = pow(Double(ox) / rx, 2) + pow(Double(oy) / ry, 2)
                guard e <= 1 else { continue }
                let x = Int(cx) + ox, y = Int(cy) + oy
                if e > 0.75 && (x + y) & 1 == 0 { continue }
                if let p = sandAt(x, y, -1.4 * k, ny: 0.3) { C[x, y] = p }
            } }
        }
        // 해초 · 조개 줄(지난 만조 자리 — 인물 앞 y 238~244 · 군데군데 끊긴다)
        for x in 0..<BeachGeo.W {
            let X = Double(x), on = P.n1(X / 23, 161)
            guard on > 0.42 else { continue }
            let y = Int((241 + 2.2 * sin(X / 31) + 1.2 * sin(X / 9)).rounded())
            let dark = SnowPx(mat: DUNE, v: L(on > 0.7 ? 1.2 : 1.8), tone: 0.5, d: 0.12, ny: 0.7)
            C[x, y] = dark
            if P.h(x, y, 162) < 0.4 { C[x, y - 1] = SnowPx(mat: DUNE, v: L(2.4), tone: 0.5, d: 0.12, ny: 0.8) }
            if P.h(x, y, 163) < 0.12 { C[x, y + 1] = dark }
            if P.h(x, 0, 164) < 0.08 { C[x, y - 2] = SnowPx(mat: FOAM, v: L(4.6), tone: 0.6, d: 0.12, ny: 0.9) }   // 조개 껍데기
        }
        // 조개 · 조약돌(흩어진 낱 픽셀 — 자국 길 밖)
        var g = SplitMix64(seed: 0xC0A5)
        for _ in 0..<70 {
            let x = Int(g.next() * 480), y = 234 + Int(g.next() * 34), k = g.next()
            C[x, y] = k < 0.5 ? SnowPx(mat: FOAM, v: L(4.2 + k * 2), tone: 0.6, d: 0.12, ny: 0.9) : SnowPx(mat: STEEL, v: L(1.6), tone: 0.5, d: 0.12, ny: 0.8)
            if k < 0.5, let s = sandAt(x, y + 1, -1, ny: 0.3) { C[x, y + 1] = s }
        }
        // 지난 사람들 발자국(옅게 · 바다 쪽으로 걸어간 줄 둘)
        for (sx, sy, dx, dy, n) in [(20.0, 262.0, 6.5, -2.4, 9), (300.0, 266.0, 5.5, -2.2, 8)] {
            for i in 0..<n {
                let x = Int(sx + dx * Double(i)), y = Int(sy + dy * Double(i)) + (i % 2 == 0 ? 0 : 2)
                for xx in x..<(x + 2) { if let p = sandAt(xx, y, -0.75, ny: 0.4) { C[xx, y] = p } }
                if let p = sandAt(x, y + 1, 0.5, ny: 0.85) { C[x, y + 1] = p }
            }
        }
        // ── 파라솔(기둥 x 96 · 모래에 꽂힌 발 y 216): 줄무늬 빨강 · 흰 천 8쪽 · 물결 테 · 꼭지
        let ux = Int(BeachGeo.umbrellaX), uy = 216
        shadow(BeachGeo.umbrellaX + shDX * 30, 222, 26 + abs(shDX) * 10, 4.5)
        let pole = SnowPx(mat: WOOD, v: L(3.4), tone: 0.6, d: 0.1, ny: 0.2), poleD = SnowPx(mat: WOOD, v: L(2.0), tone: 0.5, d: 0.1, ny: 0.2)
        for y in 150..<uy { C[ux, y] = pole; C[ux + 1, y] = poleD }
        if let p = sandAt(ux - 1, uy, 1, ny: 0.9) { C[ux - 1, uy] = p }; if let p = sandAt(ux + 2, uy, 1, ny: 0.9) { C[ux + 2, uy] = p }   // 꽂힌 자리 둔덕
        let cw = 26.0, ctop = 140.0
        for x in (ux - Int(cw))...(ux + Int(cw)) {
            let X = Double(x - ux), k = X / cw, top = ctop + 9 * k * k, bot = 152 + 1.4 * sin(abs(X) / cw * 8 * .pi / 2 + .pi / 2)   // 물결 테(쪽마다 처진다)
            let sector = Int(floor((k + 1) * 4)) % 2
            for y in Int(top)...Int(bot) {
                let under = Double(y) > bot - 1.5
                let base: UInt8 = sector == 0 ? RED : FOAM
                let lit: Float = t == .night ? (sector == 0 ? 1.6 : 2.2) : (sector == 0 ? 2.8 : 4.4)
                let v = under ? lit - 1.2 : y == Int(top) ? lit + 0.6 : lit - Float(max(0, Double(y) - top)) * 0.06
                C[x, y] = SnowPx(mat: base, v: L(Double(v)), tone: 0.55, d: 0.1, ny: under ? -0.3 : 0.7)
            }
        }
        C.rect(ux, Int(ctop) - 3, 2, 3, pole)
        // ── 감시탑(다리 x 384 · 흰 칠 나무): 다리 넷(앞 둘 보인다) · 가로대 · 사다리 · 좌석 · 등받이 · 차양 · 'LIFEGUARD' 대신 붉은 띠
        let tx = Int(BeachGeo.towerX), ty = 220
        shadow(BeachGeo.towerX + 12 + shDX * 34, 226, 22 + abs(shDX) * 12, 4)
        let wd = SnowPx(mat: WOOD, v: L(t == .night ? 2.2 : 4.2), tone: 0.7, d: 0.1, ny: 0.4), wdD = SnowPx(mat: WOOD, v: L(t == .night ? 1.2 : 2.6), tone: 0.6, d: 0.1, ny: 0.2)
        let seatY = 166
        for (lx, sh) in [(tx, wd), (tx + 2, wdD), (tx + 24, wd), (tx + 26, wdD)] {   // 앞다리 둘(조금 벌어진다)
            for y in seatY..<ty { let spread = (lx < tx + 10 ? -1 : 1) * (y - seatY) / 18; C[lx + spread, y] = sh }
        }
        for (lx, y0) in [(tx + 6, seatY), (tx + 20, seatY)] { for y in y0..<(ty - 6) { C[lx, y] = wdD } }   // 뒷다리(짧게 · 그늘)
        for yy in [184, 200] { let sp = (yy - seatY) / 18; C.rect(tx - sp, yy, 27 + sp * 2, 1, wd); C.rect(tx - sp, yy + 1, 27 + sp * 2, 1, wdD) }
        for k in 0..<6 { let yy = 174 + k * 8, sp = (yy - seatY) / 18; C.rect(tx + 9 - sp / 2, yy, 9, 1, wd) }   // 사다리 디딤
        C.rect(tx - 2, seatY - 2, 31, 3, wd); C.rect(tx - 2, seatY + 1, 31, 1, wdD)            // 좌석 판
        C.rect(tx + 2, seatY - 16, 2, 14, wd); C.rect(tx + 23, seatY - 16, 2, 14, wd)           // 등받이 기둥
        C.rect(tx + 2, seatY - 12, 23, 6, wd); C.rect(tx + 2, seatY - 7, 23, 1, wdD)
        C.rect(tx + 4, seatY - 11, 19, 2, SnowPx(mat: RED, v: L(t == .night ? 1.6 : 2.8), tone: 0.55, d: 0.1, ny: 0.3))   // 붉은 띠
        for x in (tx - 4)...(tx + 30) { let sag = abs(Double(x - tx - 13)) < 15 ? 0 : 1; C[x, seatY - 22 + sag] = wdD; C[x, seatY - 23 + sag] = wd }   // 차양 천
        C.rect(tx - 3, seatY - 22, 1, 7, wdD); C.rect(tx + 29, seatY - 22, 1, 7, wdD)
        if t == .night {   // 밤: 차양 밑 작은 등(따뜻한 빛 — BeachScene 광원과 같은 자리)
            C.rect(tx + 12, seatY - 20, 3, 2, SnowPx(mat: SOD, v: L(4.6), d: 0.1))
        }
        // ── 수건(파라솔 밑 앞 · 줄무늬) · 아이스박스 · 모래성(인물 앞 · 깃발) · 양동이
        for x in 58..<88 { for y in 232..<237 {
            let stripe = ((x - 58) / 4) % 3
            let m: UInt8 = stripe == 0 ? TEAL : stripe == 1 ? FOAM : SOD
            C[x, y + (x - 58) / 15] = SnowPx(mat: m, v: L(t == .night ? 1.6 : y == 232 ? 3.6 : 3.0), tone: 0.6, d: 0.11, ny: 0.8)
        } }
        C.rect(122, 228, 12, 7, SnowPx(mat: TEAL, v: L(t == .night ? 1.4 : 2.8), tone: 0.6, d: 0.11, ny: 0.3))
        C.rect(122, 227, 12, 2, SnowPx(mat: FOAM, v: L(t == .night ? 2 : 4.4), tone: 0.6, d: 0.11, ny: 0.9))
        shadow(128 + shDX * 6, 236, 8, 1.5, 0.8)
        let cx = 262, cy = 252
        shadow(Double(cx) + 8 + shDX * 8, Double(cy) + 1, 13, 2, 0.9)
        let cs = { (d: Float, ny: Float) -> SnowPx in SnowPx(mat: SAND, v: L(Double(min(5.2, max(0, 3.2 + d)))) * (t == .night ? 0.4 : 0.62), tone: 0.3, d: 0.11, ny: ny) }
        C.rect(cx - 9, cy - 6, 18, 6, cs(0, 0.5)); C.rect(cx - 9, cy - 7, 18, 1, cs(0.8, 0.9))   // 몸통 · 윗면
        for (x0, h) in [(cx - 10, 11), (cx + 6, 11), (cx - 2, 15)] {   // 탑 셋 · 톱니
            C.rect(x0, cy - h, 4, h - 6, cs(0.2, 0.4)); for k in 0..<2 { C[x0 + k * 3, cy - h - 1] = cs(0.9, 0.9) }
        }
        for y in (cy - 22)..<(cy - 15) { C[cx, y] = SnowPx(mat: WOOD, v: L(3.0), tone: 0.6, d: 0.11, ny: 0.2) }
        C.rect(cx + 1, cy - 22, 4, 3, SnowPx(mat: RED, v: L(t == .night ? 1.6 : 3.0), tone: 0.6, d: 0.11, ny: 0.3))
        C.rect(cx - 2, cy - 4, 4, 4, cs(-1.6, 0.1))   // 성문(그늘)
        C.rect(cx + 14, cy - 5, 5, 5, SnowPx(mat: RED, v: L(t == .night ? 1.4 : 2.6), tone: 0.6, d: 0.11, ny: 0.3)); C.rect(cx + 14, cy - 6, 5, 1, SnowPx(mat: RED, v: L(t == .night ? 2 : 3.6), tone: 0.6, d: 0.11, ny: 0.9))   // 양동이
        return C
    }
}
