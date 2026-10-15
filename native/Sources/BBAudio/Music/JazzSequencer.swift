import Foundation

/// 배경음에 게임이 주는 입력 — 웹 musicTick 이 GS 에서 읽던 것을 셋으로 줄였다(docs/06 §2.8).
public struct MusicInput: Sendable, Equatable {
    /// 음악을 굴리는가(웹: sndUpdate 가 GS.on 일 때만 musicTick 을 부른다)
    public var enabled: Bool
    /// 목표 긴장도: 1 평온 · 2 전투 · 2.5 위기 · 3 두목 — `JazzSequencer.level(…)` 로 만든다
    public var intensity: Double
    /// 버스커 기타(웹: GS.ev.k==='busk' && 진행 중)
    public var buskOn: Bool
    /// 프롤로그 전용 무거운 박동(웹: GS.prologue)
    public var prologue: Bool

    public init(enabled: Bool = true, intensity: Double = 1, buskOn: Bool = false, prologue: Bool = false) {
        self.enabled = enabled; self.intensity = intensity; self.buskOn = buskOn; self.prologue = prologue
    }
    public static let off = MusicInput(enabled: false)
}

/// 누아르 재즈 배경음: D단조 ii-V-i(Em7b5 · A7 · Dm7 · Dm7) — 웹 musicTick(35-audio.js) 이식.
/// 웹은 매 프레임 0.15초 앞을 내다보며 tone/nz 를 예약했지만, 여기서는 오디오 스레드가 표본 단위로 정확한 시각에 소리를 낸다.
/// 8분음표 단위 16스텝 = 한 마디, 4마디 순환. 긴장도에 따라 BPM 92 → 110(>1.5) → 124(>2.4), 악기가 겹친다:
/// 워킹 베이스(>1.6 이면 8분) · 브러시(>1.4 크게) · 라이드(>1.6) · 로즈 화음(>2.3 이면 엇박 추가) · 찌르기(>2.6) · 버스커 기타.
/// 할당 없이 돈다(emit 은 탈출하지 않는 클로저).
public struct JazzSequencer: Sendable {
    public static let chords: [[Int]] = [[52, 55, 58, 62], [57, 61, 64, 67], [50, 53, 57, 60], [50, 53, 57, 62]]
    public static let bassWalk: [[Int]] = [[40, 43, 46, 47], [45, 44, 43, 42], [38, 41, 45, 43], [38, 40, 41, 42]]
    @inline(__always) public static func mtof(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }

    /// 웹 lvl 계산: 두목 3 · 위기(남은 구간 25% 미만 전투) 2.5 · 적 있음 2 · 평온 1
    public static func level(foes: Int, boss: Bool, danger: Bool) -> Double {
        boss ? 3 : (danger && foes > 0) ? 2.5 : foes > 0 ? 2 : 1
    }

    public private(set) var step = 0
    /// 다음 스텝 시각(초, 합성기 시계). 0 이면 아직 시작 전
    public private(set) var nextTime = 0.0
    /// 실제 긴장도(목표로 천천히 따라간다 — 웹: 프레임마다 2%)
    public private(set) var intensity = 0.0
    public var input = MusicInput.off
    private var lastUpdate = 0.0

    public init() {}

    /// 현재 BPM(웹과 같은 문턱)
    public var bpm: Double { input.prologue ? 96 : 92 + (intensity > 1.5 ? 18 : 0) + (intensity > 2.4 ? 14 : 0) }

    /// [now, until) 동안 울릴 스텝을 낸다. emit(소리, 시작 시각(초)).
    public mutating func advance(now: Double, until: Double, seed: inout NoiseSeed, emit: (VoiceSpec, Double) -> Void) {
        guard input.enabled else { lastUpdate = now; return }
        // 긴장도: 웹은 60fps 프레임마다 M.int += (lvl − M.int)·.02 → 연속 시간으로 바꿔 적용
        let dt = max(0, now - lastUpdate); lastUpdate = now
        intensity += (input.intensity - intensity) * (1 - pow(0.98, dt * 60))
        if nextTime == 0 || nextTime < now - 0.5 { nextTime = now + 0.05 }
        while nextTime < until {
            let spb = 60 / bpm / 2
            if input.prologue { prologueStep(spb: spb, emit: emit) } else { jazzStep(spb: spb, seed: &seed, emit: emit) }
            nextTime += spb; step += 1
        }
    }

    private func prologueStep(spb: Double, emit: (VoiceSpec, Double) -> Void) {
        let st = step % 16, t = nextTime
        if st == 0 || st == 3 { emit(SfxBank.tone(0.16, f: st != 0 ? 52 : 58, to: 36, g: 0.45, bus: .music), t) }
        if st == 0 && (step / 16) % 2 == 0 { emit(SfxBank.tone(spb * 15, f: Self.mtof(38), type: .sawtooth, g: 0.03, att: 0.4, bus: .music), t) }
        if st == 8 { emit(SfxBank.tone(spb * 7, f: Self.mtof(45), type: .triangle, g: 0.025, att: 0.3, bus: .music), t) }
    }

    private func jazzStep(spb: Double, seed: inout NoiseSeed, emit: (VoiceSpec, Double) -> Void) {
        let st = step % 16, bar = (step / 16) % 4, t = nextTime, sw = st % 2 == 1 ? spb * 0.33 : 0, m = intensity
        let chord = Self.chords[bar]
        if st % 2 == 0 {                                                                    // 워킹 베이스
            let bn = Self.bassWalk[bar][st / 4]
            if st % 4 == 0 || m > 1.6 { emit(SfxBank.tone(spb * 1.8, f: Self.mtof(Double(bn)), type: .triangle, g: 0.32, att: 0.01, bus: .music), t) }
        }
        if st % 4 == 2 { emit(SfxBank.nz(0.12, f: 4000, q: 0.4, type: .highpass, g: m > 1.4 ? 0.06 : 0.035, bus: .music, seed: seed.next()), t + sw) }   // 브러시(뒷박)
        if m > 1.6 && st % 2 == 0 { emit(SfxBank.nz(0.18, f: 8000, q: 0.5, type: .highpass, g: 0.03, bus: .music, seed: seed.next()), t + sw) }            // 라이드
        if st == 0 || (m > 2.3 && st == 10) {                                               // 로즈 화음
            for n in chord { emit(SfxBank.tone(spb * (st == 0 ? 6 : 2), f: Self.mtof(Double(n + 12)), g: m > 2.3 ? 0.05 : 0.04, att: 0.02, bus: .music), t + sw) }
        }
        if m > 2.6 && st % 8 == 6 { emit(SfxBank.tone(spb, f: Self.mtof(Double(chord[3] + 24)), type: .square, g: 0.025, bus: .music), t) }   // 위기 · 두목: 찌르기
        if input.buskOn {                                                                   // 버스커 기타 아르페지오
            emit(SfxBank.tone(spb * 1.6, f: Self.mtof(Double(chord[st % 4] + 12 + (st % 8 > 3 ? 12 : 0))), type: .triangle, g: 0.09, att: 0.003, bus: .music), t + sw)
        }
    }
}

/// 오디오 스레드에서 잡음 씨앗을 뽑는 작은 수열(할당 · 잠금 없음)
public struct NoiseSeed: Sendable {
    var s: UInt64
    public init(_ seed: UInt64) { s = seed }
    public mutating func next() -> UInt32 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return UInt32(truncatingIfNeeded: z ^ (z >> 31)) | 1
    }
}
