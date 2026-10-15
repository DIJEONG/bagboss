// SaveStore — 저장 파일 하나(Application Support/BagBoss/save.json)에 localStorage 키 → JSON 문자열을 담는다.
//
// 봉투 모양(웹 셸 ios/BagBoss/Bridge/SaveStore.swift 와 같은 자리 · 같은 모양):
//   v1(웹 셸이 씀): { "v":1, "updatedAt":"ISO8601", "keys": { "<localStorage 키>": "<JSON 문자열>" } }
//   v2(네이티브가 씀): 같은 모양에 v:2. updatedAt 은 iCloud 충돌 해결용 기준 시각이다.
// - v1 · v2 모두 읽는다(같은 번들 ID 로 네이티브 앱을 내면 웹 셸 플레이어의 진행이 그대로 넘어온다).
// - keys 값은 언제나 문자열이다(웹 셸이 `[String: String]` 으로 읽으므로 셸로 되돌아가도 읽힌다). 삭제는 키를 뺀다.
// - 개발 키(dotlab.graph.v4 · dotlab.poses.v2 · dotlab-poseEdits)와 모르는 키는 건드리지 않고 그대로 다시 쓴다.
// - 쓰기: 임시 파일에 쓴 뒤 바꿔치기(원자적). 변경은 `debounce`(기본 1초) 모아 쓰고, 백그라운드 진입 때는 `flush()` 로 즉시.
// - 파일이 깨져 있으면 덮어쓰지 않도록 `save.json.corrupt-<시각>` 으로 옮겨 두고 빈 상태로 시작한다.
//
// 동시성: 모든 상태는 잠금 안에서만 만진다(@unchecked Sendable). 앱 백그라운드 진입에서 기다림 없이 부를 수 있도록
// 액터 대신 동기 API 로 둔다. 디스크 쓰기는 별도 잠금으로 한 번에 하나씩.
import Foundation

public final class SaveStore: @unchecked Sendable {
    /// 네이티브가 쓰는 봉투 버전
    public static let envelopeVersion = 2
    /// 개발 전용 키 — 읽지도 바꾸지도 않지만 파일에는 그대로 남긴다
    public static let devKeys: Set<String> = ["dotlab.graph.v4", "dotlab.poses.v2", "dotlab-poseEdits"]

    public let fileURL: URL
    public let debounce: TimeInterval
    private let now: @Sendable () -> Date

    private let lock = NSLock()
    private let ioLock = NSLock()
    private let timerQueue = DispatchQueue(label: "bagboss.persistence.save")

    // 아래는 lock 안에서만
    private var keys: [String: String] = [:]
    private var updatedAt: Date?
    private var loadedVersion: Int?
    /// 바뀔 때마다 1씩 — 쓰는 도중 또 바뀌면 dirty 를 지우지 않는다
    private var generation = 0
    private var flushedGeneration = 0
    private var flushScheduled = false
    private var lastError: Error?

    // MARK: 만들기

