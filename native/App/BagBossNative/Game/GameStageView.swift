import SwiftUI
import os
import MetalKit
import BBRender
import BBContent
import BBPresentation

// 무대(Metal): MTKView 의 그리기 콜백(화면 주기) 하나가 게임 루프다 — 틱 · 연출 · 렌더를 한 번에.
// 터치는 제스처 인식기를 거치지 않고 touchesBegan 으로 직접 받는다(docs/06 §2.7) — 시각은 UITouch.timestamp.
// HUD(웹 #ui 캔버스: 피해 숫자 · HITFX · 만화 · 말풍선 · 컷인 · 노선도 · 체력 · 두목 막대 · 문 전환)는 Metal 오버레이 패스로 그린다:
//   HUDDirector 상태 + 프레임 값 → HUDOverlay.build(그리기 목록) → OverlayRenderer(UI 3배 해상도) → 드로어블 위에 최근접으로 얹기.
//   충격파 · 번짐(웹 GS.sw · GS.smear)은 후처리 유니폼으로(RenderFrame.applyHUD).

final class StageMTKView: MTKView {
    var onTouch: ((SIMD2<Double>, Double) -> Void)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            onTouch?([Double(p.x / bounds.width), Double(p.y / bounds.height)], t.timestamp)
        }
    }
}

struct GameStageView: UIViewRepresentable {
    let session: GameSession

    func makeCoordinator() -> StageRenderer { StageRenderer(session: session) }

    func makeUIView(context: Context) -> StageMTKView {
        let v = StageMTKView(frame: .zero, device: session.render?.device ?? MTLCreateSystemDefaultDevice())
        v.colorPixelFormat = GameAssets.drawableFormat
        v.preferredFramesPerSecond = 60
        v.isMultipleTouchEnabled = true
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.delegate = context.coordinator
        let s = session
        v.onTouch = { p, ts in MainActor.assumeIsolated { s.stageTouch(p, timestamp: ts) } }
        context.coordinator.setup(device: v.device!)
        return v
    }
    func updateUIView(_ v: StageMTKView, context: Context) {}
}

@MainActor
final class StageRenderer: NSObject, MTKViewDelegate {
    let session: GameSession
    private var renderer: FrameRenderer?
    private var overlay: OverlayRenderer?
    private var overlayTarget: OverlayRenderer.Target?
    private var art: HUDArt?
    private var queue: MTLCommandQueue?
    private var targets: FrameRenderer.Targets?
    private var lastFrame: RenderFrame?
    private let inFlight = DispatchSemaphore(value: 3)

    init(session: GameSession) { self.session = session }

    func setup(device: MTLDevice) { adopt() }

