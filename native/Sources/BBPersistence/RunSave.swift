// RunSave — 판 이어 하기(localStorage `dotlab-run-v1`). 웹 41-hints-save.js saveRun()/loadRunSave() 와 같은 키 · 모양.
//
//   { v:1, at, cfg:{kit,stage,daily}, stageIdx, ci, bag:[Item], stash:[Item], tokens, score, hp, sp, kills,
//     stats, bonusDone, bonusSt, imprints }
//   Item: { id, tier, uid, t, rot, opt:null|{k,v}, x,y | sx,sy, pin?, combo?, last?, isNew? … }
//
// 웹 불러오기: v === 1 이 아니면 버린다(null). resumeRun 은 빠진 값을 `S.x || 기본` 으로 채운다.
// 웹 버그(네이티브에서 고침): GS.uid(아이템 · 배우 공용 일련번호)를 저장하지 않아 이어 하기 뒤 새 아이템 uid 가
// 기존 아이템과 겹칠 수 있다 → 불러온 뒤 `nextUid`(= 모든 아이템 uid · pin 참조의 최댓값 + 1)부터 쓴다.
import Foundation

public struct RunSave: Codable, Sendable, Equatable {
    public static let storageKey = "dotlab-run-v1"
    public static let version = 1

    public var v: Int = RunSave.version
    /// 저장 시각(Date.now() 밀리초)
    public var at: Double = 0
    public var cfg = RunConfig()
    public var stageIdx: Int = 0
    /// 호차 번호(0부터)
    public var ci: Int = 0
    public var bag: [SavedItem] = []
    public var stash: [SavedItem] = []
    public var tokens: Int = 0
    public var score: Double = 0
    public var hp: Double = 0
    public var sp: Double = 0
    public var kills: Int = 0
    /// 판 통계 {dealt, taken, crits, counters, outs …} — 불러올 때 웹은 기본 통계 위에 덮어쓴다
    public var stats: [String: Double] = [:]
    public var bonusDone: Bool = false
    /// 보너스 판 진행 { "1": true … }
    public var bonusSt: [String: JSONValue] = [:]
    /// 가방 칸 각인 ["x,y": "holster" | "pocket" | "worn"]
    public var imprints: [String: String] = [:]
    public var extras: [String: JSONValue] = [:]

    public init() {}

    public struct RunConfig: Codable, Sendable, Equatable {
        public var kit: String = "basic"
        public var stage: Int = 0
        public var daily: Bool = false
        public var extras: [String: JSONValue] = [:]
        public init(kit: String = "basic", stage: Int = 0, daily: Bool = false) {
            self.kit = kit; self.stage = stage; self.daily = daily
        }
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            kit = r.read("kit") ?? "basic"; stage = r.read("stage") ?? 0; daily = r.read("daily") ?? false
            extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("kit", kit); try w.write("stage", stage); try w.write("daily", daily); try w.finish()
        }
    }

    public init(from decoder: Decoder) throws {
        var r = try ObjectReader(decoder)
        v = r.read("v") ?? 0
        at = r.read("at") ?? 0
        cfg = r.read("cfg") ?? RunConfig()
        stageIdx = r.read("stageIdx") ?? 0
        ci = r.read("ci") ?? 0
        bag = r.read("bag") ?? []
        stash = r.read("stash") ?? []
        tokens = r.read("tokens") ?? 0
        score = r.read("score") ?? 0
        hp = r.read("hp") ?? 0
        sp = r.read("sp") ?? 0
        kills = r.read("kills") ?? 0
        stats = r.read("stats") ?? [:]
        bonusDone = r.read("bonusDone") ?? false
        bonusSt = r.read("bonusSt") ?? [:]
        imprints = r.read("imprints") ?? [:]
        extras = r.extras()
    }

    public func encode(to encoder: Encoder) throws {
        var w = ObjectWriter(encoder, extras: extras)
        try w.write("v", v); try w.write("at", at); try w.write("cfg", cfg); try w.write("stageIdx", stageIdx)
        try w.write("ci", ci); try w.write("bag", bag); try w.write("stash", stash); try w.write("tokens", tokens)
        try w.write("score", score); try w.write("hp", hp); try w.write("sp", sp); try w.write("kills", kills)
        try w.write("stats", stats); try w.write("bonusDone", bonusDone); try w.write("bonusSt", bonusSt)
        try w.write("imprints", imprints)
        try w.finish()
    }

    // MARK: uid 복원(웹 버그 수정)

    /// 이어 하기 뒤 새 아이템에 줄 다음 uid. 가방 · 보관함의 uid 와 pin 이 가리키는 uid 중 최댓값 + 1(없으면 1).
    /// 웹 newItem 은 `uid: ++GS.uid` 라서 '마지막으로 쓴 값 + 1' 이 다음 값이다.
    public var nextUid: Int {
        var m = 0
        for b in bag + stash {
            m = max(m, b.uid)
            if let p = b.pin { m = max(m, p) }
        }
        return m + 1
    }

    // MARK: 웹 불러오기 의미 그대로

    /// localStorage 문자열 → 판 저장. 없거나 · 깨졌거나 · v !== 1 이면 nil(웹 loadRunSave 와 같다).
    public static func load(webJSON raw: String?) -> RunSave? {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONDecoder().decode(JSONValue.self, from: data),
              obj["v"] == .number(1),
              let run = try? JSONDecoder().decode(RunSave.self, from: data) else { return nil }
        return run
    }
}

