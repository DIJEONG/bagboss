import Foundation
import CoreText
import CoreGraphics
import BBContent

// HUD 글자(웹 uiCx.font · fillText · strokeText · measureText) — CoreText 로 재고 굽는다.
//  · 갈무리(Galmuri11 · Galmuri9): 도트 글꼴이라 안티에일리어싱 끔(장치 배율 = UI 3배 × 변환 배율)
//  · 만화 효과음(웹 'italic 900 14px Impact'): 앱은 Anton(web/app/fonts.css 와 같은 대체) — 기울임 · 굵게는 합성
//    (크롬과 같은 방식: 기울임 = x 기울기 1/4, 굵게 = 크기 비례 외곽선 덧칠). 한글은 갈무리11로 대체
// 그림은 흰색 + 알파(곧은) — 색은 정점이 곱한다.

public struct HUDFont: Sendable, Hashable {
    public enum Face: String, Sendable { case galmuri11, galmuri11Bold, galmuri9, anton }
    public var face: Face
    public var size: Double
    public var italic = false, synthBold = false
    public init(face: Face, size: Double, italic: Bool = false, synthBold: Bool = false) { self.face = face; self.size = size; self.italic = italic; self.synthBold = synthBold }
    public static func galmuri11(_ s: Double, bold: Bool = false) -> HUDFont { HUDFont(face: bold ? .galmuri11Bold : .galmuri11, size: s) }
    public static func galmuri9(_ s: Double) -> HUDFont { HUDFont(face: .galmuri9, size: s) }
    /// 웹 'italic 900 Npx Impact,…'
    public static func comic(_ s: Double) -> HUDFont { HUDFont(face: .anton, size: s, italic: true, synthBold: true) }
    var antialias: Bool { face == .anton }
    var key: String { "\(face.rawValue)|\(size)|\(italic ? 1 : 0)\(synthBold ? 1 : 0)" }
}

public final class HUDText: @unchecked Sendable {
    public static let shared = HUDText()
    public struct Metrics: Sendable { public var ascent: Double, descent: Double }
    public struct RasterKey: Sendable, Hashable {
        public var text: String, font: HUDFont, deviceScale: Double, stroke: Double?
        var key: String { "t|\(font.key)|\(deviceScale)|\(stroke.map { String($0) } ?? "f")|\(text)" }
    }
    public struct Glyphs: Sendable { public var entry: OverlayAtlas.Entry; public var originX: Double, originY: Double }

    private let lock = NSLock()
    private var fonts: [String: CTFont] = [:]
    private var widths: [String: Double] = [:]
    private var origins: [String: (Double, Double)] = [:]

    init() { GameFonts.register() }

    private func ctFont(_ f: HUDFont, scale: Double = 1) -> CTFont {
        let k = "\(f.face.rawValue)|\(f.size * scale)"
        lock.lock(); defer { lock.unlock() }
        if let c = fonts[k] { return c }
        let name: String = switch f.face {
        case .galmuri11: GameFonts.ui
        case .galmuri11Bold: GameFonts.uiBold
        case .galmuri9: GameFonts.small
        case .anton: GameFonts.comic
        }
        // 대체 글꼴(웹 글꼴 목록 뒤쪽): 한글 → 갈무리
        let fb = f.face == .galmuri9 ? GameFonts.small : GameFonts.ui
        let cascade = [CTFontDescriptorCreateWithNameAndSize(fb as CFString, 0)] as CFArray
        let attrs = [kCTFontNameAttribute: name, kCTFontCascadeListAttribute: cascade] as [CFString: Any]
        let d = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
        let c = CTFontCreateWithFontDescriptor(d, CGFloat(f.size * scale), nil)
        fonts[k] = c
        return c
    }

    private func line(_ s: String, _ font: CTFont) -> CTLine {
        let a = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        return CTLineCreateWithAttributedString(a)
    }

    /// 웹 measureText(s).width (CSS 픽셀)
    public func measure(_ s: String, _ f: HUDFont) -> Double {
        let k = f.key + "|" + s
        lock.lock(); if let w = widths[k] { lock.unlock(); return w }; lock.unlock()
        let w = Double(CTLineGetTypographicBounds(line(s, ctFont(f)), nil, nil, nil))
        lock.lock(); widths[k] = w; lock.unlock()
        return w
    }

