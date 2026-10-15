import Foundation

/// 인물 한 명의 애니메이션 상태 중 '보이는 자세'를 정하는 데 쓰는 것(웹 액터 c 의 해당 필드).
/// 시퀀스 진행(pose · prev · k · phaseN)은 시뮬레이션이 돌리고, 블렌드 · 추종 값은 그리기마다 갱신된다.
public struct ActorPose: Sendable, Equatable {
    public var anim: String
    public var pose: String
    public var prev: String?
    public var k: Int = 0
    public var phaseN: Int = 1
    /// 보폭 위상(0~1 반복) · 걸으며 가드 올리기(0~1) · 대시 끝 시각
    public var gph: Double?, guardW: Double?, runU: Double?
    public var legRun = false
    /// 저글(날아가며 구르기)
    public var jug: (roll: Double?, kick: Double?)? {
        get { hasJug ? (jugRoll, jugKick) : nil }
        set { hasJug = newValue != nil; jugRoll = newValue?.roll; jugKick = newValue?.kick }
    }
    public var hasJug = false, jugRoll: Double?, jugKick: Double?
    public var airOv: Double?, tilt: Double?
    // 그리기마다 갱신되는 값(웹 _vr · _va · _vt · _an · _rgo · bFrom · bT0 · bDur · lastP · gres)
    public var vr: Double?, va: Double?, vt: Double?
    public var lastAnim: String?, rgo: Bool?
    public var blendFrom: Pose?, blendT0: Double?, blendDur: Double?
    public var lastPose: Pose?
    public var gres: Double?
    /// 스킨 미리보기 · 자세 편집기 회전(바퀴 — 웹 skinPv.view/360 + skinPv.spin). 주인공 · 스튜디오에서만 값이 있다(평소 nil → 웹 그대로)
    public var viewSpin: Double?

    public init(anim: String, pose: String) { self.anim = anim; self.pose = pose }

    public static func == (a: ActorPose, b: ActorPose) -> Bool {
        a.anim == b.anim && a.pose == b.pose && a.prev == b.prev && a.k == b.k && a.phaseN == b.phaseN && a.gph == b.gph &&
        a.vr == b.vr && a.va == b.va && a.lastAnim == b.lastAnim && a.rgo == b.rgo && a.blendFrom == b.blendFrom &&
        a.blendT0 == b.blendT0 && a.blendDur == b.blendDur && a.lastPose == b.lastPose && a.gres == b.gres
    }
}

/// 인물 정의 중 자세 계산에 쓰는 것
public struct ActorTraits: Sendable, Equatable {
    public var gait: Bool
    public var jw: Bool
    public var isHero: Bool
    public init(gait: Bool, jw: Bool, isHero: Bool) { self.gait = gait; self.jw = jw; self.isHero = isHero }
}

public struct EvaluatedPose: Sendable {
    public var pose: Pose
    /// 보폭 걷기 중인가(관절 풀이에서 gres 만큼 몸을 당긴다)
    public var walkGait: Bool
}

/// 웹 curPose: 키 포즈로 들어가는 구간(앞 60%)만 이징으로 채우고, 나머지는 키 포즈에 머문다
func currentPose(_ s: ActorPose, rig: RigDims, tables: AnimTables) -> Pose {
    let cur = tables.poses[live: s.pose] ?? Pose()
    guard cur.snap != true, let prev = s.prev, !prev.isEmpty, prev != s.pose else { return cur }
    let T = max(1, Int((Double(s.phaseN) * 0.6).rounded(.up))), u = min(1, Double(s.k + 1) / Double(T))
    if u >= 1 { return cur }
    let A = tables.poses[live: prev] ?? Pose(), e = 1 - (1 - u) * (1 - u)
    if A.armFK == true || A.legFK == true || cur.armFK == true || cur.legFK == true { return blendPose(A, cur, e, rig) }
    return lerpPose(A, cur, e)
}

