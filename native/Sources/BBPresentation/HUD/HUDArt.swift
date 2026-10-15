import Foundation
import BBContent
import BBSim

// HUD 데이터 · 도트 그림(웹 45-hud DFONT/DSTYLE/dGlyph · 03 GLYPH · 46-cutin 초상 생성기 · 47 BOSS_INFO/SPC · 26 FAMS · 11 STN).
// 그림은 웹과 같은 정수 연산으로 만들어 오버레이 아틀라스에 올린다(캔버스 → RGBA 바이트). 이미지 코덱을 거치지 않는다.

public final class HUDArt: @unchecked Sendable {
    public struct DStyle: Sendable { public var s: Int; public var r: [String]; public var o: String }
    public struct BossInfo: Sendable { public var n: String, nick: String, col: String, rage: String }
    public struct Special: Sendable { public var n: String, en: String, fx: String, art: String }
    public struct Stage: Sendable { public var color: String; public var stops: [String]; public var ends: [Bool] }

    public let atlas: OverlayAtlas
    public let dfont: [String: [String]]
    public let dstyle: [String: DStyle]
    public let glyph: [String: [String]]
    public let iconPal: [String: String]
    public let ramps: [[String]]
    public let rampOf: [String: (Int, Int)]
    public let bossInfo: [String: BossInfo]
    public let bossLines: [String: String]
    public let spc: [String: Special]
    public let famColor: [String: String]
    /// 역 id → 노선도 머리글(웹 STN[id].h || cap)
    public let stationCap: [String: String]
    public let stages: [Stage]
    /// 웹 SW_T(기술 → 충격파 단계) · SWP(단계 → 모양)
    public let swTier: [String: Int]
    public let swShape: [Int: (r0: Double, r1: Double, w: Double, amp: Double, dark: Double, life: Double)]
    /// 웹 ATK_FEEL[anim].w · FOE_W
    public let atkWeight: [String: String]
    public let foeW: [String: String]
    /// 웹 SIG 의 효과 종류 → 반지름(같은 종류는 처음 것)
    public let sigR: [String: Double]
    public static let skinAcc: [String: String] = ["gala": "#ffd36a", "rain": "#8fd0ff", "chicago": "#ff6a5a"]

    public init(store: ContentStore, atlas: OverlayAtlas = OverlayAtlas()) throws {
        self.atlas = atlas
        func obj(_ k: String) throws -> [String: JSONValue] { try store.raw(k).object ?? [:] }
        func strs(_ v: JSONValue?) -> [String] { v?.array?.compactMap(\.string) ?? [] }
        dfont = try obj("DFONT").mapValues(strs)
        dstyle = try obj("DSTYLE").mapValues { DStyle(s: $0["s"]?.int ?? 2, r: strs($0["r"]), o: $0["o"]?.string ?? "#000") }
        glyph = try obj("GLYPH").mapValues(strs)
        iconPal = try obj("ICON_PAL").compactMapValues(\.string)
        ramps = try store.raw("RAMPS").array?.map(strs) ?? []
        var ro: [String: (Int, Int)] = [:]
        for (ri, r) in ramps.enumerated() { for (ci, c) in r.enumerated() where ro[c] == nil { ro[c] = (ri, ci) } }
        rampOf = ro
        bossInfo = try obj("BOSS_INFO").mapValues { BossInfo(n: $0["n"]?.string ?? "", nick: $0["nick"]?.string ?? "", col: $0["col"]?.string ?? "#fff", rage: $0["rage"]?.string ?? "") }
        bossLines = try obj("BOSS_LINES").compactMapValues(\.string)
        spc = try obj("SPC").mapValues { Special(n: $0["n"]?.string ?? "", en: $0["en"]?.string ?? "", fx: $0["fx"]?.string ?? "", art: $0["art"]?.string ?? "fist:x") }
        famColor = try obj("FAMS").compactMapValues { $0["c"]?.string }
        stationCap = try obj("STN").compactMapValues { $0["h"]?.string ?? $0["cap"]?.string }
        stages = (try store.raw("STAGES").array ?? []).map { s in
            let line = s["line"]?.array ?? []
            return Stage(color: s["color"]?.string ?? "#ffb547", stops: [s["start"]?.string ?? ""] + line.map { $0["stop"]?.string ?? "" },
                         ends: line.map { $0["end"]?.bool ?? false })
        }
        swTier = try obj("SW_T").compactMapValues(\.int).merging(NativeContent.swTier) { a, _ in a }   // 네이티브 기술(새 이름만 — 웹 대조 불변)
        var sp: [Int: (Double, Double, Double, Double, Double, Double)] = [:]
        for (k, v) in try obj("SWP") {
            if let t = Int(k) { sp[t] = (v["r0"]?.double ?? 0, v["r1"]?.double ?? 0, v["w"]?.double ?? 0, v["amp"]?.double ?? 0, v["dark"]?.double ?? 0, v["life"]?.double ?? 0.1) }
        }
        swShape = sp.mapValues { (r0: $0.0, r1: $0.1, w: $0.2, amp: $0.3, dark: $0.4, life: $0.5) }
        atkWeight = try obj("ATK_FEEL").compactMapValues { $0["w"]?.string }.merging(NativeContent.atkWeight) { a, _ in a }
        foeW = try obj("FOE_W").compactMapValues(\.string)
        var sr: [String: Double] = [:]
        for (_, v) in (try obj("SIG")).sorted(by: { $0.key < $1.key }) { if let k = v["k"]?.string, sr[k] == nil { sr[k] = v["r"]?.double ?? 72 } }
        sigR = sr
    }

