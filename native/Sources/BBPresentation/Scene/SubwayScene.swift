import Foundation
import BBContent

// 지하철 장면 구성 — 웹 22-scene-world.js(drawSubwayBack · drawElBack · drawStation · drawElStation · nycStations · bridgeSpan ·
// drawCarLayer · subwayLights · eyeAdapt · subwayFX · subwayFX0) + 37-gimmicks(drawPassTrain · passTrainLights) +
// 29-combat-flow(showBulbK) 1:1 이식. 순수 함수: 입력(SceneInput)만 읽고, 웹이 숨겨서 바꾸던 상태는 SceneEffects 로 돌려준다.

/// 지금 보이는 역(웹 nycStations 원소)
struct VisibleStation { let id: String; let c: Double; let pass: Bool; let sx: Double }
/// 다리 구간이 화면에 걸친 범위(웹 bridgeSpan)
struct BridgeSpan { let p0: Double, p1: Double, full: Bool, sunK: Double }

struct SubwayContext {
    let I: SceneInput
    let K: SceneContent
    let stage: StageDef
    let line: [CarDef]
    let car: CarConcept
    let st: [VisibleStation]
    let brg: BridgeSpan?
    /// STAGE.el 이 참인지 · 'q'(7 열차 퀸스 네온 변형)인지
    let el: Bool, elQ: Bool

    init(_ I: SceneInput, _ K: SceneContent) {
        self.I = I; self.K = K
        stage = K.stages[max(0, min(I.stage, K.stages.count - 1))]
        line = stage.line
        let ci = Int(I.ci ?? 0)                                       // LINE[GS.ci||0]
        car = K.cars[line[min(max(ci, 0), line.count - 1)].car]
        switch stage.el {
        case .bool(let b)?: el = b; elQ = false
        case .string(let s)?: el = !s.isEmpty; elQ = s == "q"
        case .number(let n)?: el = n != 0 && !n.isNaN; elQ = false
        case .array?, .object?: el = true; elQ = false
        default: el = false; elQ = false
        }
        st = SubwayContext.nycStations(I, stage)
        brg = SubwayContext.bridgeSpan(I, line)
    }

    /// LINE[GS.leg] (없으면 nil)
    static func legCar(_ I: SceneInput, _ line: [CarDef]) -> CarDef? {
        guard let l = I.leg, l >= 0, l == l.rounded(), Int(l) < line.count else { return nil }
        return line[Int(l)]
    }

    static func nycStations(_ I: SceneInput, _ stage: StageDef) -> [VisibleStation] {
        let line = stage.line
        let leg = legCar(I, line) ?? line[line.count - 1]
        let legStart = I.legStart ?? 0                                  // GS.legStart||0
        let stops: [String?] = [stage.start] + line.map(\.stop)
        let li = Int(I.leg ?? 0)
        var L: [(String?, Double, Bool)] = [(li >= 0 && li < stops.count ? stops[li] : nil, legStart, false)]
        for p in leg.passes ?? [] { L.append((p[0]?.string, legStart + (p[1]?.double ?? .nan), true)) }
        for q in leg.quick ?? [] { L.append((q[0]?.string, legStart + (q[1]?.double ?? .nan), false)) }
        let late = ["arrive", "shop", "arrange", "final", "end"].contains(I.state)
        if (I.arriving || late), let ns = I.nextStop, !ns.isEmpty { L.append((ns, I.train.stopAt, false)) }
        return L.compactMap { id, c, pass in
            let sx = c - I.train.ex + SB.W / 2
            guard abs(sx - SB.W / 2) < NY.LEN / 2 + SB.W, let id else { return nil }
            return VisibleStation(id: id, c: c, pass: pass, sx: sx)
        }
    }

    static func bridgeSpan(_ I: SceneInput, _ line: [CarDef]) -> BridgeSpan? {
        guard let L = legCar(I, line), let b = L.bridge, I.on else { return nil }
        let p0 = (I.legStart ?? .nan) + b.b0 - I.train.ex + SB.W / 2, p1 = p0 + b.len
        if p1 < -40 || p0 > SB.W + 40 { return nil }
        return BridgeSpan(p0: p0, p1: p1, full: p0 <= 0 && p1 >= SB.W,
                          sunK: max(0, min(1, (min(p1, SB.W) - max(p0, 0)) / SB.W)))
    }

