import Foundation
import simd
import BBContent

// 오버레이 그리기 목록(웹 `#ui` 캔버스 2D 를 대신하는 순수 값) — BBRender OverlayRenderer 가 Metal 로 그린다.
// 좌표는 UI 캔버스 픽셀(웹 uiCv: VW·UIS × H·UIS, UIS = 3, 위→아래). 색은 곧은(미리 곱하지 않은) RGBA.
//
// 그리기 방식(캔버스 의미 그대로):
//   · direct  — 사각형 · 그림(아틀라스 텍셀) 쿼드. 겹침이 없거나 겹쳐도 캔버스와 같은 것만(fillRect · drawImage · 글자)
//   · 경로 채우기 — 스텐실에 감김 수(nonzero) 쓰기 → 덮개(bbox) 한 번 칠하고 스텐실 지움. 겹친 하위 경로 · 반투명도 캔버스와 같다
//   · 경로 선   — 선 · 이음 · 끝 삼각형을 스텐실에 '1' 로 쓰기 → 덮개(겹친 이음이 두 번 섞이지 않는다)
//   · 자르기(clip) — 스텐실 최상위 비트(0x80). 안쪽 그리기는 그 비트를 검사한다(웹 panel() 의 cx.clip())
// 정점: x · y · u · v(아틀라스 텍셀 단위) · r · g · b · a · 선형 표본(0 = 최근접, 1 = 선형)

public struct OverlayBatch: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// 색을 바로 쓴다
        case direct
        /// 스텐실 감김 쓰기(앞면 +1 · 뒷면 −1) — 색 없음
        case stencilFill
        /// 스텐실에 1 쓰기 — 색 없음
        case stencilStroke
        /// 스텐실 낮은 비트 ≠ 0 인 곳만 칠하고 지운다
        case cover
        /// 자르기 비트 세우기 · 지우기 — 색 없음
        case clipSet, clipClear
    }
    public var kind: Kind
    public var first: Int, count: Int
    /// 자르기 안쪽에서만 그리는가(direct · cover)
    public var clipped: Bool
}

public struct OverlayList: Sendable {
    /// UI 캔버스 크기(픽셀)
    public var width: Int, height: Int
    /// 정점 9 float 씩
    public var vertices: [Float] = []
    public var batches: [OverlayBatch] = []
    public static let stride = 9
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public var vertexCount: Int { vertices.count / Self.stride }
    public var isEmpty: Bool { batches.isEmpty }

    mutating func push(_ kind: OverlayBatch.Kind, clipped: Bool, _ emit: (inout [Float]) -> Void) {
        let n0 = vertexCount
        emit(&vertices)
        let n = vertexCount - n0
        guard n > 0 else { return }
        if kind == .direct, var last = batches.last, last.kind == .direct, last.clipped == clipped, last.first + last.count == n0 {
            last.count += n; batches[batches.count - 1] = last; return
        }
        batches.append(OverlayBatch(kind: kind, first: n0, count: n, clipped: clipped))
    }
}

/// 곧은 RGBA(0..1)
public struct RGBA: Sendable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static let white = RGBA(1, 1, 1), black = RGBA(0, 0, 0), clear = RGBA(0, 0, 0, 0)
    /// CSS 색: #rgb · #rrggbb · rgba(r,g,b,a) · rgb(r,g,b)
    public init(css s: String) {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#") {
            let h = Array(t.dropFirst())
            func hx(_ c: Character) -> Double { Double(c.hexDigitValue ?? 0) }
            if h.count == 3 { self.init(hx(h[0]) * 17 / 255, hx(h[1]) * 17 / 255, hx(h[2]) * 17 / 255); return }
            if h.count >= 6 { self.init((hx(h[0]) * 16 + hx(h[1])) / 255, (hx(h[2]) * 16 + hx(h[3])) / 255, (hx(h[4]) * 16 + hx(h[5])) / 255); return }
        }
        if let o = t.firstIndex(of: "("), let c = t.lastIndex(of: ")") {
            let v = t[t.index(after: o)..<c].split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            if v.count >= 3 { self.init(v[0] / 255, v[1] / 255, v[2] / 255, v.count > 3 ? v[3] : 1); return }
        }
        self.init(0, 0, 0)
    }
}

