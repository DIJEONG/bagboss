import Foundation

// 인물 3D 모델 만들기 — 웹 12-webgl.js prism · noirModel · suitModel 1:1 이식.
// 숫자 식(4.1*tw*.9 · x*.88 · y+.75 …)은 웹과 같은 순서로 계산한다 — 결과 조각이 비트 단위로 같아야 픽스처(models.json)와 맞는다.

/// 재질 번호(웹 01-core.js M)
public enum Mat {
    public static let EMPTY = 0.0, INK = 1.0, SKY = 2.0, LEAF = 3.0, GRASS = 4.0, STONE = 5.0, ARMOR = 6.0, DARK = 7.0, STEEL = 8.0, GOLD = 9.0,
                      BONE = 10.0, WOOD = 11.0, RED = 12.0, EYE = 13.0, WATER = 14.0, MOON = 15.0
    public static let SKYD = 16.0, CONC = 17.0, PANEL = 18.0, GLASS = 19.0, FRAME = 20.0, CURT = 21.0, MDARK = 22.0, PINE = 23.0, PFAR = 24.0,
                      ASPH = 25.0, CURB = 26.0, HEDGE = 27.0, LAWN = 28.0, VAN = 29.0, WIRE = 30.0, WINLIT = 31.0
    public static let SKIN = 32.0, SKIN2 = 33.0, HAIR = 34.0, CANVAS = 35.0, CROWD = 36.0
    public static let BRICK = 37.0, STONEL = 38.0, NEONT = 39.0, NEONP = 40.0, NEONO = 41.0, ROADW = 42.0, COAT = 43.0, SUIT = 44.0, IVY = 45.0,
                      TAXI = 46.0, WOODD = 47.0
    public static let DUSK = 48.0, CLOUD = 49.0, MAPLE = 50.0, LEAFO = 51.0, TRAMG = 52.0, TRAMC = 53.0, ROADS = 54.0, HILL = 55.0

    /// 이름 → 번호(웹 M[name])
    public static let byName: [String: Double] = [
        "EMPTY": 0, "INK": 1, "SKY": 2, "LEAF": 3, "GRASS": 4, "STONE": 5, "ARMOR": 6, "DARK": 7, "STEEL": 8, "GOLD": 9, "BONE": 10, "WOOD": 11,
        "RED": 12, "EYE": 13, "WATER": 14, "MOON": 15, "SKYD": 16, "CONC": 17, "PANEL": 18, "GLASS": 19, "FRAME": 20, "CURT": 21, "MDARK": 22,
        "PINE": 23, "PFAR": 24, "ASPH": 25, "CURB": 26, "HEDGE": 27, "LAWN": 28, "VAN": 29, "WIRE": 30, "WINLIT": 31, "SKIN": 32, "SKIN2": 33,
        "HAIR": 34, "CANVAS": 35, "CROWD": 36, "BRICK": 37, "STONEL": 38, "NEONT": 39, "NEONP": 40, "NEONO": 41, "ROADW": 42, "COAT": 43,
        "SUIT": 44, "IVY": 45, "TAXI": 46, "WOODD": 47, "DUSK": 48, "CLOUD": 49, "MAPLE": 50, "LEAFO": 51, "TRAMG": 52, "TRAMC": 53,
        "ROADS": 54, "HILL": 55,
    ]
}

/// 웹 noirModel(o) 의 o
public struct NoirOptions: Sendable, Equatable {
    public var suit = false
    public var coat: Double?, trou: Double?
    public var cap = false
    public var hatMat: Double?
    /// 머리 모양(suitModel): tophat · mohawk · pomp · goggle · bandana · fedora · bald · 그 밖(머리 4조각만)
    public var hair: String?
    public var fat = false
    /// 넥타이 재질 이름(웹 M[o.tie]) — 없으면 검정(MDARK)
    public var tie: String?
    public var noTie = false
    public var mandarin = false
    public var bandMat: Double?
    public init(suit: Bool = false, coat: Double? = nil, trou: Double? = nil, cap: Bool = false, hatMat: Double? = nil, hair: String? = nil,
                fat: Bool = false, tie: String? = nil, noTie: Bool = false, mandarin: Bool = false, bandMat: Double? = nil) {
        self.suit = suit; self.coat = coat; self.trou = trou; self.cap = cap; self.hatMat = hatMat; self.hair = hair
        self.fat = fat; self.tie = tie; self.noTie = noTie; self.mandarin = mandarin; self.bandMat = bandMat
    }
}

