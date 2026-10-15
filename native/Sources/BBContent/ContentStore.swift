import Foundation

/// 추출된 게임 데이터(Generated/content/*.json) 읽기.
/// 이름은 웹 원본의 최상위 const 이름 그대로다(GITEMS · ETYPES · STAGES …). 어느 조각에 있었는지는 index.json 이 안다.
public final class ContentStore: Sendable {
    public struct Entry: Sendable, Decodable {
        public let file: String
        public let shape: String
        public let bytes: Int
        public let fns: Int?
        /// 객체형 표의 웹 키 순서(Object.keys) — 순서에 기대는 로직(매점 뽑기 등)은 이걸 쓴다
        public let keyOrder: [String]?
    }
    struct Index: Decodable {
        let sourceSha16: String
        let names: [String: Entry]
        let skipped: [String: String]
    }

    public let sourceSha16: String
    public let entries: [String: Entry]
    /// 추출에서 뺀 이름과 이유(함수 · 실행 상태 · 호스트 객체 …)
    public let skipped: [String: String]
    private let files: [String: Data]
    private let lambdas: [String: String]
    /// 조각 파일 → 이름별 값 바이트(처음 읽을 때 한 번 훑어 나눈다). 예전에는 이름 하나를 읽을 때마다 파일 전체(13-rig-grammar 770KB)를 다시 파싱했다
    private let slices = SliceCache()

    public init(directory: URL) throws {
        let dec = JSONDecoder()
        let idx = try dec.decode(Index.self, from: Data(contentsOf: directory.appending(path: "index.json")))
        sourceSha16 = idx.sourceSha16
        entries = idx.names
        skipped = idx.skipped
        var files: [String: Data] = [:]
        for f in Set(idx.names.values.map(\.file)) {
            files[f] = try Data(contentsOf: directory.appending(path: f + ".json"))
        }
        self.files = files
        lambdas = try dec.decode([String: String].self, from: Data(contentsOf: directory.appending(path: "lambdas.json")))
    }

    /// 패키지에 들어 있는 생성물.
    public static func bundled() throws -> ContentStore {
        try ContentStore(directory: GeneratedResources.url.appending(path: "content"))
    }

    public var names: [String] { entries.keys.sorted() }

    /// 이름 하나를 타입으로 읽는다.
    public func decode<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let e = entries[name], let data = files[e.file] else { throw ContentError.unknownName(name) }
        let dec = JSONDecoder()
        dec.userInfo[.contentName] = name
        if let v = slices.value(name, file: e.file, data: data) {
            if T.self == JSONValue.self, let j = try? JSONValue.parse(v) { return j as! T }
            return try dec.decode(T.self, from: v)
        }
        return try dec.decode(Pick<T>.self, from: data).value   // 훑기 실패(형식이 예상과 다름) — 예전 경로
    }

    /// 모든 조각 파일을 미리 나눠 둔다(뒤 스레드에서 미리 데우기용 — 안 불러도 결과는 같다)
    public func prewarm() {
        for e in Set(entries.values.map(\.file)) { if let d = files[e] { slices.split(file: e, data: d) } }
    }

    /// 모양이 정해지지 않은 값으로 읽는다.
    public func raw(_ name: String) throws -> JSONValue { try decode(name, as: JSONValue.self) }

    /// 객체형 표를 웹 키 순서대로 읽는다.
    public func table<T: Decodable>(_ name: String, of type: T.Type = T.self) throws -> OrderedTable<T> {
        guard let order = entries[name]?.keyOrder else { throw ContentError.notAnObject(name) }
        let dict = try decode(name, as: [String: T].self)
        return OrderedTable(keys: order, values: dict)
    }

    /// 함수 자리({"$fn"})의 웹 원문 — Swift로 손으로 옮길 때 참고.
    public func lambdaSource(_ ref: FunctionRef) -> String? { lambdas[ref.path] }
    public var lambdaPaths: [String] { lambdas.keys.sorted() }
}

public enum ContentError: Error, CustomStringConvertible {
    case unknownName(String)
    case notAnObject(String)
    case missingResource(String)
    case badPixelData(String, Int, Int)
    public var description: String {
        switch self {
        case .unknownName(let n): "추출 데이터에 없는 이름: \(n)"
        case .notAnObject(let n): "객체형 표가 아님(키 순서 없음): \(n)"
        case .missingResource(let n): "리소스 없음: \(n)"
        case .badPixelData(let f, let got, let want): "픽셀 데이터 크기 불일치 \(f): \(got) ≠ \(want)"
        }
    }
}

