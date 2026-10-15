#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import BBCore

// 가방 UI 도트 스킨(웹 33-bag-ui2 buildInvSkin 1:1): 가죽 틀 · 안감 칸 · 지퍼 옆주머니 · 보류 칸 · 지하철 쓰레기통 · 놋쇠 버튼 · 짙은 판 · 토큰.
// 픽셀을 직접 찍어 CGImage 로 만든다(이미지 코덱을 거치지 않는다). 그릴 때는 최근접 확대(magnificationFilter = .nearest).

/// 작은 픽셀 캔버스 — 웹 pxCanvas 의 P(점) · R(사각형)
struct PixelCanvas {
    let w: Int, h: Int
    var px: [UInt32]   // RGBA8(메모리 순서 R,G,B,A)
    init(_ w: Int, _ h: Int) { self.w = w; self.h = h; px = Array(repeating: 0, count: w * h) }
    static func rgba(_ hex: String) -> UInt32 {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        let r = (v >> 16) & 0xff, g = (v >> 8) & 0xff, b = v & 0xff
        return r | (g << 8) | (b << 16) | (0xff << 24)
    }
    mutating func P(_ x: Int, _ y: Int, _ c: String) {
        guard x >= 0, y >= 0, x < w, y < h else { return }
        px[y * w + x] = Self.rgba(c)
    }
    mutating func R(_ x: Int, _ y: Int, _ ww: Int, _ hh: Int, _ c: String) {
        for j in 0..<hh { for i in 0..<ww { P(x + i, y + j, c) } }
    }
    func image() -> CGImage {
        let data = px.withUnsafeBufferPointer { Data(buffer: $0) }
        let provider = CGDataProvider(data: data as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}

/// 최근접 정수배 확대 — 9-슬라이스(contentsCenter)는 레이어 확대 필터를 거치지 않으므로 미리 키워 둔다
public func bbUpscale(_ img: CGImage, _ k: Int) -> CGImage {
    let w = img.width * k, h = img.height * k
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

/// 스킨 이미지 묶음 — 한 번 만들어 공유한다
public final class BagPixelSkin: @unchecked Sendable {
    public static let shared = BagPixelSkin()
    /// 9-슬라이스 테두리 폭(이미지 픽셀): frame 8 · pocket 6 · btn/plate 4
    public let frame: CGImage, cell: CGImage, pocket: CGImage, slot: CGImage, trash: CGImage, btn: CGImage, plate: CGImage, token: CGImage, lock: CGImage

    init() {
        var rng = Mulberry32(seed: 7)   // 웹 mulberry(7) — 틀 · 주머니가 같은 수열을 이어 쓴다
        // 가죽 틀 24×24(모서리 8): 바깥 검은 선 · 가죽 결 · 바느질 · 모서리 놋쇠 리벳 · 안쪽 그림자
        var f = PixelCanvas(24, 24)
        for y in 0..<24 { for x in 0..<24 { let n = rng.next(); f.P(x, y, n < 0.12 ? "#5a3820" : n < 0.3 ? "#7a4c2a" : "#6a4226") } }
        for i in 0..<24 { f.P(i, 0, "#0e0d14"); f.P(i, 23, "#0e0d14"); f.P(0, i, "#0e0d14"); f.P(23, i, "#0e0d14"); f.P(i, 1, "#9a6a3e"); f.P(1, i, "#9a6a3e"); f.P(i, 22, "#3a2414"); f.P(22, i, "#3a2414") }
        for i in 3..<21 where i % 3 != 2 { f.P(i, 3, "#e8d6a8"); f.P(i, 20, "#c9b282"); f.P(3, i, "#e8d6a8"); f.P(20, i, "#c9b282") }
        for (x, y) in [(5, 5), (17, 5), (5, 17), (17, 17)] { f.R(x, y, 2, 2, "#c08a24"); f.P(x, y, "#ffe7a8"); f.P(x + 1, y + 1, "#8a5a14") }
        for i in 7..<17 { f.P(i, 7, "#2a1a10"); f.P(7, i, "#2a1a10") }
        f.R(8, 8, 8, 8, "#3b2618")
        frame = f.image()
        // 안감 칸 16×16: 짙은 천 · 사선 결 · 박음질 경계
        var c = PixelCanvas(16, 16)
        c.R(0, 0, 16, 16, "#1f1a38")
        for y in 0..<16 { for x in 0..<16 { if (x + y) % 4 == 0 { c.P(x, y, "#262044") }; if (x - y + 16) % 6 == 0 { c.P(x, y, "#191430") } } }
        for i in 0..<16 { c.P(i, 0, "#120f22"); c.P(0, i, "#120f22"); c.P(i, 15, "#2c2650"); c.P(15, i, "#2c2650") }
        for i in stride(from: 2, to: 14, by: 3) { c.P(i, 1, "#3a3360"); c.P(1, i, "#3a3360") }
        cell = c.image()
        // 지퍼 달린 옆주머니 18×18(모서리 6)
        var p = PixelCanvas(18, 18)
        for y in 0..<18 { for x in 0..<18 { let n = rng.next(); p.P(x, y, n < 0.14 ? "#4a2e1a" : n < 0.32 ? "#6a4226" : "#5a3820") } }
        for i in 0..<18 { p.P(i, 0, "#0e0d14"); p.P(i, 17, "#0e0d14"); p.P(0, i, "#0e0d14"); p.P(17, i, "#0e0d14"); p.P(i, 1, "#8a5e38"); p.P(1, i, "#8a5e38"); p.P(i, 16, "#2a1a10"); p.P(16, i, "#2a1a10") }
        for i in 2..<16 { p.P(i, 2, i % 2 == 1 ? "#c9a24a" : "#8a6a24"); p.P(i, 3, i % 2 == 1 ? "#8a6a24" : "#c9a24a") }
        for i in 5..<14 where i % 3 != 2 { p.P(3, i, "#e8d6a8"); p.P(14, i, "#c9b282") }
        for i in 4..<14 where i % 3 != 2 { p.P(i, 14, "#c9b282") }
        pocket = p.image()
        var s = PixelCanvas(12, 12)
        s.R(0, 0, 12, 12, "#24160d"); s.R(1, 1, 10, 10, "#1a110a")
        for i in 0..<12 { s.P(i, 0, "#0b0705"); s.P(0, i, "#0b0705"); s.P(i, 11, "#7a5232"); s.P(11, i, "#7a5232"); s.P(i, 1, "#120b06"); s.P(1, i, "#120b06") }
        for (x, y) in [(2, 2), (9, 2), (2, 9), (9, 9)] { s.P(x, y, "#5a3c24") }
        slot = s.image()
        var t = PixelCanvas(28, 34)
        t.R(9, 0, 6, 3, "#d9d2bf"); t.R(10, 1, 2, 1, "#9a937e"); t.R(15, 1, 4, 2, "#bfb7a0"); t.P(16, 1, "#7d7766"); t.R(7, 2, 14, 2, "#0e0d14")
        for y in 6..<31 {
            let sh = (y - 6) / 12, x0 = 3 + sh, x1 = 24 - sh
            for x in x0...x1 { let m = ((x + y) % 5 == 0) || ((x - y + 40) % 5 == 0); t.P(x, y, m ? (x < x0 + 4 ? "#6fc07a" : x > x1 - 3 ? "#245a30" : "#3f8a4e") : "#101a12") }
            t.P(x0, y, "#0e0d14"); t.P(x1, y, "#0e0d14")
        }
        t.R(2, 3, 24, 3, "#3f8a4e"); t.R(2, 3, 24, 1, "#7fd08a"); t.R(2, 5, 24, 1, "#1c3a22"); t.P(2, 4, "#0e0d14"); t.P(25, 4, "#0e0d14")
        t.R(4, 17, 20, 2, "#2f6b3c"); t.R(4, 17, 20, 1, "#5aa868")
        t.R(5, 29, 18, 3, "#2f6b3c"); t.R(5, 29, 18, 1, "#5aa868"); t.R(5, 31, 18, 1, "#1c3a22"); t.R(6, 32, 16, 1, "#0e0d14"); t.R(8, 33, 12, 1, "#07060c")
        trash = t.image()
        var b = PixelCanvas(12, 12)
        b.R(0, 0, 12, 12, "#c08a24")
        for i in 0..<12 { b.P(i, 0, "#0e0d14"); b.P(i, 11, "#0e0d14"); b.P(0, i, "#0e0d14"); b.P(11, i, "#0e0d14"); b.P(i, 1, "#f6cb4c"); b.P(1, i, "#f6cb4c"); b.P(i, 10, "#8a5a14"); b.P(10, i, "#8a5a14") }
        b.P(1, 1, "#ffe7a8")
        btn = b.image()
        var pl = PixelCanvas(12, 12)
        pl.R(0, 0, 12, 12, "#1a1530")
        for i in 0..<12 { pl.P(i, 0, "#0e0d14"); pl.P(i, 11, "#0e0d14"); pl.P(0, i, "#0e0d14"); pl.P(11, i, "#0e0d14"); pl.P(i, 1, "#3a3360"); pl.P(1, i, "#3a3360"); pl.P(i, 10, "#110d20"); pl.P(10, i, "#110d20") }
        for (x, y) in [(2, 2), (9, 2), (2, 9), (9, 9)] { pl.P(x, y, "#5a4b9a") }
        plate = pl.image()
        var tk = PixelCanvas(12, 12)
        for y in 0..<12 { for x in 0..<12 { let d = hypot(Double(x) - 5.5, Double(y) - 5.5); if d < 5.6 { tk.P(x, y, d > 4.6 ? "#8a5a14" : d > 3.6 ? "#f6cb4c" : "#c08a24") } } }
        for (x, y) in [(4, 3), (5, 4), (7, 3), (6, 4), (5, 5), (6, 5), (5, 6), (6, 6), (5, 7), (6, 7)] { tk.P(x, y, "#3a2414") }
        tk.P(3, 2, "#ffe7a8")
        token = tk.image()
        var lk = PixelCanvas(10, 12)
        for i in 2..<8 { lk.P(i, 0, "#8d877b") }
        for i in 1..<5 { lk.P(1, i, "#8d877b"); lk.P(8, i, "#4d4943") }
        lk.R(0, 5, 10, 7, "#c08a24"); lk.R(0, 5, 10, 1, "#f6cb4c"); lk.R(4, 7, 2, 3, "#3a2414"); lk.R(0, 11, 10, 1, "#8a5a14")
        lock = lk.image()
    }
}
#endif