/// 웹 prism: y축을 따라 가늘어지는 상자. 위 단면(앞뒤 반폭 hw0, 좌우 반폭 hd0, 중심 cx0) → 아래 단면
public func prism(_ y0: Double, _ y1: Double, _ cx0: Double, _ hw0: Double, _ hd0: Double, _ cx1: Double, _ hw1: Double, _ hd1: Double,
                  _ mat: Double, _ tone: Double, _ part: Double, _ cz: Double = 0) -> Prism {
    let A = [SIMD3(cx0 - hw0, y0, cz - hd0), SIMD3(cx0 + hw0, y0, cz - hd0), SIMD3(cx0 + hw0, y0, cz + hd0), SIMD3(cx0 - hw0, y0, cz + hd0)]
    let B = [SIMD3(cx1 - hw1, y1, cz - hd1), SIMD3(cx1 + hw1, y1, cz - hd1), SIMD3(cx1 + hw1, y1, cz + hd1), SIMD3(cx1 - hw1, y1, cz + hd1)]
    return Prism(q: [[A[0], A[1], A[2], A[3]], [B[0], B[1], B[2], B[3]], [A[0], A[1], B[1], B[0]], [A[1], A[2], B[2], B[1]],
                     [A[2], A[3], B[3], B[2]], [A[3], A[0], B[0], B[3]]],
                 mat: mat, tone: tone, part: part, c: SIMD3((cx0 + cx1) / 2, (y0 + y1) / 2, cz))
}

/// 서류가방 크기 배율(2026-10-14 감독: 옛 가방 8.4 × 7 은 머리보다 작아 핸드백처럼 보인다 → 머리 폭보다 넓게)
let briefcaseK = 1.5
/// 서류가방(손잡이가 뼈 원점 — 아래로 매달린다): 가죽 몸통 · 뚜껑 띠 · 바닥 테 · 금빛 걸쇠 둘 · 쇠 손잡이 기둥 · 손잡이.
/// k = 1 이면 옛 크기(가로 8.4 · 높이 7). 두께는 조금만 늘린다(얇고 넓어야 서류가방으로 읽힌다)
func briefcase(_ k: Double) -> [Prism] {
    let M = Mat.self
    let hw = 4.2 * k, h = 7 * k * 0.95, hd = 1.6 * (1 + (k - 1) * 0.2), cx = hw - 1.9 * k
    return [prism(0, h, 0, hw, hd, 0, hw, hd, M.WOODD, 0.5, 13),                                              // 가죽 몸통
            prism(0, 1.9 * k, 0, hw + 0.08, hd + 0.08, 0, hw + 0.08, hd + 0.08, M.WOODD, 0.36, 13),          // 뚜껑 띠(이음선)
            prism(h - 0.7, h, 0, hw + 0.08, hd + 0.08, 0, hw + 0.08, hd + 0.08, M.MDARK, 0.4, 13),           // 바닥 테
            prism(1.4 * k, 2.6 * k, -cx, 0.55 * k, hd + 0.18, -cx, 0.55 * k, hd + 0.18, M.GOLD, 0.7, 13),     // 걸쇠
            prism(1.4 * k, 2.6 * k, cx, 0.55 * k, hd + 0.18, cx, 0.55 * k, hd + 0.18, M.GOLD, 0.7, 13),
            prism(-0.9, 0.1, -1.4 * k, 0.3, 0.45, -1.4 * k, 0.3, 0.45, M.STEEL, 0.6, 13),                     // 손잡이 기둥
            prism(-0.9, 0.1, 1.4 * k, 0.3, 0.45, 1.4 * k, 0.3, 0.45, M.STEEL, 0.6, 13),
            prism(-1.9, -0.8, 0, 1.4 * k + 0.3, 0.6, 0, 1.4 * k + 0.3, 0.6, M.MDARK, 0.5, 13)]               // 손잡이
}

/// JS `x || d`(재질 번호 — 0 이면 d)
@inline(__always) private func orMat(_ x: Double?, _ d: Double) -> Double { or(x, d) }

