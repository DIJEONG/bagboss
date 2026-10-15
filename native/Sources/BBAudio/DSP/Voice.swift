import Foundation

/// 웹 그래프의 버스 셋(SND.music · SND.sfx · SND.amb)
public enum Bus: UInt8, Sendable, CaseIterable { case music, sfx, amb }

/// 소리 원천
public enum VoiceSource: Sendable, Equatable {
    case osc(Waveform)
    case white
    /// 녹음 조각(SampleBank — SynthCore 가 쥔 묶음에서 읽는다). 필터 · 이득 봉투 · 버스는 다른 소리와 같다
    case sample(HitClip)
}

/// 짧은 소리 하나의 처방 — 웹 `tone()` · `nz()` · 손으로 짠 노드 묶음(brass · blip · skTone …) 하나에 해당.
/// 원천 → (필터) → 이득 봉투 → 버스. 시각은 모두 '이 소리가 울리기 시작한 순간 = 0' 기준(초).
/// 고정 크기 값 타입(참조 없음) — 오디오 스레드로 복사해 보내도 할당이 없다.
public struct VoiceSpec: Sendable, Equatable {
    public var source: VoiceSource
    public var bus: Bus = .sfx
    /// 요청 시각부터 울리기 시작할 때까지(초) — 웹 `tone(t+.07, …)` 의 +.07
    public var delay: Double = 0
    /// 시작부터 멈출 때까지(초) — 웹 `o.stop(t+dur+.05)`
    public var stop: Double
    /// 발진기 주파수(Hz). 잡음이면 쓰지 않는다
    public var freq = ParamTimeline(440)
    public var filter: FilterType = .none
    public var filterFreq = ParamTimeline(350)
    public var q: Double = 1
    public var filterGainDb: Double = 0
    public var gain = ParamTimeline(1)
    /// 잡음 씨앗(주입 난수에서)
    public var seed: UInt32 = 1
    /// 잡음이 나오는 길이(초) — 웹은 2초짜리 잡음 버퍼를 무작위 위치(0~1.5초)에서 반복 없이 틀어, 긴 소리는 버퍼 끝에서 잡음이 끊긴다
    public var noiseLength: Double = .infinity
    /// 녹음 조각 재생 속도(1 = 원래 높이 · 1.05 = 5% 높고 짧게). 조각 표본율 ≠ 출력 표본율 보정은 따로 곱한다
    public var rate: Double = 1

    public init(source: VoiceSource, stop: Double) { self.source = source; self.stop = stop }
}

/// 오디오 스레드에서 도는 소리 하나의 상태(풀의 칸 하나).
struct VoiceState {
    var spec: VoiceSpec
    var startFrame: Int64       // 절대 표본 번호
    var stopFrames: Int
    var local = 0
    var osc: Oscillator
    var rng: NoiseRNG
    var filter = Biquad()
    var freq: ParamCursor
    var ffreq: ParamCursor
    var gain: ParamCursor
    let filterAuto: Bool
    let sr: Double
    let noiseEnd: Int
    var nextWhite: Float = 0
    /// 시작 시각이 표본 경계에서 벗어난 정도(0~1 표본) — Chromium 은 시작이 표본 사이면 버퍼를 선형 보간해 읽고(고역이 준다)
    /// 자동화 사건은 실제 시각 기준으로 잰다. 둘 다 흉내 낸다.
    let frac: Double
    /// Chromium 양자 버릇: 첫 양자 동안 주파수를 quirkOffset 표본 늦게 읽는다(quirkUntil 지역 표본까지)
    let quirkOffset: Int, quirkUntil: Int
    /// 녹음 조각(없으면 nil) · 길이 · 출력 표본 하나당 조각 진행량 · 읽는 위치
    let sampleData: UnsafePointer<Float>?
    let sampleCount: Int, sampleStep: Double
    var samplePos = 0.0

    init(_ s: VoiceSpec, startFrame: Int64, sampleRate: Double, tables: WaveTableSet, quantumQuirk: Bool = false, frac: Double = 0, samples: SampleBank? = nil) {
        spec = s; sr = sampleRate; self.frac = frac
        self.startFrame = startFrame
        stopFrames = Int((s.stop * sampleRate).rounded(.up))
        if case .osc(let w) = s.source { osc = Oscillator(w, tables: tables) } else { osc = Oscillator(.sine, tables: tables) }
        rng = NoiseRNG(seed: s.seed)
        noiseEnd = s.noiseLength.isFinite ? Int((s.noiseLength * sampleRate).rounded()) : .max
        nextWhite = rng.white()
        let off = Int(startFrame % 128)
        if quantumQuirk && off > 0 && s.freq.isAutomated { quirkOffset = off; quirkUntil = 128 - off } else { quirkOffset = 0; quirkUntil = 0 }
        freq = ParamCursor(s.freq, sampleRate: sampleRate, offsetFrames: frac)
        ffreq = ParamCursor(s.filterFreq, sampleRate: sampleRate, offsetFrames: frac)
        gain = ParamCursor(s.gain, sampleRate: sampleRate, offsetFrames: frac)
        filterAuto = s.filterFreq.isAutomated
        if case .sample(let c) = s.source, let clip = samples?.clip(c) {
            sampleData = clip.samples; sampleCount = clip.count; sampleStep = s.rate * clip.sampleRate / sampleRate
        } else { sampleData = nil; sampleCount = 0; sampleStep = 0 }
        if s.filter != .none {
            filter.set(s.filter, freq: s.filterFreq.startValue, q: s.q, gainDb: s.filterGainDb, sampleRate: sampleRate)
        }
    }

    /// 블록 [blockStart, blockStart+n) 에 더한다. 끝났으면 false.
    @inline(__always) mutating func render(into out: UnsafeMutablePointer<Float>, frames n: Int, blockStart: Int64) -> Bool {
        let begin = max(0, Int(startFrame - blockStart))
        if begin >= n { return true }
        let isOsc: Bool, isSample: Bool
        if case .osc = spec.source { isOsc = true } else { isOsc = false }
        if case .sample = spec.source { isSample = true } else { isSample = false }
        let hasFilter = spec.filter != .none
        for i in begin..<n {
            if local >= stopFrames { return false }
            let g = gain.next()
            var x: Float
            if isOsc {
                var f = freq.next()
                if local < quirkUntil { f = spec.freq.value(at: (Double(local - quirkOffset) + frac) / sr) }
                x = osc.next(freq: f, sampleRate: sr)
            } else if isSample {
                // 녹음 조각: 선형 보간으로 rate 만큼 진행 — 끝나면 소리도 끝(조각이 없으면 바로 끝)
                let ip = Int(samplePos)
                guard let d = sampleData, ip + 1 < sampleCount else { return false }
                let fr = Float(samplePos - Double(ip))
                x = d[ip] + (d[ip + 1] - d[ip]) * fr
                samplePos += sampleStep
            } else if local < noiseEnd {
                let w = nextWhite; nextWhite = rng.white()
                x = w + (nextWhite - w) * Float(frac)
            } else { x = 0 }
            if hasFilter {
                if filterAuto {
                    let f = ffreq.next()
                    if f != filter.lastFreq { filter.set(spec.filter, freq: f, q: spec.q, gainDb: spec.filterGainDb, sampleRate: sr) }
                }
                x = filter.process(x)
            }
            out[i] += x * Float(g)
            local += 1
        }
        return local < stopFrames
    }
}
