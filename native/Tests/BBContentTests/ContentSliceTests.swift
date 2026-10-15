import Testing
import Foundation
@testable import BBContent

/// ContentStore 의 이름별 조각 읽기(SliceCache) · JSONValue 빠른 길이 예전 경로(파일 전체 Decodable)와 같은 값을 내는지
@Suite struct ContentSliceTests {
    /// 예전 경로: 파일 전체를 JSONValue(Decodable)로 읽고 이름으로 꺼낸다
    static func legacy(_ dir: URL, file: String) throws -> [String: JSONValue] {
        try JSONDecoder().decode([String: JSONValue].self, from: Data(contentsOf: dir.appending(path: file + ".json")))
    }

    @Test("모든 이름: 조각 + 빠른 JSONValue == 파일 전체 Decodable") func everyNameMatchesLegacy() throws {
        let dir = GeneratedResources.url.appending(path: "content")
        let store = try ContentStore(directory: dir)
        var byFile: [String: [String: JSONValue]] = [:]
        var n = 0
        for name in store.names {
            let f = store.entries[name]!.file
            if byFile[f] == nil { byFile[f] = try Self.legacy(dir, file: f) }
            let want = try #require(byFile[f]![name], "\(name)")
            #expect(try store.raw(name) == want, "\(name)")
            n += 1
        }
        #expect(n > 200)
    }

    @Test("최상위 나누기: 문자열 안 괄호 · 이스케이프 · 조각값") func splitter() throws {
        let src = #"{ "a" : {"x":"}{,\"]"}, "b":[1,[2,{"c":3}]] ,"c\"q":"s","d":-1.5e3, "e":true,"f":null }"#
        let m = try #require(SliceCache.topLevelValues(Data(src.utf8)))
        #expect(String(decoding: m["a"]!, as: UTF8.self) == #"{"x":"}{,\"]"}"#)
        #expect(String(decoding: m["b"]!, as: UTF8.self) == "[1,[2,{\"c\":3}]]")
        #expect(String(decoding: m["c\"q"]!, as: UTF8.self) == "\"s\"")
        #expect(try JSONDecoder().decode(Double.self, from: m["d"]!) == -1500)
        #expect(try JSONValue.parse(m["e"]!) == .bool(true))
        #expect(try JSONValue.parse(m["f"]!) == .null)
        #expect(m.count == 6)
    }
}
