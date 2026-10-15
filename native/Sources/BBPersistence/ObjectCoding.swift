// 여분 버킷이 있는 JSON 객체 읽기 · 쓰기 도우미.
//
// 규칙(모든 모델 공통):
// - 아는 키는 타입으로 읽는다. 키가 없으면 기본값(웹의 `{...기본값, ...저장값}` 과 같음).
// - 모르는 키는 `extras` 에 원래 값 그대로 담아 두었다가 쓸 때 다시 쓴다(웹 다음 버전 필드 보존).
// - 아는 키인데 값이 null 이거나 타입이 맞지 않으면: 타입 필드는 nil(또는 기본값)이 되고 원래 값은 `extras` 에 남는다.
//   쓸 때 타입 필드가 nil 이면 `extras` 의 원래 값을 대신 쓴다 → `pin: null` 같은 명시적 null 도 그대로 돌아간다.
//   타입 필드에 값이 있으면 그 값이 이긴다(네이티브가 바꾼 값이 우선).
import Foundation

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { stringValue = String(intValue) }
}

struct ObjectReader {
    private let c: KeyedDecodingContainer<AnyKey>
    private var consumed: Set<String> = []
    private var failed: [String: JSONValue] = [:]

    init(_ decoder: Decoder) throws {
        c = try decoder.container(keyedBy: AnyKey.self)
    }

    /// 키가 있으면 타입으로 읽는다. 실패(null · 타입 불일치)하면 원래 값을 여분으로 남기고 nil.
    mutating func read<T: Decodable>(_ key: String, as _: T.Type = T.self) -> T? {
        let k = AnyKey(key)
        consumed.insert(key)
        guard c.contains(k) else { return nil }
        if let v = try? c.decode(T.self, forKey: k) { return v }
        if let raw = try? c.decode(JSONValue.self, forKey: k) { failed[key] = raw }
        return nil
    }

    /// 읽지 않은 키 전부 + 읽다 실패한 키 → 여분 버킷
    func extras() -> [String: JSONValue] {
        var out = failed
        for k in c.allKeys where !consumed.contains(k.stringValue) {
            if let v = try? c.decode(JSONValue.self, forKey: k) { out[k.stringValue] = v }
        }
        return out
    }
}

struct ObjectWriter {
    private var c: KeyedEncodingContainer<AnyKey>
    private let extras: [String: JSONValue]
    private var written: Set<String> = []

    init(_ encoder: Encoder, extras: [String: JSONValue]) {
        c = encoder.container(keyedBy: AnyKey.self)
        self.extras = extras
    }

    /// 값이 있으면 쓰고, nil 이면 여분 버킷의 원래 값(있으면)을 쓴다. `nullIfAbsent` 면 둘 다 없을 때 null.
    mutating func write<T: Encodable>(_ key: String, _ value: T?, nullIfAbsent: Bool = false) throws {
        written.insert(key)
        let k = AnyKey(key)
        if let value { try c.encode(value, forKey: k) }
        else if let raw = extras[key] { try c.encode(raw, forKey: k) }
        else if nullIfAbsent { try c.encodeNil(forKey: k) }
    }

    /// 남은 여분 키를 쓴다(아는 키로 이미 쓴 것은 건너뜀)
    mutating func finish() throws {
        for key in extras.keys.sorted() where !written.contains(key) {
            try c.encode(extras[key]!, forKey: AnyKey(key))
        }
    }
}
