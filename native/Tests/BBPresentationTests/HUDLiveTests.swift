import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import BBCore
import BBContent
import BBSim
import BBPresentation
@testable import BBRender

/// 실제 판(Swift BBSim) 이벤트 → StageDirector/HUDDirector → HUDOverlay → OverlayRenderer 까지 한 줄로 돌린다.
/// 앱과 같은 경로(장면 렌더 + 후처리 충격파 + 오버레이)를 화면 밖에서. BB_DUMP=1 이면 tools/js/out/hud/live_<n>.png(장면 ×3 최근접 + HUD).
@Suite(.serialized) struct HUDLiveTests {
    static let out = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "tools/js/out/hud")

    @Test("실제 판 25초: 피해 숫자 · HITFX · 만화 · 충격파가 나오고 오버레이가 그려진다") func liveRun() throws {
        let store = try ContentStore.bundled(), data = try SimData.bundled(), content = try SceneContent.bundled()
        let d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
        let art = try HUDArt(store: store)
        d.hud.art = art; d.hud.playSpeed = 1
        var cfg = SimConfig(); cfg.skipTalks = true
        let sim = Sim(data: data, seed: 4242, config: cfg)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()), ov = try OverlayRenderer(device: device)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        var maxPops = 0, maxFx = 0, sw = 0, kinds = Set<String>(), dumped = 0, verts = 0
        let dump = ProcessInfo.processInfo.environment["BB_DUMP"] == "1"
        for k in 0..<(25 * 60) {
            var intents: [SimIntent] = []
            if sim.state == "shop" { intents = [.shopPick(0)] } else if sim.state == "arrange" { intents = [.advance] }
            if k % 30 == 0 { intents.append(.tap(side: k % 60 == 0 ? 1 : -1, at: sim.clock)) }
            if k % 300 == 0 { intents.append(.special) }
            let ev = sim.step(intents), s = sim.snapshot
            _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            let H = d.hud.state
            maxPops = max(maxPops, H.pops.count); maxFx = max(maxFx, H.hitFx.count); sw = max(sw, H.shockwaves.count)
            kinds.formUnion(H.hitFx.map(\.k))
            let interesting = H.pops.count >= 2 && H.hitFx.count >= 4 || H.cut != nil && (H.cut!.t > 0.5)
            if k % 20 == 0 || (interesting && dumped < 6 && k % 7 == 0) {
                var rf = RenderFrame(stage: f, atlas: content.sprites)
                rf.applyHUD(H, now: s.time)
                let F = d.hud.frame(s, view: f.view, shake: f.shake)
                let list = HUDOverlay.build(H, F, art: art)
                verts = max(verts, list.vertexCount)
                if interesting && dumped < 6 {
                    dumped += 1
                    let ui = try ov.render(list, atlas: art.atlas, queue: q)
                    #expect(ui.count == list.width * list.height * 4)
                    if dump {
                        let cb = try #require(q.makeCommandBuffer()); try fr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
                        let scene = try fr.readBack(tg.output(for: rf), queue: q)
                        Self.write(scene: scene, ui: ui, view: f.view, w: list.width, h: list.height, to: Self.out.appending(path: "live_\(dumped).png"))
                    }
                }
            }
        }
        print("[HUD live] 숫자 최대 \(maxPops) · HITFX 최대 \(maxFx) · 충격파 \(sw) · 종류 \(kinds.sorted()) · 정점 최대 \(verts) · 저장 \(dumped)")
        #expect(maxPops > 0 && maxFx > 0)
        #expect(kinds.isSuperset(of: ["streak", "flash"]))
        #expect(dumped > 0)
    }

    /// 장면(480×270)을 보이는 폭만 잘라 ×3 최근접으로 + UI(곧은 RGBA) 얹기 — 웹 화면과 같은 겹침
    static func write(scene: [UInt8], ui: [UInt8], view: StageView, w: Int, h: Int, to url: URL) {
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let sx = min(479, Int(view.cameraX) + x / 3), sy = min(269, y / 3), si = (sy * 480 + sx) * 4, o = (y * w + x) * 4
            let a = Double(ui[o + 3]) / 255
            for c in 0..<3 { px[o + c] = UInt8(min(255, Double(scene[si + c]) * (1 - a) + Double(ui[o + c]) * a)) }
        } }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
    }
}
