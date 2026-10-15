// 저장 모델 대조 — 픽스처는 tools/js/extract/saves.mjs 가 웹 게임을 실제로 돌려 만든다(native/Tests/Fixtures/saves).
import Foundation
import Testing
@testable import BBPersistence

enum Fx {
    static let dir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/saves")
    static func data(_ name: String) throws -> Data { try Data(contentsOf: dir.appending(path: name)) }
    static func value(_ name: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data(name)) }
    /// 픽스처 안 한 부분을 JSON 문자열로(localStorage 에 들어 있던 모양)
    static func string(_ v: JSONValue?) throws -> String? { try v.map { try $0.jsonString() } }
}

/// 모델 → JSON 값(파싱된 JSON 끼리 비교)
func encoded<T: Encodable>(_ v: T) throws -> JSONValue { try JSONValue(encoding: v) }
func decoded<T: Decodable>(_ t: T.Type, _ v: JSONValue) throws -> T { try JSONDecoder().decode(T.self, from: Data(v.jsonString().utf8)) }

@Suite struct JSONValueTests {
    @Test func 숫자와_불리언을_섞지_않는다() throws {
        let v = try JSONValue(jsonString: #"{"a":1,"b":true,"c":0,"d":false,"e":0.5500000000000002,"f":1791539784309,"g":null,"h":"x/y"}"#)
        #expect(v["a"] == .number(1))
        #expect(v["b"] == .bool(true))
        #expect(v["c"] == .number(0))
        #expect(v["d"] == .bool(false))
        #expect(v["e"] == .number(0.5500000000000002))
        #expect(v["g"] == .null)
        let s = try v.jsonString(sortedKeys: true)
        #expect(s == #"{"a":1,"b":true,"c":0,"d":false,"e":0.5500000000000002,"f":1791539784309,"g":null,"h":"x/y"}"#)
    }

    @Test func 참거짓은_JS_와_같다() {
        #expect(!JSONValue.number(0).truthy)
        #expect(JSONValue.number(1).truthy)
        #expect(!JSONValue.string("").truthy)
        #expect(JSONValue.object([:]).truthy)
        #expect(!JSONValue.null.truthy)
    }
}

@Suite struct MetaStateTests {
    @Test func 기본값이_웹과_같다() throws {
        #expect(try encoded(MetaState()) == Fx.value("meta-default.json"))
        #expect(MetaState.load(webJSON: nil) == MetaState())
        #expect(MetaState.load(webJSON: "깨짐{") == MetaState())
        // 정수 값 Double(best.score 등)도 JSON.stringify 처럼 "0" 으로(“0.0” 아님)
        let s = try SaveStore.webJSONString(MetaState())
        #expect(s.contains(#""best":{"score":0,"stage":0}"#), "\(s)")
        #expect(s.range(of: #"[0-9]\.0[,}\]]"#, options: .regularExpression) == nil, "\(s)")
        // 키 순서가 정해져 있어야 같은 상태 → 같은 바이트(iCloud 비교 · diff 용)
        #expect(try SaveStore.webJSONString(Fx.value("meta-played.json")) == SaveStore.webJSONString(decoded(MetaState.self, Fx.value("meta-played.json"))))
    }

    @Test func 진행한_META_왕복이_손실없다() throws {
        let fx = try Fx.value("meta-played.json")
        let m = try decoded(MetaState.self, fx)
        #expect(try encoded(m) == fx)
        // 타입 필드로 잘 읽혔는지
        #expect(m.runs == 7)
        #expect(m.best.score == 12345 && m.best.stage == 2)
        #expect(m.tot.kills == 321 && m.tot["merges"] == 3)
        #expect(m.foes["thug"] == MetaState.FoeRecord(seen: 1, ko: 1))
        #expect(m.lines == ["0": 1, "1": 1, "2": 1])
        #expect(m.tower?.lv?["1"]?.f == 3)
        #expect(m.tower?.daily?["2026-10-08"]?.t == 120)
        #expect(m.combos?["punch>kick"]?.ids == ["punch", "kick"])
        #expect(m.bonusBest == 880)
        // 모르는 필드는 여분 버킷에
        #expect(m.extras["futureField"] == ["nested": [1, "two", nil, true, 2.5]])
        // 웹 불러오기 경로도 같은 값
        #expect(MetaState.load(webJSON: try fx.jsonString()) == m)
    }

