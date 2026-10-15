import Foundation
import Metal

/// 프레임마다 새 MTLBuffer 를 만들지 않고 돌려 쓰는 정점 버퍼 풀(docs/06 §8 성능).
/// 명령 버퍼가 GPU 에서 끝나면(addCompletedHandler) 버퍼가 풀로 돌아온다 — 몇 프레임이 동시에 날아가든 안전하다.
/// 크기는 2의 거듭제곱(최소 64KB)으로 올려 잡아 정점 수가 조금씩 바뀌어도 같은 버퍼를 다시 쓴다.
final class BufferPool: @unchecked Sendable {
    let device: MTLDevice
    private let lock = NSLock()
    private var free: [MTLBuffer] = []
    /// 풀에 남겨 둘 최대 수(그 이상 돌아오면 버린다)
    private let keep: Int
    private(set) var allocations = 0

    init(device: MTLDevice, keep: Int = 12) { self.device = device; self.keep = keep }

    /// bytes 를 담은 버퍼(쓰기 끝난 상태). cb 가 끝나면 풀로 돌아온다
    func buffer<T>(_ values: [T], for cb: MTLCommandBuffer) -> MTLBuffer? {
        let len = values.count * MemoryLayout<T>.stride
        guard len > 0 else { return nil }
        var cap = 64 * 1024
        while cap < len { cap <<= 1 }
        lock.lock()
        var buf: MTLBuffer?
        if let i = free.firstIndex(where: { $0.length >= len && $0.length <= cap * 4 }) { buf = free.remove(at: i) }
        lock.unlock()
        if buf == nil { buf = device.makeBuffer(length: cap, options: [.storageModeShared, .cpuCacheModeWriteCombined]); allocations += 1 }
        guard let b = buf else { return nil }
        values.withUnsafeBytes { b.contents().copyMemory(from: $0.baseAddress!, byteCount: len) }
        let back = Returned(b)
        cb.addCompletedHandler { [weak self] _ in self?.recycle(back.buffer) }
        return b
    }

    /// 완료 처리기로 넘기는 버퍼(그 뒤 이 프레임은 버퍼를 다시 만지지 않는다)
    private struct Returned: @unchecked Sendable { let buffer: MTLBuffer; init(_ b: MTLBuffer) { buffer = b } }

    private func recycle(_ b: MTLBuffer) {
        lock.lock(); defer { lock.unlock() }
        if free.count < keep { free.append(b) }
    }
}
