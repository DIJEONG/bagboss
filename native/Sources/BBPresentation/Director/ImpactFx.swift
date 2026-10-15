import Foundation
import BBCore
import BBContent
import BBSim

// 네이티브 바닥 충격(docs/10 §4.1) — 철산고 · 도끼 꽂힘 · 무거운 내려찍기(groundImpact · fx axring/tsring).
// 웹은 HUD 벡터(검은 굵은 선 균열 · 주황 타원 고리 · 회색 먼지)로 그린다 → 깃발 켜짐(nativeMoves)에서는 그 HUD 그림을 빼고
// 무대 픽셀(G-버퍼 3D 쿼드 — 무대 조명 · 팔레트 램프 · 디더를 그대로 받는다)로 바닥 면에 그린다. 깃발 꺼짐 = 웹 그대로.
//  · 바닥 재질별: 객차(금속 판) = 움푹 눌린 자국(뒷벽 그늘 · 앞 테 빛) + 짧은 주름 선 · 무도장(나무) = 결 따라 갈라짐 + 나뭇조각 ·
//    승강장 · 타워 · 건널목(돌) = 갈래 치는 균열 + 빛 쪽 깨진 가장자리 + 돌 부스러기. 눈은 SnowFx(균열 없음 — 눌린 구덩이)
//  · 바닥은 낮은 각도로 보인다 → 균열은 좌우로 길고 세로는 아주 조금(원근). 1.6~2초에 걸쳐 픽셀 디더로 사라진다
//  · 충격 고리: 바닥 면의 옅은 공기 · 먼지 고리(0.25초 · 체크 디더 · 바닥 재질 색). 주황은 없다
// 표현 몫 — 씨앗 고정 · 게임 시간으로만 흐른다.

struct ImpactFx {
    enum Floor { case metal, wood, stone, snow }
    /// 바닥 자국 픽셀(오프셋 · 밝기 종류 0 그늘 선 · 1 빛 가장자리 · 2 얕은 안쪽) · 사라지는 문턱
    struct Px { var dx: Int, dy: Int, kind: UInt8, thr: Float, grow: Float }
    struct Decal { var x: Int, y: Int, age: Double, life: Double, floor: Floor, px: [Px] }
    struct Chip { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, gy: Double, wide: Bool, bounced: Bool }
    struct Dust { var x: Double, y: Double, vx: Double, age: Double, life: Double, r: Double }
    struct Ring { var x: Double, y: Double, age: Double, life: Double, r1: Double }

    var decals: [Decal] = [], chips: [Chip] = [], dusts: [Dust] = [], rings: [Ring] = []
    var floor: Floor = .metal
    var calm = false
    var rng = SplitMix64(seed: 0x1A9C7)
    mutating func R() -> Double { rng.next() }

    var isEmpty: Bool { decals.isEmpty && chips.isEmpty && dusts.isEmpty && rings.isEmpty }

    // MARK: 재질

    /// 그늘 선 · 빛 가장자리 · 얕은 안쪽 · 부스러기 · 먼지 재질
    static func mats(_ f: Floor) -> (line: Int, lit: Int, inner: Int, chip: Int, dust: Int) {
        switch f {
        case .metal: return (7, 8, 22, 8, 17)        // DARK · STEEL · MDARK · STEEL · CONC
        case .wood: return (47, 11, 47, 11, 11)      // WOODD · WOOD
        case .stone: return (1, 38, 7, 38, 17)       // INK · STONEL · DARK · STONEL · CONC
        case .snow: let S = NativePalette.SNOW; return (S, S, S, S, S)
        }
    }

    // MARK: 계기

    /// 바닥 충격: 자국(눈 제외) · 부스러기 · 먼지
    mutating func impact(_ x: Double, _ y: Double, power p0: Double) {
        let p = min(2.2, max(0.3, p0))
        if floor != .snow && p >= 1.0 { decals.append(Decal(x: Int(x.rounded()), y: Int(y.rounded()), age: 0, life: 1.6 + 0.25 * p, floor: floor, px: shape(p))) }
        guard floor != .snow else { return }   // 눈: 덩이 · 가루 · 구덩이는 SnowFx
        let nc = Int((3 + 4 * p) * (calm ? 0.6 : 1))
        for _ in 0..<nc {
            let side: Double = R() < 0.5 ? -1 : 1
            chips.append(Chip(x: x + side * R() * 6, y: y - 1, vx: side * (25 + R() * 70) * (0.7 + 0.3 * p), vy: -(50 + R() * 90) * (0.7 + 0.3 * p),
                              age: 0, life: 0.9 + R() * 0.4, gy: y + (R() - 0.5) * 4, wide: floor == .wood && R() < 0.6, bounced: false))
        }
        for i in 0..<Int(4 + 4 * p) {
            let side: Double = i % 2 == 0 ? 1 : -1
            dusts.append(Dust(x: x + side * R() * 8, y: y - 1 - R() * 2, vx: side * (10 + R() * 30) * p, age: -R() * 0.06, life: 0.45 + R() * 0.3, r: 1.2 + R() * 1.2))
        }
        if chips.count > 80 { chips.removeFirst(chips.count - 80) }
        if dusts.count > 80 { dusts.removeFirst(dusts.count - 80) }
        if decals.count > 8 { decals.removeFirst(decals.count - 8) }
    }