    /// GPU 자원은 GameAssets 가 뒤 스레드에서 미리 만든다(docs/06 §8 성능) — 준비되면 받아 쓰고, 그 전에는 아무것도 그리지 않는다
    private func adopt() {
        guard renderer == nil, let r = session.render else { return }
        renderer = r.frame; queue = r.queue; targets = r.targets; overlay = r.overlay; art = r.art
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// HUD 그리기 목록(판이 돌 때만)
    private func hudList(_ f: RenderFrame, in view: MTKView) -> OverlayList? {
        guard let art, session.screen == .playing, session.sim != nil else { return nil }
        let d = session.director
        var F = d.hud.frame(session.snapshot, view: session.view, shake: Double(f.shake.x))
        if session.settings.layoutNew {   // 새 배치(docs/09): 화면 고정 HUD 는 장면보다 작게 · 위에 역 이름 자리 · 점수는 SwiftUI 오른쪽 위
            let ppp = Double(view.bounds.width) / max(1, F.vw)   // 장면 1px = 몇 pt
            // 노선도 줄(역 수 × 26px)이 오른쪽 위 점수 묶음(약 150pt) 앞에서 끝나게 — 역이 많은 노선은 조금 더 작게
            let dots = Double(max(1, F.stops.count) * 26) + 4, room = Double(view.bounds.width) - 156
            F.hudScale = max(0.5, min(1, 1.45 / ppp, room / (dots * ppp)))
            // 위 SwiftUI 줄(역 이름 · 정리 칩 · 메뉴 단추 약 26pt) 아래로 노선도 · 연타를 내린다 — HUD 1px 이 작을수록 px 로는 더 많이
            F.hudTop = max(10, (30 / (ppp * F.hudScale!)).rounded(.up) - 8)
            F.scoreOutside = session.hudPlain ? true : nil
            F.uis = max(3, (Double(view.drawableSize.width) / max(1, F.vw)).rounded(.down))   // 커진 무대에서도 HUD 글자가 뭉개지지 않게
        }
        return HUDOverlay.build(d.hud.state, F, art: art)
    }

    /// 보이는 장면 폭: 새 배치는 무대 뷰 비율 그대로(장면 높이 270 을 꽉 채운다) · 예전 배치는 웹 360(4:3)
    private func visibleWidth(_ view: MTKView) -> Double {
        let b = view.bounds.size
        guard session.settings.layoutNew, b.width > 1, b.height > 1 else { return 360 }
        return max(150, min(480, Double(b.width / b.height) * 270))
    }

    func draw(in view: MTKView) {
        let media = CACurrentMediaTime()
        BootTrace.markOnce("첫 draw")
        if renderer == nil { adopt() }
        guard let renderer, let queue, let targets else { return }
        session.director.hud.playSpeed = session.paused ? 0 : session.speed
        session.director.camera.visibleWidth = visibleWidth(view)
        session.director.hud.visibleWidth = session.view.visibleWidth
        if var f = session.frame(media: media) {
            BootTrace.markOnce("첫 판 프레임")
            f.applyHUD(session.director.hud.state, now: session.snapshot.time)
            lastFrame = f
        }
        guard let f = lastFrame, let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable else { return }
        let list = hudList(f, in: view)
        inFlight.wait()
        guard let cb = queue.makeCommandBuffer() else { inFlight.signal(); return }
        do {
            try renderer.encode(f, targets: targets, into: cb)
            try renderer.encodeBlit(f, source: targets.output(for: f), pass: pass, format: view.colorPixelFormat, into: cb)
            if let list, !list.isEmpty, let overlay, let art {
                if overlayTarget?.width != list.width || overlayTarget?.height != list.height {
                    overlayTarget = try OverlayRenderer.Target(device: overlay.device, width: list.width, height: list.height)
                }
                try overlay.encode(list, atlas: art.atlas, target: overlayTarget!, into: cb)
                let p2 = MTLRenderPassDescriptor()
                p2.colorAttachments[0].texture = drawable.texture; p2.colorAttachments[0].loadAction = .load; p2.colorAttachments[0].storeAction = .store
                try overlay.encodeComposite(overlayTarget!.output, pass: p2, format: view.colorPixelFormat, into: cb)
            }
        } catch { session.lastError = "렌더 실패: \(error)"; inFlight.signal(); return }
        cb.present(drawable)
        let sem = inFlight, gpu = gpuMs
        cb.addCompletedHandler { cb in
            sem.signal()
            let ms = (cb.gpuEndTime - cb.gpuStartTime) * 1000
            gpu.withLock { $0 = ms }   // 프레임마다 Task 를 만들지 않는다(성능 — docs/06 §8)
        }
        cb.commit()
        session.lastGPUms = gpuMs.withLock { $0 }
        #if DEBUG
        if GameSession.perfLog {
            drawAcc.n += 1; drawAcc.ms += (CACurrentMediaTime() - media) * 1000
            if drawAcc.n == 120 { print(String(format: "[perf] draw 전체(CPU) %.2fms/프레임 · 120프레임 평균", drawAcc.ms / 120)); drawAcc = (0, 0) }
        }
        #endif
    }
    private let gpuMs = OSAllocatedUnfairLock(initialState: 0.0)
    #if DEBUG
    private var drawAcc = (n: 0, ms: 0.0)
    #endif
}
