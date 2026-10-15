import Foundation
import BBContent

// 무도장(콤보 연구실) 장면 구성 — 웹 08-art-dojo.js(drawDojoBack · dojoLights · dojoFX + 건널목 갈래 drawCrossBack · drawCrossFront · crossLights · crossFX ·
// xcCars · xcSpan · xcWinList · xcSunK · xcHead · xcReset · xcLeaf) 1:1 이식.
// 숨은 변경: drawDojoBack · dojoLights 가 처음 불릴 때 xcEnsure → xcReset 이 DJ.xc(단풍 72장 · 다음 전차 시각)를 Math.random 으로 만든다
//           → SceneEffects.cross(난수 주입). 무도장 흔들림 · 행인 · 전차 · 단풍 움직임(djTick · xcTick)은 그리기 밖이다.

/// 웹 DJ_POLES · DJ_WIN · DJ_ANDON · DJ_PROPS(x) · DJ_*_A(회전 스프라이트 각 표)
let DJ_POLES: [Double] = [96, 384]
let DJ_WIN: [(Double, Double)] = [(120, 220), (260, 360)]
let DJ_ANDON: [Double] = [200, 304]
let DJ_PROP_X: [String: Double] = ["mook": 112, "brd": 168, "rack": 214, "drum": 336, "bag": 410]
let DJ_SIGN_A: [Double] = [-10, -7.5, -5, -2.5, 0, 2.5, 5, 7.5, 10]
let DJ_LAMP_A: [Double] = [-15, -10, -5, 0, 5, 10, 15]
let DJ_BAG_A: [Double] = [-30, -24, -18, -12, -6, 0, 6, 12, 18, 24, 30]
/// 웹 STRAP_X(27-actors) — 손잡이 자리(문 근처 제외)
let STRAP_X: [Double] = stride(from: 18.0, to: SB.W - 18, by: 26).filter { x in !DOORS.contains { x > $0.0 - 6 && x < $0.1 + 6 } }
/// 웹 XC_SUN · XC_TY · XC_CW · XC_CS · XC_CAR(건널목)
enum XC {
    static let SUN: (Double, Double) = (332, 152), TY = 210.0, CW = 123.0
    static let CS: [Double] = [36, 240, 444]
    static let carW = 208.0, carH = 88.0, wy0 = 28.0, wy1 = 42.0
    static let wins: [(Double, Double)] = [(12, 28), (32, 48), (52, 68), (96, 112), (116, 132), (136, 152), (74, 84), (158, 168), (192, 199), (200, 206)]
    static let bog: [Double] = [30, 178]
}

struct XcCar { let cx: Double, fl: Bool, lead: Bool }
struct XcWin { let x: Double, x0: Double, x1: Double, y: Double }

/// 웹 xcCars · xcSpan · xcWinList · xcSunK · xcHead
enum CrossGeom {
    static func cars(_ T: SceneInput.Cross.Tram?) -> [XcCar] {
        guard let T else { return [] }
        return [0.0, 1].map { k in XcCar(cx: T.x - T.dir * k * (XC.carW + 6), fl: k == 0 ? T.dir < 0 : T.dir > 0, lead: k == 0) }
    }
    static func span(_ c: XcCar, _ a: Double, _ b: Double) -> (Double, Double) {
        c.fl ? (c.cx + XC.carW / 2 - b, c.cx + XC.carW / 2 - a) : (c.cx - XC.carW / 2 + a, c.cx - XC.carW / 2 + b)
    }
    static func winList(_ T: SceneInput.Cross.Tram?) -> [XcWin] {
        var out: [XcWin] = []
        for c in cars(T) { for (a, b) in XC.wins { let (x0, x1) = span(c, a, b); out.append(XcWin(x: (x0 + x1) / 2, x0: x0, x1: x1, y: XC.TY - XC.carH + (XC.wy0 + XC.wy1) / 2)) } }
        return out
    }
    /// 해가 차체에 가리면 .35, 창이 지나가면 1
    static func sunK(_ T: SceneInput.Cross.Tram?) -> Double {
        guard let T, T.warn <= 0 else { return 1 }
        let sx = XC.SUN.0
        for c in cars(T) {
            if sx < c.cx - XC.carW / 2 || sx > c.cx + XC.carW / 2 { continue }
            return winList(T).contains { sx >= $0.x0 - 1 && sx <= $0.x1 + 1 } ? 1 : 0.35
        }
        return 1
    }
    static func head(_ T: SceneInput.Cross.Tram) -> (x: Double, y: Double) { (T.x + T.dir * (XC.carW / 2 - 6), XC.TY - XC.carH + 53) }