    /// 기본 위치: Application Support/BagBoss/save.json (웹 셸과 같은 파일)
    public static func defaultFileURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent("BagBoss", isDirectory: true).appendingPathComponent("save.json")
    }

    public init(fileURL: URL, debounce: TimeInterval = 1.0, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.debounce = debounce
        self.now = now
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        loadFromDisk()
    }

    public convenience init() throws {
        self.init(fileURL: try SaveStore.defaultFileURL())
    }

    // MARK: 날 문자열 접근(localStorage 흉내)

    public func string(forKey key: String) -> String? {
        lock.withLock { keys[key] }
    }

    /// nil 이면 삭제. 바뀌면 debounce 뒤 디스크에 쓴다.
    public func setString(_ value: String?, forKey key: String) {
        let changed: Bool = lock.withLock {
            guard keys[key] != value else { return false }
            if let value { keys[key] = value } else { keys.removeValue(forKey: key) }
            generation += 1
            updatedAt = now()
            return true
        }
        if changed { scheduleFlush() }
    }

    /// 여러 키를 한 번에(웹 셸 save.put 과 같은 의미: nil = 삭제)
    public func apply(_ entries: [String: String?]) {
        let changed: Bool = lock.withLock {
            var any = false
            for (key, value) in entries where keys[key] != value {
                if let value { keys[key] = value } else { keys.removeValue(forKey: key) }
                any = true
            }
            if any { generation += 1; updatedAt = now() }
            return any
        }
        if changed { scheduleFlush() }
    }

    /// 현재 키 → 문자열 전부
    public func snapshot() -> [String: String] { lock.withLock { keys } }

    /// 마지막 변경 시각(파일에서 읽은 값 또는 이번 실행의 변경)
    public var lastUpdatedAt: Date? { lock.withLock { updatedAt } }
    /// 처음 읽은 파일의 봉투 버전(파일이 없었으면 nil) — 1 이면 웹 셸에서 넘어온 것
    public var sourceVersion: Int? { lock.withLock { loadedVersion } }
    public var hasPendingChanges: Bool { lock.withLock { generation != flushedGeneration } }
    /// 마지막 쓰기 실패(성공하면 nil)
    public var lastWriteError: Error? { lock.withLock { lastError } }

    // MARK: 쓰기

    /// 남은 변경을 지금 바로 디스크에(앱 백그라운드 진입 · 종료 직전). 변경이 없으면 아무것도 안 한다.
    @discardableResult
    public func flush() -> Bool {
        ioLock.lock(); defer { ioLock.unlock() }
        let pending: (keys: [String: String], at: Date?, gen: Int)? = lock.withLock {
            generation == flushedGeneration ? nil : (keys, updatedAt, generation)
        }
        guard let (snapKeys, snapAt, snapGen) = pending else { return true }
        do {
            let data = try Self.encodeEnvelope(keys: snapKeys, updatedAt: snapAt ?? now())
            try Self.atomicWrite(data, to: fileURL)
            lock.withLock { flushedGeneration = max(flushedGeneration, snapGen); lastError = nil }
            return true
        } catch {
            lock.withLock { lastError = error }
            return false
        }
    }

    /// debounce 뒤 한 번 쓴다(이미 예약돼 있으면 그 예약에 합친다)
    public func scheduleFlush() {
        let shouldSchedule: Bool = lock.withLock {
            if flushScheduled { return false }
            flushScheduled = true
            return true
        }
        guard shouldSchedule else { return }
        timerQueue.asyncAfter(deadline: .now() + debounce) { [weak self] in
            guard let self else { return }
            self.lock.withLock { self.flushScheduled = false }
            self.flush()
        }
    }

    // MARK: 봉투

    public struct Envelope: Sendable, Equatable {
        public var v: Int
        public var updatedAt: Date?
        public var keys: [String: String]
    }

    /// 봉투 읽기: v1 · v2(및 더 높은 v 도 keys 를 읽을 수 있으면) — keys 의 문자열이 아닌 값(null 등)은 없는 키로 본다
    public static func decodeEnvelope(_ data: Data) throws -> Envelope {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let v = (obj["v"] as? NSNumber)?.intValue ?? 1
        guard let rawKeys = obj["keys"] as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        var keys: [String: String] = [:]
        for (k, val) in rawKeys { if let s = val as? String { keys[k] = s } }
        let at = (obj["updatedAt"] as? String).flatMap(parseISO8601)
        return Envelope(v: v, updatedAt: at, keys: keys)
    }

    public static func encodeEnvelope(keys: [String: String], updatedAt: Date) throws -> Data {
        let obj: [String: Any] = [
            "v": envelopeVersion,
            "updatedAt": formatISO8601(updatedAt),
            "keys": keys,
        ]
        return try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func formatISO8601(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    static func parseISO8601(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]   // 웹 셸은 소수 초 없이 쓴다
        return f.date(from: s)
    }

    /// 같은 폴더의 임시 파일에 쓰고 바꿔치기. 중간에 죽어도 원래 파일이나 새 파일 중 하나만 남는다.
    public static func atomicWrite(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let tmp = dir.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: tmp, options: [.withoutOverwriting])
            if fm.fileExists(atPath: url.path) {
                _ = try fm.replaceItemAt(url, withItemAt: tmp, backupItemName: nil, options: [])
            } else {
                try fm.moveItem(at: tmp, to: url)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    // MARK: 내부

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let env = try Self.decodeEnvelope(data)
            lock.withLock {
                keys = env.keys
                updatedAt = env.updatedAt
                loadedVersion = env.v
            }
        } catch {
            // 깨진 파일은 지우지 않고 옆으로 치운다(플레이어 기록을 덮어쓰지 않게)
            let stamp = Int(now().timeIntervalSince1970)
            let aside = fileURL.deletingLastPathComponent().appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(stamp)")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
        }
    }
}

// MARK: - 타입 접근(웹 키 · 웹 불러오기 의미)

public extension SaveStore {
    /// 메타 진행(없거나 v≠1 이면 웹 기본값)
    func meta() -> MetaState { MetaState.load(webJSON: string(forKey: MetaState.storageKey)) }
    func setMeta(_ m: MetaState) { setJSON(m, forKey: MetaState.storageKey) }

    /// 판 이어 하기(없거나 v≠1 이면 nil). 불러온 뒤 새 uid 는 `nextUid` 부터.
    func runSave() -> RunSave? { RunSave.load(webJSON: string(forKey: RunSave.storageKey)) }
    func setRunSave(_ r: RunSave?) {
        if let r { setJSON(r, forKey: RunSave.storageKey) } else { setString(nil, forKey: RunSave.storageKey) }
    }
    func clearRunSave() { setString(nil, forKey: RunSave.storageKey) }

    func options() -> Options { Options.load(webJSON: string(forKey: Options.storageKey)) }
    func setOptions(_ o: Options) { setJSON(o, forKey: Options.storageKey) }

    func sound() -> SoundOptions { SoundOptions.load(webJSON: string(forKey: SoundOptions.storageKey)) }
    func setSound(_ s: SoundOptions) { setJSON(s, forKey: SoundOptions.storageKey) }

    /// 언어는 JSON 이 아닌 날 문자열로 저장한다(웹과 같게)
    func language() -> Language { Language.load(raw: string(forKey: Language.storageKey)) }
    func setLanguage(_ l: Language) { setString(l.rawValue, forKey: Language.storageKey) }

    /// limit: 웹 8(기본) · 네이티브 무도장은 CustomCombo.nativeMaxSteps
    func customCombo(limit: Int = CustomCombo.maxSteps) -> CustomCombo { CustomCombo.load(webJSON: string(forKey: CustomCombo.storageKey), limit: limit) }
    func setCustomCombo(_ c: CustomCombo) { setJSON(c, forKey: CustomCombo.storageKey) }

    /// JSON.stringify 와 같은 압축 문자열로 저장(키는 사전순 — 같은 상태면 같은 바이트. 웹은 키 순서에 기대지 않는다)
    func setJSON<T: Encodable>(_ value: T, forKey key: String) {
        guard let s = try? SaveStore.webJSONString(value) else { return }
        setString(s, forKey: key)
    }

    static func webJSONString<T: Encodable>(_ value: T) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try enc.encode(value), as: UTF8.self)
    }
}
