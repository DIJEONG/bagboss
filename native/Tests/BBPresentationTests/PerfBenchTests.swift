import Testing
import Foundation
import Metal
import BBCore
import BBContent
import BBSim
import BBPresentation
@testable import BBRender

/// 성능 기준선(docs/06 §8 '성능 · 시작 시간'). `BB_BENCH=1 swift test --filter PerfBenchTests` — 기본 실행에서는 건너뛴다.
///  · startup: 앱 GameSession/GameAssets 와 같은 순서로 준비 단계별 시간(ms)
///  · frames: 고정 씨앗 판 600프레임(화면 밖) — 틱 · 연출 · RenderFrame · HUD 목록 · 인코딩 CPU 시간(ms/프레임)
/// 릴리스로 재려면 `-c release` 를 붙인다(앱 시뮬레이터 빌드는 패키지가 Debug = -Onone 이다).
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["BB_BENCH"] == "1"))
struct PerfBenchTests {
    static func ms(_ t0: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6 }

    @Test("시작 단계별 시간") func startup() throws {
        var rows: [(String, Double)] = []
        func step<T>(_ name: String, _ f: () throws -> T) rethrows -> T {
            let t0 = DispatchTime.now().uptimeNanoseconds
            let v = try f(); rows.append((name, Self.ms(t0))); return v
        }
        let store = try step("ContentStore.bundled") { try ContentStore.bundled() }
        let data = try step("SimData") { try SimData(store: store) }
        let atlas = try step("AtlasMeta.bundled") { try AtlasMeta.bundled() }
        let scene = try step("SceneContent") { try SceneContent(store: store, atlas: atlas) }
        let director = try step("StageDirector") {
            try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
        }
        let art = try step("HUDArt") { try HUDArt(store: store) }
        director.hud.art = art
        let device = try #require(MTLCreateSystemDefaultDevice())
        let images = try step("(참고) 예전 NSData 아틀라스 풀기") { (try atlas.loadAtlasA(), try atlas.loadAtlasN(), try atlas.loadPalette()) }
        _ = images
        let lib = try step("Shaders.metal 실행 중 컴파일") { try FrameRenderer.makeLibrary(device) }
        _ = lib
        _ = try step("FrameRenderer 전체") { try FrameRenderer(device: device, atlas: atlas) }
        _ = try step("OverlayRenderer") { try OverlayRenderer(device: device) }
        var cfg = SimConfig(); cfg.skipTalks = true
        let sim = step("Sim 생성(새 판)") { Sim(data: data, seed: 2026, config: cfg) }
        let s = sim.snapshot
        _ = step("첫 StageDirector.frame") { director.frame(s, dt: 1.0 / 60, now: 0) }
        let total = rows.reduce(0) { $0 + $1.1 }
        print("[bench startup] " + rows.map { "\($0.0)=\(String(format: "%.1f", $0.1))" }.joined(separator: " · ") + " · 합 \(String(format: "%.0f", total))ms")
    }

