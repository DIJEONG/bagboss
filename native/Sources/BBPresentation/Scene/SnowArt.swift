import Foundation
import BBCore
import BBContent

// 눈 승강장 정지 그림(docs/10) — 7호선 46번가–블리스 고가 승강장, 막차 무렵(23:30) 폭설.
// 스프라이트 아틀라스가 아니라 무대 픽셀(G-버퍼 3D 층 1px 쿼드 — NativeRiseArt 와 같은 길)로 그린다 → 무대 조명 · 팔레트 6단 램프 · 베이어 디더를 그대로 받는다.
//  · 값: 픽셀마다 재질 · 발광(v = 램프 단 위치 0..1 — 셰이더가 6단으로 자르고 디더한다) · 톤(빛을 받는 정도) · 층 깊이(d — 점광원이 먼 층을 비추지 않게)
//  · 층(뒤 → 앞) · 시차(p — 카메라가 Δ 움직이면 화면에서 p·Δ 움직인다):
//      하늘 0 · 맨해튼 스카이라인 + 퀸즈보로 다리 0.1 · 퀸즈 지붕 · 물탱크 0.28 · 길 건너 벽돌 아파트(불 켜진 창 · 비상계단) 0.55 · 앙상한 나무 0.72 · 승강장(난간 · 기둥 · 가로등 · 역 이름판 · 가판대 · 눈 바닥) 1
//  · 깊이감: 먼 층일수록 옅고 덜 맑은 파랑(HAZE) · 대비 낮게, 가까운 층은 거의 검은 실루엣(GIRD · INK) + 따뜻한 창 · 등(SODIUM)으로 보색 대비
//  · 한 번 그려 같은 픽셀이 이어지는 가로 줄 → 세로로 같은 줄을 합친 사각형으로 묶어 둔다(층마다 · 시차 오프셋별 정점은 캐시)

/// 눈 승강장 기준선(장면 픽셀)
public enum SnowGeo {
    public static let W = 480, H = 270
    /// 눈 바닥 윗선(난간 밑) · 승강장 앞 모서리
    public static let groundTop = 200, lip = 251
    /// 가로등 기둥 · 역 이름판 · 가판대(기둥 회전차기 자리 = 웹 POLES 와 같다)
    public static let lamps: [Double] = [98, 240, 382]
    public static let lampY = 64.0
    public static let signX = 160.0, kioskX = 320.0
    /// 하늘 · 배경 깊이(GL z) — 인물(≈0.16)보다 늘 뒤
    static let zBack = 0.985
}

/// 눈 바닥 값(정지 그림 · 바닥 자국 · 반짝이가 같은 값을 쓴다 — 자국이 바닥과 이음매 없이 이어진다)
///   단 단위 s(SNOWF 램프 0..5 — 빛 없을 때) → 발광 = (s + 0.5)/6 − 기준 빛. 톤 FT 로 가로등 웅덩이 · 하늘빛을 받는다
struct SnowFloor: @unchecked Sendable {
    static let table = SnowFloor()
    /// 바닥 톤 · 기준 빛(어두운 곳 바닥이 받는 하늘빛 + 환경광 × 톤 — 단 가운데에 오게 빼 둔다)
    static let FT: Float = 0.75, base: Double = 0.33
    let edge: [Int]
    /// 단 값(장면 x · y — 바닥 밖은 nan) · 재질(SNOWF · 웅덩이 SNOWW)
    private let s: [Float]
    private let m: [UInt8]
    static let y0 = 180, rows = SnowGeo.lip - 180 + 4

    init() {
        let W = SnowGeo.W, G = SnowGeo.groundTop
        typealias P = SnowPaint
        // 윗선: 둥근 더미(기둥 · 이름판 기둥 · 가판대 둘레로 바람에 쌓인다)
        var e = [Int](repeating: G, count: W), hh = [Double](repeating: 0, count: W)
        let kx = Double(SnowGeo.kioskX) + 6
        for x in 0..<W {
            let X = Double(x)
            var m = 1.2 + P.n1(X / 16, 61) * 1.8 + P.n1(X / 7, 62) * 0.6
            for px in SnowGeo.lamps + [SnowGeo.signX - 22, SnowGeo.signX + 20] { m += 3.6 * exp(-pow((X - px) / 7, 2)) }
            m += 2.6 * exp(-pow((X - (kx + 17)) / 22, 4))
            hh[x] = m; e[x] = G - Int(m.rounded())
        }
        edge = e
        var t = [Float](repeating: .nan, count: W * Self.rows)
        var mm = [UInt8](repeating: UInt8(NativePalette.SNOWF), count: W * Self.rows)
        let B4: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
        let lip = SnowGeo.lip
        func ss(_ a: Double, _ b: Double, _ x: Double) -> Double { let u = max(0, min(1, (x - a) / (b - a))); return u * u * (3 - 2 * u) }
        // 바람결 둔덕: 가로로 길고 완만하게 물결치는 줄(마디마다 끊긴다) — y 기준 · 진폭 · 위상
        let ridges: [(Double, Double, UInt64)] = [(204, 1.2, 81), (209, 1.5, 82), (213.5, 1.0, 83), (233, 1.4, 84), (238, 1.6, 85), (242.5, 1.2, 86), (246.5, 0.9, 87)]
        for x in 0..<W {
            let X = Double(x)
            for y in e[x]..<(lip + 4) {
                let Y = Double(y), dy = y - e[x], u = (Y - Double(G)) / Double(lip - G)
                // 바탕: 뒤(난간 밑) 밝은 차가운 윗면 → 앞 모서리로 짙은 파랑
                var v = 1.55 - 1.05 * ss(0.12, 1.0, u)
                // 넓은 덩어리(아주 느린 2차원 잡음 — 일부러 둔 얼룩)
                v += 0.42 * (P.n2(X / 38, Y / 9, 63) - 0.5) + 0.18 * (P.n2(X / 13, Y / 4, 64) - 0.5)
                // 가로등 밑 밝은 윗면(빛 웅덩이가 따뜻하게 데운다 — 여기선 값만 한 단 남짓)
                var pool = 0.0
                for lx in SnowGeo.lamps { pool = max(pool, exp(-pow((X - lx - 6) / 38, 2) - pow((Y - 208) / 13, 2))) }
                v += 0.3 * pool
                // 웅덩이 속은 따뜻한 램프(SNOWW) — 가장자리는 성긴 규칙 디더로 섞는다
                if pool > 0.32 + 0.22 * (B4[(y & 3) * 4 + (x & 3)] + 0.5) / 16 { mm[(y - Self.y0) * W + x] = UInt8(NativePalette.SNOWW) }
                v += 0.5 * exp(-pow((X - kx - 17) / 26, 2) - pow((Y - 206) / 10, 2))   // 가판대 창빛
                // 다져진 길(인물이 가장 많이 걷는 줄 — 살짝 짙고 매끈)
                let path = ss(214, 218, Y) * (1 - ss(228, 233, Y))
                v -= 0.55 * path
                // 기둥 · 가판대 밑 푸른 그늘(윗선 가까이만)
                for px in SnowGeo.lamps + [SnowGeo.signX - 22, SnowGeo.signX + 20] { v -= 0.9 * exp(-pow((X - px - 3) / 5, 2)) * (1 - ss(0, 7, Double(dy))) }
                v -= 0.8 * (1 - ss(0, 6, Double(dy))) * (X > kx - 2 && X < kx + 36 ? 1 : 0)
                // 1/8 단으로 자른 뒤 · 아래 무늬는 정수 단으로 얹는다(둔덕 · 윗선 빛)
                v = (v * 8).rounded() / 8
                // 윗선 더미: 맨 윗줄 빛 · 둘째 줄 조금 · 내려가는 쪽(오른쪽 비탈)은 살짝 그늘
                if dy == 0 { v += 1.4 } else if dy == 1 { v += 0.6 }
                if dy <= 2, x + 1 < W, hh[x + 1] < hh[x] - 0.25 { v -= 0.5 }
                // 바람결 둔덕(길 밖에서만): 윗줄 한 단 밝게 · 아랫줄 한 단 그늘
                if path < 0.5 {
                    for (ry, amp, sd) in ridges {
                        let on = P.n1(X / 23 + Double(sd) * 3.1, sd) - 0.42
                        guard on > 0 else { continue }
                        let yy = (ry + amp * sin(X * 0.043 + Double(sd)) + 0.6 * sin(X * 0.11 + Double(sd) * 2)).rounded()
                        let thick = on > 0.22 ? 2.0 : 1.0
                        if Y > yy - thick - 0.5 && Y <= yy { v += 1 } else if abs(Y - yy - 1) < 0.5 { v -= on > 0.12 ? 1 : 0.5 }
                    }
                }
                t[(y - Self.y0) * W + x] = Float(v)
            }
        }
        s = t; m = mm
    }

