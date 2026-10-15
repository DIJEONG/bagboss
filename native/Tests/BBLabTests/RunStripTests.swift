import Testing
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
@testable import BBAnim
import BBRender
import BBContent

/// 질주 비교(감독 참고 그림 tools/js/out/moves/ref/run_ref.jpg) — BB_DUMP=1 일 때만 → tools/js/out/moves/compare_run.png
/// 윗줄 = 웹 runPose(깃발 꺼짐 표) · 아랫줄 = 네이티브 키 질주(nv_run0…5). 둘 다 주인공 최고 속도 156px/s 로 gph 를 거리만큼 나아가게 하고
/// 위상이 1/12 바퀴 넘을 때마다 한 장(한 바퀴 12장 = 키 · 사이 번갈아, 약 35ms 간격). 셋째 · 넷째 줄 = 같은 것을 게임 크기(1배)로. 강화(MotionStyle.on) 켬 — 앱과 같다.
/// 함께: 60fps 로 돌리며 손 · 발 관절이 한 화면 프레임에 튀는 최대 거리(px)를 찍는다(튐 점검).
@Suite struct RunStripTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_DUMP"] == "1"))
    func compareRun() throws {
        let store = try ContentStore.bundled()
        let web = try AnimTables(store), nat = try AnimTables(store).withNativeMoves()
        let seqW = try SequenceTable(store), seqN = try SequenceTable(store).withNativeMoves()
        let def = try CharacterDef.load(store, "JW_HERO")
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
        var tmpl = try RenderFrame(webCapture: Data(contentsOf: Self.root.appending(path: "native/Tests/Fixtures/frames/subway/frame.json")))
        guard case .sprite(_, let bgCount, _) = tmpl.gbuffer.first else { Issue.record("배경 없음"); return }
        tmpl.spriteVertices = Array(tmpl.spriteVertices.prefix(bgCount * 9)); tmpl.shake = .zero
        let targets = try FrameRenderer.Targets(device: device, width: tmpl.width, height: tmpl.height)
        let q = try #require(device.makeCommandQueue())
        let box = (w: 60, h: 64, top: 160), v = 156.0, cyc = 65.5, cells = 12
        func row(_ tables: AnimTables, _ seqs: SequenceTable, tilt: Double, name: String) throws -> [[UInt8]] {
            var (A, pa) = def.instance(x: 170, y: 220, flip: false, isHero: true, sequences: seqs, tables: tables)
            pa.set("walk", on: &A.actor, table: seqs, loop: tables.loop)
            A.actor.tilt = tilt
            var out: [[UInt8]] = [], t = 10.0, prevJ: Joints?, maxJump = 0.0, minAir = 99.0, lastSlot = -1, slip = 0.0, slipN = 0
            for k in 0..<200 {
                A.actor.runU = t + 1; A.actor.gph = (A.actor.gph ?? 0) + v / 60 / cyc
                var w = MeshWriter(); A.emit(time: t, dt: 1.0 / 60, style: .on, tables: tables, into: &w); t += 1.0 / 60
                if let j = A.joints {
                    if k > 30, let p = prevJ {   // 블렌드가 끝난 뒤(걷기 → 질주 섞기 0.15초)
                        for (a, b) in [(j.handF, p.handF), (j.handB, p.handB), (j.footF, p.footF), (j.footB, p.footB), (j.kneeF, p.kneeF), (j.kneeB, p.kneeB)] {
                            maxJump = max(maxJump, hypot(a.x - b.x, a.y - b.y))
                        }
                        minAir = min(minAir, max(j.footF.y, j.footB.y))
                        for (a, b) in [(j.footF, p.footF), (j.footB, p.footB)] where a.y > -0.6 && b.y > -0.6 {   // 딛은 발: 세상 좌표 미끄럼 = 몸 이동 + 발 이동
                            slip += abs(a.x - b.x + v / 60); slipN += 1
                        }
                    }
                    prevJ = j
                }
                let slot = Int(((A.actor.gph ?? 0) * 12).rounded(.down))   // 반 키 단위(한 바퀴 12장: 키 0 · 사이 · 키 1 …)
                guard k >= 30, slot != lastSlot, out.count < cells else { lastSlot = slot; continue }
                lastSlot = slot
                var f = tmpl; f.time = Float(t); f.meshVertices = w.floats
                f.gbuffer = [GBufferDraw.mesh(first: 0, count: w.vertexCount)]   // 배경 없이(검은 양복 실루엣이 보이게 — 빈 곳은 아래에서 하늘색으로)
                let cb = try #require(q.makeCommandBuffer()); try renderer.encode(f, targets: targets, into: cb); cb.commit(); cb.waitUntilCompleted()
                let px = try renderer.readBack(targets.output(for: f), queue: q)
                var c = [UInt8](repeating: 0, count: box.w * box.h * 4)
                let x0 = Int(A.x) - box.w / 2 + 4
                for y in 0..<box.h { let s0 = ((box.top + y) * tmpl.width + x0) * 4; c.replaceSubrange(y * box.w * 4..<(y + 1) * box.w * 4, with: px[s0..<s0 + box.w * 4]) }
                out.append(c)
            }
            print("[run] \(name): 한 프레임 최대 관절 이동 \(String(format: "%.2f", maxJump))px · 체공 최고(낮은 발 바닥 위) \(String(format: "%.1f", -minAir))px · 딛은 발 미끄럼 평균 \(String(format: "%.2f", slip / Double(max(1, slipN))))px/프레임(몸 이동 \(String(format: "%.2f", v / 60)))")
            return out
        }
        let top = try row(web, seqW, tilt: 0, name: "웹"), bot = try row(nat, seqN, tilt: 0.14, name: "네이티브")
        // 3배(자세 보기) 두 줄 + 1배(게임 크기) 두 줄
        let S = 3, cw = box.w * S + 4, chh = box.h * S + 4, smallH = box.h + 6
        let W = cells * cw, H = 2 * chh + 2 * smallH + 8
        var sheet = [UInt8](repeating: 18, count: W * H * 4)
        for i in stride(from: 3, to: sheet.count, by: 4) { sheet[i] = 255 }
        func lift(_ v: UInt8) -> UInt8 { UInt8(min(255, Double(v) * 1.6 + 10)) }
        // 빈 곳(장면 맑은 색) → 참고 그림 같은 하늘색 바탕 · 바닥선
        func bgFix(_ c: [UInt8]) -> [UInt8] {
            var o = c; let b0 = (c[0], c[1], c[2])
            for i in stride(from: 0, to: c.count, by: 4) where abs(Int(c[i]) - Int(b0.0)) + abs(Int(c[i + 1]) - Int(b0.1)) + abs(Int(c[i + 2]) - Int(b0.2)) < 6 {
                o[i] = 70; o[i + 1] = 110; o[i + 2] = 150
            }
            let gy = 220 - box.top; if gy < box.h { for x in 0..<box.w { let i = (gy * box.w + x) * 4; o[i] = 40; o[i + 1] = 60; o[i + 2] = 80 } }
            return o
        }
        for (r, rowc0) in [top, bot].enumerated() { for (k, c0) in rowc0.enumerated() {
            let c = bgFix(c0)
            for y in 0..<box.h * S { for x in 0..<box.w * S {
                let s = ((y / S) * box.w + x / S) * 4, d = ((r * chh + y) * W + k * cw + x) * 4
                sheet[d] = lift(c[s]); sheet[d + 1] = lift(c[s + 1]); sheet[d + 2] = lift(c[s + 2])
            } }
            for y in 0..<box.h { for x in 0..<box.w {   // 1배
                let s = (y * box.w + x) * 4, d = ((2 * chh + 8 + r * smallH + y) * W + k * (box.w + 8) + x) * 4
                sheet[d] = lift(c[s]); sheet[d + 1] = lift(c[s + 1]); sheet[d + 2] = lift(c[s + 2])
            } }
        } }
        let url = Self.root.appending(path: "tools/js/out/moves/compare_run.png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ctx = CGContext(data: &sheet, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[run] → \(url.path)")
    }
}
