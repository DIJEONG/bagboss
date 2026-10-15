import Foundation
import BBCore

/// 효과음 이름표 → 소리 처방 묶음. 웹 35-audio.js `sfx.*` 의 재료 · 수치를 그대로 옮겼다(웹 줄과 1:1 로 대응).
/// 무작위(음높이 흔들림 · 유리 조각 · 잡음 씨앗)는 주입받은 난수만 쓴다 → 같은 씨앗이면 같은 소리.
/// 메인 스레드에서 돈다(배열 할당 가능). 결과 VoiceSpec 은 SynthCore 로 보내 오디오 스레드가 그린다.
public struct SfxBank: Sendable {
    /// floor() 연속 방지 시각(웹 SND.floorT)
    public private(set) var lastFloor = -9.0

    public init() {}

    /// 한 효과음의 결과
    public struct Expansion: Sendable {
        public var voices: [VoiceSpec] = []
        public var duck: Duck?
    }

    // MARK: 웹 원형 도구 — nz(잡음 터짐) · tone(음 하나, 높이 미끄러짐)

    /// 웹 `nz(t, dur, {f, q, type, g, att, to, bus})` — 시작 지연은 VoiceSpec.delay 로 따로
    public static func nz(_ dur: Double, f: Double = 1200, q: Double = 1, type: FilterType = .bandpass, g: Double = 0.5,
                          att: Double = 0.002, to: Double? = nil, bus: Bus = .sfx, seed: UInt32, delay: Double = 0) -> VoiceSpec {
        var v = VoiceSpec(source: .white, stop: dur + 0.05)
        v.bus = bus; v.delay = delay; v.seed = seed
        // 웹: s.start(t, Math.random()*1.5) — 2초 버퍼의 무작위 위치에서 시작(버퍼 끝에서 잡음이 끊긴다)
        var h = NoiseSeed(UInt64(seed) &* 0x2545_F491_4F6C_DD1D)
        let offset = Double(h.next() >> 8) / 16_777_216 * 1.5
        v.noiseLength = 2 - offset
        v.filter = type; v.q = q
        v.filterFreq.set(f, at: 0)
        if let to { v.filterFreq.exponential(to: to, at: dur) }
        v.gain = envelope(g: g, att: att, dur: dur)
        return v
    }

    /// 웹 `tone(t, dur, {f, to, type, g, att, bus})`
    public static func tone(_ dur: Double, f: Double = 440, to: Double? = nil, type: Waveform = .sine, g: Double = 0.3,
                            att: Double = 0.004, bus: Bus = .sfx, delay: Double = 0) -> VoiceSpec {
        var v = VoiceSpec(source: .osc(type), stop: dur + 0.05)
        v.bus = bus; v.delay = delay
        v.freq.set(f, at: 0)
        if let to { v.freq.exponential(to: to, at: dur) }
        v.gain = envelope(g: g, att: att, dur: dur)
        return v
    }

    /// 0 → (선형, att) g → (지수, dur) .001
    static func envelope(g: Double, att: Double, dur: Double) -> ParamTimeline {
        var e = ParamTimeline(1)
        e.set(0, at: 0); e.linear(to: g, at: att); e.exponential(to: 0.001, at: dur)
        return e
    }

    /// 웹 skTone(f0, f1, d, type, v): 바로 v 로 시작해 지수로 .0005 까지
    public static func skTone(f0: Double, f1: Double, dur: Double, wave: Waveform, vol: Double, delay: Double = 0) -> VoiceSpec {
        var v = VoiceSpec(source: .osc(wave), stop: dur + 0.02)
        v.delay = delay
        v.freq.set(f0, at: 0); v.freq.exponential(to: f1, at: dur)
        v.gain.set(vol, at: 0); v.gain.exponential(to: 0.0005, at: dur)
        return v
    }