    /// 단 값(바닥 밖 nil)
    @inline(__always) func step(_ x: Int, _ y: Int) -> Float? {
        guard x >= 0, x < SnowGeo.W, y >= Self.y0, y < Self.y0 + Self.rows else { return nil }
        let v = s[(y - Self.y0) * SnowGeo.W + x]
        return v.isNaN ? nil : v
    }
    /// 재질(웅덩이 속 SNOWW)
    @inline(__always) func mat(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < SnowGeo.W, y >= Self.y0, y < Self.y0 + Self.rows else { return UInt8(NativePalette.SNOWF) }
        return m[(y - Self.y0) * SnowGeo.W + x]
    }
    /// 단 값 → 발광(기준 빛을 빼 둔다 — 어두운 곳에서 단 가운데)
    @inline(__always) static func emit(_ step: Float) -> Float { max(0, (step + 0.5) / 6 - Float(base)) }
    /// 바닥 픽셀(무대 픽셀 값)
    func px(_ x: Int, _ y: Int) -> SnowPx? {
        guard let v = step(x, y) else { return nil }
        let dy = y - edge[max(0, min(SnowGeo.W - 1, x))]
        return SnowPx(mat: mat(x, y), v: Self.emit(v), tone: Self.FT, d: 0.12, ny: dy < 2 ? 0.8 : 0.45)
    }
    /// 앞 모서리 처마 픽셀(밑 바닥 값에서 d 단 더한 값)
    func snow(_ x: Int, _ y: Int, _ d: Float, ny: Float) -> SnowPx {
        let v = (step(x, SnowGeo.lip - 1) ?? 1.5) + d - 0.6
        return SnowPx(mat: UInt8(NativePalette.SNOWF), v: Self.emit(v), tone: Self.FT, d: 0.12, ny: ny)
    }
    /// 처마가 턱 아래로 늘어진 길이(0..2 — 덩이로)
    static func hang(_ x: Int) -> Int { let n = SnowPaint.n1(Double(x) / 5, 73); return n > 0.62 ? 2 : n > 0.3 ? 1 : 0 }
}

/// 픽셀 한 칸
struct SnowPx: Equatable {
    var mat: UInt8, v: Float, tone: Float = 0, d: Float = 0.9, ny: Float = 0
}

/// 층 캔버스(나중에 찍은 것이 이긴다)
struct SnowCanvas {
    let w: Int, h: Int
    var px: [SnowPx?]
    init(w: Int, h: Int) { self.w = w; self.h = h; px = Array(repeating: nil, count: w * h) }
    subscript(x: Int, y: Int) -> SnowPx? {
        get { x >= 0 && y >= 0 && x < w && y < h ? px[y * w + x] : nil }
        set { if x >= 0 && y >= 0 && x < w && y < h { px[y * w + x] = newValue } }
    }
    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ p: SnowPx) {
        let x0 = max(0, x), x1 = min(w, x + rw), y0 = max(0, y), y1 = min(h, y + rh)
        guard x1 > x0, y1 > y0 else { return }
        for yy in y0..<y1 { for xx in x0..<x1 { px[yy * w + xx] = p } }
    }
    /// 같은 값 가로 줄 → 세로 합치기 사각형(x0, y0, x1, y1, 값)
    func rects() -> [(Int, Int, Int, Int, SnowPx)] {
        var out: [(Int, Int, Int, Int, SnowPx)] = []
        var open: [Int: Int] = [:]   // (x0 << 12 | x1) → out 인덱스(바로 윗줄에서 이어진 사각형)
        for y in 0..<h {
            var next: [Int: Int] = [:]
            var x = 0
            while x < w {
                guard let p = px[y * w + x] else { x += 1; continue }
                var x1 = x + 1
                while x1 < w, px[y * w + x1] == p { x1 += 1 }
                let key = x << 12 | x1
                if let i = open[key], out[i].4 == p, out[i].3 == y { out[i].3 = y + 1; next[key] = i }
                else { out.append((x, y, x1, y + 1, p)); next[key] = out.count - 1 }
                x = x1
            }
            open = next
        }
        return out
    }
}