    /// 벽꿍(네이티브 잡아 메치기 · 수플렉스가 벽에 꽂힘 · 날아간 적이 벽에 부딪힘 — fx 'wallImpact'): 벽면 자국 · 벽에서 튀는 부스러기 · 먼지 기둥.
    ///  · 자국은 바닥 자국 모양을 세워(가로 ↔ 세로) 벽면에 — 객차 판 = 세로로 눌린 자국 + 주름 · 무도장 나무 판벽 = 결(세로) 따라 갈라짐 · 타워 · 돌 = 갈래 균열
    ///  · 눈 승강장(끝 난간 · 기둥): 자국 없이 난간에 쌓인 눈이 털려 떨어진다(눈덩이 · 가루)
    ///  · dir = 벽 쪽(+1 오른쪽 벽) — 부스러기는 반대쪽으로 튄다. gy = 바닥 높이
    mutating func wall(_ x: Double, _ y: Double, dir: Double, power p0: Double, gy: Double) {
        let p = min(2.2, max(0.6, p0)), d: Double = dir >= 0 ? 1 : -1
        if floor != .snow {
            let px = shape(p).map { Px(dx: Int((Double($0.dy) * 0.8).rounded()), dy: $0.dx, kind: $0.kind, thr: $0.thr, grow: $0.grow) }   // 세운다(벽면은 세로로 길게)
            decals.append(Decal(x: Int((x - d).rounded()), y: Int(y.rounded()), age: 0, life: 2.2 + 0.25 * p, floor: floor, px: px))
            if decals.count > 8 { decals.removeFirst(decals.count - 8) }
        }
        let snowy = floor == .snow
        let nc = Int((snowy ? 18 : 5 + 3 * p) * (calm ? 0.6 : 1))
        for _ in 0..<nc {   // 벽에서 떨어져 나와 바깥(반대쪽)으로 튀고 바닥에서 한 번 튄다 — 눈은 위(난간)에서 털려 천천히
            let yy = snowy ? y - 6 - R() * 16 : y + (R() - 0.5) * 12
            chips.append(Chip(x: x - d * (1 + R() * 3), y: yy, vx: -d * (snowy ? 10 + R() * 30 : 30 + R() * 70), vy: snowy ? -(R() * 30) : -(20 + R() * 70),
                              age: 0, life: snowy ? 1.2 + R() * 0.5 : 0.9 + R() * 0.4, gy: gy + (R() - 0.5) * 3, wide: (floor == .wood || snowy) && R() < 0.6, bounced: false))
        }
        for i in 0..<Int((5 + 3 * p) * (snowy ? 2 : 1)) {   // 먼지: 맞은 자리 둘레 + 벽 밑(눈 = 난간에서 털린 눈가루 — 더 크고 많이)
            let up = i % 2 == 0
            dusts.append(Dust(x: x - d * (2 + R() * 6), y: up ? y - (snowy ? 4 + R() * 12 : (R() - 0.5) * 10) : gy - 1, vx: -d * (8 + R() * 22), age: -R() * 0.05,
                              life: (snowy ? 0.8 : 0.5) + R() * 0.35, r: (snowy ? 2.2 : 1.4) + R() * (snowy ? 2.2 : 1.4)))
        }
        if chips.count > 80 { chips.removeFirst(chips.count - 80) }
        if dusts.count > 80 { dusts.removeFirst(dusts.count - 80) }
    }

    /// 충격 고리(웹 axring · tsring 자리) — 바닥 면 공기 · 먼지 고리
    mutating func ring(_ x: Double, _ y: Double, big: Bool) {
        rings.append(Ring(x: x, y: y, age: 0, life: 0.26, r1: big ? 46 : 36))
        if rings.count > 6 { rings.removeFirst() }
    }

