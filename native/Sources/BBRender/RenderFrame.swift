import simd

/// 한 프레임을 그리는 데 필요한 전부(렌더러 입력). 렌더러는 게임 상태를 읽지 않는다 — 이 값만 본다(docs/06 §2.5).
/// 지금은 웹 캡처(frames.mjs)에서 만들어지고, N4 이후에는 BBPresentation 이 만든다.
public struct RenderFrame: Sendable {
    /// 장면 내부 해상도(지하철 480×270)
    public var width: Int
    public var height: Int
    public var time: Float
    /// 화면 흔들림(픽셀) — 스프라이트 · 3D 정점에 더해진다
    public var shake: SIMD2<Float> = .zero
    /// 좌우 반전된 스프라이트의 노멀 x 를 뒤집을지(웹 fixFlip)
    public var fixFlip = true
    /// 켜질 수 있는 창(재질 31)의 시간대 값(웹 uWin)
    public var windowLight: Float = 0
    /// 팔레트 스왑 표 48개(8세트 × 3쌍 × (원래, 바꿀))
    public var remap: [Float] = RenderFrame.defaultRemap

    /// 스프라이트 정점: 정점마다 9 float (pos.xy · uv.xy · flip · flash · depth · remap · part), 쿼드 = 6 정점
    public var spriteVertices: [Float] = []
    /// 3D 리그 정점: 정점마다 10 float (pos.xyz · normal.xy · tone · mat · part · depth · emit)
    public var meshVertices: [Float] = []
    /// G-버퍼에 그리는 순서(배경 → 그림자 → 캐릭터 → 3D → 앞 효과)
    public var gbuffer: [GBufferDraw] = []

    public var composite: CompositeParams
    /// 후처리(지하철 · 느와르 장면). 없으면 합성 결과를 그대로 화면에
    public var post: PostParams?
    public var blit: BlitParams

    public init(width: Int, height: Int, time: Float, composite: CompositeParams, post: PostParams?, blit: BlitParams) {
        self.width = width; self.height = height; self.time = time
        self.composite = composite; self.post = post; self.blit = blit
    }

    /// 웹 REMAP(12-webgl.js): 1 붉은 해골 · 2 철갑 해골 · 3 해골 기사 · 4 MMA 블루 코너 · 5~8 거리 패거리
    public static let defaultRemap: [Float] = [10, 12, 11, 7, 0, 0, 10, 8, 11, 22, 0, 0, 10, 7, 11, 12, 0, 0, 12, 6, 32, 33, 0, 0,
                                               43, 47, 6, 12, 7, 22, 43, 29, 32, 33, 6, 4, 43, 44, 44, 7, 6, 20, 43, 20, 44, 20, 32, 33]
}

public enum GBufferDraw: Sendable, Equatable {
    /// 정점 범위(정점 단위). shadow = 톤에 0.55 곱하기(그림자 쿼드)
    case sprite(first: Int, count: Int, shadow: Bool)
    case mesh(first: Int, count: Int)
}

/// 광원 하나(웹 uLP · uLC · uLD 한 칸)
public struct Light: Sendable, Equatable {
    /// x · y(장면 픽셀, 아래로 +) · z(화면 앞으로) · 반경
    public var position: SIMD4<Float>
    /// rgb · 세기
    public var color: SIMD4<Float>
    /// 점광원: (0, 0, 층 깊이, 0) · 스폿: (방향.xy, 원뿔 cos, 1) · 방향광: (방향.xyz, 2)
    public var shape: SIMD4<Float>
    public init(position: SIMD4<Float>, color: SIMD4<Float>, shape: SIMD4<Float>) { self.position = position; self.color = color; self.shape = shape }
}

