import Foundation

/// 모양이 정해지지 않은 데이터(추출 JSON의 임의 값). 타입 모델이 아직 없는 표를 읽거나, 섞인 배열을 다룰 때 쓴다.
/// 추출기 규칙(tools/js/extract/content.mjs): 함수 → {"$fn": 경로} · Set → {"$set": […]} · Map → {"$map": […]}
public enum JSONValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public subscript(key: String) -> JSONValue? { if case .object(let o) = self { o[key] } else { nil } }
    public subscript(index: Int) -> JSONValue? {
        if case .array(let a) = self, a.indices.contains(index) { a[index] } else { nil }
    }
    public var double: Double? { if case .number(let n) = self { n } else { nil } }
    public var int: Int? { double.map { Int($0) } }
    public var string: String? { if case .string(let s) = self { s } else { nil } }
    public var bool: Bool? { if case .bool(let b) = self { b } else { nil } }
    public var array: [JSONValue]? { if case .array(let a) = self { a } else { nil } }
    public var object: [String: JSONValue]? { if case .object(let o) = self { o } else { nil } }
    /// 추출기가 함수 자리에 남긴 표시({"$fn": 경로})면 그 경로 — lambdas.json 의 키.
    public var functionRef: String? { self["$fn"]?.string }
}

extension JSONValue {
    /// 빠른 길: 바이트를 직접 훑는 작은 파서. Decodable 경로(init(from:))는 값마다 try? 를 4번까지 던져 디버그 빌드에서 매우 느리다
    /// (HUDArt 준비 1.3초의 대부분). 숫자는 Double(String)(strtod — 올바른 반올림)로 읽어 JSONDecoder 와 같은 값이 된다.
    /// (JSONSerialization 은 쓰지 않는다 — 1.76 → 1.7599999999999998 처럼 마지막 자리가 어긋난다.) ContentSliceTests 가 모든 이름을 대조한다.
    public static func parse(_ data: Data) throws -> JSONValue {
        try data.withUnsafeBytes { raw in
            var p = FastJSON(raw)
            p.ws()
            let v = try p.value()
            p.ws()
            guard p.i == p.n else { throw ContentError.missingResource("JSON 끝 뒤에 남은 글자") }
            return v
        }
    }
}

private struct FastJSON {
    let b: UnsafeRawBufferPointer
    var i = 0
    let n: Int
    init(_ b: UnsafeRawBufferPointer) { self.b = b; n = b.count }
    static let bad = ContentError.missingResource("JSON 형식")

    mutating func ws() { while i < n, b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0x09 { i += 1 } }

    mutating func value() throws -> JSONValue {
        guard i < n else { throw Self.bad }
        switch b[i] {
        case 0x7B:   // {
            i += 1; var o: [String: JSONValue] = [:]
            ws(); if i < n, b[i] == 0x7D { i += 1; return .object(o) }
            while true {
                ws(); guard i < n, b[i] == 0x22 else { throw Self.bad }
                let k = try string()
                ws(); guard i < n, b[i] == 0x3A else { throw Self.bad }
                i += 1; ws()
                o[k] = try value()
                ws(); guard i < n else { throw Self.bad }
                if b[i] == 0x2C { i += 1; continue }
                if b[i] == 0x7D { i += 1; return .object(o) }
                throw Self.bad
            }
        case 0x5B:   // [
            i += 1; var a: [JSONValue] = []
            ws(); if i < n, b[i] == 0x5D { i += 1; return .array(a) }
            while true {
                ws(); a.append(try value()); ws()
                guard i < n else { throw Self.bad }
                if b[i] == 0x2C { i += 1; continue }
                if b[i] == 0x5D { i += 1; return .array(a) }
                throw Self.bad
            }
        case 0x22: return .string(try string())
        case 0x74: try lit("true"); return .bool(true)
        case 0x66: try lit("false"); return .bool(false)
        case 0x6E: try lit("null"); return .null
        default:
            let s = i
            while i < n, b[i] == 0x2D || b[i] == 0x2B || b[i] == 0x2E || b[i] == 0x65 || b[i] == 0x45 || (b[i] >= 0x30 && b[i] <= 0x39) { i += 1 }
            guard i > s, let d = Double(String(decoding: UnsafeRawBufferPointer(rebasing: b[s..<i]), as: UTF8.self)) else { throw Self.bad }
            return .number(d)
        }
    }

    mutating func lit(_ w: StaticString) throws {
        let c = w.utf8CodeUnitCount
        guard i + c <= n else { throw Self.bad }
        for k in 0..<c where b[i + k] != w.utf8Start[k] { throw Self.bad }
        i += c
    }

    mutating func hex4() throws -> UInt32 {
        guard i + 4 <= n else { throw Self.bad }
        var v: UInt32 = 0
        for _ in 0..<4 {
            let c = b[i]; i += 1
            let d: UInt8
            switch c {
            case 0x30...0x39: d = c - 0x30
            case 0x41...0x46: d = c - 0x41 + 10
            case 0x61...0x66: d = c - 0x61 + 10
            default: throw Self.bad
            }
            v = v << 4 | UInt32(d)
        }
        return v
    }

    /// 따옴표 위에서 시작
    mutating func string() throws -> String {
        i += 1
        let s = i
        while i < n, b[i] != 0x22, b[i] != 0x5C { i += 1 }
        guard i < n else { throw Self.bad }
        if b[i] == 0x22 { defer { i += 1 }; return String(decoding: UnsafeRawBufferPointer(rebasing: b[s..<i]), as: UTF8.self) }
        // 이스케이프가 있는 문자열
        var out = [UInt8](UnsafeRawBufferPointer(rebasing: b[s..<i]))
        while i < n {
            let c = b[i]
            if c == 0x22 { i += 1; return String(decoding: out, as: UTF8.self) }
            if c != 0x5C { out.append(c); i += 1; continue }
            i += 1; guard i < n else { throw Self.bad }
            let e = b[i]; i += 1
            switch e {
            case 0x22: out.append(0x22)
            case 0x5C: out.append(0x5C)
            case 0x2F: out.append(0x2F)
            case 0x62: out.append(0x08)
            case 0x66: out.append(0x0C)
            case 0x6E: out.append(0x0A)
            case 0x72: out.append(0x0D)
            case 0x74: out.append(0x09)
            case 0x75:
                var u = try hex4()
                if (0xD800..<0xDC00).contains(u), i + 6 <= n, b[i] == 0x5C, b[i + 1] == 0x75 {
                    let save = i; i += 2
                    let lo = try hex4()
                    if (0xDC00..<0xE000).contains(lo) { u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00) } else { i = save }
                }
                let sc = Unicode.Scalar(u) ?? "\u{FFFD}"
                out.append(contentsOf: Array(String(Character(sc)).utf8))
            default: throw Self.bad
            }
        }
        throw Self.bad
    }
}

/// 함수 자리 표시({"$fn": "LINKS[0].a"}). 원문은 `ContentStore.lambdaSource(_:)`.
public struct FunctionRef: Sendable, Equatable, Codable {
    public let path: String
    enum CodingKeys: String, CodingKey { case path = "$fn" }
}
