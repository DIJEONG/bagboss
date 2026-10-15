// 장면 구성 진입점 — 웹 render() 의 장면 부분:
//   지하철(타워 · 복도 · 무도장 갈래 포함): drawSubwayBack(time) → (캐릭터 · 앞 효과는 다른 층) → subwayLights(time) 7개 × lightK + 주인공 보조광 · uAmb · uEmitK → subwayFX()
//   brawl(보너스 · 비 오는 거리): 배경 nb → 소품 · 3D 차 · 바닥 물건 → 맨 앞 차 / noirLights + 보조광 + 동적 광원 / noirFX + 날씨 (NoirScene.swift)
// 웹과 같은 순서로 난수를 쓴다(배경 → 광원 → 후처리). 웹이 GS 를 바꾸던 것은 effects 로 나온다.
// 그리기 상태가 없는 갈래(입력에 corridor · dojoRoom · brawl 이 비었을 때)는 unported 로 알린다.

public struct SceneFrame: Sendable, Equatable {
    /// 배경 층 쿼드(그리기 순서 그대로) — G-버퍼 첫 그리기
    public var background: [SpriteDraw]
    /// 장면 광원(웹 subwayLights 반환값 — 자르기 · 배율 전)
    public var sceneLights: [SceneLight]
    /// 렌더 합성(자르기 · lightK · 보조광 · 환경광 · 발광)
    public var lighting: SceneLighting
    public var post: PostFX
    public var effects: SceneEffects
    /// 이식하지 않은 갈래를 만났으면 그 이름(그때 나머지 값은 비어 있다)
    public var unported: String?
    // ---- N5 장면(brawl · 무도장 건널목)이 더 쓰는 층 — 지하철 · 타워 · 복도는 비어 있다 ----
    /// 그림자 뒤 · 인물 앞 2D(웹 brawl: drawCineProps · 차 연기 입자 · 바닥 물건) — G-버퍼에서 먼지보다 먼저
    public var mid: [SpriteDraw] = []
    /// 3D(웹 drawBonusCar → pushModel: 보너스 차 · 떨어진 부품) — 인물 3D 보다 먼저(정점당 10 float)
    public var mesh: [Float] = []
    /// 인물 앞(웹 drawCrossFront — 날리는 단풍) — 앞 효과(고리 · 파편 · 불꽃)와 같은 층
    public var front: [SpriteDraw] = []
    /// 맨 앞(웹 brawl: 시차 1.18 로 지나가는 주차된 차 n_car) — 글리프 숫자 뒤
    public var top: [SpriteDraw] = []
    /// 인물 · 그림자 · 효과의 화면 x 이동(웹 charOX — brawl 카메라 -round(GS.cam))
    public var charOX: Double = 0
    /// 스프라이트 셰이더 uWin(켜질 수 있는 창 재질 — 느와르 거리 1, 지하철 0)
    public var windowLight: Double = 0
}

public enum SceneComposer {
    /// 장면 하나 구성(웹 drawSubwayBack · subwayLights · subwayFX 를 그 순서로 부른 것과 같다 — brawl 이면 render() brawl 갈래)
    public static func compose<R: SceneRandom>(_ I: SceneInput, content K: SceneContent, rng: inout R) -> SceneFrame {
        var eff = SceneEffects(invF: Int(I.invF), eye: EyeAdaptState(adT: I.eye.adT, outS: I.eye.outS, darkA: I.eye.darkA, adA: I.eye.adA))
        if let u = unported(I) {
            return SceneFrame(background: [], sceneLights: [], lighting: SceneLighting(lights: [], ambient: 0, emitK: 1),
                              post: PostFX(bloom: 0, reflY: 0, rain: 0, vig: 0, fog: 0, fogC: [0, 0, 0], inv: 0, vols: []), effects: eff, unported: u)
        }
        if I.scene == "brawl", let B = I.brawl { return NoirContext(I: I, K: K, B: B).compose(&eff, &rng) }
        let back = background(I, K, &eff, &rng)
        let I2 = applyEffects(I, eff)                                           // 그리며 만든 상태(복도 전등 · 건널목)를 광원 · 후처리가 본다
        let lights = sceneLights(I2, K, &rng)
        let post = postFX(I2, K, &eff)
        var f = SceneFrame(background: back, sceneLights: lights, lighting: lighting(I2, lights), post: post, effects: eff, unported: nil)
        f.front = front(I2, K)
        return f
    }

