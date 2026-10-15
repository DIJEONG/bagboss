import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import BBRender
import BBAnim
import BBContent

/// 동작 강화 확인용 연속 이미지(BB_DUMP=1 일 때만): 같은 동작을 왼쪽(강화 끔) · 오른쪽(강화 켬) 인물이 동시에 한다.
/// 결과: tools/js/out/motion/<이름>.png — 60fps 로 돌리고 일정 간격으로 잘라 붙인다.
@Suite struct MotionStripTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// 동작 대본: (시작 초, 동작) — walk 는 이동, launch 는 띄움(높이는 시퀀스 포즈가 가진다)
    static let script: [(Double, String)] = [(0, "idle"), (0.7, "walk"), (1.7, "kick"), (2.4, "hit"), (2.9, "upper"), (3.7, "launch"), (4.6, "jland"), (5.6, "idle")]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_DUMP"] == "1"))
    func dumpStrip() throws {
        let store = try ContentStore.bundled(), tables = try AnimTables(store), seqs = try SequenceTable(store)
        let def = try CharacterDef.load(store, "JW_HERO")
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
        var tmpl = try RenderFrame(webCapture: Data(contentsOf: Self.root.appending(path: "native/Tests/Fixtures/frames/subway/frame.json")))
        // 배경만 남긴다(첫 그리기 = 배경 스프라이트)
        guard case .sprite(_, let bgCount, _) = tmpl.gbuffer.first else { Issue.record("배경 없음"); return }
        tmpl.spriteVertices = Array(tmpl.spriteVertices.prefix(bgCount * 9)); tmpl.shake = .zero
        let targets = try FrameRenderer.Targets(device: device, width: tmpl.width, height: tmpl.height)
        let q = try #require(device.makeCommandQueue())

        var (A, pa) = def.instance(x: 170, y: 220, flip: false, isHero: true, sequences: seqs, tables: tables)
        var (B, pb) = def.instance(x: 170, y: 220, flip: false, isHero: true, sequences: seqs, tables: tables)
        let dt = 1.0 / 60, frames = Int(6.2 / dt)
        var animAcc = 0.0, nextCue = 0, shots: [([UInt8], String)] = [], diffs: [String: [Int]] = [:]
        let box = (w: 72, h: 84, top: 140)   // 인물 둘레(발 y=220 위로)
        let every = Int(ProcessInfo.processInfo.environment["BB_EVERY"] ?? "3") ?? 3
        for i in 0..<frames {
            let t = Double(i) * dt
            if nextCue < Self.script.count && t >= Self.script[nextCue].0 {
                let anim = Self.script[nextCue].1; nextCue += 1
                pa.set(anim, on: &A.actor, table: seqs, loop: tables.loop); pb.set(anim, on: &B.actor, table: seqs, loop: tables.loop)
            }
            if A.actor.anim == "walk" { let dx = 40 * dt; A.x += dx; B.x += dx; A.actor.gph = (A.actor.gph ?? 0) + dx / 28.8; B.actor.gph = (B.actor.gph ?? 0) + dx / 28.8 }
            animAcc += dt
            while animAcc >= 1.0 / 20 { animAcc -= 1.0 / 20; pa.advance(&A.actor, table: seqs, loop: tables.loop); pb.advance(&B.actor, table: seqs, loop: tables.loop) }
            // 같은 자리에서 끔 · 켬을 따로 그린다(배경이 같아야 차이만 보인다)
            var wa = MeshWriter(), wb = MeshWriter()
            A.emit(time: 10 + t, dt: dt, style: .off, tables: tables, into: &wa)
            B.emit(time: 10 + t, dt: dt, style: .on, tables: tables, into: &wb)
            guard i % every == 0 else { continue }
            var pair = [UInt8](repeating: 0, count: box.w * 2 * box.h * 4)
            for (k, w) in [wa, wb].enumerated() {
                var f = tmpl
                f.time = Float(10 + t)
                f.meshVertices = w.floats
                f.gbuffer = [GBufferDraw.sprite(first: 0, count: bgCount, shadow: false), GBufferDraw.mesh(first: 0, count: w.vertexCount)]
                let cb = try #require(q.makeCommandBuffer())
                try renderer.encode(f, targets: targets, into: cb); cb.commit(); cb.waitUntilCompleted()
                let px = try renderer.readBack(targets.output(for: f), queue: q)
                let x0 = max(0, min(tmpl.width - box.w, Int(A.x) - box.w / 2))
                for y in 0..<box.h { let s = ((box.top + y) * tmpl.width + x0) * 4, d = (y * box.w * 2 + k * box.w) * 4
                    pair.replaceSubrange(d..<d + box.w * 4, with: px[s..<s + box.w * 4]) }
            }
            do {
                shots.append((pair, A.actor.anim))
                var diff = 0
                for y in 0..<box.h { for x in 0..<box.w { let a = (y * box.w * 2 + x) * 4, b = a + box.w * 4
                    if abs(Int(pair[a]) - Int(pair[b])) + abs(Int(pair[a + 1]) - Int(pair[b + 1])) + abs(Int(pair[a + 2]) - Int(pair[b + 2])) > 24 { diff += 1 } } }
                diffs[A.actor.anim, default: []].append(diff)
            }
        }
        // 격자(4배): 칸마다 [강화 끔 | 강화 켬]
        let cols = 6, rows = (shots.count + cols - 1) / cols, S = 4, cw = box.w * 2, W = (cw * S + 8) * cols, H = (box.h * S + 8) * rows
        var sheet = [UInt8](repeating: 20, count: W * H * 4)
        for (k, (c, _)) in shots.enumerated() {
            let ox = (k % cols) * (cw * S + 8), oy = (k / cols) * (box.h * S + 8)
            for y in 0..<box.h * S { for x in 0..<cw * S {
                let s = ((y / S) * cw + x / S) * 4, d = ((oy + y) * W + ox + x) * 4
                let sep = (x / S) == box.w   // 가운데 구분선
                sheet[d] = sep ? 200 : c[s]; sheet[d + 1] = sep ? 60 : c[s + 1]; sheet[d + 2] = sep ? 60 : c[s + 2]; sheet[d + 3] = 255 } }
        }
        let name = ProcessInfo.processInfo.environment["BB_NAME"] ?? "strip"
        let url = Self.root.appending(path: "tools/js/out/motion/\(name).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ctx = CGContext(data: &sheet, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[motion] 끔↔켬 다른 픽셀(동작별 평균/최대): " + diffs.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.reduce(0, +) / $0.value.count)/\($0.value.max()!)" }.joined(separator: " · "))
        print("[motion] 동작 순서: \(shots.map(\.1).reduce(into: [String]()) { if $0.last != $1 { $0.append($1) } })")
        print("[motion] \(shots.count)장 → \(url.path)")
    }
}
