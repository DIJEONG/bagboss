// MetaState — 메타 진행(localStorage `dotlab-subway-meta-v1`). 웹 36-meta-menu.js 의 META 와 같은 키 · 모양.
//
// 웹 불러오기(그대로 재현):
//   d = { v:1, runs:0, best:{score:0,stage:0}, tot:{kills…footSet:0}, foes:{}, stns:{}, items:{}, links:{},
//         kits:{basic:1}, lines:{0:1}, daily:{} }
//   s.v === 1 이면 { ...d, ...s, best:{...d.best,...s.best}, tot:{...d.tot,...s.tot} }, 아니면 d
// → 최상위는 얕은 병합, best · tot 만 한 단계 더 병합. 선택 필드(hints · tower …)는 게임이 처음 쓸 때 생긴다(그 전엔 키가 없음).
// docs/06 §6 스키마 참고.
import Foundation

public struct MetaState: Codable, Sendable, Equatable {
    public static let storageKey = "dotlab-subway-meta-v1"
    public static let version = 1

    public var v: Int = MetaState.version
    public var runs: Int = 0
    public var best = Best()
    public var tot = Totals()
    /// 적 도감 [etype: {seen, ko}]
    public var foes: [String: FoeRecord] = [:]
    /// 들른 역 [id: 1]
    public var stns: [String: Int] = [:]
    /// 얻은 아이템 최고 ★ [id: tier]
    public var items: [String: Int] = [:]
    /// 본 연계 [id: 1]
    public var links: [String: Int] = [:]
    /// 해금한 시작 가방 [id: 1]
    public var kits: [String: Int] = ["basic": 1]
    /// 열린 노선 [stageIdx(문자열): 1]
    public var lines: [String: Int] = ["0": 1]
    /// 오늘의 노선 점수 ["YYYY-MM-DD": 점수]
    public var daily: [String: Double] = [:]

    // 선택(나중에 생김) — nil 이면 저장 JSON 에 키가 없다(웹과 같게)
    public var hints: [String: Int]?
    public var talks: [String: Int]?
    public var flags: [String: JSONValue]?
    public var seenCut: [String: Int]?
    /// 필살기 사용 횟수 [kind: n]
    public var spc: [String: Int]?
    /// 콤보 도감 [id: {n, best}]
    public var cbook: [String: ComboBookEntry]?
    /// 목격한 콤보 [id: 1]
    public var cseen: [String: Int]?
    /// 자유 콤보 기록 [key: {name, ids, n, best}]
    public var combos: [String: ComboRecord]?
    /// 두목 명장면 [etype: n]
    public var bossScenes: [String: Int]?
    public var bonusBest: Double?
    public var tower: TowerRecord?

    /// 모르는 최상위 필드(웹 다음 버전) — 그대로 보존
    public var extras: [String: JSONValue] = [:]

    public init() {}

    // MARK: 하위 타입