    @Test func 옛_저장은_얕게_병합하고_best_tot_만_한단계_더() throws {
        let fx = try Fx.value("meta-merge.json")
        let m = MetaState.load(webJSON: try Fx.string(fx["saved"]))
        #expect(try encoded(m) == fx["loaded"])
        #expect(m.tot["legacyStat"] == 2)
    }

    @Test func v가_1이_아니면_기본값() throws {
        #expect(MetaState.load(webJSON: #"{"v":2,"runs":9}"#) == MetaState())
        #expect(MetaState.load(webJSON: #"{"v":"1","runs":9}"#) == MetaState())
        #expect(MetaState.load(webJSON: #"{"runs":9}"#) == MetaState())
        #expect(MetaState.load(webJSON: #"{"v":1,"runs":9}"#).runs == 9)
    }

    @Test func 선택_필드는_없으면_키도_없다() throws {
        var m = MetaState()
        #expect(try encoded(m)["tower"] == nil)
        m.tower = .init()
        #expect(try encoded(m)["tower"] == ["best": 0, "bestT": 0, "runs": 0])
    }
}

@Suite struct RunSaveTests {
    @Test func 게임이_쓴_판_저장_왕복이_손실없다() throws {
        let fx = try Fx.value("run.json")
        let r = try #require(RunSave.load(webJSON: try fx.jsonString()))
        #expect(try encoded(r) == fx)
        #expect(r.cfg == .init(kit: "basic", stage: 0, daily: false))
        #expect(r.ci == 2 && r.tokens == 17 && r.score == 2345)
        #expect(r.bag.first?.pin != nil)
        #expect(r.stash.first?.opt == .init(k: "crit", v: 0.15))
        #expect(r.stash.first?.extras["isNew"] == true)
        #expect(r.imprints.count == 3)
    }

    @Test func v가_1이_아니면_버린다() throws {
        let fx = try Fx.value("run-rejected.json")
        #expect(fx["loaded"] == .null)   // 웹 loadRunSave 결과
        #expect(RunSave.load(webJSON: try Fx.string(fx["saved"])) == nil)
        #expect(RunSave.load(webJSON: nil) == nil)
        #expect(RunSave.load(webJSON: "null") == nil)
    }

    @Test func 다음_uid는_아이템과_pin_참조의_최댓값_더하기_1() throws {
        var r = try #require(RunSave.load(webJSON: try Fx.value("run.json").jsonString()))
        let maxUid = (r.bag + r.stash).map(\.uid).max()!
        #expect(r.nextUid == maxUid + 1)
        // pin 이 (지금은 없는) 더 큰 uid 를 가리키면 그것도 피한다
        r.bag[0].pin = 42
        #expect(r.nextUid == 43)
        #expect(RunSave().nextUid == 1)
    }

    @Test func 명시적_null_과_모르는_필드를_보존한다() throws {
        let raw = #"{"v":1,"at":1,"cfg":{"kit":"basic","stage":0,"daily":false,"seed":7},"stageIdx":0,"ci":0,"bag":[{"id":"punch","tier":1,"uid":3,"t":0,"rot":0,"opt":null,"x":0,"y":0,"pin":null,"glow":[1,2]}],"stash":[],"tokens":0,"score":0,"hp":10.5,"sp":0,"kills":0,"stats":{"dealt":1.25},"bonusDone":false,"bonusSt":{"1":true},"imprints":{},"future":{"a":1}}"#
        let src = try JSONValue(jsonString: raw)
        let r = try #require(RunSave.load(webJSON: raw))
        #expect(try encoded(r) == src)
        #expect(r.bag[0].pin == nil)
        #expect(r.cfg.extras["seed"] == 7)
        // 네이티브가 pin 을 걸면 그 값이 이긴다
        var r2 = r; r2.bag[0].pin = 9
        #expect(try encoded(r2)["bag"]?.arrayValue?.first?["pin"] == 9)
    }
}

@Suite struct OptionTests {
    @Test func 옵션_기본값과_병합() throws {
        let fx = try Fx.value("opt.json")
        #expect(try encoded(Options()) == fx["default"])
        #expect(try encoded(Options.load(webJSON: nil)) == fx["default"])
        let o = Options.load(webJSON: try Fx.string(fx["saved"]))
        #expect(try encoded(o) == fx["loaded"])
        #expect(o.skin == "navy" && o.vibe == false && o.shortCut == false)
        #expect(o.extras["devFoo"] == 3)
        #expect(Options.load(webJSON: "null") == Options())
    }

