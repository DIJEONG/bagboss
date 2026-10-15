import Foundation

/// 웹 gaitPose: 보폭 동기 걷기. 위상 gph(0~1)는 이동 거리로만 나아가고 12단으로 끊는다.
/// 남는 거리(gres)만큼 몸을 뒤로 당겨 디딘 발이 미끄러지지 않게 한다 — gres 는 상태로 돌려준다.
func gaitPose(gph: Double?, guardW: Double?, jw: Bool, base P0: Pose, rig R: RigDims, tables: AnimTables) -> (Pose, gres: Double) {
    let LL = or(R.thigh, 6) + or(R.shin, 7), A = 0.3 * LL, ph = jsMod(jsMod(or(gph, 0), 1) + 1, 1), N = 12.0
    let q = (ph * N).rounded(.down) / N, sc = or(R.sc, 1)
    func foot(_ u: Double) -> V2 {
        if u < 0.5 { return V2(A - 2 * A * (u / 0.5), 0) }
        let v = (u - 0.5) / 0.5, s = v * v * (3 - 2 * v)
        return V2(-A + 2 * A * s, -3.4 * sin(.pi * v))
    }
    let f1 = foot(q), f2 = foot(jsMod(q + 0.5, 1))
    let gres = (ph - q) * 4 * A
    // 팔: 다리와 반대 방향, 아래팔은 위팔보다 반 박자 늦게. 앞으로 갈수록 팔꿈치가 더 접힌다
    func arm(_ ph0: Double) -> (Double, Double) {
        let u = -1.25 * cos(2 * .pi * (q - ph0)), lag = -1.25 * cos(2 * .pi * (q - ph0 - 0.08))
        return (u, lag + 0.15 + 0.5 * max(0, (lag + 1.25) / 2.5))
    }
    let (uF, lF) = arm(0), (uB, lB) = arm(0.5)
    var G = P0
    G.r = 0; G.t = 0.3; G.ty = 0; G.h = .zero; G.b = V2(0, 1.1 * cos(4 * .pi * q) / sc)
    G.fF = V2((f1.x - R.legF.x + 0.5) / LL, f1.y / LL); G.fB = V2((f2.x - R.legB.x - 0.5) / LL, f2.y / LL)
    G.armFK = true; G.uF = uF; G.lF = lF; G.uB = uB; G.lB = lB
    G.tail = 0.55 * sin(2 * .pi * q); G.air = 0
    // 적이 가까우면 걸으면서 가드를 올린다
    let w = max(0, min(1, or(guardW, 0)))
    if w <= 0 { return (G, gres) }
    let S = toFK(tables.poses[live: jw ? "st0" : "m_idle0"] ?? Pose(), R), sw2 = 1 - w * 0.85
    func L(_ a: Double, _ b: Double) -> Double { a + (b - a) * w }
    var o = G
    o.t = L(raw(G.t), raw(S.t)); o.ty = L(0, or(S.ty, 0))
    o.h = V2(L(0, raw(S.h?.x)), L(0, raw(S.h?.y)))
    o.b = V2(0, raw(G.b?.y) * sw2 + L(0, raw(S.b?.y)))
    o.uF = L(uF * sw2, raw(S.uF)); o.lF = L(lF * sw2 + (1 - sw2) * uF * 0, raw(S.lF))
    o.uB = L(uB * sw2, raw(S.uB)); o.lB = L(lB * sw2, raw(S.lB))
    return (o, gres)
}

/// 웹 runPose: 전력 질주 — 접지 한가운데 가장 낮고 체공 때 가장 높다. 뒤꿈치가 먼저 올라간 뒤 무릎을 따라 앞으로, 팔꿈치 90° 크게
func runPose(gph: Double?, base P0: Pose, rig R: RigDims) -> Pose {
    let LL = or(R.thigh, 6) + or(R.shin, 7), A = 0.5 * LL, ph = jsMod(jsMod(or(gph, 0), 1) + 1, 1), N = 16.0
    let q = (ph * N).rounded(.down) / N, sc = or(R.sc, 1), ST = 0.30
    func sm(_ x0: Double) -> Double { let x = max(0, min(1, x0)); return x * x * (3 - 2 * x) }
    func foot(_ u: Double) -> V2 {
        if u < ST { let v = u / ST; return V2(A * 0.8 - A * 1.8 * v, 0) }
        let v = (u - ST) / (1 - ST), xs = sm((v - 0.22) / 0.68)
        return V2(-A + 1.8 * A * xs, -(LL * 0.72) * pow(sin(.pi * min(1, v / 0.88)), 0.5))
    }
    let f1 = foot(q), f2 = foot(jsMod(q + 0.5, 1)), bob = cos(4 * .pi * (q - ST / 2)), up = max(0, -bob)
    func arm(_ ph0: Double) -> (Double, Double) {
        let u = -2.5 * cos(2 * .pi * (q - ph0)), lag = -2.5 * cos(2 * .pi * (q - ph0 - 0.05))
        return (u, lag + 3.6)
    }
    let (uF, lF) = arm(0), (uB, lB) = arm(0.5)
    var o = P0
    o.r = 0; o.t = 1.0 + 0.3 * (1 - up); o.ty = 0; o.h = V2(1, 0); o.b = V2(0, (1.7 * bob + 0.3) / sc)
    o.fF = V2((f1.x - R.legF.x + 0.5) / LL, f1.y / LL); o.fB = V2((f2.x - R.legB.x - 0.5) / LL, f2.y / LL)
    o.armFK = true; o.uF = uF; o.lF = lF; o.uB = uB; o.lB = lB
    o.tail = 0.9 * sin(2 * .pi * q); o.air = 2.2 * up
    return o
}