    // MARK: 피해 숫자 글리프(웹 dGlyph)

    /// 웹 dGlyph(ch, st): (5s+2)×(7s+2) — 3단 색 · 윗면 흰 줄 · 1px 외곽선
    public func dGlyph(_ ch: Character, _ st: String) -> OverlayAtlas.Entry? {
        let k = "dg|\(st)|\(ch)"
        return atlas.entry(k) {
            guard let S = dstyle[st] ?? dstyle["hit"], let g = dfont[String(ch)] else { return nil }
            let s = S.s, w = 5 * s + 2, h = 7 * s + 2
            func on(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < 5 && y < 7 && Array(g[y])[x] == "#" }
            func fl(_ a: Int, _ b: Int) -> Int { Int((Double(a) / Double(b)).rounded(.down)) }
            var px = [UInt8](repeating: 0, count: w * h * 4)
            func put(_ x: Int, _ y: Int, _ c: String) { let q = RGBA(css: c), o = (y * w + x) * 4; px[o] = UInt8((q.r * 255).rounded()); px[o + 1] = UInt8((q.g * 255).rounded()); px[o + 2] = UInt8((q.b * 255).rounded()); px[o + 3] = 255 }
            for y in 0..<h { for x in 0..<w {
                let gx = fl(x - 1, s), gy = fl(y - 1, s)
                if x >= 1 && y >= 1 && on(gx, gy) {
                    let tone = gy < 2 ? 0 : gy < 5 ? 1 : 2
                    var c = S.r[tone]
                    if !on(gx, gy - 1) && (y - 1) % s == 0 { c = "#ffffff" }
                    put(x, y, c)
                } else {
                    var n = false
                    for dy in -1...1 where !n { for dx in -1...1 {
                        let xx = x + dx, yy = y + dy
                        if xx >= 1 && yy >= 1 && on(fl(xx - 1, s), fl(yy - 1, s)) { n = true; break }
                    } }
                    if n { put(x, y, S.o) }
                }
            } }
            return (w, h, px)
        }
    }

    // MARK: 컷인 원화(웹 46-cutin cutArt)

    /// 웹 cutArt(k0) — 'face:hero_strain' · 'eyes:hero' · 'rage:boss' · 'fist:x' · 'shoe:x'. skin = OPT.skin, shades = OPT.shades
    public func cutArt(_ k0: String, skin: String = "jw", shades: Bool = false) -> OverlayAtlas.Entry? {
        let hero = k0.contains("hero")
        let key = "art|" + k0 + (shades && hero ? "|s" : "") + (hero && skin != "jw" ? "|" + skin : "")
        return atlas.entry(key) {
            let parts = k0.split(separator: ":", maxSplits: 1).map(String.init)
            let a = parts[0], b = parts.count > 1 ? parts[1] : ""
            var P = PixelArt(self, skin: skin, shades: shades)
            var buf: PixelArt.Buf
            switch a {
            case "face": buf = P.portrait(b)
            case "eyes": buf = P.eyesClose(b, rage: false)
            case "rage": buf = P.eyesClose(b, rage: true)
            case "fist": buf = P.fistClose()
            default: buf = P.shoeClose()
            }
            var px = P.rgba(buf)
            if a == "eyes" && b == "hero" && (skin == "rain" || skin == "chicago") {   // 중절모 챙 그림자
                let h0 = Int((Double(buf.H) * 0.16).rounded())
                let c1 = RGBA(css: skin == "rain" ? "#3a2a1c" : "#16161c"), c2 = RGBA(css: skin == "rain" ? "#5c4630" : "#2c2c36")
                func fill(_ y0: Int, _ y1: Int, _ c: RGBA) { for y in y0..<y1 { for x in 0..<buf.W { let o = (y * buf.W + x) * 4; px[o] = UInt8((c.r * 255).rounded()); px[o + 1] = UInt8((c.g * 255).rounded()); px[o + 2] = UInt8((c.b * 255).rounded()); px[o + 3] = 255 } } }
                fill(0, h0, c1); fill(h0, h0 + 1, c2)
            }
            return (buf.W, buf.H, px)
        }
    }
}

