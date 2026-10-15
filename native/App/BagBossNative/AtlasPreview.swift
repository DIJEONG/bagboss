import CoreGraphics
import Foundation
import BBContent

/// 디버그용 CPU 칠하기: 재질 · 톤 → 팔레트 0 의 6단 색. 조명 · 디더 없음(진짜 색은 N1 Metal 합성 패스).
enum AtlasPreview {
    static func image(sprite name: String, meta: AtlasMeta) throws -> CGImage? {
        guard let s = meta.sprites[name] else { return nil }
        let a = try meta.loadAtlasA(), p = try meta.loadPalette()
        var out = [UInt8](repeating: 0, count: s.w * s.h * 4)
        for y in 0..<s.h { for x in 0..<s.w {
            let (mat, tone, emitB, alpha) = a.pixel(s.x + x, s.y + y), k = (y * s.w + x) * 4
            guard alpha != 0 else { continue }
            let step = min(5, Int(Double(tone) / 255 * 6)), emit = Double(emitB) / 255
            let c = p.pixel(step, Int(mat))
            out[k] = UInt8(min(255, Double(c.0) * (1 + emit * 0.6)))
            out[k + 1] = UInt8(min(255, Double(c.1) * (1 + emit * 0.6)))
            out[k + 2] = UInt8(min(255, Double(c.2) * (1 + emit * 0.6)))
            out[k + 3] = 255
        }}
        let ctx = CGContext(data: &out, width: s.w, height: s.h, bitsPerComponent: 8, bytesPerRow: s.w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        return ctx?.makeImage()
    }

    /// 노멀 아틀라스 (1346, 12) = [128,166,128,0] 이 그대로 읽히는지(BBContentTests 와 같은 픽셀)
    static func normalProbe() -> Bool {
        guard let n = try? AtlasMeta.bundled().loadAtlasN() else { return false }
        let p = n.pixel(1346, 12)
        return [p.0, p.1, p.2, p.3] == [128, 166, 128, 0]
    }
}
