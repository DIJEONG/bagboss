import Foundation
import os

// 시작 시간 계측(docs/06 §8 '성능 · 시작 시간'): 프로세스 시작(커널 p_starttime — dyld · 정적 초기화 포함)부터의 경과 시각.
//  · Instruments 'os_signpost'(하위 시스템 com.dijeong.bagboss · 범주 boot)에 구간 · 표시가 남는다(릴리스에서도 — 비용은 무시할 만하다)
//  · DEBUG 빌드는 콘솔에 `[boot] +1234ms 이름 (구간 56ms)` 로도 찍는다
enum BootTrace {
    static let log = OSLog(subsystem: "com.dijeong.bagboss", category: "boot")
    static let signposter = OSSignposter(logHandle: log)

    /// 프로세스 시작 시각(CLOCK_REALTIME 기준 초) — sysctl KERN_PROC_PID
    static let processStart: Double = {
        var kp = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &kp, &size, nil, 0) == 0 else { return Date().timeIntervalSince1970 }
        let t = kp.kp_proc.p_un.__p_starttime
        return Double(t.tv_sec) + Double(t.tv_usec) / 1e6
    }()

    /// 프로세스 시작부터 지금까지(ms)
    static var sinceStart: Double { (Date().timeIntervalSince1970 - processStart) * 1000 }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var once = Set<String>()

    /// 한 순간 표시
    static func mark(_ name: StaticString, _ detail: String = "") {
        signposter.emitEvent(name, "\(detail)")
        #if DEBUG
        print(String(format: "[boot] +%.0fms %@%@", sinceStart, "\(name)", detail.isEmpty ? "" : " · \(detail)"))
        #endif
    }

    /// 처음 한 번만 표시(첫 프레임 등)
    static func markOnce(_ name: StaticString, _ detail: String = "") {
        lock.lock(); let first = once.insert("\(name)").inserted; lock.unlock()
        if first { mark(name, detail) }
    }

    /// 한 번만 다시 표시할 수 있게 지운다(새 판 → 첫 판 프레임)
    static func reset(_ name: StaticString) { lock.lock(); once.remove("\(name)"); lock.unlock() }

    /// 구간 재기 — 결과 ms 를 돌려준다
    @discardableResult
    static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let id = signposter.makeSignpostID()
        let st = signposter.beginInterval(name, id: id)
        let t0 = DispatchTime.now().uptimeNanoseconds
        defer {
            signposter.endInterval(name, st)
            #if DEBUG
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
            print(String(format: "[boot] +%.0fms %@ (구간 %.1fms · %@)", sinceStart, "\(name)", ms, Thread.isMainThread ? "주" : "뒤"))
            #endif
        }
        return try body()
    }
}
