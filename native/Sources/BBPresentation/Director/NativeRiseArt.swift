import Foundation
import BBCore
import BBContent
import BBSim

// 네이티브 퇴근 승천권 무대 픽셀(docs/07 §7-R · SimConfig.nativeMoves 켜짐에서만 값이 생긴다) — 지붕 구멍 · 종이 회오리.
// 오버레이(벡터)가 아니라 무대 G-버퍼 3D 층에 1px 쿼드로 쌓는다(정점 10 float = MeshWriter 와 같음) → 카메라 · 흔들림 · 조명 · 팔레트 램프 · 디더를 무대와 함께 받는다.
//  · 무대 픽셀(부위 −1): meshFS 가 배경 스프라이트와 같은 G-버퍼 값(마스크 0.5 · 층 깊이)을 쓴다 — 천장 띠를 그대로 베껴 그려도 이음매가 없다
//  · 깊이(GL z): 인물 ≈ 0.9 − 발y/300 ± 0.04 · 천장 앞 입술 0.45 · 뚫고 나가는 몸 +0.6(≈ 0.76) · 구멍 속 · 뒤 철판 0.97
//  · 모양 난수는 구멍 · 회오리마다 씨앗으로 매 프레임 새로 뽑는다(상태 없음 — 나이만으로 그린다 · 결정적)

/// 무대 픽셀 쌓기
struct PixelMesh {
    var f: [Float] = []
    /// 가로 w 칸 한 줄(한 쿼드)
    mutating func run(_ x: Int, _ y: Int, _ w: Int, mat: Int, tone: Double, z: Double, d: Double, emit: Double = 0, part: Double = -1, nx: Double = 0, ny: Double = 0) {
        guard w > 0 else { return }
        let x0 = Float(x), x1 = Float(x + w), y0 = Float(y), y1 = Float(y + 1)
        let t: [Float] = [Float(nx), Float(ny), Float(tone), Float(mat), Float(part), Float(d), Float(emit)]
        for (px, py) in [(x0, y0), (x1, y0), (x1, y1), (x0, y0), (x1, y1), (x0, y1)] { f.append(px); f.append(py); f.append(Float(z)); f.append(contentsOf: t) }
    }
}

/// 한 픽셀 값(캔버스)
struct ArtPx: Equatable {
    var mat: Int, tone: Double, z: Double, d = 0.3, emit = 0.0, part = -1.0, nx = 0.0, ny = 0.0
}

/// 픽셀 캔버스: 나중에 찍은 것이 이긴다(가까운 층을 나중에 찍는다) → 같은 값이 이어지는 가로 줄로 묶어 내보낸다
struct ArtCanvas {
    var px: [Int: ArtPx] = [:]
    static func key(_ x: Int, _ y: Int) -> Int { (y + 512) * 4096 + (x + 1024) }
    subscript(x: Int, y: Int) -> ArtPx? {
        get { px[Self.key(x, y)] }
        set { px[Self.key(x, y)] = newValue }
    }
    func flush(into m: inout PixelMesh) {
        var rows: [Int: [(Int, ArtPx)]] = [:]
        for (k, v) in px { rows[k / 4096 - 512, default: []].append((k % 4096 - 1024, v)) }
        for y in rows.keys.sorted() {
            let r = rows[y]!.sorted { $0.0 < $1.0 }
            var i = 0
            while i < r.count {
                var j = i + 1
                while j < r.count && r[j].0 == r[j - 1].0 + 1 && r[j].1 == r[i].1 { j += 1 }
                let p = r[i].1
                m.run(r[i].0, y, j - i, mat: p.mat, tone: p.tone, z: p.z, d: p.d, emit: p.emit, part: p.part, nx: p.nx, ny: p.ny)
                i = j
            }
        }
    }
}

/// 구멍 둘레에 다시 그릴 배경 스프라이트 픽셀(아틀라스 A · N 에서 객차 · 엘리베이터 칸 · 복도 천장만 뽑아 둔다 — 처음 한 번, 앱은 미리 데운다)
final class RoofSourcePixels: @unchecked Sendable {
    struct Img { let w: Int, h: Int; let a: [UInt8]; let n: [UInt8] }
    static let shared = RoofSourcePixels()
    private let lock = NSLock()
    private var imgs: [String: Img]?

    func image(_ name: String) -> Img? { load(); return imgs?[name] }
    /// 뒤에서 미리 풀어 둔다(첫 지붕 뚫기에 멈칫하지 않게)
    func warm() { DispatchQueue.global(qos: .utility).async { self.load() } }

    private func load() {
        lock.lock(); defer { lock.unlock() }
        if imgs != nil { return }
        var out: [String: Img] = [:]
        defer { imgs = out }
        guard let meta = try? AtlasMeta.bundled() else { return }
        let W = meta.atlas.width, H = meta.atlas.height
        var buf = [UInt8](repeating: 0, count: W * H * 4)   // A → N 차례로 한 버퍼에 푼다(잠깐 29MB 하나)
        let want = meta.sprites.filter { $0.key.hasPrefix("car_") || $0.key == "tw_cab" || $0.key == "cr_ceil" }
        func rowsOf(_ k: String, _ s: AtlasMeta.Sprite) -> Int { k.hasPrefix("car_") ? min(s.h, 16) : k == "tw_cab" ? min(s.h, 24) : s.h }
        func cut(_ k: String, _ s: AtlasMeta.Sprite) -> [UInt8] {
            let rows = rowsOf(k, s)
            var a = [UInt8](repeating: 0, count: s.w * rows * 4)
            for y in 0..<rows { let o = ((s.y + y) * W + s.x) * 4, d = y * s.w * 4; a.replaceSubrange(d..<d + s.w * 4, with: buf[o..<o + s.w * 4]) }
            return a
        }
        var As: [String: [UInt8]] = [:]
        do {
            try buf.withUnsafeMutableBytes { try RGBA8Image.decompress(meta.atlas.a, width: W, height: H, into: $0.baseAddress!) }
            for (k, s) in want { As[k] = cut(k, s) }
            try buf.withUnsafeMutableBytes { try RGBA8Image.decompress(meta.atlas.n, width: W, height: H, into: $0.baseAddress!) }
        } catch { return }
        for (k, s) in want { out[k] = Img(w: s.w, h: rowsOf(k, s), a: As[k]!, n: cut(k, s)) }
    }
}

/// 이번 프레임 승천권 무대 픽셀 · 빛
public struct NativeRiseLayer: Sendable {
    public var mesh: [Float] = []
    public var lights: [SceneLight] = []
    public var vols: [VolumeLight] = []
    /// 천장을 뚫고 나가는 몸 — 천장 앞 입술 뒤로 미는 깊이
    public var zBack: [ActorID: Double] = [:]
    public var isEmpty: Bool { mesh.isEmpty && lights.isEmpty && vols.isEmpty }
}

