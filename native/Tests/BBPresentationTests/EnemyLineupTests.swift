import Testing
import Foundation
import Metal
import ImageIO
import CoreText
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBSim
import BBPresentation
@testable import BBRender

/// 적 생김새 한 줄 세우기(감독 요청 — 새 적 3종이 실제 게임 픽셀 크기에서 기존 적과 헷갈리지 않는지 눈으로 본다).
/// BB_DUMP=1 일 때만 → tools/js/out/enemies/
///   lineup.png       ETYPES 전부(웹 40 + 네이티브 3) · 실제 지하철 칸 — 칸마다 실제 크기(1×) · 2배 · 이름. 새 적은 노란 테
///   lineup_new.png   새 적 3 + 비슷한 자리의 기존 적(펀크 · 권법가 · 덩치 · 네온 덩치 · 병 던지는 놈 · 소매치기 · 배달원) 지하철 칸에서 나란히(1× · 3×)
///   strip_<id>.png   새 적의 서기 · 걷기 · 공격(무도장 상대로 — 실전과 같은 foeStrike 경로) 연속 칸
@Suite(.serialized) struct EnemyLineupTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let out = root.appending(path: "tools/js/out/enemies")
    static var dump: Bool { ProcessInfo.processInfo.environment["BB_DUMP"] == "1" }
    static let data: SimData = try! SimData.bundled().variant(nativeMoves: true)

    /// RGB 그림(장면 픽셀)
    struct Img { var w: Int, h: Int, px: [UInt8]
        init(w: Int, h: Int, fill: UInt8 = 24) { self.w = w; self.h = h; px = [UInt8](repeating: fill, count: w * h * 4); for i in stride(from: 3, to: px.count, by: 4) { px[i] = 255 } }
        func at(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) { let i = (y * w + x) * 4; return (px[i], px[i + 1], px[i + 2]) }
        mutating func set(_ x: Int, _ y: Int, _ c: (UInt8, UInt8, UInt8)) { guard x >= 0, y >= 0, x < w, y < h else { return }; let i = (y * w + x) * 4; px[i] = c.0; px[i + 1] = c.1; px[i + 2] = c.2 }
        /// src 의 (sx, sy, cw, ch) 를 k 배(최근접)로 (dx, dy) 에
        mutating func blit(_ s: Img, _ sx: Int, _ sy: Int, _ cw: Int, _ ch: Int, _ dx: Int, _ dy: Int, _ k: Int) {
            for y in 0..<ch * k { for x in 0..<cw * k {
                let ux = sx + x / k, uy = sy + y / k
                guard ux >= 0, uy >= 0, ux < s.w, uy < s.h else { continue }
                set(dx + x, dy + y, s.at(ux, uy))
            } }
        }
        mutating func rect(_ x0: Int, _ y0: Int, _ w0: Int, _ h0: Int, _ c: (UInt8, UInt8, UInt8)) {
            for x in x0..<(x0 + w0) { set(x, y0, c); set(x, y0 + h0 - 1, c) }
            for y in y0..<(y0 + h0) { set(x0, y, c); set(x0 + w0 - 1, y, c) }
        }
    }

    /// 실제 게임과 같은 경로(Sim → StageDirector → FrameRenderer)로 장면 한 장(480×270)
    final class Cam {
        let content: SceneContent, d: StageDirector, fr: FrameRenderer, tg: FrameRenderer.Targets, q: MTLCommandQueue
        init() throws {
            let store = try ContentStore.bundled(), data = EnemyLineupTests.data
            content = try SceneContent.bundled()
            d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
            let device = MTLCreateSystemDefaultDevice()!
            q = device.makeCommandQueue()!; fr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
            tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        }
        func step(_ sim: Sim, _ k: Int) -> StageFrame {
            let ev = sim.step(), s = sim.snapshot
            _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
            return d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
        }
        func render(_ f: StageFrame) throws -> Img {
            let rf = RenderFrame(stage: f, atlas: content.sprites)
            let cb = q.makeCommandBuffer()!; try fr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
            let px = try fr.readBack(tg.output(for: rf), queue: q)
            var I = Img(w: 480, h: 270); I.px = px; return I
        }
    }

    static func config() -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.playSpeed = 1
        return c
    }

    /// 무도장에 적을 줄 세운다(주인공 · 허수아비는 숨김). 무도장은 적 AI 가 돌지 않아 제자리에서 숨 쉰다
    static func line(_ w: World, _ types: [String], x0: Double, gap: Double) -> [Actor] {
        for a in w.ents where a !== w.hero { w.retire(a) }
        w.ents = [w.hero]; w.hero.hidden = true
        return types.enumerated().map { k, t in
            let T = w.data.enemy(t)!
            let e = Enemy(t: t, def: T, hp: T.hp, dmg: T.dmg, cd: T.cd, cdT: -99)
            let a = w.mkActor(w.defFor(T, k), x: x0 + Double(k) * gap, z: 0, flip: false, pose: "st0", remap: T.remap, grammar: T.grammar, e: e)
            w.setAnim(a, "idle"); w.ents.append(a); return a
        }
    }

    // MARK: 글자(CoreText — 이름표)

    static func png(_ I: Img, _ name: String, labels: [(String, Int, Int, Bool)] = []) throws {
        var px = I.px
        let ctx = CGContext(data: &px, width: I.w, height: I.h, bitsPerComponent: 8, bytesPerRow: I.w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for (s, x, y, hot) in labels {
            let font = CTFontCreateWithName("AppleSDGothicNeo-Bold" as CFString, 10, nil)
            let col = hot ? CGColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : CGColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
            let attr = NSAttributedString(string: s, attributes: [kCTFontAttributeName as NSAttributedString.Key: font, kCTForegroundColorAttributeName as NSAttributedString.Key: col])
            let ln = CTLineCreateWithAttributedString(attr)
            ctx.textPosition = CGPoint(x: x, y: I.h - y - 10)   // CG 는 아래가 0
            CTLineDraw(ln, ctx)
        }
        let url = out.appending(path: name + ".png")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[enemies] \(name) → \(url.path)")
    }

    // MARK: 전체 줄 세우기

    @Test(.enabled(if: dump)) func lineup() throws {
        let cam = try Cam()
        let sim = Sim(data: Self.data, seed: 5, config: Self.config())
        for k in 0..<240 { _ = cam.step(sim, k) }   // 실제 지하철 칸(배경 · 조명)
        sim.w.demo = true                              // 적 AI 멈춤(줄 세운 채로)
        let all = Self.data.game.enemies.keys
        let per = 7, CW = 60, CH = 76, gap = 62.0, x0 = 50.0
        let cols = 6, k2 = 2, label = 14
        let cellW = CW + CW * k2 + 12, cellH = CH * k2 + label + 8
        let rows = (all.count + cols - 1) / cols
        var sheet = Img(w: cols * cellW + 8, h: rows * cellH + 8)
        var labels: [(String, Int, Int, Bool)] = []
        var n = 0
        for g in stride(from: 0, to: all.count, by: per) {
            let types = Array(all[g..<min(all.count, g + per)])
            let actors = Self.line(sim.w, types, x0: x0, gap: gap)
            var f = cam.step(sim, 240)
            for k in 241...262 { f = cam.step(sim, k) }
            let I = try cam.render(f)
            for (k, a) in actors.enumerated() {
                let t = types[k], hot = t.hasPrefix("nv_")
                let ox = 4 + (n % cols) * cellW, oy = 4 + (n / cols) * cellH
                let sx = Int(a.x) - CW / 2 + 3, sy = Int(a.y) - CH + 6
                sheet.blit(I, sx, sy, CW, CH, ox, oy + CH * (k2 - 1), 1)            // 실제 크기(아래 맞춤)
                sheet.blit(I, sx, sy, CW, CH, ox + CW + 6, oy, k2)                  // 2배
                if hot { sheet.rect(ox - 2, oy - 2, cellW - 6, CH * k2 + 4, (255, 210, 60)) }
                labels.append(("\(Self.data.game.enemies[t]!.name) · \(t)", ox, oy + CH * k2 + 2, hot))
                n += 1
            }
        }
        try Self.png(sheet, "lineup", labels: labels)
    }

    /// 새 적과 비슷한 역할의 기존 적을 실제 지하철 칸(배경 · 조명)에서 나란히
    @Test(.enabled(if: dump)) func lineupNew() throws {
        let cam = try Cam()
        let sim = Sim(data: Self.data, seed: 5, config: Self.config())
        for k in 0..<240 { _ = cam.step(sim, k) }   // 지하철 판으로(첫 칸)
        let types = ["punk", "kungfu", "nv_spar", "slasher", "heavy", "neonbig", "nv_lineback", "bguard", "thrower", "pick", "nv_newsboy", "courier"]
        let w = sim.w
        w.demo = true   // 적 AI 멈춤(줄 세운 채로)
        let actors = Self.line(w, types, x0: 30, gap: 38)
        var f = cam.step(sim, 240)
        for k in 241...262 { f = cam.step(sim, k) }
        let I = try cam.render(f)
        let CW = 40, CH = 74, k3 = 3
        var sheet = Img(w: 8 + types.count * (CW * k3 + 4), h: CH + 8 + CH * k3 + 24)
        var labels: [(String, Int, Int, Bool)] = []
        let x0 = Int(actors.first!.x) - CW / 2, x1 = Int(actors.last!.x) + CW / 2
        sheet.blit(I, x0, Int(actors[0].y) - CH + 6, x1 - x0, CH, 4, 4, 1)          // 실제 크기 한 줄
        for (k, a) in actors.enumerated() {
            let ox = 4 + k * (CW * k3 + 4)
            sheet.blit(I, Int(a.x) - CW / 2, Int(a.y) - CH + 6, CW, CH, ox, CH + 8, k3)
            labels.append((Self.data.game.enemies[types[k]]!.name, ox + 2, CH + 8 + CH * k3 + 4, types[k].hasPrefix("nv_")))
        }
        try Self.png(sheet, "lineup_new", labels: labels)
    }

    // MARK: 새 적 동작 띠(서기 · 걷기 · 공격)

    @Test(.enabled(if: dump)) func strips() throws {
        for t in NativeContent.enemyIDs {
            let cam = try Cam()
            let sim = Sim(data: Self.data, seed: 9, config: Self.config())
            let w = sim.w
            w.startDojo(t)
            var frames: [(Img, Double, Double, String)] = []   // (장면, 적 x, y, 구분)
            var k = 0
            func run(_ n: Int, every: Int, tag: String) throws {
                for _ in 0..<n {
                    let f = cam.step(sim, k); k += 1
                    if k % every == 0, let D = w.dojoDummy() { frames.append((try cam.render(f), D.x, D.y, tag)) }
                }
            }
            try run(30, every: 10, tag: "idle")
            if let D = w.dojoDummy(), let H = w.hero { D.x = H.x + 150; w.setAnim(D, "walk") }
            try run(60, every: 6, tag: "walk")
            let T = Self.data.game.enemies[t]!
            var mvs: [String] = []; for m in T.moves where !mvs.contains(m) { mvs.append(m == "throw" ? "jab" : m) }
            for mv in mvs {
                w.dojoCommand(.foe(mv))
                try run(48, every: 3, tag: mv)
            }
            if T.range != nil {   // 던지기: 거리를 벌려 신문 뭉치(투사체)를 날린다
                if let D = w.dojoDummy(), let H = w.hero {
                    w.dojoReset(90); w.face(D, H.x)
                    let side: Double = D.x >= H.x ? 1 : -1
                    w.requestAction(D, "jab", ActionReq(cue: w.cueFor(D, "jab", "m_jab")) { c in
                        w.shots.append(Shot(x: c.x - side * 8, y: c.y - 52, vx: -side * 150, kind: NativeContent.paperThrowers.contains(t) ? "news" : ""))
                    })
                }
                try run(40, every: 3, tag: "throw")
            }
            let CW = 120, CH = 80, k2 = 2, cols = 8
            let rows = (frames.count + cols - 1) / cols
            var sheet = Img(w: cols * (CW * k2 + 4) + 4, h: rows * (CH * k2 + 18) + 4)
            var labels: [(String, Int, Int, Bool)] = []
            for (i, fr) in frames.enumerated() {
                let ox = 4 + (i % cols) * (CW * k2 + 4), oy = 4 + (i / cols) * (CH * k2 + 18)
                sheet.blit(fr.0, Int(fr.1) - CW / 2 - 20, Int(fr.2) - CH + 8, CW, CH, ox, oy, k2)
                labels.append((fr.3, ox + 2, oy + CH * k2 + 2, false))
            }
            try Self.png(sheet, "strip_\(t)", labels: labels)
        }
    }
}