/// 웹 noirModel(o): 느와르 인물(코트 · 중절모/헌팅캡). o.suit 면 suitModel
public func noirModel(_ o: NoirOptions = NoirOptions()) -> Model3 {
    if o.suit { return suitModel(o) }
    let M = Mat.self
    let C = orMat(o.coat, M.COAT), T = orMat(o.trou, M.SUIT), S = M.SKIN, HAT = orMat(o.hatMat, M.HAIR), cap = o.cap
    var head = [prism(-3, 0, 0.5, 1.6, 1.6, 0.5, 1.8, 1.8, S, 0.5, 1),                                     // 목
                prism(-11.5, -2.6, 0.8, 3.9, 3.6, 1.1, 3.2, 3.0, S, 0.6, 1),                                // 머리 · 턱
                prism(-7.6, -5.4, 4.6, 0.9, 0.8, 5.4, 1.0, 0.8, S, 0.66, 1),                                // 코
                prism(-8.4, -7.3, 4.65, 0.35, 0.5, 4.65, 0.35, 0.5, M.INK, 0.5, 1, 1.7),
                prism(-8.4, -7.3, 4.65, 0.35, 0.5, 4.65, 0.35, 0.5, M.INK, 0.5, 1, -1.7),                  // 눈
                prism(-7.8, -5.2, -0.6, 1.0, 0.5, -0.6, 1.0, 0.5, S, 0.45, 1, 3.8),                         // 귀
                prism(-11, -5.5, -2.8, 1.2, 3.8, -3.0, 1.1, 3.7, M.HAIR, 0.32, 1)]                          // 뒷머리
    if cap {
        head += [prism(-13.5, -10.2, 0.2, 4.2, 4.0, 0.4, 4.4, 4.2, HAT, 0.42, 1), prism(-10.8, -10.0, 4.5, 2.2, 3.6, 5.2, 2.4, 3.6, HAT, 0.36, 1)]
    } else {
        head += [prism(-16, -11.6, 0.6, 3.5, 3.5, 0.6, 4.0, 4.0, HAT, 0.45, 1), prism(-12.2, -11.3, 0.6, 4.05, 4.05, 0.6, 4.1, 4.1, M.RED, 0.36, 1),
                 prism(-11.5, -10.7, 1.0, 6.4, 5.9, 1.0, 6.7, 6.2, HAT, 0.38, 1)]
    }
    return [
        "head": head,
        "torso": [prism(1, 17, 0, 4.1, 7.4, 0, 3.6, 5.6, C, 0.52, 2), prism(-1.5, 2.6, 0.2, 3.0, 4.0, 0.2, 3.9, 5.3, C, 0.64, 2),     // 몸통 · 세운 칼라
                  prism(1, 7.5, 4.0, 0.35, 1.7, 3.7, 0.35, 0.25, M.FRAME, 0.72, 2), prism(1.6, 9.5, 4.25, 0.3, 0.55, 3.85, 0.3, 0.55, M.RED, 0.42, 2), // 셔츠 · 넥타이
                  prism(14, 15.6, 0, 3.75, 5.75, 0, 3.75, 5.75, C, 0.3, 2)],                                                        // 벨트
        "skirtF": [prism(-0.5, 14, 0, 4.2, 3.0, 0.6, 5.3, 4.0, C, 0.5, 3, 2.6)], "skirtB": [prism(-0.5, 14, 0, 4.2, 3.0, 0.6, 5.3, 4.0, C, 0.46, 4, -2.6)],
        "uarmF": [prism(-1, 8, 0, 2.4, 2.3, 0, 2.0, 2.0, C, 0.46, 5)],
        "farmF": [prism(0, 7.6, 0, 2.0, 2.0, 0, 1.7, 1.7, C, 0.44, 6), prism(7.3, 10.2, 0.3, 1.7, 1.5, 0.4, 1.6, 1.4, S, 0.6, 6)],
        "uarmB": [prism(-1, 8, 0, 2.4, 2.3, 0, 2.0, 2.0, C, 0.4, 7)],
        "farmB": [prism(0, 7.6, 0, 2.0, 2.0, 0, 1.7, 1.7, C, 0.38, 8), prism(7.3, 10.2, 0.3, 1.7, 1.5, 0.4, 1.6, 1.4, S, 0.55, 8)],
        "thighF": [prism(-1, 11, 0, 2.9, 2.7, 0, 2.5, 2.4, T, 0.5, 9)], "shinF": [prism(0, 11, 0, 2.4, 2.3, 0, 2.1, 2.0, T, 0.48, 10)],
        "footF": [prism(-3, 0, 1.6, 4.0, 2.0, 1.8, 4.1, 2.0, M.MDARK, 0.55, 10)],
        "thighB": [prism(-1, 11, 0, 2.9, 2.7, 0, 2.5, 2.4, T, 0.44, 11)], "shinB": [prism(0, 11, 0, 2.4, 2.3, 0, 2.1, 2.0, T, 0.42, 12)],
        "footB": [prism(-3, 0, 1.6, 4.0, 2.0, 1.8, 4.1, 2.0, M.MDARK, 0.5, 12)],
        "bat": [prism(-1, 15, 0, 0.8, 0.8, 0, 1.35, 1.35, M.WOOD, 0.55, 13)],
        "paper": [prism(-1, 9, 0, 1.1, 1.1, 0, 1.2, 1.2, M.FRAME, 0.6, 13)],
        "umb": [prism(-5, -1, -1.6, 1.1, 0.9, -1.6, 1.1, 0.9, M.WOOD, 0.55, 13), prism(-6, -4, -3.0, 1.0, 0.8, -3.0, 1.0, 0.8, M.WOOD, 0.5, 13),   // 나무 J 손잡이
                prism(-1, 1, 0, 1.0, 1.0, 0, 1.0, 1.0, M.STEEL, 0.8, 13),                                                                      // 쇠 고리
                prism(1, 17, 0, 1.9, 1.9, 0, 1.0, 1.0, M.SUIT, 0.72, 13), prism(7, 8.5, 0, 2.0, 2.0, 0, 2.0, 2.0, M.BONE, 0.7, 13),           // 접힌 천 · 똑딱이 끈
                prism(17, 22, 0, 0.7, 0.7, 0, 0.55, 0.55, M.STEEL, 0.75, 13), prism(22, 24, 0, 0.6, 0.6, 0, 0.3, 0.3, M.STEEL, 0.95, 13)],    // 살대 끝 · 쇠 끝
        "case": briefcase(briefcaseK),
        "hammer": [prism(-3, 10, 0, 0.55, 0.4, 0, 0.6, 0.45, M.WOOD, 0.5, 13), prism(10, 13, 0, 1.0, 0.6, 0, 1.0, 0.6, M.STEEL, 0.7, 13),
                   prism(9.5, 10.5, 0, 3.6, 0.7, 0, 3.4, 0.7, M.STEEL, 0.75, 13), prism(10, 11.5, -3.2, 1.6, 0.5, -4.4, 1.2, 0.4, M.STEEL, 0.6, 13)], // 장도리
        "guitar": [prism(-2, 5, 0, 0.5, 0.35, 0, 0.5, 0.35, M.WOODD, 0.45, 13), prism(5, 9, 0, 2.0, 0.8, 0, 2.6, 0.9, M.WOOD, 0.55, 13),
                   prism(9, 13, 0, 2.6, 0.9, 0, 2.2, 0.8, M.WOOD, 0.5, 13), prism(-4, -2, 0, 0.7, 0.4, 0, 0.7, 0.4, M.MDARK, 0.4, 13)],
        "pan": [prism(-1, 6, 0, 0.45, 0.4, 0, 0.45, 0.4, M.MDARK, 0.5, 13), prism(6, 13, 0, 3.0, 0.45, 0, 3.0, 0.45, M.MDARK, 0.4, 13),
                prism(6.5, 12.5, 0, 2.4, 0.5, 0, 2.4, 0.5, M.STEEL, 0.55, 13)],                                                      // 프라이팬
        "cleaver": [prism(-1, 3, 0, 0.6, 0.5, 0, 0.6, 0.5, M.WOODD, 0.5, 13), prism(3, 11, 0, 2.0, 0.25, 0, 2.4, 0.25, M.STEEL, 0.8, 13)], // 정육 식칼
        "wrench": [prism(-1, 14, 0, 0.9, 0.7, 0, 1.0, 0.8, M.STEEL, 0.6, 13), prism(14, 17, 0, 2.4, 0.9, 0, 2.4, 0.9, M.STEEL, 0.65, 13)],
        "knife": [prism(-1, 2, 0, 0.7, 0.6, 0, 0.7, 0.6, M.MDARK, 0.5, 13), prism(2, 8, 0, 0.35, 0.5, 0, 0.2, 0.3, M.STEEL, 0.75, 13)],
    ]
}

