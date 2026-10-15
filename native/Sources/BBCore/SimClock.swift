// 시뮬레이션 시간 — 고정 스텝(docs/06 §2.3, 결정 D5).
// 1틱 = 1/60초. 애니메이션 한 칸은 게임 모드 20fps = 3틱(웹 setMode('game') 의 animFps=20 — 12fps 는 엔진 실험실 값). 벽시계는 쓰지 않는다.

public enum SimTime {
    public static let ticksPerSecond = 60
    public static let dt: Double = 1.0 / Double(ticksPerSecond)
    /// 웹 게임 모드 animFps = 20 → 한 칸 = 3틱 (실험실은 12)
    public static let animFps = 20
    public static let ticksPerAnimFrame = ticksPerSecond / animFps
    /// 웹판 loop() 의 실제 dt 상한(0.1초)에 해당 — 한 화면 프레임에 돌릴 최대 틱 수
    public static let maxTicksPerFrame = 6

    @inlinable public static func ticks(seconds: Double) -> Int { Int((seconds * Double(ticksPerSecond)).rounded()) }
    @inlinable public static func seconds(ticks: Int) -> Double { Double(ticks) * dt }
    /// 웹판 시퀀스 길이(ms) → 틱
    @inlinable public static func ticks(ms: Double) -> Int { Int((ms * Double(ticksPerSecond) / 1000).rounded()) }
}

/// 화면 프레임(가변) → 시뮬레이션 틱(고정) 누산기.
/// `scale` 은 게임 속도 × 슬로 배율. 남은 시간은 다음 프레임으로 넘긴다.
public struct FixedStepAccumulator: Sendable {
    public private(set) var carry: Double = 0
    public init() {}
    /// 이번 화면 프레임에 돌릴 틱 수.
    public mutating func ticks(frameSeconds: Double, scale: Double) -> Int {
        carry += min(frameSeconds, 0.1) * max(0, scale)
        let n = Int(carry / SimTime.dt)
        carry -= Double(n) * SimTime.dt
        if n > SimTime.maxTicksPerFrame { carry = 0; return SimTime.maxTicksPerFrame }
        return n
    }
    /// 렌더 보간 비율(0..1) — 마지막 틱 이후 흐른 비율
    public var alpha: Double { carry / SimTime.dt }
}