    /// 웹 skNoise(d, f, g): 대역 잡음(Q 1.2)
    public static func skNoise(dur: Double, f: Double, g: Double, seed: UInt32, delay: Double = 0) -> VoiceSpec {
        var v = VoiceSpec(source: .white, stop: dur + 0.02)
        v.delay = delay; v.seed = seed
        v.filter = .bandpass; v.q = 1.2
        v.filterFreq = .constant(f)
        v.gain.set(g, at: 0); v.gain.exponential(to: 0.0005, at: dur)
        return v
    }

    // MARK: 펼치기

    /// 이름표 하나를 소리 처방으로 펼친다. now = 합성기 시계(초) — floor 연속 방지에만 쓴다.
    public mutating func expand<R: GameRandom>(_ cue: SfxCue, now: Double = 0, rng: inout R) -> Expansion {
        var b = Builder(seeds: SplitMix64(seed: rng.nextUInt64()))
        var duck: Duck?
        switch cue {
        case .clack(let speed):
            let k = min(1, speed / 600)
            b.nz(0, 0.05, f: 900, q: 2, g: 0.25 * k + 0.05); b.tone(0, 0.08, f: 95, to: 60, g: 0.35 * k + 0.05)
        case .hit(let heavy, let crit):
            if heavy { b.tone(0, 0.28, f: 120, to: 38, g: 0.75); b.nz(0, 0.18, f: 600, q: 0.7, g: 0.55, to: 180); b.nz(0, 0.06, f: 3000, q: 0.8, g: 0.25) }
            else { b.tone(0, 0.09, f: 170, to: 80, g: 0.45); b.nz(0, 0.07, f: 1500 + rng.next() * 600, q: 1.2, g: 0.35) }
            if crit { b.tone(0.01, 0.35, f: 1760, type: .triangle, g: 0.16); b.tone(0.01, 0.3, f: 2637, g: 0.1); b.nz(0, 0.25, f: 6000, q: 0.6, type: .highpass, g: 0.12) }
        case .hitK(let kind, let crit, let combo):
            let pv = (1 + (rng.next() - 0.5) * 0.16) * (1 + Double(min(10, combo)) * 0.025)   // 음높이 흔들림 · 연타 상승
            switch kind {
            case .jab: b.nz(0, 0.045, f: 2400 * pv, q: 1.4, g: 0.32); b.tone(0, 0.06, f: 210 * pv, to: 120, g: 0.3)           // 탁
            case .punch: b.tone(0, 0.12, f: 150 * pv, to: 62, g: 0.55); b.nz(0, 0.08, f: 900 * pv, q: 0.9, g: 0.4, to: 500)    // 퍽
            case .hammer:                                                                                                    // 쇠망치
                b.tone(0, 0.2, f: 130 * pv, to: 55, g: 0.65); b.nz(0, 0.09, f: 1800, q: 1.2, g: 0.35)
                b.tone(0.003, 0.16, f: 1250 * pv, type: .triangle, g: 0.11); b.tone(0.003, 0.12, f: 1870 * pv, g: 0.06)
            case .kick: b.tone(0, 0.16, f: 115 * pv, to: 48, g: 0.6); b.nz(0, 0.13, f: 700 * pv, q: 0.8, g: 0.42, to: 300)     // 퍽(묵직)
            case .big: b.tone(0, 0.3, f: 120 * pv, to: 36, g: 0.8); b.nz(0, 0.2, f: 600, q: 0.7, g: 0.55, to: 170); b.nz(0, 0.05, f: 1900, q: 0.7, g: 0.14)   // 쾅
            }
            if crit { b.critCrack(pv) }
        case .hit3(let tier, let crit, let combo, let air, let big):
            let pv = (1 + (rng.next() - 0.5) * 0.12) * (1 + Double(min(10, combo)) * 0.022) * (air ? 1.07 : 1), sub = air ? 0.45 : 1
            if tier <= 0 {                                                                                                   // 탁: 짧고 높게
                b.nz(0, 0.04, f: 2700 * pv, q: 1.5, g: 0.36); b.tone(0, 0.055, f: 230 * pv, to: 130, g: 0.3); b.nz(0.004, 0.03, f: 5200, q: 0.7, type: .highpass, g: 0.08)
            } else if tier == 1 {                                                                                            // 퍽 + 짧은 여운
                b.nz(0, 0.03, f: 1600 * pv, q: 1, g: 0.24); b.tone(0, 0.13, f: 150 * pv, to: 58, g: 0.55)
                b.nz(0, 0.1, f: 720 * pv, q: 0.8, g: 0.38, to: 340); b.nz(0.02, 0.14, f: 320, q: 0.6, type: .lowpass, g: 0.07 * sub, att: 0.01)
            } else {                                                                                                         // 쾅: 갈라짐 + 몸통 + 초저음 + 긴 여운
                b.nz(0, 0.025, f: 3000, q: 0.6, type: .highpass, g: 0.3); b.tone(0, 0.32, f: 108 * pv, to: 34, g: 0.85)
                b.nz(0, 0.2, f: 620 * pv, q: 0.7, g: 0.55, to: 160); b.tone(0, 0.45, f: 54, to: 30, g: 0.5 * sub)
                b.nz(0.03, big ? 0.6 : 0.4, f: 420, q: 0.5, type: .lowpass, g: (big ? 0.22 : 0.14) * sub, att: 0.025, to: 110)
                if big { duck = Duck(k: 0.32, hold: 0.14, rel: 0.36) }
            }
            if crit { b.critCrack(pv) }
        case .just:
            b.nz(0, 0.06, f: 5200, q: 0.7, type: .highpass, g: 0.16); b.tone(0, 0.22, f: 1568, type: .triangle, g: 0.17)
            b.tone(0.035, 0.32, f: 2349, g: 0.11); b.nz(0, 0.18, f: 900, q: 0.8, g: 0.12, to: 3200)
        case .floor(let p):
            if now - lastFloor < 0.07 { return Expansion() }
            lastFloor = now
            let k = min(1.6, p)
            b.tone(0, 0.16 + 0.1 * k, f: 74 + 8 * k, to: 36, g: 0.18 + 0.22 * k)
            b.nz(0, 0.12 + 0.08 * k, f: 260, q: 0.6, type: .lowpass, g: 0.12 + 0.14 * k)
            if k > 1.1 { b.nz(0.02, 0.22, f: 1300, q: 1.4, g: 0.05) }
        case .thud:
            b.tone(0, 0.22, f: 78, to: 40, g: 0.55); b.nz(0, 0.18, f: 320, q: 0.6, type: .lowpass, g: 0.35)
        case .swing:
            b.nz(0, 0.13, f: 600, q: 0.9, g: 0.16, to: 2400)
        case .hurt(let heavy):
            b.tone(0, 0.16, f: 140, to: 70, type: .triangle, g: 0.5); b.nz(0, 0.1, f: 800, q: 1, g: 0.3)
            if heavy { b.tone(0, 0.3, f: 96, to: 36, g: 0.6); b.nz(0, 0.18, f: 520, q: 0.7, g: 0.4, to: 160); duck = Duck(k: 0.45, hold: 0.1, rel: 0.3) }
        case .glass:
            for k in 0..<6 {
                let d = Double(k) * 0.012 + rng.next() * 0.02, dur = 0.12 + rng.next() * 0.1, f = 3000 + rng.next() * 4000
                b.nz(d, dur, f: f, q: 8, g: 0.18)
            }
            b.tone(0, 0.1, f: 200, to: 90, g: 0.2)
        case .boom:
            b.tone(0, 0.7, f: 90, to: 28, g: 0.9); b.nz(0, 0.6, f: 400, q: 0.6, type: .lowpass, g: 0.6, to: 60)
        case .whoosh:
            b.nz(0, 0.35, f: 300, q: 0.7, g: 0.3, to: 2000)
        case .dodge:
            b.nz(0, 0.2, f: 2400, q: 1.5, g: 0.2, to: 500)
        case .press:
            b.tone(0, 0.6, f: 60, to: 30, g: 0.55); b.nz(0, 0.5, f: 200, q: 0.5, type: .lowpass, g: 0.35, to: 60)
        case .chime:                                                                                                         // 내려가는 딩-동
            b.tone(0, 0.5, f: 659, g: 0.22); b.tone(0.38, 0.7, f: 523, g: 0.22); b.tone(0, 0.5, f: 1318, g: 0.05); b.tone(0.38, 0.7, f: 1046, g: 0.05)
        case .door(let open):
            b.nz(0, 0.5, f: open ? 500 : 900, q: 0.8, g: 0.16, to: open ? 1400 : 350); b.tone(0.48, 0.12, f: 110, to: 70, g: 0.25)
        case .click:
            b.tone(0, 0.05, f: 1200, type: .square, g: 0.12)
        case .coin:
            b.tone(0, 0.12, f: 1568, type: .triangle, g: 0.15); b.tone(0.07, 0.25, f: 2093, type: .triangle, g: 0.13)
        case .merge(let ok):
            if ok { for (i, f) in [523.0, 659, 784, 1046].enumerated() { b.tone(Double(i) * 0.07, 0.3, f: f, type: .triangle, g: 0.2) } }
            else { b.tone(0, 0.4, f: 180, to: 90, type: .sawtooth, g: 0.12); b.tone(0.15, 0.45, f: 140, to: 70, type: .sawtooth, g: 0.1) }
        case .clear:
            for (i, f) in [392.0, 523, 659, 784].enumerated() { b.tone(Double(i) * 0.09, 0.35, f: f, type: .triangle, g: 0.16) }
        case .slowIn:
            b.tone(0, 0.9, f: 110, to: 46, g: 0.35, att: 0.08); b.nz(0, 0.8, f: 900, q: 0.6, type: .lowpass, g: 0.22, att: 0.1, to: 120)
        case .carHit(let h):
            b.tone(0, 0.16, f: h ? 95 : 120, to: 45, g: 0.55); b.nz(0, 0.12, f: h ? 650 : 900, q: 2.2, g: 0.42, to: 300); b.nz(0.02, 0.18, f: 340, q: 6, g: 0.18)
        case .gong:
            b.tone(0, 1.4, f: 98, g: 0.5); b.tone(0, 1.2, f: 196 * 1.5, type: .triangle, g: 0.16); b.tone(0, 1.0, f: 523, g: 0.08); b.nz(0, 0.5, f: 900, q: 2, g: 0.2)
        case .ready:
            for (i, f) in [659.0, 880, 1318].enumerated() { b.tone(Double(i) * 0.06, 0.3, f: f, type: .triangle, g: 0.14) }
        case .brass:                                                                                                         // 톱니 넷 + 열렸다 닫히는 저역 통과
            for f in [146.8, 174.6, 220, 293.7] {
                var v = VoiceSpec(source: .osc(.sawtooth), stop: 1.0)
                v.freq = .constant(f)
                v.filter = .lowpass; v.q = 1
                v.filterFreq.set(300, at: 0); v.filterFreq.exponential(to: 2600, at: 0.08); v.filterFreq.exponential(to: 500, at: 0.7)
                v.gain.set(0, at: 0); v.gain.linear(to: 0.11, at: 0.03); v.gain.exponential(to: 0.001, at: 0.9)
                b.voices.append(v)
            }
            b.tone(0, 0.6, f: 73, to: 60, g: 0.5)
        case .rage:
            b.tone(0, 0.8, f: 62, to: 48, type: .sawtooth, g: 0.18); b.nz(0, 0.7, f: 300, q: 0.7, type: .lowpass, g: 0.35)
            b.tone(0.05, 0.5, f: 93, to: 70, type: .square, g: 0.08)
        case .hiss:                                                                                                          // 에어 브레이크
            b.tone(0, 0.12, f: 90, to: 55, g: 0.3); b.nz(0.05, 1.1, f: 5200, q: 0.4, type: .highpass, g: 0.16, att: 0.03); b.nz(0.05, 0.6, f: 2400, q: 0.8, g: 0.07, att: 0.02)
        case .pass:                                                                                                          // 교행: 굉음 · 경적
            b.nz(0, 1.7, f: 300, q: 0.5, type: .lowpass, g: 0.5, att: 0.35, to: 1200); b.nz(0.2, 1.2, f: 2500, q: 0.7, g: 0.12, att: 0.3)
            b.tone(0.05, 0.55, f: 311, type: .square, g: 0.06); b.tone(0.05, 0.55, f: 392, type: .square, g: 0.06); b.tone(0.05, 0.55, f: 466, type: .square, g: 0.04)
        case .zap:
            for k in 0..<4 {
                let d = Double(k) * 0.035 + rng.next() * 0.02
                b.nz(d, 0.03, f: 4200 + rng.next() * 2000, q: 0.6, type: .highpass, g: 0.15)
            }
            b.tone(0, 0.09, f: 120, type: .square, g: 0.045)
        case .unlock:
            for (i, f) in [523.0, 784, 1046, 1318, 1568].enumerated() { b.tone(Double(i) * 0.08, 0.5, f: f, type: .triangle, g: 0.15) }

        case .doorCreak: b.nz(0, 0.4, f: 700, q: 6, g: 0.12, to: 300)
        case .footSplash: b.nz(0, 0.06, f: 900, q: 1, g: 0.12)
        case .tallyTick: b.tone(0, 0.03, f: 1600, type: .square, g: 0.04)
        case .tireBurst: b.nz(0, 0.08, f: 1400, q: 0.8, g: 0.5)
        case .fireCrackle: b.nz(0, 0.05, f: 2200 + rng.next() * 1500, q: 3, g: 0.05)
        case .debrisClank: b.tone(0, 0.12, f: 520, to: 260, type: .triangle, g: 0.12)
        case .countdownBeep(let final): b.tone(0, 0.09, f: final ? 1320 : 880, type: .square, g: 0.08)
        case .skTone(let f0, let f1, let dur, let wave, let vol, let delay):
            b.voices.append(Self.skTone(f0: f0, f1: f1, dur: dur, wave: wave, vol: vol, delay: delay))
        case .skNoise(let dur, let f, let g, let delay):
            b.voices.append(Self.skNoise(dur: dur, f: f, g: g, seed: b.seeds.nextSeed(), delay: delay))
        case .tone(let dur, let f, let to, let wave, let g, let att, let delay):
            b.tone(delay, dur, f: f, to: to, type: wave, g: g, att: att)
        case .noise(let dur, let f, let q, let filter, let g, let att, let to, let delay):
            b.nz(delay, dur, f: f, q: q, type: filter, g: g, att: att, to: to)
        }
        return Expansion(voices: b.voices, duck: duck)
    }

