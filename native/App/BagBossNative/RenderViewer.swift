import SwiftUI
import MetalKit
import BBRender
import BBContent

/// N1 렌더 뷰어(DEBUG): 웹에서 찍은 프레임(Tests/Fixtures/frames)을 네이티브 렌더러로 화면에 그린다.
/// 시간만 흘려서 비 · 물결 · 깜빡임이 도는지, 화면 출력(세로 크롭 · sharp-bilinear)이 맞는지, GPU 시간이 얼마인지 본다.
struct RenderViewer: View {
    static let scenes = ["subway", "tower"]
    @State private var scene = "subway"
    @State private var stats = RenderStats()

    var body: some View {
        VStack(spacing: 12) {
            Picker("장면", selection: $scene) { ForEach(Self.scenes, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            MetalFrameView(scene: scene, stats: $stats)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .background(.black)
            Text(stats.text).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("렌더 뷰어 · N1")
    }
}

struct RenderStats: Equatable {
    var gpuMs: Double = 0, drawable = "", error: String?
    var text: String { error ?? String(format: "GPU %.2fms · 화면 %@", gpuMs, drawable) }
}

struct MetalFrameView: UIViewRepresentable {
    let scene: String
    @Binding var stats: RenderStats

    func makeCoordinator() -> Coordinator { Coordinator(stats: $stats) }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        v.colorPixelFormat = .bgra8Unorm
        v.preferredFramesPerSecond = 60
        v.delegate = context.coordinator
        context.coordinator.load(scene: scene, device: v.device!)
        return v
    }

    func updateUIView(_ v: MTKView, context: Context) {
        if context.coordinator.scene != scene { context.coordinator.load(scene: scene, device: v.device!) }
    }

    @MainActor final class Coordinator: NSObject, MTKViewDelegate {
        var stats: Binding<RenderStats>
        var scene = ""
        var renderer: FrameRenderer?
        var queue: MTLCommandQueue?
        var frame: RenderFrame?
        var targets: FrameRenderer.Targets?
        var t0 = CACurrentMediaTime(), baseTime: Float = 0, lastReport = 0.0

        init(stats: Binding<RenderStats>) { self.stats = stats }

        func load(scene: String, device: MTLDevice) {
            self.scene = scene
            do {
                if renderer == nil { renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()); queue = device.makeCommandQueue() }
                guard let url = Bundle.main.url(forResource: "frame", withExtension: "json", subdirectory: "frames/\(scene)") else {
                    stats.wrappedValue.error = "번들에 frames/\(scene) 없음"; return
                }
                let f = try RenderFrame(webCapture: Data(contentsOf: url))
                frame = f; baseTime = f.time; t0 = CACurrentMediaTime()
                targets = try FrameRenderer.Targets(device: device, width: f.width, height: f.height)
                stats.wrappedValue.error = nil
            } catch { stats.wrappedValue.error = "불러오기 실패: \(error)" }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer, let queue, var f = frame, let targets, let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable, let cb = queue.makeCommandBuffer() else { return }
            f.time = baseTime + Float(CACurrentMediaTime() - t0)
            do {
                try renderer.encode(f, targets: targets, into: cb)
                try renderer.encodeBlit(f, source: targets.output(for: f), pass: pass, format: view.colorPixelFormat, into: cb)
            } catch { stats.wrappedValue.error = "렌더 실패: \(error)"; return }
            cb.present(drawable)
            let size = view.drawableSize
            cb.addCompletedHandler { [weak self] cb in
                let ms = (cb.gpuEndTime - cb.gpuStartTime) * 1000
                Task { @MainActor in self?.report(ms: ms, size: size) }
            }
            cb.commit()
        }

        private func report(ms: Double, size: CGSize) {
            let now = CACurrentMediaTime(); guard now - lastReport > 0.5 else { return }
            lastReport = now
            stats.wrappedValue.gpuMs = ms
            stats.wrappedValue.drawable = "\(Int(size.width))×\(Int(size.height))"
        }
    }
}