    func inStation(_ x: Double) -> Bool { st.contains { abs(x - $0.sx) < NY.LEN / 2 } }
    func inBridge(_ x: Double) -> Bool { if let B = brg { x > B.p0 && x < B.p1 } else { false } }
    func station(_ id: String) -> StationLook { K.stations[id] ?? StationLook(.object([:])) }
    /// 웹 showBulbK
    func showBulbK(_ x: Double) -> Double {
        var b: SceneInput.ShowLamp?, dd = 1e9
        for L in I.showLamps { let q = abs(L.x - x); if q < dd { dd = q; b = L } }
        if let b, dd <= 60 { return b.k }
        return 1
    }
}

// MARK: - 그리기(배경 층)

extension SubwayContext {
    /// 웹 drawSubwayBack(복도 · 타워 · 무도장 분기 뒤, 지하철 · 고가선 몸통)
    func drawBack<R: SceneRandom>(_ P: inout Painter, _ fx: inout SceneEffects, _ rng: inout R) {
        if el { drawElBack(&P, &fx, &rng); return }
        let time = I.time, ex = I.train.ex
        let tt = I.train.v > 380 ? "sb_tunnelB" : "sb_tunnel"
        P.depth = 0.85
        if let BRG = brg, let lb = SubwayContext.legCar(I, line)?.bridge {   // 실외: 하늘 → 스카이라인 → 다리 → 강 → 갈매기 → 트러스 · 양 끝 터널 입구
            let bx = ex - ((I.legStart ?? .nan) + lb.b0)
            P.quad("br_sky", 0, 0)
            let so = -jsRound(jsMod(bx * 0.04, 960)); P.quad("br_skyline", so, BR.HZ - 84); P.quad("br_skyline", so + 960, BR.HZ - 84)
            P.quad("br_bk", jsRound(430 - bx * 0.09), BR.HZ - 128)
            let wo = -jsRound(jsMod(bx * 0.3, SB.W)); P.quad("br_water", wo, BR.HZ); P.quad("br_water", wo + SB.W, BR.HZ)
            for k in 0..<26 {
                let kd = Double(k), gy = BR.HZ + 3 + jsMod(kd * 7, 28), spread = 2 + gy - BR.HZ
                let gx = BR.SUN.0 - spread + jsMod(kd * 37 + jsFloor(time * 9) * 13, spread * 2 + 1)
                if truthy(jsMod(kd + jsFloor(time * 7), 3)) { P.quad("br_glint", jsRound(gx), gy) }
            }
            for k in 0..<3 {
                let kd = Double(k)
                P.quad("br_gull", jsRound(jsMod(380 - kd * 90 - bx * 0.06 + time * 12 * (kd + 1), 520) + 20) - 20,
                       40 + kd * 14 + jsRound(sin(time * 2 + kd) * 2))
            }
            let to = -jsRound(jsMod(ex, 192)); var x = to
            while x < SB.W { P.quad("br_truss", x, 0); x += 192 }
            if BRG.p0 > -24 { var x = BRG.p0 - SB.W; while x > -SB.W { P.quad(tt, x, 0); x -= SB.W }; P.quad("br_portal", BRG.p0 - 24, 0) }
            if BRG.p1 < SB.W + 24 { var x = BRG.p1; while x < SB.W { P.quad(tt, x, 0); x += SB.W }; P.quad("br_portal", BRG.p1, 0) }
        } else { let off = -jsRound(jsMod(ex, SB.W)); P.quad(tt, off, 0); P.quad(tt, off + SB.W, 0) }   // 빠르면 잔상 타일
        let k0 = jsFloor(ex / 260)
        for k in 0..<4 {
            let x = jsRound((k0 + Double(k)) * 260 - ex) + 40
            if x < -60 || x > SB.W + 20 || inStation(x) || inBridge(x) { continue }
            P.placeAt("sb_lamp", x, 172, false, 0); P.placeAt("sb_lamp", x, 62, false, 0)
            if I.train.v > 250 { P.quad("sb_streak", x + 5, 173); P.quad("sb_streak", x + 5, 63) }
        }
        for o in st { drawStation(&P, o) }
        let co = -jsRound(jsMod(ex * 1.15, 48)); var x = co                  // 선로 사이 강철 기둥
        while x < SB.W { if !inStation(x) && !inBridge(x) { P.quad("ny_col", x, 26) }; x += 48 }
        drawPassTrain(&P); drawCarLayer(&P, &fx, &rng)
    }