/// 가방 · 보관함 아이템 한 개(웹 newItem + 배치 좌표 + 실행 중 붙는 필드)
public struct SavedItem: Codable, Sendable, Equatable {
    public var id: String
    public var tier: Int = 1
    public var uid: Int
    /// 재사용 대기 누적 시간(초)
    public var t: Double = 0
    public var rot: Int = 0
    /// 부가 옵션. 웹은 없을 때도 `opt: null` 을 쓴다
    public var opt: ItemOption?
    /// 가방 좌표
    public var x: Int?
    public var y: Int?
    /// 보관함 좌표
    public var sx: Int?
    public var sy: Int?
    /// 콤보 경로 고정: 다음으로 이을 아이템의 uid(웹 33-bag-ui2 — 해제하면 null)
    public var pin: Int?
    /// 연타 단계(0~3)
    public var combo: Int?
    /// 마지막 발동 시각(GS.time 초)
    public var last: Double?
    /// 새로 얻음 표시 등 나머지 필드
    public var extras: [String: JSONValue] = [:]

    public init(id: String, tier: Int = 1, uid: Int, t: Double = 0, rot: Int = 0, opt: ItemOption? = nil) {
        self.id = id; self.tier = tier; self.uid = uid; self.t = t; self.rot = rot; self.opt = opt
    }

    public struct ItemOption: Codable, Sendable, Equatable {
        public var k: String
        public var v: Double
        public var extras: [String: JSONValue] = [:]
        public init(k: String, v: Double) { self.k = k; self.v = v }
        public init(from decoder: Decoder) throws {
            var r = try ObjectReader(decoder)
            guard let k: String = r.read("k") else {
                throw DecodingError.keyNotFound(AnyKey("k"), .init(codingPath: decoder.codingPath, debugDescription: "opt.k 없음"))
            }
            self.k = k; v = r.read("v") ?? 0; extras = r.extras()
        }
        public func encode(to encoder: Encoder) throws {
            var w = ObjectWriter(encoder, extras: extras)
            try w.write("k", k); try w.write("v", v); try w.finish()
        }
    }

    public init(from decoder: Decoder) throws {
        var r = try ObjectReader(decoder)
        guard let id: String = r.read("id"), let uid: Int = r.read("uid") else {
            throw DecodingError.keyNotFound(AnyKey("id/uid"), .init(codingPath: decoder.codingPath, debugDescription: "아이템 id · uid 없음"))
        }
        self.id = id; self.uid = uid
        tier = r.read("tier") ?? 1; t = r.read("t") ?? 0; rot = r.read("rot") ?? 0; opt = r.read("opt")
        x = r.read("x"); y = r.read("y"); sx = r.read("sx"); sy = r.read("sy")
        pin = r.read("pin"); combo = r.read("combo"); last = r.read("last")
        extras = r.extras()
    }

    public func encode(to encoder: Encoder) throws {
        var w = ObjectWriter(encoder, extras: extras)
        try w.write("id", id); try w.write("tier", tier); try w.write("uid", uid); try w.write("t", t)
        try w.write("rot", rot); try w.write("opt", opt, nullIfAbsent: true)
        try w.write("x", x); try w.write("y", y); try w.write("sx", sx); try w.write("sy", sy)
        try w.write("pin", pin); try w.write("combo", combo); try w.write("last", last)
        try w.finish()
    }
}