    /// 펼치기 도우미: 웹 호출 모양(t, dur, {…}) 그대로 적게 한다
    struct Builder {
        var voices: [VoiceSpec] = []
        var seeds: SplitMix64
        init(seeds: SplitMix64) { self.seeds = seeds; voices.reserveCapacity(10) }

        mutating func nz(_ t: Double, _ dur: Double, f: Double = 1200, q: Double = 1, type: FilterType = .bandpass, g: Double = 0.5, att: Double = 0.002, to: Double? = nil) {
            voices.append(SfxBank.nz(dur, f: f, q: q, type: type, g: g, att: att, to: to, seed: seeds.nextSeed(), delay: t))
        }
        mutating func tone(_ t: Double, _ dur: Double, f: Double = 440, to: Double? = nil, type: Waveform = .sine, g: Double = 0.3, att: Double = 0.004) {
            voices.append(SfxBank.tone(dur, f: f, to: to, type: type, g: g, att: att, delay: t))
        }
        /// 치명 '짝': 채찍처럼 갈라지는 잡음 + 묵직한 저음(hitK · hit3 공통)
        mutating func critCrack(_ pv: Double) {
            nz(0, 0.035, f: 2400, q: 0.6, type: .highpass, g: 0.34); nz(0.01, 0.09, f: 1100, q: 0.7, g: 0.3, to: 600); tone(0, 0.18, f: 110 * pv, to: 45, g: 0.5)
        }
    }
}

extension SplitMix64 {
    /// 잡음 씨앗(0 아님)
    mutating func nextSeed() -> UInt32 { UInt32(truncatingIfNeeded: nextUInt64() >> 16) | 1 }
}
