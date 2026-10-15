import Foundation
import BBCore
import BBSim

// 네이티브 야근 광선 무대 픽셀 · 광원(docs/07 §7-BM · SimSnapshot.beam — 깃발 켜짐에서만 값이 생긴다).
// 오버레이가 아니라 무대 G-버퍼 3D 층에 1px 쿼드(PixelMesh)로 쌓는다 → 카메라 · 흔들림 · 팔레트 램프 · 디더 · 블룸을 무대와 함께 받는다.
//  · 광선: 가운데 흰 심(MOON · 강한 발광) → 청록 몸통(NEONT) → 들쭉날쭉 가장자리(20fps 칸마다 새로 — 도트답게 끊어 움직인다) · 맥박(굵기 ±1)
//    끝은 뾰족하게 가늘어지고, 발사 순간 0.06초 동안 앞으로 뻗어 나간다. 사라질 땐 심만 남아 가늘어진다.
//  · 눈 앞 섬광(십자 별 · 맥박) · 맞은 자리 불꽃(십자 + 튀는 점) · 모음 단계는 안경이 차오르고 둘레에서 빛 점이 눈으로 빨려 든다.
//  · 광원: 눈 · 광선을 따라 몇 개 · 맞은 자리 — 무대(바닥 · 벽 · 인물)를 청록으로 물들인다 + 광선 방향 부피광(빛 기둥 번짐).
// 모양 난수는 시각(20fps 칸) · 자리로 만든 씨앗(상태 없음 — 결정적).

public struct NativeBeamLayer: Sendable {
    public var mesh: [Float] = []
    public var lights: [SceneLight] = []
    public var vols: [VolumeLight] = []
}

public enum NativeBeamArt {
    static let MOON = 15, NEONT = 39, WINLIT = 31
    /// 광선 빛 색(청록 — 형광등 · 모니터)
    static let LC: [Double] = [0.55, 1.0, 0.92]