/// 웹 drawChar0 앞부분(3D 리그): 보간 → 보행 → 저글 구르기 → 주인공 추종 → 질주 다리 → 전환 블렌드.
/// `s` 의 그리기 상태(블렌드 · 추종 · gres)를 갱신한다. time = 게임 시간(초).
public func evaluatePose(_ s: inout ActorPose, traits d: ActorTraits, rig R: RigDims, time: Double, tables: AnimTables) -> EvaluatedPose {
    let rgo = d.gait && s.anim == "walk" && (s.runU.map { $0 > time } ?? false)
    let walkG = d.gait && s.anim == "walk" && !rgo
    let runG = d.gait && (s.anim == "run" || rgo)
    var P: Pose
    if runG {   // 네이티브 표(nv_run 키)가 있으면 키 질주 — 주인공은 그대로, 적은 웹 질주와 반씩(가볍게)
        let base = currentPose(s, rig: R, tables: tables)
        P = nvRunPose(gph: s.gph, base: base, rig: R, tables: tables, mix: d.isHero ? 1 : 0.5) ?? runPose(gph: s.gph, base: base, rig: R)
    }
    else if walkG { let (g, gres) = gaitPose(gph: s.gph, guardW: s.guardW, jw: d.jw, base: currentPose(s, rig: R, tables: tables), rig: R, tables: tables); P = g; s.gres = gres }
    else { P = currentPose(s, rig: R, tables: tables) }
    if s.hasJug, truthy(s.jugRoll) || truthy(s.jugKick) { P.roll = or(s.jugRoll, 0) + or(s.jugKick, 0) }   // 날아가며 뒤로 구른다
    if d.isHero {   // 주인공 회전 · 높이는 화면 프레임마다 따라간다(애니 칸 계단 없이)
        let dtv = min(0.1, max(0, time - (s.vt ?? time))); s.vt = time
        let tr = or(P.roll, 0), cr = s.vr ?? tr, dr = jsMod(jsMod(tr - cr, 1) + 1.5, 1) - 0.5
        let vr = abs(dr) < 0.001 ? tr : cr + dr * min(1, dtv * 24); s.vr = vr
        let ta = or(P.air, 0), ca = s.va ?? ta, va = ca + (ta - ca) * min(1, dtv * 26); s.va = va
        if abs(vr) > 0.0005 || va > 0.05 || truthy(P.roll) || truthy(P.air) { P.roll = vr; P.air = va }
    }
    if s.legRun && d.gait && !runG && !walkG {   // 필살기 진격: 상체는 공격 동작, 다리는 달린다
        let RP = runPose(gph: s.gph, base: P, rig: R)
        P.fF = RP.fF; P.fB = RP.fB; P.b = V2(raw(P.b?.x), raw(P.b?.y) * 0.5 + raw(RP.b?.y)); P.air = or(P.air, 0) + raw(RP.air)
    }
    if rgo != (s.rgo ?? false) && s.lastAnim == s.anim, let lp = s.lastPose { s.blendFrom = lp; s.blendT0 = time; s.blendDur = 0.08 }   // 걷기 ↔ 대시
    s.rgo = rgo
    if s.lastAnim != s.anim {   // 동작 이름이 바뀌면 직전 자세 스냅숏에서 섞어 들어간다
        let ms = s.lastAnim.map { blendMs(from: $0, to: s.anim, reacts: tables.reacts) } ?? 0
        s.blendFrom = ms > 0 ? s.lastPose : nil; s.blendT0 = time; s.blendDur = ms / 1000; s.lastAnim = s.anim
    }
    if let from = s.blendFrom {
        let u = (time - (s.blendT0 ?? time)) / max(0.001, s.blendDur ?? 0)
        if u >= 1 { s.blendFrom = nil } else { P = blendPose(from, P, u * u * (3 - 2 * u), R) }   // 천천히 출발해 천천히 도착
    }
    s.lastPose = P
    if let v = s.viewSpin, v != 0 { P.spin = or(P.spin, 0) + v }   // 웹: 블렌드 스냅숏(lastP) 뒤에 더한다 — 보기 회전은 섞이지 않는다
    return EvaluatedPose(pose: P, walkGait: walkG)
}
