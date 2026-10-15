import Foundation
import BBCore
import BBSim

// 직장인 세 기술 무대 픽셀(docs/07 §7-OF · 깃발 켜짐에서만 — 규칙 fx 'nv_slam' · 'nv_stamp' · 'nv_stampWall' · 'nv_head' · 'nv_daze').
// 무대 G-버퍼 3D 층에 1px 쿼드(PixelMesh)로 쌓는다 → 카메라 · 흔들림 · 조명 · 팔레트 램프 · 디더를 무대와 함께 받는다.
//  · 서류(내려찍기): 가방이 터지며 A4 · 영수증이 튀어 올라 팔랑이며 떨어진다(앞면 ↔ 모서리 1px 번갈아) → 바닥에 눕고 디더로 사라진다
//  · 결재 도장(쌍장): 손바닥 자리에 빨간 도장('결' 인장)이 크게 찍혔다 줄며 사라진다 + 흰 터짐 살 + 붉은 빛
//  · 벽 도장(벽에 박힘): 벽면에 같은 도장이 남는다(몸 뒤 — 몸이 미끄러져 내려가면 드러난다) · 2.4초 뒤 디더로 사라진다
//  · 박치기 별: 머리끼리 부딪힌 자리 금빛 살 + 튀는 작은 별(2타는 크게) · 어질어질: 맞은 인물 머리 위를 작은 별 셋이 돈다(그 인물 머리를 따라간다)
// 모양 난수는 효과마다 씨앗(결정적 — 게임 시간만).

struct NativeOfficeFx {
    static let RED = 12, GOLD = 9, MOON = 15, CANVAS = 35, INK = 1, STEEL = 8

    struct Sheet { var x, y, vx, vy, age, life, ph, gy: Double; let w: Int, h: Int, receipt: Bool; var landed = false }
    struct Seal { var x, y, age: Double; let dir: Double, wall: Bool, seed: Int }
    struct Burst { var x, y, age: Double; let big: Bool, seed: Int }
    struct Daze { var id: ActorID, x, y, age: Double }

    var sheets: [Sheet] = [], seals: [Seal] = [], bursts: [Burst] = [], dazes: [Daze] = []
    var calm = false
    private var n = 0
    var isEmpty: Bool { sheets.isEmpty && seals.isEmpty && bursts.isEmpty && dazes.isEmpty }

    /// 도장 글자 '결'(7 × 11) — 인장 테두리 안에 들어간다
    static let glyph = ["###...#", "..#.###", "..#...#", "..#.###", ".#....#", ".......", "#######", "......#", "#######", "#......", "#######"]

    mutating func apply(_ events: [SimEvent], gy: Double) {
        for case let .fx(k, x, y, d) in events {
            n += 1
            switch k {
            case "nv_slam": spawnSheets(x, y, dir: d >= 0 ? 1 : -1, gy: gy)
            case "nv_stamp": seals.append(Seal(x: x, y: y, age: 0, dir: d >= 0 ? 1 : -1, wall: false, seed: n))
            case "nv_stampWall": seals.append(Seal(x: x, y: y, age: 0, dir: d >= 0 ? 1 : -1, wall: true, seed: n))
            case "nv_head": bursts.append(Burst(x: x, y: y, age: 0, big: abs(d) > 1.5, seed: n))
            case "nv_daze": dazes.removeAll { $0.id == ActorID(d) }; dazes.append(Daze(id: ActorID(d), x: x, y: y, age: 0))
            default: break
            }
        }
        if seals.count > 6 { seals.removeFirst(seals.count - 6) }
        if bursts.count > 6 { bursts.removeFirst(bursts.count - 6) }
    }

