// SaveStore — 봉투 v1(웹 셸) 읽기 · v2 쓰기 · 원자적 쓰기 · 미뤄 쓰기 · 개발 키 보존
import Foundation
import Testing
@testable import BBPersistence

/// 테스트마다 새 임시 폴더
struct TempDir: ~Copyable {
    let url: URL
    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "bbpersist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    var saveFile: URL { url.appending(path: "BagBoss/save.json") }
    func files(in sub: String = "BagBoss") -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.appending(path: sub).path)) ?? []
    }
    deinit { try? FileManager.default.removeItem(at: url) }
}

/// 웹 셸(ios/BagBoss/Bridge/SaveStore.swift)이 쓰는 모양 그대로
func webShellEnvelope(_ keys: [String: String]) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["v": 1, "updatedAt": "2026-10-01T12:34:56Z", "keys": keys] as [String: Any],
                               options: [.sortedKeys])
}

@Suite struct SaveStoreTests {
    @Test func 웹_셸_v1_파일을_읽고_v2로_다시_쓴다() throws {
        let tmp = try TempDir()
        let meta = try Fx.value("meta-played.json").jsonString()
        let run = try Fx.value("run.json").jsonString()
        let dev = #"{"nodes":[1,2,3]}"#
        try FileManager.default.createDirectory(at: tmp.saveFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try webShellEnvelope([
            "dotlab-subway-meta-v1": meta, "dotlab-run-v1": run, "dotlab-lang": "en",
            "dotlab-opt": #"{"skin":"navy"}"#, "dotlab-snd": #"{"vol":{"master":0.3},"muted":false}"#,
            "dotlab.graph.v4": dev, "dotlab.poses.v2": "[]", "dotlab-poseEdits": "{}",
        ]).write(to: tmp.saveFile)

        let store = SaveStore(fileURL: tmp.saveFile, debounce: 60)
        #expect(store.sourceVersion == 1)
        #expect(store.lastUpdatedAt == ISO8601DateFormatter().date(from: "2026-10-01T12:34:56Z"))
        #expect(store.meta().runs == 7)
        #expect(store.runSave()?.ci == 2)
        #expect(store.language() == .en)
        #expect(store.options().skin == "navy")
        #expect(store.sound().vol.master == 0.3)
        #expect(store.customCombo() == CustomCombo())   // 없는 키 → 기본
        // 16단 저장 → 네이티브 한도로 그대로 · 웹 한도로 앞 8개(같은 키 'dotlab-cc')
        let c16 = (0..<16).map { $0 % 2 == 0 ? "punch:\($0 % 4)" : "kick" }
        store.setCustomCombo(CustomCombo(steps: c16))
        #expect(store.customCombo(limit: CustomCombo.nativeMaxSteps).steps == c16)
        #expect(store.customCombo().steps == Array(c16.prefix(8)))
        store.setString(#"["punch:3","punch:0","round"]"#, forKey: CustomCombo.storageKey)   // 예전 저장본
        #expect(store.customCombo(limit: CustomCombo.nativeMaxSteps).steps == ["punch:3", "punch:0", "round"])
        store.setString(nil, forKey: CustomCombo.storageKey)

        var m = store.meta(); m.runs += 1
        store.setMeta(m)
        #expect(store.hasPendingChanges)
        #expect(store.flush())
        #expect(!store.hasPendingChanges)

        let env = try SaveStore.decodeEnvelope(Data(contentsOf: tmp.saveFile))
        #expect(env.v == 2)
        #expect(env.updatedAt != nil)
        // 개발 키는 바이트까지 그대로
        #expect(env.keys["dotlab.graph.v4"] == dev)
        #expect(env.keys["dotlab.poses.v2"] == "[]")
        #expect(env.keys["dotlab-poseEdits"] == "{}")
        #expect(env.keys["dotlab-run-v1"] == run)
        // 메타는 runs 만 바뀌고 나머지(모르는 필드 포함)는 그대로
        var expected = try Fx.value("meta-played.json").objectValue!
        expected["runs"] = 8
        #expect(try JSONValue(jsonString: env.keys["dotlab-subway-meta-v1"]!) == .object(expected))

        // 다시 열면 v2 로 읽힌다
        let again = SaveStore(fileURL: tmp.saveFile)
        #expect(again.sourceVersion == 2)
        #expect(again.meta().runs == 8)
        #expect(again.snapshot() == env.keys)
    }

    @Test func 웹_셸이_v2_파일도_읽을_수_있는_모양() throws {
        // 셸은 obj["keys"] as? [String: String] 으로 읽는다 → keys 값은 모두 문자열이어야 한다
        let tmp = try TempDir()
        let store = SaveStore(fileURL: tmp.saveFile)
        store.setLanguage(.ko)
        store.setOptions(Options())
        store.flush()
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: tmp.saveFile)) as? [String: Any]
        #expect(obj?["keys"] as? [String: String] != nil)
        #expect((obj?["keys"] as? [String: String])?["dotlab-lang"] == "ko")   // 언어는 따옴표 없는 날 문자열
    }

