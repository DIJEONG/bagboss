import Foundation
import Metal
import QuartzCore
import BBCore
import BBContent
import BBSim
import BBPresentation
import BBRender
import BBAudio

// 앱 전체에서 한 번 만드는 무거운 준비물(docs/06 §8 '성능 · 시작 시간').
// 앱 init 에서 `GameAssets.shared.start()` → 뒤 스레드에서 병렬로 굽는다. 화면은 기다리지 않는다:
//   store(4ms) ─┬─ core: SimData ‖ SceneContent ‖ 파형표(소리) ‖ 조각 나누기 → FlowContent · StageDirector   → 타이틀(GameSession)
//               └─ render: FrameRenderer(아틀라스 풀기 A‖N ‖ 셰이더 묶음 → 파이프라인 7개 병렬) ‖ OverlayRenderer ‖ HUDArt
//                          → 화면 출력 · HUD 얹기 파이프라인 미리 만들기 → (core 와 함께) 데우기 프레임                 → '출발' 가능
// 타이틀은 core 만 기다린다. render 가 늦으면 출발 요청은 GameSession 이 붙잡아 두었다가 준비되면 바로 시작한다.

/// 타이틀에 필요한 데이터(읽기 전용 — 만든 뒤에는 메인에서만 쓴다)
final class GameCore: @unchecked Sendable {
    let store: ContentStore
    let data: SimData
    let atlas: AtlasMeta
    let sceneContent: SceneContent
    let flow: FlowContent
    /// 뒤에서 미리 만든 연출 감독(판마다 start() 가 상태를 비운다)
    let director: StageDirector

    init(store: ContentStore, data: SimData, atlas: AtlasMeta, sceneContent: SceneContent, flow: FlowContent, director: StageDirector) {
        self.store = store; self.data = data; self.atlas = atlas; self.sceneContent = sceneContent; self.flow = flow; self.director = director
    }
}

/// 판을 그리는 데 필요한 GPU 자원(만든 뒤에는 메인 — StageRenderer 에서만 쓴다)
final class GameRender: @unchecked Sendable {
    let device: MTLDevice
    let frame: FrameRenderer
    let overlay: OverlayRenderer
    let art: HUDArt
    let queue: MTLCommandQueue
    let targets: FrameRenderer.Targets

    init(device: MTLDevice, frame: FrameRenderer, overlay: OverlayRenderer, art: HUDArt, queue: MTLCommandQueue, targets: FrameRenderer.Targets) {
        self.device = device; self.frame = frame; self.overlay = overlay; self.art = art; self.queue = queue; self.targets = targets
    }
}

final class GameAssets: @unchecked Sendable {
    static let shared = GameAssets()

    /// 화면 출력 형식(GameStageView 의 MTKView 와 같게)
    static let drawableFormat = MTLPixelFormat.bgra8Unorm

    private let lock = NSLock()
    private var storeTask: Task<ContentStore, Error>?
    private var coreTask: Task<GameCore, Error>?
    private var renderTask: Task<GameRender, Error>?

    /// 앱 시작 때 한 번(여러 번 불러도 같다)
    func start() {
        lock.lock(); defer { lock.unlock() }
        guard storeTask == nil else { return }
        BootTrace.mark("준비 시작")
        let st = Task.detached(priority: .userInitiated) { try BootTrace.measure("ContentStore") { try ContentStore.bundled() } }
        let ct = Task.detached(priority: .userInitiated) { try await Self.loadCore(store: st.value) }
        let rt = Task.detached(priority: .userInitiated) { try await Self.loadRender(store: st.value) }
        storeTask = st; coreTask = ct; renderTask = rt
        // 데우기(첫 판 프레임 멈칫 줄이기 — 글자 굽기 · 모델 · GPU 파이프라인 첫 사용). 실패해도 상관없다
        Task.detached(priority: .utility) {
            guard let c = try? await ct.value, let r = try? await rt.value else { return }
            Self.warm(core: c, render: r)
        }
    }

    func core() async throws -> GameCore {
        start()
        let t = lock.withLock { coreTask! }
        return try await t.value
    }

    func render() async throws -> GameRender {
        start()
        let t = lock.withLock { renderTask! }
        return try await t.value
    }

    // MARK: 굽기

