import Foundation
import BBCore

/// 열차 상태 중 소리가 읽는 것(웹 sndUpdate 가 TR · GS · 장소에서 읽던 값).
public struct TrainSoundInput: Sendable, Equatable {
    public enum Phase: String, Sendable { case accel, cruise, brake, stop }
    /// 속도 TR.v(px/s)
    public var speed: Double = 0
    public var phase: Phase = .stop
    /// 제동 불꽃 GS.brakeGlow(0~1)
    public var brakeGlow: Double = 0
    /// 바깥(다리 위 전체 · 고가) — 굴림을 줄이고 바람을 키운다
    public var outdoors = false
    /// 역에 서 있음 GS.atStop
    public var atStop = false
    /// 문 열림 정도 TR.door(0~1)
    public var door: Double = 0
    /// 문을 열고 싶은가 GS.doorWant(nil = 아직 정하지 않음)
    public var doorWant: Bool?
    /// 고장 · 공사 칸(형광등 지직)
    public var flickeryCar = false
    /// 깜빡임 세기 TR.flickS
    public var flicker: Double = 0
    /// 정전 칸(1비트) — 형광등 소리 없음
    public var oneBit = false
    /// 단조 시계(초) — 문 소리 판정(웹 performance.now)
    public var time: Double = 0
    /// 네이티브 눈 승강장(docs/10): 눈바람 세기(0 = 없음 — 웹 그대로 · 0.5 평소 · 1 돌풍)
    public var snowWind: Double = 0
    /// 네이티브 해변 도장(docs/12): 파도 세기(0 = 없음 · 0.2 잠잠 · 1 큰 파도가 밀려오는 순간)
    public var surf: Double = 0

    public init() {}
}

/// 계속 도는 소리 목표 하나: 값 + setTargetAtTime 시간 상수
public struct ParamTarget: Sendable, Equatable {
    public var value: Double, tc: Double
    public init(_ value: Double, _ tc: Double) { self.value = value; self.tc = tc }
}

/// 열차 루프 8종의 목표값(웹 SND.rumG · motO · windG … 에 거는 setTargetAtTime 묶음). 오디오 스레드로 통째로 보낸다.
public struct AmbienceTargets: Sendable, Equatable {
    /// 굴림(갈색 잡음 → 저역 통과)
    public var rumGain = ParamTarget(0, 0.1), rumFreq = ParamTarget(120, 0.1)
    /// 모터(톱니 → 대역 통과 Q6)
    public var motFreq = ParamTarget(440, 0.15), motFilter = ParamTarget(400, 0.15), motGain = ParamTarget(0, 0.2)
    /// 바람(백색 → 대역 통과 Q.7)
    public var windFreq = ParamTarget(900, 0.3), windGain = ParamTarget(0, 0.3)
    /// 제동 마찰(백색 → 2600/3900 좁은 대역)
    public var fricGain = ParamTarget(0, 0.04)
    /// 제동 갈림(갈색 → 저역 통과)
    public var grindGain = ParamTarget(0, 0.06), grindFreq = ParamTarget(160, 0.1)
    /// 멈출 무렵 쇳소리(사인 셋)
    public var squealGain = ParamTarget(0, 0.015)
    public var squealFreq0 = ParamTarget(3150, 0.01), squealFreq1 = ParamTarget(4720, 0.01), squealFreq2 = ParamTarget(6230, 0.01)
    /// 역 웅성임
    public var crowdGain = ParamTarget(0, 0.3)
    /// 형광등 지직(사각 120Hz → 저역 통과 900)
    public var humGain = ParamTarget(0, 0.05)

    public init() {}
    /// 모두 끄기(0.3초에 걸쳐)
    public static var silent: AmbienceTargets {
        var a = AmbienceTargets()
        for kp in [\AmbienceTargets.rumGain, \.motGain, \.windGain, \.fricGain, \.grindGain, \.squealGain, \.crowdGain, \.humGain] as [WritableKeyPath<AmbienceTargets, ParamTarget>] {
            a[keyPath: kp] = ParamTarget(0, 0.3)
        }
        return a
    }
    /// 39 프롤로그 빗소리: 바람 필터를 높이 올리고 굴림을 줄인다
    public mutating func applyRain() {
        windFreq = ParamTarget(3600, 0.2); windGain = ParamTarget(0.16, 0.3); rumGain = ParamTarget(0.02, 0.3)
    }
}

