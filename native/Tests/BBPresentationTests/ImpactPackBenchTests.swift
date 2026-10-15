import Testing
import Foundation
import Metal
import BBCore
import BBContent
import BBSim
@testable import BBPresentation
@testable import BBRender

/// 타격감 묶음 성능(docs/11 §성능): 보통 칸(7호선 1호차) 600프레임을 묶음 켬 · 끔으로 번갈아 3번씩 — CPU ms/프레임 차이.
/// `BB_BENCH=1 swift test -c release --filter ImpactPackBenchTests` (기본 실행에서는 건너뛴다)
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["BB_BENCH"] == "1"))
struct ImpactPackBenchTests {
    @Test func normalCar() throws {
        let store = try ContentStore.bundled(), data = try SimData(store: store, nativeMoves: true), atlas = try AtlasMeta.bundled()
        let scene = try SceneContent(store: store, atlas: atlas)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: atlas)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        var sums: [Bool: [Double]] = [true: [], false: []]
        for round in 0..<6 {
            let on = round % 2 == 0
            let d = try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
            d.hud.playSpeed = 1; d.camera.visibleWidth = 198; d.impactPack = on
            var cfg = SimConfig(); cfg.skipTalks = true; cfg.nativeMoves = true; cfg.stage = 3; cfg.autoAdvance = true
            let sim = Sim(data: data, seed: 4242, config: cfg)
            for _ in 0..<(60 * 4 + 30) { sim.step() }
            var acc = 0.0, peak = 0
            var lastCB: MTLCommandBuffer?
            let N = 600
            for k in 0..<N {
                let ev = sim.step(PerfBenchTests.intents(sim, k)), s = sim.snapshot
                if k % 120 == 0 { sim.debugLowFoes(6) }   // 웨이브를 자주 끝내 KO 마무리 · 열기도 들어가게
                let t0 = DispatchTime.now().uptimeNanoseconds
                _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                var rf = RenderFrame(stage: f, atlas: scene.sprites)
                rf.applyHUD(d.hud.state, now: s.time)
                let cb = try #require(q.makeCommandBuffer())
                try fr.encode(rf, targets: tg, into: cb); cb.commit()
                acc += PerfBenchTests.ms(t0)
                peak = max(peak, d.feel.dust.puffs.count + d.feel.embers.count)
                lastCB?.waitUntilCompleted(); lastCB = cb
            }
            lastCB?.waitUntilCompleted()
            sums[on]!.append(acc / Double(N))
            print(String(format: "[bench impact] %@ · 연출+RenderFrame+인코딩 %.3f ms/프레임 · 입자 최대 %d", on ? "켬" : "끔", acc / Double(N), peak))
        }
        let a = sums[true]!.sorted()[1], b = sums[false]!.sorted()[1]   // 가운뎃값
        print(String(format: "[bench impact] 켬 %.3f · 끔 %.3f · 차이 %+.3f ms/프레임", a, b, a - b))
    }
}