    public struct Best: Codable, Sendable, Equatable {
        public var score: Double = 0
        public var stage: Int = 0
        public var extras: [String: JSONValue] = [:]
        public init() {}
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            score = r.read("score") ?? 0
            stage = r.read("stage") ?? 0
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("score", score); try w.write("stage", stage); try w.finish()
        }
    }

    /// 누적 통계. 기본 9개 키 + 웹이 나중에 더한 키는 extras(`tot` 도 한 단계 병합 대상)
    public struct Totals: Codable, Sendable, Equatable {
        public static let keys = ["kills", "crits", "dodges", "links", "throws", "outs", "onTime", "merges", "footSet"]
        public var kills = 0, crits = 0, dodges = 0, links = 0, `throws` = 0, outs = 0, onTime = 0, merges = 0, footSet = 0
        public var extras: [String: JSONValue] = [:]
        public init() {}

        /// 웹 `META.tot[k]` 처럼 이름으로(모르는 키는 extras 의 숫자)
        public subscript(key: String) -> Int {
            get {
                switch key {
                case "kills": kills; case "crits": crits; case "dodges": dodges; case "links": links
                case "throws": `throws`; case "outs": outs; case "onTime": onTime; case "merges": merges; case "footSet": footSet
                default: extras[key]?.intValue ?? 0
                }
            }
            set {
                switch key {
                case "kills": kills = newValue; case "crits": crits = newValue; case "dodges": dodges = newValue
                case "links": links = newValue; case "throws": `throws` = newValue; case "outs": outs = newValue
                case "onTime": onTime = newValue; case "merges": merges = newValue; case "footSet": footSet = newValue
                default: extras[key] = .number(Double(newValue))
                }
            }
        }

        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            kills = r.read("kills") ?? 0; crits = r.read("crits") ?? 0; dodges = r.read("dodges") ?? 0
            links = r.read("links") ?? 0; `throws` = r.read("throws") ?? 0; outs = r.read("outs") ?? 0
            onTime = r.read("onTime") ?? 0; merges = r.read("merges") ?? 0; footSet = r.read("footSet") ?? 0
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            for k in Self.keys { try w.write(k, self[k]) }
            try w.finish()
        }
    }

    public struct FoeRecord: Codable, Sendable, Equatable {
        public var seen = 0, ko = 0
        public var extras: [String: JSONValue] = [:]
        public init(seen: Int = 0, ko: Int = 0) { self.seen = seen; self.ko = ko }
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            seen = r.read("seen") ?? 0; ko = r.read("ko") ?? 0; extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("seen", seen); try w.write("ko", ko); try w.finish()
        }
    }

    public struct ComboBookEntry: Codable, Sendable, Equatable {
        public var n = 0, best = 0
        public var extras: [String: JSONValue] = [:]
        public init(n: Int = 0, best: Int = 0) { self.n = n; self.best = best }
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            n = r.read("n") ?? 0; best = r.read("best") ?? 0; extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("n", n); try w.write("best", best); try w.finish()
        }
    }

    public struct ComboRecord: Codable, Sendable, Equatable {
        public var name = ""
        public var ids: [String] = []
        public var n = 0, best = 0
        public var extras: [String: JSONValue] = [:]
        public init(name: String = "", ids: [String] = [], n: Int = 0, best: Int = 0) {
            self.name = name; self.ids = ids; self.n = n; self.best = best
        }
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            name = r.read("name") ?? ""; ids = r.read("ids") ?? []; n = r.read("n") ?? 0; best = r.read("best") ?? 0
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("name", name); try w.write("ids", ids); try w.write("n", n); try w.write("best", best)
            try w.finish()
        }
    }

    /// 엘리베이터 타워 기록. 웹은 처음 쓸 때 `{best:0, bestT:0, runs:0}` 으로 만들고 ot · lv · daily 는 나중에 붙인다.
    public struct TowerRecord: Codable, Sendable, Equatable {
        public var best: Int = 0
        public var bestT: Double = 0
        public var runs: Int = 0
        /// 마지막으로 연 야근 단계
        public var ot: Int?
        /// 야근 단계별 최고 [ot(문자열): {f, t}]
        public var lv: [String: FloorTime]?
        /// 날짜별 최고 [date: {f, t}]
        public var daily: [String: FloorTime]?
        public var extras: [String: JSONValue] = [:]
        public init() {}

        public struct FloorTime: Codable, Sendable, Equatable {
            public var f: Int = 0
            public var t: Double = 0
            public var extras: [String: JSONValue] = [:]
            public init(f: Int = 0, t: Double = 0) { self.f = f; self.t = t }
            public init(from decoder: Decoder) throws {
                var r = try ObjectReader(decoder)
                f = r.read("f") ?? 0; t = r.read("t") ?? 0; extras = r.extras()
            }
            public func encode(to encoder: Encoder) throws {
                var w = ObjectWriter(encoder, extras: extras)
                try w.write("f", f); try w.write("t", t); try w.finish()
            }
        }

        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            best = r.read("best") ?? 0; bestT = r.read("bestT") ?? 0; runs = r.read("runs") ?? 0
            ot = r.read("ot"); lv = r.read("lv"); daily = r.read("daily")
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("best", best); try w.write("bestT", bestT); try w.write("runs", runs)
            try w.write("ot", ot); try w.write("lv", lv); try w.write("daily", daily)
            try w.finish()
        }
    }

    // MARK: Codable — 키가 빠진 필드는 웹 기본값(얕은 병합). best · tot 는 각 타입이 키별 기본값을 채운다(한 단계 병합).

    public init(from decoder: Decoder) throws {
        var r = try ObjectReader(decoder)
        v = r.read("v") ?? MetaState.version
        runs = r.read("runs") ?? 0
        best = r.read("best") ?? Best()
        tot = r.read("tot") ?? Totals()
        foes = r.read("foes") ?? [:]
        stns = r.read("stns") ?? [:]
        items = r.read("items") ?? [:]
        links = r.read("links") ?? [:]
        kits = r.read("kits") ?? ["basic": 1]
        lines = r.read("lines") ?? ["0": 1]
        daily = r.read("daily") ?? [:]
        hints = r.read("hints"); talks = r.read("talks"); flags = r.read("flags"); seenCut = r.read("seenCut")
        spc = r.read("spc"); cbook = r.read("cbook"); cseen = r.read("cseen"); combos = r.read("combos")
        bossScenes = r.read("bossScenes"); bonusBest = r.read("bonusBest"); tower = r.read("tower")
        extras = r.extras()
    }

    public func encode(to encoder: Encoder) throws {
        var w = ObjectWriter(encoder, extras: extras)
        try w.write("v", v); try w.write("runs", runs); try w.write("best", best); try w.write("tot", tot)
        try w.write("foes", foes); try w.write("stns", stns); try w.write("items", items); try w.write("links", links)
        try w.write("kits", kits); try w.write("lines", lines); try w.write("daily", daily)
        try w.write("hints", hints); try w.write("talks", talks); try w.write("flags", flags); try w.write("seenCut", seenCut)
        try w.write("spc", spc); try w.write("cbook", cbook); try w.write("cseen", cseen); try w.write("combos", combos)
        try w.write("bossScenes", bossScenes); try w.write("bonusBest", bonusBest); try w.write("tower", tower)
        try w.finish()
    }

    // MARK: 웹 불러오기 의미 그대로

    /// localStorage 문자열 → META. 없거나 · 깨졌거나 · v !== 1 이면 기본값(웹 metaLoad 와 같다).
    public static func load(webJSON raw: String?) -> MetaState {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONDecoder().decode(JSONValue.self, from: data),
              obj["v"] == .number(1),
              let meta = try? JSONDecoder().decode(MetaState.self, from: data) else { return MetaState() }
        return meta
    }
}