/// 합성 패스(조명 · 팔레트 램프 · 캐릭터 선) — 웹 렌더 프리셋 6 "느와르 · 부드러운 빛"
public struct CompositeParams: Sendable {
    public var lights: [Light] = []        // 최대 8
    public var ambient: Float = 0.55       // uAmb(장면 · 정전 · 프롤로그에 따라)
    public var emitK: Float = 1            // uEmitK
    public var sun: SIMD2<Float> = [0, -1] // uSun(릴리프 그림자용, 프리셋 6 은 안 씀)
    public var preset = NoirPreset()
    /// 네이티브 깊이 · 조명(무도장 — docs/10 §10). 0 = 웹 그대로: 인물 1px 림 세기 · 림 쪽(-1 왼쪽 · +1 오른쪽) · 눈 바닥 램프 내림(단 단위 /6)
    public var edgeRim: Float = 0, edgeSide: Float = 0, floorStep: Float = 0
    /// 림 2색 · 반대쪽 세기: (광원 쪽 색 곱 rgb · 반대쪽 세기) · (반대쪽 색 곱 rgb · 색 켬 0/1)
    public var rimTint: [SIMD4<Float>] = [.zero, .zero]
    /// 네이티브 인물 가독성(0 = 웹 그대로): (세기 · 어두운 배경 문턱(밝기) · 밝힘 · -) — 배경이 어두우면 바깥 테를 잉크 대신 밝힌 차가운 선으로
    public var outlineAdapt: SIMD4<Float> = .zero
    public init() {}
}

/// 프리셋 6 노드 값(웹 PRESETS[6] 그대로가 기본)
public struct NoirPreset: Sendable, Equatable {
    public var lightAmb: Float = 0.12, lightGain: Float = 1, rim: Float = 0.8
    public var rampPalette: Float = 0, tintAmount: Float = 0.6, dither: Float = 0.85
    public var linePalette: Float = 0, outer: Float = 1, inner: Float = 1, select: Float = 1
    public var lineTint: SIMD3<Float> = [0x1d / 255.0, 0x2b / 255.0, 0x6b / 255.0]
    public init() {}
}

/// 후처리 값(웹 runPost 의 fx + 충격파 · 번짐)
public struct PostParams: Sendable {
    public var grade: SIMD3<Float> = [1, 1, 1], saturation: Float = 1
    public var exposure: Float = 1
    public var windowReflection: Float = 0, windowY: SIMD2<Float> = .zero
    public var pressure: Float = 0
    public var bloom: Float = 0, reflectY: Float = 0
    public var rain: Float = 0, vignette: Float = 0, fog: Float = 0, fogColor: SIMD3<Float> = .zero
    public var invert = false
    /// 젖은 바닥 재질(도로 · 보도) — 웹은 M.ROADW · M.CURB
    public var wetMaterials: SIMD3<Float> = [42, 26, -1]
    /// 볼류메트릭 원뿔 최대 6: (위치.xy, 방향.xy) · (rgb, 세기) · (원뿔 cos, 길이, 헤일로, -)
    public var volumes: [(SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)] = []
    /// 충격파 최대 4: (x, y, 반지름, 밀기) · (고리 폭, 어둡게, -, -)
    public var shockwaves: [(SIMD4<Float>, SIMD4<Float>)] = []
    public var smear: SIMD4<Float> = .zero, smearAmount: Float = 0
    /// 블룸 블러 왕복(웹은 반경 1 · 2 두 번)
    public var blurRadii: [Float] = [1, 2]
    // ---- 네이티브 깊이 · 조명(무도장 — docs/10 §10). 전부 0 = 웹 그대로 ----
    /// 원경: (섞기 · 시작 깊이 · 끝 깊이 · 안개) · (안개 rgb · 명도 낮춤) · (채도 낮춤 · 반사 줄기 · 줄기 윗선 y · 줄기 폭)
    public var depthFar: SIMD4<Float> = .zero, depthHaze: SIMD4<Float> = .zero, depthMisc: SIMD4<Float> = .zero
    /// 원경 흐림에서 뺄 원(장면 x · y · 반지름 — 건널목 해 원판)
    public var depthKeep: SIMD4<Float> = .zero
    /// 원경 블러 반경(반 해상도 px) · 캐시 열쇠(같으면 지난 원경 블러를 다시 쓴다 — nil = 매 프레임)
    public var farBlur: Float = 0.5, farKey: Int? = nil
    /// 전경 행인 · 큰 눈송이(PostU.FG)
    public var foreground: [SIMD4<Float>] = [.zero, .zero, .zero]
    /// 전경 층(미리 곱한 RGBA 바이트 · 폭 × 높이 — 행인 · 억새 · 경보기 · 기둥 …) — 있으면 렌더러가 텍스처로 올린다
    public var passer: [UInt8]? = nil, passerSize: SIMD2<Int> = .zero
    /// 전경 판 번호(0 = 늘 올린다 · 같은 번호면 지난 텍스처 그대로)
    public var passerVersion = 0
    /// 배경별 덧(PostU.EX 8칸)
    public var depthExtra: [SIMD4<Float>] = Array(repeating: .zero, count: 8)
    /// 원경 흐림 패스가 필요한가
    public var wantsFar: Bool { depthFar.x > 0 }
    public init() {}
}