    /// 웹 xcLeaf(x, gy) — 난수 4개(ph · rot · c · s)
    static func leaf<R: SceneRandom>(_ x: Double, _ gy: Double, _ rng: inout R) -> SceneInput.Cross.Leaf {
        let ph = rng.next() * 6.28, rot = jsFloor(rng.next() * 4), c: Double = rng.next() < 0.55 ? 0 : 1, s = jsFloor(rng.next() * 3)
        return .init(x: x, gy: gy, h: 0, rot: rot, c: c, s: s, ph: ph)
    }
    /// 웹 xcReset() — 다음 전차 시각 · 바닥 단풍 72장(60%는 사람이 서는 줄 근처)
    static func reset<R: SceneRandom>(_ rng: inout R) -> SceneInput.Cross {
        var X = SceneInput.Cross(nextT: 4 + rng.next() * 4)
        for k in 0..<72 {
            let x = 14 + rng.next() * (SB.W - 28)
            let gy = k % 5 < 3 ? 223 + rng.next() * 12 : 236 + rng.next() * 26
            X.leaves.append(leaf(x, gy, &rng))
        }
        return X
    }
    /// 웹 xcKey(L)
    static func key(_ L: SceneInput.Cross.Leaf) -> String { "xc_leaf\(jsStr(L.c))\(jsStr(L.s))@\(toInt32(jsFloor(L.rot)) & 3)" }
}

struct DojoContext {
    let I: SceneInput
    let K: SceneContent
    let D: SceneInput.DojoRoom
    var cross: Bool { (D.bg ?? "dojo") == "cross" }

    /// 웹 xcEnsure(): DJ.xc 가 없으면 만든다(숨은 변경 → eff.cross)
    func xc<R: SceneRandom>(_ eff: inout SceneEffects, _ rng: inout R) -> SceneInput.Cross {
        if let X = D.xc ?? eff.cross { return X }
        let X = CrossGeom.reset(&rng); eff.cross = X; return X
    }

    /// 웹 drawDojoBack(time) — 건널목이면 drawCrossBack
    func drawBack<R: SceneRandom>(_ P: inout Painter, _ eff: inout SceneEffects, _ rng: inout R) {
        let X = xc(&eff, &rng)
        if cross { drawCrossBack(X, &P); return }
        let time = I.time
        P.depth = 0.9; P.quad("dj_out", 0, 0)
        P.depth = 0.6
        for w in D.walkers {                                                       // 창 밖 행인(창 안에 있을 때만)
            guard DJ_WIN.contains(where: { w.x > $0.0 + 4 && w.x < $0.1 - 4 }) else { continue }
            P.placeAt("dj_walk\(jsStr(w.um))\(jsStr(jsMod(jsFloor(w.t * 3), 2)))", jsRound(w.x), 194, w.v < 0, 0)
        }
        P.depth = 0.3; P.quad("dj_ceil", 0, 0); P.quad("dj_room", 0, 80); P.quad("dj_floor", 0, 222)
        let deg = { (r: Double) in r * 180 / Double.pi }
        P.placeAt("dj_sign@\(djIdx(DJ_SIGN_A, deg(D.sign)))", 240, 100, false, 0)
        for (k, x) in [150.0, 330].enumerated() {
            let a = k < D.lamps.count ? D.lamps[k] : 0
            P.placeAt("dj_lamp@\(djIdx(DJ_LAMP_A, deg(a) + sin(time * 0.9 + Double(k)) * 2))", x, 100, false, 0)
        }
        if let rx = stableSorted(STRAP_X, by: { abs($0 - 250) }).first { P.placeAt("dj_ring", rx, 112, false, 0) }
        for x in DJ_ANDON { P.placeAt("dj_andon", x, 84, false, 0) }
        let jit = { (t: Double) in t > 0 ? jsRound(sin(time * 80) * 2 * t / 0.5) : 0 }
        P.placeAt("dj_mook", DJ_PROP_X["mook"]! + jit(D.mook), 222, false, 0)
        P.placeAt(D.brd ? "dj_brd_b" : "dj_brd", DJ_PROP_X["brd"]!, 222, false, 0)
        P.placeAt(D.rack ? "dj_rack_b" : "dj_rack", DJ_PROP_X["rack"]!, 222, false, 0)
        P.placeAt("dj_drum", DJ_PROP_X["drum"]! + jit(D.drum), 222, false, 0)
        P.placeAt("dj_bag@\(djIdx(DJ_BAG_A, deg(D.bag)))", DJ_PROP_X["bag"]!, 100, false, 0)
        drawShots(&P)
        P.ox = 0; P.depth = 0
    }

