import Foundation

/// localStorage 'dotlab*' 키의 네이티브 백업.
/// - 파일: Application Support/BagBoss/save.json  (iCloud 기기 백업에 포함된다)
/// - 웹이 바꿀 때마다 save.put으로 받아 1초 모아서 원자적으로 쓴다
/// - 앱 시작 시 스냅숏을 웹에 주입 → 웹 저장소가 비었으면(WebKit 데이터 정리 · 재설치 복원 등) 그 키만 복원
/// 1단계에서는 '웹 localStorage가 원본, 파일은 백업'이다. 2단계에서 원본을 네이티브로 옮길지 결정(docs/01).
final class SaveStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.dijeong.bagboss.save")
    private let fileURL: URL
    private var data: [String: String] = [:]
    private var dirty = false
    private var writeScheduled = false

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("BagBoss", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("save.json")
        load()
    }

    /// 웹에 주입할 현재 값(키 → 문자열)
    func snapshot() -> [String: String] {
        queue.sync { data }
    }

    /// value == nil 이면 삭제
    func apply(_ puts: [String: String?]) {
        queue.async {
            for (key, value) in puts {
                if let value { self.data[key] = value } else { self.data.removeValue(forKey: key) }
            }
            self.dirty = true
            self.scheduleWrite()
        }
    }

    /// 백그라운드 진입 등: 남은 변경을 지금 바로 디스크에
    func flush() {
        queue.sync { self.writeNow() }
    }

    var fileSizeBytes: Int {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
    }

    // MARK: 내부 (queue 위에서만)
    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let keys = obj["keys"] as? [String: String] else { return }
        data = keys
    }

    private func scheduleWrite() {
        guard !writeScheduled else { return }
        writeScheduled = true
        queue.asyncAfter(deadline: .now() + 1.0) {
            self.writeScheduled = false
            self.writeNow()
        }
    }

    private func writeNow() {
        guard dirty else { return }
        let obj: [String: Any] = [
            "v": 1,
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "keys": data,
        ]
        do {
            let raw = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
            try raw.write(to: fileURL, options: [.atomic])
            dirty = false
        } catch {
            NSLog("[BagBoss] 저장 파일 쓰기 실패: %@", error.localizedDescription)
        }
    }
}
