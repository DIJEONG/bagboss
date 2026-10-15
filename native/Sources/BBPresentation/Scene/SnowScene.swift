import Foundation
import BBContent
import BBSim

// 눈 승강장 장면 구성(docs/10) — 무대 픽셀 배경(SnowArt) + 광원 · 후처리. 웹에 없는 장면이라 웹 대조 대상이 아니다(깃발 켜짐에서만 온다).
//  · 시간: 막차 무렵(23:30) — 짙은 남색 하늘, 지평선은 도시 불빛이 눈구름에 비친 청록 빛무리. 달은 없다(눈구름)
//  · 빛: 가로등 셋(나트륨 · 위에서 아래로 스폿 + 바닥 빛 웅덩이 — 원뿔 안 내리는 눈이 데워진다) · 가판대 창 · 하늘 방향광(차가운 채움)
//    점광원은 층 깊이(d 0.42)까지만 비춘다 → 길 건너 건물 · 먼 도시엔 닿지 않는다(대기 원근)
//  · 후처리: 블룸(등 · 창) · 위가 짙은 푸른 안개 · 비네트 · 살짝 차가운 색 보정

struct SnowContext {
    let I: SceneInput
    let K: SceneContent
    let camX: Double
    /// 무도장 깊이 · 조명 세기(docs/10 §10 — 0 = 지금 그대로. 눈 승강장 판(달리기)은 늘 0)
    var depthK = 0.0

    func compose() -> SceneFrame {
        var mid = Painter(K.sprites)
        drawMid(&mid)
        let raw = lights()
        var f = SceneFrame(background: [], sceneLights: raw, lighting: lighting(raw), post: fx(), effects: SceneEffects(invF: max(0, Int(I.invF) - 1), eye: EyeAdaptState(adT: I.eye.adT, outS: I.eye.outS, darkA: I.eye.darkA, adA: I.eye.adA)), unported: nil)
        f.mid = mid.out
        return f
    }

    /// 그림자 뒤 · 인물 앞 2D: 바닥 물건(아이템) · 날아가는 병 · 신문 · 상자
    func drawMid(_ P: inout Painter) {
        P.depth = 0
        for it in I.items {
            let y = SB.FLOOR + it.z - 2 - jsRound(abs(sin(it.t * 4)) * 2)
            if it.kind != "gear" { P.placeAt("it_" + it.kind, jsRound(it.x), y, false, 0) }
            else { let ic = it.id.flatMap { K.itemIcons[$0] } ?? ""; P.placeAt(K.sprites[ic] != nil ? ic : "it_gem", jsRound(it.x), y - 4, false, 0) }
        }
        for s in I.shots {
            if s.friendly { P.quad("sb_box", jsRound(s.x) - 5, jsRound(s.y) - 4); continue }
            if s.kind == "news" { P.placeAt(newsShot(s), jsRound(s.x) - 4, jsRound(s.y) - 4, s.vx < 0, 0); continue }
            let k = m32(jsRound(s.t * 40) * (s.vx < 0 ? -1 : 1))
            P.placeAt("sb_bottle@" + jsStr(k), jsRound(s.x), jsRound(s.y), false, 0)
        }
    }

    /// 장면 광원(화면 가운데에 가까운 가로등 둘 — 스폿 + 웅덩이) · 가판대 · 하늘
    func lights() -> [SceneLight] {
        let warm: [Double] = [1, 0.64, 0.32], q = depthK
        // 깊이 · 조명(q > 0): 하늘 채움은 더 차갑고 약하게 · 등 · 웅덩이 · 가판대는 세기/반경을 올려 따뜻한 빛과 대비(바닥은 합성에서 한 단 내린다)
        var L = [SceneLight(dirl: [-0.25, 0.55, 0.8], c: [0.5 - 0.08 * q, 0.62 - 0.04 * q, 1], i: 0.24 * (1 - 0.3 * q))]
        let cx = camX + 100
        for lx in stableSorted(SnowGeo.lamps, by: { abs($0 - cx) }).prefix(2) {
            let hx = lx + 7, fl = 0.96 + 0.04 * sin(I.time * 13 + lx)   // 나트륨 등 아주 약한 떨림
            L.append(SceneLight(x: hx, y: SnowGeo.lampY + 2, z: 26, r: 175 * (1 + 0.1 * q), c: warm, i: 1.25 * fl * (1 + 0.2 * q), spot: [0, 1], cone: 0.82))
            var pool = SceneLight(x: hx, y: 204, z: 16, r: 78 * (1 + 0.3 * q), c: [1, 0.66 - 0.08 * q, 0.36 - 0.1 * q], i: 0.42 * fl * (1 + 0.35 * q)); pool.d = 0.42   // 바닥 빛 웅덩이(눈 바닥 톤이 받아 따뜻하게 밝아진다)
            L.append(pool)
        }
        var k = SceneLight(x: SnowGeo.kioskX + 23, y: 172, z: 18, r: 78, c: [1, 0.72, 0.4], i: 0.9 * (1 - 0.3 * q)); k.d = 0.42   // 가판대 바닥 빛은 오히려 낮춘다(인물 오른쪽 바닥이 하얗게 뜨지 않게)
        L.append(k)
        var sign = SceneLight(x: SnowGeo.signX - 15, y: 103, z: 10, r: 34, c: [0.8, 0.35, 0.85], i: 0.5); sign.d = 0.42
        L.append(sign)
        return L
    }

