import Testing
import Foundation
import Metal
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 모드 HUD 를 실제 판으로(Swift BBSim → StageDirector/HUDDirector → HUDOverlay → OverlayRenderer):
/// 타워 · 보너스 · 무도장 · 프롤로그 복도 · 거리 연출에서 HUDFrame.modes 가 채워지고 오버레이가 그려지는지,
/// 거리 연출(brawl charOX)에서 인물 기준 자리가 화면 안으로 밀리는지 본다. BB_DUMP=1 → tools/js/out/hud/live_mode_<모드>.png(장면 + HUD)
@Suite(.serialized) struct ModeHUDLiveTests {
    static let data = try! SimData.bundled()

    func run(_ name: String, sim: Sim, seconds: Double, taps: Bool = true, check: (HUDFrame, SimSnapshot) -> Void) throws {
        let store = try ContentStore.bundled(), content = try SceneContent.bundled()
        let d = try StageDirector(content: content, store: store, tables: Self.data.animTables, catalog: HUDCatalog(Self.data), heavyReactions: Self.data.heavyRK)
        let art = try HUDArt(store: store)
        d.hud.art = art; d.hud.playSpeed = 1
        var f: StageFrame?
        for k in 0..<Int(seconds * 60) {
            var intents: [SimIntent] = []
            if sim.state == "shop" { intents = [.shopPick(0)] } else if sim.state == "arrange" { intents = [.advance] }
            if taps && k % 30 == 0 { intents.append(.tap(side: 1, at: sim.clock)) }
            let ev = sim.step(intents)
            _ = d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60)
            f = d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60)
        }
        let s = sim.snapshot, fr = try #require(f)
        let F = d.hud.frame(s, view: fr.view, shake: fr.shake)
        check(F, s)
        let list = HUDOverlay.build(d.hud.state, F, art: art)
        #expect(list.vertexCount > 0)
        if ProcessInfo.processInfo.environment["BB_DUMP"] == "1" {
            let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
            let frr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()), ov = try OverlayRenderer(device: device)
            let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
            var rf = RenderFrame(stage: fr, atlas: content.sprites); rf.applyHUD(d.hud.state, now: s.time)
            let cb = try #require(q.makeCommandBuffer()); try frr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
            let scene = try frr.readBack(tg.output(for: rf), queue: q), ui = try ov.render(list, atlas: art.atlas, queue: q)
            HUDLiveTests.write(scene: scene, ui: ui, view: fr.view, w: list.width, h: list.height, to: HUDLiveTests.out.appending(path: "live_mode_\(name).png"))
        }
    }

    @Test func tower() throws {
        var c = SimConfig(); c.mode = .tower; c.skipTalks = true
        try run("tower", sim: Sim(data: Self.data, seed: 7, config: c), seconds: 9) { F, s in
            #expect(F.modes?.tower?.floor == s.tower?.floor && F.modes?.tower?.name.isEmpty == false)
        }
    }
    @Test func bonus() throws {
        var c = SimConfig(); c.mode = .bonus; c.skipTalks = true
        try run("bonus", sim: Sim(data: Self.data, seed: 8, config: c), seconds: 6) { F, s in
            #expect(F.modes?.bonus != nil && F.modes?.bonus?.score == s.bonus?.score)
        }
    }
    @Test func dojo() throws {
        var c = SimConfig(); c.mode = .dojo; c.skipTalks = true
        let sim = Sim(data: Self.data, seed: 9, config: c)
        sim.apply(.dojo(.combo(2)))
        try run("dojo", sim: sim, seconds: 3) { F, _ in
            #expect(F.modes?.dojo?.rows.count == 3)
            #expect(F.modes?.dojo?.rows.first?[1].hasSuffix("f") == true)
        }
    }
    @Test func corridor() throws {
        var c = SimConfig(); c.prologue = true; c.skipTalks = true
        try run("corridor", sim: Sim(data: Self.data, seed: 10, config: c), seconds: 4) { F, s in
            #expect(s.prologue != nil && F.modes?.corridor != nil)
            #expect(F.lbox > 0.9)   // 웹 47: GS.prologue 면 레터박스
        }
    }
    @Test func cine() throws {
        var c = SimConfig(); c.prologue = true; c.skipTalks = true
        let sim = Sim(data: Self.data, seed: 31, config: c)
        sim.w.pr!.x = sim.w.sd.corrLen; sim.w.pr!.wi = 99; sim.w.ents = [sim.w.hero]; sim.w.hero.x = 400   // 웹 jumpTo('cine')
        var t = 0
        while sim.snapshot.cine == nil && t < 600 { sim.step(); t += 1 }
        try run("cine", sim: sim, seconds: 1.6, taps: false) { F, s in
            #expect(F.modes?.cine != nil)
            let H = s.actors.first { $0.isHero }!
            #expect(s.hudCharOX < 0, "거리 카메라가 움직였다")
            #expect(F.heroX == H.x + s.hudCharOX)
            #expect(abs((F.heroX ?? 0) - F.camX - F.vw / 2) < F.vw, "말풍선 · 숫자 기준이 화면 안")
        }
    }
}