/// 층 하나(사각형 + 시차) — 오프셋별 정점 캐시
final class SnowLayer: @unchecked Sendable {
    let p: Double
    /// 층 깊이(GL z — 뒤 층일수록 크다: 같은 그리기 안에서 앞 층이 깊이 검사를 이긴다)
    let z: Double
    let rects: [(Int, Int, Int, Int, SnowPx)]
    private var cacheDX = Int.min
    private var cache: [Float] = []
    init(p: Double, z: Double, canvas: SnowCanvas) { self.p = p; self.z = z; rects = canvas.rects() }
    /// 카메라 x 에서의 정점(장면 x = 층 x + (1 − p)·camX)
    func mesh(camX: Double) -> [Float] {
        let dx = Int(((1 - p) * camX).rounded())
        if dx == cacheDX { return cache }
        var f: [Float] = []; f.reserveCapacity(rects.count * 60)
        let z = Float(self.z)
        for (x0, y0, x1, y1, q) in rects {
            let a = Float(x0 + dx), b = Float(x1 + dx), c = Float(y0), d = Float(y1)
            guard b > 0, a < Float(SnowGeo.W) else { continue }
            let t: [Float] = [0, q.ny, q.tone, Float(q.mat), -1, q.d, q.v]
            for (px, py) in [(a, c), (b, c), (b, d), (a, c), (b, d), (a, d)] { f.append(px); f.append(py); f.append(z); f.append(contentsOf: t) }
        }
        cacheDX = dx; cache = f
        return f
    }
}

/// 눈 승강장 그림 전부(처음 한 번 — 앱은 뒤 스레드에서 미리 데운다)
public final class SnowArt: @unchecked Sendable {
    public static let shared = SnowArt()
    private let lock = NSLock()
    private var built: [SnowLayer]?
    private var lastKey: [Int] = []
    private var lastMesh: [Float] = []

    /// 미리 그려 둔다(첫 눈 구간에 멈칫하지 않게)
    public func warm() { DispatchQueue.global(qos: .utility).async { _ = self.layers() } }

    func layers() -> [SnowLayer] {
        lock.lock(); defer { lock.unlock() }
        if let b = built { return b }
        let b = SnowPaint.paint()
        built = b
        return b
    }

    /// 이번 카메라의 배경 정점 전부(층 오프셋이 같으면 지난 것 그대로)
    public func mesh(camX: Double) -> [Float] {
        let L = layers()
        let key = L.map { Int(((1 - $0.p) * camX).rounded()) }
        lock.lock(); defer { lock.unlock() }
        if key == lastKey { return lastMesh }
        var f: [Float] = []
        for l in L { f += l.mesh(camX: camX) }
        lastKey = key; lastMesh = f
        return f
    }
    /// 사각형 수(성능 점검)
    public var rectCount: Int { layers().reduce(0) { $0 + $1.rects.count } }
}

// MARK: - 그리기

enum SnowPaint {
    typealias M = NativePalette
    static let INK: UInt8 = 1, WINLIT: UInt8 = 31, GOLD: UInt8 = 9, RED: UInt8 = 12, STEEL: UInt8 = 8, TAXI: UInt8 = 46, EYE: UInt8 = 13
    static let SNOW = UInt8(M.SNOW), NITE = UInt8(M.NITE), HAZE = UInt8(M.HAZE), GIRD = UInt8(M.GIRD), LINE7 = UInt8(M.LINE7)
    static let SOD = UInt8(M.SODIUM), BRICK = UInt8(M.BRICKN), TEAL = UInt8(M.TEAL)

    /// 단 가운데 값(평평한 칠 — 디더 없이 그 단)
    static func L(_ step: Double) -> Float { Float((step + 0.5) / 6) }
    /// 정수 해시 0..1
    static func h(_ x: Int, _ y: Int, _ s: UInt64 = 0) -> Double {
        var g = SplitMix64(seed: UInt64(bitPattern: Int64(x &* 73856093 ^ y &* 19349663)) &+ s &* 0x9E3779B97F4A7C15); return g.next()
    }
    /// 부드러운 2차원 잡음(값 잡음 · 코사인 보간)
    static func n2(_ x: Double, _ y: Double, _ s: UInt64) -> Double {
        let i = Int(floor(x)), j = Int(floor(y)), fx = x - floor(x), fy = y - floor(y)
        let u = (1 - cos(fx * .pi)) / 2, w = (1 - cos(fy * .pi)) / 2
        let a = h(i, j, s) * (1 - u) + h(i + 1, j, s) * u, b = h(i, j + 1, s) * (1 - u) + h(i + 1, j + 1, s) * u
        return a * (1 - w) + b * w
    }
    /// 부드러운 1차원 잡음(값 잡음 · 코사인 보간)
    static func n1(_ x: Double, _ s: UInt64) -> Double {
        let i = Int(floor(x)), f = x - floor(x), u = (1 - cos(f * .pi)) / 2
        return h(i, 0, s) * (1 - u) + h(i + 1, 0, s) * u
    }

    static func paint() -> [SnowLayer] {
        [SnowLayer(p: 0, z: 0.996, canvas: sky()), SnowLayer(p: 0.1, z: 0.995, canvas: far()), SnowLayer(p: 0.28, z: 0.994, canvas: queens()),
         SnowLayer(p: 0.55, z: 0.993, canvas: blocks()), SnowLayer(p: 0.72, z: 0.992, canvas: tree()), SnowLayer(p: 1, z: SnowGeo.zBack + 0.0005, canvas: platform()),
         SnowLayer(p: 1.25, z: SnowGeo.zBack - 0.0005, canvas: branches())]
    }