/// 웹 sndUpdate 의 '판단' 쪽(메인 스레드, 매 프레임): 열차 상태 → 루프 목표값 + 그때그때 내는 효과음(정차 hiss · 문 닫힘 chime · 문 열림/닫힘).
/// 실제 합성은 SynthCore 의 AmbienceLoops 가 한다.
public struct TrainAmbience: Sendable {
    private var lastPhase: TrainSoundInput.Phase?
    private var seenDoorWant = false
    private var lastDoorWant: Bool?
    private var doorT = -9.0
    private var lastDoor: Double?
    private var doorMov = 0

    public init() {}

    public struct Output: Sendable {
        public var targets: AmbienceTargets
        public var cues: [SfxCue]
    }

    public mutating func update<R: GameRandom>(_ s: TrainSoundInput, rng: inout R) -> Output {
        var a = AmbienceTargets(), cues: [SfxCue] = []
        let v = s.speed, k = min(1, v / 720), out = s.outdoors
        a.rumGain = ParamTarget(0.05 + 0.5 * k * (out ? 0.6 : 1), 0.1); a.rumFreq = ParamTarget(70 + 170 * k, 0.1)
        a.motFreq = ParamTarget(90 + 780 * k, 0.15); a.motFilter = ParamTarget(160 + 900 * k, 0.15)
        a.motGain = ParamTarget(s.phase == .accel ? 0.05 : 0.02 * k, 0.2)
        a.windGain = ParamTarget(out ? 0.12 * k : 0.02 * k, 0.3)
        if s.snowWind > 0 {   // 눈 승강장: 서 있는 열차 밖 — 낮게 깔린 바람 + 돌풍 때 조금 높고 크게(부드럽게)
            a.windGain = ParamTarget(max(a.windGain.value, 0.035 + 0.07 * s.snowWind), 0.6)
            a.windFreq = ParamTarget(380 + 520 * s.snowWind, 0.8)
        }
        if s.surf > 0 {   // 해변: 밀려올 때 '쏴아' 차오르고(밝게 · 크게) 빠질 때 낮게 잦아드는 쉬익 — 같은 바람 잡음을 빠르게 움직인다
            a.windGain = ParamTarget(max(a.windGain.value, 0.03 + 0.11 * s.surf), 0.35)
            a.windFreq = ParamTarget(300 + 900 * s.surf, 0.4)
        }
        let br = s.brakeGlow > 0.05 && v > 8 ? s.brakeGlow : 0
        a.fricGain = ParamTarget(br * 0.2 * min(1, v / 220), 0.04)                                   // 긁히는 마찰(속도에 비례)
        a.grindGain = ParamTarget(br * 0.22 * min(1, v / 400), 0.06); a.grindFreq = ParamTarget(60 + v * 0.25, 0.1)   // 갈리는 저음
        let sq = br > 0 && v < 260 ? (rng.next() < 0.78 ? 1 : 0.12) * 0.035 * min(1, (260 - v) / 120) : 0   // 쇳소리: 멈출 무렵에만, 끊겼다 이어진다
        a.squealGain = ParamTarget(sq, 0.015)
        a.squealFreq0 = ParamTarget(3150 * (1 + (rng.next() - 0.5) * 0.03), 0.01)                  // 불규칙한 떨림
        a.squealFreq1 = ParamTarget(4720 * (1 + (rng.next() - 0.5) * 0.03), 0.01)
        a.squealFreq2 = ParamTarget(6230 * (1 + (rng.next() - 0.5) * 0.03), 0.01)
        if lastPhase == .brake && s.phase == .stop { cues.append(.hiss) }
        lastPhase = s.phase
        a.crowdGain = ParamTarget(s.atStop && s.door > 0.5 ? 0.07 : 0, 0.3)
        a.humGain = ParamTarget(s.flickeryCar ? 0.012 + 0.03 * s.flicker : (s.oneBit ? 0 : 0.004), 0.05)
        // 문: 닫힘 시작이면 딩-동, 움직이기 시작하면 열림/닫힘 소리(닫힘은 요청 1.5초 안에만)
        if !seenDoorWant || lastDoorWant != s.doorWant {
            if seenDoorWant && lastDoorWant == true && s.doorWant == false && s.door > 0.5 { cues.append(.chime) }
            seenDoorWant = true; lastDoorWant = s.doorWant; doorT = s.time
        }
        let prev = lastDoor ?? s.door
        let dm = s.door > prev ? 1 : s.door < prev ? -1 : 0
        if dm != 0 && dm != doorMov && (s.time - doorT < 1.5 || dm > 0) { cues.append(.door(open: dm > 0)) }
        doorMov = dm; lastDoor = s.door
        return Output(targets: a, cues: cues)
    }
}