    /// 웹 drawStation
    func drawStation(_ P: inout Painter, _ o: VisibleStation) {
        let S = station(o.id), x0 = jsRound(o.sx - NY.LEN / 2), x1 = x0 + NY.LEN, id = o.id
        let vis = { (x: Double) in x > -260 && x < SB.W + 20 }
        if S.vault {
            var x = x0
            while x < x1 { if vis(x) { P.quad("ch_vault", x, 0); for lx in [52.0, 172] { P.quad("ch_lamp", x + lx, 96) } }; x += 240 }
        } else {
            var x = x0
            while x < x1 {
                if vis(x) {
                    P.quad("ny_ceil", x, 0); P.quad(S.ruin ? "ny_ruin" : S.brick ? "ny_brick" : "ny_wall", x, NY.CEIL)
                    if S.band { P.quad("ny_band_" + id, x, NY.BAND) }
                }
                x += 240
            }
        }
        if K.sprites["ny_cap_" + id] != nil { var x = x0 + 44; while x < x1 - 20 { if vis(x) { P.quad("ny_cap_" + id, x, S.band ? NY.CAP : NY.BAND + 2) }; x += 120 } }
        if S.big { var x = x0 + 70; while x < x1 - 60 { if vis(x) { P.quad("ny_big_" + id, x, NY.BAND - 4) }; x += 160 } }
        if S.tab, let T = K.sprites["ny_tab_" + id] {
            let D = K.sprites["ny_dir_" + id]
            for k in -1...1 {
                let x = jsRound(o.sx + Double(k) * 320 - Double(T.w) / 2)   // 가운데 이름판이 정차 때 가운데 창에 오게
                if vis(x) { P.quad("ny_tab_" + id, x, NY.TAB); if let D { P.quad("ny_dir_" + id, x + Double((T.w - D.w) >> 1), NY.DIR) } }
            }
        }
        var x = x0 + 28
        while x < x1 { if vis(x) { P.quad("ny_beam_" + S.beam, x, 0) }; x += 64 }   // 선로 사이 I-빔
        for e in [x0, x1 - 4] where vis(e) { P.quad("ny_beam_black", e, 0) }       // 승강장 끝
    }

    /// 웹 drawElBack — 고가선(밤)
    func drawElBack<R: SceneRandom>(_ P: inout Painter, _ fx: inout SceneEffects, _ rng: inout R) {
        let ex = I.train.ex, Q = elQ
        P.depth = 0.85
        P.quad(Q ? "q_sky" : "el_sky", 0, 0)
        let fo = -jsRound(jsMod(ex * 0.03, 960))
        if Q { P.quad("q_far", fo, EL.HZ - 74); P.quad("q_far", fo + 960, EL.HZ - 74) } else { P.quad("el_far", fo, EL.HZ - 50); P.quad("el_far", fo + 960, EL.HZ - 50) }
        let legStart = I.legStart ?? .nan
        if !Q && I.leg == 0 { let yx = jsRound(250 - (ex - legStart) * 0.22); if yx > -380 && yx < SB.W { P.quad("el_yankee", yx, EL.HZ - 74) } }
        if Q, let L = SubwayContext.legCar(I, line), L.stop == "mets" {
            let yx = jsRound(SB.W + 40 - (ex - legStart) * 0.22 + 900); if yx > -400 && yx < SB.W { P.quad("q_ball", yx, EL.HZ - 70) }
        }
        let bo = -jsRound(jsMod(ex * 0.45, 480))
        if Q { P.quad("q_bld", bo, 58); P.quad("q_bld", bo + 480, 58) } else { P.quad("el_bld", bo, 92); P.quad("el_bld", bo + 480, 92) }
        for o in st { drawElStation(&P, o) }
        let so = -jsRound(jsMod(ex, 192)); var x = so
        while x < SB.W { if !inStation(x + 96) { P.quad("el_struct", x, 150) }; x += 192 }
        drawPassTrain(&P); drawCarLayer(&P, &fx, &rng)
    }