    mutating func spawnSheets(_ x: Double, _ y: Double, dir: Double, gy: Double) {
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: n &* 2654435761 &+ 41))
        func r() -> Double { g.next() }
        let count = calm ? 6 : 13
        for i in 0..<count {
            let receipt = i % 4 == 3
            sheets.append(Sheet(x: x + (r() - 0.5) * 10, y: y + (r() - 0.5) * 8, vx: dir * (r() * 110 - 30) + (r() - 0.5) * 90, vy: -(70 + r() * 170),
                                age: 0, life: 1.8 + r() * 0.9, ph: r() * 6.28, gy: gy + (r() - 0.5) * 5,
                                w: receipt ? 2 : 4, h: receipt ? 4 : 3, receipt: receipt))
        }
        if sheets.count > 60 { sheets.removeFirst(sheets.count - 60) }
    }

    mutating func advance(_ dt: Double) {
        guard dt > 0, !isEmpty else { return }
        for i in sheets.indices {
            var s = sheets[i]
            s.age += dt
            if !s.landed {
                // 처음엔 튀어 오르고 → 공기 저항으로 금방 느려져 팔랑이며 내려온다(종단 속도 · 좌우 흔들림)
                s.vy += 380 * dt; s.vx *= pow(0.2, dt)
                s.vy = min(s.vy, 34)
                s.x += (s.vx + sin(s.age * 7 + s.ph) * 18) * dt; s.y += s.vy * dt
                if s.y >= s.gy && s.vy > 0 { s.y = s.gy; s.landed = true }
            }
            sheets[i] = s
        }
        sheets.removeAll { $0.age > $0.life }
        for i in seals.indices { seals[i].age += dt }
        seals.removeAll { $0.age > ($0.wall ? 2.4 : 0.5) }
        for i in bursts.indices { bursts[i].age += dt }
        bursts.removeAll { $0.age > 0.32 }
        for i in dazes.indices { dazes[i].age += dt }
        dazes.removeAll { $0.age > 1.15 }
    }

    private static func h(_ a: Int, _ b: Int, _ c: Int = 0) -> Double {
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: a &* 73856093 ^ b &* 19349663 ^ c &* 83492791 &+ 11)); return g.next()
    }

    /// 앞(인물 앞) 픽셀 · 벽 도장(배경 바로 앞) 픽셀 · 광원. heads = 그린 인물 머리 자리 · zc = 인물 깊이 기준(0.9 − 발y/300)
    func build(heads: [ActorID: SIMD2<Double>], zc: Double, time: Double) -> (front: [Float], back: [Float], lights: [SceneLight]) {
        var F = ArtCanvas(), B = ArtCanvas(), L: [SceneLight] = []
        let zf = zc - 0.07, k = calm ? 0.6 : 1.0

        // 서류: 팔랑임 위상으로 앞면(4×3) · 기울어짐(4×2) · 모서리(4×1)
        for (i, s) in sheets.enumerated() {
            let u = s.age / s.life
            if u > 0.7 && Self.h(i, Int(s.x), Int(s.y)) < (u - 0.7) / 0.3 { continue }   // 디더로 사라짐
            let c = abs(cos(s.age * (s.landed ? 0 : 6) + s.ph))
            let hh = s.landed ? 1 : c > 0.62 ? s.h : c > 0.25 ? max(1, s.h - 1) : 1
            let x0 = Int(s.x.rounded()) - s.w / 2, y0 = Int(s.y.rounded()) - hh + 1
            for yy in 0..<hh { for xx in 0..<s.w {
                let line = !s.receipt && hh >= 3 && yy == 1 && xx > 0 && xx < s.w - 1   // A4 글줄 한 줄
                F[x0 + xx, y0 + yy] = line ? ArtPx(mat: Self.STEEL, tone: 0.45, z: zf, d: 0.1)
                                           : ArtPx(mat: Self.CANVAS, tone: s.receipt ? 0.75 : 0.9 - Double(yy) * 0.04, z: zf, d: 0.1, emit: 0.06)
            } }
        }

        // 결재 도장
        for s in seals {
            let sc = 2
            let pop = s.wall ? (s.age < 0.05 ? 3 : 2) : (s.age < 0.06 ? 3 : 2)
            let fade = s.wall ? (s.age < 1.6 ? 1 : max(0, 1 - (s.age - 1.6) / 0.8)) : max(0, 1 - s.age / 0.5)
            let W = 11, H = 15
            let cx = Int(s.x.rounded()), cy = Int(s.y.rounded())
            let ox = cx - W * pop / 2, oy = cy - H * pop / 2
            func cell(_ gx: Int, _ gy: Int) -> Bool {
                if gx == 0 || gy == 0 || gx == W - 1 || gy == H - 1 { return true }
                let lx = gx - 2, ly = gy - 2
                guard lx >= 0, lx < 7, ly >= 0, ly < 11 else { return false }
                let row = Self.glyph[ly]; return row[row.index(row.startIndex, offsetBy: lx)] == "#"
            }
            for gy in 0..<H { for gx in 0..<W where cell(gx, gy) {
                // 인주 결: 군데군데 비고(찍힌 도장답게) · 사라질 땐 디더
                let hv = Self.h(s.seed, gx, gy)
                if hv < 0.12 || hv > fade + 0.02 { continue }
                for py in 0..<pop { for px in 0..<pop {
                    let X = ox + gx * pop + px, Y = oy + gy * pop + py
                    if s.wall { B[X, Y] = ArtPx(mat: Self.RED, tone: 0.55 + hv * 0.2, z: 0.983, d: 0.1, emit: 0.12 * fade) }
                    else { F[X, Y] = ArtPx(mat: Self.RED, tone: 0.8, z: zf - 0.01, d: 0.1, emit: (0.35 - 0.25 * s.age / 0.5) * k) }
                } }
            } }
            _ = sc
            if !s.wall {
                // 흰 터짐 살(첫 0.12초) — 도장 둘레 8방향
                if s.age < 0.12 {
                    let r0 = 8 + Int(s.age / 0.12 * 10), len = 6
                    for a in 0..<8 {
                        let th = Double(a) * .pi / 4 + 0.2, dx = cos(th), dy = sin(th)
                        for q in 0..<len { F[cx + Int((dx * Double(r0 + q)).rounded()), cy + Int((dy * Double(r0 + q)).rounded())] = ArtPx(mat: Self.MOON, tone: 1, z: zf - 0.02, d: 0.1, emit: 1.2 * k) }
                    }
                }
                L.append(SceneLight(x: s.x, y: s.y, z: 14, r: 64, c: [1.0, 0.32, 0.26], i: 0.6 * fade * k, em: true))
            }
        }

        // 박치기 별 터짐
        for b in bursts {
            let u = b.age / 0.32, R = b.big ? 12.0 : 7.0
            let cx = Int(b.x.rounded()), cy = Int(b.y.rounded())
            let rays = b.big ? 8 : 6
            for a in 0..<rays {
                let th = Double(a) / Double(rays) * 2 * .pi + Double(b.seed % 5) * 0.3
                let r0 = 2 + u * R * 0.6, r1 = r0 + (b.big ? 6 : 4) * (1 - u)
                var r = r0
                while r <= r1 { F[cx + Int((cos(th) * r).rounded()), cy + Int((sin(th) * r * 0.8).rounded())] = ArtPx(mat: r < r0 + 2 ? Self.MOON : Self.GOLD, tone: 1, z: zf - 0.02, d: 0.1, emit: 1.1 * k); r += 0.7 }
            }
            if u < 0.35 { for dx in -1...1 { for dy in -1...1 { F[cx + dx, cy + dy] = ArtPx(mat: Self.MOON, tone: 1, z: zf - 0.02, d: 0.1, emit: 1.4 * k) } } }
            // 튀는 작은 별(+ 꼴)
            for j in 0..<(b.big ? 5 : 3) {
                let th = Self.h(b.seed, j, 1) * 2 * .pi, d = (6 + Self.h(b.seed, j, 2) * 10) * (0.3 + u)
                star(&F, cx + Int((cos(th) * d).rounded()), cy + Int((sin(th) * d * 0.8 - u * 4).rounded()), zf - 0.02, 0.9 * k)
            }
            L.append(SceneLight(x: b.x, y: b.y, z: 14, r: b.big ? 48 : 30, c: [1.0, 0.86, 0.5], i: (b.big ? 0.55 : 0.3) * (1 - u) * k, em: true))
        }

        // 어질어질: 머리 위를 도는 별 셋(뒤쪽 반 바퀴는 머리 뒤로)
        for d in dazes {
            let hp = heads[d.id] ?? SIMD2(d.x, d.y + 8)
            let fade = d.age > 0.9 ? (1.15 - d.age) / 0.25 : 1
            for j in 0..<3 {
                let th = d.age * 7 + Double(j) * 2 * .pi / 3
                let x = Int((hp.x + cos(th) * 9).rounded()), y = Int((hp.y - 11 + sin(th) * 2.5).rounded())
                if Self.h(Int(d.id), j, Int(d.age * 20)) > fade { continue }
                star(&F, x, y, sin(th) < 0 ? zc + 0.06 : zf, 0.8 * k)
            }
        }

        var mf = PixelMesh(), mb = PixelMesh()
        F.flush(into: &mf); B.flush(into: &mb)
        return (mf.f, mb.f, L)
    }

    /// 작은 별(+ 꼴 3×3 — 가운데 흰빛)
    private func star(_ C: inout ArtCanvas, _ x: Int, _ y: Int, _ z: Double, _ e: Double) {
        C[x, y] = ArtPx(mat: Self.MOON, tone: 1, z: z, d: 0.1, emit: e * 1.3)
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] { C[x + dx, y + dy] = ArtPx(mat: Self.GOLD, tone: 0.95, z: z, d: 0.1, emit: e) }
    }
}