/// 키 순서를 지키는 표.
public struct OrderedTable<T: Sendable>: Sendable {
    public let keys: [String]
    public let values: [String: T]
    public subscript(key: String) -> T? { values[key] }
    public var count: Int { keys.count }
    public var ordered: [(key: String, value: T)] { keys.compactMap { k in values[k].map { (k, $0) } } }
}

/// 생성물 폴더 위치.
public enum GeneratedResources {
    public static var url: URL { Bundle.module.resourceURL!.appending(path: "Generated") }
}

// MARK: - 조각 파일({ 이름: 값, … })에서 이름 하나만 꺼내기

extension CodingUserInfoKey {
    static let contentName = CodingUserInfoKey(rawValue: "bb.contentName")!
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private struct Pick<T: Decodable>: Decodable {
    let value: T
    init(from decoder: Decoder) throws {
        let name = decoder.userInfo[.contentName] as! String
        value = try decoder.container(keyedBy: AnyKey.self).decode(T.self, forKey: AnyKey(stringValue: name))
    }
}

// MARK: - 조각 파일 나누기(최상위 객체 { "이름": 값, … } → 이름별 값 바이트)

/// 파일별로 한 번만 훑는다. 값 바이트는 원본 그대로라 JSONDecoder 결과가 파일 전체를 읽을 때와 같다.
final class SliceCache: @unchecked Sendable {
    private let lock = NSLock()
    private var byFile: [String: [String: Data]] = [:]
    private var failed = Set<String>()

    func value(_ name: String, file: String, data: Data) -> Data? {
        lock.lock()
        if let m = byFile[file] { lock.unlock(); return m[name] }
        let bad = failed.contains(file)
        lock.unlock()
        if bad { return nil }
        return split(file: file, data: data)?[name]
    }

    @discardableResult
    func split(file: String, data: Data) -> [String: Data]? {
        lock.lock()
        if let m = byFile[file] { lock.unlock(); return m }
        lock.unlock()
        let m = Self.topLevelValues(data)
        lock.lock(); defer { lock.unlock() }
        if let m { byFile[file] = m } else { failed.insert(file) }
        return m
    }

    /// 최상위 객체의 키 → 값 바이트 범위. 문자열 안 괄호 · 이스케이프를 건너뛴다. 형식이 어긋나면 nil
    static func topLevelValues(_ data: Data) -> [String: Data]? {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [String: Data]? in
            guard let b = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let n = raw.count
            var i = 0
            @inline(__always) func ws() { while i < n, b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0x09 { i += 1 } }
            /// 따옴표에서 시작해 닫는 따옴표 다음으로
            @inline(__always) func skipString() -> Bool {
                i += 1
                while i < n { let c = b[i]; if c == 0x5C { i += 2; continue }; i += 1; if c == 0x22 { return true } }
                return false
            }
            ws(); guard i < n, b[i] == 0x7B else { return nil }   // {
            i += 1
            var out: [String: Data] = [:]
            while true {
                ws(); guard i < n else { return nil }
                if b[i] == 0x7D { return out }                      // }
                if b[i] == 0x2C { i += 1; continue }                // ,
                guard b[i] == 0x22 else { return nil }
                let k0 = i
                guard skipString() else { return nil }
                let keyBytes = Data(bytes: b + k0, count: i - k0)
                guard let key = try? JSONDecoder().decode(String.self, from: keyBytes) else { return nil }
                ws(); guard i < n, b[i] == 0x3A else { return nil }  // :
                i += 1; ws()
                let v0 = i
                var depth = 0
                scan: while i < n {
                    switch b[i] {
                    case 0x22: guard skipString() else { return nil }
                    case 0x7B, 0x5B: depth += 1; i += 1
                    case 0x7D, 0x5D:
                        if depth == 0 { break scan }
                        depth -= 1; i += 1
                    case 0x2C: if depth == 0 { break scan }; i += 1
                    default: i += 1
                    }
                }
                guard i < n else { return nil }
                var v1 = i
                while v1 > v0, b[v1 - 1] == 0x20 || b[v1 - 1] == 0x0A || b[v1 - 1] == 0x0D || b[v1 - 1] == 0x09 { v1 -= 1 }
                out[key] = Data(bytes: b + v0, count: v1 - v0)
            }
        }
    }
}