    /// 웹 drawElStation
    func drawElStation(_ P: inout Painter, _ o: VisibleStation) {
        let x0 = jsRound(o.sx - NY.LEN / 2), x1 = x0 + NY.LEN
        let vis = { (x: Double) in x > -260 && x < SB.W + 20 }
        var x = x0
        while x < x1 { if vis(x) { P.quad("el_plat", x, 0) }; x += 240 }
        if let sg = K.sprites["el_sign_" + o.id] {
            for k in -1...1 {
                let x = jsRound(o.sx + Double(k) * 300 - Double(sg.w) / 2)
                if vis(x) { P.quad("el_sign_" + o.id, x, 26); P.quad("el_sign_" + o.id, x, 166) }
            }
        }
    }

    /// 웹 drawPassTrain(37-gimmicks)
    func drawPassTrain(_ P: inout Painter) {
        guard let t = I.passT else { return }
        let x0 = SB.W + 30 - t * 1500, y = SB.WIN_Y0 - 10 + I.train.dy
        P.quad("pt_head", jsRound(x0) - 22, y)
        for k in 0..<8 { let x = jsRound(x0 + Double(k) * 192); if x < SB.W && x > -192 { P.quad("pt_car", x, y) } }
    }

    /// 웹 drawCarLayer — 선로 · 대차 · 객차 · 문 · 손잡이 · 바닥 물건
    func drawCarLayer<R: SceneRandom>(_ P: inout Painter, _ fx: inout SceneEffects, _ rng: inout R) {
        let C = car, dy = I.train.dy, ex = I.train.ex, TR = I.train
        let ci = I.ci ?? .nan
        P.depth = 0.5
        let toff = -jsRound(jsMod(ex, 20))
        P.quad("sb_track", toff - SB.W, SB.H - 27); P.quad("sb_track", toff, SB.H - 27); P.quad("sb_track", toff + SB.W, SB.H - 27)
        let wf = jsMod(jsFloor(ex / 1.31), 8)
        for bx in [28.0, 376] { P.quad("sb_bogie" + jsStr(wf), bx, 232 + jsRound(TR.jolt)) }
        if let sp = I.brakeSp { for p in sp { P.placeAt("fx_spark" + (p.t < 0.12 ? "0" : p.t < 0.25 ? "1" : "2"), jsRound(p.x), jsRound(p.y), false, 0) } }
        P.depth = 0.3; P.quad("car_" + C.key, 0, SB.CAR_Y + dy)
        do {                                                                  // 패러디 광고 포스터
            let h = jsMod(ci * 7 + (I.stageIdx.flatMap { truthy($0) ? $0 : nil } ?? 0) * 3, 6)
            for (k, x) in [14.0, 188, 246, 420].enumerated() { P.quad("ad_" + jsStr(jsMod(h + Double(k) * 5, 6)), x + 1, SB.CAR_Y + 12 + dy) }
        }
        if ["night", "works", "dark", "redbird", "gang", "cargo"].contains(C.key) {   // 네온 낙서
            for (k, x) in [118.0, 358].enumerated() { P.quad("tag_" + jsStr(jsMod(ci + Double(k), 3)), x - 1, SB.WIN_Y0 + 2 + dy) }
        }
        do {                                                                  // 앞뒤 칸 · 주름 연결 통로
            let G = 8.0
            P.quad("car_" + C.key, -SB.W - G, SB.CAR_Y + dy); P.quad("car_" + C.key, SB.W + G, SB.CAR_Y + dy)
            P.quad("sb_gangway", -G, SB.CAR_Y + 12 + dy); P.quad("sb_gangway", SB.W, SB.CAR_Y + 12 + dy)
        }
        for (a, _) in DOORS { let o = jsRound(TR.door * 15); P.quad("sb_door", a - o, SB.WIN_Y0 - 2 + dy); P.quad("sb_door", a + 17 + o, SB.WIN_Y0 - 2 + dy) }
        if C.fans == true { for x in [112.0, 232, 352] { P.quad("sb_fan" + jsStr(jsMod(jsFloor(TR.t * 14 + x), 3)), x - 9, SB.CAR_Y + 9 + dy) } }
        if C.lanterns == true {
            for x in [96.0, 216, 336] { let sw = jsRound(sin(TR.t * 2.2 + x) * 1.5 + TR.a * -0.004); P.quad("sb_lanternR", x - 4 + sw, SB.CAR_Y + 10 + dy) }
        }
        if C.marquee == true {                                                // 쇼 칸 전구 줄
            let ph = jsFloor(TR.t * 9)
            func bs(_ on: Double, _ lk: Double) -> String { lk < 0.3 ? "sb_bulbOff" : lk > 1.4 ? "sb_bulbOn" : (truthy(on) ? "sb_bulbOn" : "sb_bulbOff") }
            for k in 0..<39 {
                let kd = Double(k), x = 10 + kd * 12
                P.quad(bs(jsMod(kd + ph, 3), showBulbK(x)), x - 1, SB.CAR_Y + 4 + dy)
                P.quad(bs(jsMod(kd + ph + 1, 3), showBulbK(x + 6)), x + 5, SB.CAR_Y + 30 + dy)
            }
        }
        if C.gears == true {                                                  // 놋쇠 톱니 · 랜턴
            for x in [72.0, 192, 312, 432] { P.placeAt("sb_gear", x, SB.CAR_Y + 15 + dy, jsMod(jsFloor(TR.t * 4) + x, 2) == 0, 0) }
            for x in [132.0, 252, 372] { P.quad("sb_lantern", x, SB.CAR_Y + 22 + dy) }
        }
        var x = 18.0                                                          // 천장 손잡이
        while x < SB.W - 18 {
            defer { x += 26 }
            if DOORS.contains(where: { x > $0.0 - 6 && x < $0.1 + 6 }) { continue }
            if let h = I.holders.first(where: { $0.strapX == x }) {           // 잡힌 손잡이: 고리가 손 위치에
                let loopY = jsRound(h.y + (h.handDY ?? .nan)) - 8, top = 156 + dy
                var yy = top
                while yy < loopY { P.placeAt("sb_strapseg", x, yy, false, 0); yy += 6 }
                P.placeAt("sb_strap@0", x, jsMax(top - 4, loopY), false, 0)
                continue
            }
            let sa = I.straps.first(where: { $0.x == x })?.a ?? 0
            let ang = TR.strap + sin(x * 0.7 + TR.t * 0.8) * 0.05 + (truthy(sa) ? sa : 0)
            P.placeAt("sb_strap@" + jsStr(m32(jsRound(ang / (Double.pi / 16)))), x, 156 + dy, false, 0)
        }
        for x in POLES { P.quad("sb_pole", x - 3, SB.CAR_Y + 12 + dy) }
        for p in I.props {
            if p.k == "puddle" { P.quad("sb_puddle", jsRound(p.x), SB.FLOOR - 2 + dy); P.quad("sb_cup", jsRound(p.x) + 13, SB.FLOOR - 4 + dy) }
            else { P.quad("sb_box", jsRound(p.x) - 5, SB.FLOOR - 8 + dy) }
        }
        for c in I.cans { P.placeAt("sb_can", jsRound(c.x), SB.FLOOR - 1 + dy, c.v < 0, 0) }
        for s in I.shots {                                                    // 돌면서 날아가는 병 · 던진 짐 상자
            if s.friendly { P.quad("sb_box", jsRound(s.x) - 5, jsRound(s.y) - 4 + dy); continue }
            if s.kind == "news" { P.placeAt(newsShot(s), jsRound(s.x) - 4, jsRound(s.y) - 4 + dy, s.vx < 0, 0); continue }   // 네이티브: 펄럭이며 날아가는 신문 뭉치
            let k = m32(jsRound(s.t * 40) * (s.vx < 0 ? -1 : 1))
            P.placeAt("sb_bottle@" + jsStr(k), jsRound(s.x), jsRound(s.y) + dy, false, 0)
        }
        if C.works == true && rng.next() < 0.025 {                            // 뜯긴 패널 배선에서 튀는 불꽃 → 숨은 상태 변경을 출력으로
            let sx = [30.0, 210, 410][Int(jsFloor(rng.next() * 3))] + jsFloor(rng.next() * 30)
            fx.sparks.append(.init(x: sx, y: SB.CAR_Y + 60 + dy, age: 1))
            if I.hasBits {
                for _ in 0..<4 {
                    let vx = (rng.next() - 0.5) * 70, vy = -(20 + rng.next() * 60)
                    fx.bits.append(.init(x: sx, y: SB.CAR_Y + 60 + dy, vx: vx, vy: vy, t: 0.3))
                }
            }
        }
    }
}