/// 네이티브 질주(SimConfig.nativeMoves — 표에 nv_run0…5 가 있을 때만. 웹 표엔 없어 깃발 꺼짐은 runPose 그대로).
/// 16비트 벨트스크롤 달리기(감독 참고 그림 run_ref): 착지 → 눌림(지나감) → 체공 × 좌우. 키 6장을 보폭 위상 gph 로 고른다 —
/// gph 는 이동 거리로만 나아가므로(질주 한 바퀴 ≈ max(40, min(66, v·0.42))px → 95~157px/s 에서 0.42초 · 키 한 장 70ms) 발이 미끄러지지 않는다.
/// 키 사이는 끊지 않고 섞는다 — 발은 고르게(딛은 발이 바닥에 붙는다), 몸 · 팔은 키 근처에 머물게(16비트 키 프레임 느낌 · 튐 없음). mix < 1 이면 웹 runPose 와 섞는다(적 — 가볍게).
func nvRunPose(gph: Double?, base P0: Pose, rig R: RigDims, tables: AnimTables, mix: Double) -> Pose? {
    let N = 6
    guard let K0 = tables.poses[live: "nv_run0"] else { return nil }
    let ph = jsMod(jsMod(or(gph, 0), 1) + 1, 1), q = ph * Double(N)
    let i = Int(q) % N, uf = q - Double(Int(q)), u = uf * uf * (3 - 2 * uf)   // 발은 고르게(uf — 딛은 발이 몸 속도와 같이 뒤로), 몸 · 팔은 키에 머물듯(u)
    let A = i == 0 ? K0 : (tables.poses[live: "nv_run\(i)"] ?? K0), B = tables.poses[live: "nv_run\((i + 1) % N)"] ?? K0
    func L(_ a: Double?, _ b: Double?) -> Double { or(a, 0) + (or(b, 0) - or(a, 0)) * u }
    func L2(_ a: V2?, _ b: V2?) -> V2 { V2(L(a?.x, b?.x), L(a?.y, b?.y)) }
    func F2(_ a: V2?, _ b: V2?) -> V2 { V2(or(a?.x, 0) + (or(b?.x, 0) - or(a?.x, 0)) * uf, or(a?.y, 0) + (or(b?.y, 0) - or(a?.y, 0)) * uf) }
    let sc = or(R.sc, 1)
    var o = P0
    o.r = 0; o.t = L(A.t, B.t); o.ty = L(A.ty, B.ty); o.h = L2(A.h, B.h)
    let bb = L2(A.b, B.b); o.b = V2(bb.x, bb.y / sc)
    o.fF = F2(A.fF, B.fF); o.fB = F2(A.fB, B.fB)
    o.armFK = true; o.uF = L(A.uF, B.uF); o.lF = L(A.lF, B.lF); o.uB = L(A.uB, B.uB); o.lB = L(A.lB, B.lB)
    o.tail = 0.9 * sin(2 * .pi * ph); o.air = L(A.air, B.air)
    o.legFK = nil; o.roll = nil; o.spin = nil
    if mix >= 1 { return o }
    let W = runPose(gph: gph, base: P0, rig: R)
    func M(_ a: Double?, _ b: Double?) -> Double { or(a, 0) + (or(b, 0) - or(a, 0)) * mix }
    func M2(_ a: V2?, _ b: V2?) -> V2 { V2(M(a?.x, b?.x), M(a?.y, b?.y)) }
    var m = W
    m.t = M(W.t, o.t); m.ty = M(W.ty, o.ty); m.h = M2(W.h, o.h); m.b = M2(W.b, o.b); m.fF = M2(W.fF, o.fF); m.fB = M2(W.fB, o.fB)
    m.uF = M(W.uF, o.uF); m.lF = M(W.lF, o.lF); m.uB = M(W.uB, o.uB); m.lB = M(W.lB, o.lB); m.air = M(W.air, o.air)
    return m
}