    @Test func 원자적_쓰기는_임시_파일을_남기지_않는다() throws {
        let tmp = try TempDir()
        let url = tmp.url.appending(path: "a/b/save.json")
        try SaveStore.atomicWrite(Data("one".utf8), to: url)
        try SaveStore.atomicWrite(Data("two".utf8), to: url)   // 있는 파일 바꿔치기
        #expect(try String(contentsOf: url, encoding: .utf8) == "two")
        #expect(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path) == ["save.json"])
    }

    @Test func 판_저장_지우기와_변경없는_flush() throws {
        let tmp = try TempDir()
        let store = SaveStore(fileURL: tmp.saveFile, debounce: 60)
        #expect(store.flush())                                   // 바뀐 게 없으면 파일도 안 만든다
        #expect(!FileManager.default.fileExists(atPath: tmp.saveFile.path))
        var r = RunSave(); r.bag = [SavedItem(id: "punch", uid: 4)]
        store.setRunSave(r)
        store.flush()
        #expect(SaveStore(fileURL: tmp.saveFile).runSave()?.nextUid == 5)
        store.clearRunSave()
        store.flush()
        #expect(SaveStore(fileURL: tmp.saveFile).runSave() == nil)
        #expect(SaveStore(fileURL: tmp.saveFile).string(forKey: RunSave.storageKey) == nil)
        #expect(tmp.files() == ["save.json"])
    }

    @Test func 미뤄_쓰기는_debounce_뒤_한_번() async throws {
        let tmp = try TempDir()
        let store = SaveStore(fileURL: tmp.saveFile, debounce: 0.05)
        store.setString("1", forKey: "dotlab-x")
        store.setString("2", forKey: "dotlab-x")
        #expect(!FileManager.default.fileExists(atPath: tmp.saveFile.path))
        var waited = 0.0
        while store.hasPendingChanges && waited < 3 { try await Task.sleep(for: .milliseconds(20)); waited += 0.02 }
        #expect(!store.hasPendingChanges)
        #expect(SaveStore(fileURL: tmp.saveFile).string(forKey: "dotlab-x") == "2")
    }

    @Test func 깨진_파일은_옆으로_치우고_빈_상태로() throws {
        let tmp = try TempDir()
        try FileManager.default.createDirectory(at: tmp.saveFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{깨짐".utf8).write(to: tmp.saveFile)
        let store = SaveStore(fileURL: tmp.saveFile)
        #expect(store.snapshot().isEmpty)
        #expect(store.meta() == MetaState())
        #expect(tmp.files().contains { $0.hasPrefix("save.json.corrupt-") })
    }

    @Test func 봉투_keys_의_문자열이_아닌_값은_없는_키() throws {
        let data = Data(#"{"v":1,"keys":{"a":"x","b":null,"c":3}}"#.utf8)
        let env = try SaveStore.decodeEnvelope(data)
        #expect(env.keys == ["a": "x"])
        #expect(env.updatedAt == nil)
    }
}
