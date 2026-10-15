import Foundation

// 웹 원본 수식과 같은 값을 내기 위한 JS 의미 보조(장면 구성 이식 전용 — BBAnim/JS.swift 와 같은 규칙).

/// JS `Math.round` (0.5 는 +∞ 쪽)
@inline(__always) func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
/// JS `a % b` (부호는 a 를 따른다)
@inline(__always) func jsMod(_ a: Double, _ b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }
@inline(__always) func jsFloor(_ x: Double) -> Double { x.rounded(.down) }
/// JS `Math.max` · `Math.min` — NaN 이 하나라도 있으면 NaN
@inline(__always) func jsMax(_ a: Double, _ b: Double) -> Double { (a.isNaN || b.isNaN) ? .nan : Swift.max(a, b) }
@inline(__always) func jsMin(_ a: Double, _ b: Double) -> Double { (a.isNaN || b.isNaN) ? .nan : Swift.min(a, b) }
/// JS 숫자 참 판정: 0 · NaN 은 거짓
@inline(__always) func truthy(_ x: Double) -> Bool { x != 0 && !x.isNaN }
/// JS ToInt32 (비트 연산 피연산자)
@inline(__always) func toInt32(_ x: Double) -> Int32 {
    guard x.isFinite else { return 0 }
    let t = x.rounded(.towardZero).truncatingRemainder(dividingBy: 4294967296)
    return Int32(truncatingIfNeeded: Int64(t))
}
/// JS `m32 = a => ((a%32)+32)%32`
@inline(__always) func m32(_ a: Double) -> Double { jsMod(jsMod(a, 32) + 32, 32) }

/// JS 숫자 → 문자열(스프라이트 이름 조립용). 정수는 소수점 없이.
func jsStr(_ x: Double) -> String {
    if x.isNaN { return "NaN" }
    if x.isInfinite { return x > 0 ? "Infinity" : "-Infinity" }
    if x == x.rounded(), abs(x) < 1e21 { return String(Int64(x)) }
    return String(x)
}

/// V8 Array.prototype.sort 는 안정 정렬 — 같은 키는 원래 순서를 지킨다
func stableSorted<T>(_ a: [T], by key: (T) -> Double) -> [T] {
    a.enumerated().sorted { l, r in
        let kl = key(l.element), kr = key(r.element)
        return kl != kr ? kl < kr : l.offset < r.offset
    }.map(\.element)
}

/// 웹 hash(n)(17-light-frame) — sin 기반 0..1 의사 난수
@inline(__always) func jsHash(_ n: Double) -> Double { let s = sin(n * 127.1 + 311.7) * 43758.5453; return s - s.rounded(.down) }

/// V8 Math.hypot(a, b, c) — 최댓값으로 나눠 제곱합(Kahan 보정) · BBAnim jsHypot 과 같다
@inline(__always) func jsHypot3(_ a: Double, _ b: Double, _ c: Double) -> Double {
    let x = abs(a), y = abs(b), z = abs(c), mx = max(x, y, z)
    if mx == 0 { return 0 }
    var sum = 0.0, comp = 0.0
    for v in [x, y, z] { let r = v / mx, s = r * r - comp, prelim = sum + s; comp = (prelim - sum) - s; sum = prelim }
    return sqrt(sum) * mx
}
