import Foundation

/// 키 포즈 하나(웹 POSES 항목 · 13-rig-grammar). 필드가 '없음'인 것과 0 인 것이 다르게 쓰이므로 전부 옵셔널로 둔다.
/// 각도 단위: aF · aB · w · uF · lF · uB · lB 는 22.5°(π/8), spin · roll 은 바퀴(1 = 360°), spr* · l?? 는 도.
public struct Pose: Sendable, Equatable, Decodable {
    // 몸
    public var r: Double?            // 몸 앞뒤 이동
    public var b: V2?                // 골반 위치(앞, 아래)
    public var h: V2?                // 머리 위치 보정
    public var t: Double?            // 몸통 기울기
    public var ty: Double?           // 몸통 비틀기(라디안)
    public var air: Double?          // 떠오름(px)
    public var spin: Double?, roll: Double?
    public var hn: Double?, hy: Double?     // 고개(도 · 네이티브 자세 편집기 추가 — 웹 자세엔 없다): hn 숙임(+ 앞) · 젖힘(−) · hy 돌림(+ 화면 쪽)
    // 팔(IK): 방향 · 뻗음
    public var aF: Double?, aB: Double?, eF: Double?, eB: Double?
    public var strF: Double?, strB: Double?   // 아래팔 늘이기(과장)
    public var upF: Bool?, upB: Bool?         // 팔꿈치를 들어 수평 ㄱ자
    public var w: Double?                     // 무기 각도
    // 팔(FK)
    public var armFK: Bool?
    public var uF: Double?, lF: Double?, uB: Double?, lB: Double?
    // 다리(IK): 발 목표(다리 길이 단위)
    public var fF: V2?, fB: V2?
    public var strL: Double?                  // 차는 다리 늘이기
    public var spr: Double?, sprF: Double?, sprB: Double?   // 다리 벌리기(도)
    // 다리(FK)
    public var legFK: Bool?
    public var lFT: Double?, lFK: Double?, lBT: Double?, lBK: Double?
    public var legH: Double?
    // 연출 표시
    public var smear: String?, smearAt: String?
    public var tail: Double?
    public var snap: Bool?, impact: Bool?, charge: Bool?, frontB: Bool?
    public var tv: Double?

    public init() {}
}

// MARK: - 보간(웹 16-anim.js · 17-light-frame.js)

/// 웹 lerpA: 22.5° 단위 각도를 16 모듈러 최단 경로로
@inlinable func lerpA(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (jsMod(jsMod(b - a, 16) + 24, 16) - 8) * t }

