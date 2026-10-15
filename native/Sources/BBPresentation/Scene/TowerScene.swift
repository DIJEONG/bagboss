import Foundation
import BBContent

// 엘리베이터 타워 장면 구성 — 웹 09-art-tower.js(twLamps · twSill · drawTowerBack · towerLights · towerFX) 1:1 이식.
// 웹 towerFX 는 GS.invF 를 깎는다(숨은 변경) → SceneEffects.invF 로 돌려준다. 흔들림 · 버튼 · 불꽃 일렁임 난수는 주입받는다.

struct TowerLamp { let x: Double, y: Double, a: Double, hang: Bool, on: Bool, bx: Double }

struct TowerContext {
    let I: SceneInput
    let K: SceneContent
    let T: SceneInput.Tower
    var dy: Double { I.train.dy }                                         // TR.dy||0 (입력에서 이미 0 처리)

    func floorDef(_ n: Int) -> TowerFloor? { n >= 0 && n < K.towerFloors.count ? K.towerFloors[n] : nil }

    /// 웹 twLamps — 칸 천장 전등 둘(떨어져 매달리면 흔들린다)
    func lamps() -> [TowerLamp] {
        TW_LAMPX.enumerated().map { i, x in
            let S = T.lamps[i], len = S.hang ? 24.0 : 4
            let blink = S.flick > 0 && truthy(jsMod(jsFloor(I.gsTime * 30), 2))
            return TowerLamp(x: x + sin(S.a) * len, y: TWR.CEIL + dy + cos(S.a) * len + (S.hang ? 6 : 4), a: S.a, hang: S.hang,
                             on: !T.dark && !blink, bx: x)
        }
    }
    /// 웹 twSill — n층 문턱의 화면 y
    func sill(_ n: Int) -> Double { jsRound(222 + (T.pos - Double(n - 1) * TWR.FH)) }
    var lampFoes: [SceneInput.Foe] { I.foes.filter { $0.lamp && !$0.down && !$0.jug } }

