import Foundation
import BBCore
import BBContent
import BBSim

// 무도장 부서지는 소품 그림 · 파편(네이티브 — World+NativeObj · docs/07 §7-OB). 무대 G-버퍼 3D 층에 1px 쿼드(PixelMesh)로 그린다 → 카메라 · 흔들림 · 조명 · 팔레트를 무대와 함께 받는다.
//  · 유리 부스: 철제 틀(2px) + 받침 · 푸른 유리(사선 반사 두 줄) → 깨지면 틀 가장자리에 들쭉날쭉한 유리 조각만 남고, 금이 간 자국
//  · 나무 상자: 널빤지 + 가새 → 깨지면 낮게 흩어진 널빤지 더미
//  · 장지문: 짙은 나무 살(3×5 칸) + 한지(은은히 빛남) → 깨지면 가운데가 찢겨 뚫린 구멍(테두리 너덜) · 살 몇 개 부러짐
//  · 파편: 깨지는 순간(fx 'objBreak:종류') 유리 조각 · 나무 쪼가리 · 한지 조각을 날린다 — 중력 · 바닥 튕김 · 유리는 바닥에 반짝이며 남는다(1.6~2.4초)
// 모양 난수는 소품 번호 · 파편 번호로 만든 씨앗(결정적 — 게임 시간만).

struct DojoObjFx {
    struct Bit { var x, y, vx, vy, age, life: Double; let mat: Int, tone: Double, w: Int, h: Int, emit: Double, paper: Bool, ph: Double }
    var bits: [Bit] = []
    private var n = 0
    var isEmpty: Bool { bits.isEmpty }

    static let GLASS = 19, FRAME = 20, WOOD = 11, WOODD = 47, DARK = 7, INK = 1, CANVAS = 35, STEEL = 8

