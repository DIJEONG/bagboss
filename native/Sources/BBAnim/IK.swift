import Foundation

/// 2관절 풀이 결과 — K 무릎(팔꿈치), F 발(손), aT · aS 각도(22.5° 단위)
public struct Limb: Sendable, Equatable {
    public var K: V2, F: V2, aT: Double, aS: Double
}

/// 웹 solveLeg: 엉덩이 H 에서 발 목표 T 까지. 닿지 않으면 다리를 펴서 목표를 가리킨다
func solveLeg(_ H: V2, _ T: V2, _ L1: Double, _ L2: Double, _ sgn: Double = 1) -> Limb {
    let dx = T.x - H.x, dy = T.y - H.y, phi = atan2(dx, dy)
    var d = hypot(dx, dy), al = 0.0
    if d < L1 + L2 - 0.01 {
        d = max(d, abs(L1 - L2) + 0.01)
        al = acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))))
    }
    let th = phi + sgn * al, K = V2(H.x + L1 * sin(th), H.y + L1 * cos(th))
    let ps = al > 0 ? atan2(T.x - K.x, T.y - K.y) : th
    return Limb(K: K, F: V2(K.x + L2 * sin(ps), K.y + L2 * cos(ps)), aT: th * 8 / .pi, aS: ps * 8 / .pi)
}

/// 웹 solveArm: 손 방향(a)과 뻗은 정도(e)로 손 위치를 정하고, 팔꿈치는 아래로 접히는 해(up 이면 위)
func solveArm(_ S: V2, _ a: Double, _ e: Double?, _ L1: Double, _ L2: Double, up: Bool) -> Limb {
    let th = a * .pi / 8, L = (L1 + L2) * max(0.3, min(1, e ?? 1))
    let T = V2(S.x + L * sin(th), S.y + L * cos(th))
    let p = solveLeg(S, T, L1, L2, 1), m = solveLeg(S, T, L1, L2, -1)
    return up ? (m.K.y < p.K.y ? m : p) : (m.K.y > p.K.y ? m : p)
}

/// 웹 rotEnd: 32방향 인덱스(11.25°)로 끝점 — 항상 정수 픽셀
func rotEnd(_ x: Double, _ y: Double, _ a2: Double, _ len: Double) -> V2 {
    let th = a2 * .pi / 16
    return V2(x + jsRound(len * sin(th)), y + jsRound(len * cos(th)))
}

/// 웹 rotV: 스프라이트 회전과 같은 규칙(22.5° 단위)
func rotV(_ p: V2, _ th16: Double) -> V2 {
    let th = th16 * .pi / 8, c = cos(th), s = sin(th)
    return V2(p.x * c + p.y * s, -p.x * s + p.y * c)
}

/// 웹 m32
@inlinable func m32(_ a: Double) -> Double { jsMod(jsMod(a, 32) + 32, 32) }