    /// 그리기 상태가 없어 그릴 수 없는 갈래 이름(brawl · prologue · dojo) — 웹 drawSubwayBack 의 갈래 순서(복도 → 타워 → 무도장)
    public static func unported(_ I: SceneInput) -> String? {
        if I.scene == "brawl" { return I.brawl == nil ? "brawl" : nil }
        if I.prologue { return I.corridor == nil ? "prologue" : nil }
        if I.tower != nil { return nil }
        if I.dojo { return I.dojoRoom == nil ? "dojo" : nil }
        return nil
    }

    /// 그리기가 만든 숨은 상태를 입력에 반영(웹은 같은 객체라 이어지는 광원 · 후처리 함수가 바로 본다)
    public static func applyEffects(_ I: SceneInput, _ eff: SceneEffects) -> SceneInput {
        var I = I
        if !eff.corridorLamps.isEmpty { I.corridor?.lamps += eff.corridorLamps }
        if let X = eff.cross, I.dojoRoom != nil, I.dojoRoom?.xc == nil { I.dojoRoom?.xc = X }
        return I
    }

    /// 웹 drawSubwayBack (복도 → 타워 → 무도장 → 지하철)
    public static func background<R: SceneRandom>(_ I: SceneInput, _ K: SceneContent, _ eff: inout SceneEffects, _ rng: inout R) -> [SpriteDraw] {
        var P = Painter(K.sprites)
        if I.prologue, let C = I.corridor { CorridorContext(I: I, K: K, C: C).drawBack(&P, &eff, &rng) }
        else if let T = I.tower { TowerContext(I: I, K: K, T: T).drawBack(&P, &rng) }
        else if I.dojo, let D = I.dojoRoom { DojoContext(I: I, K: K, D: D).drawBack(&P, &eff, &rng) }
        else { SubwayContext(I, K).drawBack(&P, &eff, &rng) }
        return P.out
    }

    /// 웹 subwayLights
    public static func sceneLights<R: SceneRandom>(_ I: SceneInput, _ K: SceneContent, _ rng: inout R) -> [SceneLight] {
        if I.prologue, let C = I.corridor { return CorridorContext(I: I, K: K, C: C).lights() }
        if let T = I.tower { return TowerContext(I: I, K: K, T: T).lights(&rng) }
        if I.dojo, let D = I.dojoRoom { return DojoContext(I: I, K: K, D: D).lights(D.xc ?? SceneInput.Cross()) }
        return SubwayContext(I, K).lights(&rng)
    }

    /// 웹 subwayFX (복도 → 무도장 → 타워 → subwayFX0 + 노선 색 보정)
    public static func postFX(_ I: SceneInput, _ K: SceneContent, _ eff: inout SceneEffects) -> PostFX {
        if I.prologue, let C = I.corridor { return CorridorContext(I: I, K: K, C: C).fx(&eff) }
        if I.dojo, let D = I.dojoRoom { return DojoContext(I: I, K: K, D: D).fx(D.xc ?? SceneInput.Cross()) }
        if let T = I.tower { return TowerContext(I: I, K: K, T: T).fx(&eff) }
        return SubwayContext(I, K).fx(&eff)
    }

    /// 웹 drawCrossFront — 인물 앞 층(건널목 날리는 단풍)
    public static func front(_ I: SceneInput, _ K: SceneContent) -> [SpriteDraw] {
        guard I.dojo, !I.prologue, I.tower == nil, let D = I.dojoRoom, let X = D.xc else { return [] }
        return DojoContext(I: I, K: K, D: D).drawFront(X)
    }

    /// 웹 render() 의 지하철 광원 합성 · uAmb · uEmitK
    public static func lighting(_ I: SceneInput, _ lights: [SceneLight]) -> SceneLighting {
        let lk = I.lightK ?? 1
        var out = lights.prefix(7).map { l -> SceneLight in var l = l; l.i = l.i * lk; return l }
        if let H = I.hero, !H.hidden, lk > 0.02 {                            // 검은 양복이 어둠에 묻히지 않게
            out.append(SceneLight(x: H.x + (H.flip ? -10 : 10), y: H.y - 48, z: 30, r: 78, c: [0.82, 0.88, 1], i: 0.6 * lk * (I.oneBit ? 0.5 : 1)))
        }
        let subway = I.scene == "subway"
        let uAmbV: Double = subway ? (I.dojo ? 0.82 : (I.on && I.tower != nil) ? (I.tower!.dark ? 0.14 : 0.44) : 0.55) : 1
        let amb = uAmbV * (subway && I.on ? (I.prologue ? 1.45 : I.oneBit ? 0.08 : (0.2 + 0.8 * (I.lightK ?? 1))) : 1)
        let emitK = subway && I.on ? (I.emitK ?? 1) : 1
        return SceneLighting(lights: out, ambient: amb, emitK: emitK)
    }
}
