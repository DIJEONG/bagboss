import BBCore

// 장면 구성의 출력 어휘 — 렌더러(BBRender)를 모르는 순수 값이다. BBRender 쪽 SceneAdapter 가 RenderFrame 으로 옮긴다.
// 웹 원본: 17-light-frame quad() · placeAt() 의 인자, 장면 *Lights() 의 광원 객체, *FX() 의 fx 객체(runPost 입력).

/// 스프라이트 쿼드 하나(웹 quad() 한 번 — placeAt 은 피벗을 풀어 quad 로 바꾼 뒤 기록한다).
/// x · y 는 drawOX 를 더하기 전 값, 나머지는 호출 순간의 층 상태(drawDepth · drawOX · drawRemap · drawPart).
public struct SpriteDraw: Sendable, Equatable {
    public var name: String
    public var x: Double
    public var y: Double
    public var flip: Double
    public var flash: Double
    public var depth: Double
    public var offsetX: Double
    public var remap: Double
    public var part: Double
    public init(name: String, x: Double, y: Double, flip: Double = 0, flash: Double = 0,
                depth: Double = 0, offsetX: Double = 0, remap: Double = 0, part: Double = 0) {
        self.name = name; self.x = x; self.y = y; self.flip = flip; self.flash = flash
        self.depth = depth; self.offsetX = offsetX; self.remap = remap; self.part = part
    }
}

/// 장면 광원(웹 광원 객체 그대로). 방향광은 dirl 만 쓴다.
public struct SceneLight: Sendable, Equatable, Codable {
    public var x: Double = 0, y: Double = 0, z: Double = 0, r: Double = 0
    public var c: [Double]
    public var i: Double
    /// 스폿 방향(x, y) · 원뿔 cos
    public var spot: [Double]?
    public var cone: Double?
    /// 비상등처럼 정전 배율(×0.45)을 받지 않는 빛
    public var em: Bool?
    /// 방향광 방향(xyz)
    public var dirl: [Double]?
    /// 층 깊이(도시 장면 동적 광원) — 지하철 · 타워는 없음
    public var d: Double?
    public init(x: Double, y: Double, z: Double, r: Double, c: [Double], i: Double,
                spot: [Double]? = nil, cone: Double? = nil, em: Bool? = nil) {
        self.x = x; self.y = y; self.z = z; self.r = r; self.c = c; self.i = i; self.spot = spot; self.cone = cone; self.em = em
    }
    public init(dirl: [Double], c: [Double], i: Double) { self.dirl = dirl; self.c = c; self.i = i }

    // 웹 객체는 필드가 있다 없다 한다(방향광엔 x 가 없음) — 없는 필드는 기본값
    enum CodingKeys: String, CodingKey { case x, y, z, r, c, i, spot, cone, em, dirl, d }
    public init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        x = try k.decodeIfPresent(Double.self, forKey: .x) ?? 0; y = try k.decodeIfPresent(Double.self, forKey: .y) ?? 0
        z = try k.decodeIfPresent(Double.self, forKey: .z) ?? 0; r = try k.decodeIfPresent(Double.self, forKey: .r) ?? 0
        c = try k.decode([Double].self, forKey: .c); i = try k.decode(Double.self, forKey: .i)
        spot = try k.decodeIfPresent([Double].self, forKey: .spot); cone = try k.decodeIfPresent(Double.self, forKey: .cone)
        em = try k.decodeIfPresent(Bool.self, forKey: .em); dirl = try k.decodeIfPresent([Double].self, forKey: .dirl)
        d = try k.decodeIfPresent(Double.self, forKey: .d)
    }
}

/// 볼류메트릭 빛줄기(웹 fx.vols 한 칸)
public struct VolumeLight: Sendable, Equatable, Codable {
    public var x: Double, y: Double, dx: Double, dy: Double
    public var c: [Double]
    public var i: Double, cone: Double, len: Double, halo: Double
}

/// 후처리 입력(웹 fx 객체 — runPost 가 읽는 필드). 없는 필드는 runPost 의 기본값(expo 1 · grade 1 · sat 1 …)을 쓴다.
public struct PostFX: Sendable, Equatable, Codable {
    public var expo: Double?
    public var winR: Double?
    public var winY: [Double]?
    public var press: Double?
    public var bloom: Double
    public var reflY: Double
    public var rain: Double
    public var vig: Double
    public var fog: Double
    public var fogC: [Double]
    public var inv: Double
    public var grade: [Double]?
    public var sat: Double?
    public var vols: [VolumeLight]
}