/// 오디오 스레드 쪽: 웹 sndInit 이 만든 계속 도는 노드 묶음. 같은 잡음 버퍼를 같은 시각에 돌리던 웹처럼
/// 백색 잡음 하나(바람 · 마찰 · 웅성임)와 갈색 잡음 하나(굴림 · 갈림)를 나눠 쓴다.
/// 이득은 표본마다, 필터 계수는 16표본마다 갱신한다(시간 상수가 10ms 이상이라 차이가 들리지 않는다).
struct AmbienceLoops {
    private let sr: Double
    private var rumG, rumF, motO, motF, motG, windF, windG, frG, grG, grF, sqG, sq0, sq1, sq2, crowdG, humG: TargetParam
    private var white = NoiseRNG(seed: 0xA5A5_1234)
    private var brown = BrownNoise()
    private var fRum = Biquad(), fMot = Biquad(), fWind = Biquad(), fFr1 = Biquad(), fFr2 = Biquad(), fGr = Biquad(), fCrowd = Biquad(), fHum = Biquad()
    private var oMot: Oscillator, oHum: Oscillator
    private var oSq0: Oscillator, oSq1: Oscillator, oSq2: Oscillator
    private var ctl = 0

    init(sampleRate: Double, tables: WaveTableSet) {
        sr = sampleRate
        oMot = Oscillator(.sawtooth, tables: tables); oHum = Oscillator(.square, tables: tables)
        oSq0 = Oscillator(.sine, tables: tables); oSq1 = Oscillator(.sine, tables: tables); oSq2 = Oscillator(.sine, tables: tables)
        let d = AmbienceTargets()
        rumG = TargetParam(0); rumF = TargetParam(d.rumFreq.value); motO = TargetParam(d.motFreq.value); motF = TargetParam(d.motFilter.value)
        motG = TargetParam(0); windF = TargetParam(d.windFreq.value); windG = TargetParam(0); frG = TargetParam(0); grG = TargetParam(0)
        grF = TargetParam(d.grindFreq.value); sqG = TargetParam(0); sq0 = TargetParam(3150); sq1 = TargetParam(4720); sq2 = TargetParam(6230)
        crowdG = TargetParam(0); humG = TargetParam(0)
        fFr1.set(.bandpass, freq: 2600, q: 9, sampleRate: sr); fFr2.set(.bandpass, freq: 3900, q: 11, sampleRate: sr)
        fCrowd.set(.bandpass, freq: 500, q: 0.8, sampleRate: sr); fHum.set(.lowpass, freq: 900, q: 1, sampleRate: sr)
        refreshFilters()
    }

    mutating func apply(_ a: AmbienceTargets) {
        func t(_ p: inout TargetParam, _ x: ParamTarget) { p.setTarget(x.value, tc: x.tc, sampleRate: sr) }
        t(&rumG, a.rumGain); t(&rumF, a.rumFreq); t(&motO, a.motFreq); t(&motF, a.motFilter); t(&motG, a.motGain)
        t(&windF, a.windFreq); t(&windG, a.windGain); t(&frG, a.fricGain); t(&grG, a.grindGain); t(&grF, a.grindFreq)
        t(&sqG, a.squealGain); t(&sq0, a.squealFreq0); t(&sq1, a.squealFreq1); t(&sq2, a.squealFreq2)
        t(&crowdG, a.crowdGain); t(&humG, a.humGain)
    }