    /// 웹 drawTowerBack — 승강로 → 층 문들(멈춘 층은 문 뒤 풍경) → 케이블 → 칸 → 계기 · 전등 → 철창 문 → 바닥 물건
    func drawBack<R: SceneRandom>(_ P: inout Painter, _ rng: inout R) {
        let time = I.time
        P.depth = 0.95
        do { let off = jsMod(jsMod(T.pos, 150) + 150, 150); var y = off - 150; while y < SB.H { P.quad("tw_shaft", 0, jsRound(y)); y += 150 } }
        let f0 = Int(jsFloor(T.pos / TWR.FH)) + 1, stopped = T.phase != "move"
        for n in max(1, f0 - 1)...(f0 + 2) {
            let sill = sill(n)
            if sill < -30 || sill > SB.H + 110 { continue }
            let here = stopped && n == T.floor, F = floorDef(n), o = here ? T.door : 0, dx = jsRound(o * 68)
            if here, let F, o > 0 {
                let jx = T.shk > 0 ? jsRound((rng.next() - 0.5) * 4 * T.shk / 0.5) : 0
                let jy = T.shk > 0 ? jsRound((rng.next() - 0.5) * 3 * T.shk / 0.5) : 0
                P.depth = 0.93; P.quad("fs_" + F.fs + (T.wreck.contains(n) ? "_b" : ""), TWR.G0 + jx, sill - 96 + jy)
                if F.fs == "park" && T.alarm > 0 && jsMod(jsFloor(time * 4), 2) == 0 {
                    P.depth = 0.928; P.quad("fr_hazard", TWR.G0 + 64, sill - 96 + 51); P.quad("fr_hazard", TWR.G0 + 108, sill - 96 + 51)
                }
                P.depth = 0.925
                for f in T.fly {
                    let u = min(1, f.t / f.dur), x = f.x0 + (f.x1 - f.x0) * u, y = f.y0 + (f.y1 - f.y0) * u - sin(u * Double.pi) * 14
                    let si = u < 0.34 ? 0 : u < 0.67 ? 1 : 2, r = toInt32(f.r0 + jsFloor(u * 6)) & 3
                    P.placeAt("fr_body\(si)@\(r)", jsRound(x), jsRound(y), false, 0)
                }
            }
            P.depth = 0.92; P.quad("tw_ld", TWR.G0 - dx, sill - 96); P.quad("tw_ld", TWR.G0 + 68 + dx, sill - 96, 1)
            let fn = "tw_fn@\(min(50, n))"
            if o < 0.4 && K.sprites[fn] != nil { P.quad(fn, TWR.G0 - dx + 8, sill - 90) }
            if o < 0.05 { P.quad("tw_leak", TWR.G0, sill - 1) }
            P.depth = 0.91; P.quad("tw_land", TWR.G0 - 10, sill - 106)
        }
        P.depth = 0.88; P.quad("tw_cable", 228, dy)
        P.depth = 0.3; P.quad("tw_cab", TWR.CX, TWR.CY + dy)
        P.depth = 0.29
        let zf = T.pos / TWR.FH, fpos = max(0, min(9, zf - 10 * jsFloor(min(zf, TW_TOP - 1) / 10)))   // 구간마다 1~10
        let ang = -80 + fpos * 160 / 9 + T.sagV * 1.2
        P.placeAt("tw_needle@\(djIdx(TW_NEEDLE, ang))", 240, 116 + dy, false, 0)
        P.quad("tw_plate@" + jsStr(max(4, min(9, truthy(T.limit) ? T.limit : TW_LIMIT))), 94, 130 + dy)
        if T.over && jsMod(jsFloor(time * 4), 2) == 0 { P.quad("tw_over", 142, 133 + dy) }
        func lit(_ n0: Double) {
            if n0 < 1 { return }
            let n = jsMod(n0 - 1, 10) + 1, r = 4 - jsFloor((n - 1) / 2), c = jsMod(n - 1, 2)
            P.quad("tw_btnL", TWR.PX - 8 + 4 + c * 7, 145 + r * 7 + dy)
        }
        lit(min(10, Double(T.floor) + (T.phase == "move" ? 1 : 0)))
        if T.panelT > 0 { for _ in 0..<3 { lit(1 + jsFloor(rng.next() * 10)) } }
        if !T.kit { P.quad("tw_kitB", 356, 134 + dy) }
        for x in T.dent { P.quad("tw_dent", x - 9, 96 + dy) }
        for L in lamps() {
            if L.hang {
                P.placeAt("tw_hole", L.bx, 96 + dy, false, 0)
                P.placeAt((L.on ? "tw_lampH@" : "tw_lampHo@") + String(djIdx(TW_LAMP_A, L.a * 180 / Double.pi)), L.bx, 100 + dy, false, 0)
            } else { P.placeAt(L.on ? "tw_lamp" : "tw_lampOff", L.bx, TWR.CEIL + dy, false, 0) }
        }
        P.depth = 0.28; P.quad("tw_gate@" + jsStr(max(0, min(6, jsRound(T.door * 6)))), TWR.G0, TWR.GT - 2 + dy)
        P.depth = 0.25; for p in I.props where p.k == "puddle" { P.quad(p.ice ? "tw_ice" : "sb_puddle", jsRound(p.x), SB.FLOOR - 2 + dy) }
        P.depth = 0.22
        for f in T.fires { P.placeAt("tw_fire@" + jsStr(jsMod(jsFloor(time * 10) + Double(toInt32(f.x) >> 3), 3)), f.x, SB.FLOOR + 3 + dy, false, 0) }   // 플랑베 불꽃
        for it in I.items {
            let nm = "it_" + it.kind
            let y = SB.FLOOR + jsRound(truthy(it.z) ? it.z : 0) - 2 - jsRound(abs(sin(it.t * 4)) * 2) + dy
            if it.kind != "gear" && K.sprites[nm] != nil { P.placeAt(nm, jsRound(it.x), y, false, 0) }
            else if it.kind == "gear" {
                let ic = it.id.flatMap { K.itemIcons[$0] }
                P.placeAt(ic.flatMap { K.sprites[$0] != nil ? $0 : nil } ?? "it_gem", jsRound(it.x), y - 4, false, 0)
            }
        }
        for s in I.shots {                                                    // 타워에선 던지는 게 접시
            if s.friendly { P.quad("sb_box", jsRound(s.x) - 5, jsRound(s.y) - 4 + dy); continue }
            P.placeAt("tw_dish@\(toInt32(jsFloor(s.t * 14)) & 3)", jsRound(s.x), jsRound(s.y) + dy, false, 0)
        }
        P.ox = 0; P.depth = 0
    }

