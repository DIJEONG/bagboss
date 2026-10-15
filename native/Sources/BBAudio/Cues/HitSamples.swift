import Foundation
import BBCore

// 녹음 타격음 층(네이티브 전용 · SoundSettings.sampleHits — docs/11 §녹음 타격음).
// 웹 합성 처방(SfxBank.expand)을 그대로 펼친 뒤, 타격 스타일마다
//   · 합성의 '찰싹 · 갈라짐' 잡음(대역 · 고역 통과 잡음)은 녹음 조각으로 바꾸고
//   · 합성의 낮은 몸통(사인 '쿵' · 저역 통과 여운)과 치명 '짝'(critCrack)은 남겨 겹친다.
// 끄면(sampleHits = false) 이 파일은 불리지 않는다 → 소리는 지금 합성 그대로.

/// 타격 스타일 — 녹음 조각과 겹치기 방식을 고르는 단위
public enum HitStyle: String, Sendable, CaseIterable {
    /// 잽 '탁'
    case jab
    /// 주먹 '퍽'(스트레이트 · 훅 · 팔꿈치)
    case punch
    /// 발차기 · 무릎 '퍽(묵직)'
    case kick
    /// 몸통 치기(리버 블로 · 숄더 롤 카운터) — 둔하고 낮게
    case body
    /// 올려치기 · 띄우기(어퍼 · 승천권 · 무릎 올려치기 · 파고들어 올려치기)
    case upper
    /// 쇠망치(프롤로그 장도리)
    case hammer
    /// 메치기 · 내려찍기 · 넘어뜨리기 '쾅'
    case big
}

/// 타격 맥락 — 앱이 표현 층(SoundCue.hit3 의 detail)에서 옮겨 준다. 없으면 이름표만 보고 고른다
public struct HitContext: Sendable, Equatable {
    /// 때린 동작(웹 att.anim — 'jab' · 'upper' · 'nv_liver' …)
    public var move: String
    /// 받아치기 · 카운터(COUNTER/BLAM)
    public var counter: Bool
    public init(move: String = "", counter: Bool = false) { self.move = move; self.counter = counter }
}

public enum HitSampleMap {
    /// 동작 → 스타일(모르는 동작은 nil → 이름표의 등급 · 종류로)
    public static func style(move raw: String) -> HitStyle? {
        let m = raw.hasSuffix("_air") ? String(raw.dropLast(4)) : raw
        switch m {
        case "jab", "nv_flick", "bfist", "swat": return .jab
        case "cross", "hook", "nv_hook", "elbow", "uthrust", "nv_cork", "hbutt", "nv_headbutt", "nv_dial": return .punch
        case "kick", "round", "sweep", "knee", "bkick", "stomp", "polespin", "hangkick", "charge", "fkick", "skick",
             "renkan", "cycle", "nv_lowk", "nv_stomp": return .kick
        case "upper", "scoop", "nv_rise", "nv_kneelift", "nv_duckup", "nv_liverup": return .upper
        case "nv_liver", "nv_roll": return .body
        case "axe", "suplex", "throw", "tetsu", "nv_sx_arch", "nv_gr_swing", "nv_slam", "nv_stamp", "nv_punt": return .big
        default:
            if m.hasPrefix("nv_hl_") || m.hasPrefix("nv_gr_") || m.hasPrefix("nv_sx_") { return .big }   // 네이티브 잡기 · 메치기 계열
            if m.hasPrefix("hm_") { return .hammer }
            return nil
        }
    }

    /// 이름표(+맥락) → 스타일. 타격음이 아니면 nil
    public static func style(for cue: SfxCue, context: HitContext? = nil) -> HitStyle? {
        switch cue {
        case .hitK(let k, _, _):
            switch k {
            case .jab: return .jab
            case .punch: return .punch
            case .kick: return .kick
            case .hammer: return .hammer
            case .big: return .big
            }
        case .hit3(let tier, _, _, _, _):
            if let m = context?.move, let s = style(move: m) { return s }
            return tier <= 0 ? .jab : tier == 1 ? .punch : .big
        default: return nil
        }
    }

    /// 스타일 → 조각 후보(둘 이상이면 번갈아 — 같은 소리 반복을 줄인다)
    public static func clips(_ s: HitStyle) -> [HitClip] {
        switch s {
        case .jab: [.jab]
        case .punch: [.punchA, .punchB]
        case .kick: [.kickA, .kickB]
        case .body: [.kickB]
        case .upper: [.upper]
        case .hammer: [.hammer]
        case .big: [.big]
        }
    }

    /// 겹치기 처방
    public struct Recipe: Sendable, Equatable {
        /// 녹음 조각 이득 · 기본 속도(높이)
        public var gain: Double, rate: Double
        /// 합성 몸통 이득(남긴 소리에 곱한다)
        public var synthGain: Double
        /// 녹음 조각에 거는 저역 통과(Hz, nil = 없음) — 몸통 치기를 둔하게
        public var lowpass: Double?
    }

    /// 이득은 오프라인 렌더(HitCompareRender · master .8 · sfx .8 · 컴프레서 뒤)에서 앞 150ms RMS 가 합성보다 0~+3dB 가 되게 맞췄다
    public static func recipe(_ s: HitStyle) -> Recipe {
        switch s {
        case .jab: Recipe(gain: 0.3, rate: 1.0, synthGain: 0.6)
        case .punch: Recipe(gain: 0.5, rate: 1.0, synthGain: 0.8)
        case .kick: Recipe(gain: 0.47, rate: 0.97, synthGain: 0.85)
        case .body: Recipe(gain: 0.45, rate: 0.92, synthGain: 1.0, lowpass: 2400)
        case .upper: Recipe(gain: 0.62, rate: 1.03, synthGain: 0.8)
        case .hammer: Recipe(gain: 0.45, rate: 1.0, synthGain: 1.0)
        case .big: Recipe(gain: 0.6, rate: 0.97, synthGain: 0.75)
        }
    }

