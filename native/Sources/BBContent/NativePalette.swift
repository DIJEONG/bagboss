import Foundation

// 네이티브 전용 재질 램프(docs/10 눈 승강장). 웹 팔레트(생성물 palettes.rgba)는 재질 56~79 가 비어 있다(검은 칸 — 어떤 스프라이트도 쓰지 않는다).
// 렌더러가 팔레트를 올릴 때 그 빈 줄에만 이 램프를 써 넣는다 → 기존 재질 · 웹 대조 픽셀은 한 칸도 바뀌지 않는다.
// 램프 6단(어둠 → 밝음) · 팔레트 3벌 모두 같은 값.

public enum NativePalette {
    /// 재질 번호
    public static let SNOW = 56, NITE = 57, HAZE = 58, GIRD = 59, LINE7 = 60, SODIUM = 61, BRICKN = 62, TEAL = 63
    /// 눈 바닥 전용(촘촘한 램프 · 셰이더가 순한 디더로 자른다 — 띠 경계에서만 좁게 섞인다)
    public static let SNOWF = 64
    /// 가로등 빛 웅덩이 속 눈 바닥(따뜻한 나트륨빛이 밴 램프 — SNOWF 와 같은 순한 디더)
    public static let SNOWW = 65
    /// 타격 열기(docs/11 §4 — 무거운 타격 자리의 달아오름 · 불티): 검붉음 → 주황 → 노란 흰빛
    public static let HEAT = 66
    /// 해변 도장(docs/12): 마른 모래 · 젖은 모래(바닥 전용 — SNOWF 처럼 순한 디더) · 오후 바다 · 노을 바다 · 오후 하늘 · 노을 하늘 · 거품 · 해 · 칠한 나무 · 바닷풀
    public static let SAND = 67, SANDW = 68, SEA = 69, SEAD = 70, SKYA = 71, SKYD = 72, FOAM = 73, SUN = 74, WOODP = 75, DUNE = 76
    /// 해변: 모래 위로 밀려온 얇은 물(젖은 바닥 반사 재질 — 짙게 두고 비친 하늘이 색을 낸다)
    public static let SHEET = 77
    /// 램프(재질 번호 → 6단 RGB)
    public static let ramps: [(Int, [UInt32])] = [
        (SNOW, [0x1A2546, 0x2C3E6C, 0x4E6AA0, 0x88A3CF, 0xC4D6EE, 0xF3F8FF]),     // 눈: 푸른 그늘 → 흰 빛
        (NITE, [0x04071A, 0x09102E, 0x101B45, 0x18295C, 0x223B76, 0x334F8E]),     // 밤하늘: 짙은 남색
        (HAZE, [0x1B2848, 0x293A60, 0x3C517C, 0x566B94, 0x7586AB, 0x9DADC8]),     // 먼 도시 안개: 옅고 덜 맑은 파랑
        (GIRD, [0x05080B, 0x0B1216, 0x131C21, 0x1D292D, 0x2C3B3C, 0x435450]),     // 고가 철골: 검푸른 초록
        (LINE7, [0x25082A, 0x481050, 0x781E84, 0xAD3BB2, 0xD56ED4, 0xF3C1EE]),    // 7호선 보라
        (SODIUM, [0x3B1506, 0x782C08, 0xB85410, 0xEE8A22, 0xFFC055, 0xFFF0B8]),   // 나트륨 · 텅스텐 등
        (BRICKN, [0x120A10, 0x21121A, 0x361C23, 0x4D2D2C, 0x684237, 0x885D46]),   // 밤 벽돌
        (TEAL, [0x0A1830, 0x112C4A, 0x1C4766, 0x2C6683, 0x4C8BA6, 0x86BDCF]),     // 지평선 청록 빛무리
        (SNOWF, [0x1D2A52, 0x2C3F72, 0x3F5890, 0x5B77AE, 0x95A6CF, 0xDCE2F0]),    // 눈 바닥: 앞 모서리 그늘 → 차가운 윗면 → 빛 웅덩이(단 사이를 좁게)
        (SNOWW, [0x2C2B50, 0x4A4068, 0x7A6378, 0xAA8C88, 0xD6B396, 0xF6DFBC]),    // 웅덩이 눈: 보랏빛 그늘 → 크림빛 윗면
        (HEAT, [0x2A0604, 0x6A1006, 0xB0260A, 0xE8501A, 0xFF9238, 0xFFD890]),     // 타격 열기: 검붉음 → 주황 → 노란 흰빛
        (SAND, [0x4A3428, 0x7A5A40, 0xA88258, 0xCDA673, 0xE6C892, 0xF8E6BC]),     // 마른 모래: 그늘 갈색 → 따뜻한 베이지 → 햇빛 크림(단 사이를 좁게)
        (SANDW, [0x261C1E, 0x3E3030, 0x5A4840, 0x7A6452, 0x9C8468, 0xC6B08E]),    // 젖은 모래: 짙은 회갈색(물 먹은 모래 — 하늘이 비친다)
        (SEA, [0x0A1E3A, 0x123A5E, 0x1C5C82, 0x2E86A6, 0x5CB4C8, 0xB4E6EA]),      // 오후 바다: 깊은 남청 → 청록 → 얕은 물빛
        (SEAD, [0x1A1430, 0x33224A, 0x5A3460, 0x8E4C68, 0xD07A66, 0xFFC27A]),     // 노을 바다: 보랏빛 그늘 → 장밋빛 → 금빛 반사
        (SKYA, [0x2A5C9A, 0x3C78B8, 0x5A94CE, 0x82B2DE, 0xB2D2EC, 0xE4F0F8]),     // 오후 하늘: 짙은 하늘색(위) → 수평선 옅은 빛
        (SKYD, [0x2A1E48, 0x5A3062, 0x9A4468, 0xE0685E, 0xF7A05A, 0xFFD88C]),     // 노을 하늘: 보라 → 자홍 → 주황 → 금빛
        (FOAM, [0x3C5470, 0x6A86A0, 0x9AB2C4, 0xC6D6E0, 0xE6EEF2, 0xFFFFFF]),     // 거품 · 물보라: 푸른 그늘 → 흰 빛
        (SUN, [0x8A3A10, 0xD0661A, 0xF6A036, 0xFFD268, 0xFFF0B0, 0xFFFFF0]),      // 해 · 반짝임: 주황 → 노랑 → 흰빛
        (WOODP, [0x2A2A30, 0x4A4A50, 0x78767A, 0xA8A4A2, 0xD2CEC8, 0xF2EEE6]),    // 흰 칠 나무(감시탑 · 울타리 — 바랜 흰색)
        (SHEET, [0x10202E, 0x1C3446, 0x2C4C60, 0x46687A, 0x6C8C98, 0xA8C4C8]),    // 밀려온 물: 짙은 청회색(반사가 하늘빛을 더한다)
        (DUNE, [0x1E2412, 0x34401C, 0x56602A, 0x7E8240, 0xA8A462, 0xD2C88C]),     // 바닷풀 · 해초: 짙은 올리브 → 밀짚빛
    ]

    /// 풀린 팔레트 바이트(행 = 팔레트 · 재질, 열 = 단)에 빈 줄만 채운다
    public static func apply(to p: UnsafeMutableRawPointer, steps: Int, materials: Int, palettes: Int) {
        let b = p.assumingMemoryBound(to: UInt8.self)
        for pal in 0..<palettes {
            for (m, ramp) in ramps where m < materials {
                let row = pal * materials + m
                var empty = true
                for s in 0..<steps { let o = (row * steps + s) * 4; if b[o] != 0 || b[o + 1] != 0 || b[o + 2] != 0 { empty = false } }
                guard empty else { continue }   // 웹 팔레트가 언젠가 이 줄을 쓰면 건드리지 않는다
                for s in 0..<min(steps, ramp.count) {
                    let o = (row * steps + s) * 4, c = ramp[s]
                    b[o] = UInt8((c >> 16) & 255); b[o + 1] = UInt8((c >> 8) & 255); b[o + 2] = UInt8(c & 255); b[o + 3] = 255
                }
            }
        }
    }
}