extension PostFX {
    enum CodingKeys: String, CodingKey { case expo, winR, winY, press, bloom, reflY, rain, vig, fog, fogC, inv, grade, sat, vols }
    /// 웹 fx 객체는 inv 가 없을 수 있다(noirFX — runPost 는 fx.inv||0)
    public init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        self.init(expo: try k.decodeIfPresent(Double.self, forKey: .expo), winR: try k.decodeIfPresent(Double.self, forKey: .winR),
                  winY: try k.decodeIfPresent([Double].self, forKey: .winY), press: try k.decodeIfPresent(Double.self, forKey: .press),
                  bloom: try k.decode(Double.self, forKey: .bloom), reflY: try k.decode(Double.self, forKey: .reflY), rain: try k.decode(Double.self, forKey: .rain),
                  vig: try k.decode(Double.self, forKey: .vig), fog: try k.decode(Double.self, forKey: .fog), fogC: try k.decode([Double].self, forKey: .fogC),
                  inv: try k.decodeIfPresent(Double.self, forKey: .inv) ?? 0, grade: try k.decodeIfPresent([Double].self, forKey: .grade),
                  sat: try k.decodeIfPresent(Double.self, forKey: .sat), vols: try k.decode([VolumeLight].self, forKey: .vols))
    }
}

/// 렌더 합성 값(웹 render() 가 장면 광원에 lightK · 주인공 보조광을 더하고 uAmb · uEmitK 를 정하는 부분)
public struct SceneLighting: Sendable, Equatable {
    public var lights: [SceneLight]
    public var ambient: Double
    public var emitK: Double
}

/// 눈 적응(자동 노출) 상태 — 웹은 GS.adT · outS · darkA · adA 에 숨겨 둔다. 여기선 입력으로 받고 새 값을 돌려준다.
public struct EyeAdaptState: Sendable, Equatable, Codable {
    public var adT: Double?
    public var outS: Double?
    public var darkA: Double?
    public var adA: Double?
    public init(adT: Double? = nil, outS: Double? = nil, darkA: Double? = nil, adA: Double? = nil) {
        self.adT = adT; self.outS = outS; self.darkA = darkA; self.adA = adA
    }
}

/// 장면 구성이 '게임 상태에 하던 일'을 드러낸 것. 웹은 함수 안에서 직접 바꾼다(숨은 변경) — 여기선 호출자가 반영한다.
public struct SceneEffects: Sendable, Equatable {
    /// GS.invF(화면 반전 남은 프레임) 새 값 — subwayFX0 · towerFX 가 하나씩 깎는다
    public var invF: Int
    /// 눈 적응 새 상태(subwayFX0 → eyeAdapt)
    public var eye: EyeAdaptState
    /// 공사 칸 배선 불꽃(drawCarLayer 가 sparks 배열에 넣던 것)
    public var sparks: [Spark] = []
    /// 그 불꽃의 파편(GS.bits 에 넣던 것)
    public var bits: [Bit] = []
    /// 보너스 차 찌그러짐 수 새 값(웹 carBones 가 C.dentN 에 쓰던 것 — 다음 프레임 입력 car.dentN)
    public var dentN: Int?
    /// 복도 전등을 처음 그리며 만든 자리(웹 corrLamps 가 P.lamps 에 난수 각도로 넣던 것)
    public var corridorLamps: [SceneInput.Corridor.Lamp] = []
    /// 무도장이 처음 그려지며 만든 건널목 상태(웹 xcEnsure → xcReset 이 DJ.xc 에 넣던 것)
    public var cross: SceneInput.Cross?
    public init(invF: Int, eye: EyeAdaptState) { self.invF = invF; self.eye = eye }
    public struct Spark: Sendable, Equatable, Codable { public var x: Double, y: Double, age: Double }
    public struct Bit: Sendable, Equatable, Codable { public var x: Double, y: Double, vx: Double, vy: Double, t: Double }
}

// MARK: - 연출 난수

/// 장면 연출 난수(웹 Math.random 자리) — [0, 1). 호출 순서까지 웹과 같아야 대조가 된다.
public protocol SceneRandom {
    mutating func next() -> Double
}

/// BBCore 생성기(rngFx 스트림)를 장면 난수로
public struct FxRandom<G: GameRandom>: SceneRandom {
    public var base: G
    public init(_ base: G) { self.base = base }
    public mutating func next() -> Double { base.next() }
}

/// 기록된 수열을 그대로 내는 난수(웹 대조 · 재생용). 다 쓰면 마지막 값(없으면 0)을 되풀이한다.
public struct ReplayRandom: SceneRandom {
    public let values: [Double]
    public private(set) var used = 0
    public init(_ values: [Double]) { self.values = values }
    public mutating func next() -> Double {
        defer { used += 1 }
        return used < values.count ? values[used] : (values.last ?? 0)
    }
}

/// 언제나 같은 값(e2e 대조에서 웹 Math.random 을 상수로 바꿨을 때)
public struct ConstantRandom: SceneRandom {
    public let value: Double
    public init(_ value: Double) { self.value = value }
    public mutating func next() -> Double { value }
}