    /// 자국 모양(원점 기준 픽셀) — 재질별
    mutating func shape(_ p: Double) -> [Px] {
        var out: [Px] = []
        var seen = Set<Int>()
        func put(_ dx: Int, _ dy: Int, _ k: UInt8, _ g: Double) {
            let key = (dx + 512) << 10 | (dy + 512)
            guard !seen.contains(key) else { return }
            seen.insert(key); out.append(Px(dx: dx, dy: dy, kind: k, thr: Float(R()), grow: Float(g)))
        }
        switch floor {
        case .metal:
            // 눌린 판: 납작한 타원 — 뒷벽(위 호) 그늘 · 앞 테(아래 호) 빛 · 안쪽 얕게 + 좌우로 짧은 주름 선
            let rx = 7 + 3 * p, ry = 1.6 + 0.5 * p
            for dy in -Int(ceil(ry))...Int(ceil(ry)) { for dx in -Int(ceil(rx))...Int(ceil(rx)) {
                let e = pow(Double(dx) / rx, 2) + pow(Double(dy) / ry, 2)
                guard e <= 1.05 else { continue }
                let edge = e > 0.5
                put(dx, dy, edge ? (dy < 0 ? 0 : dy > 0 ? 1 : 2) : 2, e * 0.5)
            } }
            for _ in 0..<(3 + Int(p)) {   // 주름: 가장자리에서 바깥으로 1px 짙은 줄(옆에 빛 1px)
                let side: Double = R() < 0.5 ? -1 : 1
                var X = side * (rx - 1), Y = (R() - 0.5) * 2 * ry
                let n = 3 + Int(R() * (4 + 3 * p)), sl = (R() - 0.5) * 0.5
                for k in 0..<n { X += side; Y += sl; put(Int(X.rounded()), Int(Y.rounded()), 0, 0.5 + Double(k) * 0.08); if k % 2 == 0 { put(Int(X.rounded()), Int(Y.rounded()) + 1, 1, 0.5 + Double(k) * 0.08) } }
            }
        case .wood, .stone, .snow:
            // 갈래 치는 균열: 가운데 깨진 자리 → 좌우로 길게(세로는 조금) · 빛 쪽(위 — 등 · 천장 빛) 1px 깨진 가장자리
            let wood = floor == .wood
            for dx in -2...2 { put(dx, 0, 0, 0); if abs(dx) < 2 { put(dx, -1, 2, 0) } }
            put(-1, 1, 1, 0); put(1, 1, 1, 0)
            func crack(_ x0: Double, _ y0: Double, _ dir: Double, _ len: Int, _ depth: Int, _ g0: Double) {
                var X = x0, Y = y0
                var slope = wood ? 0 : (R() - 0.5) * 0.3
                for k in 0..<len {
                    X += dir
                    if wood { if R() < 0.08 { Y += R() < 0.5 ? -1 : 1 } }   // 나무: 결 따라 거의 곧게(가끔 옆 판자로 한 칸)
                    else { slope += (R() - 0.5) * 0.18; slope = max(-0.22, min(0.22, slope)); Y += slope }
                    let ix = Int(X.rounded()), iy = Int(Y.rounded()), g = g0 + Double(k) * 0.035
                    put(ix, iy, 0, g)
                    if R() < 0.4 { put(ix, iy - 1, 1, g) }                     // 빛 쪽 깨진 가장자리
                    if depth > 0 && k > 2 && R() < 0.11 { crack(X, Y, dir, max(2, (len - k) / 2), depth - 1, g) }   // 곁가지
                }
            }
            let n = 2 + Int(p * 1.5)
            for i in 0..<n {
                let dir: Double = i % 2 == 0 ? 1 : -1
                crack(dir * 2, (R() - 0.5) * 1.4, dir, Int(8 + R() * (8 + 9 * p)), wood ? 1 : 2, 0)
            }
        }
        return out
    }

    // MARK: 흐름

    mutating func advance(_ dt: Double, wind: Double = 0) {
        guard dt > 0, !isEmpty else { return }
        for i in decals.indices { decals[i].age += dt }
        decals.removeAll { $0.age > $0.life }
        for i in chips.indices {
            var c = chips[i]
            c.age += dt; c.vy += 420 * dt; c.x += c.vx * dt; c.y += c.vy * dt
            if c.vy > 0 && c.y >= c.gy { if c.bounced { c.y = c.gy; c.vx *= 0.5; c.vy = 0 } else { c.y = c.gy; c.vy *= -0.3; c.vx *= 0.6; c.bounced = true } }
            chips[i] = c
        }
        chips.removeAll { $0.age > $0.life }
        for i in dusts.indices { dusts[i].age += dt; dusts[i].x += (dusts[i].vx + wind * 0.3) * dt; dusts[i].vx *= exp(-3 * dt); dusts[i].y -= 6 * dt }
        dusts.removeAll { $0.age > $0.life }
        for i in rings.indices { rings[i].age += dt }
        rings.removeAll { $0.age > $0.life }
    }

