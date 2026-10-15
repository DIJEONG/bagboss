import Testing
import Foundation
import ImageIO
@preconcurrency import CoreText
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBAnim
@testable import BBSim
@testable import BBRender
import BBPresentation

/// 피격 반응 다양화 비교 띠(BB_DUMP=1 — docs/11 §9) → tools/js/out/hitreact/
///   zones.png   줄 = 자리 · 방향(머리 앞 · 몸통 앞 · 다리 · 등 뒤 · 위에서 · 아래에서 · 무거운 타격). 칸 = [기존(웹) 4칸 | 새 1타 4칸 | 2타 | 3타]
///               4칸 = 맞고 0.05 · 0.15 · 0.3 · 0.45초(무거운 줄은 0.1 · 0.3 · 0.5 · 0.7초)
///   repeat6.png 같은 잽 6번 연달아(0.6초 간격) — 윗줄 기존 · 아랫줄 새(각 타격 0.15초 칸 · 0.3초 칸)
///   weight.png  같은 타격(머리 · 앞 · 보통) — 신문팔이(0.8배 · 가벼움) · 불량배(보통) · 라인배커(1.08배 · 무거움), 0.05~0.6초
@Suite(.serialized) struct HitReactStripTests {
    static let out = NeckAuditTests.root.appending(path: "tools/js/out/hitreact")
    static var dump: Bool { ProcessInfo.processInfo.environment["BB_DUMP"] == "1" }

    struct Ctx {
        let tables: AnimTables, seqs: SequenceTable, subs: [NeckAuditTests.Subject], P: NeckAuditTests.Painter
        init() throws {
            let store = try ContentStore.bundled()
            let baseT = try AnimTables(store)
            tables = baseT.withNativeMoves(); seqs = try SequenceTable(store).withNativeMoves()
            subs = try NeckAuditTests.subjects(store: store, base: baseT, seqs: seqs)
            P = try NeckAuditTests.Painter()
        }
        func subject(_ prefix: String) -> NeckAuditTests.Subject { subs.first { $0.name.hasPrefix(prefix) || $0.members.contains { $0.hasPrefix(prefix) } } ?? subs[min(4, subs.count - 1)] }
    }

    /// 한 인물에 피격 몇 번: hits[i] = (시각, 반응 동작, 변형 고르기 입력 — nil 이면 웹 그대로). 칸 시각(초)마다 메시
    static func play(_ C: Ctx, _ S: NeckAuditTests.Subject, hits: [(Double, String, (HitZone, HitDir, HitTier, HitMass)?)], shots: [Double]) -> [([Float], String)] {
        var r = NeckAuditTests.rig(S), pl = SequencePlayer(), t = 10.0
        r.actor = ActorPose(anim: "idle", pose: "st0")
        pl.set("idle", on: &r.actor, table: C.seqs, loop: C.tables.loop)
        let end = (shots.max() ?? 1) + 0.02
        var out: [([Float], String)] = [], hi = 0, si = 0, k = 0
        let sorted = shots.sorted()
        var label = ""
        while t - 10 <= end {
            let now = t - 10
            if hi < hits.count && now >= hits[hi].0 - 1e-9 {
                let h = hits[hi]
                pl.set(h.1, on: &r.actor, table: C.seqs, loop: C.tables.loop)
                if let g = h.2 { let v = r.react.trigger(actor: 5, zone: g.0, dir: g.1, tier: g.2, mass: g.3, time: t, hold: 0.1); label = v.rawValue } else { label = "웹 \(h.1)" }
                hi += 1
            }
            var w = MeshWriter(); r.emit(time: t, dt: 1.0 / 60, style: .on, tables: C.tables, into: &w)
            while si < sorted.count && now >= sorted[si] - 1e-9 { out.append((w.floats, label)); si += 1 }
            k += 1; t += 1.0 / 60
            if k % 3 == 0 { pl.advance(&r.actor, table: C.seqs, loop: C.tables.loop) }
        }
        return out
    }

