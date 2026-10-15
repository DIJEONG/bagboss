import Foundation
import BBContent
import BBAnim
import BBSim

// brawl 장면 구성 — 웹 render() 의 scene==='brawl' 갈래(보너스 차 부수기 · 프롤로그 뒤 비 오는 거리 GS.cine) 1:1 이식:
//   배경 nb0..3(charOX 시차) → [그림자] → drawCineProps · drawBonusCar(3D 차 → pushModel · 연기 입자 drawPfx · 떨어진 부품) · 바닥 물건
//   → [인물] → 맨 앞 주차된 차 n_car(시차 1.18) / 광원 noirLights(6) + 주인공 · 무리 보조광 + 소품 동적 광원 / 후처리 noirFX + 날씨
// 웹 원본: 18-render-loop.js(render brawl 줄 · noirLights · noirFX · NOIR_KIND) · 06-art-arenas.js(NOIR_LIGHTS) · 39-prologue.js(CINE · drawCineProps) ·
//          40-bonus.js(carBones · drawBonusCar) · 43-fx-smoke.js(drawPfx) · 12-webgl.js(boneT · pushModel).
// 숨은 변경: carBones 가 C.dentN 을 쓴다(그리기 모델은 그 전 값) → SceneEffects.dentN. 흔들림 · 불길 세기는 주입 난수.

/// 웹 NVW · NVH · NFLOOR(06-art-arenas — 느와르 거리 480×270 · 건물 밑선)
enum NV { static let W = 480.0, H = 270.0, FLOOR = 196.0, BW = 1920.0 }
/// 웹 CINE(39-prologue) — 비 오는 거리 연출 자리
enum CINE { static let start = 160.0, trash = 560.0, ent = 1000.0, y = NV.FLOOR + 26, spd = 150.0 }

/// 웹 NOIR_LIGHTS(genNoir 가 채우는 거리 광원 — 세계 좌표) · NOIR_KIND
struct NoirLamp { let x: Double, y: Double, kind: String }
let NOIR_LIGHTS: [NoirLamp] = [200.0, 560, 940, 1300, 1680].map { NoirLamp(x: $0 - 11, y: 58, kind: "lamp") } + [
    NoirLamp(x: 165, y: 120, kind: "tube"), NoirLamp(x: 230, y: 170, kind: "neonO"), NoirLamp(x: 850, y: 125, kind: "neonT"), NoirLamp(x: 775, y: 170, kind: "shop"),
    NoirLamp(x: 1345, y: 80, kind: "neonR"), NoirLamp(x: 1200, y: 170, kind: "shop"), NoirLamp(x: 1478, y: 128, kind: "neonP"), NoirLamp(x: 1790, y: 116, kind: "bulb"),
    NoirLamp(x: 1790, y: 172, kind: "shop"), NoirLamp(x: 45, y: 150, kind: "door"),
]
struct NoirKind { let c: [Double], i: Double, r: Double, z: Double }
let NOIR_KIND: [String: NoirKind] = [
    "lamp": .init(c: [1, 0.8, 0.52], i: 1.5, r: 210, z: 30), "tube": .init(c: [0.88, 0.94, 1], i: 1.15, r: 180, z: 22),
    "neonO": .init(c: [1, 0.42, 0.14], i: 1.2, r: 100, z: 8), "neonT": .init(c: [0.2, 0.9, 0.95], i: 1.15, r: 140, z: 12),
    "neonR": .init(c: [1, 0.18, 0.2], i: 1.15, r: 120, z: 10), "neonP": .init(c: [1, 0.28, 0.62], i: 1.2, r: 120, z: 10),
    "shop": .init(c: [1, 0.84, 0.58], i: 0.95, r: 95, z: 10), "bulb": .init(c: [1, 0.84, 0.5], i: 1.0, r: 150, z: 14),
    "door": .init(c: [0.92, 0.95, 1], i: 0.8, r: 60, z: 8),
]
/// 웹 render() 의 brawl 날씨 표(GS.stage) — 보너스 {.3, .14} · 거리 연출 {.9, .22}
let BRAWL_WEATHER: [(rain: Double, fog: Double)] = [(0.55, 0.18), (0.15, 0.42), (0.95, 0.22)]

