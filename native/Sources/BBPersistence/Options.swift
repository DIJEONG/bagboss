// 옵션 · 소리 · 언어 · 커스텀 콤보 — 웹 저장 키와 같은 모양.
//   dotlab-opt  : 47-special-ui.js  OPT = { ...{autoSpc:false, shortCut:true, noFlash:false}, ...저장값 }
//   dotlab-snd  : 35-audio.js       v 가 참이면 Object.assign(SND.vol, v.vol||{}); SND.muted = !!v.muted
//   dotlab-lang : 00-i18n.js        JSON 이 아닌 날 문자열 'ko' | 'en' (없거나 빈 문자열이면 'ko')
//   dotlab-cc   : 42-dojo.js        배열이면 앞 CC_MAX(8)개, 아니면 기본 콤보 — 네이티브 앱은 앞 16개(nativeMaxSteps · 같은 키 · 같은 모양)
import Foundation

// MARK: - Options (dotlab-opt)

/// 옵션. 기본 3개 + 게임이 쓰는 몇 개는 타입으로, 개발자 설정(dev* · dj* …)은 extras 로 그대로 둔다.
public struct Options: Codable, Sendable, Equatable {
    public static let storageKey = "dotlab-opt"

    /// 자동 필살기
    public var autoSpc = false
    /// 짧은 연출
    public var shortCut = true
    /// 번쩍임 줄이기
    public var noFlash = false
    /// 주인공 양복 스킨(결제 연동 대상) — 저장값이 없으면 키가 없다
    public var skin: String?
    /// 진동
    public var vibe: Bool?
    /// 나머지(devBag · devCar · devGod · devLine · devLines · djbg · djDummy · djTab · djZoom · prologue · shades · twOT …)
    public var extras: [String: JSONValue] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        var r = try ObjectReader(decoder)
        autoSpc = r.read("autoSpc") ?? false
        shortCut = r.read("shortCut") ?? true
        noFlash = r.read("noFlash") ?? false
        skin = r.read("skin"); vibe = r.read("vibe")
        extras = r.extras()
    }

    public func encode(to encoder: Encoder) throws {
        var w = ObjectWriter(encoder, extras: extras)
        try w.write("autoSpc", autoSpc); try w.write("shortCut", shortCut); try w.write("noFlash", noFlash)
        try w.write("skin", skin); try w.write("vibe", vibe)
        try w.finish()
    }

    /// 웹 불러오기: 객체가 아니면(없음 · 깨짐 · null) 기본값, 객체면 기본값 위에 덮어쓴다
    public static func load(webJSON raw: String?) -> Options {
        guard let data = (raw ?? "{}").data(using: .utf8),
              let obj = try? JSONDecoder().decode(JSONValue.self, from: data), obj.objectValue != nil,
              let o = try? JSONDecoder().decode(Options.self, from: data) else { return Options() }
        return o
    }
}

// MARK: - SoundOptions (dotlab-snd)

public struct SoundOptions: Codable, Sendable, Equatable {
    public static let storageKey = "dotlab-snd"

    public var vol = Volumes()
    public var muted = false
    /// 웹은 {vol, muted} 만 쓰지만 모르는 필드도 보존한다
    public var extras: [String: JSONValue] = [:]

    public init() {}

    public struct Volumes: Codable, Sendable, Equatable {
        public var master = 0.8
        public var music = 0.55
        public var sfx = 0.8
        /// 웹 Object.assign 이라 저장값의 다른 키도 그대로 붙는다
        public var extras: [String: JSONValue] = [:]
        public init() {}
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            master = r.read("master") ?? 0.8; music = r.read("music") ?? 0.55; sfx = r.read("sfx") ?? 0.8
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("master", master); try w.write("music", music); try w.write("sfx", sfx); try w.finish()
        }
    }

    public init(from decoder: Decoder) throws {
        var r = try ObjectReader(decoder)
        vol = r.read("vol") ?? Volumes()
        // 웹 `!!v.muted` — 불리언이 아닌 값도 참/거짓으로
        if let m: JSONValue = r.read("muted") { muted = m.truthy } else { muted = false }
        extras = r.extras()
    }

    public func encode(to encoder: Encoder) throws {
        var w = ObjectWriter(encoder, extras: extras)
        try w.write("vol", vol); try w.write("muted", muted); try w.finish()
    }

    /// 웹 불러오기: 거짓 값(없음 · null · 깨짐)이면 기본값
    public static func load(webJSON raw: String?) -> SoundOptions {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONDecoder().decode(JSONValue.self, from: data), obj.truthy else { return SoundOptions() }
        guard obj.objectValue != nil, let s = try? JSONDecoder().decode(SoundOptions.self, from: data) else {
            return SoundOptions()   // 참이지만 객체가 아닌 값(숫자 등): 웹도 vol · muted 를 못 읽어 기본값이 된다
        }
        return s
    }
}

// MARK: - Language (dotlab-lang)

/// 언어 코드. 저장은 JSON 이 아닌 날 문자열이다(따옴표 없이 `ko`).
public struct Language: RawRepresentable, Codable, Sendable, Hashable {
    public static let storageKey = "dotlab-lang"
    public static let ko = Language(rawValue: "ko")
    public static let en = Language(rawValue: "en")

    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// 웹 `localStorage.getItem('dotlab-lang') || 'ko'`
    public static func load(raw: String?) -> Language {
        guard let raw, !raw.isEmpty else { return .ko }
        return Language(rawValue: raw)
    }
}

// MARK: - CustomCombo (dotlab-cc)

/// 무도장 커스텀 콤보(동작 문자열 배열, 예: "punch:3", "round")
public struct CustomCombo: Codable, Sendable, Equatable {
    public static let storageKey = "dotlab-cc"
    /// 42-dojo.js CC_MAX(웹 대조 기준)
    public static let maxSteps = 8
    /// 네이티브 무도장 최대 단수(BBSim NativeContent.dojoCCMax 와 같은 값). 키 · 모양은 그대로라 8단 이하 저장본도 그대로 읽힌다
    public static let nativeMaxSteps = 16
    public static let defaultSteps = ["punch:3", "punch:0", "punch:1", "punch:2", "round"]

    /// 배열 원소는 웹이 무엇이든 받아 주므로 JSONValue 로 보존한다(보통 문자열)
    public var items: [JSONValue]

    public var steps: [String] {
        get { items.compactMap(\.stringValue) }
        set { items = newValue.map(JSONValue.string) }
    }

    public init(steps: [String] = CustomCombo.defaultSteps) { items = steps.map(JSONValue.string) }

    public init(from decoder: Decoder) throws { items = try decoder.singleValueContainer().decode([JSONValue].self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(items) }

    /// 웹 ccLoad: 배열이면 앞 limit 개(기본 = 웹 8개), 아니면 기본
    public static func load(webJSON raw: String?, limit: Int = maxSteps) -> CustomCombo {
        guard let raw, let data = raw.data(using: .utf8),
              let arr = (try? JSONDecoder().decode(JSONValue.self, from: data))?.arrayValue else { return CustomCombo() }
        var c = CustomCombo(); c.items = Array(arr.prefix(max(0, limit))); return c
    }
}
