import Foundation
import os

/// 대역 제한 파형표 — Chromium PeriodicWave 의 내장 파형(사각 · 톱니 · 삼각)과 같은 방식:
/// - 표 크기 S: 표본율 ≤24k 면 2048, ≤88.2k 면 4096, 그 위는 16384.
/// - 1/3옥타브마다 표 하나(범위 수 = round(3·log2 S)). 범위 i 의 배음 수 = ⌊S/2 · 2^(−i/3)⌋ (직류 · 나이퀴스트 칸 제외).
/// - 기본 주파수 f 로 범위를 고르고(pitchRange = 1 + 3·log2(f / (sr/S))) 이웃한 두 표를 섞는다 → 배음이 나이퀴스트를 넘지 않는다.
/// - 정규화: 배음이 가장 많은 표(범위 0)의 최댓값으로 모든 표를 나눈다(깁스 넘침 포함 최댓값 = 1).
/// 사인은 표 없이 sin() 을 쓴다. 표는 표 크기마다 한 번 만들고(앱은 시작 때 뒤 스레드에서) 오디오 스레드는 읽기만 한다.
/// 병렬 생성용 포인터 묶음(작업마다 겹치지 않는 칸만 쓴다)
private struct UncheckedPointers: @unchecked Sendable {
    let sinT: UnsafeMutablePointer<Double>, coefs: UnsafeMutablePointer<Double>, rows: UnsafeMutablePointer<Double>
}

final class WaveTableSet: @unchecked Sendable {
    let size: Int
    let ranges: Int
    let sampleRate: Double
    private let lowestFundamental: Double
    private let stride: Int                     // 표 하나 = size + 1 (보간용 덧칸)
    private let data: UnsafeMutablePointer<Float>   // [모양 3][범위][size+1]
    /// 표 데이터 주인(표 크기 S 가 같으면 표본율이 달라도 표가 같다 — 44.1k · 48k 는 같은 4096 표를 나눠 쓴다)
    private let storage: Storage

    final class Storage: @unchecked Sendable {
        let size: Int, ranges: Int
        let data: UnsafeMutablePointer<Float>
        init(size: Int) {
            self.size = size
            ranges = Int((3 * log2(Double(size))).rounded())
            data = .allocate(capacity: 3 * ranges * (size + 1))
            Self.build(size: size, ranges: ranges, into: data)
        }
        deinit { data.deallocate() }

        /// 범위 r 의 표 = 배음 1…P(r) 을 n 오름차순으로 더한 값(정규화 전). P(r) 은 r 이 클수록 작다(단조 감소).
        /// 열(i)마다 누적합을 n 오름차순으로 늘려 가며 각 범위의 배음 수에 닿을 때 찍는다 → 표본마다 더하는 순서가
        /// 예전 구현(범위마다 1부터 다시 · 행 단위)과 같아 결과가 비트 단위로 같다(WaveTableSpeedTests).
        /// 일은 Σ P(r) → max P(r)(약 1/5)이고, 열 묶음 × 모양으로 나눠 여러 코어에서 돈다(디버그 빌드에서 9초 → 수십 ms — docs/06 §8)
        static func build(size: Int, ranges: Int, into data: UnsafeMutablePointer<Float>) {
            let half = size / 2, stride = size + 1
            // sin(2π·m/S) 표 — 배음 합을 곱셈 · 표 찾기로만
            let sinT = UnsafeMutablePointer<Double>.allocate(capacity: size)
            defer { sinT.deallocate() }
            for m in 0..<size { sinT[m] = sin(2 * Double.pi * Double(m) / Double(size)) }
            let shapes: [Waveform] = [.square, .sawtooth, .triangle]
            let coefs = UnsafeMutablePointer<Double>.allocate(capacity: 3 * half)
            defer { coefs.deallocate() }
            for (si, shape) in shapes.enumerated() {
                for n in 0..<half {
                    let pn = Double.pi * Double(n)
                    let c: Double = switch shape {
                    case .square: n & 1 == 1 ? 4 / pn : 0
                    case .sawtooth: (n & 1 == 1 ? 2 : -2) / pn
                    case .triangle: n & 1 == 1 ? (8 / (pn * pn)) * (n & 2 != 0 ? -1 : 1) : 0
                    case .sine: n == 1 ? 1 : 0
                    }
                    coefs[si * half + n] = n == 0 ? 0 : c
                }
            }
            let P = (0..<ranges).map { r in min(half - 1, Int(pow(2, -Double(r) / 3) * Double(half))) }
            // 정규화 전 값 [모양][범위][size]
            let rows = UnsafeMutablePointer<Double>.allocate(capacity: 3 * ranges * size)
            defer { rows.deallocate() }
            let chunks = 16
            let job = UncheckedPointers(sinT: sinT, coefs: coefs, rows: rows)
            DispatchQueue.concurrentPerform(iterations: 3 * chunks) { w in
                let si = w / chunks, ch = w % chunks
                let i0 = ch * size / chunks, i1 = (ch + 1) * size / chunks, len = i1 - i0
                let coef = job.coefs + si * half, sinP = job.sinT
                let acc = UnsafeMutablePointer<Double>.allocate(capacity: len)
                defer { acc.deallocate() }
                acc.initialize(repeating: 0, count: len)
                var n = 1
                for r in Swift.stride(from: ranges - 1, through: 0, by: -1) {
                    let target = P[r]
                    while n <= target {
                        let c = coef[n]
                        if c != 0 {
                            var idx = (n * i0) % size
                            for k in 0..<len { acc[k] += c * sinP[idx]; idx += n; if idx >= size { idx -= size } }
                        }
                        n += 1
                    }
                    (job.rows + (si * ranges + r) * size + i0).update(from: acc, count: len)
                }
            }
            for si in 0..<3 {
                var peak = 0.0
                let r0 = rows + si * ranges * size
                for i in 0..<size { peak = max(peak, abs(r0[i])) }
                let scale = 1 / max(1e-12, peak)
                for r in 0..<ranges {
                    let src = rows + (si * ranges + r) * size, base = data + (si * ranges + r) * stride
                    for i in 0..<size { base[i] = Float(src[i] * scale) }
                    base[size] = base[0]
                }
            }
        }
    }