struct NoirContext {
    let I: SceneInput
    let K: SceneContent
    let B: SceneInput.Brawl
    /// 웹 charOX = -Math.round(GS.cam)
    var charOX: Double { -jsRound(B.cam) }

    /// 한 장면 전부(웹 render() brawl 갈래의 그리기 · 광원 · 후처리 순서 그대로 — 난수도 그 순서)
    func compose<R: SceneRandom>(_ eff: inout SceneEffects, _ rng: inout R) -> SceneFrame {
        let back = background()
        var mid = Painter(K.sprites), mesh: [Float] = [], dyn: [SceneLight] = []
        drawMid(&mid, &mesh, &dyn, &eff, &rng)
        let top = drawTop()
        let raw = noirLights()
        let lit = lighting(raw, dyn: dyn)
        var f = SceneFrame(background: back, sceneLights: raw, lighting: lit, post: fx(), effects: eff, unported: nil)
        f.mid = mid.out; f.mesh = mesh; f.top = top; f.charOX = charOX; f.windowLight = 1
        return f
    }

    /// 배경: 느와르 거리 4장(화면에 걸친 것만) — drawOX = charOX
    func background() -> [SpriteDraw] {
        var P = Painter(K.sprites)
        let ox = charOX
        P.ox = ox
        for k in 0..<4 { let x = Double(k) * NV.W; if x + ox < SB.W && x + NV.W + ox > 0 { P.quad("nb\(k)", x, 0) } }
        return P.out
    }

    /// 그림자 뒤 층: drawCineProps(dyn) · drawBonusCar(dyn) · 바닥 물건(+장비 빛). drawOX = charOX, drawDepth = 0
    func drawMid<R: SceneRandom>(_ P: inout Painter, _ mesh: inout [Float], _ dyn: inout [SceneLight], _ eff: inout SceneEffects, _ rng: inout R) {
        let ox = charOX
        P.ox = ox; P.depth = 0
        if let C = B.cine { drawCineProps(C, &P, &dyn) }
        if let BN = B.bonus, let C = BN.car { drawBonusCar(BN, C, &P, &mesh, &dyn, &eff, &rng) }
        P.ox = ox
        for it in I.items {
            let y = NV.FLOOR + it.z - 2 - jsRound(abs(sin(it.t * 4)) * 2)
            if it.kind != "gear" { P.placeAt("it_" + it.kind, jsRound(it.x), y, false, 0) }
            else { let ic = it.id.flatMap { K.itemIcons[$0] } ?? ""; P.placeAt(K.sprites[ic] != nil ? ic : "it_gem", jsRound(it.x), y - 4, false, 0) }
            if it.kind == "gear" { dyn.append(SceneLight(x: it.x + ox + 0.5, y: y - 6, z: 8, r: 30, c: [1, 0.85, 0.5], i: 0.8)) }
        }
    }

    /// 웹 drawCineProps — 쓰레기통 · 장도리(꽂힘 / 포물선) · 초록 구형 등 둘 · 지하철 입구(+ 빛)
    func drawCineProps(_ C: SceneInput.Brawl.Cine, _ P: inout Painter, _ dyn: inout [SceneLight]) {
        let ox = -jsRound(B.cam)
        P.depth = 0.02
        P.quad("cn_trash", CINE.trash - 10, CINE.y - 26)
        if C.hammerIn { P.quad("cn_hammer", CINE.trash - 4, CINE.y - 36) }
        else if let T = C.toss {
            let u = min(1, T.t / 0.42), x = T.x0 + (CINE.trash - T.x0) * u, y = T.y0 + (CINE.y - 30 - T.y0) * u - 40 * u * (1 - u) * 4
            P.quad("cn_hammer", jsRound(x) - 5, jsRound(y) - 7)
        }
        for gx in [CINE.ent - 52, CINE.ent + 82] {
            P.quad("cn_globe", gx - 10, CINE.y - 84)
            dyn.append(SceneLight(x: gx + ox, y: CINE.y - 76, z: 22, r: 130, c: [0.45, 1, 0.55], i: 2.2))
        }
        P.quad("cn_subway", CINE.ent - 42, CINE.y - 72)
        dyn.append(SceneLight(x: CINE.ent + 20 + ox, y: CINE.y, z: 4, r: 80, c: [1, 0.85, 0.55], i: 1.4))
        P.depth = 0
    }