// MARK: - 광원

extension SubwayContext {
    /// 웹 subwayLights(지하철 몸통)
    func lights<R: SceneRandom>(_ rng: inout R) -> [SceneLight] {
        var L: [SceneLight] = []
        let C = car, dy = I.train.dy, TR = I.train
        if C.oneBit == true && I.oneBit {                                     // 정전 칸: 작은 붉은 비상등 둘
            for x in [130.0, 350] {
                L.append(SceneLight(x: x, y: SB.CAR_Y + 44 + dy, z: 30, r: 100, c: [1, 0.36, 0.28], i: 1.2 * (x == 350 ? 1 - TR.flickS * 0.85 : 1), em: true))
            }
        } else {
            for (k, x) in [(0, 64.0), (1, 184), (2, 304), (3, 424)] {
                if C.broken == true && k == 2 { continue }
                var i = 1.05
                if (C.broken == true || C.works == true) && k == 1 { i *= 1 - 0.85 * TR.flickS }
                if brg != nil && (k == 0 || k == 3) { continue }
                if brg != nil { i *= 0.5 }                                    // 낮 구간: 실내등은 반쯤만
                L.append(SceneLight(x: x, y: SB.CAR_Y + 7 + dy, z: 24, r: 118, c: C.light, i: i * (C.li ?? 1)))
            }
        }
        if let B = brg {
            for (px, dir) in [(B.p0, -1.0), (B.p1, 1)] where px > -140 && px < SB.W + 140 {   // 터널 입구 햇빛
                L.append(SceneLight(x: px + dir * 26, y: 96, z: 40, r: 210, c: [1, 0.74, 0.48], i: 1.5))
            }
            for wx in [59.0, 200, 280, 422] {                                 // 창으로 쏟아지는 노을빛 · 트러스 그림자
                if !inBridge(wx) { continue }
                let ph = jsMod(jsMod(wx + TR.ex, 96) + 96, 96), d = min(ph, 96 - ph), open = d < 9 ? 0.25 : 1
                L.append(SceneLight(x: wx, y: 176, z: 10, r: 120, c: [1, 0.62, 0.32], i: 1.55 * open))
            }
            L.append(SceneLight(dirl: [-0.55, 0.35, 0.3], c: [1, 0.6, 0.32], i: 0.5 * B.sunK))
            return L
        }
        var sl: [SceneLight] = []                                             // 역 형광등(역이 화면을 덮은 만큼)
        for o in st {
            let x0 = o.sx - NY.LEN / 2, x1 = x0 + NY.LEN, cover = max(0, min(1, (min(x1, SB.W) - max(x0, 0)) / 240))
            var x = x0 + 60
            while x < x1 {
                if x > -60 && x < SB.W + 60 {
                    let S2 = station(o.id)
                    let fl = S2.ruin ? (sin(I.gsTime * 23 + x) * sin(I.gsTime * 7.3) > 0.55 ? 0.25 : 1) : 1
                    sl.append(SceneLight(x: x, y: 30, z: 50, r: 230, c: S2.vault ? [1, 0.78, 0.52] : S2.ruin ? [0.55, 0.86, 0.62] : [0.92, 0.97, 1],
                                         i: (S2.ruin ? 0.8 : 1.45) * cover * fl))
                }
                x += 180
            }
        }
        if !sl.isEmpty { L += stableSorted(sl) { abs($0.x - 240) }.prefix(2) }
        else if el {                                                          // 거리의 나트륨 가로등
            let k0 = jsFloor(TR.ex * 0.45 / 300); var tl: [SceneLight] = []
            for k in 0..<3 { let x = jsRound((k0 + Double(k)) * 300 - TR.ex * 0.45) + 60; if x > -60 && x < SB.W + 60 { tl.append(SceneLight(x: x, y: 200, z: 20, r: 150, c: [1, 0.6, 0.28], i: 0.95)) } }
            L += tl.prefix(2)
        } else {                                                              // 터널등
            let k0 = jsFloor(TR.ex / 260); var tl: [SceneLight] = []
            for k in 0..<4 { let x = jsRound((k0 + Double(k)) * 260 - TR.ex) + 43; if x > -40 && x < SB.W + 40 { tl.append(SceneLight(x: x, y: 176, z: 7, r: 115, c: [1, 0.74, 0.42], i: 1.25)) } }
            L += tl.prefix(2)
        }
        if C.gears == true { for x in [134.0, 374] { L.append(SceneLight(x: x, y: SB.CAR_Y + 26 + dy, z: 16, r: 70, c: [1, 0.62, 0.25], i: 1.1)) } }
        if C.lanterns == true { for x in [96.0, 336] { L.append(SceneLight(x: x, y: SB.CAR_Y + 18 + dy, z: 14, r: 84, c: [1, 0.38, 0.22], i: 1.2)) } }
        if C.strobe == true {                                                 // 클럽 칸: 박자마다 색이 바뀌는 조명
            let bt = I.gsTime * 2.1, b = jsFloor(bt), ph = bt - b, pulse = 1 - ph * 0.7
            for k in 0..<2 {
                let x = k != 0 ? 360 - jsMod(b * 97, 160) : 120 + jsMod(b * 61, 140)
                L.append(SceneLight(x: x, y: SB.CAR_Y + 12 + dy, z: 16, r: 126, c: STROBE_COLS[Int(jsMod(b + Double(k) * 2, 4))], i: 1.35 * pulse))
            }
        }
        if C.marquee == true {
            for Lp in I.showLamps {
                if Lp.k > 0.02 { L.append(SceneLight(x: Lp.x, y: SB.CAR_Y + 8 + dy, z: 14, r: 110, c: [1, 0.82, 0.5], i: 1.15 * Lp.k)) }
                if Lp.sparkT > 0 { L.insert(SceneLight(x: Lp.x, y: SB.CAR_Y + 10 + dy, z: 8, r: 46, c: [1, 0.95, 0.75], i: 2.4 * min(1, Lp.sparkT / 0.08)), at: 0) }
            }
        }
        if I.brakeGlow > 0.02 {                                               // 제동 불꽃 빛(앞에)
            for x in [66.0, 414] { L.insert(SceneLight(x: x, y: 256, z: 6, r: 52, c: [1, 0.62, 0.26], i: (1.1 + rng.next() * 0.6) * I.brakeGlow), at: 0) }
        }
        if C.cab == true { L.append(SceneLight(x: 468, y: 176, z: 18, r: 320, c: [1, 0.95, 0.8], i: 1.5, spot: [1, 0], cone: 0.82)) }
        passTrainLights(&L, &rng)
        if C.oneBit == true && I.oneBit { for j in L.indices where L[j].em != true { L[j].i *= 0.45 } }   // 정전 칸: 바깥 빛만 약하게
        return L
    }