    /// 깨짐: 종류별 파편을 뿌린다(x · 소품 가운데 y · 날아온 방향 dir)
    mutating func spawn(kind: String, x: Double, y: Double, dir: Double, gy: Double) {
        n += 1
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: n &* 2654435761 &+ 97))
        func r() -> Double { g.next() }
        let count = kind == "glass" ? 46 : kind == "crate" ? 18 : 22
        for k in 0..<count {
            let u = Double(k) / Double(count)
            switch kind {
            case "glass":
                let big = r() < 0.25
                bits.append(Bit(x: x + (r() - 0.5) * 22, y: y + (u - 0.5) * 56, vx: dir * (30 + r() * 150) + (r() - 0.5) * 70, vy: -(20 + r() * 150),
                                age: 0, life: 1.6 + r() * 0.8, mat: Self.GLASS, tone: 0.6 + r() * 0.4, w: big ? 2 : 1, h: big ? 2 : 1, emit: 0.25 + r() * 0.3, paper: false, ph: r() * 6))
            case "crate":
                let long = r() < 0.5
                bits.append(Bit(x: x + (r() - 0.5) * 18, y: gy - r() * 20, vx: dir * (20 + r() * 110) + (r() - 0.5) * 60, vy: -(40 + r() * 130),
                                age: 0, life: 1.4 + r() * 0.6, mat: r() < 0.5 ? Self.WOOD : Self.WOODD, tone: 0.5 + r() * 0.4, w: long ? 3 : 1, h: long ? 1 : 2, emit: 0, paper: false, ph: r() * 6))
            default:   // 장지문: 한지 조각(느리게 팔랑) + 살 쪼가리
                let paper = r() < 0.75
                bits.append(Bit(x: x + (r() - 0.5) * 16, y: y + (u - 0.5) * 40, vx: dir * (20 + r() * 80) + (r() - 0.5) * 40, vy: -(10 + r() * 70),
                                age: 0, life: 1.6 + r() * 0.8, mat: paper ? Self.CANVAS : Self.WOODD, tone: paper ? 0.8 + r() * 0.15 : 0.5, w: paper ? 2 : 1, h: paper ? 1 : 3,
                                emit: paper ? 0.08 : 0, paper: paper, ph: r() * 6))
            }
        }
        if bits.count > 400 { bits.removeFirst(bits.count - 400) }
    }

    mutating func advance(_ dt: Double, gy: Double) {
        guard dt > 0 else { return }
        for i in bits.indices {
            var b = bits[i]
            b.age += dt
            if b.paper { b.vy += 120 * dt; b.vx *= pow(0.25, dt); b.vy = min(b.vy, 40); b.x += sin(b.age * 9 + b.ph) * 14 * dt }
            else { b.vy += 520 * dt }
            b.x += b.vx * dt; b.y += b.vy * dt
            let floor = gy + (b.ph - 3) * 1.2   // 바닥 줄(앞뒤로 조금 흩어진다)
            if b.y >= floor { b.y = floor; if abs(b.vy) > 40 && !b.paper { b.vy = -b.vy * 0.3; b.vx *= 0.5 } else { b.vy = 0; b.vx *= 0.6 } }
            bits[i] = b
        }
        bits.removeAll { $0.age > $0.life }
    }

    func mesh(z: Double) -> [Float] {
        var m = PixelMesh()
        for b in bits {
            let fade = b.age > b.life - 0.4 ? (b.life - b.age) / 0.4 : 1
            let glint = b.mat == Self.GLASS ? 0.5 + 0.5 * sin(b.age * 14 + b.ph) : 1
            for yy in 0..<b.h { m.run(Int(b.x.rounded()), Int(b.y.rounded()) + yy, b.w, mat: b.mat, tone: b.tone * (0.7 + 0.3 * glint), z: z, d: 0.15, emit: b.emit * glint * fade, ny: 0.5) }
        }
        return m.f
    }

    // MARK: 소품 그림

    /// 놓인 소품 전부(바닥 gy · 깊이 z — 인물보다 조금 뒤)
    static func objects(_ objs: [DojoView.Obj], gy: Double, z: Double) -> [Float] {
        var C = ArtCanvas()
        for o in objs {
            let x = Int(o.x.rounded()), y = Int(gy.rounded())
            switch o.kind {
            case "glass": glass(&C, x, y, o, z)
            case "crate": crate(&C, x, y, o, z)
            default: shoji(&C, x, y, o, z)
            }
        }
        var m = PixelMesh(); C.flush(into: &m); return m.f
    }

    private static func h(_ i: Int, _ s: Int) -> Double { var g = SplitMix64(seed: UInt64(truncatingIfNeeded: i &* 7919 &+ s &* 104729 &+ 31)); return g.next() }

    /// 유리 부스(폭 26 · 높이 66 · 받침 4)
    private static func glass(_ C: inout ArtCanvas, _ x: Int, _ y: Int, _ o: DojoView.Obj, _ z: Double) {
        let W = 13, H = 66, top = y - H
        for dy in 0..<4 { for dx in -W - 1...W + 1 { C[x + dx, y - 1 - dy] = ArtPx(mat: DARK, tone: dy == 3 ? 0.55 : 0.3, z: z, d: 0.3) } }   // 받침
        for yy in top..<(y - 4) {
            for dx in -W...W {
                let edge = dx <= -W + 1 || dx >= W - 1 || yy <= top + 1, mid = yy == top + H / 2 - 4
                if edge || mid { C[x + dx, yy] = ArtPx(mat: FRAME, tone: dx == -W || yy == top ? 0.85 : 0.45, z: z, d: 0.3); continue }
                let r = yy - top, c = dx + W
                if !o.broken {
                    // 유리: 위는 밝고 아래로 갈수록 짙게 · 사선 반사 두 줄(굵은 것 · 가는 것) · 성긴 점무늬로 비쳐 보이게(뒤 배경 대신 어둠)
                    let k = (c + r / 2) % 23, streak = k == 3 || k == 4 || k == 8, dots = (c + r) % 2 == 0
                    let base = 0.72 - Double(r) / Double(H) * 0.3
                    C[x + dx, yy] = streak ? ArtPx(mat: GLASS, tone: 0.97, z: z, d: 0.6, emit: 0.3, nx: 0.2, ny: -0.2)
                                           : ArtPx(mat: GLASS, tone: dots ? base : base - 0.18, z: z, d: 0.6, emit: dots ? 0.1 : 0.03, nx: 0.2, ny: -0.2)
                } else {
                    // 깨짐: 틀 가장자리에서 안쪽으로 뻗은 들쭉날쭉한 조각만 남는다
                    let fromEdge = min(c - 2, 2 * W - 2 - c, r - 2, H - 6 - r)
                    let jag = Int(h(o.id &* 131 &+ r, c / 3) * 5)
                    if fromEdge <= jag { C[x + dx, yy] = ArtPx(mat: GLASS, tone: fromEdge == jag ? 0.95 : 0.5, z: z, d: 0.6, emit: fromEdge == jag ? 0.22 : 0.05) }
                }
            }
        }
    }

    /// 나무 상자(폭 20 · 높이 22)
    private static func crate(_ C: inout ArtCanvas, _ x: Int, _ y: Int, _ o: DojoView.Obj, _ z: Double) {
        let W = 10
        if !o.broken {
            let H = 22
            for r in 0..<H { for dx in -W...W {
                let yy = y - 1 - r, edge = abs(dx) >= W - 1 || r <= 1 || r >= H - 2, plank = r % 6 == 0, brace = abs((dx + W) - r * 2 * W / H) <= 1
                let (mat, tone): (Int, Double) = edge ? (WOODD, r >= H - 2 ? 0.9 : 0.6) : brace ? (WOODD, 0.75) : plank ? (WOODD, 0.5) : (WOOD, 0.72 + Double((dx + W) % 5) * 0.05)
                C[x + dx, yy] = ArtPx(mat: mat, tone: tone, z: z, d: 0.3)
            } }
        } else {   // 낮게 흩어진 널빤지 더미
            for k in 0..<6 {
                let len = 6 + Int(h(o.id, k) * 8), ox = Int((h(o.id, k + 9) - 0.5) * 26), oy = Int(h(o.id, k + 20) * 5), sl = h(o.id, k + 30) < 0.5 ? 0 : 1
                for i in 0..<len { C[x + ox + i - len / 2, y - 1 - oy - (sl == 1 ? i / 4 : 0)] = ArtPx(mat: k % 2 == 0 ? WOOD : WOODD, tone: 0.55, z: z, d: 0.3) }
            }
        }
    }

    /// 장지문(폭 26 · 높이 70)
    private static func shoji(_ C: inout ArtCanvas, _ x: Int, _ y: Int, _ o: DojoView.Obj, _ z: Double) {
        let W = 13, H = 70, top = y - H
        for yy in top..<y {
            for dx in -W...W {
                let r = yy - top, c = dx + W
                let frame = c <= 1 || c >= 2 * W - 1 || r <= 1 || r >= H - 3
                let lattice = c % 9 == 0 || r % 14 == 0
                if frame { C[x + dx, yy] = ArtPx(mat: WOODD, tone: 0.45, z: z, d: 0.3); continue }
                if o.broken {
                    // 가운데 찢긴 구멍(테두리 너덜) — 살도 구멍 안에선 부러져 없다
                    let ex = Double(c - W) / 9.5, ey = Double(r - H / 2 + 2) / 20, d = ex * ex + ey * ey
                    let rag = 0.75 + h(o.id &+ r, c) * 0.5
                    if d < rag * 0.85 { continue }
                    if d < rag { C[x + dx, yy] = ArtPx(mat: CANVAS, tone: 0.65, z: z, d: 0.5, emit: 0.04); continue }
                }
                C[x + dx, yy] = lattice ? ArtPx(mat: WOODD, tone: 0.35, z: z, d: 0.3) : ArtPx(mat: CANVAS, tone: 0.85, z: z, d: 0.6, emit: 0.1)
            }
        }
    }
}