    /// 웹 drawBonusCar — 3D 차(찌그러짐은 지난 dentN 만큼) · 연기 입자 · 떨어진 부품 · 비상등 · 불길 빛 · 전조등 · 후미등
    func drawBonusCar<R: SceneRandom>(_ BN: SceneInput.Brawl.Bonus, _ C: SceneInput.Brawl.Bonus.Car, _ P: inout Painter, _ mesh: inout [Float],
                                      _ dyn: inout [SceneLight], _ eff: inout SceneEffects, _ rng: inout R) {
        let ox = C.x - jsRound(B.cam)
        let bones = CarMesh.bones(C, &rng)                                         // 웹 carBones(C) — 흔들림 난수 · dentN 새 값
        eff.dentN = BonusCarRig.dentN(C.dmgF)
        var model = K.carModel; model["dents"] = Array((K.carModel["dents"] ?? []).prefix(max(0, C.dentN)))
        CarMesh.push(model, bones, ox: ox, footY: C.y, flash: C.flash > 0, into: &mesh)
        drawPfx(BN.pfx, &P)
        for d in C.debris {
            guard let pcs = K.carModel[d.key] else { continue }
            CarMesh.push([d.key: pcs], [(d.key, CarMesh.Bone(x: d.x - C.x, y: d.y - C.y, z: d.z, th: d.th, sy: nil))], ox: ox, footY: C.y, flash: false, into: &mesh)
        }
        if BN.alarm && !BN.alarmOff && truthy(jsMod(jsFloor(B.perfNow / 260), 2)) {   // 비상등
            for (hx, hy) in [(57.0, -10.0), (-57, -12)] { dyn.append(SceneLight(x: ox + hx, y: C.y + hy, z: 8, r: 46, c: [1, 0.62, 0.12], i: 1.5)) }
        }
        if BN.fire { dyn.append(SceneLight(x: ox + 30, y: C.y - 24, z: 12, r: 110, c: [1, 0.55, 0.2], i: 1.6 + rng.next() * 0.6)) }   // 불길의 일렁이는 빛
        if C.stage < 3 { dyn.append(SceneLight(x: ox + 57, y: C.y - 13, z: 6, r: 80, c: [1, 0.95, 0.8], i: 1.2, spot: [1, 0], cone: 0.7)) }
        dyn.append(SceneLight(x: ox - 57, y: C.y - 13, z: 6, r: 28, c: [1, 0.2, 0.15], i: 0.7))
    }

    /// 웹 drawPfx(43-fx-smoke) — 도트 연기 · 김(사라질 땐 디더) · 불꽃 4칸
    func drawPfx(_ pfx: [SceneInput.Brawl.Bonus.Puff], _ P: inout Painter) {
        if pfx.isEmpty { return }                                               // 웹: BN.pfx 가 없으면 drawDepth 를 건드리지 않는다
        P.depth = 0.01
        for p in pfx {
            let u = p.t / p.life
            if p.k == "fire" {
                let f = jsMod(jsFloor(p.t * 12 + p.x), 4)
                if u < 0.85 { P.quad("pf_fire" + jsStr(f), jsRound(p.x - 4), jsRound(p.y - 13)) }
                continue
            }
            let k = min(3, Int(jsFloor(u * 4.2))), base = p.k == "stm" ? "pf_stm" : "pf_smk", r = [3.0, 6, 9, 12][max(0, k)]
            P.quad(base + (u > 0.7 ? "D" : "") + String(k), jsRound(p.x - r - 1), jsRound(p.y - r - 1))
        }
        P.depth = 0
    }

    /// 맨 앞: 주차된 차 세 대(시차 1.18 · 가운데 것만 뒤집힘)
    func drawTop() -> [SpriteDraw] {
        var P = Painter(K.sprites)
        P.ox = jsRound(charOX * 1.18)
        for x in [380.0, 1150, 1720] { P.placeAt("n_car", x, NV.H + 2, x == 1150, 0) }
        return P.out
    }

