import Foundation

// 네이티브 강화: 2차 운동(웹에 없는 섬세한 동작).
// 원칙
//  · 보이는 층만 바꾼다 — 키 포즈 · 시퀀스 길이 · 큐 프레임(판정 타이밍)은 그대로. 시뮬레이션은 이 값을 모른다.
//  · 화면 프레임 dt 로 돈다(60/120Hz). 게임 20fps 키 포즈 리듬(리미티드 애니메이션)은 지키고, 그 사이의 '물리'만 매끄럽게 한다.
//  · 결과는 픽셀 격자로 래스터화되므로 진폭은 1~3px 수준 — 도트 질감을 해치지 않는 선.
//  · 같은 입력(dt 열)이면 같은 결과(난수 없음).

/// 강화 설정 — 기본은 꺼짐(웹과 같은 그림)
public struct MotionStyle: Sendable, Equatable {
    public var enabled = false
    /// 코트 자락: 다리 · 몸통 각도를 늦게 따라오며 출렁이고, 이동 속도만큼 뒤로 끌린다
    public var coat = true
    public var coatStiffness = 140.0, coatDamping = 11.0, coatDrag = 0.006, coatLimit = 0.7
    /// 머리 추종: 빠른 동작 · 피격 때 머리가 반 박자 늦게 따라온다(무게감)
    public var headLag = true
    public var headStiffness = 260.0, headDamping = 20.0, headLimit = 1.6
    /// 호흡: 대기 자세에서 상체가 미세하게 오르내린다
    public var breathing = true
    public var breathPeriod = 3.4, breathAmp = 0.7
    /// 충격 찌그러짐: 착지 · 피격 순간 상체가 눌렸다 튀어 오른다
    public var impact = true
    public var impactStiffness = 420.0, impactDamping = 16.0, landKick = 2.6, hitKick = 1.8, impactLimit = 0.16
    /// 목: 머리 밑 ↔ 몸통 윗면을 잇는 조각(웹 모델엔 목이 없다 — 머리 오프셋이 크면 머리가 떠 보인다 · Neck.swift)
    public var neck = true
    /// 목 길이 부드러운 한계(px · 0 = 끔): 넘는 만큼 neckGive 배만 남긴다 — 젖히기 · 피격 극단 포즈의 '늘어난 목' 줄이기
    public var neckMax = 2.5, neckGive = 0.2
    /// 피격 반응 다양화(HitReact.swift): 맞은 자리 · 방향 · 세기 · 몸무게로 고른 변형을 반응 자세에 얹는다.
    /// 변형은 연출 감독이 깃발 켜짐(HUDCatalog.native)일 때만 건다 — 걸리지 않으면 자세는 그대로다
    public var hitReact = true

    public init(enabled: Bool = false) { self.enabled = enabled }
    public static let off = MotionStyle()
    public static let on = MotionStyle(enabled: true)
}

/// 감쇠 스프링 하나(반암시적 오일러 — 큰 dt 에서도 터지지 않게 쪼개 돈다)
struct Spring: Sendable, Equatable {
    var x = 0.0, v = 0.0
    mutating func step(target: Double, k: Double, c: Double, dt: Double) {
        let n = max(1, Int((dt / (1.0 / 240)).rounded(.up))), h = dt / Double(n)
        for _ in 0..<n { v += (k * (target - x) - c * v) * h; x += v * h }
    }
}

/// 인물 한 명의 2차 운동 상태
public struct SecondaryMotion: Sendable, Equatable {
    var skirtF = Spring(), skirtB = Spring()
    var headX = Spring(), headY = Spring()
    var squash = Spring()
    var lastHipsWorldX: Double?, lastAir = 0.0, lastAnim = ""
    var initialized = false
    public init() {}