    @Test func 소리_기본값과_Object_assign() throws {
        let fx = try Fx.value("snd.json")
        #expect(try encoded(SoundOptions()) == fx["default"])
        let s = SoundOptions.load(webJSON: try Fx.string(fx["saved"]))
        #expect(try encoded(s) == fx["loaded"])   // muted:1 → true, vol 의 다른 키(voice)도 붙는다
        #expect(s.vol.master == 0.8 && s.vol.music == 0.2 && s.muted)
        #expect(SoundOptions.load(webJSON: "0") == SoundOptions())
    }

    @Test func 언어는_날_문자열() throws {
        let fx = try Fx.value("lang.json")
        #expect(Language.load(raw: nil).rawValue == fx["default"]?.stringValue)
        #expect(Language.load(raw: "") == .ko)
        #expect(Language.load(raw: fx["raw"]?.stringValue) == .en)
    }

    @Test func 커스텀_콤보는_앞_8개() throws {
        let fx = try Fx.value("cc.json")
        #expect(fx["max"] == .number(Double(CustomCombo.maxSteps)))
        #expect(try encoded(CustomCombo()) == fx["default"])
        #expect(try encoded(CustomCombo.load(webJSON: try Fx.string(fx["saved"]))) == fx["loaded"])
        #expect(CustomCombo.load(webJSON: #"{"a":1}"#) == CustomCombo())
    }

    @Test func 커스텀_콤보_네이티브_16단() throws {
        let fx = try Fx.value("cc.json")
        // 예전(8단 이하) 저장본은 네이티브 한도로 읽어도 그대로
        let old8 = #"["punch:0","kick:1","round","punch:0","punch:1","punch:2","punch:3","kick:0"]"#
        let c8 = CustomCombo.load(webJSON: old8, limit: CustomCombo.nativeMaxSteps)
        #expect(c8.steps.count == 8 && c8.steps.first == "punch:0" && c8.steps.last == "kick:0")
        #expect(CustomCombo.load(webJSON: #"["round"]"#, limit: CustomCombo.nativeMaxSteps).steps == ["round"])
        // 웹 픽스처(10개)는 네이티브 한도에선 다 남는다 · 웹 한도에선 앞 8개
        #expect(CustomCombo.load(webJSON: try Fx.string(fx["saved"]), limit: CustomCombo.nativeMaxSteps).items == fx["saved"]?.arrayValue)
        // 16단 저장 → 같은 키 · 같은 모양(문자열 배열)으로 다시 읽힌다 · 17번째부터는 잘린다
        let long = (0..<20).map { "punch:\($0 % 4)" }
        let enc = try encoded(CustomCombo(steps: Array(long.prefix(16))))
        let raw = try enc.jsonString()
        #expect(CustomCombo.load(webJSON: raw, limit: CustomCombo.nativeMaxSteps).steps == Array(long.prefix(16)))
        let raw20 = String(data: try JSONEncoder().encode(long), encoding: .utf8)!
        #expect(CustomCombo.load(webJSON: raw20, limit: CustomCombo.nativeMaxSteps).steps.count == CustomCombo.nativeMaxSteps)
        #expect(CustomCombo.load(webJSON: raw20).steps.count == CustomCombo.maxSteps)   // 웹은 앞 8개
    }
}
