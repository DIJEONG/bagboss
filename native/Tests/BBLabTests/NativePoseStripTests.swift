import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import BBRender
import BBAnim
import BBContent

/// 네이티브 동작(NativeMoves) 키 포즈 확인용 — 주인공 혼자 동작마다 한 줄씩, 게임 20fps 칸마다 한 장(BB_DUMP=1 일 때만).
/// 결과: tools/js/out/moves/poses.png (3배 최근접). 동작 강화(MotionStyle.on)를 켠 그림 — 앱과 같다.
@Suite struct NativePoseStripTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let rows: [[String]] = [
        ["nv_go", "walk", "nv_skid", "nv_skidEnd"], ["nv_step"],
        ["nv_drIn", "nv_drWL", "nv_drHL", "nv_drWR", "nv_drHR", "nv_drWL", "nv_drHLq", "nv_drWR", "nv_drHRq"], ["nv_drFin", "nv_drFinUp"],
        ["nv_flick"], ["nv_liver"], ["nv_cork"], ["upper"], ["nv_roll"],
    ]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_DUMP"] == "1"))
    func dumpPoses() throws {
        let store = try ContentStore.bundled(), tables = try AnimTables(store).withNativeMoves(), seqs = try SequenceTable(store).withNativeMoves()
        let def = try CharacterDef.load(store, "JW_HERO")
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
        var tmpl = try RenderFrame(webCapture: Data(contentsOf: Self.root.appending(path: "native/Tests/Fixtures/frames/subway/frame.json")))
        guard case .sprite(_, let bgCount, _) = tmpl.gbuffer.first else { Issue.record("배경 없음"); return }
        tmpl.spriteVertices = Array(tmpl.spriteVertices.prefix(bgCount * 9)); tmpl.shake = .zero
        let targets = try FrameRenderer.Targets(device: device, width: tmpl.width, height: tmpl.height)
        let q = try #require(device.makeCommandQueue())
        let box = (w: 76, h: 84, top: 140), S = 3, maxCols = 16
        var sheetRows: [[[UInt8]]] = []
        for row in Self.rows {
            var (A, pa) = def.instance(x: 170, y: 220, flip: false, isHero: true, sequences: seqs, tables: tables)
            var cells: [[UInt8]] = [], t = 10.0
            for anim in row {
                pa.set(anim, on: &A.actor, table: seqs, loop: tables.loop)
                let total = (seqs.steps(anim) ?? []).reduce(0) { $0 + min($1.length, 300) }
                let frames = max(1, Int((total / 50).rounded(.up)))   // 20fps 칸
                for k in 0..<frames {
                    for _ in 0..<3 {   // 1/60 × 3 = 한 칸
                        if anim == "walk" || anim == "nv_go" { A.actor.runU = t + 1; A.actor.gph = (A.actor.gph ?? 0) + 2.4 / 40 }
                        let rush = anim.hasPrefix("nv_dr") && !anim.hasPrefix("nv_drFin")   // 러시: 상체는 위빙 · 훅, 다리는 달린다(규칙의 legRun)
                        A.actor.legRun = rush; if rush { A.actor.gph = (A.actor.gph ?? 0) + 6.5 / 66 }
                        var w = MeshWriter(); A.emit(time: t, dt: 1.0 / 60, style: .on, tables: tables, into: &w); t += 1.0 / 60
                    }
                    var w = MeshWriter(); A.emit(time: t, dt: 0, style: .on, tables: tables, into: &w)
                    var f = tmpl; f.time = Float(t); f.meshVertices = w.floats
                    f.gbuffer = [GBufferDraw.sprite(first: 0, count: bgCount, shadow: false), GBufferDraw.mesh(first: 0, count: w.vertexCount)]
                    let cb = try #require(q.makeCommandBuffer()); try renderer.encode(f, targets: targets, into: cb); cb.commit(); cb.waitUntilCompleted()
                    let px = try renderer.readBack(targets.output(for: f), queue: q)
                    var c = [UInt8](repeating: 0, count: box.w * box.h * 4)
                    let x0 = Int(A.x) - box.w / 2
                    for y in 0..<box.h { let s0 = ((box.top + y) * tmpl.width + x0) * 4; c.replaceSubrange(y * box.w * 4..<(y + 1) * box.w * 4, with: px[s0..<s0 + box.w * 4]) }
                    cells.append(c)
                    pa.advance(&A.actor, table: seqs, loop: tables.loop)
                }
            }
            sheetRows.append(Array(cells.prefix(maxCols)))
        }
        let cols = sheetRows.map(\.count).max() ?? 1, cw = box.w * S + 4, chh = box.h * S + 4
        let W = cols * cw, H = sheetRows.count * chh
        var sheet = [UInt8](repeating: 18, count: W * H * 4)
        for (r, cells) in sheetRows.enumerated() { for (k, c) in cells.enumerated() {
            for y in 0..<box.h * S { for x in 0..<box.w * S {
                let s = ((y / S) * box.w + x / S) * 4, d = ((r * chh + y) * W + k * cw + x) * 4
                func lift(_ v: UInt8) -> UInt8 { UInt8(min(255, Double(v) * 2.4 + 6)) }   // 어두운 느와르 장면을 밝게(포즈 보기용)
                sheet[d] = lift(c[s]); sheet[d + 1] = lift(c[s + 1]); sheet[d + 2] = lift(c[s + 2]); sheet[d + 3] = 255
            } }
        } }
        let url = Self.root.appending(path: "tools/js/out/moves/poses.png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ctx = CGContext(data: &sheet, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[poses] \(sheetRows.map(\.count)) → \(url.path)")
    }
}