    /// 뼈(웹 그대로 만든 것)에 2차 운동을 얹는다.
    /// - hipsWorldX: 화면에서 골반 x(이동 속도 계산용) · facing: 바라보는 방향(+1/-1) · air: 지금 떠 있는 높이(px)
    public mutating func apply(_ sk: inout Skeleton, style: MotionStyle, anim: String, pose: Pose, hipsWorldX: Double, facing: Double,
                               dt: Double, time: Double, reacts: Set<String>) {
        guard style.enabled, dt > 0 else { return }
        let dt = min(dt, 1.0 / 20)
        guard let tIdx = sk.bones.firstIndex(where: { $0.name == "torso" }) else { return }
        let hipsY = sk.bones.first { $0.name == "skirtF" }?.bone.y ?? sk.bones[tIdx].bone.y
        let vx = lastHipsWorldX.map { (hipsWorldX - $0) / dt } ?? 0
        let air = or(pose.air, 0)
        defer { lastHipsWorldX = hipsWorldX; lastAir = air; lastAnim = anim; initialized = true }

        // 충격: 착지(높이가 갑자기 0 으로) · 피격 동작에 들어선 순간
        if style.impact && initialized {
            if lastAir > 3 && air < 0.5 { squash.v += style.landKick }
            if anim != lastAnim && reacts.contains(anim) { squash.v += style.hitKick }
        }
        squash.step(target: 0, k: style.impactStiffness, c: style.impactDamping, dt: dt)
        let s = max(-style.impactLimit, min(style.impactLimit, squash.x))

        // 코트 자락: 목표 각도(웹 값) + 이동 끌림 → 스프링이 늦게 따라온다
        func coat(_ name: String, _ sp: inout Spring) {
            guard style.coat, let i = sk.bones.firstIndex(where: { $0.name == name }) else { return }
            let target = sk.bones[i].bone.th + max(-style.coatLimit, min(style.coatLimit, facing * vx * style.coatDrag))
            if !initialized { sp.x = target; sp.v = 0 }
            sp.step(target: target, k: style.coatStiffness, c: style.coatDamping, dt: dt)
            sk.bones[i].bone.th = target + max(-style.coatLimit, min(style.coatLimit, sp.x - target))
        }
        coat("skirtF", &skirtF); coat("skirtB", &skirtB)

        // 머리: 몸이 확 움직이면 머리 위치가 잠깐 남는다(목 길이 안에서)
        var headDX = 0.0, headDY = 0.0
        if style.headLag, let hb = sk["head"] {
            let wx = hipsWorldX + facing * (hb.x - sk.bones[tIdx].bone.x), wy = hb.y - air
            if !initialized { headX.x = wx; headY.x = wy }
            headX.step(target: wx, k: style.headStiffness, c: style.headDamping, dt: dt)
            headY.step(target: wy, k: style.headStiffness, c: style.headDamping, dt: dt)
            headDX = facing * max(-style.headLimit, min(style.headLimit, headX.x - wx))
            headDY = max(-style.headLimit, min(style.headLimit, headY.x - wy))
        }

        // 호흡: 대기 · 휴식 자세에서만
        let calm = ["idle", "rest_sit", "rest_lean", "pass", "busk"].contains(anim)
        let breath = style.breathing && calm ? style.breathAmp * 0.5 * (1 - cos(2 * .pi * time / style.breathPeriod)) : 0

        // 상체(골반 위) 뼈에 적용: 눌림은 골반 높이를 축으로 세로 압축, 호흡은 위로 살짝
        let upper: Set<String> = ["torso", "head", "uarmF", "farmF", "uarmB", "farmB"]
        for i in sk.bones.indices {
            let n = sk.bones[i].name
            let isUpper = upper.contains(n) || !["skirtF", "skirtB", "thighF", "shinF", "thighB", "shinB", "footF", "footB"].contains(n)
            guard isUpper else { continue }
            var b = sk.bones[i].bone
            if s != 0 { b.y = hipsY + (b.y - hipsY) * (1 - s); if n == "torso" { b.sy = or(b.sy, 1) * (1 - s * 0.6) } }
            b.y -= breath
            if n == "head" { b.x += headDX; b.y += headDY }
            sk.bones[i].bone = b
        }
    }
}
