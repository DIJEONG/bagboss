import Foundation

/// 소리 설정 — 웹 localStorage 'dotlab-snd' 와 같은 키 · 모양: `{"vol":{"master":.8,"music":.55,"sfx":.8},"muted":false}`.
/// 모르는 키가 와도 무시하고, 빠진 키는 웹 기본값으로 채운다(웹 Object.assign 과 같은 효과).
public struct SoundSettings: Sendable, Equatable, Codable {
    public struct Volumes: Sendable, Equatable, Codable {
        public var master: Double = 0.8
        public var music: Double = 0.55
        public var sfx: Double = 0.8
        public init(master: Double = 0.8, music: Double = 0.55, sfx: Double = 0.8) { self.master = master; self.music = music; self.sfx = sfx }
        public init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            master = try c.decodeIfPresent(Double.self, forKey: .master) ?? 0.8
            music = try c.decodeIfPresent(Double.self, forKey: .music) ?? 0.55
            sfx = try c.decodeIfPresent(Double.self, forKey: .sfx) ?? 0.8
        }
    }
    public var vol = Volumes()
    public var muted = false
    /// 네이티브 전용: 타격음에 녹음 조각을 겹친다(docs/11 §녹음 타격음). 끄면 웹 합성 그대로.
    /// 'dotlab-snd' 모양에는 넣지 않는다(저장 · 디코딩 키는 vol · muted 뿐 — 앱이 'bbn-sfx-sample' 로 따로 저장)
    public var sampleHits = true

    private enum CodingKeys: String, CodingKey { case vol, muted }

    public init(vol: Volumes = Volumes(), muted: Bool = false, sampleHits: Bool = true) { self.vol = vol; self.muted = muted; self.sampleHits = sampleHits }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        vol = try c.decodeIfPresent(Volumes.self, forKey: .vol) ?? Volumes()
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
    }

    /// 웹 저장 키
    public static let storageKey = "dotlab-snd"

    /// 버스 이득(웹 sndApplyVol): music = 음악×.5 · sfx = 효과음 · amb = 효과음×.7 · master = 음소거면 0
    public var busGains: (music: Double, sfx: Double, amb: Double, master: Double) {
        (vol.music * 0.5, vol.sfx, vol.sfx * 0.7, muted ? 0 : vol.master)
    }
}
