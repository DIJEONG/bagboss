import XCTest
import Foundation
@testable import BBAnim

// 웹 noirModel · suitModel · defFor(LOOK_CACHE) · PASS_MODEL · skinModel 결과 ↔ BBAnim/Models (tools/js/extract/models.mjs)
final class ModelParityTests: XCTestCase {
    struct Input: Decodable {
        // noir
        var suit: Bool?, coat: JSONScalar?, trou: Double?, cap: Bool?, hatMat: Double?, hair: String?, fat: Bool?, tie: String?
        var noTie: Bool?, mandarin: Bool?, bandMat: Double?
        // look
        var key: String?, boss: Bool?
        // pass · skin
        var i: Int?, k: String?
    }
    /// coat 는 noir 에서 재질 번호, look 에서 재질 이름
    enum JSONScalar: Decodable {
        case num(Double), str(String)
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let v = try? c.decode(Double.self) { self = .num(v) } else { self = .str(try c.decode(String.self)) }
        }
        var num: Double? { if case .num(let v) = self { v } else { nil } }
        var str: String? { if case .str(let v) = self { v } else { nil } }
    }
    struct Case: Decodable { let id: String, kind: String, input: Input, model: Model3 }
    struct Fixture: Decodable { let cases: [Case]; let M: [String: Double] }

    static let fixture: Fixture = {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/models.json.deflate")
        let d = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(Fixture.self, from: (d as NSData).decompressed(using: .zlib) as Data)
    }()

    func build(_ c: Case) -> Model3 {
        let I = c.input
        switch c.kind {
        case "look":
            let L = LookSpec(key: I.key!)!
            XCTAssertEqual(L.hair, I.hair, c.id); XCTAssertEqual(L.fat, I.fat ?? false, c.id); XCTAssertEqual(L.coat, I.coat?.str, c.id)
            XCTAssertEqual(L.boss, I.boss ?? false, c.id); XCTAssertEqual(L.tie, I.tie, c.id); XCTAssertEqual(L.mandarin, I.mandarin ?? false, c.id)
            return CharacterModels.look(L)
        case "noir":
            let o = NoirOptions(suit: I.suit ?? false, coat: I.coat?.num, trou: I.trou, cap: I.cap ?? false, hatMat: I.hatMat, hair: I.hair,
                                fat: I.fat ?? false, tie: I.tie, noTie: I.noTie ?? false, mandarin: I.mandarin ?? false, bandMat: I.bandMat)
            if let base = CharacterModels.base(c.id) { XCTAssertTrue(diff(base, noirModel(o)).isEmpty, "\(c.id) 기본 정의") }
            return noirModel(o)
        case "pass": return CharacterModels.passenger(I.i!)
        case "skin": return CharacterModels.skin(I.k!)
        default: XCTFail("모르는 종류 \(c.kind)"); return [:]
        }
    }

    /// 다른 곳 목록(빈 배열이면 같음) — 1e-9 이내
    /// 네이티브에서 새로 만든 조각(웹 대조 제외 — 2026-10-14 네이티브 완전 전환): 서류가방(크게 · 걸쇠 · 손잡이 — NoirModels briefcase)
    static let nativeOnly: Set<String> = ["case"]

    func diff(_ a: Model3, _ b: Model3) -> [String] {
        var out: [String] = []
        if Set(a.keys) != Set(b.keys) { out.append("뼈 \(a.keys.sorted()) ≠ \(b.keys.sorted())") }
        for (k, pa) in a where !Self.nativeOnly.contains(k) { guard let pb = b[k] else { continue }
            if pa.count != pb.count { out.append("\(k) 조각 수 \(pa.count) ≠ \(pb.count)"); continue }
            for (i, (x, y)) in zip(pa, pb).enumerated() {
                func near(_ u: Double, _ v: Double) -> Bool { abs(u - v) <= 1e-9 }
                if !near(x.mat, y.mat) || !near(x.tone, y.tone) || !near(x.part, y.part) { out.append("\(k)[\(i)] 재질/톤/부위 \(x.mat),\(x.tone),\(x.part) ≠ \(y.mat),\(y.tone),\(y.part)") }
                if (0..<3).contains(where: { !near(x.c[$0], y.c[$0]) }) { out.append("\(k)[\(i)] 중심 \(x.c) ≠ \(y.c)") }
                if x.q.count != y.q.count { out.append("\(k)[\(i)] 면 수"); continue }
                for (qa, qb) in zip(x.q, y.q) where qa.count != qb.count || zip(qa, qb).contains(where: { p, r in (0..<3).contains { !near(p[$0], r[$0]) } }) {
                    out.append("\(k)[\(i)] 꼭짓점 \(qa) ≠ \(qb)"); break
                }
            }
        }
        return out
    }

    func testMaterialsMatchWeb() {
        for (k, v) in Self.fixture.M { XCTAssertEqual(Mat.byName[k], v, k) }
        XCTAssertEqual(Mat.byName.count, Self.fixture.M.count)
    }

    func testAllModelsMatchWeb() {
        let F = Self.fixture
        XCTAssertGreaterThan(F.cases.count, 80)
        var bad = 0, prisms = 0
        for c in F.cases {
            let m = build(c)
            prisms += c.model.values.reduce(0) { $0 + $1.count }
            let d = diff(c.model, m)
            if !d.isEmpty { bad += 1; XCTFail("\(c.id): \(d.prefix(4).joined(separator: " / "))") }
        }
        print("[ModelParity] \(F.cases.count)건 · 조각 \(prisms)개 · 어긋남 \(bad)건")
    }

    func testCacheAndKeys() {
        var cache = CharacterModelCache()
        XCTAssertNil(cache.look(key: "pomp|true"))
        XCTAssertNotNil(cache.look(key: "undefined||COAT|||"))
        XCTAssertEqual(cache.passenger(4)["head"], CharacterModels.passenger(1)["head"])
        XCTAssertEqual(cache.skin("없음")["head"], CharacterModels.skin("jw")["head"])
    }
}