/// 웹 lerpPose. 결과에는 아래 필드만 있다(웹 객체 리터럴의 키 집합) — blendPose 의 `{...b, ...m}` 이 이 집합을 덮어쓴다.
func lerpPose(_ A: Pose, _ B: Pose, _ u: Double) -> Pose {
    func L(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
    func L2(_ x: V2?, _ y: V2?) -> V2 { let a = x ?? V2(.nan, .nan), b = y ?? V2(.nan, .nan); return V2(L(a.x, b.x), L(a.y, b.y)) }
    var o = Pose()
    o.r = L(raw(A.r), raw(B.r)); o.b = L2(A.b, B.b); o.h = L2(A.h, B.h)
    o.t = L(or(A.t, 0), or(B.t, 0)); o.ty = L(or(A.ty, 0), or(B.ty, 0))
    o.strF = L(or(A.strF, 1), or(B.strF, 1)); o.strB = L(or(A.strB, 1), or(B.strB, 1))
    o.aF = lerpA(raw(A.aF), raw(B.aF), u); o.aB = lerpA(raw(A.aB), raw(B.aB), u); o.w = lerpA(raw(A.w), raw(B.w), u)
    o.eF = L(nn(A.eF, 1), nn(B.eF, 1)); o.eB = L(nn(A.eB, 1), nn(B.eB, 1))
    o.fF = L2(A.fF, B.fF); o.fB = L2(A.fB, B.fB)
    o.air = L(or(A.air, 0), or(B.air, 0)); o.smear = B.smear; o.charge = B.charge
    o.strL = L(or(A.strL, 1), or(B.strL, 1)); o.upF = B.upF; o.upB = B.upB; o.smearAt = B.smearAt
    o.spr = L(or(A.spr, 0), or(B.spr, 0))
    o.sprF = L(A.sprF ?? A.spr ?? 0, B.sprF ?? B.spr ?? 0); o.sprB = L(A.sprB ?? A.spr ?? 0, B.sprB ?? B.spr ?? 0)
    o.legH = B.legH
    // 각도 입력이 없는 자세는 기본 서기 다리 각도로 본다
    o.lFT = L(nn(A.lFT, -102.6), nn(B.lFT, -102.6)); o.lFK = L(nn(A.lFK, -31.9), nn(B.lFK, -31.9))
    o.lBT = L(nn(A.lBT, -53.1), nn(B.lBT, -53.1)); o.lBK = L(nn(A.lBK, -6.4), nn(B.lBK, -6.4))
    o.spin = or(A.spin, 0) + (jsMod(jsMod(or(B.spin, 0) - or(A.spin, 0), 1) + 1.5, 1) - 0.5) * u
    o.roll = or(A.roll, 0) + (jsMod(jsMod(or(B.roll, 0) - or(A.roll, 0), 1) + 1.5, 1) - 0.5) * u
    // 고개(네이티브): 둘 다 없으면 없음(웹 자세는 그대로)
    if A.hn != nil || B.hn != nil { o.hn = L(or(A.hn, 0), or(B.hn, 0)) }
    if A.hy != nil || B.hy != nil { o.hy = L(or(A.hy, 0), or(B.hy, 0)) }
    return o
}

/// `{...base, ...lerp}` — lerpPose 결과가 가진 키만 덮어쓴다(값이 없음이어도 덮는다)
func overlayLerp(_ base: Pose, _ m: Pose) -> Pose {
    var o = base
    o.r = m.r; o.b = m.b; o.h = m.h; o.t = m.t; o.ty = m.ty; o.strF = m.strF; o.strB = m.strB
    o.aF = m.aF; o.aB = m.aB; o.w = m.w; o.eF = m.eF; o.eB = m.eB; o.fF = m.fF; o.fB = m.fB
    o.air = m.air; o.smear = m.smear; o.charge = m.charge; o.strL = m.strL; o.upF = m.upF; o.upB = m.upB
    o.smearAt = m.smearAt; o.spr = m.spr; o.sprF = m.sprF; o.sprB = m.sprB; o.legH = m.legH
    o.lFT = m.lFT; o.lFK = m.lFK; o.lBT = m.lBT; o.lBK = m.lBK; o.spin = m.spin; o.roll = m.roll
    o.hn = m.hn; o.hy = m.hy
    return o
}

/// 웹 toFK: 팔 IK 자세를 위팔 · 아래팔 각도(FK)로 — IK 자세와 FK 자세(걷기)를 섞을 수 있게
func toFK(_ P: Pose, _ R: RigDims) -> Pose {
    if P.armFK == true { return P }
    func ang(_ A: V2, _ B: V2) -> Double { atan2(B.x - A.x, B.y - A.y) / (Double.pi / 8) }
    let fF = solveArm(.zero, raw(P.aF), P.eF, R.upper, R.fore * or(P.strF, 1), up: false)
    let fB = solveArm(.zero, raw(P.aB), P.eB, R.upper, R.fore * or(P.strB, 1), up: false)
    var o = P
    o.armFK = true
    o.uF = ang(.zero, fF.K); o.lF = ang(fF.K, fF.F); o.uB = ang(.zero, fB.K); o.lB = ang(fB.K, fB.F)
    return o
}

/// 웹 blendPose: 직전에 그린 자세에서 새 자세로 짧게 섞는다(팔은 FK 각도로)
func blendPose(_ A: Pose, _ B: Pose, _ u: Double, _ R: RigDims) -> Pose {
    let a = toFK(A, R), b = toFK(B, R)
    func L(_ x: Double, _ y: Double) -> Double { x + (y - x) * u }
    func la(_ x: Double, _ y: Double) -> Double { var d = y - x; while d > 8 { d -= 16 }; while d < -8 { d += 16 }; return x + d * u }
    var a2 = a; a2.b = a.b ?? .zero; a2.h = a.h ?? .zero
    let m = lerpPose(a2, b, u)
    var o = overlayLerp(b, m)
    o.armFK = true
    o.uF = la(raw(a.uF), raw(b.uF)); o.lF = la(raw(a.lF), raw(b.lF)); o.uB = la(raw(a.uB), raw(b.uB)); o.lB = la(raw(a.lB), raw(b.lB))
    o.tail = L(or(a.tail, 0), or(b.tail, 0)); o.impact = b.impact; o.smear = b.smear; o.smearAt = b.smearAt
    return o
}

/// 웹 BLEND_MS: 동작이 바뀔 때 섞는 시간(ms)
public func blendMs(from: String, to: String, reacts: Set<String>) -> Double {
    if reacts.contains(to) && to != "getup" && to != "getupP" && to != "stagger" { return 0 }
    if to == "duck" { return 45 }
    if from == "walk" && to == "idle" { return 300 }
    if from == "walk" { return 70 }
    if to == "walk" { return 150 }
    return 110
}