    /// 돌면서 날아가는 병 · 던진 짐 상자(무도장 · 건널목은 TR.dy 없이)
    func drawShots(_ P: inout Painter) {
        for s in I.shots {
            if s.friendly { P.quad("sb_box", jsRound(s.x) - 5, jsRound(s.y) - 4); continue }
            if s.kind == "news" { P.placeAt(newsShot(s), jsRound(s.x) - 4, jsRound(s.y) - 4, s.vx < 0, 0); continue }
            let k = m32(jsRound(s.t * 40) * (s.vx < 0 ? -1 : 1))
            P.placeAt("sb_bottle@" + jsStr(k), jsRound(s.x), jsRound(s.y), false, 0)
        }
    }

    /// 웹 drawCrossBack(time) — 하늘 · 해 · 흐르는 구름 · 언덕 · 선로 · 가선 기둥 · 전차(두 칸 · 바퀴) · 가선 · 건널목 기둥 · 경보등 · 바닥 · 창빛 · 바닥 단풍
    func drawCrossBack(_ X: SceneInput.Cross, _ P: inout Painter) {
        let time = I.time
        P.depth = 0.95
        var x = 0.0; while x < SB.W { P.quad("xc_sky", x, 0); x += 16 }
        P.placeAt("xc_sun", XC.SUN.0, XC.SUN.1, false, 0)
        P.depth = 0.93
        for (n, x0, y, sp) in [("xc_cloud0", 60.0, 40.0, 4.5), ("xc_cloud1", 300, 22, 7), ("xc_cloud2", 180, 98, 10)] {   // 구름은 천천히 흐른다
            let w = Double(K.sprites[n]?.w ?? 0), span = SB.W + w
            P.quad(n, jsRound(jsMod(jsMod(x0 + time * sp, span) + span, span) - w), y)
        }
        P.depth = 0.9; P.quad("xc_hills", 0, 150); P.quad("xc_hills", 240, 150)
        P.depth = 0.85; x = 0; while x < SB.W { P.quad("xc_track", x, 198); x += 96 }
        P.depth = 0.83; for cx in XC.CS { P.placeAt("xc_cpole", cx, 211, false, 0) }
        if let T = X.tr {
            let cars = CrossGeom.cars(T), wk = toInt32(jsFloor(T.dist / 4)) & 3
            P.depth = 0.8
            if cars.count == 2 { P.placeAt("xc_bel", jsRound((cars[0].cx + cars[1].cx) / 2), XC.TY - 20, false, 0) }
            for (i, c) in cars.enumerated() {
                let bump = Double(toInt32(jsFloor((c.cx + Double(i) * 37) / 40)) & 1), cx = jsRound(c.cx)
                P.placeAt(T.kind == "B" ? "xc_carB" : "xc_carA", cx, XC.TY - bump, c.fl, 0)   // 이음매마다 1px 출렁
                for b in XC.bog { for o in [-8.0, 8] { let (x0, _) = CrossGeom.span(c, b + o, b + o); P.placeAt("xc_wh@\(wk)", jsRound(x0), 198, false, 0) } }
            }
        }
        P.depth = 0.8; P.quad("xc_cat", 0, XC.CW - 17)
        P.depth = 0.6
        for (i, px) in DJ_POLES.enumerated() {                                    // 건널목 기둥 = 기둥 튕기기 자리
            P.placeAt("xc_post", px, 222, false, 0)
            if X.bell { let on = jsMod(jsFloor(time * 2.4) + Double(i), 2) == 0; P.placeAt("xc_lamp", px + (on ? -9 : 9), 144, false, 0) }
        }
        P.depth = 0.55; P.quad("xc_wires", 0, 24)
        P.depth = 0.3; x = 0; while x < SB.W { P.quad("xc_floor", x, 222); x += 96 }
        if let T = X.tr, T.warn <= 0 {                                            // 창으로 든 빛이 바닥에 비스듬히
            P.depth = 0.28
            for w in CrossGeom.winList(T) {
                if w.x < -30 || w.x > SB.W + 30 { continue }
                let b = max(0, 1 - abs(w.x - XC.SUN.0) / 130), rx = toInt32(jsRound(w.x))
                if b < 0.08 && ((rx >> 4) & 1) != 0 { continue }
                let k = b > 0.6 ? 3 : b > 0.3 ? 2 : 1
                P.placeAt("xc_patch@\(k)", jsRound(w.x - 30), 228 + Double((rx >> 3) & 1) * 4, false, 0)
            }
        }
        P.depth = 0.25
        for L in X.leaves where (L.h ?? 0) <= 0 { P.placeAt(CrossGeom.key(L), jsRound(L.x), jsRound(L.gy), false, 0) }
        drawShots(&P)
        P.ox = 0; P.depth = 0
    }