    /// 웹 noirLights(ox, time) — 하늘 방향광 + 화면 가운데에 가까운 거리 광원 7개(네온은 깜빡임)
    func noirLights() -> [SceneLight] {
        let ox = charOX, time = I.time
        var L = [SceneLight(dirl: [-0.3, 0.6, 0.7], c: [0.42, 0.52, 0.78], i: 0.1)]
        let cx = SB.W / 2 - ox
        for l in stableSorted(NOIR_LIGHTS, by: { abs($0.x - cx) }).prefix(7) {
            let k = NOIR_KIND[l.kind]!
            let fl = l.kind.hasPrefix("neon") ? 0.9 + 0.1 * jsHash(jsFloor(time * 14) + l.x) : 1
            if l.kind == "lamp" { L.append(SceneLight(x: l.x + ox, y: l.y, z: k.z, r: k.r, c: k.c, i: k.i * 0.9, spot: [0, 1], cone: 0.74)) }
            else { L.append(SceneLight(x: l.x + ox, y: l.y, z: k.z, r: k.r, c: k.c, i: k.i * fl)) }
        }
        return L
    }

    /// 웹 render(): noirLights 6개 + 주인공 보조광 + 무리 보조광 + 장면 동적 광원 · uAmb .45 · uEmitK 1
    func lighting(_ raw: [SceneLight], dyn: [SceneLight]) -> SceneLighting {
        var L = Array(raw.prefix(6))
        let ox = charOX
        if let H = I.hero, !H.hidden { L.append(SceneLight(x: H.x + ox + (H.flip ? -8 : 8), y: H.y - 46, z: 26, r: 72, c: [0.78, 0.84, 1], i: 0.45)) }
        if !B.crowd.isEmpty {                                                   // 적 무리 전체를 덮는 넓은 보조광
            let n = Double(B.crowd.count)
            let mx = B.crowd.reduce(0) { $0 + $1.x } / n, my = B.crowd.reduce(0) { $0 + $1.y } / n
            L.append(SceneLight(x: mx + ox, y: my - 50, z: 34, r: 150, c: [0.7, 0.78, 1], i: 0.4))
        }
        return SceneLighting(lights: L + dyn, ambient: 0.45, emitK: 1)
    }

    /// 웹 {...noirFX(charOX, wx.rain), fog: wx.fog} — 날씨: 거리 연출 · 보너스 · GS.stage 표
    func fx() -> PostFX {
        let ox = charOX
        let w: (rain: Double, fog: Double) = B.cine != nil ? (0.9, 0.22) : B.bonus != nil ? (0.3, 0.14)
            : BRAWL_WEATHER[min(BRAWL_WEATHER.count - 1, max(0, Int(B.stage ?? 0)))]
        let lamps = NOIR_LIGHTS.filter { $0.kind == "lamp" }.map {
            VolumeLight(x: $0.x + ox, y: $0.y + 2, dx: 0, dy: 1, c: [1, 0.78, 0.48], i: 1, cone: 0.86, len: 150, halo: 10)
        }
        let neon = NOIR_LIGHTS.filter { $0.kind.hasPrefix("neon") || $0.kind == "tube" }.map {
            VolumeLight(x: $0.x + ox, y: $0.y, dx: 0, dy: 1, c: NOIR_KIND[$0.kind]!.c, i: 0.45, cone: 2, len: 1, halo: 20)
        }
        let vols = Array((lamps + neon).filter { $0.x > -80 && $0.x < SB.W + 80 }.prefix(6))
        return PostFX(expo: nil, winR: nil, winY: nil, press: nil, bloom: 0.95, reflY: NV.FLOOR, rain: w.rain, vig: 0.55, fog: w.fog,
                      fogC: [0.05, 0.06, 0.09], inv: 0, grade: nil, sat: nil, vols: vols)
    }
}

// MARK: - 3D 차(웹 carBones · boneT · pushModel)

/// 보너스 차 3D 정점(웹 drawBonusCar → pushModel 의 v3). 정점당 10 float(BBAnim MeshWriter 와 같은 배치)
public enum CarMesh {
    struct Bone { var x: Double, y: Double, z: Double, th: Double, sy: Double? }
    /// 웹 carBones 의 put 순서(객체 키 순서 = 정점 순서)
    static let order = ["farW", "body", "detail", "cabin", "interior", "pillar", "glassS", "glassX", "glassF", "glassB", "wiper", "hood", "trunk",
                        "bumperF", "bumperR", "doorF", "doorR", "mirror", "wheelF", "hubF", "wheelF2", "wheelR", "wheelR2", "lightF", "lightR", "dents"]

