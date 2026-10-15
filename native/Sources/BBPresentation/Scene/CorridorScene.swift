import Foundation
import BBContent

// 프롤로그 지하 복도 장면 구성 — 웹 39-prologue.js(drawCorridor · corrLamps · corridorLights) + 22-scene-world.js subwayFX 의 GS.prologue 갈래 1:1 이식.
// 숨은 변경: corrLamps 가 처음 보는 자리의 전등을 Math.random 각도로 P.lamps 에 넣는다 → SceneEffects.corridorLamps(난수는 주입).
//           subwayFX(복도)가 GS.invF 를 깎는다 → SceneEffects.invF. 두드리는 문의 떨림(±1px)도 주입 난수.
// 전등 흔들림 물리(lampTick · lampKick)는 그리기 밖(BBSim 복도 규칙 또는 CorridorLampSwing)이다.

/// 웹 CORR_LEN · CR_PIPE_Y · LAMP_TOP · LAMP_L
enum CORR { static let LEN = 1500.0, PIPE_Y = 130.0, LAMP_TOP = 36.0, LAMP_L = 62.0 }

/// 웹 CORR_SEG — 구간(240)마다 정해진 조합: 문 / 철창 · 배전함 · 그래피티 · 잡동사니
struct CorrSeg { let door: String; let gf: [(String, Double, Double)]; let jbox: Double; let junk: Double }
let CORR_SEG: [CorrSeg] = [
    CorrSeg(door: "door", gf: [("gf_ltn", 8, 74), ("gf_tag1", 150, 112)], jbox: 52, junk: 180),
    CorrSeg(door: "gate", gf: [("gf_mob", 10, 82), ("gf_crown", 26, 72), ("gf_sticker", 176, 128)], jbox: 186, junk: 12),
    CorrSeg(door: "door", gf: [("gf_nyc", 156, 86), ("gf_tag2", 14, 126), ("gf_tag3", 160, 132)], jbox: 30, junk: 186),
    CorrSeg(door: "gate", gf: [("gf_b2", 150, 80), ("gf_tag1", 10, 120), ("gf_sticker", 60, 104)], jbox: 54, junk: 178),
]

/// 웹 corrLamps() 원소
struct CorrLamp { let ax: Double, x: Double, y: Double, a: Double, wx: Double }

struct CorridorContext {
    let I: SceneInput
    let K: SceneContent
    let C: SceneInput.Corridor

    /// 웹 corrLamps(): 화면 근처 200 간격 전등 — 없는 자리는 (rand-.5)·.1 각도로 만든다(eff 에 기록)
    func lamps<R: SceneRandom>(_ eff: inout SceneEffects, _ rng: inout R) -> [CorrLamp] {
        var out: [CorrLamp] = []
        var wx = jsFloor((C.x - 80) / 200) * 200 + 60
        while wx < C.x + SB.W + 80 {
            let a: Double
            if let L = C.lamps.first(where: { $0.wx == wx }) ?? eff.corridorLamps.first(where: { $0.wx == wx }) { a = L.a }
            else { a = (rng.next() - 0.5) * 0.1; eff.corridorLamps.append(.init(wx: wx, a: a)) }
            let ax = wx - C.x
            out.append(CorrLamp(ax: ax, x: ax + sin(a) * CORR.LAMP_L, y: CORR.LAMP_TOP + cos(a) * CORR.LAMP_L, a: a, wx: wx))
            wx += 200
        }
        return out
    }
    /// 이미 만든 전등만 읽기(광원 · 후처리 — 그리기에서 다 만들었다)
    func lamps() -> [CorrLamp] { var e = SceneEffects(invF: 0, eye: EyeAdaptState()); var r = ConstantRandom(0.5); return lamps(&e, &r) }

