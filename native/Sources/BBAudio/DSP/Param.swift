import Foundation

// 웹 AudioParam 자동화의 네이티브 판(Web Audio 명세 §1.6 그대로).
// - ParamTimeline: 소리 하나가 '자기 시작 시각 = 0' 기준으로 갖는 사건 목록(최대 4개 · 힙 할당 없음).
// - ParamCursor: 오디오 스레드에서 표본마다 값을 내는 증분 계산기(구간마다 pow 한 번, 나머지는 덧셈 · 곱셈).
// - TargetParam: setTargetAtTime 을 매 프레임 부르는 웹 패턴(연속 지수 접근)의 판.

/// 자동화 사건 하나.
public struct ParamEvent: Sendable, Equatable {
    public enum Kind: UInt8, Sendable { case set, linear, exponential }
    public var kind: Kind
    public var value: Double
    public var time: Double
    public init(_ kind: Kind, _ value: Double, at time: Double) { self.kind = kind; self.value = value; self.time = time }
}

/// 값 곡선(사건 최대 4개). 웹 tone/nz 의 봉투(0 → 선형 → 지수)와 주파수 미끄러짐이 모두 이 안에 든다.
/// 고정 크기 값 타입이라 오디오 스레드로 그대로 복사해 보내도 할당 · 참조 계수가 없다.
public struct ParamTimeline: Sendable, Equatable {
    public static let capacity = 4
    /// 첫 사건 전의 값(웹 노드의 기본값 · `.value`)
    public var initial: Double
    public private(set) var count = 0
    private var e0 = ParamEvent(.set, 0, at: 0), e1 = ParamEvent(.set, 0, at: 0)
    private var e2 = ParamEvent(.set, 0, at: 0), e3 = ParamEvent(.set, 0, at: 0)

    public init(_ initial: Double) { self.initial = initial }

    /// 상수 하나.
    public static func constant(_ v: Double) -> ParamTimeline { ParamTimeline(v) }

    public subscript(i: Int) -> ParamEvent {
        get { switch i { case 0: e0; case 1: e1; case 2: e2; default: e3 } }
        set { switch i { case 0: e0 = newValue; case 1: e1 = newValue; case 2: e2 = newValue; default: e3 = newValue } }
    }

    public mutating func append(_ e: ParamEvent) {
        precondition(count < Self.capacity, "ParamTimeline: 사건은 최대 \(Self.capacity)개")
        self[count] = e; count += 1
    }
    public mutating func set(_ v: Double, at t: Double) { append(ParamEvent(.set, v, at: t)) }
    public mutating func linear(to v: Double, at t: Double) { append(ParamEvent(.linear, v, at: t)) }
    public mutating func exponential(to v: Double, at t: Double) { append(ParamEvent(.exponential, v, at: t)) }

    /// 첫 사건이 '0초에 값 지정'이면 그 값, 아니면 initial — 소리가 시작할 때의 값.
    public var startValue: Double { count > 0 && self[0].time <= 0 ? self[0].value : initial }
    /// 사건이 하나라도 시간에 따라 값을 바꾸는가(바꾸지 않으면 필터 계수를 한 번만 계산한다)
    public var isAutomated: Bool {
        var v = initial
        for i in 0..<count { if self[i].value != v { return true }; v = self[i].value }
        return false
    }

    /// 명세 그대로의 값(시각 t, 초) — 참고 · 테스트용. 오디오 스레드는 ParamCursor 를 쓴다.
    public func value(at t: Double) -> Double {
        var pv = initial, pt = 0.0
        for i in 0..<count {
            let e = self[i]
            switch e.kind {
            case .set:
                if t < e.time { return pv }
            case .linear:
                if t < e.time {
                    let span = e.time - pt
                    return span <= 0 ? e.value : pv + (e.value - pv) * (t - pt) / span
                }
            case .exponential:
                if t < e.time {
                    // 명세: 앞 값과 부호가 다르거나 0 이면 끝날 때까지 앞 값 유지
                    if pv * e.value <= 0 { return pv }
                    let span = e.time - pt
                    return span <= 0 ? e.value : pv * pow(e.value / pv, (t - pt) / span)
                }
            }
            pv = e.value; pt = e.time
        }
        return pv
    }
}

