import UIKit

/// 실기기 측정 기록. 웹의 perf.sample(1초마다) + 기기 상태(발열 · 배터리 · 앱 메모리)를 한 줄씩 CSV로 남긴다.
/// 파일: Documents/perf/session-YYYYMMDD-HHMMSS.csv  → '파일' 앱 › 나의 iPhone › BAG BOSS 에서 꺼낸다.
/// 주의: appMemMB는 앱 프로세스만이다. 게임(JS · WebGL)은 별도 WebContent 프로세스에서 돌아서 여기 안 잡힌다
///       → JS 힙 · WebContent 메모리는 Safari 웹 인스펙터 / Instruments로 본다(docs/04).
@MainActor
final class PerfMonitor {
    struct Live {
        var fps: Double = 0
        var p50: Double = 0
        var p95: Double = 0
        var maxMs: Double = 0
        var long: Int = 0
        var scene: String = ""
        var px: String = ""
        var fpsMin60: Double = 0          // 최근 60초 중 가장 낮은 1초 FPS
        var fpsAvg60: Double = 0
        var samples: Int = 0
    }

    private(set) var live = Live()
    private(set) var sessionURL: URL?
    private var handle: FileHandle?
    private var startedAt = Date()
    private var recentFPS: [Double] = []
    var onUpdate: (() -> Void)?

    var thermalLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "?"
        }
    }

    var batteryPercent: Int {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? -1 : Int((level * 100).rounded())
    }

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        startedAt = Date()
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dir = docs.appendingPathComponent("perf", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp: String = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let url = dir.appendingPathComponent("session-\(stamp).csv")
        let device = Self.deviceModel()
        let os = UIDevice.current.systemVersion
        let header = "# BAG BOSS perf · \(device) · iOS \(os) · app \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?")\n"
            + "t,fps,p50,p95,max,long,scene,px,thermal,battery,appMemMB,event,detail\n"
        fm.createFile(atPath: url.path, contents: header.data(using: .utf8))
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        sessionURL = url

        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.mark("thermal", detail: self?.thermalLabel ?? "") }
        }
    }

    /// bridge.js report() 의 payload: { fps, p50, p95, max, long, scene, px }
    func ingest(_ s: [String: Any]) {
        func d(_ k: String) -> Double { (s[k] as? NSNumber)?.doubleValue ?? 0 }
        live.fps = d("fps"); live.p50 = d("p50"); live.p95 = d("p95"); live.maxMs = d("max")
        live.long = (s["long"] as? NSNumber)?.intValue ?? 0
        live.scene = s["scene"] as? String ?? ""
        live.px = s["px"] as? String ?? ""
        live.samples += 1
        recentFPS.append(live.fps)
        if recentFPS.count > 60 { recentFPS.removeFirst(recentFPS.count - 60) }
        live.fpsMin60 = recentFPS.min() ?? 0
        live.fpsAvg60 = recentFPS.isEmpty ? 0 : recentFPS.reduce(0, +) / Double(recentFPS.count)
        write(event: "", detail: "")
        onUpdate?()
    }

    /// 사건 줄(시작 · 발열 변화 · 메모리 경고 · 웹 프로세스 종료 · JS 오류 …)
    func mark(_ event: String, detail: String = "") {
        write(event: event, detail: detail)
        onUpdate?()
    }

    private func write(event: String, detail: String) {
        guard let handle else { return }
        let t = String(format: "%.1f", Date().timeIntervalSince(startedAt))
        let mem = String(format: "%.0f", Self.appFootprintMB())
        func q(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "'") + "\"" }
        let row = [t, fmt(live.fps), fmt(live.p50), fmt(live.p95), fmt(live.maxMs), String(live.long),
                   q(live.scene), live.px, thermalLabel, String(batteryPercent), mem, event, q(detail)].joined(separator: ",") + "\n"
        if let data = row.data(using: .utf8) { try? handle.write(contentsOf: data) }   // 디스크 가득 등 I/O 오류에도 죽지 않게
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }

    func summaryText() -> String {
        let l = live
        return String(format: "FPS %.0f (60초 평균 %.0f · 최저 %.0f)\np95 %.1fms · 최대 %.0fms · 긴 프레임 %ld\n%@ · %@\n발열 %@ · 배터리 %ld%% · 앱 %.0fMB",
                      l.fps, l.fpsAvg60, l.fpsMin60, l.p95, l.maxMs, l.long, l.scene, l.px,
                      thermalLabel, batteryPercent, Self.appFootprintMB())
    }

    static func appFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    static func deviceModel() -> String {
        var sys = utsname()
        uname(&sys)
        return withUnsafeBytes(of: &sys.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