    /// 웹 passTrainLights
    func passTrainLights<R: SceneRandom>(_ L: inout [SceneLight], _ rng: inout R) {
        guard let t = I.passT else { return }
        let x0 = SB.W + 30 - t * 1500; var n = 0
        for k in 0..<8 where n < 2 {
            let x = x0 + Double(k) * 192 + 60
            if x > -40 && x < SB.W + 40 { L.insert(SceneLight(x: x, y: 176, z: 40, r: 170, c: [0.95, 0.97, 1], i: 1.9 * (0.7 + 0.3 * rng.next())), at: 0); n += 1 }
        }
    }
}

// MARK: - 후처리

extension SubwayContext {
    /// 웹 eyeAdapt — 눈 적응(자동 노출). 웹은 GS 에 상태를 숨겨 바꾼다 → 새 상태를 돌려준다
    func eyeAdapt(_ eye: inout EyeAdaptState) -> Double {
        let now = I.eye.now
        let adT = eye.adT.flatMap { truthy($0) ? $0 : nil } ?? now        // GS.adT||now
        let ps = truthy(I.eye.playSpeed) ? I.eye.playSpeed : 1
        let dt = min(0.1, now - adT) * ps
        eye.adT = now
        var out = 0.0
        if let Lb = SubwayContext.legCar(I, line), let b = Lb.bridge {
            let ls = I.legStart ?? .nan
            out = I.train.ex >= ls + b.b0 && I.train.ex < ls + b.b0 + b.len ? 1 : 0
        }
        let o0 = eye.outS ?? out
        let outS = o0 + (out - o0) * (1 - exp(-dt / 0.15)); eye.outS = outS
        let stK = st.reduce(0.0) { m, o in max(m, max(0, 1 - abs(o.sx - SB.W / 2) / (NY.LEN / 2 + 80))) }
        let Ls = (0.18 + 0.82 * outS + 0.3 * stK * (1 - outS)) * (I.oneBit ? 0.35 : 1)
        let d0 = eye.darkA.flatMap { truthy($0) ? $0 : nil } ?? 0
        let darkA = d0 + ((I.oneBit ? 1 : 0) - d0) * (1 - exp(-dt / (I.oneBit ? 3 : 0.8))); eye.darkA = darkA
        var adA = eye.adA ?? Ls
        let tgtA = I.oneBit ? Ls / 0.35 * 0.85 : Ls
        let tau = tgtA > adA ? 0.45 : 1.6
        adA += (tgtA - adA) * (1 - exp(-dt / tau)); eye.adA = adA
        return max(0.32, min(3, pow(Ls / adA, 0.6))) * (1 + 0.15 * (truthy(darkA) ? darkA : 0))
    }

