import Foundation

// 야근 광선(nv_beam — SimConfig.nativeMoves · docs/07 §7-BM). 감독 참고 그림: 한 손 두 손가락을 관자놀이(안경테)에 대고 고개를 젖혀 외치며 눈에서 광선 · 다른 손은 허리 옆에서 주먹을 쥔다 · 다리는 넓게 버틴다.
// 칸: 손 올림(bm_set) → 모음(bm_charge — 고개 숙여 안경이 차오른다) → 발사(bm_fire 큐 — 고개가 젖혀지며 광선) → 유지(bm_hold — 반동을 버티며 밀린다) → 끊기(bm_end — 마지막 한 방) → 회복.
// 문법: 다리 · 팔 모두 각도 값(NativeKneePoses 와 같다 — 다리 0° 앞 · −90° 아래 / 팔 0 아래 · 4 앞 · 8 위 · 12 뒤, 22.5° 단위).
//   F 팔(뒷팔 · 화면 쪽) = 안경에 댄 손 · B 팔(앞팔) = 허리 옆 주먹 · F 다리 = 뒷다리(뒤로 길게 버팀) · B 다리 = 앞다리(굽혀 버팀).

extension NativeMoves {
    /// 각도 값 자세 — leg = (뒷 허벅지, 뒷 무릎, 앞 허벅지, 앞 무릎)(도) · arm = (뒷 위팔, 뒷 아래팔, 앞 위팔, 앞 아래팔)(22.5°)
    private static func BM(t: Double, ty: Double = 0, hn: Double? = nil, air: Double = 0, r: Double = 0,
                          leg: (Double, Double, Double, Double), arm: (Double, Double, Double, Double),
                          impact: Bool? = nil, snap: Bool? = nil) -> Pose {
        var p = Pose()
        p.r = r; p.b = V2(0, 0); p.h = V2(1, 1); p.t = t; p.ty = ty; p.hn = hn; p.air = air; p.w = 4
        p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.fF = V2(-0.5, 0); p.fB = V2(0.5, 0)   // 각도 값이 아닌 자세와 섞일 때의 대략값
        p.legFK = true; p.lFT = leg.0; p.lFK = leg.1; p.lBT = leg.2; p.lBK = leg.3
        p.armFK = true; p.uF = arm.0; p.lF = arm.1; p.uB = arm.2; p.lB = arm.3
        p.impact = impact; p.snap = snap
        return p
    }

    static let bmPoses: [String: Pose] = [
        // 1 손 올림: 뒷손 두 손가락을 안경테 옆으로 · 앞손은 허리 옆에서 주먹 · 몸을 화면 쪽으로 돌리며 살짝 숙인다
        "bm_set": BM(t: 0.6, ty: 0.35, hn: 14, r: 1, leg: (-112, -10, -70, -30), arm: (4.6, 10.6, 1.4, 3.2)),
        // 2 모음: 고개를 숙여 안경에 힘을 모은다(안경이 차오른다) · 주먹을 더 꽉 · 무릎을 조금 더 굽혀 버틸 준비
        "bm_charge": BM(t: 0.9, ty: 0.4, hn: 22, r: 1, leg: (-118, -14, -66, -42), arm: (4.4, 10.8, 0.8, 2.6)),
        // 3 발사(큐): 고개가 젖혀지며 외친다 · 가슴을 펴고 상체는 뒤로 · 뒷다리를 뒤로 길게 · 앞무릎 굽혀 버팀
        "bm_fire": BM(t: -0.6, ty: 0.45, hn: -12, r: 0, leg: (-130, 0, -58, -52), arm: (4.8, 10.8, 0.4, 2.2), impact: true, snap: true),
        // 4 유지: 반동을 버티며 더 낮게 · 상체 더 뒤로(광선을 밀어붙인다)
        "bm_hold": BM(t: -0.8, ty: 0.45, hn: -14, r: -1, leg: (-134, 0, -54, -60), arm: (4.8, 10.9, 0.3, 2.0)),
        // 5 끊기(마지막 한 방): 고개를 앞으로 꺾어 마지막을 쏟아낸다
        "bm_end": BM(t: -0.2, ty: 0.4, hn: 4, r: 0, leg: (-128, 0, -58, -50), arm: (4.8, 10.6, 0.6, 2.4), snap: true),
        // 6 회복: 손가락을 떼어 가드로 · 다리를 모은다
        "bm_rec": BM(t: 0.7, ty: 0.1, hn: 6, r: 2, leg: (-104, -16, -76, -22), arm: (4.2, 7.6, 4.4, 7.0)),
    ]

    /// 손 올림 2 · 모음 3 · 발사 1(큐 250ms) · 유지 7 · 끊기 3(bm_end 650ms — 마지막 한 방) · 회복 2 · 서기 2 = 20칸(1.0초)
    static let bmSequences: [String: [SeqStep]] = [
        "nv_beam": S([("bm_set", 100), ("bm_charge", 150), ("bm_fire", 50), ("bm_hold", 350), ("bm_end", 150), ("bm_rec", 100), ("c_over", 100)]),
    ]
    static let bmCues: [String: String] = ["nv_beam": "bm_fire"]
}
