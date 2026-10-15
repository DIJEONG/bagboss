import Foundation

// 웹 원본과 같은 결과를 내기 위한 JS 의미 보조(이식 코드 전용).
// 원본 수식에서 `x||d` · `x??d` · `%` · `Math.round` 가 서로 다르게 동작하는 지점이 많다 — 섞어 쓰면 값이 어긋난다.

public typealias V2 = SIMD2<Double>

/// JS `x || d` — 없음 · 0 · NaN 이면 d
@inlinable func or(_ x: Double?, _ d: Double) -> Double {
    guard let x, x != 0, !x.isNaN else { return d }
    return x
}
/// JS `x ?? d` — 없음일 때만 d
@inlinable func nn(_ x: Double?, _ d: Double) -> Double { x ?? d }
/// JS 에서 없는 값을 산술에 쓰면 NaN
@inlinable func raw(_ x: Double?) -> Double { x ?? .nan }
/// JS `Math.round` (0.5 는 +∞ 쪽)
@inlinable func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
/// JS `a % b` (부호는 a 를 따른다)
@inlinable func jsMod(_ a: Double, _ b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }
/// JS 참 판정(숫자): 0 · NaN · 없음은 거짓
@inlinable func truthy(_ x: Double?) -> Bool { if let x, x != 0, !x.isNaN { true } else { false } }
@inlinable func RI(_ v: V2) -> V2 { V2(jsRound(v.x), jsRound(v.y)) }
