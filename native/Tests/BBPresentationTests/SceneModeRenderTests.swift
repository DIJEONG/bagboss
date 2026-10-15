import Foundation
import Testing
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import BBCore
import BBContent
import BBSim
@testable import BBPresentation
@testable import BBRender

// N5 장면(brawl · 복도 · 무도장) 눈으로 보기 + 연결 점검:
//  ① 웹 픽스처 입력 → 장면 구성 → Metal 렌더(배경 · 소품 · 3D 차 · 앞 차 · 광원 · 후처리) — 그림이 비지 않는지
//  ② 실제 시뮬레이션(보너스 · 프롤로그 복도 · 무도장 · 건널목) → StageDirector(SceneInputBuilder) → RenderFrame → Metal — 갈래가 열리고(unported 없음) 그려지는지
// BB_DUMP=1 이면 PNG 를 BB_SCENE_DUMP(기본 tools/js/out/scenes)에 쓴다.

private let modeDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/scenes/modes")
private let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private struct RenderInput: Decodable { let render: R; struct R: Decodable { let input: SceneInput; let random: Double } }

@Suite("N5 장면 렌더(눈으로 보기)", .serialized) struct SceneModeRenderTests {
    static let content: SceneContent = try! SceneContent.bundled()
    static let data: SimData = try! SimData.bundled()
    static var dumpDir: URL {
        if let p = ProcessInfo.processInfo.environment["BB_SCENE_DUMP"] { return URL(filePath: p) }
        return repoRoot.appending(path: "tools/js/out/scenes")
    }
    static var dump: Bool { ProcessInfo.processInfo.environment["BB_DUMP"] == "1" }

    /// RenderFrame → Metal → 후처리 결과 RGBA(480×270)
    static func render(_ rf: RenderFrame) throws -> [UInt8] {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let r = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
        let t = try FrameRenderer.Targets(device: device, width: rf.width, height: rf.height)
        let q = try #require(device.makeCommandQueue()), cb = try #require(q.makeCommandBuffer())
        try r.encode(rf, targets: t, into: cb); cb.commit(); cb.waitUntilCompleted()
        #expect(cb.error == nil)
        return try r.readBack(t.output(for: rf), queue: q)
    }
    static func png(_ px: [UInt8], w: Int = 480, h: Int = 270, name: String) {
        guard dump else { return }
        var p = px; for i in stride(from: 3, to: p.count, by: 4) { p[i] = 255 }
        let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let url = dumpDir.appending(path: name + ".png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
    }
    /// 밝기 평균(0..255)
    static func mean(_ px: [UInt8]) -> Double {
        var s = 0; for i in stride(from: 0, to: px.count, by: 4) { s += Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) }
        return Double(s) / Double(px.count / 4 * 3)
    }

    /// 장면 구성만으로 RenderFrame(인물 없음)
    static func frame(_ S: SceneFrame, input I: SceneInput) -> RenderFrame {
        var comp = CompositeParams(); comp.apply(S.lighting, shake: I.shake)
        var rf = RenderFrame(width: 480, height: 270, time: Float(I.time), composite: comp,
                             post: S.unported == nil ? PostParams(scene: S.post, impactInvert: I.impactInvert, shake: I.shake) : nil, blit: BlitParams(visibleWidth: 480))
        rf.applyScene(S)
        var b = SpriteBatch()
        b.append(S.background, atlas: content.sprites); let n0 = b.vertexCount
        b.append(S.mid, atlas: content.sprites); let n1 = b.vertexCount
        b.append(S.front + S.top, atlas: content.sprites); let n2 = b.vertexCount
        rf.spriteVertices = b.vertices; rf.meshVertices = S.mesh
        var g: [GBufferDraw] = [.sprite(first: 0, count: n0, shadow: false)]
        if n1 > n0 { g.append(.sprite(first: n0, count: n1 - n0, shadow: false)) }
        if !S.mesh.isEmpty { g.append(.mesh(first: 0, count: S.mesh.count / 10)) }
        if n2 > n1 { g.append(.sprite(first: n1, count: n2 - n1, shadow: false)) }
        rf.gbuffer = g
        return rf
    }

    @Test("웹 픽스처 입력 → 장면 렌더") func fixtures() throws {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: modeDir.path())) ?? []).filter { $0.hasSuffix(".json") }.sorted()
        #expect(!names.isEmpty)
        for n in names {
            let R = try JSONDecoder().decode(RenderInput.self, from: Data(contentsOf: modeDir.appending(path: n))).render
            var rng = ConstantRandom(R.random)
            let S = SceneComposer.compose(R.input, content: Self.content, rng: &rng)
            #expect(S.unported == nil)
            let px = try Self.render(Self.frame(S, input: R.input))
            let m = Self.mean(px)
            #expect(m > 6, Comment(rawValue: "\(n): 너무 어둡다(평균 \(m))"))
            Self.png(px, name: "fixture_" + n.replacingOccurrences(of: ".json", with: ""))
        }
    }

    /// 시뮬레이션을 돌리며 StageDirector 로 프레임을 만든다 — at 초마다 그림
    static func play(_ name: String, config: SimConfig, seconds: Double, shots: [Double], intents: (Int, Sim) -> [SimIntent] = { _, _ in [] },
                     check: (StageFrame, SimSnapshot) -> Void) throws {
        let store = try ContentStore.bundled()
        let d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
        let sim = Sim(data: data, seed: 2026, config: config)
        var next = shots
        for k in 0..<Int(seconds * 60) {
            let ev = sim.step(intents(k, sim))
            let s = sim.snapshot
            _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            check(f, s)
            if let t = next.first, Double(k) / 60 >= t {
                next.removeFirst()
                var rf = RenderFrame(stage: f, atlas: content.sprites)
                rf.applyScene(f.scene)
                let px = try render(rf)
                #expect(mean(px) > 6, Comment(rawValue: "\(name) \(t)초: 너무 어둡다"))
                png(px, name: "\(name)_\(String(format: "%04.1f", t))")
            }
        }
    }

    @Test("보너스: 시뮬레이션 → 감독 → 렌더(차 3D · 연기 · 앞 차)") func bonus() throws {
        var c = SimConfig(); c.mode = .bonus
        var meshMax = 0, puffs = 0, brawl = 0, dent = 0
        try Self.play("bonus", config: c, seconds: 26, shots: [1.5, 8, 14, 20, 25.5], intents: { k, _ in k % 20 == 0 ? [.tap(side: 1, at: Double(k) / 60)] : [] }) { f, s in
            guard let B = s.bonus else { return }
            #expect(f.scene.unported == nil)
            brawl += f.scene.windowLight == 1 ? 1 : 0
            meshMax = max(meshMax, f.scene.mesh.count / 10)
            puffs = max(puffs, f.scene.mid.filter { $0.name.hasPrefix("pf_") }.count)
            dent = max(dent, B.car.dentN)
        }
        #expect(brawl > 0)
        #expect(meshMax > 1000, "차 3D 정점")
        _ = puffs; _ = dent
    }

    @Test("프롤로그 복도: 시뮬레이션 → 감독 → 렌더") func corridor() throws {
        var c = SimConfig(); c.prologue = true
        var seen = 0
        try Self.play("corridor", config: c, seconds: 12, shots: [2, 6, 11.5]) { f, s in
            guard s.prologue != nil, s.cine == nil else { return }
            seen += 1
            #expect(f.scene.unported == nil)
            #expect(f.scene.background.contains { $0.name == "cr_wall2" })
        }
        #expect(seen > 0, "프롤로그가 시작되지 않음(SimConfig.prologue)")
    }

    @Test("무도장 · 건널목: 시뮬레이션 → 감독 → 렌더") func dojo() throws {
        var c = SimConfig(); c.mode = .dojo
        var room = 0, cross = 0
        try Self.play("dojo", config: c, seconds: 20, shots: [2, 12, 16, 19.5], intents: { k, _ in k == 6 * 60 ? [.dojo(.background("cross"))] : k == 60 ? [.dojo(.combo(0))] : [] }) { f, s in
            guard s.demo, s.dojo != nil else { return }
            #expect(f.scene.unported == nil)
            if f.scene.background.contains(where: { $0.name == "dj_out" }) { room += 1 }
            if f.scene.background.contains(where: { $0.name == "xc_sky" }) { cross += 1 }
        }
        #expect(room > 0)
        #expect(cross > 0)
    }
}
