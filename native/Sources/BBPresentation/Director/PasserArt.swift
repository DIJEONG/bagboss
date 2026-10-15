import Foundation

// 무도장 깊이(docs/10 §10) — 카메라 앞을 지나가는 행인 그림. 무대 픽셀 크기(1px = 장면 1px)로 직접 찍는다(벡터 흐림 덩어리가 아니라 픽셀 실루엣).
//  · 인물(키 ≈ 52px)보다 카메라에 가까워 ≈ 1.9배(발 → 정수리 100px) — 발은 화면 아래 밖, 화면 가장자리에서 잘린다
//  · 옆모습 걷기: 다리 둘이 엇갈려 다리 사이 틈이 열고 닫힘 · 무릎 굽힘 · 디딤마다 위아래 들썩 · 어깨 흔들림 · 팔 흔들기(반대 위상)
//    우산은 들썩임이 반 박자 늦게 · 코트 자락 · 목도리 꼬리가 펄럭 · 추위 속 입김(두 걸음마다)
//  · 빛: 거의 검은 실루엣 + 가로등 쪽 가장자리 따뜻한 테 · 우산 천이 등빛을 받아 옅게 데워짐 · 어깨 · 우산 · 모자 위 쌓인 눈 하이라이트
//  · 결과는 미리 곱한 RGBA(W×H). 렌더러가 postFS 에서 흐린 뒤(가까운 초점 밖) 24단 베이어로 자른다(원경과 같은 픽셀 DOF)

enum PasserKind: Int, CaseIterable, Sendable {
    case umbrella = 0, coatScarf, parka, pair
    /// 점검 띠 이름표(영문 — 화면에 나오지 않는다)
    var name: String { ["umbrella", "long coat + scarf", "hooded parka", "pair"][rawValue] }
}

struct PasserArt {
    static let W = 112, H = 144
    /// 발 기준점(캔버스 안) — 장면에서 이 점이 발 자리에 온다
    static let footX = 56, footY = 138

    /// 발 기준점 뒤로 몸이 나가는 길이(장면 px — 우산 반지름 · 목도리 꼬리 · 뒷사람)
    static func backExtent(_ k: PasserKind) -> Double { [31.0, 19, 16, 36][k.rawValue] }

    // 부위(색 · 빛 처리용)
    private enum P: UInt8 { case none = 0, body, coat, scarf, canopy, shaft, hood, back, puff }

    private var m = [UInt8](repeating: 0, count: W * H)

