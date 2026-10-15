import BBContent
import BBPresentation
import simd

// BBPresentation 장면 구성(SceneFrame) → 렌더러 입력(RenderFrame 조각). 웹 render() 의 '묶기' 부분:
// 배경 쿼드 → 정점(quad), 광원 → uLP · uLC · uLD(흔들림만큼 x 이동), fx → runPost 유니폼.

extension SpriteBatch {
    /// 장면 쿼드 목록을 정점으로 쌓는다(웹 quad 와 같은 정점 · 층 값)
    public mutating func append(_ draws: [SpriteDraw], atlas: [String: AtlasMeta.Sprite]) {
        for d in draws {
            guard let s = atlas[d.name] else { continue }
            depth = Float(d.depth); offsetX = Float(d.offsetX); remap = Float(d.remap); part = Float(d.part)
            quad(s, x: Float(d.x), y: Float(d.y), flip: d.flip != 0, flash: d.flash != 0)
        }
        depth = 0; offsetX = 0; remap = 0; part = 0
    }
}

extension Light {
    /// 웹 render(): 방향광은 (0,0,0,1) · (방향, 2), 점광원은 (0,0,층 깊이,0), 스폿은 (방향, cos, 1). shake = SHK()
    public init(scene L: SceneLight, shake: Double = 0) {
        let c = SIMD4<Float>(Float(L.c[0]), Float(L.c[1]), Float(L.c[2]), Float(L.i))
        if let d = L.dirl {
            self.init(position: SIMD4(Float(0 + shake), 0, 0, 1), color: c, shape: SIMD4(Float(d[0]), Float(d[1]), Float(d[2]), 2))
            return
        }
        let shape: SIMD4<Float> = if let s = L.spot { SIMD4(Float(s[0]), Float(s[1]), Float(L.cone ?? 0), 1) } else { SIMD4(0, 0, Float(L.d ?? 0), 0) }
        self.init(position: SIMD4(Float(L.x + shake), Float(L.y), Float(L.z), Float(L.r)), color: c, shape: shape)
    }
}

extension CompositeParams {
    /// 장면 합성 값 적용(광원 최대 8 — 웹은 장면 광원 뒤에 인물 · 효과 동적 광원을 붙인 다음 8개로 자른다)
    public mutating func apply(_ s: SceneLighting, extraLights: [SceneLight] = [], shake: Double = 0) {
        lights = (s.lights + extraLights).prefix(8).map { Light(scene: $0, shake: shake) }
        ambient = Float(s.ambient); emitK = Float(s.emitK)
    }
}

extension PostParams {
    /// 웹 runPost(fx): 없는 필드는 runPost 기본값. impactInvert = IMPF>0, shake = SHK()(빛줄기 x)
    public init(scene f: PostFX, impactInvert: Bool = false, shake: Double = 0) {
        self.init()
        exposure = Float(f.expo ?? 1); windowReflection = Float(f.winR ?? 0)
        let wy = f.winY ?? [0, 0]; windowY = SIMD2(Float(wy[0]), Float(wy[1]))
        pressure = Float(f.press ?? 0); bloom = Float(f.bloom); reflectY = Float(f.reflY)
        let g = f.grade ?? [1, 1, 1]; grade = SIMD3(Float(g[0]), Float(g[1]), Float(g[2])); saturation = Float(f.sat ?? 1)
        rain = Float(f.rain); invert = f.inv != 0 || impactInvert; vignette = Float(f.vig); fog = Float(f.fog)
        fogColor = SIMD3(Float(f.fogC[0]), Float(f.fogC[1]), Float(f.fogC[2]))
        volumes = f.vols.prefix(6).map { v in
            (SIMD4(Float(v.x + shake), Float(v.y), Float(v.dx), Float(v.dy)), SIMD4(Float(v.c[0]), Float(v.c[1]), Float(v.c[2]), Float(v.i)),
             SIMD4(Float(v.cone), Float(v.len), Float(v.halo), 0))
        }
    }
}

extension RenderFrame {
    /// 장면 구성이 정하는 스프라이트 셰이더 값 — uWin(느와르 거리의 켜질 수 있는 창 = 1, 지하철 0).
    /// RenderFrame(stage:) 뒤에 부른다(FrameAssembly 가 아직 이 값을 옮기지 않는다).
    public mutating func applyScene(_ s: SceneFrame) {
        windowLight = Float(s.windowLight)
    }
}