    private mutating func refreshFilters() {
        fRum.set(.lowpass, freq: rumF.value, q: 1, sampleRate: sr)
        fMot.set(.bandpass, freq: motF.value, q: 6, sampleRate: sr)
        fWind.set(.bandpass, freq: windF.value, q: 0.7, sampleRate: sr)
        fGr.set(.lowpass, freq: grF.value, q: 1, sampleRate: sr)
    }

    private var silent: Bool {
        rumG.isSilent && motG.isSilent && windG.isSilent && frG.isSilent && grG.isSilent && sqG.isSilent && crowdG.isSilent && humG.isSilent
    }

    /// amb · sfx 버스에 더한다
    mutating func render(amb: UnsafeMutablePointer<Float>, sfx: UnsafeMutablePointer<Float>, frames n: Int) {
        if silent { return }
        for i in 0..<n {
            if ctl == 0 {
                rumF.step(16); motF.step(16); windF.step(16); grF.step(16)
                refreshFilters(); ctl = 16
            }
            ctl -= 1
            rumG.step(); motO.step(); motG.step(); windG.step(); frG.step(); grG.step(); sqG.step()
            sq0.step(); sq1.step(); sq2.step(); crowdG.step(); humG.step()
            let w = white.white(), b = brown.next(white.white())
            var a: Float = 0, s: Float = 0
            a += fRum.process(b) * Float(rumG.value)
            a += fMot.process(oMot.next(freq: motO.value, sampleRate: sr)) * Float(motG.value)
            a += fWind.process(w) * Float(windG.value)
            a += fCrowd.process(w) * Float(crowdG.value)
            a += fHum.process(oHum.next(freq: 120, sampleRate: sr)) * Float(humG.value)
            s += (fFr1.process(w) + fFr2.process(w)) * Float(frG.value)
            let sq = 0.5 * oSq0.next(freq: sq0.value, sampleRate: sr) + 0.32 * oSq1.next(freq: sq1.value, sampleRate: sr) + 0.18 * oSq2.next(freq: sq2.value, sampleRate: sr)
            s += sq * Float(sqG.value)
            s += fGr.process(b) * Float(grG.value)
            amb[i] += a; sfx[i] += s
        }
    }
}

/// 43 보너스 차 경보: 사각파 → 대역 통과 1100 Q1.2, 초당 4번 880 ↔ 1180 Hz. 끄면 300Hz 로 미끄러지며 0.5초에 사라진다.
struct AlarmLoop {
    private let sr: Double
    var on = false
    private var freq = TargetParam(440), gain = TargetParam(0)
    private var osc: Oscillator
    private var bp = Biquad()
    private var ctl = 0

    init(sampleRate: Double, tables: WaveTableSet) {
        sr = sampleRate
        osc = Oscillator(.square, tables: tables)
        bp.set(.bandpass, freq: 1100, q: 1.2, sampleRate: sampleRate)
    }

    mutating func render(sfx: UnsafeMutablePointer<Float>, frames n: Int, startTime: Double) {
        if !on && gain.isSilent { return }
        for i in 0..<n {
            if ctl == 0 {       // 웹은 프레임마다 setTarget — 여기선 64표본(≈1.3ms)마다
                let t = startTime + Double(i) / sr, ph = Int(t * 4) % 2
                freq.setTarget(on ? (ph == 1 ? 880 : 1180) : 300, tc: on ? 0.01 : 0.6, sampleRate: sr)
                gain.setTarget(on ? 0.045 : 0, tc: on ? 0.05 : 0.5, sampleRate: sr)
                ctl = 64
            }
            ctl -= 1
            freq.step(); gain.step()
            sfx[i] += bp.process(osc.next(freq: freq.value, sampleRate: sr)) * Float(gain.value)
        }
    }
}