/// 2D 아핀 변환(캔버스 setTransform(a,b,c,d,e,f)): x' = a·x + c·y + e, y' = b·x + d·y + f
public struct Affine: Sendable, Equatable {
    public var a = 1.0, b = 0.0, c = 0.0, d = 1.0, e = 0.0, f = 0.0
    public init() {}
    public init(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f }
    public func apply(_ x: Double, _ y: Double) -> SIMD2<Double> { [a * x + c * y + e, b * x + d * y + f] }
    /// 오른쪽에 곱하기(캔버스 translate · rotate · scale 은 현재 변환 뒤에 붙는다)
    public func then(_ m: Affine) -> Affine {
        Affine(a * m.a + c * m.b, b * m.a + d * m.b, a * m.c + c * m.d, b * m.c + d * m.d, a * m.e + c * m.f + e, b * m.e + d * m.f + f)
    }
    /// 선 굵기 배율(균등 배율 가정)
    public var scale: Double { sqrt(abs(a * d - b * c)) }
    public var isAxisAligned: Bool { b == 0 && c == 0 }
}

public enum LineCap: Sendable { case butt, round, square }
public enum LineJoin: Sendable { case miter, round, bevel }
public enum TextAlign: Sendable { case left, center, right }
public enum TextBaseline: Sendable { case alphabetic, middle, top }

/// 캔버스 2D 흉내(웹 uiCx 호출을 거의 그대로 옮길 수 있게). 결과는 `list`.
public struct OverlayPainter {
    public var list: OverlayList
    public let atlas: OverlayAtlas
    struct State {
        var m = Affine()
        var alpha = 1.0
        var fill = RGBA.black, stroke = RGBA.black
        var fillGradient: (y0: Double, y1: Double, c0: RGBA, c1: RGBA)?
        var lineWidth = 1.0
        var cap = LineCap.butt, join = LineJoin.miter
        var dash: [Double] = []
        var font = HUDFont.galmuri11(10)
        var align = TextAlign.left, baseline = TextBaseline.alphabetic
        var smoothing = true
        var clipped = false
    }
    var st = State()
    var stack: [State] = []
    /// 지금 경로(장치 좌표 — 캔버스처럼 점을 넣을 때의 변환으로 바뀐다)
    var subpaths: [[SIMD2<Double>]] = []
    var closedFlags: [Bool] = []
    var clipDepth = 0

    public init(width: Int, height: Int, atlas: OverlayAtlas) {
        list = OverlayList(width: width, height: height); self.atlas = atlas
    }

    // MARK: 상태

    public mutating func save() { stack.append(st) }
    public mutating func restore() {
        guard let s = stack.popLast() else { return }
        if st.clipped && !s.clipped { clearClip() }
        st = s
    }
    public mutating func setTransform(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) { st.m = Affine(a, b, c, d, e, f) }
    public mutating func translate(_ x: Double, _ y: Double) { st.m = st.m.then(Affine(1, 0, 0, 1, x, y)) }
    public mutating func scale(_ x: Double, _ y: Double) { st.m = st.m.then(Affine(x, 0, 0, y, 0, 0)) }
    public mutating func rotate(_ r: Double) { let c = cos(r), s = sin(r); st.m = st.m.then(Affine(c, s, -s, c, 0, 0)) }
    public var transform: Affine { st.m }
    public var globalAlpha: Double { get { st.alpha } set { st.alpha = newValue } }
    public mutating func fillStyle(_ c: String) { st.fill = RGBA(css: c); st.fillGradient = nil }
    public mutating func fillStyle(_ c: RGBA) { st.fill = c; st.fillGradient = nil }
    /// 세로 선형 그라디언트(웹 createLinearGradient(0,y0,0,y1) — 글자 채우기에만 쓴다)
    public mutating func fillGradient(y0: Double, y1: Double, _ c0: String, _ c1: String) { st.fillGradient = (y0, y1, RGBA(css: c0), RGBA(css: c1)); st.fill = RGBA(css: c1) }
    public mutating func strokeStyle(_ c: String) { st.stroke = RGBA(css: c) }
    public var lineWidth: Double { get { st.lineWidth } set { st.lineWidth = newValue } }
    public var lineCap: LineCap { get { st.cap } set { st.cap = newValue } }
    public var lineJoin: LineJoin { get { st.join } set { st.join = newValue } }
    public mutating func setLineDash(_ d: [Double]) { st.dash = d }
    public var font: HUDFont { get { st.font } set { st.font = newValue } }
    public var textAlign: TextAlign { get { st.align } set { st.align = newValue } }
    public var textBaseline: TextBaseline { get { st.baseline } set { st.baseline = newValue } }
    public var imageSmoothingEnabled: Bool { get { st.smoothing } set { st.smoothing = newValue } }

