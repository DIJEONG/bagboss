import Foundation

/// 표현 층이 부르는 효과음 이름표 — 웹 `sfx.*` id 와 파라미터 그대로 + 다른 조각에서 tone/nz/skTone/skNoise 를 직접 부르던 단독 소리.
/// 어떤 이벤트에 어떤 소리를 붙일지는 표현 쪽 매핑표가 정한다(docs/06 §3).
public enum SfxCue: Sendable, Hashable {
    /// 웹 hitK 의 kind. 'big' 및 그 밖의 값은 `.big`(넘어뜨리기 · 메치기 '쾅')
    public enum HitKind: String, Sendable, Hashable, CaseIterable { case jab, punch, hammer, kick, big }

    /// 레일 이음매 — speed = TR.v(px/s)
    case clack(speed: Double)
    case hit(heavy: Bool, crit: Bool)
    case hitK(HitKind, crit: Bool, combo: Int)
    /// 타격음 3단: 0 탁 · 1 퍽 · 2 쾅. big 이면 배경음을 잠깐 누른다(덕킹)
    case hit3(tier: Int, crit: Bool = false, combo: Int = 0, air: Bool = false, big: Bool = false)
    case just
    /// 몸이 바닥에 떨어지는 쿵(p = 세기). 70ms 안에 다시 오면 무시(웹 SND.floorT)
    case floor(Double)
    case thud, swing
    case hurt(heavy: Bool)
    case glass, boom, whoosh, dodge, press
    /// 문 닫힘 딩-동
    case chime
    case door(open: Bool)
    case click, coin
    case merge(ok: Bool)
    case clear, slowIn
    case carHit(heavy: Bool)
    case gong, ready, brass, rage
    /// 에어 브레이크(정차 순간 — TrainAmbience 가 스스로도 낸다)
    case hiss
    /// 교행 열차: 굉음 · 경적
    case pass
    case zap, unlock

    // --- 단독 소리(다른 조각의 직접 호출) ---
    /// 39 프롤로그 문 끼이익(doorOpen) — door(open:true)와 함께 낸다
    case doorCreak
    /// 39 프롤로그 빗길 발소리(첨벙)
    case footSplash
    /// 43 보너스 결과 줄 넘김 틱
    case tallyTick
    /// 43 보너스: 타이어 터짐 바람
    case tireBurst
    /// 43 보너스: 불길 타닥(무작위 높이)
    case fireCrackle
    /// 43 보너스: 파편 쨍그랑
    case debrisClank
    /// 43 보너스 남은 시간 삑(2초 이하면 높게)
    case countdownBeep(final: Bool)
    /// 13 · 08 · 24 의 skTone(f0 → f1 지수, 바로 시작해 지수 감쇠) — delay 는 웹 setTimeout 지연
    case skTone(f0: Double, f1: Double, dur: Double, wave: Waveform, vol: Double, delay: Double = 0)
    /// 13 · 08 · 24 의 skNoise(대역 잡음 Q1.2)
    case skNoise(dur: Double, f: Double, g: Double, delay: Double = 0)
    /// 범용 tone/nz(웹 원형 그대로)
    case tone(dur: Double, f: Double, to: Double? = nil, wave: Waveform = .sine, g: Double = 0.3, att: Double = 0.004, delay: Double = 0)
    case noise(dur: Double, f: Double = 1200, q: Double = 1, filter: FilterType = .bandpass, g: Double = 0.5, att: Double = 0.002, to: Double? = nil, delay: Double = 0)
}

/// 덕킹(웹 sndDuck(k, hold, rel)) — 음악 · 환경음 버스를 k배로 12ms 만에 낮추고 hold 동안 버틴 뒤 rel 동안 되돌린다
public struct Duck: Sendable, Equatable {
    public var k: Double, hold: Double, rel: Double
    public init(k: Double, hold: Double, rel: Double) { self.k = k; self.hold = hold; self.rel = rel }
}