    /// 웹 drawCrossFront() — 날리는 잎 · 떨어지는 잎(사람 앞)
    func drawFront(_ X: SceneInput.Cross) -> [SpriteDraw] {
        guard cross else { return [] }
        var P = Painter(K.sprites)
        for L in X.leaves where (L.h ?? 0) > 0 { P.placeAt(CrossGeom.key(L), jsRound(L.x), jsRound(L.gy - (L.h ?? 0)), false, 0) }
        for F in X.fall { P.placeAt(CrossGeom.key(F), jsRound(F.x), jsRound(F.y ?? F.gy), false, 0) }
        return P.out
    }

    /// 웹 dojoLights(time) / crossLights(time)
    func lights(_ X: SceneInput.Cross) -> [SceneLight] {
        let time = I.time
        if cross {
            var L: [SceneLight] = []
            let T = X.tr.flatMap { $0.warn <= 0 ? $0 : nil }, k = CrossGeom.sunK(X.tr)
            L.append(SceneLight(x: XC.SUN.0, y: XC.SUN.1 + 10, z: 120, r: 620, c: [1, 0.6, 0.36], i: 0.75 * (0.35 + 0.65 * k)))   // 지는 해
            L.append(SceneLight(x: 80, y: 30, z: 90, r: 520, c: [0.62, 0.44, 0.82], i: 0.4))                                    // 하늘빛(보라) 채움
            L.append(SceneLight(x: 240, y: 150, z: 70, r: 280, c: [1, 0.76, 0.56], i: 0.5 * (0.55 + 0.45 * k)))                 // 사람 앞쪽 따뜻한 채움
            if X.bell {
                for (i, px) in DJ_POLES.enumerated() {
                    let on = jsMod(jsFloor(time * 2.4) + Double(i), 2) == 0
                    L.append(SceneLight(x: px + (on ? -9 : 9), y: 144, z: 16, r: 70, c: [1, 0.18, 0.12], i: 1.1, em: true))  // 건널목 적색등
                }
            }
            if let T {
                let W = stableSorted(CrossGeom.winList(T).filter { $0.x > -20 && $0.x < SB.W + 20 }, by: { abs($0.x - XC.SUN.0) }).first
                if let W { L.append(SceneLight(x: W.x, y: 200, z: -40, r: 210, c: [1, 0.7, 0.4], i: 1.4 * k)) }                  // 해 쪽 창빛(뒤에서 테두리)
                let hd = CrossGeom.head(T)
                if hd.x > -320 && hd.x < SB.W + 320 {
                    L.append(SceneLight(x: hd.x + T.dir * 30, y: hd.y, z: 22, r: 260, c: [1, 0.9, 0.7], i: 0.95, spot: [T.dir, 0.05], cone: 0.96))   // 전조등
                }
            } else { L.append(SceneLight(x: 240, y: 236, z: 10, r: 300, c: [1, 0.7, 0.5], i: 0.25)) }                          // 바닥 되튐
            if X.spk > 0 { L.append(SceneLight(x: X.spkX, y: XC.CW + 6, z: 30, r: 340, c: [0.7, 0.85, 1], i: 2.4 * X.spk / 0.14, em: true)) }   // 팬터그래프 불꽃
            return L
        }
        var L: [SceneLight] = []
        for x in DJ_ANDON { L.append(SceneLight(x: x, y: 98, z: 46, r: 205, c: [1, 0.88, 0.7], i: 1.15)) }       // 천장 종이 등(안돈)
        for x in DJ_ANDON { L.append(SceneLight(x: x, y: 66, z: 16, r: 120, c: [1, 0.82, 0.6], i: 0.6)) }        // 등이 천장 널판을 비추는 윗빛
        for (k, x) in [150.0, 330].enumerated() {                                                                   // 붉은 등롱
            let sw = sin(k < D.lamps.count ? D.lamps[k] : 0) * 10
            L.append(SceneLight(x: x + sw, y: 112, z: 18, r: 150, c: [1, 0.6, 0.32], i: 1.3, em: true))
        }
        for (a, b) in DJ_WIN { L.append(SceneLight(x: (a + b) / 2, y: 172, z: 34, r: 130, c: [0.6, 0.74, 1], i: 0.75)) }   // 창으로 드는 달빛
        L.append(SceneLight(x: 240, y: 104, z: 14, r: 64, c: [1, 0.82, 0.55], i: 0.45))                             // 현판
        L.append(SceneLight(x: 256, y: 226, z: 8, r: 250, c: [1, 0.75, 0.5], i: 0.32))                              // 마루에서 되튀는 빛
        return L
    }