/// 웹 pBuf · drawFace · heroMood · portrait · eyesClose · fistClose · shoeClose · skinFace · shades64 · pShade · pOutline 그대로(정수 · Math.round 의미까지)
struct PixelArt {
    struct Buf { var W: Int, H: Int; var a: [String?]; var fx: [Bool] }
    let art: HUDArt
    let skin: String, shades: Bool
    init(_ art: HUDArt, skin: String, shades: Bool) { self.art = art; self.skin = skin; self.shades = shades }

    static func jsRound(_ v: Double) -> Int { Int((v + 0.5).rounded(.down)) }

    static func buf(_ W: Int, _ H: Int) -> Buf { Buf(W: W, H: H, a: Array(repeating: nil, count: W * H), fx: Array(repeating: false, count: W * H)) }

    // 그리기 원시(웹 pBuf 안 함수)
    static func set(_ b: inout Buf, _ x0: Double, _ y0: Double, _ c: String, _ keep: Bool = false) {
        let x = jsRound(x0), y = jsRound(y0)
        if x >= 0 && y >= 0 && x < b.W && y < b.H { b.a[y * b.W + x] = c; b.fx[y * b.W + x] = keep }
    }
    static func get(_ b: Buf, _ x: Int, _ y: Int) -> String? { (x < 0 || y < 0 || x >= b.W || y >= b.H) ? nil : b.a[y * b.W + x] }
    static func rect(_ b: inout Buf, _ x: Double, _ y: Double, _ w: Int, _ h: Int, _ c: String, _ k: Bool = false) {
        for j in 0..<max(0, h) { for i in 0..<max(0, w) { set(&b, x + Double(i), y + Double(j), c, k) } }
    }
    static func ell(_ b: inout Buf, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: String, _ k: Bool = false) {
        var y = -ry
        while y <= ry {
            var x = -rx
            while x <= rx { if (x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1 { set(&b, cx + x, cy + y, c, k) }; x += 1 }
            y += 1
        }
    }
    static func line(_ b: inout Buf, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: String, _ k: Bool = false, _ th: Int = 1) {
        var n = Int(max(abs(x1 - x0), abs(y1 - y0)).rounded(.up)); if n == 0 { n = 1 }
        for s in 0...n {
            let x = x0 + (x1 - x0) * Double(s) / Double(n), y = y0 + (y1 - y0) * Double(s) / Double(n)
            for i in 0..<th { for j in 0..<th { set(&b, x + Double(i - (th >> 1)), y + Double(j - (th >> 1)), c, k) } }
        }
    }
    static func poly(_ b: inout Buf, _ pts: [(Double, Double)], _ c: String, _ k: Bool = false) {
        let ys = pts.map(\.1)
        var y = Int(ys.min()!.rounded(.down))
        let yEnd = Int(ys.max()!.rounded(.up))
        while y <= yEnd {
            var xs: [Double] = []
            let yy = Double(y) + 0.5
            for i in 0..<pts.count {
                let (ax, ay) = pts[i], (bx, by) = pts[(i + 1) % pts.count]
                if (ay <= yy && by > yy) || (by <= yy && ay > yy) { xs.append(ax + (yy - ay) * (bx - ax) / (by - ay)) }
            }
            xs.sort()
            var i = 0
            while i + 1 < xs.count {
                var x = jsRound(xs[i]); let xe = jsRound(xs[i + 1])
                while x < xe { set(&b, Double(x), Double(y), c, k); x += 1 }
                i += 2
            }
            y += 1
        }
    }

    // 망점 음영 · 잉크 외곽선
    func shade(_ b: inout Buf, lx: Int = -1, ly: Int = -1) {
        let src = b.a, W = b.W, H = b.H
        for y in 0..<H { for x in 0..<W {
            guard let c = src[y * W + x], !b.fx[y * W + x], let (ri, ci) = art.rampOf[c] else { continue }
            let R = art.ramps[ri]
            func out(_ dx: Int, _ dy: Int) -> Bool {
                let q: String? = (x + dx < 0 || y + dy < 0 || x + dx >= W || y + dy >= H) ? nil : src[(y + dy) * W + x + dx]
                guard let q, let r = art.rampOf[q] else { return true }
                return r.0 != ri
            }
            if out(lx, ly) || out(0, ly) { b.a[y * W + x] = R[min(R.count - 1, ci + 1)] }
            else if out(-lx, -ly) || out(0, -ly) || out(-lx, 0) { b.a[y * W + x] = R[max(0, ci - 1)] }
            else if ((x + y) & 1) == 0 && ci > 0 && (Double(x) / Double(W) + Double(y) / Double(H)) > 1.05 { b.a[y * W + x] = R[ci - 1] }
        } }
    }
    static func outline(_ b: inout Buf) {
        var o = b.a
        for y in 0..<b.H { for x in 0..<b.W {
            if b.a[y * b.W + x] != nil { continue }
            if [(1, 0), (-1, 0), (0, 1), (0, -1)].contains(where: { d in if let c = get(b, x + d.0, y + d.1) { return c != "K" } else { return false } }) { o[y * b.W + x] = "K" }
        } }
        b.a = o
    }
    func rgba(_ b: Buf) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: b.W * b.H * 4)
        for i in 0..<(b.W * b.H) {
            guard let c = b.a[i], let hex = art.iconPal[c] else { continue }
            let q = RGBA(css: hex)
            px[i * 4] = UInt8((q.r * 255).rounded()); px[i * 4 + 1] = UInt8((q.g * 255).rounded()); px[i * 4 + 2] = UInt8((q.b * 255).rounded()); px[i * 4 + 3] = 255
        }
        return px
    }

    struct Face {
        var hair: String? = nil, jaw: Double? = nil, brow: Double? = nil, coat: String? = nil, tie: String? = nil
        var stubble = false, scar = false, hat: String? = nil, chops = false, iris: String? = nil, smirk = false
        var collar: String? = nil, mustache = false, silver = false, glare = false
    }

    // 얼굴 틀(64×64)
    func drawFace(_ b: inout Buf, _ P: Face) {
        typealias S = PixelArt
        let cx = 32.0, cy = 30.0, rx = (P.jaw ?? 0) != 0 ? P.jaw! : 14, ry = 18.0, coat = P.coat ?? "n"
        S.poly(&b, [(4, 64), (10, 50), (22, 46), (42, 46), (54, 50), (60, 64)], coat)
        if P.collar == "mandarin" {
            S.poly(&b, [(24, 44), (40, 44), (41, 51), (23, 51)], coat); S.line(&b, 32, 46, 32, 63, "C", true)
            for y in [52.0, 56, 60] { S.rect(&b, 31, y, 2, 2, "Y", true) }
        } else {
            S.poly(&b, [(25, 45), (39, 45), (32, 58)], "w", true); S.poly(&b, [(30, 48), (34, 48), (35, 62), (32, 64), (29, 62)], P.tie ?? "N", true)
            S.poly(&b, [(22, 46), (30, 47), (27, 60)], coat == "n" ? "m" : coat); S.poly(&b, [(42, 46), (34, 47), (37, 60)], coat)
        }
        S.rect(&b, 27, 40, 10, 7, "S"); S.ell(&b, cx, cy, rx, ry, "s"); S.poly(&b, [(cx - rx + 2, cy + 6), (cx + rx - 2, cy + 6), (cx + 4, cy + ry + 1), (cx - 6, cy + ry)], "s")
        S.ell(&b, cx - rx + 1, cy + 2, 3, 5, "s"); S.line(&b, cx - rx + 1, cy, cx - rx + 1, cy + 4, "S", true)
        if P.hair == "slick" {
            S.poly(&b, [(cx - rx - 1, cy - 2), (cx - rx + 1, cy - 15), (cx - 4, cy - 21), (cx + 10, cy - 20), (cx + rx + 1, cy - 12), (cx + rx - 2, cy - 6), (cx + 2, cy - 11), (cx - 8, cy - 9), (cx - rx + 3, cy + 1)], "N")
            for k in 0..<5 { S.line(&b, cx - 10 + Double(k * 4), cy - 18, cx - 2 + Double(k * 5), cy - 12, "n", true) }
        }
        if P.silver { for (x0, y0) in [(cx - rx + 1, cy - 6), (cx - rx + 2, cy - 10), (cx + rx - 3, cy - 8)] { S.line(&b, x0, y0, x0 + 3, y0 - 4, "W", true, 2) } }
        if P.hair == "crop" {
            S.poly(&b, [(cx - rx, cy - 6), (cx - rx + 3, cy - 16), (cx + 6, cy - 20), (cx + rx, cy - 13), (cx + rx - 1, cy - 9), (cx - rx + 3, cy - 4)], "N")
            var x = cx - rx + 3
            while x < cx + rx { S.set(&b, x, cy - 15 + jsMod(x, 3), "n", true); x += 2 }
        }
        if P.hat == "tophat" {
            S.rect(&b, cx - 12, cy - 36, 24, 20, "N"); S.rect(&b, cx - 17, cy - 17, 34, 3, "N"); S.rect(&b, cx - 12, cy - 21, 24, 3, "x")
            for gx in [cx - 7, cx + 5] { S.ell(&b, gx, cy - 21, 3, 3, "Y"); S.ell(&b, gx, cy - 21, 1.6, 1.6, "l", true) }
        }
        if P.chops {
            S.poly(&b, [(cx - rx + 1, cy + 2), (cx - rx + 5, cy + 2), (cx - rx + 6, cy + 14), (cx - rx + 2, cy + 12)], "x")
            S.poly(&b, [(cx + rx - 5, cy + 2), (cx + rx - 1, cy + 2), (cx + rx - 2, cy + 12), (cx + rx - 6, cy + 14)], "x")
            S.poly(&b, [(cx - 6, cy + 9), (cx + 8, cy + 9), (cx + 6, cy + 12), (cx - 4, cy + 12)], "x")
        }
        let by = cy - 3, ang = P.brow ?? 2.5
        S.line(&b, cx - 10, by - 1, cx - 3, by + ang * 0.6, "N", true, 2); S.line(&b, cx + 3, by + ang * 0.6, cx + 11, by - 1, "N", true, 2)
        for ex in [cx - 7, cx + 7] {
            S.rect(&b, ex - 3, by + 3, 7, 3, "h", true); S.rect(&b, ex - 1, by + 3, 3, 3, P.iris ?? "N", true); S.set(&b, ex, by + 3, "h", true)
            S.line(&b, ex - 3, by + 2, ex + 3, by + 2, "K", true); S.line(&b, ex - 2, by + 6, ex + 3, by + 6, "S", true)
        }
        if P.glare { for ex in [cx - 7, cx + 7] { S.rect(&b, ex - 1, by + 4, 3, 1, "r", true) } }
        S.line(&b, cx + 1, by + 4, cx + 3, cy + 8, "S", true); S.line(&b, cx - 1, cy + 9, cx + 4, cy + 9, "z", true)
        S.line(&b, cx - 5, cy + 13, cx + 6, cy + 12 + (P.smirk ? -1 : 1), "z", true); S.set(&b, cx - 5, cy + 14, "z", true)
        if P.stubble {
            var y = cy + 9
            while y < cy + ry {
                var x = cx - rx + 3
                while x < cx + rx - 2 {
                    if jsMod(x * 7 + y * 3, 5) == 0 && S.get(b, Int(x), Int(y)) == "s" { S.set(&b, x, y, "S", true) }
                    x += 1
                }
                y += 1
            }
        }
        if P.scar { S.line(&b, cx + 5, by - 4, cx + 10, by + 10, "w", true); S.line(&b, cx + 6, by - 4, cx + 11, by + 10, "S", true) }
        if P.mustache { S.poly(&b, [(cx - 5, cy + 11), (cx + 7, cy + 11), (cx + 5, cy + 12), (cx - 3, cy + 12)], "N", true) }
    }
    func jsMod(_ a: Double, _ m: Double) -> Double { a.truncatingRemainder(dividingBy: m) }

    func heroMood(_ b: inout Buf, _ m: String) {
        typealias S = PixelArt
        let cx = 32.0, cy = 30.0, by = 27.0, L = cx - 7, Rr = cx + 7
        func sweat(_ x: Double, _ y: Double) { S.set(&b, x, y, "l", true); S.set(&b, x, y + 1, "l", true); S.set(&b, x - 1, y + 2, "b", true); S.set(&b, x, y + 2, "l", true) }
        func brows(_ a: Double) { S.line(&b, cx - 10, by - 1 - a * 0.3, cx - 3, by + a * 0.6, "N", true, 2); S.line(&b, cx + 3, by + a * 0.6, cx + 11, by - 1 - a * 0.3, "N", true, 2) }
        func teeth() {
            S.rect(&b, cx - 5, cy + 11, 11, 3, "h", true)
            var x = cx - 4; while x <= cx + 5 { S.set(&b, x, cy + 12, "W", true); x += 2 }
            S.line(&b, cx - 5, cy + 10, cx + 5, cy + 10, "K", true); S.line(&b, cx - 5, cy + 14, cx + 5, cy + 14, "K", true)
        }
        func shut(_ ex: Double, _ dir: Double) { S.rect(&b, ex - 3, by + 2, 7, 5, "s", true); S.line(&b, ex - 3 * dir, by + 3, ex, by + 4, "K", true); S.line(&b, ex, by + 4, ex - 3 * dir, by + 5, "K", true) }
        if m == "strain" || m == "hurt" || m == "crit" { brows(m == "crit" ? 4.5 : 4); teeth(); sweat(cx + 12, by - 2) }
        if m == "hurt" || m == "crit" {
            S.rect(&b, L - 3, by + 2, 7, 5, "s", true); S.line(&b, L - 3, by + 4, L + 3, by + 5, "K", true); S.line(&b, L - 2, by + 3, L + 2, by + 3, "S", true)
            S.line(&b, cx - 9, by - 3, cx - 5, by - 1, "r", true); S.set(&b, cx - 7, by, "R", true); S.set(&b, cx - 7, by + 1, "R", true)
            S.ell(&b, cx + 9, cy + 5, 2.5, 2, "S", true); S.set(&b, cx + 9, cy + 5, "P", true); S.set(&b, cx + 10, cy + 6, "z", true); S.line(&b, cx + 2, cy + 10, cx + 2, cy + 12, "R", true)
        }
        if m == "crit" {
            var a = 0.0
            while a < .pi * 2 { S.set(&b, Double(S.jsRound(Rr + cos(a) * 5)), Double(S.jsRound(by + 4 + sin(a) * 3.2)), S.jsRound(a * 5) % 2 != 0 ? "P" : "z", true); a += 0.2 }
            S.rect(&b, Rr - 3, by + 2, 7, 2, "S", true); S.line(&b, Rr - 3, by + 4, Rr + 3, by + 4, "K", true); S.ell(&b, cx, cy + 12, 3.5, 2.2, "K", true); S.rect(&b, cx - 2, cy + 10, 5, 1, "h", true); S.line(&b, cx + 4, cy + 12, cx + 5, cy + 16, "R", true)
            S.line(&b, cx - 2, cy - 14, cx - 5, by - 1, "N", true); S.line(&b, cx + 3, cy - 14, cx + 1, by, "N", true); S.line(&b, cx + 6, cy - 13, cx + 6, by - 2, "n", true); sweat(cx - 13, by); sweat(cx + 13, cy + 4)
        }
        if m == "flinch" {
            brows(5); shut(L, 1); shut(Rr, -1); S.rect(&b, cx - 5, cy + 10, 11, 4, "K", true); S.rect(&b, cx - 4, cy + 10, 9, 1, "h", true); S.rect(&b, cx - 4, cy + 13, 9, 1, "h", true); sweat(cx + 12, by - 3)
        }
        if m == "shout" {
            brows(5.5)
            for ex in [L, Rr] { S.rect(&b, ex - 3, by + 2, 7, 4, "h", true); S.rect(&b, ex - 1, by + 3, 2, 2, "N", true); S.line(&b, ex - 3, by + 1, ex + 3, by + 1, "K", true) }
            S.ell(&b, cx, cy + 12, 4.5, 3.4, "K", true); S.rect(&b, cx - 3, cy + 9, 7, 1, "h", true); S.ell(&b, cx, cy + 14, 2.2, 1.2, "R", true)
        }
    }

    func skinFace(_ b: inout Buf) {
        typealias S = PixelArt
        let k = skin, cx = 32.0, cy = 30.0
        if k == "jw" { return }
        if k == "gala" {
            S.poly(&b, [(22, 46), (30, 47), (27, 60)], "N"); S.poly(&b, [(42, 46), (34, 47), (37, 60)], "N"); S.poly(&b, [(25, 45), (39, 45), (32, 56)], "w", true)
            S.poly(&b, [(26, 47), (31, 49), (26, 52)], "N", true); S.poly(&b, [(38, 47), (33, 49), (38, 52)], "N", true); S.rect(&b, 31, 48, 2, 3, "N", true); S.poly(&b, [(45, 53), (49, 52), (48, 56)], "r", true)
        }
        if k == "rain" { S.poly(&b, [(15, 49), (24, 41), (27, 50), (19, 57)], "C"); S.poly(&b, [(49, 49), (40, 41), (37, 50), (45, 57)], "C") }
        if k == "chicago" { for x in [8.0, 13, 18, 46, 51, 56] { S.line(&b, x, 51, x + (x < 32 ? -1 : 1), 63, "W", true) } }
        if k == "rain" || k == "chicago" {
            let hc = k == "rain" ? "x" : "N", bc = k == "rain" ? "N" : "w"
            S.poly(&b, [(cx - 13, cy - 14), (cx - 11, cy - 26), (cx - 3, cy - 29), (cx + 3, cy - 27), (cx + 10, cy - 28), (cx + 12, cy - 14)], hc); S.line(&b, cx - 1, cy - 28, cx + 1, cy - 21, "N", true)
            S.rect(&b, cx - 12, cy - 18, 25, 3, bc); S.poly(&b, [(cx - 21, cy - 15), (cx + 21, cy - 15), (cx + 17, cy - 11), (cx - 17, cy - 11)], hc); S.line(&b, cx - 17, cy - 11, cx + 17, cy - 11, "N", true)
        }
    }

    func shades64(_ b: inout Buf, _ m: String?) {
        typealias S = PixelArt
        let by = 27.0, L = 25.0, Rr = 39.0
        for (x0, x1) in [(L - 5, L + 4), (Rr - 4, Rr + 5)] {
            S.rect(&b, x0, by + 1, Int(x1 - x0 + 1), 6, "K", true); S.rect(&b, x0 + 1, by + 7, Int(x1 - x0 - 1), 1, "K", true); S.line(&b, x0, by, x1, by, "N", true)
            S.set(&b, x0 + 1, by + 2, "h", true); S.set(&b, x0 + 2, by + 2, "h", true); S.line(&b, x0 + 4, by + 5, x0 + 7, by + 2, "l", true)
        }
        S.line(&b, L + 5, by + 2, Rr - 5, by + 2, "N", true); S.line(&b, L - 6, by + 2, L - 8, by + 1, "N", true); S.line(&b, Rr + 6, by + 2, Rr + 8, by + 1, "N", true)
        if m == "crit" { S.line(&b, L - 3, by + 2, L, by + 4, "h", true); S.line(&b, L, by + 4, L - 1, by + 6, "h", true) }
    }

    mutating func portrait(_ kind: String) -> Buf {
        let sp = kind.split(separator: "_", maxSplits: 1).map(String.init)
        let base = sp[0], mood = sp.count > 1 ? sp[1] : nil
        var b = PixelArt.buf(64, 64)
        var P: Face
        switch base {
        case "hero": P = Face(hair: "slick", jaw: 13, brow: 2.8, coat: "n", tie: "N")
        case "boss": P = Face(hair: "crop", jaw: 16, brow: 3.4, coat: "C", tie: "N", stubble: true, scar: true)
        case "boss2": P = Face(jaw: 16, brow: 3, coat: "x", hat: "tophat", chops: true, iris: "y", smirk: true)
        case "boss3": P = Face(hair: "slick", jaw: 12, brow: 3.6, coat: "w", iris: "N", collar: "mandarin", mustache: true, silver: true)
        case "boss4": P = Face(hair: "crop", jaw: 14, brow: 3, coat: "p", tie: "b", stubble: true, iris: "e", smirk: true)
        case "kaneB": P = Face(hair: "slick", jaw: 12, brow: 3.2, coat: "w", tie: "r", scar: true, iris: "N", smirk: true, silver: true)
        case "mgr": P = Face(hair: "crop", jaw: 17, brow: 3.6, coat: "C", tie: "y", stubble: true, mustache: true)
        case "headchef": P = Face(hair: "crop", jaw: 16, brow: 3.4, coat: "w", tie: "r", stubble: true, mustache: true)
        default: P = Face(hair: "crop", jaw: 14, brow: 3, coat: "n")
        }
        if base == "hero" {
            switch skin { case "gala": P.coat = "w"; P.tie = "w"; case "rain": P.coat = "C"; P.tie = "x"; case "chicago": P.tie = "r"; default: break }
            if mood == nil { P.smirk = true }
        }
        drawFace(&b, P)
        if base == "hero" { skinFace(&b) }
        if let mood { heroMood(&b, mood) }
        if base == "hero" && shades { shades64(&b, mood) }
        shade(&b); PixelArt.outline(&b)
        return b
    }

    func eyesClose(_ kind: String, rage: Bool) -> Buf {
        typealias S = PixelArt
        var b = S.buf(96, 36); S.rect(&b, 0, 0, 96, 36, "s")
        if kind == "boss2" { S.rect(&b, 0, 0, 96, 7, "N"); S.rect(&b, 0, 7, 96, 3, "x"); for gx in [30.0, 66] { S.ell(&b, gx, 8, 7, 5, "Y"); S.ell(&b, gx, 8, 4, 3, "l", true) } }
        else { S.poly(&b, [(0, 0), (96, 0), (96, 6), (70, 4), (48, 7), (20, 3), (0, 8)], "N") }
        let ang = rage ? 6.0 : 4
        S.line(&b, 10, 12, 42, 12 + ang, "N", true, 4); S.line(&b, 54, 12 + ang, 86, 12, "N", true, 4)
        for ex in [26.0, 70] {
            let l = ex < 48
            S.ell(&b, ex, 23, 13, 5, "h", true); S.ell(&b, ex + (l ? 3 : -3), 23, 5, 5, rage ? "r" : "N", true); S.ell(&b, ex + (l ? 3 : -3), 23, 2, 2, "K", true)
            S.set(&b, ex + (l ? 1 : -5), 21, "h", true); S.set(&b, ex + (l ? 2 : -4), 21, "h", true)
            S.line(&b, ex - 14, 18, ex + 14, 17, "K", true, 2); S.line(&b, ex - 12, 29, ex + 12, 29, "S", true)
            if rage { S.line(&b, ex - 10, 22, ex - 6, 24, "r", true); S.line(&b, ex + 8, 24, ex + 11, 22, "r", true) }
        }
        S.line(&b, 47, 20, 49, 35, "S", true); if rage { S.line(&b, 46, 6, 44, 11, "R", true); S.line(&b, 50, 6, 52, 11, "R", true) }
        if kind == "hero" && !rage && shades {
            for ex in [26.0, 70] {
                S.ell(&b, ex, 23, 15, 8, "K", true); S.line(&b, ex - 15, 15, ex + 15, 15, "N", true, 2); S.line(&b, ex - 9, 27, ex - 2, 19, "l", true, 2); S.line(&b, ex - 4, 29, ex + 1, 24, "l", true)
                S.set(&b, ex - 10, 18, "h", true); S.set(&b, ex - 9, 18, "h", true)
            }
            S.line(&b, 41, 19, 55, 19, "N", true, 2); S.line(&b, 10, 17, 2, 15, "N", true, 2); S.line(&b, 86, 17, 94, 15, "N", true, 2)
        }
        shade(&b); S.outline(&b)
        return b
    }

    func fistClose() -> Buf {
        typealias S = PixelArt
        var b = S.buf(56, 56); S.poly(&b, [(0, 56), (0, 36), (18, 30), (22, 56)], "n"); S.rect(&b, 10, 30, 14, 8, "w")
        S.poly(&b, [(16, 8), (46, 6), (52, 14), (52, 36), (44, 44), (18, 44), (12, 32)], "s"); for x in [24.0, 32, 40] { S.line(&b, x, 8, x, 24, "S", true) }; S.line(&b, 16, 24, 50, 24, "S", true)
        for x in [18.0, 26, 34, 42] { S.rect(&b, x, 9, 6, 3, "h", true) }; S.poly(&b, [(12, 26), (26, 24), (28, 36), (14, 38)], "S")
        var y = 33.0; while y < 45 { S.line(&b, 18, y, 46, y + 1, "W", true); y += 3 }
        shade(&b); S.outline(&b)
        return b
    }

    func shoeClose() -> Buf {
        typealias S = PixelArt
        var b = S.buf(64, 48); S.poly(&b, [(0, 0), (18, 0), (22, 20), (6, 24)], "n"); S.poly(&b, [(6, 18), (40, 14), (58, 22), (62, 32), (60, 38), (8, 40)], "N")
        S.poly(&b, [(30, 16), (44, 16), (54, 22), (30, 24)], "n"); for x in [32.0, 37, 42] { S.line(&b, x, 18, x + 4, 21, "w", true) }; S.rect(&b, 6, 38, 56, 5, "G"); S.rect(&b, 6, 38, 12, 6, "x"); S.line(&b, 18, 26, 52, 24, "h", true)
        shade(&b); S.outline(&b)
        return b
    }
}