    /// 웹 drawCorridor(time)
    func drawBack<R: SceneRandom>(_ P: inout Painter, _ eff: inout SceneEffects, _ rng: inout R) {
        let x0 = C.x
        P.depth = 0.85
        for k in -1..<4 { let x = Double(k) * 240 - jsMod(x0, 240); P.quad("cr_wall2", jsRound(x), 0); P.quad("cr_floor2", jsRound(x), SB.FLOOR - 6) }
        var wx = jsFloor((x0 - 240) / 240) * 240
        while wx < x0 + SB.W + 240 {
            let bx = jsRound(wx - x0), seg = CORR_SEG[Int(jsMod(jsMod(jsRound(wx / 240), 4) + 4, 4))]
            for (g, gx, gy) in seg.gf { P.quad(g, bx + gx, gy) }                  // 뉴욕식 그래피티
            P.quad("cr_jbox", bx + seg.jbox, 40); P.quad("cr_vent", bx + (seg.jbox > 120 ? 60 : 150), 50)
            let D = C.doors.first { $0.wxc == wx + 120 }, st = D?.st ?? "shut"
            let jit: Double = st == "bang" && jsMod(D!.t, 0.5) < 0.12 ? (rng.next() < 0.5 ? -1 : 1) : 0
            if seg.door == "gate" && st != "open" { P.quad("cr_gate", bx + 97 + jit, SB.FLOOR - 81) }
            else { P.quad(st == "open" ? "cr_door_o" : "cr_door", bx + 98 + jit, SB.FLOOR - 81) }
            P.quad("cr_junk", bx + seg.junk, SB.FLOOR - 24); P.quad("cr_drain", bx + 168, SB.FLOOR - 2)
            wx += 240
        }
        for k in -1..<4 { let x = jsRound(Double(k) * 240 - jsMod(x0, 240)); P.quad("cr_ceil", x, 0); P.quad("cr_fluo", x + 150, 42) }
        for k in -1..<5 { P.quad("cr_wpipe", jsRound(Double(k) * 160 - jsMod(x0, 160)), CORR.PIPE_Y - 5) }      // 문 위 벽에 고정한 배수관
        for k in -1..<4 {                                                          // 걸이 사이로 처진 전선 다발(두 변형 번갈아)
            let seg = jsFloor(x0 / 240) + Double(k)
            P.quad(toInt32(seg) & 1 != 0 ? "cr_cables2" : "cr_cables", jsRound(Double(k) * 240 - jsMod(x0, 240)), 30)
        }
        let n = Int((CORR.LAMP_L / 2).rounded(.up))
        for L in lamps(&eff, &rng) {                                              // 흔들리는 전선 · 전등
            for i in 1..<n {
                let u = Double(i) / Double(n)
                P.quad("cr_dot", jsRound(L.ax + (L.x - L.ax) * u), jsRound(CORR.LAMP_TOP + (L.y - CORR.LAMP_TOP) * u))
            }
            P.quad("cr_lamp", jsRound(L.x) - 7, jsRound(L.y) - 1)
        }
        let ex = CORR.LEN + 440 - x0
        if ex < SB.W + 60 { P.quad(C.out ? "cr_exit_o" : "cr_exit", jsRound(ex) - 24, SB.FLOOR - 98) }
        P.depth = 0
    }

    /// 웹 corridorLights()
    func lights() -> [SceneLight] {
        var L: [SceneLight] = []
        for lp in lamps() {                                                       // 맨전구(가끔 깜빡) — 흔들리는 자리에서
            let fl = sin(I.gsTime * 13 + lp.wx) > 0.97 ? 0.4 : 1
            L.append(SceneLight(x: lp.x, y: lp.y + 8, z: 20, r: 240, c: [1, 0.88, 0.65], i: 2.1 * fl, spot: [sin(lp.a), cos(lp.a)], cone: 0.78))
            L.append(SceneLight(x: lp.x, y: lp.y + 4, z: 6, r: 26, c: [1, 0.8, 0.5], i: 0.8 * fl))
        }
        let ex = CORR.LEN + 440 - C.x
        if ex < SB.W + 80 { L.append(SceneLight(x: ex, y: SB.FLOOR - 90, z: 20, r: 90, c: [0.4, 1, 0.6], i: 1.2)) }
        if C.out { L.append(SceneLight(x: ex, y: SB.FLOOR - 40, z: 30, r: 260, c: [0.85, 1, 0.88], i: min(3.2, C.outT * 3))) }   // 열린 철문 너머의 빛
        var wx = jsFloor((C.x - 240) / 240) * 240
        while wx < C.x + SB.W + 240 { L.append(SceneLight(x: wx + 167 - C.x, y: 52, z: 34, r: 300, c: [0.86, 0.96, 1], i: 2.2)); wx += 240 }   // 천장 형광등
        L.append(SceneLight(x: SB.W / 2, y: 140, z: 80, r: 460, c: [0.6, 0.85, 0.82], i: 0.6))
        return L
    }

    /// 웹 subwayFX() 복도 갈래: 저채도 녹색 · 짙은 비네트 · 전등 갓 아래 빛 삼각형(GS.invF 를 깎는다)
    func fx(_ eff: inout SceneEffects) -> PostFX {
        let inv: Double = eff.invF > 0 ? 1 : 0
        if eff.invF > 0 { eff.invF -= 1 }
        let vols = lamps().prefix(6).map {
            VolumeLight(x: $0.x, y: $0.y + 8, dx: sin($0.a), dy: cos($0.a), c: [1, 0.92, 0.78], i: 0.24, cone: 0.86, len: 150, halo: 6)
        }
        return PostFX(expo: 1.3, winR: 0, winY: [0, 0], press: 0, bloom: 0.75, reflY: SB.FLOOR - 4, rain: 0, vig: 0.55, fog: 0.1,
                      fogC: [0.06, 0.12, 0.13], inv: inv, grade: [0.8, 1.0, 1.06], sat: 0.72, vols: Array(vols))
    }
}