public enum NativeRiseArt {
    // 재질 번호(아틀라스 materials)
    static let INK = 1, SKY = 2, ARMOR = 6, DARK = 7, STEEL = 8, GOLD = 9, BONE = 10, RED = 12, EYE = 13, MOON = 15, CONC = 17, FRAME = 20, MDARK = 22, VAN = 29, WIRE = 30, CANVAS = 35, DUSK = 48
    static let zFront = 0.45, zBack = 0.97, zDebris = 0.3

    /// 천장 띠(무대 종류별) — top = 바깥 지붕 윗줄 y · rows = 띠 높이 · cut = 뚫린 깊이 · sheet = 바깥 철판 줄 수
    struct Band { var top: Int, rows: Int, cut: Int, sheet: Int, hw: Double; var src: (name: String, x: Int, y: Int, d: Double)? }

    static func band(_ h: RoofHole, _ hx: Int, _ bg: [SpriteDraw], dy: Double) -> Band? {
        switch h.kind {
        case "car":
            let c = bg.first { $0.name.hasPrefix("car_") && $0.x == 0 }
            let top = Int(jsRound(c?.y ?? 140 + dy))
            return Band(top: top, rows: 12, cut: 12, sheet: 4, hw: 13, src: c.map { ($0.name, Int($0.x), top, $0.depth) })
        case "hatch":
            let c = bg.first { $0.name == "tw_cab" }
            let top = Int(jsRound(c?.y ?? 88 + dy))
            return Band(top: top, rows: 15, cut: 13, sheet: 8, hw: 9, src: c.map { ($0.name, Int($0.x), top, $0.depth) })
        case "tile":
            let c = bg.first { $0.name == "cr_ceil" && Double(hx) >= $0.x && Double(hx) < $0.x + 240 }
            return Band(top: 24, rows: 20, cut: 18, sheet: 0, hw: 11, src: c.map { ($0.name, Int($0.x), Int($0.y), $0.depth) })
        default: return nil
        }
    }

    /// 프레임 조립(StageDirector.frame): 구멍 · 종이 회오리 · 빛. heads = 그린 인물 머리(장면 픽셀)
    public static func build(_ hud: HUDState, _ s: SimSnapshot, background bg: [SpriteDraw], sprites: [String: AtlasMeta.Sprite], heads: [ActorID: SIMD2<Double>], noFlash: Bool) -> NativeRiseLayer {
        var out = NativeRiseLayer()
        guard !hud.roofHoles.isEmpty || !hud.risePapers.isEmpty else { return out }
        var m = PixelMesh()
        for h in hud.roofHoles {
            // 구멍 바로 위에 보이는 바깥(그 자리를 덮는 배경 스프라이트로 고른다 — 노을 다리 · 고가 밤하늘 · 터널)
            func covers(_ d: SpriteDraw) -> Bool { guard let S = sprites[d.name] else { return false }; return h.x >= d.x && h.x < d.x + Double(S.w) && 120 >= d.y && 120 < d.y + Double(S.h) }
            let skyNames: Set<String> = ["br_sky", "el_sky", "q_sky", "sb_tunnelA", "sb_tunnelB", "sb_tunnel"]
            let hits: [String] = bg.filter(covers).map { $0.name }
            let over: String = hits.last { skyNames.contains($0) || $0.hasPrefix("sb_tunnel") } ?? ""
            let sky: Sky = s.tower != nil ? .shaft : s.prologue != nil ? .plenum : over == "br_sky" ? .dusk : (over == "el_sky" || over == "q_sky") ? .night : .tunnel
            hole(h, s, bg, sky, noFlash, &m, &out)
        }
        for p in hud.risePapers { paper(p, s, heads, &m) }
        out.mesh = m.f
        return out
    }

    enum Sky { case dusk, night, tunnel, shaft, plenum }

    // MARK: 지붕 구멍

