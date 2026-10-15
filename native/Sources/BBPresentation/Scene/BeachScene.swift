import Foundation
import BBContent
import BBSim

// 해변 도장 장면 구성(docs/12) — 무대 픽셀 배경(BeachArt · BeachFx) + 광원 · 후처리. 웹에 없는 장면(깃발 켜짐 · 무도장에서만).
//  · 오후: 오른쪽 위 해(따뜻한 흰 방향광) + 하늘 채움(푸른) · 밝은 환경광 · 블룸 낮게 · 살짝 따뜻한 보정
//  · 노을: 수평선에 걸린 해(낮고 붉은 방향광 — 인물은 해 쪽 테가 금빛: DojoDepth 림) + 보랏빛 채움 · 블룸 높게 · 따뜻한 보정 · 채도 조금 올림
//  · 밤: 달(차가운 방향광) · 감시탑 차양 밑 등(따뜻한 점광원) · 카메라 쪽 산책로 불빛(인물이 어둠에 묻히지 않게) · 차가운 보정
//  · 해 · 달 빛무리(볼류메트릭 헤일로) · 젖은 바닥 반사 줄(reflY — 물 · 젖은 모래에 하늘과 해가 비친다)

struct BeachContext {
    let I: SceneInput
    let K: SceneContent
    let camX: Double
    let time: BeachTime
    /// 무도장 깊이 · 조명 세기(0 = 꺼짐)
    var depthK = 0.0

    func compose() -> SceneFrame {
        var mid = Painter(K.sprites)
        SnowContext(I: I, K: K, camX: camX).drawMid(&mid)   // 바닥 물건 · 날아가는 것(눈 승강장과 같다)
        let raw = lights()
        var f = SceneFrame(background: [], sceneLights: raw, lighting: lighting(raw), post: fx(), effects: SceneEffects(invF: max(0, Int(I.invF) - 1), eye: EyeAdaptState(adT: I.eye.adT, outS: I.eye.outS, darkA: I.eye.darkA, adA: I.eye.adA)), unported: nil)
        f.mid = mid.out
        return f
    }

    /// 해(달) 장면 자리 — 하늘 층은 화면에 붙어 있다
    var sunAt: SIMD2<Double> { let s = BeachGeo.sun(time); return SIMD2(camX + s.x, s.y) }

    func lights() -> [SceneLight] {
        let q = depthK
        switch time {
        case .day:
            return [SceneLight(dirl: [0.45, 0.75, 0.5], c: [1, 0.95, 0.84], i: 0.62),
                    SceneLight(dirl: [-0.35, 0.6, 0.7], c: [0.62, 0.76, 1], i: 0.26 * (1 - 0.2 * q))]
        case .dusk:
            return [SceneLight(dirl: [0.8, 0.22, 0.3], c: [1, 0.58, 0.3], i: 0.62),
                    SceneLight(dirl: [-0.4, 0.55, 0.7], c: [0.58, 0.44, 0.82], i: 0.24)]
        case .night:
            var L = [SceneLight(dirl: [0.35, 0.7, 0.55], c: [0.6, 0.72, 1], i: 0.3)]
            var tower = SceneLight(x: BeachGeo.towerX + 13, y: 148, z: 20, r: 120, c: [1, 0.68, 0.38], i: 1.1); tower.d = 0.42   // 감시탑 차양 밑 등
            L.append(tower)
            var walk = SceneLight(x: camX - 30, y: 190, z: 70, r: 230, c: [1, 0.8, 0.55], i: 0.26); walk.d = 0.42   // 카메라 쪽 산책로 불빛
            L.append(walk)
            return L
        }
    }