    @Test("판 600프레임 CPU ms/프레임") func frames() throws {
        let store = try ContentStore.bundled(), data = try SimData(store: store), atlas = try AtlasMeta.bundled()
        let scene = try SceneContent(store: store, atlas: atlas)
        let art = try HUDArt(store: store)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: atlas), ov = try OverlayRenderer(device: device)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        // 1회차 = 차가운 공용 캐시(HUD 글자 · 컷인 그림 · 인물 모델) · 2회차 = 같은 판을 새 감독으로 다시(앱의 '데우기' 뒤 상태)
        for pass in 1...2 {
            let d = try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
            d.hud.art = art; d.hud.playSpeed = 1
            var ovTarget: OverlayRenderer.Target?
            var cfg = SimConfig(); cfg.skipTalks = true
            let sim = Sim(data: data, seed: 4242, config: cfg)
            var acc = (sim: 0.0, dir: 0.0, rf: 0.0, hud: 0.0, enc: 0.0)
            var worst = 0.0, worstK = 0, worstParts = [Double](repeating: 0, count: 5), slow: [String] = []
            let N = 600
            var lastCB: MTLCommandBuffer?
            for k in 0..<N {
                let intents = Self.intents(sim, k)
                let f0 = DispatchTime.now().uptimeNanoseconds
                var t0 = f0
                var parts = [Double](repeating: 0, count: 5)
                let ev = sim.step(intents), s = sim.snapshot
                parts[0] = Self.ms(t0); acc.sim += parts[0]; t0 = DispatchTime.now().uptimeNanoseconds
                _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                parts[1] = Self.ms(t0); acc.dir += parts[1]; t0 = DispatchTime.now().uptimeNanoseconds
                var rf = RenderFrame(stage: f, atlas: scene.sprites)
                rf.applyHUD(d.hud.state, now: s.time)
                parts[2] = Self.ms(t0); acc.rf += parts[2]; t0 = DispatchTime.now().uptimeNanoseconds
                let F = d.hud.frame(s, view: f.view, shake: f.shake)
                let list = HUDOverlay.build(d.hud.state, F, art: art)
                parts[3] = Self.ms(t0); acc.hud += parts[3]; t0 = DispatchTime.now().uptimeNanoseconds
                let cb = try #require(q.makeCommandBuffer())
                try fr.encode(rf, targets: tg, into: cb)
                if !list.isEmpty {
                    if ovTarget?.width != list.width || ovTarget?.height != list.height { ovTarget = try OverlayRenderer.Target(device: device, width: list.width, height: list.height) }
                    try ov.encode(list, atlas: art.atlas, target: ovTarget!, into: cb)
                }
                cb.commit()
                parts[4] = Self.ms(t0); acc.enc += parts[4]
                let tot = Self.ms(f0)
                if tot > worst { worst = tot; worstK = k; worstParts = parts }
                if tot > 8 { slow.append(String(format: "#%d %.1f", k, tot)) }
                lastCB?.waitUntilCompleted(); lastCB = cb
            }
            lastCB?.waitUntilCompleted()
            let n = Double(N)
            let tot = (acc.sim + acc.dir + acc.rf + acc.hud + acc.enc) / n
            print(String(format: "[bench frames %d회차] %d프레임 · 틱 %.3f · 연출 %.3f · RenderFrame %.3f · HUD 목록 %.3f · 인코딩 %.3f · 합 %.3f ms/프레임 · 최악 %.2f ms",
                         pass, N, acc.sim / n, acc.dir / n, acc.rf / n, acc.hud / n, acc.enc / n, tot, worst)
                  + String(format: " (#%d: 틱 %.1f · 연출 %.1f · RF %.1f · HUD %.1f · 인코딩 %.1f)", worstK, worstParts[0], worstParts[1], worstParts[2], worstParts[3], worstParts[4])
                  + " · 8ms 넘은 프레임 \(slow.count)개 \(slow.prefix(8).joined(separator: ", "))")
        }
    }

    /// 눈 승강장(docs/10) ↔ 같은 깃발의 보통 칸: 판 600프레임(새 배치 보이는 폭 198) — 틱 · 연출 · RenderFrame · 인코딩 CPU · 배경 정점 수
    @Test("눈 승강장 600프레임 CPU ms/프레임") func snowFrames() throws {
        let store = try ContentStore.bundled(), data = try SimData(store: store, nativeMoves: true), atlas = try AtlasMeta.bundled()
        let scene = try SceneContent(store: store, atlas: atlas)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: atlas)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        for (name, snow) in [("보통 칸(7호선 1호차)", false), ("눈 승강장", true), ("보통 칸(7호선 1호차)", false), ("눈 승강장", true)] {
            let d = try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
            d.hud.playSpeed = 1; d.camera.visibleWidth = 198
            var cfg = SimConfig(); cfg.skipTalks = true; cfg.nativeMoves = true; cfg.nativeSnow = snow; cfg.stage = 3; cfg.autoAdvance = true
            let sim = Sim(data: data, seed: 4242, config: cfg)
            for _ in 0..<30 { sim.step() }
            if snow { _ = sim.debugSnowJump() }
            for _ in 0..<(60 * 4) { sim.step() }   // 탑승 · 첫 웨이브
            var acc = (sim: 0.0, dir: 0.0, rf: 0.0, enc: 0.0), worst = 0.0, verts = 0
            let N = 600
            var lastCB: MTLCommandBuffer?
            for k in 0..<N {
                let f0 = DispatchTime.now().uptimeNanoseconds
                var t0 = f0
                let ev = sim.step(Self.intents(sim, k)), s = sim.snapshot
                acc.sim += Self.ms(t0); t0 = DispatchTime.now().uptimeNanoseconds
                _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                acc.dir += Self.ms(t0); t0 = DispatchTime.now().uptimeNanoseconds
                var rf = RenderFrame(stage: f, atlas: scene.sprites)
                rf.applyHUD(d.hud.state, now: s.time)
                acc.rf += Self.ms(t0); t0 = DispatchTime.now().uptimeNanoseconds
                let cb = try #require(q.makeCommandBuffer())
                try fr.encode(rf, targets: tg, into: cb); cb.commit()
                acc.enc += Self.ms(t0)
                worst = max(worst, Self.ms(f0)); verts = max(verts, rf.meshVertices.count / 10)
                lastCB?.waitUntilCompleted(); lastCB = cb
            }
            lastCB?.waitUntilCompleted()
            let n = Double(N)
            print(String(format: "[bench snow] %@ · 틱 %.3f · 연출 %.3f · RenderFrame %.3f · 인코딩 %.3f · 합 %.3f ms/프레임 · 최악 %.2f ms · 3D 정점 최대 %d",
                         name, acc.sim / n, acc.dir / n, acc.rf / n, acc.enc / n, (acc.sim + acc.dir + acc.rf + acc.enc) / n, worst, verts))
        }
    }

    /// 벤치 · 앱 데우기와 같은 입력(30프레임마다 좌우 탭 · 300프레임마다 필살 · 매점 첫 카드 · 정리 출발)
    static func intents(_ sim: Sim, _ k: Int) -> [SimIntent] {
        var intents: [SimIntent] = []
        if sim.state == "shop" { intents = [.shopPick(0)] } else if sim.state == "arrange" { intents = [.advance] }
        if k % 30 == 0 { intents.append(.tap(side: k % 60 == 0 ? 1 : -1, at: sim.clock)) }
        if k % 300 == 0 { intents.append(.special) }
        return intents
    }
}
