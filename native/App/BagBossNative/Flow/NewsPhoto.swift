import Foundation
import Metal
import CoreGraphics
import BBContent
import BBRender

// 결과 신문 '보도 사진'(웹 38-title-news newsPhoto): 판이 끝난 순간의 장면을 240×135 로 줄이고
// 밝기 → pow(L, .8)·1.15 를 4×4 순서 디더(Bayer)로 흑백 망점 → 종이빛(236,232,222 / 22,18,8).
// 화면의 MTKView 드로어블은 framebufferOnly 라 읽을 수 없으므로, 같은 RenderFrame 을 따로 만든 렌더러 · 타깃에 한 번 더 그려 읽는다
// (BBRender 공개 API: FrameRenderer.encode · Targets.output · readBack). 판마다 한 번이라 동기 읽기로 충분하다.

@MainActor
final class NewsPhotoCapture {
    private let atlas: AtlasMeta
    private var renderer: FrameRenderer?
    private var queue: MTLCommandQueue?
    private var targets: FrameRenderer.Targets?

    init(atlas: AtlasMeta) { self.atlas = atlas }

    /// RenderFrame → 디더 사진(실패하면 nil)
    func capture(_ f: RenderFrame) -> CGImage? {
        do {
            if renderer == nil {
                guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
                renderer = try FrameRenderer(device: dev, atlas: atlas); queue = dev.makeCommandQueue()
            }
            guard let r = renderer, let q = queue else { return nil }
            if targets == nil || targets!.width != f.width || targets!.height != f.height {
                targets = try FrameRenderer.Targets(device: r.device, width: f.width, height: f.height)
            }
            guard let t = targets, let cb = q.makeCommandBuffer() else { return nil }
            try r.encode(f, targets: t, into: cb)
            cb.commit(); cb.waitUntilCompleted()
            let px = try r.readBack(t.output(for: f), queue: q)
            // 화면에 보이던 부분(세로 화면 크롭: cameraX ~ +visibleWidth)
            let vw = Int(max(1, min(Float(f.width), f.blit.visibleWidth)).rounded()), cx = Int(max(0, min(Float(f.width - vw), f.blit.cameraX)).rounded())
            return Self.dither(px, width: f.width, height: f.height, crop: (cx, vw))
        } catch {
            return nil
        }
    }

    /// 웹 newsPhoto 의 축소 + 4×4 순서 디더. 원본 비율을 지키려고 16:9 로 가운데를 자른다
    static func dither(_ px: [UInt8], width W: Int, height H: Int, crop: (x: Int, w: Int), outW: Int = 240, outH: Int = 135) -> CGImage? {
        let B: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
        let srcW = Double(crop.w), srcH = min(Double(H), srcW * Double(outH) / Double(outW))
        let y0 = (Double(H) - srcH) * 0.45
        var out = [UInt8](repeating: 255, count: outW * outH * 4)
        for y in 0..<outH {
            for x in 0..<outW {
                // 상자 평균(웹 drawImage 축소와 비슷하게 — 2×2 표본)
                var L = 0.0
                for (dx, dy) in [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)] {
                    let sx = min(W - 1, crop.x + Int((Double(x) + dx) / Double(outW) * srcW))
                    let sy = min(H - 1, Int(y0 + (Double(y) + dy) / Double(outH) * srcH))
                    let o = (sy * W + sx) * 4
                    L += (0.3 * Double(px[o]) + 0.59 * Double(px[o + 1]) + 0.11 * Double(px[o + 2])) / 255
                }
                L /= 4
                let v: Double = pow(L, 0.8) * 1.15 > (B[(y % 4) * 4 + x % 4] + 0.5) / 16 ? 236 : 22
                let o = (y * outW + x) * 4
                out[o] = UInt8(v); out[o + 1] = UInt8(v - 4); out[o + 2] = UInt8(v - 14); out[o + 3] = 255
            }
        }
        let data = Data(out) as CFData
        guard let prov = CGDataProvider(data: data) else { return nil }
        return CGImage(width: outW, height: outH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: outW * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
