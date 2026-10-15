// JSONValue — 저장 JSON 의 '모르는 필드'를 그대로 들고 다니기 위한 작은 JSON 값 타입.
// BBContent 에 의존하지 않으려고 BBPersistence 안에 따로 둔다(docs/06 §2.9 '여분 버킷').
//
// 숫자는 JS 와 같이 Double 하나로 둔다(웹 저장값은 모두 JS 숫자 = IEEE 754 배정밀도라 손실이 없다).
// 정수로 떨어지는 값은 "5" 처럼 소수점 없이 쓴다(JSON.stringify 와 같은 모양).
import Foundation

public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - 편의 접근

public extension JSONValue {
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var doubleValue: Double? { if case .number(let n) = self { return n }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    var isNull: Bool { if case .null = self { return true }; return false }
    /// 정수로 정확히 떨어지는 숫자만
    var intValue: Int? {
        guard case .number(let n) = self, n.rounded() == n, abs(n) < 9.007_199_254_740_992e15 else { return nil }
        return Int(n)
    }
    /// JS 의 `!!v` 와 같은 참/거짓 판정
    var truthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return n != 0 && !n.isNaN
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }
    subscript(key: String) -> JSONValue? { objectValue?[key] }
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        // 순서 주의: Bool 을 숫자보다 먼저 본다(1 이 true 로 바뀌지 않는지는 테스트로 확인한다)
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "JSON 값이 아님")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n):
            // JSON.stringify 처럼 정수 값은 소수점 없이
            if n.rounded() == n, abs(n) < 9.007_199_254_740_992e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

// MARK: - 문자열 ↔ 값

public extension JSONValue {
    /// JSON 문자열을 읽는다(최상위 스칼라도 허용 — JSON.parse 와 같게)
    init(jsonString: String) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: Data(jsonString.utf8))
    }

    /// JSON.stringify 와 같은 압축 문자열
    func jsonString(sortedKeys: Bool = false) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = sortedKeys ? [.sortedKeys, .withoutEscapingSlashes] : [.withoutEscapingSlashes]
        return String(decoding: try enc.encode(self), as: UTF8.self)
    }

    /// Encodable 값을 JSONValue 로(비교 · 테스트용)
    init<T: Encodable>(encoding value: T) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

// MARK: - 리터럴

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, b in b }))
    }
}