    private mutating func set(_ x: Int, _ y: Int, _ p: P) {
        guard x >= 0, y >= 0, x < Self.W, y < Self.H else { return }
        if p == .back, m[y * Self.W + x] != 0 { return }   // 뒷사람은 앞사람 뒤로
        m[y * Self.W + x] = p.rawValue
    }
    private func at(_ x: Int, _ y: Int) -> P {
        guard x >= 0, y >= 0, x < Self.W, y < Self.H else { return .none }
        return P(rawValue: m[y * Self.W + x]) ?? .none
    }
    private mutating func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ p: P) {
        for y in Int(floor(cy - ry))...Int(ceil(cy + ry)) { for x in Int(floor(cx - rx))...Int(ceil(cx + rx)) {
            let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1 { set(x, y, p) }
        } }
    }
    /// 굵은 선(둥근 끝)
    private mutating func limb(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ w0: Double, _ w1: Double, _ p: P) {
        let n = max(1, Int(hypot(x1 - x0, y1 - y0) * 2))
        for i in 0...n { let u = Double(i) / Double(n); let r = (w0 + (w1 - w0) * u) / 2
            ellipse(x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, r, r, p) }
    }
    /// 볼록하지 않아도 되는 다각형(짝홀 규칙)
    private mutating func poly(_ pts: [(Double, Double)], _ p: P) {
        let ys = pts.map(\.1), y0 = Int(floor(ys.min()!)), y1 = Int(ceil(ys.max()!))
        for y in y0...y1 {
            let Y = Double(y) + 0.5; var xs: [Double] = []
            for i in pts.indices { let a = pts[i], b = pts[(i + 1) % pts.count]
                if (a.1 <= Y) != (b.1 <= Y) { xs.append(a.0 + (Y - a.1) / (b.1 - a.1) * (b.0 - a.0)) } }
            xs.sort()
            var k = 0; while k + 1 < xs.count { for x in Int((xs[k]).rounded())..<Int((xs[k + 1]).rounded()) { set(x, y, p) }; k += 2 }
        }
    }

    /// 사람 하나(옆모습 · +x 쪽을 본다). ox = 발 기준 가로 오프셋 · ph = 걸음 위상(라디안) · t = 초 · s = 크기
    private mutating func person(_ kind: PasserKind, ox: Double, ph: Double, t: Double, s: Double, back: Bool, umbrella: Bool) {
        let fx = Double(Self.footX) + ox, fy = Double(Self.footY)
        func X(_ v: Double) -> Double { fx + v * s }
        func Y(_ v: Double) -> Double { fy + v * s }
        let body: P = back ? .back : .body, coat: P = back ? .back : .coat
        let bob = 1.6 * (abs(cos(ph)) - 0.5)                    // 다리가 모일 때(한 발 디딤 한가운데) 몸이 가장 높다
        let sway = 0.8 * sin(ph)
        let hipY = -47 - bob, hipX = 0.5 + sway * 0.3
        // 다리: 위상 ψ 의 발 x = 11·sin ψ, 앞으로 나가는(cos ψ > 0) 발은 들린다 → 무릎이 앞으로 굽는다
        for (k, psi) in [ph, ph + .pi].enumerated() {
            let fxL = 13 * sin(psi), lift = max(0, cos(psi)) * 6
            let footYv = -lift * 0.9, kneeX = (hipX + fxL) / 2 + 2.5 + lift * 0.5, kneeY = (hipY + footYv) / 2 - lift * 0.4
            let p: P = (k == 1 && !back) ? body : body
            limb(X(hipX), Y(hipY), X(kneeX), Y(kneeY), 10 * s, 8 * s, p)
            limb(X(kneeX), Y(kneeY), X(fxL), Y(footYv - 2.5), 8 * s, 6.5 * s, p)
            limb(X(fxL - 2), Y(footYv - 1.6), X(fxL + 6), Y(footYv - 1.2), 4.4 * s, 4.6 * s, p)   // 신발
        }
        let shY = -80 - bob, lean = 1.6
        switch kind {
        case .parka:
            // 부푼 파카(짧은 자락) · 후드
            let hem = -50 - bob + 0.6 * sin(ph * 2)
            ellipse(X(-1 + sway * 0.3), Y(shY + 6), 12.5 * s, 9 * s, coat)                                         // 부푼 어깨
            poly([(X(-11 + sway * 0.4), Y(shY + 4)), (X(10 + lean), Y(shY + 4)), (X(13 + lean * 0.6), Y(shY + 16)), (X(12.5), Y(hem)),
                  (X(-12.5), Y(hem + 0.8)), (X(-13.5), Y(shY + 16))], coat)
            for yy in stride(from: shY + 12, to: hem - 2, by: 8) { ellipse(X(-12.8), Y(yy), 1.4 * s, 2.4 * s, coat); ellipse(X(12.6 + lean * 0.5), Y(yy + 3), 1.2 * s, 2.2 * s, coat) }   // 누빔 불룩
            poly([(X(-9), Y(shY + 2)), (X(-11.5), Y(shY - 8)), (X(-6), Y(shY - 17)), (X(3 + lean), Y(shY - 18.5)), (X(10 + lean), Y(shY - 12)),
                  (X(11 + lean), Y(shY - 4)), (X(8 + lean), Y(shY + 2))], back ? .back : .hood)                     // 후드(뒤가 불룩 · 목이 묻힌다)
            ellipse(X(-7.5), Y(shY - 6), 4.5 * s, 7 * s, back ? .back : .hood)
        default:
            // 롱코트(무릎 아래 자락 — 디딤에 맞춰 뒤 자락이 펄럭)
            let hemY = -34 - bob, flap = 1.6 * sin(ph * 2 + 0.8) + 0.8 * sin(t * 7.3)
            ellipse(X(-0.5 + sway * 0.3), Y(shY + 4), 10 * s, 6 * s, coat)                                         // 둥근 어깨
            poly([(X(-9.5 + sway * 0.4), Y(shY + 3)), (X(8.5 + lean), Y(shY + 3)), (X(10 + lean), Y(shY + 18)), (X(13 + max(0, sin(ph)) * 2.5), Y(hemY + 0.5)),
                  (X(1), Y(hemY + 1.6)), (X(-14 - flap), Y(hemY + 0.8 + 0.6 * flap)), (X(-11), Y(shY + 20))], coat)
            ellipse(X(-1), Y(-50 - bob), 11 * s, 6 * s, coat)                                                      // 허리 아래 엉덩이 둘레(자락이 다리 위로)
            limb(X(-2 + lean), Y(shY - 2), X(1.5 + lean), Y(shY - 6), 6.5 * s, 6.5 * s, body)                     // 목
            ellipse(X(2 + lean), Y(shY - 12.5), 7 * s, 8.3 * s, body)                                               // 머리
            ellipse(X(0.5 + lean), Y(shY - 17), 7.2 * s, 4.6 * s, body)                                             // 머리칼 · 모자
            if kind == .coatScarf || kind == .pair && back {
                limb(X(-5 + lean), Y(shY - 1), X(6 + lean), Y(shY - 1), 5 * s, 5 * s, back ? .back : .scarf)       // 목도리
                let f = sin(t * 8.1 + ph) * 2, f2 = sin(t * 11.3) * 1.2
                poly([(X(-5), Y(shY - 2)), (X(-12 - f * 0.4), Y(shY + 3 + f)), (X(-17 - f), Y(shY + 10 + f + f2)), (X(-14 - f), Y(shY + 12 + f)), (X(-4), Y(shY + 4))],
                     back ? .back : .scarf)                                                                          // 꼬리(바람에 뒤로)
            }
        }
        // 팔: 우산 든 팔은 들어 올린 채, 아니면 다리와 반대로 흔든다(롱코트 · 목도리는 주머니에 손 — 작게)
        let swing = kind == .coatScarf ? 0.16 : 0.62
        if umbrella {
            limb(X(1 + lean), Y(shY + 3), X(9), Y(shY + 16), 5.5 * s, 5 * s, coat)
            limb(X(9), Y(shY + 16), X(8), Y(shY + 4), 5 * s, 4.4 * s, coat)
            ellipse(X(8), Y(shY + 3), 2.6 * s, 2.6 * s, body)
            limb(X(-1), Y(shY + 4), X(-1 - 20 * sin(-sin(ph) * swing)), Y(shY + 4 + 26 * cos(sin(ph) * swing)), 5.5 * s, 4.6 * s, coat)
        } else {
            for (k, sg) in [1.0, -1.0].enumerated() where !(back && k == 1) {
                let a = -sin(ph) * swing * sg
                let ex = 0.5 + 13 * sin(a), ey = shY + 3 + 13 * cos(a), hx = ex + 13 * sin(a * 1.6 + 0.15), hy = ey + 13 * cos(a * 1.6 + 0.15)
                limb(X(0.5), Y(shY + 3), X(ex), Y(ey), 6 * s, 5.4 * s, coat); limb(X(ex), Y(ey), X(hx), Y(hy), 5.4 * s, 4.6 * s, coat)
                ellipse(X(hx), Y(hy + 1), 2.4 * s, 2.6 * s, body)
            }
        }
        if umbrella {
            // 우산: 들썩임이 반 박자 늦게 · 손잡이 → 대 → 덮개(살 끝 물결) · 위로 좀 기울어 앞으로
            let lag = 1.6 * (abs(cos(ph - 0.6)) - 0.5), cy = shY - 25 - lag, cx = 5.0
            limb(X(8), Y(shY + 4), X(cx), Y(cy), 1.6 * s, 1.6 * s, .shaft)
            var pts: [(Double, Double)] = []
            for i in 0...24 { let a = Double.pi + Double.pi * Double(i) / 24; pts.append((X(cx + 29 * cos(a)), Y(cy + 15 * sin(a)))) }
            for i in stride(from: 8, through: 0, by: -1) {   // 살 끝 물결(아래 가장자리)
                let u = Double(i) / 8; pts.append((X(cx - 29 + 58 * u), Y(cy + (i % 2 == 0 ? 1.5 : -0.8))))
            }
            poly(pts, .canopy)
            limb(X(cx), Y(cy - 15), X(cx), Y(cy - 19), 1.4 * s, 1.4 * s, .shaft)   // 꼭지
        }
    }

    /// 한 프레임 그림. phase = 걸음 위상(라디안 — 한 바퀴 = 두 걸음) · facing = 걷는 쪽(+1 오른쪽) · light = 가로등 쪽(+1 오른쪽) · warmK = 등빛 세기
    static func render(_ kind: PasserKind, phase: Double, t: Double, facing: Double, light: Double, warmK: Double = 1) -> [UInt8] {
        var A = PasserArt()
        switch kind {
        case .umbrella: A.person(.umbrella, ox: 0, ph: phase, t: t, s: 1, back: false, umbrella: true)
        case .coatScarf: A.person(.coatScarf, ox: 0, ph: phase, t: t, s: 1, back: false, umbrella: false)
        case .parka: A.person(.parka, ox: 0, ph: phase, t: t, s: 1, back: false, umbrella: false)
        case .pair:
            A.person(.coatScarf, ox: 0, ph: phase, t: t, s: 1, back: false, umbrella: false)
            A.person(.parka, ox: -19, ph: phase + 1.4, t: t, s: 0.94, back: true, umbrella: false)   // 뒷사람(조금 작고 덜 검다)
        }
        // 입김: 두 걸음마다 얼굴 앞에서 퍼져 흩어진다(0.7초)
        let breathAge = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 1.05
        let headY = Double(footY) - 92, headX = Double(footX) + 9
        if breathAge < 0.7, kind != .pair || true {
            let u = breathAge / 0.7
            for j in 0..<4 { let r = 1.6 + 3.2 * u + Double(j % 2)
                A.ellipse(headX + 3 + 9 * u + Double(j) * 2.2, headY + 2 - 4 * u - Double(j), r, r * 0.8, .puff) }
        }
        let puffA = breathAge < 0.7 ? 0.42 * (1 - breathAge / 0.7) : 0
        // 좌우: 캔버스는 +x 를 보는 그림 → 왼쪽으로 걸으면 발 기준점을 축으로 뒤집는다
        var out = [UInt8](repeating: 0, count: W * H * 4)
        let ls = light * facing >= 0 ? 1 : -1   // 그림 좌표에서 등 쪽
        func col(_ x: Int, _ y: Int) -> (Double, Double, Double, Double)? {
            let p = A.at(x, y); guard p != .none else { return nil }
            if p == .puff { return (0.78 * puffA, 0.82 * puffA, 0.92 * puffA, puffA) }
            var c: (Double, Double, Double)
            switch p {
            case .back: c = (0.07, 0.075, 0.11)
            case .scarf: c = (0.17, 0.045, 0.05)
            case .canopy: c = (0.05, 0.05, 0.085)
            case .shaft: c = (0.11, 0.1, 0.1)
            default: c = (0.032, 0.036, 0.07)
            }
            func empty(_ dx: Int, _ dy: Int) -> Bool { let q = A.at(x + dx, y + dy); return q == .none || q == .puff }
            let rimK = p == .back ? 0.45 : 1.0
            // 등 쪽 테(1px 진하게 · 2px 옅게)
            if empty(ls, 0) { c = mix(c, (0.66, 0.38, 0.18), 0.78 * rimK * warmK) }
            else if empty(2 * ls, 0) { c = mix(c, (0.46, 0.26, 0.13), 0.38 * rimK * warmK) }
            // 우산 천: 등 쪽 · 위쪽이 빛을 받아 데워진다
            if p == .canopy {
                var cx0 = x, n = 0; while A.at(cx0 - 1, y) == .canopy { cx0 -= 1 }; while A.at(cx0 + n, y) == .canopy { n += 1 }
                let u = Double(x - cx0) / Double(max(1, n - 1)), side = ls > 0 ? u : 1 - u
                c = mix(c, (0.26, 0.17, 0.12), 0.45 * side * side * warmK)
            }
            // 위로 열린 자리 = 쌓인 눈(어깨 · 우산 · 후드 · 머리) — 두 줄
            let top = empty(0, -1), top2 = !top && empty(0, -2)
            if top || top2 {
                let snowy = p == .canopy || p == .hood || p == .coat || p == .back || (p == .body && y < footY - 95)
                if snowy { c = mix(c, (0.7, 0.76, 0.9), (top ? 0.8 : 0.35) * (p == .back ? 0.6 : 1)) }
                else { c = mix(c, (0.3, 0.36, 0.55), 0.35) }   // 하늘빛 윗테
            }
            return (c.0, c.1, c.2, 1)
        }
        for y in 0..<H { for x in 0..<W {
            let lx = x - Int((Double(footY - y) * 0.045).rounded())   // 걷는 몸이 앞으로 조금 기운다(위로 갈수록 앞)
            let sx = facing >= 0 ? lx : 2 * footX - x - Int((Double(footY - y) * 0.045).rounded())
            guard let c = col(sx, y) else { continue }
            let d = (y * W + x) * 4   // 미리 곱한 RGBA
            out[d] = UInt8(min(255, c.0 * 255)); out[d + 1] = UInt8(min(255, c.1 * 255)); out[d + 2] = UInt8(min(255, c.2 * 255)); out[d + 3] = UInt8(c.3 * 255)
        } }
        return out
    }
    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ k: Double) -> (Double, Double, Double) {
        let u = max(0, min(1, k)); return (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u)
    }
}