    /// 웹 carBones(C): 흔들림 sh = (rand-.5)·2.4·shake(shake > 0 일 때만 난수 하나) — 뼈 자리는 BBSim BonusCarRig.bones 를 그대로 쓴다
    static func bones<R: SceneRandom>(_ C: SceneInput.Brawl.Bonus.Car, _ rng: inout R) -> [(String, Bone)] {
        let sh = C.shake > 0 ? (rng.next() - 0.5) * 2.4 * C.shake : 0
        let B = BonusCarRig.bones(stage: C.stage, dmgF: C.dmgF, gone: Set(C.gone), tilt: C.tilt, sh: sh)
        return order.compactMap { k in B[k].map { (k, Bone(x: $0.x, y: $0.y, z: $0.z, th: $0.th, sy: $0.sy)) } }
    }

    // 웹 12-webgl YAW · PIT(3/4 시점 + 살짝 내려다봄)
    static let CY = cos(30 * Double.pi / 180), SY = sin(30 * Double.pi / 180), CP = cos(14 * Double.pi / 180), SP = sin(14 * Double.pi / 180)

    /// 웹 boneT(bone)(p) — 차 뼈는 비틀기 · 벌리기 · 몸 회전이 없다
    @inline(__always) static func T(_ b: Bone, _ p: SIMD3<Double>) -> SIMD3<Double> {
        let cs = cos(b.th), sn = sin(b.th), cyw = cos(0.0), syw = sin(0.0), sy = (b.sy.map { truthy($0) ? $0 : 1 } ?? 1)
        let px = p.x * cyw - p.z * syw, pz = p.x * syw + p.z * cyw, py = p.y * sy
        let x = px * cs - py * sn + b.x, z = pz + b.z, y = px * sn + py * cs + b.y
        let xr = x * CY - z * SY, zr = x * SY + z * CY
        return SIMD3(xr, y * CP + zr * SP, -y * SP + zr * CP)
    }

    /// 웹 pushModel(act{flip:false, y:footY}, B, ox, footY, m=>m, flash) — 앞면만 삼각형 두 개씩
    static func push(_ model: Model3, _ B: [(String, Bone)], ox: Double, footY: Double, flash: Bool, into v: inout [Float]) {
        for (key, bone) in B {
            guard let pieces = model[key] else { continue }
            for pc in pieces {
                let cc = T(bone, pc.c)
                let mat = flash ? 13 : pc.mat, tone = flash ? 1 : pc.tone, emit: Double = flash ? 1 : 0
                for qd in pc.q {
                    let P = qd.map { T(bone, $0) }
                    let ux = P[1].x - P[0].x, uy = P[1].y - P[0].y, uz = P[1].z - P[0].z
                    let vx = P[2].x - P[0].x, vy = P[2].y - P[0].y, vz = P[2].z - P[0].z
                    var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx
                    let L0 = jsHypot3(nx, ny, nz), L = L0 == 0 ? 1 : L0
                    nx /= L; ny /= L; nz /= L
                    let mx = (P[0].x + P[2].x) / 2 - cc.x, my = (P[0].y + P[2].y) / 2 - cc.y, mz = (P[0].z + P[2].z) / 2 - cc.z
                    if nx * mx + ny * my + nz * mz < 0 { nx = -nx; ny = -ny; nz = -nz }   // 바깥쪽을 보게
                    if nz <= 0.02 { continue }                                          // 뒷면은 버린다
                    for tri in [[0, 1, 2], [0, 2, 3]] {
                        for k in tri {
                            let p = P[k]
                            v.append(contentsOf: [Float(ox + p.x), Float(footY + p.y), Float(0.9 - footY / 300 - p.z / 600), Float(nx), Float(-ny),
                                                  Float(tone), Float(mat), Float(pc.part), Float(0.5 + p.z / 60), Float(emit)])
                        }
                    }
                }
            }
        }
    }
}