    static func h(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: a &* 73856093 ^ b &* 19349663 ^ c &* 83492791 &+ 7)); return g.next()
    }

    /// 안경알 띠: 눈 자리에서 머리 뒤쪽으로 안경 폭(약 7px)만큼 · 2px 높이 — 가운데 흰 심(MOON) · 위아래 가장자리 청록(NEONT) · 맥박.
    /// heat = 밝기(0~1 — 모음은 차오르고 · 발사는 1 · 사라질 땐 줄어든다)
    static func visor(_ ex: Int, _ ey: Int, f: Double, heat: Double, fr: Int, put: (Int, Int, Int, Double, Double) -> Void) {
        guard heat > 0.02 else { return }
        let d = f >= 0 ? -1 : 1, pulse = fr % 2 == 0 ? 1.0 : 0.85
        for i in -1...7 {
            let x = ex + d * i, edge = i == -1 || i == 7
            put(x, ey, edge ? NEONT : MOON, 1, (edge ? 0.9 : 1.5) * heat * pulse)
            if !edge && heat > 0.5 { put(x, ey - 1, NEONT, 0.95, 1.0 * heat * pulse) }   // 위 가장자리(두께 2px)
        }
    }

    /// eye = 그린 머리에서 잡은 눈 자리(장면 픽셀) · z = 깊이(인물보다 조금 앞)
    public static func build(_ B: SimSnapshot.BeamView, eye: SIMD2<Double>, z: Double, time: Double, calm: Bool) -> NativeBeamLayer {
        var out = NativeBeamLayer()
        var C = ArtCanvas()
        let fr = Int((time * 20).rounded(.down))   // 20fps 칸
        let ex = Int(eye.x.rounded()), ey = Int(eye.y.rounded())
        func put(_ x: Int, _ y: Int, _ mat: Int, _ tone: Double, _ emit: Double) { C[x, y] = ArtPx(mat: mat, tone: tone, z: z, d: 0.1, emit: emit) }

        switch B.phase {
        case "charge":
            // 안경이 차오른다(가로 3~5px 흰 줄 · 점점 밝게) + 둘레에서 빛 점이 눈으로 빨려 든다
            let k = min(1, B.t / 0.25)
            for dx in -2...2 where abs(dx) <= 1 + Int(k * 1.5) { put(ex + dx, ey, MOON, 0.8 + 0.2 * k, 0.4 + 0.8 * k) }
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * .pi + h(i, 1, 3) * 0.6, r = (1 - k) * 14 + 3 + h(i, fr, 5) * 2
                put(ex + Int((cos(a) * r).rounded()), ey + Int((sin(a) * r * 0.7).rounded()), NEONT, 0.9, 0.7)
            }
            out.lights.append(SceneLight(x: eye.x, y: eye.y, z: 14, r: 30 + 20 * k, c: LC, i: (calm ? 0.5 : 0.9) * k, em: true))
            visor(ex, ey, f: B.f, heat: 0.35 + 0.65 * k, fr: fr, put: put)
            out.lights.append(SceneLight(x: eye.x - B.f * 2, y: eye.y + 2, z: 4, r: 18, c: LC, i: (calm ? 0.5 : 1.0) * k, em: true))   // 얼굴에 비치는 빛(가까이 · 작게)
        case "fire", "fade":
            let fade = B.phase == "fade" ? max(0, 1 - B.t / 0.18) : 1
            let grow = B.phase == "fire" ? min(1, B.t / 0.06 + 0.15) : 1
            let L = B.len * grow
            let d = SIMD2(B.f * cos(B.ang), -sin(B.ang)), n = SIMD2(-d.y, d.x)
            let pulse = fr % 2 == 0 ? 1 : 0
            let wBody = fade < 1 ? fade : 1 + 0.5 * Double(pulse)   // 몸통 반폭(얇게 — 감독 피드백: 위아래로 눌러 가늘게)
            let steps = Int(L)
            for s in 0...max(0, steps) {
                let sd = Double(s)
                // 끝 18px 은 뾰족하게 · 눈 바로 앞 3px 은 섬광이 덮는다
                let tip = min(1, (L - sd) / 18), wb = wBody * tip
                let c = eye + d * sd
                let edgeOn = h(s / 2, fr, 11) > 0.45
                let wEdge = wb + (edgeOn ? 0.5 + 0.5 * Double(Int(h(s / 3, fr, 13) * 2)) : 0)
                var o = -wEdge
                while o <= wEdge + 0.01 {
                    let p = c + n * o, ax = abs(o)
                    let x = Int(p.x.rounded()), y = Int(p.y.rounded())
                    if ax <= 0.5 * max(0.5, fade) { put(x, y, MOON, 1.0, 1.4 * fade) }                  // 흰 심(1px)
                    else if ax <= wb { put(x, y, NEONT, 0.95 - ax * 0.08, 1.0 * fade) }                 // 청록 몸통
                    else if C[x, y] == nil { put(x, y, NEONT, 0.6, 0.55 * fade) }                       // 들쭉날쭉 가장자리
                    o += 0.5
                }
            }
            // 눈 앞 섬광(십자 별 · 맥박)
            let fl = Int((2 + Double(pulse)) * fade)
            if fl > 0 {
                for k in -fl...fl { put(ex + k, ey, abs(k) <= 1 ? MOON : NEONT, 1, (abs(k) <= 1 ? 1.5 : 1.1) * fade) }   // 가로 팔(길게)
                for k in -(fl / 2)...(fl / 2) where k != 0 { put(ex, ey + k, NEONT, 0.95, 1.1 * fade) }                       // 세로 팔(짧게)
            }
            // 안경알 띠(안경 가로 전체가 하얗게 탄다 — 참고: 바이저처럼 한 줄) · 발사 직후 가로 빛줄기(애너모픽 플레어 — 0.12초에 걸쳐 줄어든다)
            visor(ex, ey, f: B.f, heat: fade, fr: fr, put: put)
            let st = B.phase == "fire" ? max(0, 1 - B.t / 0.12) : 0
            if st > 0 && !calm {
                let half = Int((10 + 26 * st).rounded())
                for k in -half...half where abs(k) > 3 {
                    let u = Double(abs(k)) / Double(half)
                    if u > 0.75 && (k + fr) % 2 == 0 { continue }   // 끝은 성기게(도트로 사라진다)
                    put(ex - Int(B.f) * 2 + k, ey, u < 0.4 ? MOON : NEONT, 1, (1.3 - u) * st)
                }
            }
            out.lights.append(SceneLight(x: eye.x - B.f * 2, y: eye.y + 2, z: 4, r: 20, c: LC, i: (calm ? 0.6 : 1.3) * fade, em: true))   // 얼굴에 비치는 빛(이마 · 콧등 · 뺨)
            // 맞은 자리 불꽃(최근 셋 — 십자 + 튀는 점)
            for (i, p) in B.hits.suffix(3).enumerated() {
                let hx = Int(p.x.rounded()), hy = Int(p.y.rounded()), r = 2 + Int(h(i, fr, 17) * 3)
                for k in -r...r { put(hx + k, hy, MOON, 1, 1.2 * fade); put(hx, hy + k, NEONT, 0.9, 1.0 * fade) }
                for j in 0..<4 {
                    let a = h(i, fr, 20 + j) * 2 * .pi, rr = 3 + h(i, fr, 30 + j) * 7
                    put(hx + Int((cos(a) * rr).rounded()), hy + Int((sin(a) * rr).rounded()), NEONT, 0.8, 0.8 * fade)
                }
                out.lights.append(SceneLight(x: p.x, y: p.y, z: 12, r: 34, c: [0.8, 1, 0.95], i: (calm ? 0.35 : 0.6) * fade, em: true))
            }
            // 광원: 눈 · 광선을 따라 · 부피광(광선 방향 빛 번짐)
            let I = (calm ? 0.6 : 1.0) * fade
            out.lights.append(SceneLight(x: eye.x, y: eye.y, z: 14, r: 64, c: LC, i: 1.2 * I, em: true))
            var s = 45.0
            while s < L { let p = eye + d * s; out.lights.append(SceneLight(x: p.x, y: p.y, z: 16, r: 50, c: LC, i: 0.55 * I, em: true)); s += 60 }
            out.vols.append(VolumeLight(x: eye.x, y: eye.y, dx: d.x, dy: d.y, c: LC, i: 0.5 * I, cone: 0.998, len: L, halo: 3))
        default: break
        }
        var m = PixelMesh(); C.flush(into: &m); out.mesh = m.f
        return out
    }
}