    private static let cacheLock = OSAllocatedUnfairLock(initialState: [Double: WaveTableSet]())
    private static let storageLock = OSAllocatedUnfairLock(initialState: [Int: Storage]())

    /// 표본율별로 한 번만 만든다(잠금 — 어느 스레드에서든. 앱은 시작 때 뒤 스레드에서 미리 만든다: AudioEngine.prewarm)
    static func shared(sampleRate: Double) -> WaveTableSet {
        cacheLock.withLock { cache in
            if let t = cache[sampleRate] { return t }
            let t = WaveTableSet(sampleRate: sampleRate)
            cache[sampleRate] = t
            return t
        }
    }

    static func tableSize(_ sr: Double) -> Int { sr <= 24000 ? 2048 : sr <= 88200 ? 4096 : 16384 }

    init(sampleRate sr: Double) {
        sampleRate = sr
        size = Self.tableSize(sr)
        let sz = size
        storage = Self.storageLock.withLock { c in
            if let s = c[sz] { return s }
            let s = Storage(size: sz); c[sz] = s; return s
        }
        ranges = storage.ranges
        lowestFundamental = sr / Double(size)
        stride = size + 1
        data = storage.data
    }

    /// 표 하나(덧칸 포함 size+1) — 테스트용
    func rawTable(shape si: Int, range r: Int) -> [Float] { Array(UnsafeBufferPointer(start: data + (si * ranges + r) * stride, count: stride)) }

    /// 모양 · 위상[0,1) · 기본 주파수 → 값
    @inline(__always) func sample(_ shape: Waveform, phase: Double, freq: Double) -> Float {
        let si: Int
        switch shape {
        case .sine: return Float(sin(2 * .pi * phase))
        case .square: si = 0
        case .sawtooth: si = 1
        case .triangle: si = 2
        }
        let ratio = freq > 0 ? freq / lowestFundamental : 0.5
        var pr = 1 + 3 * log2(ratio)
        pr = max(0, min(Double(ranges - 1), pr))
        let r1 = Int(pr), r2 = r1 < ranges - 1 ? r1 + 1 : r1
        let k = Float(pr - Double(r1))
        let pos = phase * Double(size), i = Int(pos), a = Float(pos - Double(i))
        let hi = data + (si * ranges + r1) * stride, lo = data + (si * ranges + r2) * stride
        let vh = hi[i] + (hi[i + 1] - hi[i]) * a
        let vl = lo[i] + (lo[i + 1] - lo[i]) * a
        return (1 - k) * vh + k * vl
    }
}
