import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
@testable import BBRender
import BBContent

/// 웹 캡처 프레임(Tests/Fixtures/frames)을 같은 입력으로 그려 단계별 픽셀을 비교한다.
/// BB_DUMP=1 이면 네이티브 결과 · 차이 그림을 tools/js/out/frames/<장면>/ 에 쓴다.
@Suite(.serialized) struct WebParityTests {
    static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/frames")
    static let dumpDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "tools/js/out/frames")

    struct Stats: CustomStringConvertible {
        var exact = 0.0, near = 0.0, step = 0.0, maxDiff = 0, mean = 0.0
        var description: String { String(format: "일치 %.2f%% · ±2 이내 %.2f%% · 한 단(±11) 이내 %.2f%% · 최대 차 %d · 평균 %.3f", exact * 100, near * 100, step * 100, maxDiff, mean) }
    }

    static func compare(_ a: [UInt8], _ b: [UInt8], rgbOnly: Bool) -> Stats {
        precondition(a.count == b.count)
        var s = Stats(); var exact = 0, near = 0, step = 0, sum = 0
        let n = a.count / 4
        for i in 0..<n {
            var m = 0
            for c in 0..<(rgbOnly ? 3 : 4) { let d = abs(Int(a[i * 4 + c]) - Int(b[i * 4 + c])); m = max(m, d); sum += d }
            if m == 0 { exact += 1 }; if m <= 2 { near += 1 }; if m <= 11 { step += 1 }; s.maxDiff = max(s.maxDiff, m)
        }
        s.exact = Double(exact) / Double(n); s.near = Double(near) / Double(n); s.step = Double(step) / Double(n); s.mean = Double(sum) / Double(n * (rgbOnly ? 3 : 4))
        return s
    }

    static func loadWeb(_ scene: String, _ stage: String) throws -> [UInt8] {
        let d = try Data(contentsOf: fixtures.appending(path: "\(scene)/\(stage).rgba.deflate"))
        return [UInt8](try (d as NSData).decompressed(using: .zlib) as Data)
    }

    static func dump(_ px: [UInt8], w: Int, h: Int, to url: URL, opaque: Bool = true) {
        var p = px; if opaque { for i in stride(from: 3, to: p.count, by: 4) { p[i] = 255 } }
        let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
    }
    static func diffImage(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var o = [UInt8](repeating: 0, count: a.count)
        for i in stride(from: 0, to: a.count, by: 4) {
            let m = (0..<3).map { abs(Int(a[i + $0]) - Int(b[i + $0])) }.max()!
            o[i] = UInt8(min(255, m * 8)); o[i + 1] = m == 0 ? 0 : 40; o[i + 2] = 0; o[i + 3] = 255
        }
        return o
    }

    @Test(arguments: ["subway", "tower"])
    func stagesMatchWeb(scene: String) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let frame = try RenderFrame(webCapture: Data(contentsOf: Self.fixtures.appending(path: "\(scene)/frame.json")))
        let r = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
        let t = try FrameRenderer.Targets(device: device, width: frame.width, height: frame.height)
        let q = try #require(device.makeCommandQueue()), cb = try #require(q.makeCommandBuffer())
        try r.encode(frame, targets: t, into: cb); cb.commit(); cb.waitUntilCompleted()
        #expect(cb.error == nil)

        let dump = ProcessInfo.processInfo.environment["BB_DUMP"] == "1"
        var results: [(String, Stats)] = []
        for (stage, tex, rgbOnly) in [("gInfo", t.gInfo, false), ("gNorm", t.gNorm, false), ("comp", t.comp, true), ("bloom", t.bloomA, true), ("post", t.post, true)] {
            let web = try Self.loadWeb(scene, stage), mine = try r.readBack(tex, queue: q)
            let s = Self.compare(mine, web, rgbOnly: rgbOnly); results.append((stage, s))
            if ProcessInfo.processInfo.environment["BB_CHANNELS"] == "1" {
                var bad = [0, 0, 0, 0], ex: [String] = []
                for i in stride(from: 0, to: mine.count, by: 4) { for c in 0..<4 where abs(Int(mine[i + c]) - Int(web[i + c])) > 2 {
                    bad[c] += 1; if ex.count < 6 { ex.append("(\((i / 4) % tex.width),\((i / 4) / tex.width)) c\(c) 나 \(Array(mine[i..<i+4])) 웹 \(Array(web[i..<i+4]))") } } }
                print("[\(scene)] \(stage) 채널별 >2: \(bad) 예: \(ex.joined(separator: " | "))")
            }
            if dump {
                Self.dump(mine, w: tex.width, h: tex.height, to: Self.dumpDir.appending(path: "\(scene)/native_\(stage).png"))
                Self.dump(Self.diffImage(mine, web), w: tex.width, h: tex.height, to: Self.dumpDir.appending(path: "\(scene)/diff_\(stage).png"))
            }
        }
        for (k, s) in results { print("[\(scene)] \(k): \(s)") }
        let by = Dictionary(uniqueKeysWithValues: results)
        // 기준(2026-10-09 측정치 바로 아래 — 떨어지면 셰이더 이식이 어긋난 것):
        // · G-버퍼: 값 변환뿐 → ±2 이내 거의 전부. 남는 0.05% 는 3D 삼각형 가장자리 래스터화 규칙 차이(SwiftShader ↔ Apple GPU)
        // · 합성: 조명 · 디더 계산 — G-버퍼 가장자리 차이가 번져 나온 것만 남는다
        // · 후처리: 마지막에 24단 양자화 → 부동소수 끝자리 차이로 경계에서 한 단(≈11)씩 넘어간다 — 한 단 이내로 본다.
        //   '일치'가 60~75% 인 것은 오차가 아니다: 4/24·255 = 42.5 동률을 SwiftShader 는 42, Apple GPU 는 43 으로 반올림한다(1 차이는 전부 이 한 쌍).
        #expect(by["gInfo"]!.near > 0.999, "gInfo \(by["gInfo"]!)")
        #expect(by["gNorm"]!.near > 0.998, "gNorm \(by["gNorm"]!)")
        #expect(by["comp"]!.near > 0.998, "comp \(by["comp"]!)")
        #expect(by["bloom"]!.near > 0.999, "bloom \(by["bloom"]!)")
        #expect(by["post"]!.step > 0.998, "post \(by["post"]!)")
    }
}