    static func hole(_ h: RoofHole, _ s: SimSnapshot, _ bg: [SpriteDraw], _ sky: Sky, _ noFlash: Bool, _ m: inout PixelMesh, _ out: inout NativeRiseLayer) {
        let dy = s.trainShakeY
        let hx = Int(jsRound(h.x - ((s.prologue?.x ?? 0) - h.scroll0)))
        let age = h.age, f = h.f >= 0 ? 1 : -1
        let floorY = Int(jsRound(SB.FLOOR + dy)) - 1
        let shaftC: [Double] = sky == .dusk ? [1, 0.74, 0.5] : sky == .night ? [0.72, 0.84, 1] : [1, 0.86, 0.62]
        let burst = max(0, 1 - age / 0.9)
        let flick = age < 1.2 ? 0.85 + 0.15 * hash01(h.seed, Int(age * 14)) : 1
        if h.kind == "open" { return }   // 네이티브 눈 승강장: 지붕이 없다 — 구멍 · 빛줄기 없이 눈 내리는 하늘로 날아간다
        guard let B = band(h, hx, bg, dy: dy) else {   // 천장이 안 보이는 곳(무도장): 위에서 쏟아지는 빛줄기만 잠깐
            let k = max(0, 1 - age / 1.4)
            if k > 0 { out.vols.append(VolumeLight(x: Double(hx), y: 20, dx: 0, dy: 1, c: shaftC, i: 0.9 * k, cone: 0.94, len: 200, halo: 6)) }
            return
        }
        var rng = SplitMix64(seed: h.seed)
        func R() -> Double { rng.next() }
        let top = B.top, hatch = h.kind == "hatch", tile = h.kind == "tile"
        let pop = min(1, age / 0.06)   // 터지는 순간(철판이 0.06초에 젖혀진다)
        var C = ArtCanvas()

        // 1) 뚫린 모양: 거의 곧은 옆(줄마다 들쭉날쭉 ±1~2px) · 아래 가장자리는 칸마다 깊이가 다른 톱니
        var L = [Double](repeating: 0, count: B.cut), Rr = L
        for r in 0..<B.cut {
            let v = Double(r) / Double(max(1, B.cut - 1))
            let w = B.hw * (1 - (hatch ? 0.06 : 0.45) * v)
            L[r] = max(3, w + (R() * 2 - 1) * (hatch ? 0.5 : 1.6) + (r % 3 == 0 ? 1 : 0)); Rr[r] = max(3, w + (R() * 2 - 1) * (hatch ? 0.5 : 1.6) + (r % 4 == 1 ? 1 : 0))
        }
        var bot: [Int: Int] = [:], dep = 0.0
        for dx in -Int(B.hw) - 3...Int(B.hw) + 3 {   // 아래 가장자리: 찢긴 톱니(옆 칸과 이어지게 — 무작위 걸음)
            dep = max(-2, min(2, dep + (R() * 2 - 1) * 1.3))
            bot[dx] = B.cut - 1 - (hatch ? 0 : Int(jsRound(1.5 + dep + Double(abs(dx)) * 0.25)))
        }
        func inGap(_ dx: Int, _ r: Int) -> Bool {
            guard r >= 0 && r < B.cut, r <= (bot[dx] ?? -1) else { return false }
            return Double(dx) > -L[r] - 0.5 && Double(dx) < Rr[r] + 0.5
        }
        let W = Int(B.hw) + 10
        // 2) 천장 띠 앞 입술(지금 뚫고 나가는 몸 · 용 앞) — 객차 스프라이트 픽셀을 그대로 베껴 앞 깊이로
        let passing = age < 1.2
        if passing, let S = B.src, let img = RoofSourcePixels.shared.image(S.name) {
            for r in 0..<min(B.rows, img.h - (top - S.y)) {
                let sy = top - S.y + r
                guard sy >= 0 else { continue }
                for dx in -W...W {
                    let sx = hx + dx - S.x
                    guard sx >= 0 && sx < img.w else { continue }
                    let o = (sy * img.w + sx) * 4
                    guard img.a[o + 3] >= 128 else { continue }
                    let nx = Double(img.n[o]) / 255 * 2 - 1, ny = Double(img.n[o + 1]) / 255 * 2 - 1
                    C[hx + dx, top + r] = ArtPx(mat: Int(img.a[o]), tone: Double(img.a[o + 1]) / 255, z: zFront, d: S.d, emit: Double(img.a[o + 2]) / 255, nx: nx, ny: ny)
                }
            }
        }
        // 3) 구멍 속: 어둠 + 위쪽에 바깥(밤하늘 · 노을 · 터널 천장 · 승강로)이 디더로 비친다
        let skyMat = sky == .dusk ? DUSK : sky == .night ? SKY : sky == .shaft ? WIRE : DARK
        for r in 0..<B.cut {
            for dx in -W...W where inGap(dx, r) {
                let x = hx + dx, y = top + r
                // 위 3줄 = 바깥(노을 · 밤하늘은 밝게 빛나고 아래로 체크 디더) · 그 아래 = 천장 속 어둠
                let glow = sky == .dusk || sky == .night
                var p = ArtPx(mat: INK, tone: 0.08, z: zBack, d: 0.95)
                if (r == 0 && (x + y) & 1 == 0) || (r == 1 && (x + y) & 3 == 0) {
                    p = glow ? ArtPx(mat: skyMat, tone: 0.95, z: zBack, d: 0.95, emit: 0.45)
                             : ArtPx(mat: skyMat, tone: 0.3, z: zBack, d: 0.95, emit: 0.04)
                }
                if (sky == .shaft || sky == .tunnel) && (dx == -3 || dx == 4) && r < B.cut - 2 { p = ArtPx(mat: WIRE, tone: 0.32, z: zBack, d: 0.95) }   // 승강로 줄 · 터널 배선
                if sky == .plenum && r == 2 { p = ArtPx(mat: WIRE, tone: 0.4, z: zBack, d: 0.95) }   // 천장 속 배관
                C[x, y] = p
            }
        }
        if !hatch {   // 부러진 천장 뼈대 둘: 구멍 위에서 아래로 늘어진 짧은 살(앞)
            for (i, bx) in [-Int(B.hw * 0.4), Int(B.hw * 0.5)].enumerated() {
                let n = 3 + Int(R() * 3), lean = i == 0 ? 1 : -1
                for k in 0..<n { C[hx + bx + (k > 1 ? lean : 0), top + 2 + k] = ArtPx(mat: FRAME, tone: k == 0 ? 0.8 : 0.5, z: zFront, d: 0.3) }
            }
        }
        // 4) 찢긴 가장자리: 아래 · 왼쪽은 실내등을 받아 밝게, 오른쪽은 그늘(1px) · 아래로 처진 이빨 몇 개
        let edgeMat = tile ? STEEL : hatch ? VAN : FRAME
        for r in 0..<B.rows {
            for dx in -W...W where !inGap(dx, r) {
                let x = hx + dx, y = top + r
                let l = inGap(dx + 1, r), rt = inGap(dx - 1, r), up = inGap(dx, r - 1)
                guard l || rt || up else { continue }
                let sheet = r < B.sheet
                if up { C[x, y] = ArtPx(mat: edgeMat, tone: 0.92, z: zFront, d: 0.3) }
                else if l { C[x, y] = ArtPx(mat: sheet ? MDARK : edgeMat, tone: sheet ? 0.7 : 0.82, z: zFront, d: 0.3) }
                else { C[x, y] = ArtPx(mat: sheet ? MDARK : edgeMat, tone: 0.2, z: zFront, d: 0.3) }
            }
        }
        for _ in 0..<(hatch ? 0 : 3) {   // 아래로 처진 천장재 이빨
            let dx = Int(jsRound((R() * 2 - 1) * (B.hw * 0.4))), r = B.cut + Int(R() * 2)
            C[hx + dx, top + r] = ArtPx(mat: edgeMat, tone: 0.86, z: zFront, d: 0.3)
            if R() < 0.6 { C[hx + dx, top + r + 1] = ArtPx(mat: edgeMat, tone: 0.5, z: zFront, d: 0.3) }
        }
        // 5) 지붕 선 들림: 구멍 양옆 바깥 철판이 1px 솟는다 · 금 간 자국
        if B.sheet > 0 {
            for side in [-1, 1] {
                let base = side < 0 ? -Int(L[0]) : Int(Rr[0])
                for k in 1...5 { let x = hx + base + side * k; if k < 4 { C[x, top - 1] = ArtPx(mat: MDARK, tone: k == 1 ? 0.78 : 0.6, z: zFront, d: 0.3, ny: 0.6) } }
                for k in 2...6 { let x = hx + base + side * (k + 2); if (k + Int(R() * 3)) % 3 != 0 { C[x, top + 1 + (k & 1)] = ArtPx(mat: MDARK, tone: 0.08, z: zFront, d: 0.3) } }
            }
        }
        // 6) 젖혀진 철판(깡통 뚜껑처럼 바깥 · 위로 벌어진 판) — 크기 · 각도가 제각각인 삼각 판 + 끝이 더 말린 것.
        //    하늘 쪽 면은 밝게(체크 디더로 아래쪽 어둡게) · 바깥 모서리 1px 하이라이트 · 안쪽 모서리 1px 그늘 · 검은 테두리
        var P = ArtCanvas()
        struct Flap { var b0: Double, b1: Double, tip: (Double, Double), curl: (Double, Double)?, front: Bool, mat: Int, lite: Double }
        var flaps: [Flap] = []
        let big = hatch ? 0.8 : 1.0
        let spots: [(Double, Double, Double)] = [(-1, 0.0, 1.2), (1, 0.0, 1.15), (-1, 0.55, 0.75), (1, 0.5, 0.8), (1, 0.9, 0.5)]   // (쪽, 가운데서 거리, 크기)
        for (i, sp) in spots.enumerated() where !(hatch && (i < 2 || i >= 4)) {   // 해치: 큰 판 대신 뚜껑(아래)
            let side = sp.0
            let edge = side < 0 ? -L[0] : Rr[0]
            let o = edge * (1 - sp.1 * 0.75)                 // 바깥 큰 판은 가장자리에, 작은 판은 안쪽에
            let wb = (4 + R() * 2.5) * sp.2 * big + 1.5
            let len = (7 + R() * 5) * sp.2 * big + 2
            let lean = side * (0.45 + R() * 0.5) * (sp.1 < 0.3 ? 1.25 : 0.6)   // 바깥 판일수록 많이 젖혀진다
            let b0 = Double(hx) + o - side * wb * 0.15, b1 = b0 - side * wb
            let bx = (b0 + b1) / 2
            let grow = pop < 1 ? pop : 1 + 0.06 * sin(age * 38) * exp(-age * 7)
            let tip = (bx + sin(lean) * len * grow, Double(top) - cos(lean) * len * grow)
            let curl: (Double, Double)? = R() < 0.45 ? (tip.0 + side * (2 + R() * 2), tip.1 + 1 + R() * 2) : nil
            let inner = sp.1 > 0.4 && !hatch
            flaps.append(Flap(b0: b0, b1: b1, tip: tip, curl: curl, front: i % 3 != 2, mat: hatch ? VAN : tile ? STEEL : inner ? FRAME : MDARK, lite: inner ? 0.62 : 0.72))
        }
        func inTri(_ px: Double, _ py: Double, _ a: (Double, Double), _ b: (Double, Double), _ c: (Double, Double)) -> Bool {
            func sgn(_ p: (Double, Double), _ q: (Double, Double), _ r: (Double, Double)) -> Double { (p.0 - r.0) * (q.1 - r.1) - (q.0 - r.0) * (p.1 - r.1) }
            let p = (px, py), d1 = sgn(p, a, b), d2 = sgn(p, b, c), d3 = sgn(p, c, a)
            return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0))
        }
        for F in flaps {
            let A = (F.b0, Double(top) + 0.5), Bp = (F.b1, Double(top) + 0.5)
            var mask = Set<Int>()
            let xs = [F.b0, F.b1, F.tip.0, F.curl?.0 ?? F.tip.0], ys = [Double(top), F.tip.1, F.curl?.1 ?? F.tip.1]
            for y in Int(floor(ys.min()! - 1))...top { for x in Int(floor(xs.min()! - 1))...Int(ceil(xs.max()! + 1)) {
                let cx = Double(x) + 0.5, cy = Double(y) + 0.5
                var hit = inTri(cx, cy, A, Bp, F.tip)
                if !hit, let c = F.curl { let m = ((F.tip.0 * 2 + F.b0 + F.b1) / 4, (F.tip.1 * 2 + Double(top)) / 3); hit = inTri(cx, cy, F.tip, c, m) }
                if hit { mask.insert(ArtCanvas.key(x, y)) }
            } }
            let side = F.b0 > F.b1 ? -1 : 1   // 바깥 쪽(구멍에서 먼 쪽) 부호
            for k in mask {
                let x = k % 4096 - 1024, y = k / 4096 - 512
                let outEdge = !mask.contains(ArtCanvas.key(x + side, y)), inEdge = !mask.contains(ArtCanvas.key(x - side, y))
                let topEdge = !mask.contains(ArtCanvas.key(x, y - 1))
                var tone = F.lite - (Double(top - y) < 3 && (x + y) & 1 == 0 ? 0.14 : 0)   // 뿌리 쪽은 체크 디더로 어둡게
                var mat = F.mat
                if topEdge || outEdge { tone = 0.95; if mat == MDARK { mat = FRAME } }
                else if inEdge { tone = 0.22 }
                P[x, y] = ArtPx(mat: mat, tone: tone, z: F.front ? zFront : zBack, d: 0.3, nx: Double(side) * 0.3, ny: 0.4)
            }
        }
        for (k, p) in P.px {   // 검은 테두리(하늘 쪽만)
            let x = k % 4096 - 1024, y = k / 4096 - 512
            for (ox, oy) in [(1, 0), (-1, 0), (0, -1)] where P[x + ox, y + oy] == nil && y + oy < top {
                if C[x + ox, y + oy] == nil { C[x + ox, y + oy] = ArtPx(mat: MDARK, tone: 0.04, z: p.z, d: 0.3) }
            }
        }
        for (k, p) in P.px { C.px[k] = p }
        if hatch {   // 엘리베이터 비상 해치: 뜯긴 뚜껑이 한쪽 경첩에 매달려 흔들린다(리벳)
            let sw = sin(age * 5) * 0.3 * exp(-age * 0.7) * min(1, age / 0.05)
            let ang = -Double(f) * (0.4 + sw) * min(1, pop * 1.2)   // 경첩에서 거의 곧추선 뚜껑(살짝 바깥으로)
            let bx = Double(hx) - Double(f) * (B.hw + 1), by = Double(top) - 0.5
            var lid = ArtCanvas()
            for t in 0..<16 {
                for q in 0..<4 {
                    let x = Int(floor(bx + sin(ang) * Double(t) * 0.5 - Double(f) * cos(ang) * Double(q))), y = Int(floor(by - cos(ang) * Double(t) * 0.5 - sin(ang) * Double(q) * 0.3))
                    let edge = q == 0 || t >= 14, rivet = (t == 3 || t == 12) && q == 2
                    lid[x, y] = ArtPx(mat: VAN, tone: rivet ? 0.3 : edge ? 0.95 : q == 3 ? 0.35 : 0.72, z: zFront, d: 0.3)
                }
            }
            for (k, p) in lid.px {
                let x = k % 4096 - 1024, y = k / 4096 - 512
                for (ox, oy) in [(1, 0), (-1, 0), (0, -1), (0, 1)] where lid[x + ox, y + oy] == nil && y + oy < top { C[x + ox, y + oy] = ArtPx(mat: MDARK, tone: 0.04, z: p.z, d: 0.3) }
            }
            for (k, p) in lid.px { C.px[k] = p }
        }
        // 7) 늘어진 전선 둘(끝에서 가끔 불꽃) · 깨진 형광등 하나(깜빡이다 꺼진다)
        if !tile || true {
            for (i, cx) in [-Int(B.hw * 0.35), Int(B.hw * 0.45)].enumerated() {
                let len = 5 + Int(R() * 6), ph = R() * 6
                let sw = (0.35 * sin(age * 6 + ph) * exp(-age * 0.6) + 0.12 * sin(age * 1.7 + ph)) * (i == 0 ? 1 : -1)
                var x = Double(hx + cx) + 0.5
                for k in 0..<len {
                    let y = top + B.cut - 2 + k
                    x += sin(sw * Double(k) / Double(len) * 2)
                    C[Int(floor(x)), y] = ArtPx(mat: WIRE, tone: 0.3, z: zFront, d: 0.3)
                }
                let fl = hash01(h.seed &+ UInt64(i), Int(age * 18))
                if age < 3 && fl > 0.82 { C[Int(floor(x)), top + B.cut - 2 + len] = ArtPx(mat: GOLD, tone: 1, z: zFront, d: 0.3, emit: 1) }
            }
        }
        if !hatch {
            let side = R() < 0.5 ? -1.0 : 1.0
            let bx = side < 0 ? -L[min(5, B.cut - 1)] : Rr[min(5, B.cut - 1)]
            let sw = 0.25 * sin(age * 4.2) * exp(-age * 0.5)
            let ang = side * (0.95 + sw)   // 경첩에서 아래 · 구멍 쪽으로 늘어진다
            let on = age < 0.4 || (age < 4 && hash01(h.seed &+ 7, Int(age * 11)) > 0.55 + age * 0.08)
            for t in 0..<7 {
                for q in 0..<2 {
                    let x = Int(floor(Double(hx) + bx - sin(ang) * Double(t) + Double(q) * cos(ang))), y = top + (tile ? 3 : 6) + Int(floor(cos(ang) * Double(t) * 0.9)) + q
                    C[x, y] = ArtPx(mat: FRAME, tone: q == 0 ? 0.92 : 0.55, z: zFront, d: 0.3, emit: on && q == 0 && t > 1 ? 0.9 : 0)
                }
            }
        }
        // 8) 터지는 순간: 짧고 단단한 섬광(십자 별 · 0.08초) — 섬광 줄이기면 작게
        if age < 0.08 {
            let n = noFlash ? 2 : 5, e = noFlash ? 0.5 : 1
            for k in -n...n { C[hx + k, top + 3] = ArtPx(mat: EYE, tone: 1, z: zFront, d: 0.3, emit: e); C[hx, top + 3 + k] = ArtPx(mat: EYE, tone: 1, z: zFront, d: 0.3, emit: e) }
            for k in 1...max(1, n / 2) { for (a, b) in [(1, 1), (-1, 1), (1, -1), (-1, -1)] { C[hx + a * k, top + 3 + b * k] = ArtPx(mat: MOON, tone: 1, z: zFront, d: 0.3, emit: e) } }
        }
        // 9) 불꽃(위로 튀었다 떨어진다) · 철판 파편(중력 · 바닥에서 튄다) · 천장 먼지(흘러내린다)
        var drng = SplitMix64(seed: h.seed ^ 0xD3B)
        func D() -> Double { drng.next() }
        for _ in 0..<(noFlash ? 4 : 9) {
            let vx = (D() * 2 - 1) * 90, vy = -(60 + D() * 120), life = 0.3 + D() * 0.25
            guard age < life else { continue }
            let x = Double(hx) + vx * age, y = Double(top + 3) + vy * age + 260 * age * age
            C[Int(floor(x)), Int(floor(y))] = ArtPx(mat: GOLD, tone: age < life * 0.5 ? 1 : 0.8, z: zFront, d: 0.3, emit: age < life * 0.6 ? 1 : 0.5)
        }
        for i in 0..<10 {
            let x0 = Double(hx) + (D() * 2 - 1) * 6, y0 = Double(top + 4 + Int(D() * 4))
            let vx = (D() * 2 - 1) * 75, vy = -20 + D() * 70
            let sz = D() < 0.4 ? 2 : 1, tall = D() < 0.5
            let mat = [MDARK, FRAME, STEEL, MDARK][i % 4], tone = 0.35 + D() * 0.45
            let keep = 2.2 + D() * 0.8
            guard age < keep + 0.4 else { continue }
            if age > keep && Int(age * 16) % 2 == 0 { continue }   // 사라지기 전 깜빡
            let p = ballistic(x0, y0, vx, vy, age, floorY: Double(floorY - (sz - 1)))
            for a in 0..<sz { for b in 0..<(tall ? sz : 1) { C[Int(floor(p.0)) + a, Int(floor(p.1)) - b] = ArtPx(mat: mat, tone: tone + (a == 0 && b == 0 ? 0.2 : 0), z: zDebris, d: 0.3) } }
        }
        let bottom = top + B.cut
        for _ in 0..<22 {
            let t0 = D() * 1.3, sp = 30 + D() * 45, ph = D() * 6, x0 = Double(hx) + (D() * 2 - 1) * (B.hw * 0.7)
            let t = age - t0
            guard t > 0 else { continue }
            let y = Double(bottom) + sp * t
            guard y < Double(floorY) else { continue }
            let x = x0 + sin(t * 5 + ph) * 1.5
            C[Int(floor(x)), Int(floor(y))] = ArtPx(mat: CONC, tone: 0.75 - min(0.4, t * 0.2), z: zDebris, d: 0.3)
        }
        // 10) 하늘로 피어오르는 먼지 기둥(지붕 위) · '…쿵' 먼지 한 줌(구멍 위 · 아래)
        func puff(_ cx: Double, _ cy: Double, _ r: Double, _ u: Double, _ tone: Double) {
            let ri = Int(ceil(r))
            for oy in -ri...ri { for ox in -ri...ri {
                let d2 = Double(ox * ox + oy * oy), x = Int(floor(cx)) + ox, y = Int(floor(cy)) + oy
                guard d2 <= r * r + 0.5 else { continue }
                let edge = d2 > (r - 1) * (r - 1)
                if (edge || u > 0.55) && (x + y) & 1 == 1 { continue }   // 가장자리 · 옅어질 때 체크 디더
                if u > 0.8 && (x & 1 == 0 || y & 1 == 0) { continue }
                C[x, y] = ArtPx(mat: CONC, tone: tone - (oy < 0 ? 0 : 0.12), z: zFront, d: 0.3)
            } }
        }
        if !tile {
            for _ in 0..<9 {
                let life = 0.9 + D() * 0.8, t0 = D() * 0.25, rise = 18 + D() * 26, dr = (D() * 2 - 1) * 10 + Double(f) * 4
                let t = age - t0
                guard t > 0 && t < life else { continue }
                let u = t / life
                puff(Double(hx) + (D() * 2 - 1) * 5 + dr * u, Double(top) - 2 - rise * (1 - pow(1 - u, 2)), 1 + 2.2 * u, u, 0.62 - 0.25 * u)
            }
        }
        if let th = h.thud, th < 1.0 {
            for _ in 0..<5 {
                let t = th - D() * 0.15, life = 0.6 + D() * 0.35
                guard t > 0 && t < life else { continue }
                let u = t / life
                puff(Double(hx) + (D() * 2 - 1) * 4, Double(top) - 1 - 10 * u, 1 + 1.6 * u, u, 0.6)
                let gx = Double(hx) + (D() * 2 - 1) * 6, gy = Double(bottom) + 40 * t
                if gy < Double(floorY) { C[Int(floor(gx)), Int(floor(gy))] = ArtPx(mat: CONC, tone: 0.7, z: zDebris, d: 0.3) }
            }
        }
        // 11) 빛줄기 속 먼지 티(처음 1초는 많이 · 뒤엔 둘셋만 남아 떠다닌다)
        let motes = age < 1.4 ? 8 : 3
        for i in 0..<motes {
            let ph = hash01(h.seed &+ 99, i) * 6.28, sp = 4 + hash01(h.seed &+ 98, i) * 7
            let yy = Double(bottom + 6) + (age * sp + hash01(h.seed &+ 97, i) * 70).truncatingRemainder(dividingBy: Double(max(10, floorY - bottom - 8)))
            let xx = Double(hx) + sin(age * 0.9 + ph) * 3.5 + (hash01(h.seed &+ 96, i) * 2 - 1) * 3
            C[Int(floor(xx)), Int(floor(yy))] = ArtPx(mat: MOON, tone: 0.85, z: zDebris, d: 0.3, emit: age < 1.4 ? 0.45 : 0.22)
        }
        C.flush(into: &m)
        // 12) 빛: 구멍에서 바닥으로 떨어지는 빛줄기(무대 볼류메트릭 — 처음 밝게, 깜빡이다 가라앉아 은은히 남는다) + 구멍 둘레 빛
        let vi = (1.5 + 2.5 * burst) * flick * (noFlash ? 0.7 : 1)
        out.vols.append(VolumeLight(x: Double(hx), y: Double(top + 2), dx: 0, dy: 1, c: shaftC, i: vi, cone: 0.965, len: Double(floorY - top) + 6, halo: 6))
        out.lights.append(SceneLight(x: Double(hx), y: Double(top + B.cut), z: 30, r: 100, c: shaftC, i: (0.7 + 0.9 * burst) * flick, spot: [0, 1], cone: 0.9))   // 바닥으로 떨어지는 빛 웅덩이
        out.lights.append(SceneLight(x: Double(hx), y: Double(top + B.cut + 4), z: 22, r: 60, c: shaftC, i: (0.4 + 1.0 * burst) * flick))
        if age < 0.12 && !noFlash { out.lights.append(SceneLight(x: Double(hx), y: Double(top + 3), z: 10, r: 60, c: [1, 0.95, 0.8], i: 2.4 * (1 - age / 0.12))) }
        if let t = h.target, age < 1.6 { out.zBack[t] = 0.6 }
    }

    /// 중력 · 바닥 튀기(닫힌 꼴 대신 작은 걸음 — 결정적)
    static func ballistic(_ x0: Double, _ y0: Double, _ vx0: Double, _ vy0: Double, _ age: Double, floorY: Double) -> (Double, Double) {
        var x = x0, y = y0, vx = vx0, vy = vy0, t = 0.0
        let dt = 1.0 / 120
        while t < age {
            let h = min(dt, age - t)
            vy += 560 * h; x += vx * h; y += vy * h
            if y >= floorY { y = floorY; if abs(vy) > 40 { vy = -vy * 0.32; vx *= 0.55 } else { vy = 0; vx *= 0.8 } }
            t += h
        }
        return (x, y)
    }

    static func hash01(_ seed: UInt64, _ i: Int) -> Double {
        var g = SplitMix64(seed: seed &+ UInt64(bitPattern: Int64(i)) &* 0x9E3779B97F4A7C15); return g.next()
    }

    // MARK: 종이 회오리

    /// 서류 한 장 그림(앞면 · 기울어짐 · 모서리 1px · 뒷면) — W 흰 종이 · G 글줄 · B 파란 머리띠 · Y 영수증 · R 결재 도장 · b 뒷면 · E 모서리
    static let sheetArt: [[[String]]] = [
        [["WWWW", "WGGW", "WWWW", "WGGW", "WWWW"], ["WW", "GW", "WW", "GW", "WW"], ["E", "E", "E", "E", "E"], ["bbbb", "bbbb", "bbbb", "bbbb", "bbbb"]],                  // A4
        [["YYY", "YGY", "YYY", "YGY", "YYY", "Y.Y"], ["YY", "GY", "YY", "GY", "YY", "Y."], ["E", "E", "E", "E", "E", "E"], ["yyy", "yyy", "yyy", "yyy", "yyy", "y.y"]],  // 영수증
        [["BBBBB", "WWWWW", "WGGGW", "WWWWW", "WGGWW", "WWWWW"], ["BBB", "WWW", "GGW", "WWW", "GWW", "WWW"], ["B", "E", "E", "E", "E", "E"], ["bbbbb", "bbbbb", "bbbbb", "bbbbb", "bbbbb", "bbbbb"]],   // 파란 머리 서식
        [["WWWWWW", "WGGGGW", "WWWWWW", "WGGGWW", "WWWRRW", "WGWRRW", "WWWWWW"], ["WWW", "GGW", "WWW", "GGW", "WRW", "WRW", "WWW"], ["E", "E", "E", "E", "E", "E", "E"],
         ["bbbbbb", "bbbbbb", "bbbbbb", "bbbbbb", "bbbbbb", "bbbbbb", "bbbbbb"]],   // 결재 도장 서류(한 장)
    ]

    /// 몸이 도는 빠르기(라디안/초) — 승천권 키 spin(0 → .06 → .25 → .48 → .62 → .82 → 1.0, 0.4초에 한 바퀴 남짓)을 따른 봉우리 · 꼭대기 뒤 잦아듦
    static func spinRate(_ t: Double) -> Double {
        let peak = 2 * Double.pi * 2.6
        if t < 0 { return 0 }
        if t < 0.06 { return peak * t / 0.06 }
        if t < 0.28 { return peak }
        return peak * exp(-(t - 0.28) * 5)
    }

    /// 한 장의 지금 자리 · 앞뒤 · 그림 칸 · 기울기(−1 · 0 · 1 — 미끄러지는 쪽 앞 모서리가 아래) · 사라짐(0~1, 디더로 지운다)
    public struct Sheet: Sendable { public var x: Double, y: Double; public var front: Bool; public var frame: Int, kind: Int; public var landed: Bool, rot: Bool; public var lean = 0, fade = 0.0, id = 0 }

    /// 떨어지는 방식(장마다): 흔들 진자 · 끝없이 재주넘는 영수증 · 구겨져 빨리 떨어지는 장
    enum Fall { case flutter, tumble, crumple }

    /// 놓인 뒤 흐른 tb 초의 낙하(놓인 자리 기준 dx · dy · 그림 칸 · 기울기). 닫힌 꼴이라 나이만으로 같은 값(결정적)
    ///  0 ~ 0.3초: 회오리에서 받은 접선 속도가 공기 저항으로 지수 감쇠(위 기운도 함께) → 그 뒤 종류별 낙하
    ///  진자: x = A·sin φ (φ = 2π·tb'/T) · 내려가는 빠르기 ∝ (1.8·cos²φ − 0.35) — 가운데를 미끄러질 때 빨리 · 끝에서 고개를 들고 잠깐 멈칫(살짝 뜬다)
    ///        그림: 미끄러질 땐 앞면(앞 모서리 아래로 1px 기울임) · 끝에 가까우면 기울어짐 · 되돌 때 모서리(1px 선)
    ///  재주넘기: 한 방향으로 비스듬히 · 회전각으로 앞 → 기울 → 모서리 → 뒤
    ///  옆미끄럼: 진자 장 일부가 한 번, 0.18초 동안 가파르게 미끄러졌다가 다시 진자로
    struct FallPlan {
        var kind: Fall, vx0: Double, vy0: Double, T: Double, A: Double, vt: Double, side: Double, spin: Double, spin0: Double, slipAt: Double?, slipDir: Double
        func at(_ tb: Double) -> (dx: Double, dy: Double, frame: Int, lean: Int) {
            let k = 9.0, ta = min(tb, 0.3)
            // 1) 남은 기운 감쇠 + 종단 속도로 넘어가는 중력
            var dx = vx0 / k * (1 - exp(-k * ta)), dy = vy0 / k * (1 - exp(-k * ta)) + 0.5 * 90 * ta * ta * 0.5
            guard tb > 0.3 else {
                let ang = spin0 + spin * tb
                return (dx, dy, kind == .tumble ? Self.tumbleFrame(ang) : (abs(vx0 * exp(-k * tb)) > 40 ? 1 : 0), vx0 > 0 ? 1 : -1)
            }
            let u = tb - 0.3
            switch kind {
            case .flutter:
                let w = 2 * Double.pi / T, ph = w * u
                dx += side * A * sin(ph)
                // ∫(1.8·cos²φ − 0.35) dt = 0.55·t + 0.45·sin2φ/w
                dy += vt * (0.55 * u + 0.45 * sin(2 * ph) / w) + 4 * min(1, u * 3)
                if let s0 = slipAt, u > s0 {   // 옆미끄럼(가파르게 짧게 → 다시 진자)
                    let e = min(1, (u - s0) / 0.18), sm = e * e * (3 - 2 * e)
                    dx += slipDir * 7 * sm; dy += 9 * sm
                }
                let c = cos(ph), sn = sin(ph)
                let frame = abs(c) < 0.28 ? 2 : abs(c) < 0.62 ? 1 : 0           // 되돌기(cos 0) = 모서리 · 끝 가까이 = 기울어짐 · 가운데 = 앞면
                let lean = abs(c) < 0.28 ? 0 : (side * c > 0 ? 1 : -1)          // 미끄러지는 쪽 앞 모서리가 아래
                _ = sn
                return (dx, dy, frame, lean)
            case .tumble:
                dx += side * 22 * u; dy += vt * u + 4 * min(1, u * 3)
                return (dx, dy, Self.tumbleFrame(spin0 + spin * tb), side > 0 ? 1 : -1)
            case .crumple:
                dx += side * 6 * sin(u * 5); dy += vt * u + 4 * min(1, u * 3)
                return (dx, dy, Self.tumbleFrame(spin0 + spin * tb), 0)
            }
        }
        /// 회전각 → 그림 칸(앞 0 · 기울 1 · 모서리 2 · 뒤 3)
        static func tumbleFrame(_ a: Double) -> Int {
            let c = cos(a)
            if abs(c) < 0.3 { return 2 }
            if abs(c) < 0.72 { return 1 }
            return c > 0 ? 0 : 3
        }
    }

    /// 종이 회오리 한 번의 지금 장들(그리기 · 점검 그림이 같이 쓴다). heads 가 없어도 된다
    public static func paperSheets(_ P: RisePaper, at t: Double) -> [Sheet] {
        let cx = P.x, gy = P.y
        let dir = P.f >= 0 ? 1.0 : -1.0
        let n = P.calm ? 5 : 14
        let floorY = gy - 1
        let roof = P.roof.map { (x: $0[0], top: ($0.count > 1 ? $0[1] : 140) - 1) }
        var rng = SplitMix64(seed: P.seed)
        func R() -> Double { rng.next() }
        var sheets: [Sheet] = []
        let kinds = [3, 0, 1, 2, 0, 1, 0, 2, 1, 0, 2, 0, 1, 0]   // 결재 도장 한 장은 늘 · A4 · 영수증 · 서식 고루
        for i in 0..<n {
            let jacket = i % 5 < 3                                         // 가방 · 양복에서 터진 것 / 발밑에서 휩쓸려 오른 것
            let delay = jacket ? R() * 0.04 : 0.03 + R() * 0.1
            let h0 = jacket ? 26 + R() * 22 : R() * 3
            let r0 = jacket ? 3 + R() * 4 : 8 + R() * 9
            let H = jacket ? 46 + R() * 74 : 16 + R() * 60
            let tRel = 0.22 + R() * 0.26
            let lag = 0.62 + R() * 0.32
            let th0 = R() * 2 * .pi
            let kind = kinds[i % kinds.count]
            let rot = kind != 3 && R() < 0.3
            // 낙하 성격(장마다 다르게 — 같이 움직이지 않게)
            let roll = R()
            let fall: Fall = kind == 1 && roll < 0.7 ? .tumble : (kind != 3 && roll > 0.86 ? .crumple : .flutter)
            let T = 0.5 + R() * 0.6, A = 9 + R() * 8
            var vt = fall == .tumble ? 34 + R() * 8 : fall == .crumple ? 48 + R() * 10 : 20 + R() * 15
            if P.calm { vt *= 1.4 }
            let spin = (fall == .tumble ? 11 + R() * 5 : fall == .crumple ? 7 + R() * 4 : 3) * (R() < 0.5 ? -1 : 1), spin0 = R() * 6.28
            let slipAt: Double? = fall == .flutter && R() < 0.4 ? 0.4 + R() * 0.9 : nil, slipDir = R() < 0.5 ? -1.0 : 1.0
            let lie = 0.6 + R() * 0.6, skidK = 0.6 + R() * 0.6
            let sucked = roof != nil && jacket && H > 70                   // 지붕 뚫기: 높이 오른 몇 장은 구멍으로
            let vy0 = -(30 + R() * 50)                                      // 놓일 때 남은 위 기운(난수는 미리 — 나이와 무관하게 같은 순서)
            guard t > delay else { continue }
            let dt = 1.0 / 120
            var tt = delay, th = th0, h = h0, r = r0
            var x = cx, y = gy - h, front = true
            // 1) 회오리: 몸 회전을 조금 늦게 따라 돌고, 꼭대기까지 오르는 상승 기류에 실린다(위로 갈수록 반지름이 넓다 — 느슨한 깔때기)
            while tt < min(t, tRel) {
                let u = tt - delay
                th += dir * spinRate(tt) * lag * dt
                h = h0 + (H - h0) * (1 - pow(1 - min(1, u / 0.24), 2.2))
                r = r0 + 6 + h * 0.3 + 2 * sin(u * 9 + Double(i))   // 위로 갈수록 넓은 깔때기(몸 실루엣 밖으로)
                tt += dt
            }
            x = cx + r * cos(th); front = sin(th) > 0; y = gy - h - 0.28 * r * sin(th)
            var frame = Int(floor((th - th0) * 1.2)) & 3, lean = 0, fade = 0.0, landed = false
            if t > tRel {
                let w = dir * spinRate(tRel) * lag
                let vx0 = -r * sin(th) * w * 0.55
                if sucked, let rf = roof {   // 구멍으로 빨려 올라간다
                    var px = x, py = y, vx = vx0, vy = vy0
                    tt = tRel
                    while tt < t { vx += ((rf.x - px) * 30 - vx) * min(1, 6 * dt); vy += (-320 - vy) * min(1, 5 * dt); px += vx * dt; py += vy * dt; tt += dt }
                    if py < rf.top - 8 { continue }
                    x = px; y = py; frame = FallPlan.tumbleFrame(spin0 + 14 * (t - tRel))
                } else {
                    // 2) 놓임 → 3) 종이답게 떨어진다(진자 · 재주넘기 · 구겨진 장 · 옆미끄럼) → 4) 닿으면 짧게 미끄러져 눕고 디더로 사라진다
                    let side: Double = vx0 >= 0 ? 1 : -1
                    let F = FallPlan(kind: fall, vx0: vx0, vy0: vy0, T: T, A: A, vt: vt, side: side, spin: spin, spin0: spin0, slipAt: slipAt, slipDir: slipDir)
                    let tb = t - tRel
                    var land: Double?
                    var q = 0.0
                    while q <= tb { if y + F.at(q).dy >= floorY { land = q; break }; q += 1.0 / 60 }
                    if let la = land {
                        let p0 = F.at(la), p1 = F.at(max(0, la - 1.0 / 60))
                        let vxl = (p0.dx - p1.dx) * 60
                        let after = tb - la
                        let skid = max(-6, min(6, vxl * 0.12 * skidK)) * (1 - exp(-after * 10))
                        x += p0.dx + skid; y = floorY
                        frame = after < 0.08 ? 1 : 2; lean = after < 0.08 ? (vxl > 0 ? 1 : -1) : 0   // 모서리가 한 번 튀었다 납작하게
                        landed = after >= 0.08
                        if after > lie + 0.35 { continue }
                        fade = max(0, (after - lie) / 0.35)
                    } else {
                        let p = F.at(tb)
                        x += p.dx; y += p.dy; frame = p.frame; lean = p.lean
                    }
                }
            }
            var sh = Sheet(x: x, y: y, front: front, frame: frame, kind: kind, landed: landed, rot: rot && !landed)
            sh.lean = lean; sh.fade = fade; sh.id = i
            sheets.append(sh)
        }
        // 지붕 뚫기 뒤: 빛줄기를 타고 되돌아 내려오는 몇 장(진자)
        if let rf = roof, !P.calm {
            for k in 0..<3 {
                let t0 = 0.9 + Double(k) * 0.35, tb = t - t0
                guard tb > 0 else { continue }
                let F = FallPlan(kind: .flutter, vx0: 0, vy0: 0, T: 0.7 + Double(k) * 0.15, A: 4, vt: 22 + Double(k) * 4, side: k == 1 ? -1 : 1, spin: 0, spin0: 0, slipAt: nil, slipDir: 1)
                let p = F.at(tb)
                let y = rf.top + 3 + p.dy
                guard y < floorY else { continue }
                var sh = Sheet(x: rf.x + Double(k - 1) * 3 + p.dx, y: y, front: true, frame: p.frame, kind: k == 1 ? 1 : 0, landed: false, rot: false)
                sh.lean = p.lean; sh.id = 100 + k; sheets.append(sh)
            }
        }
        return sheets
    }

    static func paper(_ P: RisePaper, _ s: SimSnapshot, _ heads: [ActorID: SIMD2<Double>], _ m: inout PixelMesh) {
        let heroZ = 0.9 - P.y / 300
        let sheets = paperSheets(P, at: P.age)
        // 그리기: 몸 뒤 장은 어둡게 · 깊이 뒤 / 앞 장은 앞 — 얼굴 · 주먹 가까이 앞 장은 건너뛴다(실루엣이 읽히게)
        let head = heads[P.actor]
        var C = ArtCanvas()
        for sh in sheets {
            if sh.front, let hd = head, abs(sh.x - hd.x) < 7 && sh.y > hd.y - 26 && sh.y < hd.y + 6 { continue }
            let art = sheetArt[sh.kind][sh.landed ? 2 : sh.frame]
            let dk = sh.front ? 1.0 : 0.62
            let z = heroZ + (sh.front ? -0.12 : 0.12)
            let rows = sh.landed ? [String(repeating: "E", count: max(3, sheetArt[sh.kind][0][0].count))] : art
            let H = rows.count, W = rows[0].count
            let X0 = Int(floor(sh.x)) - (sh.rot ? H : W) / 2, Y0 = Int(floor(sh.y)) - (sh.rot ? W : H) / 2
            for (r, row) in rows.enumerated() {
                let sx = sh.rot ? 0 : sh.lean * (r - H / 2) / 2   // 앞 모서리가 아래로(1px 기울임)
                for (c, ch) in row.enumerated() where ch != "." {
                    if sh.fade > 0 { let b4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5][((r & 3) << 2) | (c & 3)]; if Double(b4) / 16 < sh.fade { continue } }   // 디더로 사라진다(깜빡임 없이)
                    var p = ArtPx(mat: CANVAS, tone: 1.0 * dk, z: z, d: 0.5, emit: sh.front ? 0.28 : 0.08, part: 12)   // 부위 12 = 인물처럼 어두운 1px 테두리(작아도 종이 한 장으로 읽힌다)   // 종이는 빛을 잘 받는다(어두운 무대에서도 하얗게 — 번지는 블룸 없이 작은 발광만)
                    switch ch {
                    case "G": p.tone = 0.42 * dk
                    case "b": p.tone = 0.7 * dk
                    case "E": p.tone = 0.6 * dk
                    case "Y": p.mat = BONE; p.tone = 0.95 * dk
                    case "y": p.mat = BONE; p.tone = 0.72 * dk
                    case "B": p.mat = ARMOR; p.tone = 0.62 * dk
                    case "R": p.mat = RED; p.tone = 0.75 * dk
                    default: break
                    }
                    let (px, py) = sh.rot ? (X0 + r, Y0 + c) : (X0 + c + sx, Y0 + r)
                    C[px, py] = p
                }
            }
        }
        C.flush(into: &m)
    }
}