    /// 칸(장면 64×80 · 3배) 격자 — 줄 머리 글자 + 칸 아래 글자
    static func sheet(_ C: Ctx, rows: [(String, [([Float], String)])], name: String, bw: Int = 64, bh: Int = 80, z: Int = 2) throws {
        let cols = rows.map(\.1.count).max() ?? 1, cw = bw * z + 4, ch = bh * z + 14, head = 16
        let W = cols * cw + 8, H = rows.count * (ch + head) + 6
        var img = [UInt8](repeating: 18, count: W * H * 4)
        for i in stride(from: 3, to: img.count, by: 4) { img[i] = 255 }
        var labels: [(String, Int, Int, Bool)] = []
        for (ri, row) in rows.enumerated() {
            let oy = ri * (ch + head) + head + 2
            labels.append((row.0, 6, oy - head + 2, true))
            for (ci, cell) in row.1.enumerated() {
                let px = try C.P.render(cell.0)
                let ox = ci * cw + 6, cx = 170 - bw / 2 + 4, cy = 220 - bh + 8
                for y in 0..<bh * z { for x in 0..<bw * z {
                    let sx = cx + x / z, sy = cy + y / z
                    guard sx >= 0, sy >= 0, sx < C.P.W, sy < C.P.tmpl.height else { continue }
                    let s = (sy * C.P.W + sx) * 4, d = ((oy + y) * W + ox + x) * 4
                    img[d] = px[s]; img[d + 1] = px[s + 1]; img[d + 2] = px[s + 2]
                } }
                labels.append((cell.1, ox, oy + bh * z + 1, false))
            }
        }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let ctx = CGContext(data: &img, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for (s, x, y, hot) in labels {
            let font = CTFontCreateWithName("AppleSDGothicNeo-Bold" as CFString, hot ? 11 : 9, nil)
            let col = hot ? CGColor(red: 1, green: 0.82, blue: 0.35, alpha: 1) : CGColor(red: 0.8, green: 0.84, blue: 0.9, alpha: 1)
            let attr = NSAttributedString(string: s, attributes: [kCTFontAttributeName as NSAttributedString.Key: font, kCTForegroundColorAttributeName as NSAttributedString.Key: col])
            ctx.textPosition = CGPoint(x: x, y: H - y - 11)
            CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        }
        let url = out.appending(path: name + ".png")
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[hitreact] \(name) → \(url.path)")
    }

    @Test(.enabled(if: dump)) func strips() throws {
        let C = try Ctx()
        let thug = C.subject("불량배"), news = C.subject("신문팔이"), line = C.subject("라인배커")
        let N = HitMass.normal
        // ① 자리 · 방향
        let cases: [(String, String, HitZone, HitDir, HitTier)] = [
            ("머리 · 앞(잽 · 크로스 — 웹 hit)", "hit", .head, .front, .medium), ("몸통 · 앞(앞차기 · 리버 — 웹 hitB)", "hitB", .body, .front, .medium),
            ("다리(하단 차기 — 웹 hit)", "hit", .legs, .front, .medium), ("등 뒤(웹 hit)", "hit", .head, .back, .medium),
            ("위에서(내려찍기 — 웹 hit)", "hit", .head, .above, .medium), ("아래에서(어퍼컷 — 웹 hit)", "hit", .head, .below, .medium),
            ("무거운 타격(받아치기 · 무게 H — 웹 rHook)", "rHook", .head, .front, .heavy),
        ]
        var rows: [(String, [([Float], String)])] = []
        for (title, anim, z, d, t) in cases {
            let ts = t == .heavy ? [0.1, 0.3, 0.5, 0.7] : [0.05, 0.15, 0.3, 0.45]
            let gap = t == .heavy ? 1.2 : 0.8
            let old = Self.play(C, thug, hits: [(0, anim, nil)], shots: ts)
            let new = Self.play(C, thug, hits: (0..<3).map { (Double($0) * gap, anim, (z, d, t, N)) }, shots: (0..<3).flatMap { i in ts.map { $0 + Double(i) * gap } })
            rows.append((title + " — 기존 4칸 | 새 1 · 2 · 3타", old + new))
        }
        try Self.sheet(C, rows: rows, name: "zones")
        // ② 같은 잽 6번
        let six = (0..<6).map { Double($0) * 0.6 }
        let shots6 = six.flatMap { [$0 + 0.15, $0 + 0.3] }
        let old6 = Self.play(C, thug, hits: six.map { ($0, "hit", nil) }, shots: shots6)
        let new6 = Self.play(C, thug, hits: six.map { ($0, "hit", (.head, .front, .light, N)) }, shots: shots6)
        try Self.sheet(C, rows: [("같은 잽 6번 — 기존(웹): 매번 같은 반응", old6), ("같은 잽 6번 — 새: 연달아 같은 변형 없음", new6)], name: "repeat6")
        // ③ 몸무게
        let tw = [0.05, 0.12, 0.2, 0.3, 0.45, 0.6]
        var wrows: [(String, [([Float], String)])] = []
        for (nm, S, key) in [("신문팔이 소년(0.8배 — 가벼움 ×1.4)", news, "nv_newsboy"), ("불량배(보통 ×1)", thug, "punk"), ("라인배커(1.08배 — 무거움 ×0.5)", line, "nv_lineback")] {
            let m = HitReact.mass(type: key, hero: false, boss: false)
            wrows.append((nm + " — 기존 | 새(같은 변형)", Self.play(C, S, hits: [(0, "hit", nil)], shots: [0.12, 0.3]) + Self.play(C, S, hits: [(0, "hit", (.head, .front, .medium, m))], shots: tw)))
        }
        try Self.sheet(C, rows: wrows, name: "weight")
    }
}