    private static func loadCore(store: ContentStore) async throws -> GameCore {
        async let tables: Void = Task.detached(priority: .userInitiated) {
            // 소리 파형표(표본율마다 한 번). 출력 표본율과 다르면 AudioEngine 이 그 표본율로 다시 만든다
            // 파형표(44.1k · 48k 는 같은 4096 표 — 표본율이 정해지기 전에 먼저 굽는다). 출력 장치 열기는 기다리지 않는다(아래)
            BootTrace.measure("파형표") { AudioEngine.prewarm(sampleRate: 48_000) }
        }.value
        // 출력 장치 열기(첫 outputNode — 시뮬레이터 100~300ms). 타이틀은 기다리지 않는다 — 메인의 AudioEngine.init 이 겹치면 남은 만큼만 기다린다
        Task.detached(priority: .userInitiated) {
            let sr = BootTrace.measure("소리 출력 준비") { AudioEngine.prewarmOutput() }
            AudioEngine.prewarm(sampleRate: sr)   // 표 크기가 다른 표본율(≤24k 등)이면 여기서 굽는다
        }
        async let split: Void = Task.detached(priority: .userInitiated) { BootTrace.measure("조각 나누기") { store.prewarm() } }.value
        async let atlasMeta = Task.detached(priority: .userInitiated) { try BootTrace.measure("AtlasMeta") { try AtlasMeta.bundled() } }.value
        async let simData = Task.detached(priority: .userInitiated) { try BootTrace.measure("SimData") { try SimData(store: store, nativeMoves: true) } }.value
        let atlas = try await atlasMeta
        let scene = try BootTrace.measure("SceneContent") { try SceneContent(store: store, atlas: atlas) }
        let data = try await simData
        let flow = try BootTrace.measure("FlowContent") { try FlowContent(store: store, data: data) }
        let director = try BootTrace.measure("StageDirector") {
            try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
        }
        _ = await tables
        _ = await split
        BootTrace.mark("core 준비")
        return GameCore(store: store, data: data, atlas: atlas, sceneContent: scene, flow: flow, director: director)
    }

    private static func loadRender(store: ContentStore) async throws -> GameRender {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw RenderError.encoder }
        async let art = Task.detached(priority: .userInitiated) { try BootTrace.measure("HUDArt") { try HUDArt(store: store) } }.value
        async let overlay = Task.detached(priority: .userInitiated) {
            try BootTrace.measure("OverlayRenderer") {
                let o = try OverlayRenderer(device: device)
                try o.prepareComposite(format: drawableFormat)
                return UncheckedBox(o)
            }
        }.value
        let frame = try BootTrace.measure("FrameRenderer") {
            let atlas = try AtlasMeta.bundled()
            let f = try FrameRenderer(device: device, atlas: atlas)
            try f.prepareBlit(format: drawableFormat)
            return f
        }
        let targets = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        let r = GameRender(device: device, frame: frame, overlay: (try await overlay).value, art: try await art, queue: queue, targets: targets)
        BootTrace.mark("render 준비")
        return r
    }

    /// 화면 밖 데우기: 버리는 판 · 버리는 감독으로 몇 프레임 — 공용 캐시(HUD 글자 아틀라스 · HUDText · 셰이더 첫 사용)를 채운다.
    /// 앱의 감독 · 판에는 손대지 않는다(결과 화면 · 결정성에 영향 없음). GPU 는 별도 큐 · 별도 대상으로.
    private static func warm(core c: GameCore, render r: GameRender) {
        BootTrace.measure("데우기") {
            guard let d = try? StageDirector(content: c.sceneContent, store: c.store, tables: c.data.animTables, catalog: HUDCatalog(c.data), heavyReactions: c.data.heavyRK),
                  let queue = r.device.makeCommandQueue(),
                  let targets = try? FrameRenderer.Targets(device: r.device, width: 480, height: 270),
                  let fr = try? FrameRenderer(device: r.device, atlas: c.atlas),
                  let ov = try? OverlayRenderer(device: r.device) else { return }
            d.hud.art = r.art; d.hud.playSpeed = 1
            var cfg = SimConfig(); cfg.skipTalks = true; cfg.prologue = false
            let sim = Sim(data: c.data, seed: 7, config: cfg)
            var target: OverlayRenderer.Target?
            // 150프레임(2.5초 분량): 첫 컷인(필살) · 만화 글자 · 피해 숫자가 나오는 구간 — 벤치(PerfBenchTests) 1회차 최악 20ms 멈칫이 여기서 사라진다
            let N = 150
            for k in 0..<N {
                var intents: [SimIntent] = []
                if sim.state == "shop" { intents = [.shopPick(0)] } else if sim.state == "arrange" { intents = [.advance] }
                if k % 30 == 0 { intents.append(.tap(side: k % 60 == 0 ? 1 : -1, at: sim.clock)) }
                if k == 0 { intents.append(.special) }
                let ev = sim.step(intents), s = sim.snapshot
                _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                let list = HUDOverlay.build(d.hud.state, d.hud.frame(s, view: f.view, shake: f.shake), art: r.art)
                guard k == N - 1 || k == 0, let cb = queue.makeCommandBuffer() else { continue }
                var rf = RenderFrame(stage: f, atlas: c.sceneContent.sprites)
                rf.applyHUD(d.hud.state, now: s.time)
                try? fr.encode(rf, targets: targets, into: cb)
                if !list.isEmpty, let t = try? OverlayRenderer.Target(device: r.device, width: list.width, height: list.height) {
                    target = t
                    try? ov.encode(list, atlas: r.art.atlas, target: t, into: cb)
                }
                cb.commit(); cb.waitUntilCompleted()
            }
            _ = target
        }
    }
}

/// Sendable 이 아닌 값을 작업 경계 너머로 넘길 때(만든 쪽은 더 쓰지 않는다)
struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }
