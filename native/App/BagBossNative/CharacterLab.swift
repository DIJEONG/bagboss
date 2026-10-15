import SwiftUI
import MetalKit
import BBRender
import BBAnim
import BBContent

/// N2 캐릭터 실험실(DEBUG): 같은 동작을 왼쪽(웹 원본) · 오른쪽(네이티브 강화) 인물이 동시에 한다.
/// 슬로모션과 강화 항목별 켜기로 2차 운동(코트 · 머리 추종 · 호흡 · 충격)을 비교한다.
struct CharacterLab: View {
    @State private var settings = LabSettings()
    var body: some View {
        VStack(spacing: 10) {
            LabMetalView(settings: settings).aspectRatio(4.0 / 3.0, contentMode: .fit).background(.black)
            HStack { Text("← 웹 원본").font(.caption); Spacer(); Text("네이티브 강화 →").font(.caption) }.foregroundStyle(.secondary)
            Picker("속도", selection: $settings.speed) { Text("1×").tag(1.0); Text("0.5×").tag(0.5); Text("0.25×").tag(0.25) }.pickerStyle(.segmented)
            Toggle("코트 자락", isOn: $settings.style.coat)
            Toggle("머리 추종", isOn: $settings.style.headLag)
            Toggle("호흡", isOn: $settings.style.breathing)
            Toggle("착지 · 피격 찌그러짐", isOn: $settings.style.impact)
            Spacer()
        }
        .padding()
        .navigationTitle("캐릭터 실험실 · N2")
    }
}

struct LabSettings: Equatable {
    var speed = 1.0
    var style = MotionStyle.on
}

struct LabMetalView: UIViewRepresentable {
    let settings: LabSettings
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        v.colorPixelFormat = .bgra8Unorm; v.preferredFramesPerSecond = 60; v.delegate = context.coordinator
        context.coordinator.setup(device: v.device!)
        return v
    }
    func updateUIView(_ v: MTKView, context: Context) { context.coordinator.settings = settings }

    @MainActor final class Coordinator: NSObject, MTKViewDelegate {
        var settings = LabSettings()
        var renderer: FrameRenderer?, queue: MTLCommandQueue?, targets: FrameRenderer.Targets?
        var tmpl: RenderFrame?, bgCount = 0
        var tables: AnimTables?, seqs: SequenceTable?
        var A: CharacterRig?, B: CharacterRig?, pa = SequencePlayer(), pb = SequencePlayer()
        var t = 0.0, animAcc = 0.0, last = CACurrentMediaTime(), cue = 0
        static let script: [(Double, String)] = [(0, "idle"), (1.2, "walk"), (2.4, "kick"), (3.1, "hit"), (3.6, "upper"), (4.4, "launch"), (5.3, "jland"), (6.3, "idle")]
        static let loopLen = 7.8, startX = (A: 200.0, B: 300.0)

        func setup(device: MTLDevice) {
            do {
                let store = try ContentStore.bundled()
                tables = try AnimTables(store); seqs = try SequenceTable(store)
                renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()); queue = device.makeCommandQueue()
                guard let url = Bundle.main.url(forResource: "frame", withExtension: "json", subdirectory: "frames/subway") else { return }
                var f = try RenderFrame(webCapture: Data(contentsOf: url))
                if case .sprite(_, let n, _) = f.gbuffer.first { bgCount = n }
                f.spriteVertices = Array(f.spriteVertices.prefix(bgCount * 9)); f.shake = .zero
                f.blit.cameraX = 70; f.blit.zoom = 1
                tmpl = f
                targets = try FrameRenderer.Targets(device: device, width: f.width, height: f.height)
                let def = try CharacterDef.load(store, "JW_HERO")
                (A, pa) = def.instance(x: Self.startX.A, y: 220, flip: false, isHero: true, sequences: seqs!, tables: tables!)
                (B, pb) = def.instance(x: Self.startX.B, y: 220, flip: false, isHero: true, sequences: seqs!, tables: tables!)
            } catch { print("[lab] 준비 실패: \(error)") }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer, let queue, let targets, let tables, let seqs, var A, var B, var f = tmpl,
                  let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable, let cb = queue.makeCommandBuffer() else { return }
            let now = CACurrentMediaTime(), dt = min(0.05, now - last) * settings.speed; last = now
            t += dt
            if t >= Self.loopLen { t = 0; cue = 0; A.x = Self.startX.A; B.x = Self.startX.B }
            if cue < Self.script.count && t >= Self.script[cue].0 {
                let anim = Self.script[cue].1; cue += 1
                pa.set(anim, on: &A.actor, table: seqs, loop: tables.loop); pb.set(anim, on: &B.actor, table: seqs, loop: tables.loop)
            }
            if A.actor.anim == "walk" { let dx = 40 * dt; A.x += dx; B.x += dx; A.actor.gph = (A.actor.gph ?? 0) + dx / 28.8; B.actor.gph = (B.actor.gph ?? 0) + dx / 28.8 }
            animAcc += dt
            while animAcc >= 1.0 / 20 { animAcc -= 1.0 / 20; pa.advance(&A.actor, table: seqs, loop: tables.loop); pb.advance(&B.actor, table: seqs, loop: tables.loop) }
            var w = MeshWriter()
            A.emit(time: 10 + t, dt: dt, style: .off, tables: tables, into: &w)
            B.emit(time: 10 + t, dt: dt, style: settings.style, tables: tables, into: &w)
            self.A = A; self.B = B
            f.time = Float(10 + t); f.meshVertices = w.floats
            f.gbuffer = [.sprite(first: 0, count: bgCount, shadow: false), .mesh(first: 0, count: w.vertexCount)]
            do {
                try renderer.encode(f, targets: targets, into: cb)
                try renderer.encodeBlit(f, source: targets.output(for: f), pass: pass, format: view.colorPixelFormat, into: cb)
            } catch { return }
            cb.present(drawable); cb.commit()
        }
    }
}