    /// 장면 광원 7개 + 주인공 · 무리 보조광(검은 양복이 눈밤에 묻히지 않게) · 환경광
    func lighting(_ raw: [SceneLight]) -> SceneLighting {
        var L = Array(raw.prefix(6))
        let q = depthK
        if q > 0, let H = I.hero, !H.hidden {
            // 깊이 · 조명: 보조광 둘 → 림 광원 둘(가까운 가로등 쪽 따뜻하게 · 반대쪽 차갑게 — 합성 림 rimSum 이 받는다) · 환경광 조금 낮춤
            let xs = [H.x] + I.foes.map(\.x), cx = xs.reduce(0, +) / Double(xs.count)
            let side: Double = DojoDepth.keyLightX("snow", cx: cx) < cx ? -1 : 1
            L.append(SceneLight(x: cx + side * 34, y: H.y - 46, z: 5, r: 130, c: [1, 0.62, 0.3], i: 1.1 * q))
            L.append(SceneLight(x: cx - side * 38, y: H.y - 40, z: 5, r: 110, c: [0.55, 0.72, 1], i: 0.75 * q))
            return SceneLighting(lights: L, ambient: 0.55 * (1 - 0.25 * q), emitK: 1)
        }
        if let H = I.hero, !H.hidden { L.append(SceneLight(x: H.x + (H.flip ? -10 : 10), y: H.y - 48, z: 30, r: 80, c: [0.78, 0.86, 1], i: 0.42)) }
        if !I.foes.isEmpty {
            let n = Double(I.foes.count), mx = I.foes.reduce(0) { $0 + $1.x } / n, my = I.foes.reduce(0) { $0 + $1.y } / n
            L.append(SceneLight(x: mx, y: my - 50, z: 34, r: 150, c: [0.62, 0.72, 1], i: 0.3))
        }
        return SceneLighting(lights: L, ambient: 0.55, emitK: 1)
    }

    func fx() -> PostFX {
        var vols: [VolumeLight] = []
        let q = depthK, hk = 1 + 1.2 * q, ik = 1 + 0.5 * q   // 깊이 · 조명: 헤일로 · 빛기둥 · 블룸을 올린다
        for lx in stableSorted(SnowGeo.lamps, by: { abs($0 - camX - 100) }).prefix(3) {
            vols.append(VolumeLight(x: lx + 7, y: SnowGeo.lampY + 2, dx: 0, dy: 1, c: [1, 0.68, 0.38], i: 0.62 * ik, cone: 0.84, len: 150, halo: 9 * hk))
        }
        vols.append(VolumeLight(x: SnowGeo.kioskX + 23, y: 168, dx: 0, dy: 1, c: [1, 0.72, 0.42], i: 0.35 * (1 - 0.35 * q), cone: 2, len: 1, halo: 16 * hk))   // 헤일로는 키우고 세기(반사 줄기)는 낮춤
        vols.append(VolumeLight(x: SnowGeo.signX - 15, y: 103, dx: 0, dy: 1, c: [0.85, 0.4, 0.9], i: 0.25 * ik, cone: 2, len: 1, halo: 8 * hk))
        let inv: Double = I.invF > 0 ? 1 : 0
        return PostFX(expo: 1.05, winR: 0, winY: [0, 0], press: 0, bloom: 0.75 * (1 + 0.7 * q), reflY: q > 0 ? Double(SnowGeo.groundTop) - 1 : -999, rain: 0, vig: 0.5, fog: 0.16,
                      fogC: [0.07, 0.1, 0.2], inv: inv, grade: [0.94, 0.98, 1.08], sat: 0.96, vols: vols)
    }
}