    /// 주인공 · 무리 보조광(검은 양복이 묻히지 않게) — 깊이 · 조명 켜짐이면 해(달) 쪽 · 반대쪽 림 광원 둘
    func lighting(_ raw: [SceneLight]) -> SceneLighting {
        var L = Array(raw.prefix(6))
        let amb: Double = time == .day ? 0.6 : time == .dusk ? 0.46 : 0.3
        let key: [Double] = time == .day ? [1, 0.92, 0.8] : time == .dusk ? [1, 0.6, 0.32] : [0.62, 0.74, 1]
        let fill: [Double] = time == .day ? [0.6, 0.74, 1] : time == .dusk ? [0.62, 0.5, 0.9] : [1, 0.72, 0.42]
        if let H = I.hero, !H.hidden {
            let xs = [H.x] + I.foes.map(\.x), cx = xs.reduce(0, +) / Double(xs.count)
            let side: Double = sunAt.x < cx ? -1 : 1
            let q = depthK
            L.append(SceneLight(x: cx + side * 36, y: H.y - 50, z: 8, r: 140, c: key, i: (time == .dusk ? 0.9 : 0.55) * (0.6 + 0.4 * q)))
            L.append(SceneLight(x: cx - side * 38, y: H.y - 40, z: 8, r: 110, c: fill, i: 0.45 * (0.6 + 0.4 * q)))
        }
        return SceneLighting(lights: L, ambient: amb, emitK: 1)
    }

    func fx() -> PostFX {
        let s = sunAt, q = depthK
        var vols: [VolumeLight] = []
        switch time {
        case .day: vols.append(VolumeLight(x: s.x, y: s.y, dx: 0, dy: 1, c: [1, 0.96, 0.82], i: 0.5, cone: 2, len: 1, halo: 16 * (1 + 0.6 * q)))
        case .dusk: vols.append(VolumeLight(x: s.x, y: s.y, dx: 0, dy: 1, c: [1, 0.62, 0.32], i: 0.8, cone: 2, len: 1, halo: 30 * (1 + 0.6 * q)))
        case .night:
            vols.append(VolumeLight(x: s.x, y: s.y, dx: 0, dy: 1, c: [0.78, 0.86, 1], i: 0.45, cone: 2, len: 1, halo: 13 * (1 + 0.6 * q)))
            vols.append(VolumeLight(x: BeachGeo.towerX + 13, y: 148, dx: 0, dy: 1, c: [1, 0.7, 0.4], i: 0.45, cone: 0.8, len: 70, halo: 6))
            // 등대(Sea Gate) 회전 빛줄기: 옆에서 보면 좌우로 늘었다 줄고, 카메라 쪽을 향할 때 번쩍
            let lb = BeachFx.lighthouseBeam(I.time), lx = Double(BeachGeo.lighthouse.x) + 0.94 * camX + 1, ly = Double(BeachGeo.lighthouse.y)
            vols.append(VolumeLight(x: lx, y: ly, dx: lb.dir, dy: 0.04, c: [1, 0.9, 0.66], i: 0.8 * lb.len + 0.2, cone: 0.992, len: 6 + 150 * lb.len, halo: 3 + 14 * lb.flash))
        }
        let inv: Double = I.invF > 0 ? 1 : 0
        let reflY = q > 0 ? Double(BeachGeo.horizon + BeachGeo.shore) / 2 : -999   // 물 · 젖은 모래가 수평선 위 하늘(해)을 비춘다
        switch time {
        case .day:
            return PostFX(expo: 1.0, winR: 0, winY: [0, 0], press: 0, bloom: 0.42 * (1 + 0.4 * q), reflY: reflY, rain: 0, vig: 0.32, fog: 0.05, fogC: [0.55, 0.68, 0.85], inv: inv, grade: [1.03, 1.0, 0.96], sat: 1.06, vols: vols)
        case .dusk:
            return PostFX(expo: 1.04, winR: 0, winY: [0, 0], press: 0, bloom: 0.85 * (1 + 0.5 * q), reflY: reflY, rain: 0, vig: 0.45, fog: 0.1, fogC: [0.5, 0.26, 0.3], inv: inv, grade: [1.08, 0.98, 0.9], sat: 1.1, vols: vols)
        case .night:
            return PostFX(expo: 1.06, winR: 0, winY: [0, 0], press: 0, bloom: 0.72 * (1 + 0.5 * q), reflY: reflY, rain: 0, vig: 0.55, fog: 0.14, fogC: [0.06, 0.09, 0.18], inv: inv, grade: [0.93, 0.98, 1.08], sat: 0.96, vols: vols)
        }
    }
}