/// 웹 suitModel(o): 양복 인물 — 재킷 자락은 엉덩이까지, 모자 대신 넘긴 머리(+수염) · 패거리는 헌팅캡 · 머리 모양 갈래
public func suitModel(_ o: NoirOptions) -> Model3 {
    let M = Mat.self
    let C = orMat(o.coat, M.SUIT), T = orMat(o.trou, M.SUIT), S = M.SKIN, H = M.HAIR
    var bo = o; bo.suit = false; bo.coat = C; bo.trou = T
    var m = noirModel(bo)
    var head = [prism(-3, 0, 0.5, 1.6, 1.6, 0.5, 1.8, 1.8, S, 0.5, 1), prism(-11.5, -2.6, 0.8, 3.9, 3.6, 1.1, 3.2, 3.0, S, 0.6, 1),
                prism(-7.6, -5.4, 4.6, 0.9, 0.8, 5.4, 1.0, 0.8, S, 0.66, 1),
                prism(-7.8, -5.2, -0.6, 1.0, 0.5, -0.6, 1.0, 0.5, S, 0.45, 1, 3.8)]
    if o.cap {
        head += [prism(-11, -5.5, -2.8, 1.2, 3.8, -3.0, 1.1, 3.7, H, 0.32, 1), prism(-13.5, -10.2, 0.2, 4.2, 4.0, 0.4, 4.4, 4.2, M.HAIR, 0.42, 1),
                 prism(-10.8, -10.0, 4.5, 2.2, 3.6, 5.2, 2.4, 3.6, M.HAIR, 0.36, 1)]
    } else {
        head += [prism(-12.8, -10.2, 0.1, 4.3, 3.95, 0.2, 4.1, 3.85, H, 0.3, 1),     // 넘긴 윗머리
                 prism(-11, -3.2, -2.7, 1.4, 3.85, -3.0, 1.2, 3.7, H, 0.27, 1),       // 목덜미까지 내려온 뒷머리
                 prism(-12.2, -9.6, 3.6, 1.0, 3.6, 3.2, 0.8, 3.4, H, 0.36, 1),        // 앞머리
                 prism(-5.6, -2.5, 2.6, 2.0, 3.2, 2.0, 1.7, 2.7, H, 0.33, 1)]         // 수염
    }
    // 머리 스타일(스팀펑크 포함): 톱햇+놋쇠 고글 · 모히칸 · 퐁파두르 · 고글 가죽모자 · 반다나 · 중절모 · 민머리
    if let hair = o.hair, !hair.isEmpty {
        head.removeSubrange(4...)
        func hb(_ m: Double, _ t: Double) -> Prism { prism(-12.6, -9.6, 0.1, 4.25, 3.95, 0.2, 4.15, 3.9, m, t, 1) }
        func lens(_ y0: Double, _ y1: Double, _ x: Double) -> [Prism] {
            [prism(y0, y1, x, 0.6, 1.0, x, 0.6, 1.0, M.GOLD, 0.7, 1, 1.35), prism(y0, y1, x, 0.6, 1.0, x, 0.6, 1.0, M.GOLD, 0.7, 1, -1.35),
             prism(y0 + 0.4, y1 - 0.4, x + 0.35, 0.3, 0.6, x + 0.35, 0.3, 0.6, M.GLASS, 0.7, 1, 1.35),
             prism(y0 + 0.4, y1 - 0.4, x + 0.35, 0.3, 0.6, x + 0.35, 0.3, 0.6, M.GLASS, 0.7, 1, -1.35)]
        }
        let hat = orMat(o.hatMat, M.MDARK)
        switch hair {
        case "tophat":
            head += [prism(-11, -5, -2.8, 1.2, 3.8, -3, 1.1, 3.7, H, 0.3, 1), prism(-21.5, -12.4, 0.3, 3.3, 3.3, 0.3, 3.4, 3.4, M.MDARK, 0.3, 1),
                     prism(-12.8, -11.9, 0.3, 5.4, 5.4, 0.3, 5.4, 5.4, M.MDARK, 0.24, 1),
                     prism(-13.9, -12.8, 0.3, 3.45, 3.45, 0.3, 3.45, 3.45, M.WOODD, 0.5, 1)] + lens(-14.6, -12.2, 3.5)
        case "mohawk":
            head += [prism(-12.4, -9.6, 0.1, 4.15, 3.9, 0.2, 4.1, 3.85, S, 0.48, 1), prism(-17, -10.6, -0.2, 4.6, 0.9, 0.1, 3.8, 1.0, M.NEONP, 0.5, 1)]
        case "pomp":
            head += [hb(H, 0.3), prism(-15.2, -11, 2.6, 2.6, 3.5, 1.2, 3.6, 3.8, H, 0.38, 1), prism(-11, -4, -2.8, 1.3, 3.8, -3, 1.1, 3.6, H, 0.28, 1)]
        case "goggle":
            head += [hb(M.WOODD, 0.42), prism(-11, -6, -2.9, 1.2, 3.9, -3.1, 1.1, 3.8, M.WOODD, 0.36, 1),
                     prism(-11.4, -10.2, 0.1, 4.3, 4.0, 0.1, 4.3, 4.0, M.MDARK, 0.4, 1)] + lens(-12.4, -9.8, 3.9)
        case "bandana":
            head += [hb(M.RED, 0.45), prism(-10.4, -7.2, -4.3, 0.8, 0.7, -5.4, 0.6, 0.6, M.RED, 0.4, 1), prism(-11, -5, -2.8, 1.2, 3.8, -3, 1.1, 3.7, H, 0.3, 1)]
        case "fedora":   // 중절모: 움푹한 크라운 · 띠 · 앞으로 내린 챙
            head += [prism(-11, -5, -2.8, 1.2, 3.8, -3, 1.1, 3.7, H, 0.3, 1), prism(-16.4, -11.4, 0.4, 3.4, 3.5, 0.5, 3.95, 4.05, hat, 0.44, 1),
                     prism(-16.6, -15.6, 0.4, 1.2, 2.2, 0.4, 1.2, 2.2, hat, 0.3, 1),
                     prism(-12.4, -11.3, 0.5, 4.0, 4.1, 0.5, 4.05, 4.15, orMat(o.bandMat, M.RED), 0.42, 1),
                     prism(-11.6, -10.8, 1.0, 6.4, 6.0, 1.3, 6.8, 6.3, hat, 0.34, 1)]
        case "bald":
            head += [prism(-12.2, -9.6, 0.1, 4.1, 3.85, 0.2, 4.05, 3.8, S, 0.52, 1), prism(-5.6, -2.5, 2.6, 2.0, 3.2, 2.0, 1.7, 2.7, H, 0.33, 1)]
        default: break   // 모르는 모양(crop 등): 얼굴 4조각만
        }
    }
    let fat = o.fat, tw: Double = fat ? 1.75 : 1                                                     // 배불뚝이: 몸통이 두툼하고 배가 튀어나온다
    // 웹: ...(fat ? { thighF … uarmB } : {}) 뒤에 같은 열쇠를 다시 써서 배불뚝이 팔다리는 덮인다 → 몸통만 달라진다(그대로 옮김)
    m["head"] = head
    if o.mandarin {
        m["torso"] = [prism(1, 17, 0, 4.1 * tw, 7.4 * tw * 0.9, fat ? 1.2 : 0, 3.6 * tw * 1.2, 5.6 * tw * 1.05, C, 0.42, 2),
                      prism(-1.2, 2.2, 0.3, 2.9, 3.4, 0.3, 3.1, 3.7, C, 0.6, 2)]
            + [4.0, 7, 10, 13].map { y in prism(y, y + 1, 4.05, 0.45, 0.9, 4.0, 0.45, 0.9, M.GOLD, 0.82, 2) }
            + [prism(2, 16, 4.0, 0.22, 0.25, 3.7, 0.22, 0.25, C, 0.2, 2)]
    } else {
        var t = [prism(1, 17, 0, 4.1 * tw, 7.4 * tw * 0.9, fat ? 1.2 : 0, 3.6 * tw * 1.2, 5.6 * tw * 1.05, C, 0.4, 2)]
        if fat { t += [prism(5, 18, 5.0, 5.2, 8.2, 7.4, 5.6, 8.8, C, 0.48, 2), prism(10.5, 15.5, 12.4, 1.0, 5.0, 12.8, 1.0, 4.6, M.FRAME, 0.64, 2)] }   // 불룩한 배 · 셔츠
        t += [prism(1, 9, 4.0, 0.35, 2.2, 3.75, 0.35, 0.3, M.FRAME, 0.76, 2)]                                                  // 흰 셔츠 V
        if !o.noTie {
            let tie = o.tie.flatMap { Mat.byName[$0] }
            t += [prism(1.4, 10.5, 4.25, 0.3, 0.6, 3.9, 0.3, 0.6, o.tie != nil ? (tie ?? .nan) : M.MDARK, o.tie != nil ? 0.5 : 0.3, 2)]   // 넥타이(기본 검정)
        }
        t += [prism(1, 9.5, 4.1, 0.3, 2.6, 3.8, 0.3, 0.9, C, 0.26, 2, 0),                                                     // 라펠
              prism(9.5, 17, 3.75, 0.25, 0.3, 3.65, 0.25, 0.3, C, 0.18, 2, 1.0), prism(13, 13.6, 3.0, 0.8, 0.3, 3.0, 0.8, 0.3, C, 0.2, 2, 4.4)]   // 앞여밈선 · 주머니 덮개
        m["torso"] = t
    }
    m["skirtF"] = [prism(-0.5, 6, 0, 4.2, 3.0, 0.3, 4.5, 3.4, C, 0.36, 3, 2.6)]
    m["skirtB"] = [prism(-0.5, 6, 0, 4.2, 3.0, 0.3, 4.5, 3.4, C, 0.32, 4, -2.6)]
    m["uarmF"] = [prism(-1, 8, 0, 2.4, 2.3, 0, 2.0, 2.0, C, 0.42, 5)]
    m["uarmB"] = [prism(-1, 8, 0, 2.4, 2.3, 0, 2.0, 2.0, C, 0.36, 7)]
    m["thighF"] = [prism(-1, 11, 0, 2.9, 2.7, 0, 2.5, 2.4, T, 0.4, 9), prism(0, 10.5, 2.75, 0.22, 0.22, 2.4, 0.22, 0.22, T, 0.62, 9)]   // 다린 바지 주름
    m["thighB"] = [prism(-1, 11, 0, 2.9, 2.7, 0, 2.5, 2.4, T, 0.34, 11), prism(0, 10.5, 2.75, 0.22, 0.22, 2.4, 0.22, 0.22, T, 0.55, 11)]
    m["shinF"] = [prism(0, 11, 0, 2.4, 2.3, 0, 2.1, 2.0, T, 0.38, 10), prism(0, 2.2, 2.35, 0.25, 1.6, 2.3, 0.25, 1.4, T, 0.18, 10)]    // 무릎 접힘
    m["shinB"] = [prism(0, 11, 0, 2.4, 2.3, 0, 2.1, 2.0, T, 0.32, 12), prism(0, 2.2, 2.35, 0.25, 1.6, 2.3, 0.25, 1.4, T, 0.16, 12)]
    m["footF"] = [prism(-3, 0, 1.6, 4.0, 2.0, 1.8, 4.1, 2.0, M.MDARK, 0.5, 10), prism(-3.1, -2.7, 4.2, 0.9, 0.9, 4.2, 0.9, 0.9, M.FRAME, 0.95, 10, 0.6)]  // 구두 광택
    m["footB"] = [prism(-3, 0, 1.6, 4.0, 2.0, 1.8, 4.1, 2.0, M.MDARK, 0.45, 12), prism(-3.1, -2.7, 4.2, 0.9, 0.9, 4.2, 0.9, 0.9, M.FRAME, 0.85, 12, -0.6)]
    m["farmF"] = [prism(0, 7.0, 0, 2.0, 2.0, 0, 1.7, 1.7, C, 0.4, 6), prism(0, 1.4, -1.9, 0.25, 1.5, -1.8, 0.25, 1.3, C, 0.16, 6),
                  prism(7.0, 7.8, 0, 1.75, 1.75, 0, 1.75, 1.75, M.FRAME, 0.74, 6), prism(7.6, 10.2, 0.3, 1.7, 1.5, 0.4, 1.6, 1.4, S, 0.6, 6)]
    m["farmB"] = [prism(0, 7.0, 0, 2.0, 2.0, 0, 1.7, 1.7, C, 0.34, 8), prism(0, 1.4, -1.9, 0.25, 1.5, -1.8, 0.25, 1.3, C, 0.14, 8),
                  prism(7.0, 7.8, 0, 1.75, 1.75, 0, 1.75, 1.75, M.FRAME, 0.7, 8), prism(7.6, 10.2, 0.3, 1.7, 1.5, 0.4, 1.6, 1.4, S, 0.55, 8)]
    return m
}
