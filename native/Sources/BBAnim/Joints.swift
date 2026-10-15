import Foundation

/// 관절 위치(골반 기준 지역 좌표: x 앞, y 아래). 몸 이동(r) · 공중(air) · 걷기 잔여(gres) 오프셋이 이미 더해져 있다(웹 j).
public struct Joints: Sendable, Equatable {
    public var hips: V2, neck: V2, head: V2
    public var legF: V2, legB: V2, kneeF: V2, kneeB: V2, footF: V2, footB: V2
    public var shF: V2, shB: V2, elbF: V2, elbB: V2, handF: V2, handB: V2
    /// 어깨 깊이(몸통 비틀기 반영)
    public var zF: Double, zB: Double
    /// 무기 뼈 이름(bat · knife · paper …)
    public var weapon: String?
}

/// 관절 풀이 입력 중 인물 상태에서 오는 것
public struct JointInput: Sendable {
    public var tilt: Double?
    public var airOv: Double?
    /// 보폭 걷기 중이면 그 잔여 거리(몸을 뒤로 당김)
    public var walkResidual: Double?
    /// 지금 키 포즈 이름(몸통 원화 tv 조회용 — 3D 리그는 views 가 없어 실제로는 안 씀)
    public var weaponSprite: String?
    public init(tilt: Double?, airOv: Double?, walkResidual: Double?, weaponSprite: String?) {
        self.tilt = tilt; self.airOv = airOv; self.walkResidual = walkResidual; self.weaponSprite = weaponSprite
    }
}

/// 웹 무기 스프라이트 → 3D 무기 뼈
let weaponBone: [String: String] = ["it_bat": "bat", "it_knife": "knife", "w_knife": "knife", "w_paper": "paper", "w_umb": "umb", "w_case": "case",
                                    "w_wrench": "wrench", "w_guitar": "guitar", "w_hammer": "hammer", "w_pan": "pan", "w_cleaver": "cleaver"]

