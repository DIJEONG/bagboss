import Foundation
import BBCore
import BBSim

// 무대 입력(웹 48-input): 화면 아래쪽 1/3 = 숙이기, 그 위 왼쪽 반 · 오른쪽 반 = 그쪽으로 수동 공격(manual(-1/+1)).
// 콤보 '탭!' 창이 열려 있으면 어디를 눌러도 tapWindow. 터치 시각은 시뮬레이션 시계로 바꿔 싣는다(저스트 판정은 그 시각 기준 — docs/06 §2.3).

public enum InputMapper {
    /// 아래쪽 이 비율 아래를 누르면 숙이기(웹 r.height*.67)
    public static let duckLine = 0.67

    /// 무대 뷰 안 위치(0..1, 위→아래) → 의도
    public static func intent(at p: SIMD2<Double>, simTime at: Double, tapWindowOpen: Bool = false) -> SimIntent {
        if tapWindowOpen { return .tapWindow(at: at) }
        if p.y > duckLine { return .duck(at: at) }
        return .tap(side: p.x < 0.5 ? -1 : 1, at: at)
    }

    /// 터치 시각(UITouch.timestamp — CACurrentMediaTime 과 같은 시계) → 시뮬레이션 시계.
    /// 마지막 화면 프레임에서 (그때 미디어 시각, 그때 시뮬레이션 시계)를 기억해 두고 차이만큼 옮긴다.
    /// 다음 틱 전에 들어온 터치라 시계보다 조금 앞설 수 있다 — 시뮬레이션은 지연(lag)을 0..0.1초로 자른다.
    public static func simTime(touch ts: Double, frameMedia: Double, frameSimClock: Double) -> Double {
        let d = max(-0.1, min(0.1, ts - frameMedia))
        return frameSimClock + d
    }
}

/// 화면 프레임(가변 · 60/120Hz) → 시뮬레이션 틱(고정 60Hz) 구동기. 시뮬레이션이 게임 속도 · 슬로를 스스로 곱하므로 여기서는 실제 시간만 센다.
public struct GameLoopClock: Sendable {
    private var acc = FixedStepAccumulator()
    /// 한 화면 프레임에 돌릴 최대 틱(멈칫한 뒤 따라잡기 상한)
    public var maxTicksPerFrame = 4
    /// 마지막 프레임 시각(미디어 시계) · 그때 시뮬레이션 시계 — 터치 시각 변환용
    public private(set) var frameMedia = 0.0, frameSimClock = 0.0
    private var lastMedia: Double?
    public init() {}

    /// 이번 화면 프레임에 돌릴 틱 수와 프레임 길이(초)
    public mutating func begin(media: Double) -> (ticks: Int, dt: Double) {
        let dt = lastMedia.map { max(0, min(0.1, media - $0)) } ?? (1.0 / 60)
        lastMedia = media
        let n = min(maxTicksPerFrame, acc.ticks(frameSeconds: dt, scale: 1))
        return (n, dt)
    }
    /// 틱을 다 돌린 뒤 시계 기록
    public mutating func end(media: Double, simClock: Double) { frameMedia = media; frameSimClock = simClock }
    /// 멈췄다 다시 시작(백그라운드 · 일시정지 뒤) — 밀린 시간을 버린다
    public mutating func resync() { lastMedia = nil; acc = FixedStepAccumulator() }
}