    public func metrics(_ f: HUDFont) -> Metrics {
        let c = ctFont(f)
        // 캔버스 textBaseline 'top' · 'middle' 은 em 칸 기준(크롬: 글꼴 ascent:descent 비율로 em 을 나눈다)
        let a = Double(CTFontGetAscent(c)), d = Double(CTFontGetDescent(c)), k = f.size / max(1e-6, a + d)
        return Metrics(ascent: a * k, descent: d * k)
    }

    /// 글자 그림(아틀라스 칸) — 원점 = 기준선 왼쪽이 그림 칸 안에서 어디인가(장치 픽셀, 위→아래)
    public func raster(_ k: RasterKey, atlas: OverlayAtlas) -> Glyphs? {
        let key = k.key
        var made: (Double, Double)?
        guard let e = atlas.entry(key, make: {
            guard let r = render(k) else { return nil }
            made = (r.ox, r.oy)
            return (r.w, r.h, r.rgba)
        }) else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let m = made { origins[key] = m }
        guard let o = origins[key] else { return nil }
        return Glyphs(entry: e, originX: o.0, originY: o.1)
    }

    private func render(_ k: RasterKey) -> (w: Int, h: Int, rgba: [UInt8], ox: Double, oy: Double)? {
        let ds = k.deviceScale, f = k.font
        let font = ctFont(f, scale: ds)
        let ln = line(k.text, font)
        var asc: CGFloat = 0, desc: CGFloat = 0
        let adv = Double(CTLineGetTypographicBounds(ln, &asc, &desc, nil))
        let sw = (k.stroke ?? 0) * ds
        let bold = f.synthBold ? f.size * ds * (f.size * ds <= 9 ? 1.0 / 24 : f.size * ds >= 36 ? 1.0 / 32 : (1.0 / 24 + (1.0 / 32 - 1.0 / 24) * (f.size * ds - 9) / 27)) : 0
        let skew = f.italic ? 0.25 : 0
        let pad = Int((sw / 2 + bold + 3).rounded(.up))
        let slant = Int((Double(asc) * skew).rounded(.up))
        let w = Int(adv.rounded(.up)) + pad * 2 + slant + 2
        let h = Int(Double(asc + desc).rounded(.up)) + pad * 2 + 2
        guard w > 0, h > 0, w < 2000, h < 2000 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.setShouldAntialias(f.antialias); ctx.setAllowsAntialiasing(f.antialias)
            ctx.setShouldSmoothFonts(false); ctx.setAllowsFontSmoothing(false)
            ctx.setShouldSubpixelPositionFonts(false); ctx.setShouldSubpixelQuantizeFonts(false)
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            // 기준선: 아래에서 pad + desc
            let baseY = CGFloat(pad) + desc + 1
            ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: CGFloat(skew), d: 1, tx: 0, ty: 0)
            ctx.textPosition = CGPoint(x: CGFloat(pad + 1), y: baseY)
            if k.stroke != nil {
                ctx.setTextDrawingMode(.stroke); ctx.setLineWidth(CGFloat(sw + bold * 2)); ctx.setLineJoin(.round)
            } else if bold > 0 {
                ctx.setTextDrawingMode(.fillStroke); ctx.setLineWidth(CGFloat(bold)); ctx.setLineJoin(.miter)
            } else { ctx.setTextDrawingMode(.fill) }
            CTLineDraw(ln, ctx)
            return true
        }
        guard ok else { return nil }
        // 미리 곱한 흰색 → 곧은 흰색(알파만)
        for i in stride(from: 0, to: buf.count, by: 4) { let a = buf[i + 3]; buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; buf[i + 3] = a }
        // CG 는 아래→위 — 그대로 두면 행 0 이 위(비트맵 메모리는 위 행부터)
        let ox = Double(pad + 1), oy = Double(h) - (Double(pad) + Double(desc) + 1)
        return (w, h, buf, ox, oy)
    }
}
