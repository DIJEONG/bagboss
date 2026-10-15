import Foundation
import BBCore
import BBContent

/// 인물별 대사 목소리(웹 44-story.js VOX) — 추출 데이터에서 읽는다.
public struct VoxPreset: Sendable, Decodable, Equatable {
    /// 기준 음높이(Hz)
    public let f: Double
    public let type: String
    /// 글자 하나 길이(ms)
    public let ms: Double
    /// 모음에 따른 음높이 폭(반음)
    public let span: Double
    public let vol: Double
    /// 글자 안에서 음높이가 미끄러지는 배수
    public let slide: Double

    public var waveform: Waveform { Waveform(web: type) ?? .triangle }
}

/// 대사 blip: 글자 하나 → 짧은 음 하나. 한글이면 중성(모음)으로 음높이를 정하고, 아니면 글자 코드로 흩뿌린다.
/// 웹 blip(who, ch) 그대로. 무작위 ±0.6반음은 주입 난수.
public struct BlipVoice: Sendable {
    public let presets: [String: VoxPreset]
    /// 중성 21개 → 음높이 단계(웹 VOWEL)
    public let vowel: [Int]

    public init(presets: [String: VoxPreset], vowel: [Int]) {
        self.presets = presets; self.vowel = vowel
    }
    /// 추출 데이터(VOX · VOWEL)에서
    public init(content: ContentStore) throws {
        try self.init(presets: content.decode("VOX"), vowel: content.decode("VOWEL"))
    }

    /// 웹 타자 효과가 blip 을 내는 글자인가(공백 · 문장 부호 제외 — 44-story.js tkShow)
    public static func speaks(_ ch: Character) -> Bool {
        !(ch.isWhitespace || ".,!?…·—:()".contains(ch))
    }

    /// 글자 하나의 소리. 모르는 인물은 'cond'(웹 기본값).
    public func voice<R: GameRandom>(who: String, char ch: Character, rng: inout R) -> VoiceSpec? {
        guard let V = presets[who] ?? presets["cond"], let code = ch.utf16.first.map(Int.init) else { return nil }
        var st: Double
        if code >= 0xAC00 && code <= 0xD7A3 {
            st = Double(vowel[((code - 0xAC00) % 588) / 28]) * V.span / 4
        } else {
            let span2 = Int(V.span * 2)
            st = Double((code * 7) % max(1, span2)) - V.span
        }
        st += (rng.next() - 0.5) * 1.2
        let f = V.f * pow(2, st / 12), d = V.ms / 1000 * 0.85
        var v = VoiceSpec(source: .osc(V.waveform), stop: d + 0.02)
        v.freq.set(f, at: 0); v.freq.linear(to: f * V.slide, at: d)
        v.gain.set(0, at: 0); v.gain.linear(to: V.vol, at: 0.006); v.gain.exponential(to: 0.0005, at: d)
        return v
    }
}