    /// 재생 속도 흔들림 폭(±4.5%) · 이득 흔들림 폭(±10% ≈ ±0.9dB)
    public static let rateJitter = 0.09, gainJitter = 0.2
}

extension ParamTimeline {
    /// 모든 값에 k 를 곱한 타임라인(이득 줄이기)
    func scaled(_ k: Double) -> ParamTimeline {
        var t = self
        t.initial *= k
        for i in 0..<count { var e = t[i]; e.value *= k; t[i] = e }
        return t
    }
}

extension SfxBank {
    /// 녹음 조각을 겹친 타격음. 타격음이 아니면 expand 와 같다.
    /// 합성 처방은 expand 를 그대로 한 번 부른 결과에서 고른다(난수 소비가 같다) — 그 뒤 조각 고르기 · 흔들림에 난수 셋을 더 쓴다.
    public mutating func expandLayered<R: GameRandom>(_ cue: SfxCue, context: HitContext? = nil, now: Double = 0, rng: inout R) -> Expansion {
        guard let style = HitSampleMap.style(for: cue, context: context) else { return expand(cue, now: now, rng: &rng) }
        let synth = expand(cue, now: now, rng: &rng)
        let (crit, combo, air, tier): (Bool, Int, Bool, Int) = {
            switch cue {
            case .hitK(let k, let c, let n): return (c, n, false, k == .jab ? 0 : k == .big ? 2 : 1)
            case .hit3(let t, let c, let n, let a, _): return (c, n, a, t)
            default: return (false, 0, false, 1)
            }
        }()
        let R = HitSampleMap.recipe(style)
        var out = Expansion(voices: [], duck: synth.duck)
        out.voices.reserveCapacity(synth.voices.count + 3)

        // 1) 합성: 치명 '짝'(끝 3개 — Builder.critCrack)은 그대로, 나머지는 몸통만 남겨 줄인다
        let crackCount = crit ? 3 : 0
        let body = synth.voices.dropLast(crackCount)
        let heavy = tier >= 2 || style == .big          // '쾅': 대역 잡음 몸통(620→160Hz)까지 남긴다
        for v in body {
            let keep: Bool
            switch v.source {
            case .osc, .sample: keep = true
            case .white: keep = v.filter == .lowpass || (heavy && v.filter == .bandpass && v.filterFreq.startValue < 1000)
            }
            guard keep else { continue }
            var w = v; w.gain = v.gain.scaled(R.synthGain)
            out.voices.append(w)
        }
        out.voices.append(contentsOf: synth.voices.suffix(crackCount))

        // 2) 녹음 조각: 후보 중 하나 · 속도/이득 흔들림 · 연타 높이 상승(웹 hit3 와 같은 .022/단, 10단까지) · 공중 +4%
        let cands = HitSampleMap.clips(style)
        let pick = cands[min(cands.count - 1, Int(rng.next() * Double(cands.count)))]
        let jr = 1 + (rng.next() - 0.5) * HitSampleMap.rateJitter
        let jg = 1 + (rng.next() - 0.5) * HitSampleMap.gainJitter
        let comboUp = 1 + Double(min(10, combo)) * 0.022
        let rate = R.rate * jr * comboUp * (air ? 1.04 : 1)
        let tierK = tier <= 0 ? 0.85 : tier == 1 ? 1.0 : 1.15
        let counter = context?.counter == true
        let g = R.gain * jg * tierK * (crit ? 1.15 : 1) * (counter ? 1.15 : 1)
        out.voices.append(Self.sampleVoice(pick, gain: g, rate: rate, lowpass: R.lowpass))

        // 3) 치명 · 카운터: 한 겹 더(짧고 밝게)
        if crit {
            if style == .big { out.voices.append(Self.sampleVoice(.kickA, gain: 0.4, rate: 0.9 * comboUp, lowpass: nil)) }
            else { out.voices.append(Self.sampleVoice(.big, gain: 0.3, rate: 1.12 * comboUp, lowpass: nil)) }
        }
        if counter { out.voices.append(Self.sampleVoice(.jab, gain: 0.35, rate: 0.94 * comboUp, lowpass: nil)) }
        return out
    }

    /// 소리 내기 창구(AudioEngine.play 가 부른다): sampleHits 가 꺼져 있으면 expand 그대로(맥락 무시 · 난수 소비도 같다)
    public mutating func expand<R: GameRandom>(_ cue: SfxCue, context: HitContext?, sampleHits: Bool, now: Double = 0, rng: inout R) -> Expansion {
        sampleHits ? expandLayered(cue, context: context, now: now, rng: &rng) : expand(cue, now: now, rng: &rng)
    }

    /// 녹음 조각 소리 하나(이득 상수 · 조각이 끝나면 끝 — stop 은 상한)
    public static func sampleVoice(_ c: HitClip, gain: Double, rate: Double, lowpass: Double?, delay: Double = 0) -> VoiceSpec {
        var v = VoiceSpec(source: .sample(c), stop: 1.0)
        v.rate = rate; v.delay = delay
        v.gain = .constant(gain)
        if let lowpass { v.filter = .lowpass; v.q = 0.7; v.filterFreq = .constant(lowpass) }
        return v
    }
}