/// 웹 drawChar0 가운데(3D 리그): 자세 P → 관절. tq(몸통 기울기)도 돌려준다(뼈 만들 때 쓴다)
public func solveJoints(_ P: Pose, rig R: RigDims, input c: JointInput) -> (Joints, tq: Double) {
    let sc = or(R.sc, 1)
    let tq = or(P.t, 0) * or(R.leanK, 1) + or(c.tilt, 0)   // 3D 리그는 몸통 각도를 끊지 않는다
    let rr = jsRound(raw(P.r) * sc)
    let air = jsRound((or(P.air, 0) + or(c.airOv, 0)) * sc)
    let gr = c.walkResidual.map { jsRound(or($0, 0)) } ?? 0
    func tor(_ p: V2) -> V2 { RI(rotV(p, -tq)) }   // 몸을 숙이면 골반 위 관절들이 함께 돈다
    let pb = P.b ?? V2(.nan, .nan), ph = P.h ?? V2(.nan, .nan)
    var hips = V2(jsRound(pb.x * sc), R.hip + jsRound(pb.y * sc))

    // 다리 각도 입력(FK): 0° 몸 앞 · −90° 아래 · 무릎은 허벅지 기준 굽힘
    var legFK: (F: (K: V2, F: V2), B: (K: V2, F: V2))?
    if P.legFK == true {
        let T1 = or(R.thigh, 6), T2 = or(R.shin, 7), dg = Double.pi / 180
        let csF = cos((P.sprF ?? P.spr ?? 0) * dg), csB = cos((P.sprB ?? P.spr ?? 0) * dg)
        func leg(_ th: Double, _ kn: Double, _ k: Double = 1) -> (K: V2, F: V2) {
            let a = th * dg, b = (th + kn) * dg, K = V2(T1 * k * cos(a), -T1 * k * sin(a))
            return (K, V2(K.x + T2 * k * cos(b), K.y - T2 * k * sin(b)))
        }
        // strL(차는 다리 늘이기)은 각도 값 자세에서도 F 다리에 — 웹 각도 값 자세엔 strL 이 없다(네이티브 무릎 올려치기: 짧은 다리로도 무릎이 몸통 밖으로 나오게)
        let L = (F: leg(raw(P.lFT), raw(P.lFK), or(P.strL, 1)), B: leg(raw(P.lBT), raw(P.lBK)))
        legFK = L
        let drop = max(L.F.F.y * csF, L.B.F.y * csB)
        hips = V2(jsRound(pb.x * sc), -jsRound(P.legH ?? drop))   // legH: 골반 높이 직접 지정
    }
    var shF = hips + tor(R.shF), shB = hips + tor(R.shB)
    let legF = hips + R.legF, legB = hips + R.legB
    let headBase = hips + tor(R.head), head = headBase + RI(V2(ph.x * sc, ph.y * sc))
    if truthy(P.ty) { let sx = sin(P.ty!) * 6.6; shF.x += sx; shB.x -= sx }   // 비틀면 가까운 어깨가 앞으로

    // 팔: FK(걷기 · 블렌드) 또는 IK
    func fkArm(_ S: V2, _ u: Double, _ l: Double) -> Limb {
        let tu = u * .pi / 8, tl = l * .pi / 8, K = V2(S.x + R.upper * sin(tu), S.y + R.upper * cos(tu))
        return Limb(K: K, F: V2(K.x + R.fore * sin(tl), K.y + R.fore * cos(tl)), aT: u, aS: l)
    }
    let armF: Limb, armB: Limb
    if P.armFK == true { armF = fkArm(shF, raw(P.uF), raw(P.lF)); armB = fkArm(shB, raw(P.uB), raw(P.lB)) }
    else {
        armF = solveArm(shF, raw(P.aF), P.eF, R.upper, R.fore * or(P.strF, 1), up: P.upF == true)
        armB = solveArm(shB, raw(P.aB), P.eB, R.upper, R.fore * or(P.strB, 1), up: P.upB == true)
    }

    // 다리: 발 목표는 바닥 기준 → 몸을 낮추면 무릎이 굽는다
    let L1 = or(R.thigh, 6), L2 = or(R.shin, 7), LL = L1 + L2
    func tgt(_ fp: V2?, _ base: V2) -> V2 { V2(base.x + (fp?.x ?? 0) * LL, min(0, (fp?.y ?? 0) * LL)) }
    let sprKF = 1 / cos((P.sprF ?? P.spr ?? 0) * .pi / 180), sprKB = 1 / cos((P.sprB ?? P.spr ?? 0) * .pi / 180)
    func tgtS(_ fp: V2?, _ base: V2, _ lg: V2, _ k: Double) -> V2 { let T = tgt(fp, base); return k == 1 ? T : V2(T.x, lg.y + (T.y - lg.y) * k) }
    let kL = or(P.strL, 1)
    let ikF: (K: V2, F: V2), ikB: (K: V2, F: V2)
    if let L = legFK { ikF = (legF + L.F.K, legF + L.F.F); ikB = (legB + L.B.K, legB + L.B.F) }
    else {
        let a = solveLeg(legF, tgtS(P.fF, R.legF, legF, sprKF), L1 * kL, L2 * kL); ikF = (a.K, a.F)
        let b = solveLeg(legB, tgtS(P.fB, R.legB, legB, sprKB), L1, L2); ikB = (b.K, b.F)
    }
    let off = V2(rr - gr, -air)
    let tyv = or(P.ty, 0)
    let j = Joints(hips: hips + off, neck: hips + tor(V2(0, R.head.y)) + off, head: head + off,
                   legF: legF + off, legB: legB + off, kneeF: ikF.K + off, kneeB: ikB.K + off, footF: ikF.F + off, footB: ikB.F + off,
                   shF: shF + off, shB: shB + off, elbF: armF.K + off, elbB: armB.K + off, handF: armF.F + off, handB: armB.F + off,
                   zF: 6.6 * cos(tyv), zB: -6.6 * cos(tyv), weapon: c.weaponSprite.flatMap { weaponBone[$0] })
    return (j, tq)
}