    /// 웹 towerLights(7개 한도는 render 가 자른다)
    func lights<R: SceneRandom>(_ rng: inout R) -> [SceneLight] {
        var L: [SceneLight] = []
        let time = I.time, F = floorDef(T.floor)
        for a in I.foes where a.lamp && !a.down && !a.jug && L.count < 2 {   // 적 손전등
            let f: Double = a.flip ? -1 : 1
            L.append(SceneLight(x: a.x + f * 12, y: a.y - 40, z: 16, r: 230, c: [1, 0.95, 0.82], i: T.dark ? 1.7 : 0.85, spot: [f, 0.16], cone: 0.9))
        }
        if T.dark {
            let pu = 0.7 + 0.3 * sin(time * 5)
            L.append(SceneLight(x: 96, y: 114 + dy, z: 20, r: 210, c: [1, 0.1, 0.06], i: 1.55 * pu, em: true))
            L.append(SceneLight(x: 384, y: 114 + dy, z: 20, r: 170, c: [1, 0.1, 0.06], i: 1.05 * pu, em: true))
        } else { for lp in lamps() where lp.on { L.append(SceneLight(x: lp.x, y: lp.y + 6, z: 18, r: 132, c: [1, 0.88, 0.7], i: 1.7)) } }
        if T.alarm > 0 && T.phase != "move" && T.door > 0.3 && jsMod(jsFloor(time * 4), 2) == 0 {   // 차 경보 비상등
            L.append(SceneLight(x: TWR.G0 + 90, y: 160 + dy, z: -20, r: 170, c: [1, 0.62, 0.12], i: 1.4, em: true))
        }
        for f in T.fires.prefix(2) { L.append(SceneLight(x: f.x, y: 206 + dy, z: 14, r: 120, c: [1, 0.52, 0.18], i: 1.3 + rng.next() * 0.45, em: true)) }
        if T.phase != "move" && T.door > 0.02 {                               // 문으로 드는 층 불빛
            var col = F?.col ?? [1, 1, 1], k = 1.0
            if F?.strobe == true { let bt = I.gsTime * 2.1, bb = jsFloor(bt); col = STROBE_COLS[Int(jsMod(bb, 4))]; k = 1.3 * (1 - (bt - bb) * 0.6) }
            if F?.flame == true { k *= 0.82 + 0.36 * rng.next() }
            L.append(SceneLight(x: 240, y: 172 + dy, z: -30, r: 220, c: col, i: 1.6 * T.door * k * (1 + T.fl * 2.4)))
            L.append(SceneLight(x: 240, y: 210 + dy, z: 22, r: 130, c: col, i: 0.55 * T.door * k))
        } else {                                                              // 지나가는 층 문틈 빛
            let f0 = Int(jsFloor(T.pos / TWR.FH)) + 1
            for n in f0...(f0 + 1) {
                let s = sill(n); if s < 90 || s > 250 { continue }
                L.append(SceneLight(x: 240, y: s - 2, z: -22, r: 150, c: floorDef(n)?.col ?? [1, 1, 1], i: 1.25 * max(0, 1 - abs(s - 176) / 90)))
            }
        }
        if T.over && jsMod(jsFloor(time * 4), 2) == 0 { L.append(SceneLight(x: 146, y: 136 + dy, z: 8, r: 46, c: [1, 0.15, 0.1], i: 1.5, em: true)) }
        L.append(SceneLight(x: 240, y: 232, z: 12, r: 200, c: [0.95, 0.8, 0.62], i: T.dark ? 0.04 : 0.14))   // 바닥에서 되튀는 빛
        L.append(SceneLight(x: 240, y: 150, z: 80, r: 300, c: [0.58, 0.64, 0.8], i: T.dark ? 0.03 : 0.08))
        return L
    }

    /// 웹 towerFX — invF 를 깎던 것은 eff 로
    func fx(_ eff: inout SceneEffects) -> PostFX {
        let F = floorDef(T.floor)
        let inv: Double = eff.invF > 0 ? 1 : 0
        if eff.invF > 0 { eff.invF -= 1 }
        var vols: [VolumeLight] = []
        if !T.dark { for lp in lamps() where lp.on { vols.append(VolumeLight(x: lp.x, y: lp.y + 8, dx: sin(lp.a), dy: cos(lp.a), c: [1, 0.9, 0.72], i: 0.15, cone: 0.74, len: 104, halo: 8)) } }
        if T.phase != "move" && T.door > 0.05 { vols.append(VolumeLight(x: 240, y: 152 + dy, dx: 0, dy: 1, c: F?.col ?? [1, 1, 1], i: 0.13 * T.door, cone: 0.5, len: 72, halo: 0)) }
        for a in lampFoes {
            let f: Double = a.flip ? -1 : 1
            vols.append(VolumeLight(x: a.x + f * 12, y: a.y - 40, dx: f, dy: 0.16, c: [1, 0.95, 0.82], i: T.dark ? 0.22 : 0.09, cone: 0.9, len: 150, halo: 4))
        }
        let g = (T.phase != "move" && T.door > 0.3 && F?.col != nil) ? F!.col : [1, 0.96, 0.9]
        return PostFX(expo: T.dark ? 0.6 : 1.02, winR: 0, winY: [0, 0], press: 0, bloom: T.dark ? 1.4 : 1.0, reflY: SB.FLOOR - 1, rain: 0,
                      vig: T.dark ? 0.75 : 0.5, fog: 0.05, fogC: [0.08, 0.08, 0.1], inv: inv,
                      grade: [0.95 + 0.07 * g[0], 0.95 + 0.06 * g[1], 0.95 + 0.06 * g[2]], sat: 1.03, vols: vols)
    }
}