/// 오디오 스레드용 증분 계산기. `next()` 가 현재 표본의 값을 내고 한 표본 나아간다.
struct ParamCursor {
    private var tl: ParamTimeline
    private let sr: Double
    private var n: Int = 0           // 지역 표본 번호
    private var idx = 0              // 진행 중인 사건 번호
    private var segEnd = 0           // 이 구간이 끝나는 표본
    private var value: Double
    private var add = 0.0, mul = 1.0
    private var prevV: Double, prevT = 0.0
    /// 지역 표본 0 이 사건 시각 0 보다 몇 표본 뒤인가(0~1) — 시작이 표본 사이에 걸린 소리
    private let off: Double

    init(_ tl: ParamTimeline, sampleRate: Double, offsetFrames: Double = 0) {
        self.tl = tl; sr = sampleRate; off = offsetFrames
        value = tl.initial; prevV = tl.initial
        enter(0)
    }

    @inline(__always) private func frameOf(_ t: Double) -> Int { Int((t * sr - off - 1e-9).rounded(.up)) }

    /// 표본 n 에서 구간을 다시 잡는다(구간 경계에서만 — pow 는 여기서만).
    private mutating func enter(_ n: Int) {
        while idx < tl.count && n >= frameOf(tl[idx].time) {
            prevV = tl[idx].value; prevT = tl[idx].time; idx += 1
        }
        add = 0; mul = 1
        guard idx < tl.count else { value = prevV; segEnd = .max; return }
        let e = tl[idx]
        segEnd = frameOf(e.time)
        let t = (Double(n) + off) / sr, span = e.time - prevT
        switch e.kind {
        case .set:
            value = prevV
        case .linear:
            value = prevV + (e.value - prevV) * (t - prevT) / span
            add = (e.value - prevV) / (span * sr)
        case .exponential:
            if prevV * e.value <= 0 { value = prevV }
            else {
                let r = e.value / prevV
                value = prevV * pow(r, (t - prevT) / span)
                mul = pow(r, 1 / (span * sr))
            }
        }
    }

    @inline(__always) mutating func next() -> Double {
        if n >= segEnd { enter(n) }
        let v = value
        value = value * mul + add
        n += 1
        return v
    }

    /// 앞으로 값이 더 바뀌지 않는가(마지막 사건 뒤)
    var isSettled: Bool { idx >= tl.count }
}

/// setTargetAtTime 을 매 프레임 거는 계속 도는 값(열차 루프 · 버스 볼륨). 표본마다 목표로 지수 접근 —
/// 명세의 v(t) = 목표 + (v0 − 목표)·e^(−(t−T0)/τ) 와 표본 단위로 같다.
public struct TargetParam: Sendable {
    public var value: Double
    public var target: Double
    private var coef: Double = 1

    public init(_ v: Double) { value = v; target = v }

    /// 목표 · 시간 상수(초). τ ≤ 0 이면 바로 뛴다.
    public mutating func setTarget(_ t: Double, tc: Double, sampleRate: Double) {
        target = t
        coef = tc <= 0 ? 1 : 1 - exp(-1 / (tc * sampleRate))
    }
    /// 표본 k 개 진행(제어율 갱신용: 한 번에 여러 표본을 건너뛴다)
    @inline(__always) public mutating func step(_ k: Int = 1) {
        if k == 1 { value += (target - value) * coef }
        else { value = target + (value - target) * pow(1 - coef, Double(k)) }
    }
    public var isSilent: Bool { abs(value) < 1e-6 && abs(target) < 1e-6 }
}
