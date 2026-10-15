import Foundation
import BBCore
import BBSim

// 내선 연결 무대 픽셀(docs/07 §7-PH · SimSnapshot.cord — 깃발 켜짐에서만 값이 생긴다).
// 오버레이가 아니라 무대 G-버퍼 3D 층에 1px 쿼드(PixelMesh)로 쌓는다 → 카메라 · 흔들림 · 조명 · 팔레트 램프 · 디더를 무대와 함께 받는다.
//  · 색(2026-10-14 감독 비교 — 어두운 선은 어두운 배경에 묻힌다): 빨간 선 · 빨간 수화기('핫라인' 비상 전화) + 어두운 1px 테두리 → 밝은 · 어두운 배경 모두에서 읽힌다.
//  · 꼬인 전화선: 손 → 수화기 사이를 지그재그(삼각파)로 — 날아가는 동안은 팽팽하게 펴지고(진폭 1) · 끌어올 땐 다시 꼬이며(진폭 2) · 튕겨 돌아올 땐 처진다.
//    꼭대기 칸만 밝은 빨강(코일 반짝임) → 1px 에서도 '꼬인 선'으로 읽힌다.
//  · 수화기: 빨강 7×2 + 어두운 테두리(어느 배경에서도 떨어져 보이게) · 날아가는 동안 1px 떨림(따르릉) · 걸린 순간 흰 살 + 작은 빛.
//  · 발밑에 감긴 선: 끌어온 거리만큼 고리가 쌓인다(최대 4개).
// 모양 난수는 쓰지 않는다(시각 · 자리만 — 결정적).

public struct NativeCordLayer: Sendable {
    public var mesh: [Float] = []
    public var lights: [SceneLight] = []
}

public enum NativeCordArt {
    static let INK = 1, STEEL = 8, CANVAS = 35, MOON = 15, RED = 12
    /// 수화기 모양(7 × 2 — 위: 손잡이 · 아래: 귀 · 입 쪽) — '#' 크림 · 둘레 1px 는 어두운 테두리
    static let handset = ["#######", "##...##"]

    public static func build(_ C: SimSnapshot.CordView, z: Double, time: Double, calm: Bool) -> NativeCordLayer {
        var out = NativeCordLayer()
        var A = ArtCanvas()
        let fr = Int((time * 20).rounded(.down))   // 20fps 칸
        func put(_ x: Int, _ y: Int, _ mat: Int, _ tone: Double, _ emit: Double = 0) { A[x, y] = ArtPx(mat: mat, tone: tone, z: z, d: 0.1, emit: emit) }

        // ── 전화선 ──
        let hand = C.hand, tip = C.tip, v = tip - hand, L = (v.x * v.x + v.y * v.y).squareRoot()
        if L > 3 {
            let d = v / L, n = SIMD2(-d.y, d.x)
            let amp: Double, sag: Double
            switch C.phase {
            case "fly": amp = 1; sag = 0
            case "pull": amp = C.t < 0.06 ? 1 : 2; sag = 0
            case "reel": amp = 2; sag = 8
            default: amp = 2; sag = 4
            }
            let period = 4.0
            var pts: [(Int, Int, Bool)] = []
            var s = 0.0
            while s <= L {
                let u = s / L
                let ph = (s + (C.phase == "pull" ? C.t * 60 : 0)).truncatingRemainder(dividingBy: period) / period   // 끌어올 땐 꼬임이 손 쪽으로 흘러든다
                let tri = ph < 0.5 ? ph * 4 - 1 : 3 - ph * 4                 // −1 … 1 삼각파
                let p = hand + d * s + n * (tri * amp) + SIMD2(0, sag * 4 * u * (1 - u))
                pts.append((Int(p.x.rounded()), Int(p.y.rounded()), tri > 0.5))
                s += 0.5
            }
            // 어두운 테두리(바깥 1px — 선이 아닌 칸만) → 빨간 선(꼭대기 칸은 밝게 — 코일 반짝임)
            var on = Set<Int>(); for (x, y, _) in pts { on.insert(x &* 4099 &+ y) }
            for (x, y, _) in pts {
                for (ox, oy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where !on.contains((x + ox) &* 4099 &+ (y + oy)) && A[x + ox, y + oy] == nil { put(x + ox, y + oy, INK, 0.2) }
            }
            for (x, y, crest) in pts { put(x, y, RED, crest ? 0.95 : 0.7, crest ? 0.2 : 0.05) }
        }

        // ── 수화기 ──
        let ring = C.phase == "fly" ? (fr % 2 == 0 ? 1 : -1) : 0   // 날아가는 동안 따르릉 떨림
        let hx = Int(tip.x.rounded()) - 3 + ring, hy = Int(tip.y.rounded()) - 1
        let fl = C.f < 0
        for (ry, row) in handset.enumerated() {
            for (rx, ch) in row.enumerated() where ch == "#" {
                let x = hx + (fl ? 6 - rx : rx)
                // 테두리(바깥 1px — 비어 있는 칸만)
                for (ox, oy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where A[x + ox, hy + ry + oy] == nil { put(x + ox, hy + ry + oy, INK, 0.25) }
            }
        }
        for (ry, row) in handset.enumerated() {
            for (rx, ch) in row.enumerated() where ch == "#" {
                put(hx + (fl ? 6 - rx : rx), hy + ry, RED, ry == 0 ? (rx == 1 || rx == 5 ? 1.0 : 0.85) : 0.65, ry == 0 ? 0.15 : 0.05)   // 빨간 비상 전화(위 칸 귀 · 입 쪽에 밝은 반사)
            }
        }

        // ── 걸린 순간: 흰 살 · 작은 빛 ──
        if C.phase == "pull" && C.t < 0.1 {
            let k = 1 - C.t / 0.1, r = 3 + Int(k * 4)
            let cx = Int(tip.x.rounded()), cy = Int(tip.y.rounded())
            for i in 2...r {
                put(cx + i, cy, MOON, 1, 1.0 * k); put(cx - i, cy, MOON, 1, 1.0 * k)
                if i <= r - 1 { put(cx, cy - i, MOON, 1, 0.9 * k); put(cx, cy + i, MOON, 1, 0.9 * k) }
                if i <= r - 2 { put(cx + i, cy - i, MOON, 0.9, 0.7 * k); put(cx - i, cy - i, MOON, 0.9, 0.7 * k) }
            }
            out.lights.append(SceneLight(x: tip.x, y: tip.y, z: 12, r: 26, c: [1, 0.95, 0.8], i: (calm ? 0.3 : 0.6) * k, em: true))
        }

        // ── 발밑에 감긴 선(끌어온 만큼 고리) ──
        let loops = min(4, Int(C.hauled / 24))
        if loops > 0 {
            let fx0 = C.foot.x - C.f * 6, gy = C.foot.y
            for i in 0..<loops {
                let cx = fx0 - C.f * Double(i % 2 == 0 ? i * 2 : -i), cy = gy - 1 - Double(i) * 1.2
                for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 8) {
                    let x = Int((cx + cos(a) * 3.5).rounded()), y = Int((cy + sin(a) * 1.5).rounded())
                    put(x, y, sin(a) < -0.3 ? STEEL : INK, sin(a) < -0.3 ? 0.7 : 0.3)
                }
            }
        }

        var m = PixelMesh(); A.flush(into: &m); out.mesh = m.f
        return out
    }
}
