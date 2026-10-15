import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
@testable import BBRender
import BBPresentation
import BBContent

/// HUD 오버레이(웹 #ui 캔버스) 대조: tools/js/extract/hud.mjs 가 찍은 순간마다 같은 입력(HUDState · HUDFrame)을
/// HUDOverlay.build → OverlayRenderer 로 그려 웹 픽셀과 비교한다. BB_DUMP=1 이면 tools/js/out/hud/native_<순간>.png · diff_<순간>.png.
///  · 도트(피해 숫자 · pxText · 칸 · 초상)는 픽셀 단위로 같아야 한다 — 'pixel' 순간은 잉크 픽셀 거의 전부 정확 일치
///  · 벡터(호 · 원 · 다각형)와 글자(갈무리 · Anton)는 안티에일리어싱이 달라 가장자리가 다르다 → 3×3 칸(장면 1픽셀) 평균으로 본다
@Suite(.serialized) struct HUDParityTests {
    static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/hud")
    static let dumpDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "tools/js/out/hud")
    nonisolated(unsafe) static var shared: (OverlayRenderer, MTLCommandQueue, HUDArt)?

    static func setup() throws -> (OverlayRenderer, MTLCommandQueue, HUDArt) {
        if let s = shared { return s }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let s = (try OverlayRenderer(device: device), try #require(device.makeCommandQueue()), try HUDArt(store: try ContentStore.bundled()))
        shared = s; return s
    }

    struct Stats: CustomStringConvertible {
        var ink = 0, exact = 0.0, near = 0.0, block = 0.0, blockMean = 0.0
        var description: String { String(format: "잉크 %d · 정확 %.2f%% · ±32 이내 %.2f%% · 3×3 칸 ±24 이내 %.2f%% · 칸 평균 차 %.2f", ink, exact * 100, near * 100, block * 100, blockMean) }
    }

    /// 미리 곱한 값으로 비교(투명 픽셀의 RGB 는 의미 없음)
    static func pm(_ p: [UInt8], _ i: Int) -> (Int, Int, Int, Int) {
        let a = Int(p[i + 3]); return (Int(p[i]) * a / 255, Int(p[i + 1]) * a / 255, Int(p[i + 2]) * a / 255, a)
    }
    static func compare(_ a: [UInt8], _ b: [UInt8], w: Int, h: Int) -> Stats {
        var s = Stats(); var ex = 0, nr = 0
        for i in stride(from: 0, to: a.count, by: 4) where a[i + 3] > 0 || b[i + 3] > 0 {
            s.ink += 1
            let x = pm(a, i), y = pm(b, i)
            let m = max(abs(x.0 - y.0), abs(x.1 - y.1), abs(x.2 - y.2), abs(x.3 - y.3))
            if m <= 1 { ex += 1 }; if m <= 32 { nr += 1 }
        }
        s.exact = Double(ex) / Double(max(1, s.ink)); s.near = Double(nr) / Double(max(1, s.ink))
        var blocks = 0, ok = 0, sum = 0.0
        for by in 0..<(h / 3) { for bx in 0..<(w / 3) {
            var sa = (0, 0, 0, 0), sb = (0, 0, 0, 0), any = false
            for dy in 0..<3 { for dx in 0..<3 {
                let i = ((by * 3 + dy) * w + bx * 3 + dx) * 4
                if a[i + 3] > 0 || b[i + 3] > 0 { any = true }
                let x = pm(a, i), y = pm(b, i)
                sa = (sa.0 + x.0, sa.1 + x.1, sa.2 + x.2, sa.3 + x.3); sb = (sb.0 + y.0, sb.1 + y.1, sb.2 + y.2, sb.3 + y.3)
            } }
            guard any else { continue }
            blocks += 1
            let m = Double(max(abs(sa.0 - sb.0), abs(sa.1 - sb.1), abs(sa.2 - sb.2), abs(sa.3 - sb.3))) / 9
            sum += m; if m <= 24 { ok += 1 }
        } }
        s.block = Double(ok) / Double(max(1, blocks)); s.blockMean = sum / Double(max(1, blocks))
        return s
    }

    static func dump(_ px: [UInt8], w: Int, h: Int, to url: URL) {
        var p = px
        // 곧은 → 미리 곱한(CG 저장용)
        for i in stride(from: 0, to: p.count, by: 4) { let a = Int(p[i + 3]); for c in 0..<3 { p[i + c] = UInt8(Int(p[i + c]) * a / 255) } }
        let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
    }
    static func diff(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var o = [UInt8](repeating: 0, count: a.count)
        for i in stride(from: 0, to: a.count, by: 4) {
            let x = pm(a, i), y = pm(b, i), m = max(abs(x.0 - y.0), abs(x.1 - y.1), abs(x.2 - y.2), abs(x.3 - y.3))
            let base = UInt8(max(a[i + 3], b[i + 3]) / 6)
            o[i] = m > 1 ? UInt8(min(255, 60 + m * 3)) : base; o[i + 1] = base; o[i + 2] = base; o[i + 3] = 255
        }
        return o
    }

    /// 순간 → (기준: 정확, ±32, 3×3 칸)
    static let moments: [String: (exact: Double, near: Double, block: Double)] = [
        // 측정(2026-10-09): pixel 99.92 / 100 / 100 · wipe 99.9 · 컷인 93~97 / 98.5~99.5 · 벡터 86.6 / 97 / 99.1 · 만화 86.8 / 97.2 / 97.7
        "pixel": (0.995, 0.999, 0.999), "wipe": (0.995, 0.995, 0.995), "wipe_open": (0.99, 0.99, 0.995),
        "combo": (0.92, 0.96, 0.95), "crit": (0.95, 0.97, 0.97), "boss": (0.94, 0.95, 0.94), "bubbles": (0.95, 0.97, 0.97),
        "comic": (0.83, 0.95, 0.95), "vectors": (0.83, 0.95, 0.97),
        "cut_spc": (0.91, 0.97, 0.97), "cut_spc_in": (0.92, 0.97, 0.97), "cut_vs": (0.91, 0.97, 0.97), "cut_rage": (0.95, 0.98, 0.98),
    ]

    @Test(arguments: moments.keys.sorted())
    func momentMatchesWeb(name: String) throws {
        let url = Self.fixtures.appending(path: "\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { Issue.record("픽스처 없음: \(name) — node tools/js/extract/hud.mjs"); return }
        let cap = try HUDCapture(json: Data(contentsOf: url))
        let web = [UInt8](try (Data(contentsOf: Self.fixtures.appending(path: "\(name).rgba.deflate")) as NSData).decompressed(using: .zlib) as Data)
        let (r, q, art) = try Self.setup()
        let list = HUDOverlay.build(cap.state, cap.frame, art: art)
        #expect(list.width == cap.width && list.height == cap.height)
        let mine = try r.render(list, atlas: art.atlas, queue: q)
        #expect(mine.count == web.count)
        guard mine.count == web.count else { return }
        let s = Self.compare(mine, web, w: cap.width, h: cap.height)
        print("[HUD \(name)] \(s) · 정점 \(list.vertexCount) · 묶음 \(list.batches.count)")
        if ProcessInfo.processInfo.environment["BB_DUMP"] == "1" {
            Self.dump(mine, w: cap.width, h: cap.height, to: Self.dumpDir.appending(path: "native_\(name).png"))
            try? Data(mine).write(to: Self.dumpDir.appending(path: "native_\(name).rgba"))
            Self.dump(Self.diff(mine, web), w: cap.width, h: cap.height, to: Self.dumpDir.appending(path: "diff_\(name).png"))
        }
        if let probe = ProcessInfo.processInfo.environment["BB_HUD_PROBE"], probe == name {
            var n = 0
            for i in stride(from: 0, to: mine.count, by: 4) {
                let x = Self.pm(mine, i), y = Self.pm(web, i)
                if max(abs(x.0 - y.0), abs(x.1 - y.1), abs(x.2 - y.2), abs(x.3 - y.3)) > 32 && n < 60 {
                    n += 1; print("  (\((i / 4) % cap.width),\((i / 4) / cap.width)) 나 \(Array(mine[i..<i + 4])) 웹 \(Array(web[i..<i + 4]))")
                }
            }
        }
        let want = Self.moments[name]!
        #expect(s.exact >= want.exact, "정확 \(s.exact)")
        #expect(s.near >= want.near, "±32 \(s.near)")
        #expect(s.block >= want.block, "3×3 \(s.block)")
    }
}