/// 화면 출력(정수배 · sharp-bilinear · 세로 크롭 · 줌 펀치)
public struct BlitParams: Sendable, Equatable {
    public var zoom: Float = 1
    public var zoomCenter: SIMD2<Float> = [0.5, 0.5]
    /// 세로 화면에서 보이는 폭(VW)과 그 시작(카메라 x)
    public var visibleWidth: Float
    public var cameraX: Float = 0
    /// 화면 기울기(라디안 — 네이티브 펀치인 더치 틸트, 0 = 웹 그대로)
    public var roll: Float = 0
    public init(visibleWidth: Float) { self.visibleWidth = visibleWidth }
}

// MARK: - GPU 유니폼 묶기(Shaders.metal 의 구조체와 같은 순서 · float4 단위)

extension RenderFrame {
    var spriteUniforms: [SIMD4<Float>] {
        [SIMD4(Float(width), Float(height), shake.x, shake.y), SIMD4(time, fixFlip ? 1 : 0, 0, windowLight)]
    }
    var shadowUniforms: [SIMD4<Float>] {
        var u = spriteUniforms; u[1].z = 1; return u
    }
    var compositeUniforms: [SIMD4<Float>] {
        let c = composite, p = c.preset
        let ls = Array(c.lights.prefix(8))
        var u: [SIMD4<Float>] = [SIMD4(Float(width), Float(height), time, Float(ls.count)), SIMD4(c.ambient, c.emitK, c.sun.x, c.sun.y)]
        u += (0..<8).map { $0 < ls.count ? ls[$0].position : .zero }
        u += (0..<8).map { $0 < ls.count ? ls[$0].color : .zero }
        u += (0..<8).map { $0 < ls.count ? ls[$0].shape : .zero }
        u += [SIMD4(p.lightAmb, p.lightGain, p.rim, c.edgeRim), SIMD4(p.rampPalette, p.tintAmount, p.dither, c.edgeSide),
              SIMD4(p.linePalette, p.outer, p.inner, p.select), SIMD4(p.lineTint, c.floorStep)] + c.rimTint.prefix(2)
        u.append(c.outlineAdapt)
        return u
    }
    func postUniforms(_ f: PostParams) -> [SIMD4<Float>] {
        let vols = Array(f.volumes.prefix(6)), sws = Array(f.shockwaves.prefix(4))
        var u: [SIMD4<Float>] = [
            SIMD4(f.grade, f.saturation), SIMD4(f.exposure, f.windowReflection, f.windowY.x, f.windowY.y),
            SIMD4(f.pressure, time, f.bloom, f.reflectY), SIMD4(f.rain, f.vignette, f.fog, f.invert ? 1 : 0),
            SIMD4(f.fogColor, 0), SIMD4(Float(width), Float(height), Float(vols.count), Float(sws.count)), SIMD4(f.wetMaterials, 0),
        ]
        u += (0..<6).map { $0 < vols.count ? vols[$0].0 : .zero }
        u += (0..<6).map { $0 < vols.count ? vols[$0].1 : .zero }
        u += (0..<6).map { $0 < vols.count ? vols[$0].2 : .zero }
        u += (0..<4).map { $0 < sws.count ? sws[$0].0 : .zero }
        u += (0..<4).map { $0 < sws.count ? sws[$0].1 : .zero }
        u += [f.smear, SIMD4(f.smearAmount, 0, 0, 0)]
        u += [f.depthFar, f.depthHaze, f.depthMisc, f.depthKeep] + f.foreground.prefix(3) + f.depthExtra.prefix(8)
        return u
    }
}
