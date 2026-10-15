import Foundation

// 오버레이 아틀라스(CPU RGBA8, 곧은 알파) — 피해 숫자 글리프(dGlyph) · 컷인 원화 · 글자 그림을 한 장에 모은다.
// 렌더러(BBRender OverlayRenderer)는 version 이 바뀌면 dirty 범위만 GPU 로 올린다. 이미지 코덱을 거치지 않는다(데이터 픽셀).
// 칸 배치는 선반(shelf) 방식. 가득 차면 통째로 비우고(version 증가) 이번 프레임에 필요한 것부터 다시 굽는다.

public final class OverlayAtlas: @unchecked Sendable {
    public struct Entry: Sendable, Equatable { public var x: Int, y: Int, w: Int, h: Int }
    public static let size = 2048
    /// 흰 텍셀 가운데(단색 채우기 uv) — (0,0)~(3,3) 은 늘 흰색
    public static let whiteUV: SIMD2<Double> = [1.5, 1.5]

    public private(set) var pixels: [UInt8]
    /// 바뀐 행 범위(렌더러가 올린 뒤 clearDirty)
    public private(set) var dirty: Range<Int>? = nil
    public private(set) var version = 0
    private var entries: [String: Entry] = [:]
    private var shelfY = 4, shelfH = 0, cursorX = 4
    private let lock = NSLock()

    public init() {
        pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        reset()
    }

    private func reset() {
        // 16MB 를 한 번에 0 으로(첨자 반복은 디버그 빌드에서 1.3초 — 시작 시간 측정 docs/06 §8)
        pixels.withUnsafeMutableBytes { _ = memset($0.baseAddress!, 0, $0.count) }
        for y in 0..<3 { for x in 0..<3 { let o = (y * Self.size + x) * 4; pixels[o] = 255; pixels[o + 1] = 255; pixels[o + 2] = 255; pixels[o + 3] = 255 } }
        entries = [:]; shelfY = 4; shelfH = 0; cursorX = 4
        dirty = 0..<Self.size; version += 1
    }

    public func clearDirty() { lock.lock(); dirty = nil; lock.unlock() }

    /// 렌더러가 올릴 때 쓰는 잠금 구간
    public func withPixels<T>(_ f: ([UInt8], Range<Int>?) -> T) -> T { lock.lock(); defer { lock.unlock() }; return f(pixels, dirty) }

    /// 열쇠로 찾고, 없으면 make 로 굽는다(w · h · RGBA 곧은 알파)
    public func entry(_ key: String, make: () -> (w: Int, h: Int, rgba: [UInt8])?) -> Entry? {
        lock.lock()
        if let e = entries[key] { lock.unlock(); return e }
        lock.unlock()
        guard let img = make(), img.w > 0, img.h > 0, img.w <= Self.size - 8, img.h <= Self.size - 8 else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let e = entries[key] { return e }
        guard let e = place(img.w, img.h) ?? { reset(); return place(img.w, img.h) }() else { return nil }
        for y in 0..<img.h {
            let src = y * img.w * 4, dst = ((e.y + y) * Self.size + e.x) * 4
            pixels.replaceSubrange(dst..<(dst + img.w * 4), with: img.rgba[src..<(src + img.w * 4)])
        }
        let r = e.y..<(e.y + e.h)
        dirty = dirty.map { min($0.lowerBound, r.lowerBound)..<max($0.upperBound, r.upperBound) } ?? r
        version += 1
        entries[key] = e
        return e
    }

    private func place(_ w: Int, _ h: Int) -> Entry? {
        let pad = 2
        if cursorX + w + pad > Self.size { shelfY += shelfH + pad; shelfH = 0; cursorX = 4 }
        if shelfY + h + pad > Self.size { return nil }
        let e = Entry(x: cursorX, y: shelfY, w: w, h: h)
        cursorX += w + pad; shelfH = max(shelfH, h)
        return e
    }
}
