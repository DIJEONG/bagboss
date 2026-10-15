// 난수 — 시뮬레이션은 전역 난수를 쓰지 않고 주입받은 생성기만 쓴다(docs/06 §2.3).
// 규칙용(rngRule)과 연출용(rngFx) 스트림을 나눠, 연출을 바꿔도 판정 결과가 흔들리지 않게 한다.

/// 게임 전체가 쓰는 난수 생성기 약속. `next()`는 [0, 1) 실수.
public protocol GameRandom: Sendable {
    mutating func nextUInt64() -> UInt64
}

extension GameRandom {
    /// [0, 1) — 상위 53비트로 만든다.
    @inlinable public mutating func next() -> Double {
        Double(nextUInt64() >> 11) * 0x1.0p-53
    }
    /// [lo, hi)
    @inlinable public mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * next()
    }
    /// 0 ..< n
    @inlinable public mutating func int(_ n: Int) -> Int {
        precondition(n > 0)
        return Int(next() * Double(n))
    }
    @inlinable public mutating func chance(_ p: Double) -> Bool { next() < p }
    @inlinable public mutating func pick<T>(_ a: [T]) -> T { a[int(a.count)] }
}

/// SplitMix64 — 시드 하나로 빠르고 품질 좋은 64비트 수열. 기본 생성기.
public struct SplitMix64: GameRandom {
    public private(set) var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// 같은 부모에서 독립 스트림을 가른다(규칙 · 연출 분리용).
    public mutating func split() -> SplitMix64 { SplitMix64(seed: nextUInt64()) }
}

/// 웹판 `mulberry(a)`(04-art-figure.js) 와 비트 단위로 같은 생성기.
/// 웹과 결과를 맞춰야 하는 곳(오늘의 타워 · 절차 배치 대조 테스트)에서만 쓴다.
public struct Mulberry32: Sendable {
    public private(set) var a: Int32
    public init(seed: Int32) { a = seed }
    /// [0, 1) — JS 와 같은 값.
    public mutating func next() -> Double {
        a = a &+ 0x6D2B_79F5
        let au = UInt32(bitPattern: a)
        var t = (au ^ (au >> 15)) &* (1 | au)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}