    // MARK: 하늘 — 짙은 남색 → 지평선 청록 빛무리(도시 불빛이 눈구름에 비친다). 낮은 눈구름 띠
    static func sky() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: 200)
        for y in 0..<200 {
            for x in 0..<SnowGeo.W {
                let t = Double(y) / 150
                // 눈구름: 느린 잡음 띠(세로로 납작)
                let cl = n1(Double(x) / 70 + Double(y) * 0.05, 3) * 0.6 + n1(Double(x) / 23, 9) * 0.4
                let band = max(0, sin(Double(y) / 150 * .pi * 2.2 + 0.6)) * 0.06
                if y < 104 {
                    var v = 0.09 + 0.36 * pow(t / 0.69, 1.6) + (cl - 0.5) * 0.08 + band
                    v = (v * 24).rounded() / 24
                    C[x, y] = SnowPx(mat: NITE, v: Float(v), d: 0.99)
                } else {
                    // 경계 4줄은 체크로 섞는다(재질이 바뀌는 곳을 디더로)
                    if y < 108 && (x + y) & 1 == 0 && y < 106 { C[x, y] = SnowPx(mat: NITE, v: Float(0.48), d: 0.99); continue }
                    var v = 0.34 + 0.46 * min(1, (Double(y) - 104) / 56) + (cl - 0.5) * 0.06
                    v = (v * 24).rounded() / 24
                    C[x, y] = SnowPx(mat: TEAL, v: Float(v), d: 0.99)
                }
            }
        }
        return C
    }

    // MARK: 맨해튼(먼 실루엣 · 옅은 안개 파랑 · 아주 작은 창 몇 개) + 퀸즈보로 다리
    static func far() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: 200)
        let base = 168
        let hz = SnowPx(mat: HAZE, v: L(1.9), d: 0.96)
        let hzD = SnowPx(mat: HAZE, v: L(1.45), d: 0.96)
        var x = 0
        var k = 0
        // 스카이라인: 높이가 고르지 않은 탑들(가운데가 미드타운 — 높다)
        while x < SnowGeo.W {
            let w = 6 + Int(h(k, 1, 11) * 14)
            let mid = exp(-pow((Double(x) - 290) / 120, 2))
            let top = base - 22 - Int(h(k, 2, 11) * 26 + mid * 52)
            let shade = h(k, 3, 11) < 0.35 ? hzD : hz
            for yy in top..<base {   // 아래로 갈수록 안개가 두껍다(밝게) · 왼쪽 모서리 1px 빛 · 오른쪽 1px 그늘
                let u = Double(yy - top) / Double(max(1, base - top))
                var v = Double(shade.v) - 0.07 + 0.12 * u; v = (v * 24).rounded() / 24
                for xx in x..<(x + w) { C[xx, yy] = SnowPx(mat: HAZE, v: Float(v + (xx == x ? 0.05 : xx == x + w - 1 ? -0.04 : 0)), d: 0.96) }
            }
            if h(k, 4, 11) < 0.3 { C.rect(x + w / 2 - 1, top - 3, 2, 3, shade) }   // 지붕 기계실
            // 창: 아주 작은 따뜻한 점(대비 낮게)
            for yy in stride(from: top + 3, to: base - 2, by: 4) { for xx in stride(from: x + 2, to: x + w - 1, by: 3) where h(xx, yy, 13) < 0.16 {
                C[xx, yy] = h(xx, yy, 14) < 0.7 ? SnowPx(mat: SOD, v: L(1.9), d: 0.96) : SnowPx(mat: HAZE, v: L(3.4), d: 0.96)
            } }
            x += w + (h(k, 5, 11) < 0.25 ? 1 : 0); k += 1
        }
        // 엠파이어 스테이트(계단 꼴 + 첨탑 · 꼭대기 붉은 등)
        func spire(_ cx: Int, _ steps: [(Int, Int)], _ mast: Int, _ p: SnowPx) {
            var y = base
            for (w, hh) in steps { C.rect(cx - w / 2, y - hh, w, hh, p); y -= hh }
            C.rect(cx, y - mast, 1, mast, p)
            C[cx, y - mast - 1] = SnowPx(mat: RED, v: L(3.2), d: 0.96)
        }
        spire(300, [(22, 40), (16, 22), (10, 14), (6, 8), (3, 6)], 12, hzD)
        // 크라이슬러(비늘 꼴 왕관 — 창 몇 줄이 빛난다)
        spire(250, [(14, 50), (10, 14), (8, 6), (6, 5), (4, 4), (2, 4)], 9, hz)
        for (i, wv) in [8, 6, 4].enumerated() { let y = base - 50 - 14 - 1 - i * 5; for xx in 0..<wv where xx % 2 == 0 { C[250 - wv / 2 + xx, y] = SnowPx(mat: SOD, v: L(2.4), d: 0.96) } }
        // 시티그룹 센터(비스듬히 잘린 꼭대기)
        for xx in 0..<14 { let t = base - 70 - (13 - xx) * 7 / 13; C.rect(196 + xx, t, 1, base - t, hzD) }
        // 432 파크(가는 탑)
        C.rect(274, base - 96, 5, 96, hz)
        for yy in stride(from: base - 94, to: base - 4, by: 5) { C[276, yy] = SnowPx(mat: HAZE, v: L(2.6), d: 0.96) }
        // 퀸즈보로 다리(캔틸레버 트러스 · 탑 넷 · 상판 불빛) — 스카이라인 앞
        let bp = SnowPx(mat: HAZE, v: L(1.15), d: 0.95)
        let deckY = 150
        C.rect(0, deckY, 210, 2, bp)
        for tx in [18, 78, 138, 198] { C.rect(tx - 2, deckY - 26, 4, 26 + 18, bp) }
        for i in 0..<210 {   // 트러스: 탑에서 내려오는 곡선 위 현 + X 자 살
            let ph = Double((i + 2) % 60) / 60, top = deckY - 4 - Int(18 * pow(abs(ph - 0.5) * 2, 1.7))
            C[i, top] = bp
            if (i + top) % 6 == 0 { for yy in top..<deckY { if (yy - top + i) % 6 == 0 { C[i, yy] = bp } } }
            if i % 7 == 3 { C[i, deckY + 2] = SnowPx(mat: SOD, v: L(2.2), d: 0.95) }   // 상판 가로등
        }
        return C
    }

    // MARK: 퀸즈(낮은 지붕 · 물탱크 · 굴뚝 · 첨탑 — 지붕 위 눈)
    static func queens() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: 210)
        let wall = SnowPx(mat: HAZE, v: L(0.9), d: 0.88), wallD = SnowPx(mat: NITE, v: L(1.7), d: 0.88)
        let snow = SnowPx(mat: SNOW, v: L(1.6), d: 0.88)
        var x = -4, k = 0
        while x < SnowGeo.W {
            let w = 16 + Int(h(k, 1, 21) * 34), top = 150 + Int(h(k, 2, 21) * 22)
            let p = h(k, 3, 21) < 0.5 ? wall : wallD
            C.rect(x, top, w, 210 - top, p)
            for xx in x..<(x + w) where h(xx, 0, 22) < 0.85 { C[xx, top - 1] = snow }   // 지붕 위 눈(군데군데)
            for yy in stride(from: top + 4, to: 205, by: 7) { for xx in stride(from: x + 2, to: x + w - 2, by: 5) where h(xx, yy, 23) < 0.12 {
                C[xx, yy] = SnowPx(mat: SOD, v: L(2.3), d: 0.88); C[xx + 1, yy] = SnowPx(mat: SOD, v: L(2.0), d: 0.88)
            } }
            if h(k, 4, 21) < 0.45 {   // 물탱크: 다리 · 통 · 고깔 지붕(눈)
                let cx = x + 4 + Int(h(k, 5, 21) * Double(max(1, w - 10))), ty = top - 14
                C.rect(cx, ty + 9, 1, 5, p); C.rect(cx + 6, ty + 9, 1, 5, p); C.rect(cx + 1, ty + 11, 5, 1, p)
                C.rect(cx, ty + 2, 7, 7, p)
                for r in 0..<3 { C.rect(cx + r, ty + 1 - r, 7 - r * 2, 1, r == 2 ? snow : p) }
                C.rect(cx + 1, ty + 2, 5, 1, snow)
            } else if h(k, 6, 21) < 0.3 { C.rect(x + w - 6, top - 6, 2, 6, p); C[x + w - 6, top - 7] = snow; C[x + w - 5, top - 7] = snow }   // 굴뚝
            x += w; k += 1
        }
        // 교회 첨탑 하나
        let sx = 352
        C.rect(sx - 3, 132, 7, 40, wallD)
        for r in 0..<14 { C.rect(sx - 3 + r / 4, 131 - r, 7 - (r / 4) * 2, 1, wallD) }
        C[sx, 116] = snow; C[sx, 113] = wallD; C[sx - 1, 114] = wallD; C[sx + 1, 114] = wallD
        return C
    }

    // MARK: 길 건너 벽돌 아파트(가까운 중경) — 불 켜진 창 · 비상계단 · 창턱 눈 · 처마 눈. 건물 사이 틈으로 먼 층이 보인다
    static func blocks() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: SnowGeo.groundTop + 4)
        var x = -6, k = 0
        let bottom = SnowGeo.groundTop + 4
        while x < SnowGeo.W {
            let w = 46 + Int(h(k, 1, 31) * 40)
            let gap = k % 2 == 1 ? 26 + Int(h(k, 3, 31) * 34) : (h(k, 2, 31) < 0.3 ? 6 : 0)   // 건물 사이 틈(먼 맨해튼이 보이는 창)
            let top = (k % 3 == 0 ? 78 : 104) + Int(h(k, 4, 31) * 38)
            let brick = h(k, 5, 31) < 0.7
            // 벽: 위는 어둡고 아래로 갈수록 거리 나트륨 불빛을 받는다(디더 경사)
            for yy in top..<bottom {
                let u = Double(yy - top) / Double(bottom - top)
                var v = (brick ? 0.12 : 0.1) + 0.2 * pow(u, 1.8)
                v = (v * 36).rounded() / 36
                for xx in x..<(x + w) { C[xx, yy] = SnowPx(mat: brick ? BRICK : NITE, v: Float(v), d: 0.72) }
            }
            // 벽돌 줄눈(아래쪽 밝은 곳에서만 보이게 — 3줄마다 어두운 1px)
            if brick { for yy in stride(from: top + 6, to: bottom, by: 3) where yy > top + (bottom - top) / 2 { for xx in x..<(x + w) where (xx + yy / 3 * 3) % 7 != 0 && h(xx, yy, 35) < 0.35 {
                if var p = C[xx, yy] { p.v -= 0.04; C[xx, yy] = p }
            } } }
            // 처마 돌림띠 + 눈(울퉁불퉁)
            C.rect(x - 1, top - 2, w + 2, 2, SnowPx(mat: GIRD, v: L(1.3), d: 0.72))
            for xx in (x - 1)..<(x + w + 1) {
                let lump = h(xx / 3, top, 36) < 0.5 ? 1 : 0
                C.rect(xx, top - 3 - lump, 1, 1 + lump, SnowPx(mat: SNOW, v: L(2.6 + (xx % 5 == 0 ? 0.5 : 0)), d: 0.72))
            }
            // 창 격자
            let cw = 10 + (k % 2), rh = 14, ww = 4, wh = 6
            var fire: Set<Int> = []
            if w > 70 && h(k, 7, 31) < 0.65 { fire.insert(1 + Int(h(k, 8, 31) * Double(max(1, w / cw - 3)))) }   // 비상계단이 붙은 창 줄
            var col = 0
            for wx in stride(from: x + 5, to: x + w - ww - 3, by: cw) {
                var row = 0
                for wy in stride(from: top + 8, to: bottom - 10, by: rh) {
                    let r = h(wx, wy, 37)
                    let lit = r < 0.24, tv = r > 0.96
                    for yy in 0..<wh { for xx in 0..<ww {
                        var p = SnowPx(mat: NITE, v: L(yy == 0 ? 1.4 : 0.8), d: 0.72)              // 꺼진 창: 하늘이 비친다
                        if lit {
                            let warm = 3.2 + (yy >= wh - 2 ? 0.5 : 0) - (xx == 0 ? 0.6 : 0)
                            p = SnowPx(mat: SOD, v: L(warm), d: 0.72)
                            if h(wx, wy, 38) < 0.35 && xx >= 2 && yy < 4 { p = SnowPx(mat: BRICK, v: L(3.0), d: 0.72) }   // 커튼 그림자
                            if yy == 2 && h(wx, wy, 39) < 0.5 { p = SnowPx(mat: SOD, v: L(2.2), d: 0.72) }   // 창살
                        } else if tv { p = SnowPx(mat: TEAL, v: L(3.4), d: 0.72) }                   // 텔레비전 푸른 빛
                        C[wx + xx, wy + yy] = p
                    } }
                    C.rect(wx - 1, wy + wh, ww + 2, 1, SnowPx(mat: SNOW, v: L(lit ? 3.2 : 2.3), d: 0.72))   // 창턱 눈
                    if fire.contains(col) {   // 비상계단 층판(눈 쌓임) · 난간 · 사다리
                        let py = wy + wh + 2, px0 = wx - 4
                        C.rect(px0, py, ww + 16, 1, SnowPx(mat: GIRD, v: L(0.4), d: 0.72))
                        C.rect(px0, py - 1, ww + 16, 1, SnowPx(mat: SNOW, v: L(2.4), d: 0.72))
                        for xx in stride(from: px0, to: px0 + ww + 16, by: 2) { C[xx, py - 4] = SnowPx(mat: GIRD, v: L(0.3), d: 0.72) }
                        C.rect(px0, py - 5, ww + 16, 1, SnowPx(mat: GIRD, v: L(0.4), d: 0.72))
                        if row % 2 == 0 { for t in 0..<rh where py + t < bottom - 10 { C[px0 + ww + 14 - t, py + t] = SnowPx(mat: GIRD, v: L(0.3), d: 0.72) } }
                        else { for t in 0..<rh where py + t < bottom - 10 { C[px0 + 2 + t, py + t] = SnowPx(mat: GIRD, v: L(0.3), d: 0.72) } }
                    }
                    row += 1
                }
                col += 1
            }
            // 지붕 위: 물탱크 · 안테나(실루엣)
            if h(k, 9, 31) < 0.4 {
                let cx = x + 8 + Int(h(k, 10, 31) * Double(w - 20)), ty = top - 18
                let p = SnowPx(mat: GIRD, v: L(0.6), d: 0.72)
                C.rect(cx, ty + 10, 1, 6, p); C.rect(cx + 8, ty + 10, 1, 6, p); C.rect(cx, ty + 12, 9, 1, p)
                C.rect(cx, ty + 2, 9, 8, p)
                for r in 0..<3 { C.rect(cx + r, ty + 1 - r, 9 - r * 2, 1, p) }
                C.rect(cx + 1, ty + 1, 7, 1, SnowPx(mat: SNOW, v: L(2.3), d: 0.72)); C.rect(cx + 3, ty - 1, 3, 1, SnowPx(mat: SNOW, v: L(2.6), d: 0.72))
            } else if h(k, 11, 31) < 0.5 { C.rect(x + w - 12, top - 12, 1, 9, SnowPx(mat: GIRD, v: L(0.6), d: 0.72)); C.rect(x + w - 15, top - 9, 7, 1, SnowPx(mat: GIRD, v: L(0.6), d: 0.72)) }
            x += w + gap; k += 1
        }
        return C
    }

    // MARK: 앙상한 나무(가지 끝까지 실루엣 · 위쪽 면에 눈)
    static func tree() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: SnowGeo.groundTop + 2)
        var rng = SplitMix64(seed: 0x7EE5)
        func R() -> Double { rng.next() }
        let bark = SnowPx(mat: INK, v: L(0.7), d: 0.6)
        func branch(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ w: Double, _ depth: Int) {
            var px = x, py = y
            let steps = Int(len)
            var ang = a
            for _ in 0..<steps {
                ang += (R() - 0.5) * 0.25
                px += cos(ang); py -= sin(ang)
                let ww = max(1, Int(w.rounded()))
                C.rect(Int(px) - ww / 2, Int(py), ww, 1, bark)
                if sin(ang) < 0.9 && R() < 0.5 { C[Int(px), Int(py) - 1] = SnowPx(mat: SNOW, v: L(1.9), d: 0.6) }   // 가지 윗면 눈
            }
            guard depth > 0 else { return }
            let n = depth > 3 ? 2 : 2 + Int(R() * 2)
            for _ in 0..<n { branch(px, py, ang + (R() - 0.5) * 1.5, len * (0.55 + R() * 0.2), w * 0.62, depth - 1) }
        }
        let tx = 206.0
        C.rect(Int(tx) - 2, 150, 5, SnowGeo.groundTop + 2 - 150, bark)
        branch(tx, 150, .pi / 2 + 0.15, 30, 4, 5)
        branch(tx, 160, .pi / 2 + 0.9, 24, 3, 4)
        branch(tx, 158, .pi / 2 - 0.8, 26, 3, 4)
        return C
    }

    // MARK: 가장 가까운 실루엣 — 승강장 옆 가로수가 위에서 늘어뜨린 가지(거의 검정 · 윗면에 눈). 하늘 위쪽만 가린다(인물에 닿지 않는다)
    static func branches() -> SnowCanvas {
        var C = SnowCanvas(w: 600, h: 90)
        var rng = SplitMix64(seed: 0xB4A2)
        func R() -> Double { rng.next() }
        let bark = SnowPx(mat: INK, v: L(0.2), d: 0.2)
        func branch(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ w: Double, _ depth: Int) {
            var px = x, py = y, ang = a
            for _ in 0..<Int(len) {
                ang += (R() - 0.5) * 0.3
                px += cos(ang); py += sin(ang)
                guard py < 86 else { return }
                let ww = max(1, Int(w.rounded()))
                C.rect(Int(px) - ww / 2, Int(py), ww, ww > 2 ? 2 : 1, bark)
                let top = Int(py) - (ww > 2 ? 1 : 1)
                if w > 2.6 && R() < 0.8 { C[Int(px), top] = SnowPx(mat: SNOW, v: L(2.2), d: 0.2); if ww > 4 { C[Int(px), top - 1] = SnowPx(mat: SNOW, v: L(1.6), d: 0.2) } }   // 굵은 가지 윗면에만 눈
                else if w > 1.6 && R() < 0.25 { C[Int(px), top] = SnowPx(mat: SNOW, v: L(1.4), d: 0.2) }
            }
            guard depth > 0 else { return }
            for _ in 0..<(2 + Int(R() * 2)) { branch(px, py, ang + (R() - 0.5) * 1.6, len * (0.5 + R() * 0.25), w * 0.6, depth - 1) }
        }
        // 위 가장자리에서 들어오는 큰 가지 셋(카메라 어디서나 하나쯤 보이게)
        branch(-8, 6, 0.28, 70, 8, 6)
        branch(270, -4, 0.95, 40, 7, 5); branch(270, -4, .pi - 0.6, 46, 6, 5)
        branch(608, 8, .pi - 0.3, 74, 8, 6)
        return C
    }

    // MARK: 승강장(가장 가까운 층) — 난간 · 가로등 · 역 이름판 · 가판대 · 눈 바닥 · 앞 모서리
    static func platform() -> SnowCanvas {
        var C = SnowCanvas(w: SnowGeo.W, h: SnowGeo.H)
        let G = SnowGeo.groundTop
        let iron = SnowPx(mat: GIRD, v: L(0.5), tone: 0.35, d: 0.38), ironL = SnowPx(mat: GIRD, v: L(1.3), tone: 0.5, d: 0.38, ny: 0.5)
        let snowTop = { (s: Double) in SnowPx(mat: SNOW, v: L(s), tone: 0.45, d: 0.3, ny: 0.7) }
        // 1) 난간(아래 가림판 · 가로대 둘 · 살 · 위 가로대에 쌓인 눈)
        C.rect(0, G - 8, SnowGeo.W, 8, SnowPx(mat: GIRD, v: L(0.25), tone: 0.3, d: 0.38))   // 아래 가림판(눈 바람막이)
        for x in 0..<SnowGeo.W { if x % 12 == 0 { C[x, G - 8] = ironL } }
        C.rect(0, G - 24, SnowGeo.W, 2, iron); C.rect(0, G - 25, SnowGeo.W, 1, ironL)
        C.rect(0, G - 15, SnowGeo.W, 1, iron)
        for x in stride(from: 2, to: SnowGeo.W, by: 5) { C.rect(x, G - 22, 1, 14, iron) }
        for x in 0..<SnowGeo.W {   // 위 가로대 눈: 1~3px 울퉁불퉁 · 군데군데 흘러내린 고드름
            let hh = 1 + Int(n1(Double(x) / 9, 41) * 2.6)
            for k in 0..<hh { C[x, G - 26 - k] = snowTop(k == hh - 1 ? 4.0 : 3.1) }
            if h(x, 1, 42) < 0.05 { C[x, G - 22] = SnowPx(mat: TEAL, v: L(3.0), tone: 0.4, d: 0.38); if h(x, 2, 42) < 0.5 { C[x, G - 21] = SnowPx(mat: TEAL, v: L(2.2), tone: 0.4, d: 0.38) } }
            if h(x, 3, 42) < 0.5 { C[x, G - 16] = snowTop(2.6) }   // 가운데 가로대에도 눈
        }
        // 2) 가로등(웹 POLES 자리 98 · 240 · 382 — 기둥 회전차기를 그대로 쓴다): 기둥 · 받침 · 거위목 팔 · 갓 · 나트륨 등 · 갓 위 눈
        for lx in SnowGeo.lamps.map({ Int($0) }) {
            C.rect(lx - 1, 70, 3, G - 70, iron); C[lx - 1, 70] = ironL
            for y in 70..<G where y % 2 == 0 { C[lx - 1, y] = ironL }   // 왼쪽 가장자리 빛
            C.rect(lx - 3, G - 6, 7, 6, iron); C.rect(lx - 3, G - 7, 7, 1, snowTop(3.4))
            C.rect(lx - 2, 100, 5, 2, ironL)
            // 거위목 팔(오른쪽으로 휘어 등을 단다)
            for (dx, dy) in [(0, 0), (1, -1), (2, -2), (3, -2), (4, -2), (5, -2), (6, -1), (7, 0)] { C[lx + dx, 68 + dy] = iron; C[lx + dx, 67 + dy] = snowTop(3.0) }
            let hx = lx + 7
            C.rect(hx - 4, Int(SnowGeo.lampY) - 2, 9, 2, iron)                  // 갓
            C.rect(hx - 5, Int(SnowGeo.lampY) - 3, 11, 1, snowTop(3.8))         // 갓 위 눈
            C.rect(hx - 2, Int(SnowGeo.lampY), 5, 2, SnowPx(mat: SOD, v: 1.0, d: 0.38))   // 등(발광)
            C.rect(hx - 1, Int(SnowGeo.lampY) + 2, 3, 1, SnowPx(mat: SOD, v: L(4.6), d: 0.38))
        }
        // 3) 역 이름판(검은 판 · 흰 글자 '46 ST' · 보라 7 원) — 기둥 둘
        let sx = Int(SnowGeo.signX), sy = 96
        C.rect(sx - 22, sy + 16, 2, G - sy - 16, iron); C.rect(sx + 20, sy + 16, 2, G - sy - 16, iron)
        C.rect(sx - 24, sy, 48, 16, SnowPx(mat: INK, v: L(0.4), tone: 0.3, d: 0.38))
        C.rect(sx - 24, sy - 1, 48, 1, snowTop(3.6)); C.rect(sx - 23, sy - 2, 40, 1, snowTop(3.0))
        C.rect(sx - 24, sy + 16, 48, 1, ironL)
        // 7 원(지름 9)
        let bx = sx - 16, by = sy + 8
        for yy in -4...4 { for xx in -4...4 where xx * xx + yy * yy <= 18 { C[bx + xx, by + yy] = SnowPx(mat: LINE7, v: L(3.6), d: 0.38) } }
        for (gx, gy) in [(-2, -2), (-1, -2), (0, -2), (1, -2), (1, -1), (0, 0), (0, 1), (-1, 2)] { C[bx + gx, by + gy] = SnowPx(mat: EYE, v: L(4.2), d: 0.38) }
        text(&C, "46 ST", sx - 8, sy + 2, SnowPx(mat: EYE, v: L(3.6), d: 0.38))
        text(&C, "BLISS", sx - 8, sy + 9, SnowPx(mat: STEEL, v: L(2.6), d: 0.38))
        // 4) 가판대(기둥 320 옆 · 난간 앞): 지붕 눈 · 주황 불빛 창 · 잡지 줄 · 철 덧문
        let kx = Int(SnowGeo.kioskX) + 6, ky = G - 44
        C.rect(kx, ky, 34, 44, SnowPx(mat: GIRD, v: L(0.8), tone: 0.45, d: 0.36))
        C.rect(kx - 2, ky - 3, 38, 3, SnowPx(mat: GIRD, v: L(1.5), tone: 0.5, d: 0.36, ny: 0.4))   // 처마
        for x in (kx - 3)..<(kx + 37) { let hh = 2 + Int(n1(Double(x) / 5, 51) * 2.2); for k in 0..<hh { C[x, ky - 4 - k] = snowTop(k == hh - 1 ? 4.2 : 3.3) } }
        C.rect(kx + 3, ky + 4, 28, 14, SnowPx(mat: SOD, v: L(4.0), d: 0.36))                        // 불 켜진 창
        for (i, c) in [RED, LINE7, TAXI, STEEL, RED, GOLD, LINE7].enumerated() { C.rect(kx + 4 + i * 4, ky + 11, 3, 6, SnowPx(mat: c, v: L(2.8), tone: 0.3, d: 0.36)) }   // 잡지 표지
        C.rect(kx + 3, ky + 4, 28, 1, SnowPx(mat: SOD, v: L(4.8), d: 0.36))
        C.rect(kx + 3, ky + 18, 28, 1, SnowPx(mat: SNOW, v: L(3.2), tone: 0.4, d: 0.36))            // 창턱 눈
        C.rect(kx + 3, ky + 22, 28, 18, SnowPx(mat: GIRD, v: L(0.6), tone: 0.4, d: 0.36))           // 덧문
        for y in stride(from: ky + 23, to: ky + 40, by: 2) { C.rect(kx + 3, y, 28, 1, SnowPx(mat: GIRD, v: L(1.2), tone: 0.5, d: 0.36, ny: 0.3)) }
        text(&C, "NEWS", kx + 9, ky - 2, SnowPx(mat: SOD, v: L(4.4), d: 0.36))
        // 5) 눈 바닥(재질 SNOWF — 셰이더가 순한 디더로 자른다): 넓고 매끈한 값 구역 + 일부러 둔 덩어리
        //    가로등 밑 밝은 윗면(빛 웅덩이가 데운다) · 앞으로 갈수록 짙은 파랑 · 바람결 둔덕(밝은 윗줄 + 그늘 아랫줄) · 다져진 길(살짝 짙고 매끈) · 기둥 밑 그늘
        //    윗선(난간과 만나는 곳)은 둥근 더미 + 윗면 빛. 값은 단 단위로 정하고 1/8 단으로 잘라 둔다(같은 값 가로 줄이 길게 이어져 사각형이 적다)
        let F = SnowFloor.table
        for x in 0..<SnowGeo.W {
            for y in F.edge[x]..<SnowGeo.lip { if let p = F.px(x, y) { C[x, y] = p } }
        }
        // 앞 모서리: 눈 처마(둥근 이마 빛 → 아래로 늘어진 덩이) · 노란 점자 띠가 군데군데 · 콘크리트 턱 · 고드름 몇 · 아래 어둠(선로 · 레일에 눈)
        let lip = SnowGeo.lip
        for x in 0..<SnowGeo.W {
            let hang = SnowFloor.hang(x)   // 처마가 턱 아래로 늘어진 길이 0..2
            C[x, lip] = F.snow(x, lip, 0.9, ny: -0.3)
            for k in 0..<hang { C[x, lip + 1 + k] = F.snow(x, lip + 1 + k, k == hang - 1 ? 0.15 : 0.55, ny: -0.6) }
            for y in (lip + 1 + hang)..<(lip + 5) { C[x, y] = SnowPx(mat: GIRD, v: L(x % 16 == 0 ? 0.9 : y == lip + 1 + hang ? 0.35 : 0.55), tone: 0.3, d: 0.12) }
            if h(x / 3, 7, 71) < 0.16 && h(x, 8, 71) < 0.7 { C[x, lip - 3] = SnowPx(mat: TAXI, v: L(1.6), tone: 0.35, d: 0.12) }   // 눈 사이로 보이는 점자 띠
            for y in (lip + 5)..<SnowGeo.H where C[x, y] == nil { C[x, y] = SnowPx(mat: INK, v: L(0.15), tone: 0.2, d: 0.12) }
            for ry in [lip + 12, lip + 17] where C[x, ry]?.mat == INK { C[x, ry] = SnowPx(mat: STEEL, v: L(0.6), tone: 0.35, d: 0.12, ny: 0.6); C[x, ry - 1] = SnowPx(mat: SNOW, v: L(1.8), tone: 0.35, d: 0.12) }
        }
        // 고드름: 처마 밑에 드문드문(굵은 뿌리 → 가늘게 · 왼쪽 1px 빛)
        for x in 2..<(SnowGeo.W - 2) where h(x, 9, 72) < 0.06 && h(x - 1, 9, 72) >= 0.06 && h(x - 2, 9, 72) >= 0.06 {
            let top = lip + 1 + SnowFloor.hang(x), n = 2 + Int(h(x, 10, 72) * 5)
            for k in 0..<n {
                let lit = k < n - 1 ? 3.3 - Double(k) * 0.35 : 2.0
                C[x, top + k] = SnowPx(mat: TEAL, v: L(lit), tone: 0.45, d: 0.12, ny: 0.2)
                if k < n / 2 { C[x + 1, top + k] = SnowPx(mat: TEAL, v: L(1.9), tone: 0.35, d: 0.12) }   // 뿌리는 2px(오른쪽은 그늘)
            }
            C[x, top + n] = SnowPx(mat: SNOW, v: L(3.0), tone: 0.6, d: 0.12)   // 끝 물방울 반짝
        }
        return C
    }

    /// 3×5(작게면 3×4) 글자
    static func text(_ C: inout SnowCanvas, _ s: String, _ x: Int, _ y: Int, _ p: SnowPx, small: Bool = false) {
        let G: [Character: [String]] = [
            "4": ["101", "101", "111", "001", "001"], "6": ["111", "100", "111", "101", "111"], "S": ["111", "100", "111", "001", "111"],
            "T": ["111", "010", "010", "010", "010"], "B": ["110", "101", "110", "101", "110"], "L": ["100", "100", "100", "100", "111"],
            "I": ["111", "010", "010", "010", "111"], "N": ["101", "111", "111", "101", "101"], "E": ["111", "100", "110", "100", "111"],
            "W": ["101", "101", "101", "111", "101"], " ": ["000", "000", "000", "000", "000"],
        ]
        var cx = x
        for ch in s {
            guard let g = G[ch] else { cx += 4; continue }
            let rows = small ? [g[0], g[1], g[3], g[4]] : g
            for (r, row) in rows.enumerated() { for (c, b) in row.enumerated() where b == "1" { C[cx + c, y + r] = p } }
            cx += ch == " " ? 2 : 4
        }
    }
}