    // MARK: 그리기

    /// 바닥 자국(배경 바로 앞 · 그림자보다 먼저 — backMesh)
    func decalMesh(z: Double = 0.9838) -> [Float] {
        guard !decals.isEmpty else { return [] }
        var m = SnowQuads(quads: decals.reduce(0) { $0 + $1.px.count })
        for d in decals {
            let M = Self.mats(d.floor)
            let grow = d.age / 0.09   // 0.09초에 걸쳐 가운데서 바깥으로 뻗는다
            let fade = Float(max(0, (d.age - 0.35) / (d.life - 0.35)))   // 0.35초 뒤부터 낱 픽셀 디더로 사라진다
            for q in d.px where Double(q.grow) <= grow && q.thr >= fade {
                let (mat, tone, emit): (Int, Double, Double) = q.kind == 0 ? (M.line, 0.25, 0.0) : q.kind == 1 ? (M.lit, d.floor == .metal ? 0.95 : 0.7, d.floor == .metal ? 0.3 : 0.05) : (M.inner, 0.45, 0.02)
                m.run(d.x + q.dx, d.y + q.dy, 1, mat: mat, tone: tone, z: z, d: 0.15, emit: emit, ny: q.kind == 1 ? 0.8 : q.kind == 0 ? -0.4 : 0.2)
            }
        }
        return m.f
    }

    /// 부스러기 · 먼지 · 충격 고리(인물과 깊이 검사 — 고리 앞 호는 발 앞, 뒤 호는 뒤)
    func mesh(floorOverride: Floor? = nil) -> [Float] {
        guard !(chips.isEmpty && dusts.isEmpty && rings.isEmpty) else { return [] }
        let M = Self.mats(floorOverride ?? floor)
        var m = SnowQuads(quads: chips.count * 2 + dusts.count * 9 + rings.count * 90)
        for c in chips {
            let z = 0.9 - c.gy / 300 - 0.03, u = c.age / c.life
            if u > 0.7 && (Int(c.x) + Int(c.y)) & 1 == 0 { continue }
            m.run(Int(c.x.rounded()), Int(c.y.rounded()), c.wide ? 2 : 1, mat: M.chip, tone: 0.8, z: z, d: 0.15, emit: 0.08, ny: 0.6)
            if !c.bounced && !c.wide { m.run(Int(c.x.rounded()), Int(c.y.rounded()) + 1, 1, mat: M.line, tone: 0.3, z: z, d: 0.15, emit: 0, ny: -0.3) }
        }
        for d in dusts where d.age >= 0 {
            let u = d.age / d.life, r = d.r + 1.6 * min(1, u * 1.5), ri = Int(ceil(r))
            let x = Int(d.x.rounded()), y = Int(d.y.rounded()), z = 0.9 - d.y / 300 - 0.02
            for oy in -ri...0 { for ox in -ri...ri where Double(ox * ox + oy * oy * 3) <= r * r {
                guard (x + ox + y + oy) & 1 == 0, !(u > 0.6 && (x + ox) & 2 == 0) else { continue }
                m.run(x + ox, y + oy, 1, mat: M.dust, tone: 0.55, z: z, d: 0.15, emit: 0.06 * (1 - u), ny: 0.4)
            } }
        }
        // 고리: 납작한 타원 테(가로 r · 세로 r × 0.2) — 가는 체크 디더 점, 바깥으로 퍼지며 옅어진다
        for g in rings {
            let u = g.age / g.life, e = 1 - pow(1 - u, 2.2)
            let rx = 6 + (g.r1 - 6) * e, ry = max(1.5, rx * 0.2)
            let n = Int(rx * 2.2)
            let keep = calm ? 0.35 : 0.6 * (1 - u) + 0.15
            for i in 0..<n {
                let a = Double(i) / Double(n) * .pi * 2
                let X = Int((g.x + cos(a) * rx).rounded()), Y = Int((g.y + sin(a) * ry).rounded())
                let hsh = Double(UInt32(truncatingIfNeeded: (X &* 73856093) ^ (Y &* 19349663) ^ i) % 1000) / 1000
                guard hsh < keep else { continue }
                let z = 0.9 - Double(Y) / 300 + (sin(a) > 0 ? -0.05 : 0.05)
                m.run(X, Y, 1, mat: M.dust == NativePalette.SNOW ? M.dust : M.chip, tone: 0.8, z: z, d: 0.15, emit: (calm ? 0.12 : 0.3) * (1 - u), ny: 0.6)
            }
        }
        return m.f
    }
}