    /// 웹 subwayFX0 + LINE_GRADE 덮어쓰기(subwayFX 의 지하철 갈래)
    func fx(_ eff: inout SceneEffects) -> PostFX {
        let inv: Double = eff.invF > 0 ? 1 : 0
        if eff.invF > 0 { eff.invF -= 1 }
        var f: PostFX
        if el {
            let m = eyeAdapt(&eff.eye)
            f = PostFX(expo: m, winR: 0.55, winY: [SB.WIN_Y0, SB.WIN_Y1], press: truthy(I.press) ? I.press : 0, bloom: 0.85, reflY: -999, rain: 0,
                       vig: 0.55, fog: 0.1, fogC: [0.12, 0.07, 0.12], inv: inv, grade: nil, sat: nil, vols: [])
        } else {
            let m = eyeAdapt(&eff.eye), winR = I.winROff ? 0 : 0.62, press = truthy(I.press) ? I.press : 0
            if let B = brg {
                let k = B.sunK
                var vols = [VolumeLight(x: BR.SUN.0, y: BR.SUN.1, dx: 0, dy: 1, c: [1, 0.7, 0.36], i: 0.55 * k, cone: 2, len: 1, halo: 30),
                            VolumeLight(x: BR.SUN.0, y: BR.SUN.1, dx: -0.34, dy: 0.94, c: [1, 0.62, 0.3], i: 0.42 * k, cone: 0.94, len: 240, halo: 6)]
                for (px, dir) in [(B.p0, -1.0), (B.p1, 1)] where px > -60 && px < SB.W + 60 {
                    vols.append(VolumeLight(x: px, y: 70, dx: dir * 0.9, dy: 0.44, c: [1, 0.8, 0.55], i: 0.75, cone: 0.86, len: 190, halo: 16))
                }
                f = PostFX(expo: m, winR: winR, winY: [SB.WIN_Y0, SB.WIN_Y1], press: press, bloom: 0.5, reflY: -999, rain: 0, vig: 0.48,
                           fog: 0.08 * k, fogC: [0.3, 0.14, 0.08], inv: inv, grade: nil, sat: nil, vols: vols)
            } else {
                var vols: [VolumeLight] = []
                if car.cab == true { vols.append(VolumeLight(x: 466, y: 176, dx: 1, dy: 0, c: [1, 0.95, 0.8], i: 1.1, cone: 0.9, len: 220, halo: 8)) }
                let k0 = jsFloor(I.train.ex / 260)
                for k in 0..<4 {
                    let x = jsRound((k0 + Double(k)) * 260 - I.train.ex) + 43
                    if x > -30 && x < SB.W + 30 && !inStation(x) { vols.append(VolumeLight(x: x, y: 174, dx: 0, dy: 1, c: [1, 0.74, 0.42], i: 0.5, cone: 2, len: 1, halo: 12)) }
                }
                f = PostFX(expo: m, winR: winR, winY: [SB.WIN_Y0, SB.WIN_Y1], press: press, bloom: 0.9, reflY: -999, rain: 0, vig: 0.62,
                           fog: 0.06, fogC: [0.02, 0.02, 0.04], inv: inv, grade: nil, sat: nil, vols: Array(vols.prefix(6)))
            }
        }
        let gi = Int(I.stageIdx.flatMap { truthy($0) ? $0 : nil } ?? 0)   // LINE_GRADE[GS.stageIdx||0]
        if gi >= 0 && gi < K.lineGrade.count { f.grade = K.lineGrade[gi].grade; f.sat = K.lineGrade[gi].sat }
        return f
    }
}