    // MARK: 정점

    private func color(_ c: RGBA) -> RGBA { RGBA(c.r, c.g, c.b, c.a * st.alpha) }
    private static func vtx(_ v: inout [Float], _ p: SIMD2<Double>, _ uv: SIMD2<Double>, _ c: RGBA, _ lin: Float) {
        v += [Float(p.x), Float(p.y), Float(uv.x), Float(uv.y), Float(c.r), Float(c.g), Float(c.b), Float(c.a), lin]
    }
    /// 단색 삼각형 목록 → 정점(아틀라스 흰 텍셀)
    private static func tris(_ v: inout [Float], _ pts: [SIMD2<Double>], _ c: RGBA) {
        let w = OverlayAtlas.whiteUV
        for p in pts { vtx(&v, p, w, c, 0) }
    }
    private static func quadTris(_ p0: SIMD2<Double>, _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>) -> [SIMD2<Double>] { [p0, p1, p2, p0, p2, p3] }

    // MARK: 사각형

    public mutating func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        guard w != 0, h != 0 else { return }
        let c = color(st.fill); guard c.a > 0 else { return }
        let m = st.m
        let q = Self.quadTris(m.apply(x, y), m.apply(x + w, y), m.apply(x + w, y + h), m.apply(x, y + h))
        list.push(.direct, clipped: st.clipped) { Self.tris(&$0, q, c) }
    }
    public mutating func strokeRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        beginPath(); moveTo(x, y); lineTo(x + w, y); lineTo(x + w, y + h); lineTo(x, y + h); closePath(); stroke()
    }

    // MARK: 경로

    public mutating func beginPath() { subpaths = []; closedFlags = [] }
    public mutating func moveTo(_ x: Double, _ y: Double) { subpaths.append([st.m.apply(x, y)]); closedFlags.append(false); lastUser = [x, y] }
    public mutating func lineTo(_ x: Double, _ y: Double) {
        if subpaths.isEmpty { moveTo(x, y); return }
        subpaths[subpaths.count - 1].append(st.m.apply(x, y)); lastUser = [x, y]
    }
    public mutating func closePath() {
        guard !subpaths.isEmpty else { return }
        closedFlags[closedFlags.count - 1] = true
        if let f = subpaths.last?.first { subpaths.append([f]); closedFlags.append(false) }   // 닫은 뒤 새 하위 경로는 시작점에서
    }
    /// 호 조각 수: 장치 반지름에 비례(약 2px 마디)
    private func segs(_ r: Double, _ sweep: Double) -> Int {
        let rd = r * st.m.scale
        return max(4, min(256, Int((abs(sweep) * max(rd, 1) / 2).rounded(.up))))
    }
    public mutating func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ rot: Double, _ a0: Double, _ a1: Double, _ ccw: Bool = false) {
        guard rx >= 0, ry >= 0 else { return }
        // 캔버스: 시계 방향이면 a1 이 a0 보다 작으면 2π 를 더한다(한 바퀴 넘으면 한 바퀴로)
        var e = a1
        if !ccw { if a1 - a0 >= 2 * .pi { e = a0 + 2 * .pi } else { while e < a0 { e += 2 * .pi } } }
        else { if a0 - a1 >= 2 * .pi { e = a0 - 2 * .pi } else { while e > a0 { e -= 2 * .pi } } }
        let sweep = e - a0, n = segs(max(rx, ry), sweep)
        let cr = cos(rot), sr = sin(rot)
        for i in 0...n {
            let t = a0 + sweep * Double(i) / Double(n)
            let px = cos(t) * rx, py = sin(t) * ry
            let x1 = x + px * cr - py * sr, y1 = y + px * sr + py * cr
            if i == 0 && (subpaths.isEmpty) { moveTo(x1, y1) } else { lineTo(x1, y1) }
        }
    }
    public mutating func arc(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ ccw: Bool = false) { ellipse(x, y, r, r, 0, a0, a1, ccw) }
    /// 캔버스 arcTo(x1,y1,x2,y2,r) — 지금 점(사용자 좌표로 되돌리지 않고 마지막 점의 사용자 좌표를 따로 기억)
    private var lastUser: SIMD2<Double>?
    public mutating func arcTo(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ r: Double) {
        guard let p0 = lastUser else { moveTo(x1, y1); return }
        let v1 = SIMD2(p0.x - x1, p0.y - y1), v2 = SIMD2(x2 - x1, y2 - y1)
        let l1 = (v1 * v1).sum().squareRoot(), l2 = (v2 * v2).sum().squareRoot()
        guard l1 > 0, l2 > 0, r > 0 else { lineTo(x1, y1); return }
        let u1 = v1 / l1, u2 = v2 / l2
        let cosT = max(-1, min(1, (u1 * u2).sum())), th = acos(cosT)
        guard th > 1e-6, th < .pi - 1e-6 else { lineTo(x1, y1); return }
        let d = r / tan(th / 2)
        let t1 = SIMD2(x1, y1) + u1 * d, t2 = SIMD2(x1, y1) + u2 * d
        let bis = (u1 + u2) / ((u1 + u2) * (u1 + u2)).sum().squareRoot()
        let c = SIMD2(x1, y1) + bis * (r / sin(th / 2))
        lineTo(t1.x, t1.y)
        let a0 = atan2(t1.y - c.y, t1.x - c.x), a1 = atan2(t2.y - c.y, t2.x - c.x)
        let cross = u1.x * u2.y - u1.y * u2.x
        ellipseCont(c.x, c.y, r, a0, a1, cross > 0)
    }
    private mutating func ellipseCont(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ ccw: Bool) {
        var e = a1
        if !ccw { while e < a0 { e += 2 * .pi } } else { while e > a0 { e -= 2 * .pi } }
        let n = segs(r, e - a0)
        for i in 1...n { let t = a0 + (e - a0) * Double(i) / Double(n); lineTo(x + cos(t) * r, y + sin(t) * r) }
    }

    /// 채우기(nonzero) — 스텐실 감김 → 덮개
    public mutating func fill() {
        let c = color(st.fill); guard c.a > 0 else { return }
        var tri: [SIMD2<Double>] = []
        for sp in subpaths where sp.count >= 3 {
            let o = sp[0]
            for i in 1..<(sp.count - 1) { tri += [o, sp[i], sp[i + 1]] }
        }
        guard !tri.isEmpty else { return }
        emitStencilCover(.stencilFill, tri, c)
    }
    /// 단순 볼록 경로를 바로 칠한다(겹침 없는 볼록 다각형 — 스텐실 생략. 덮개와 같은 결과)
    public mutating func fillConvexDirect() {
        let c = color(st.fill); guard c.a > 0 else { return }
        var tri: [SIMD2<Double>] = []
        for sp in subpaths where sp.count >= 3 { let o = sp[0]; for i in 1..<(sp.count - 1) { tri += [o, sp[i], sp[i + 1]] } }
        guard !tri.isEmpty else { return }
        list.push(.direct, clipped: st.clipped) { Self.tris(&$0, tri, c) }
    }

    public mutating func stroke() {
        let c = color(st.stroke); guard c.a > 0 else { return }
        let w = st.lineWidth * st.m.scale
        guard w > 0 else { return }
        var tri: [SIMD2<Double>] = []
        for (k, sp0) in subpaths.enumerated() {
            var sp = sp0
            // 같은 점 겹침 제거
            sp = sp.enumerated().filter { $0.offset == 0 || pdist(sp[$0.offset - 1], $0.element) > 1e-9 }.map(\.element)
            let closed = closedFlags[k]
            if closed, sp.count > 1, pdist(sp[0], sp[sp.count - 1]) < 1e-9 { sp.removeLast() }
            guard sp.count >= 2 else { continue }
            if !st.dash.isEmpty {
                for d in dashed(sp + (closed ? [sp[0]] : []), st.dash.map { $0 * st.m.scale }) { tri += Self.strokeGeometry(d, closed: false, w: w, cap: st.cap, join: st.join) }
            } else {
                tri += Self.strokeGeometry(sp, closed: closed, w: w, cap: st.cap, join: st.join)
            }
        }
        guard !tri.isEmpty else { return }
        emitStencilCover(.stencilStroke, tri, c)
    }

    private mutating func emitStencilCover(_ kind: OverlayBatch.Kind, _ tri: [SIMD2<Double>], _ c: RGBA) {
        var lo = SIMD2<Double>(repeating: .infinity), hi = SIMD2<Double>(repeating: -.infinity)
        for p in tri { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        lo = (lo - 1).rounded(.down); hi = (hi + 1).rounded(.up)
        guard hi.x > 0, hi.y > 0, lo.x < Double(list.width), lo.y < Double(list.height) else { return }
        list.push(kind, clipped: false) { Self.tris(&$0, tri, c) }
        let q = Self.quadTris(lo, [hi.x, lo.y], hi, [lo.x, hi.y])
        list.push(.cover, clipped: st.clipped) { Self.tris(&$0, q, c) }
    }

    /// 점선 나누기(장치 좌표 길이)
    private func dashed(_ pts: [SIMD2<Double>], _ pattern: [Double]) -> [[SIMD2<Double>]] {
        var out: [[SIMD2<Double>]] = [], cur: [SIMD2<Double>] = []
        var di = 0, left = pattern[0], on = true
        if on { cur = [pts[0]] }
        for i in 1..<pts.count {
            var a = pts[i - 1]; let b = pts[i]
            var seg = pdist(a, b)
            while seg > 0 {
                let step = min(seg, left)
                let p = a + (b - a) * (step / pdist(a, b))
                if on { cur.append(p) }
                seg -= step; left -= step; a = p
                if left <= 1e-9 {
                    if on { if cur.count >= 2 { out.append(cur) }; cur = [] } else { cur = [a] }
                    on.toggle(); di = (di + 1) % pattern.count; left = pattern[di]
                    if on { cur = [a] }
                }
            }
        }
        if on && cur.count >= 2 { out.append(cur) }
        return out
    }

    /// 선 기하(장치 좌표): 마디 사각형 + 이음 + 끝
    static func strokeGeometry(_ p: [SIMD2<Double>], closed: Bool, w: Double, cap: LineCap, join: LineJoin) -> [SIMD2<Double>] {
        let h = w / 2
        var t: [SIMD2<Double>] = []
        let n = p.count
        let segN = closed ? n : n - 1
        func dir(_ i: Int) -> SIMD2<Double> { let a = p[i % n], b = p[(i + 1) % n]; let d = b - a; let l = (d * d).sum().squareRoot(); return l > 0 ? d / l : [1, 0] }
        func fan(_ c: SIMD2<Double>, _ a0: Double, _ a1: Double) {
            var e = a1; while e < a0 { e += 2 * .pi }
            let k = max(2, min(64, Int(((e - a0) * max(h, 1) / 1.5).rounded(.up))))
            for i in 0..<k {
                let t0 = a0 + (e - a0) * Double(i) / Double(k), t1 = a0 + (e - a0) * Double(i + 1) / Double(k)
                t += [c, c + SIMD2(cos(t0), sin(t0)) * h, c + SIMD2(cos(t1), sin(t1)) * h]
            }
        }
        for i in 0..<segN {
            let a = p[i], b = p[(i + 1) % n], d = dir(i), nn = SIMD2(-d.y, d.x) * h
            t += quadTris(a + nn, b + nn, b - nn, a - nn)
        }
        // 이음
        let joints = closed ? Array(0..<n) : Array(1..<(n - 1))
        for i in joints {
            let d0 = dir((i - 1 + n) % n), d1 = dir(i), c = p[i]
            let cross = d0.x * d1.y - d0.y * d1.x
            if abs(cross) < 1e-9 && (d0 * d1).sum() > 0 { continue }
            switch join {
            case .round:
                fan(c, 0, 2 * .pi)
            case .miter, .bevel:
                // 바깥쪽 꼭짓점 둘 + (미터면) 교점
                let s: Double = cross > 0 ? -1 : 1
                let n0 = SIMD2(-d0.y, d0.x) * h * s, n1 = SIMD2(-d1.y, d1.x) * h * s
                t += [c, c + n0, c + n1]
                if join == .miter {
                    let m = n0 + n1, ml = (m * m).sum().squareRoot()
                    if ml > 1e-9 {
                        let cosHalf = max(1e-6, ml / (2 * h))
                        let miterLen = h / cosHalf
                        if miterLen / h <= 10 { let tip = c + m / ml * miterLen; t += [c + n0, tip, c + n1] }
                    }
                }
            }
        }
        // 끝
        if !closed {
            for (pt, d) in [(p[0], -dir(0)), (p[n - 1], dir(n - 2))] {
                switch cap {
                case .butt: break
                case .round: let a = atan2(d.y, d.x); fan(pt, a - .pi / 2, a + .pi / 2)
                case .square:
                    let nn = SIMD2(-d.y, d.x) * h
                    t += quadTris(pt + nn, pt + nn + d * h, pt - nn + d * h, pt - nn)
                }
            }
        }
        return t
    }

    // MARK: 자르기

    /// 지금 경로로 자른다(웹 cx.clip() — save/restore 짝 안에서만 쓴다. 겹친 자르기는 쓰지 않는다)
    public mutating func clip() {
        var tri: [SIMD2<Double>] = []
        for sp in subpaths where sp.count >= 3 { let o = sp[0]; for i in 1..<(sp.count - 1) { tri += [o, sp[i], sp[i + 1]] } }
        guard !tri.isEmpty else { return }
        list.push(.clipSet, clipped: false) { Self.tris(&$0, tri, .white) }
        st.clipped = true
    }
    private mutating func clearClip() {
        let W = Double(list.width), H = Double(list.height)
        list.push(.clipClear, clipped: false) { Self.tris(&$0, Self.quadTris([0, 0], [W, 0], [W, H], [0, H]), .white) }
    }

    // MARK: 그림(아틀라스)

    /// 아틀라스 칸 그리기(웹 drawImage(img, sx, sy, sw, sh, x, y, w, h)) — 최근접(imageSmoothingEnabled=false)
    public mutating func drawImage(_ e: OverlayAtlas.Entry, sx: Double = 0, sy: Double = 0, sw: Double? = nil, sh: Double? = nil,
                                   _ x: Double, _ y: Double, _ w: Double, _ h: Double, linear: Bool? = nil) {
        let sw = sw ?? Double(e.w), sh = sh ?? Double(e.h)
        let c = RGBA(1, 1, 1, st.alpha); guard c.a > 0, w != 0, h != 0 else { return }
        let m = st.m
        let u0 = Double(e.x) + sx, v0 = Double(e.y) + sy, u1 = u0 + sw, v1 = v0 + sh
        let p = [m.apply(x, y), m.apply(x + w, y), m.apply(x + w, y + h), m.apply(x, y + h)]
        let uv: [SIMD2<Double>] = [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]
        let lin: Float = (linear ?? st.smoothing) ? 1 : 0
        list.push(.direct, clipped: st.clipped) { v in for i in [0, 1, 2, 0, 2, 3] { Self.vtx(&v, p[i], uv[i], c, lin) } }
    }

    // MARK: 글자

    /// 글자 번역 자리(웹 00-i18n 이 CanvasRenderingContext2D.fillText · strokeText · measureText 를 감싼 것과 같은 한 곳).
    /// 기본은 BBContent Loc.tr — 한국어 모드면 그대로 돌려준다. 시험에서 바꿔 끼울 수 있다
    nonisolated(unsafe) public static var translate: @Sendable (String) -> String = { Loc.tr($0) }

    public func measureText(_ s: String) -> Double { HUDText.shared.measure(Self.translate(s), st.font) }

    public mutating func fillText(_ s: String, _ x: Double, _ y: Double) { text(Self.translate(s), x, y, stroke: nil) }
    public mutating func strokeText(_ s: String, _ x: Double, _ y: Double) { text(Self.translate(s), x, y, stroke: st.lineWidth) }

    private mutating func text(_ s: String, _ x: Double, _ y: Double, stroke: Double?) {
        guard !s.isEmpty else { return }
        let base = stroke == nil ? (st.fillGradient == nil ? st.fill : .white) : st.stroke
        let c0 = color(base); guard c0.a > 0 else { return }
        let m = st.m, sc = m.scale
        guard sc > 0 else { return }
        let spec = st.font
        let w = HUDText.shared.measure(s, spec)
        let met = HUDText.shared.metrics(spec)
        let ox: Double = st.align == .left ? 0 : st.align == .center ? -w / 2 : -w
        let oy: Double = st.baseline == .alphabetic ? 0 : st.baseline == .top ? met.ascent : (met.ascent - met.descent) / 2
        // 장치 배율로 굽는다(회전 · 비균등은 쿼드로)
        let key = HUDText.RasterKey(text: s, font: spec, deviceScale: (sc * 4).rounded() / 4, stroke: stroke.map { ($0 * 4).rounded() / 4 })
        guard let g = HUDText.shared.raster(key, atlas: atlas) else { return }
        let ds = key.deviceScale
        // 그림 원점(사용자 좌표): 기준선 왼쪽 = (x + ox, y + oy). 그림 칸은 기준선 왼쪽에서 (originX, originY) 장치 픽셀 떨어짐
        let ux = x + ox - g.originX / ds, uy = y + oy - g.originY / ds
        let uw = Double(g.entry.w) / ds, uh = Double(g.entry.h) / ds
        let axis = m.isAxisAligned && abs(m.a - ds) < 1e-6 && abs(m.d - ds) < 1e-6
        var p = [m.apply(ux, uy), m.apply(ux + uw, uy), m.apply(ux + uw, uy + uh), m.apply(ux, uy + uh)]
        if axis {   // 축 정렬 · 같은 배율: 장치 픽셀에 맞춰 선명하게
            let o = SIMD2(p[0].x.rounded(.toNearestOrAwayFromZero), p[0].y.rounded(.down)); let d = o - p[0]; p = p.map { $0 + d }
        }
        let e = g.entry
        let uv: [SIMD2<Double>] = [[Double(e.x), Double(e.y)], [Double(e.x + e.w), Double(e.y)], [Double(e.x + e.w), Double(e.y + e.h)], [Double(e.x), Double(e.y + e.h)]]
        let lin: Float = axis ? 0 : 1
        if let G = st.fillGradient, stroke == nil {
            // 세로 그라디언트: 그림 칸을 y0 · y1 에서 잘라 세 띠로(캔버스는 바깥을 끝 색으로 고정)
            let cuts = [uy, max(uy, min(uy + uh, G.y0)), max(uy, min(uy + uh, G.y1)), uy + uh]
            func col(_ yy: Double) -> RGBA {
                let t = G.y1 == G.y0 ? 1 : max(0, min(1, (yy - G.y0) / (G.y1 - G.y0)))
                return color(RGBA(G.c0.r + (G.c1.r - G.c0.r) * t, G.c0.g + (G.c1.g - G.c0.g) * t, G.c0.b + (G.c1.b - G.c0.b) * t, G.c0.a + (G.c1.a - G.c0.a) * t))
            }
            var bands: [([SIMD2<Double>], [SIMD2<Double>], [RGBA])] = []
            for k in 0..<3 where cuts[k + 1] > cuts[k] {
                let ya = cuts[k], yb = cuts[k + 1]
                let va = Double(e.y) + (ya - uy) / uh * Double(e.h), vb = Double(e.y) + (yb - uy) / uh * Double(e.h)
                let q = [m.apply(ux, ya), m.apply(ux + uw, ya), m.apply(ux + uw, yb), m.apply(ux, yb)]
                let qu: [SIMD2<Double>] = [[Double(e.x), va], [Double(e.x + e.w), va], [Double(e.x + e.w), vb], [Double(e.x), vb]]
                let ca = col(ya), cb = col(yb)
                bands.append((q, qu, [ca, ca, cb, cb]))
            }
            list.push(.direct, clipped: st.clipped) { v in
                for (q, qu, qc) in bands { for i in [0, 1, 2, 0, 2, 3] { Self.vtx(&v, q[i], qu[i], qc[i], 1) } }
            }
            return
        }
        list.push(.direct, clipped: st.clipped) { v in for i in [0, 1, 2, 0, 2, 3] { Self.vtx(&v, p[i], uv[i], c0, lin) } }
    }
}

@inline(__always) func pdist(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { let d = a - b; return (d * d).sum().squareRoot() }