    /// 웹 dojoFX() / crossFX()
    func fx(_ X: SceneInput.Cross) -> PostFX {
        if cross {
            let T = X.tr.flatMap { $0.warn <= 0 ? $0 : nil }
            var vols = [VolumeLight(x: XC.SUN.0, y: XC.SUN.1, dx: -0.5, dy: -0.2, c: [1, 0.7, 0.45], i: 0.07, cone: 2, len: 1, halo: 22)]
            var expo = 0.94, bloom = 0.9
            if let T {
                expo *= 0.9 + 0.1 * CrossGeom.sunK(X.tr)
                let ws = CrossGeom.winList(T).map { ($0, max(0, 1 - abs($0.x - XC.SUN.0) / 110)) }.filter { $0.1 > 0.05 }
                for (w, b) in stableSorted(ws, by: { -$0.1 }).prefix(4) {                // 창으로 뚫고 나오는 빛줄기
                    vols.append(VolumeLight(x: w.x, y: w.y, dx: -0.3, dy: 0.95, c: [1, 0.72, 0.42], i: 0.2 * b, cone: 0.9, len: 80, halo: 4))
                }
                let hd = CrossGeom.head(T)
                vols.append(VolumeLight(x: hd.x, y: hd.y, dx: T.dir, dy: 0.03, c: [1, 0.92, 0.75], i: 0.13, cone: 0.96, len: 240, halo: 5))   // 전조등 빛기둥
            }
            if X.spk > 0 { let q = X.spk / 0.14; expo += 0.3 * q; bloom += 0.6 * q }
            return PostFX(expo: expo, winR: 0, winY: [0, 0], press: 0, bloom: bloom, reflY: SB.FLOOR - 1, rain: 0, vig: 0.3, fog: 0.07,
                          fogC: [0.36, 0.16, 0.14], inv: 0, grade: [1.1, 0.97, 0.86], sat: 1.08, vols: vols)
        }
        var vols: [VolumeLight] = []
        for (a, b) in DJ_WIN { vols.append(VolumeLight(x: (a + b) / 2, y: 156, dx: 0.36, dy: 0.93, c: [0.72, 0.84, 1], i: 0.2, cone: 0.82, len: 120, halo: 8)) }
        for x in DJ_ANDON { vols.append(VolumeLight(x: x, y: 100, dx: 0, dy: 1, c: [1, 0.9, 0.72], i: 0.2, cone: 0.72, len: 110, halo: 10)) }
        for (k, x) in [150.0, 330].enumerated() {
            vols.append(VolumeLight(x: x + sin(k < D.lamps.count ? D.lamps[k] : 0) * 10, y: 116, dx: 0, dy: 1, c: [1, 0.7, 0.4], i: 0.22, cone: 2, len: 1, halo: 14))
        }
        return PostFX(expo: 1.12, winR: 0, winY: [0, 0], press: 0, bloom: 1.0, reflY: SB.FLOOR - 1, rain: 0, vig: 0.34, fog: 0.05,
                      fogC: [0.18, 0.12, 0.07], inv: 0, grade: [1.07, 1.0, 0.9], sat: 1.06, vols: vols)
    }
}
