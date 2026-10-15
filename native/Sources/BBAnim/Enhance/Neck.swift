import Foundation

// 네이티브 강화: 목(웹 모델에 없는 조각 — docs/07 7-X).
// 웹 리그엔 목 뼈가 없다: 머리 뼈는 목 관절(골반 + 몸통 17px)에서 앞으로 0.6 + 자세 머리 오프셋 h(화면 좌표 · 몸통 기울기와 따로)에 놓이고,
// 모델은 머리 밑에 3px 살색 토막(머리 지역 y −3…0)만 단다. 몸통 윗면은 목 관절 1px 아래 → 쉴 땐 맞붙지만,
// h 가 몸통 위쪽(젖히기 · 피격)이나 옆(숙이며 앞으로)으로 크면 토막과 몸통 사이가 비어 '머리가 떠' 보인다.
// 여기서는 매 프레임 머리 토막 안쪽 → 몸통 윗면 안쪽을 잇는 짧은 사각뿔대(살색 · 깃이 있는 옷은 아래를 깃 색)를 더한다.
//  · 모델(생성물)은 그대로 — 조각 치수는 모델의 목 토막 · 몸통 첫 조각에서 읽는다(네이티브 적 몸 크기 배율도 따라간다).
//  · 같은 그리기 경로(emitModel — 외곽선 · 빛 · 디더). 살 부분은 머리 부위 번호(1)라 머리와 사이 선이 없고, 깃은 몸통(2).
//  · 양 끝은 머리 토막 · 몸통 안에 묻혀 겹치는 곳은 가려진다(토막보다 가늘게 — 같은 면에 겹쳐 깜빡이지 않게).
//  · 머리가 몸통 안으로 들어간 자세(숙임)에선 목이 짧아져 몸통 속에 숨는다.

/// 목 조각 치수(모델마다 한 번)
public struct NeckSpec: Sendable, Equatable {
    /// 머리 지역: 목 위 끝(토막 안쪽) · 반폭(앞뒤 x · 좌우 z)
    var top: SIMD3<Double>, topHW: Double, topHD: Double
    /// 머리 지역: 목 토막 아래 단면 가운데(머리 밑)
    var headBase: SIMD3<Double>
    /// 몸통 지역 y: 목 아래 끝(몸통 윗면보다 안쪽) · 몸통 윗면 · 반폭
    var baseY: Double, torsoTop: Double, baseHW: Double, baseHD: Double
    /// 살 재질 · 톤
    var skin: Double, tone: Double
    /// 깃(세운 깃 · 차이나 칼라 · 목 보호대): 재질 · 톤 · 몸통 윗면 위로 올라오는 길이
    var collar: (mat: Double, tone: Double, up: Double)?
    /// 모델 배율(목 토막 크기 / 웹 1.8)
    var k: Double

    public static func == (a: NeckSpec, b: NeckSpec) -> Bool {
        a.top == b.top && a.topHW == b.topHW && a.baseY == b.baseY && a.skin == b.skin && a.collar?.mat == b.collar?.mat && a.k == b.k
    }

    /// 모델에서 읽기 — 머리 첫 조각(목 토막, 살색)과 몸통 첫 조각(몸통)이 없으면 nil
    public init?(model m: Model3) {
        guard let st = m["head"]?.first, st.mat == Mat.SKIN, let to = m["torso"]?.first else { return nil }
        let a = st.q[0], b = st.q[1]                                  // 위 단면 · 아래 단면(prism 순서)
        let y0 = a[0].y, y1 = b[0].y, cx = (b[0].x + b[1].x) / 2
        let hwB = (b[1].x - b[0].x) / 2, hdB = (b[2].z - b[1].z) / 2
        k = hwB / 1.8
        // 위 끝: 토막 아래 끝에서 1/3 위(토막 안) · 토막보다 8% 가늘게
        headBase = SIMD3(cx, y1, 0)
        top = SIMD3(cx, y1 - (y1 - y0) / 3, 0); topHW = hwB * 0.86; topHD = hdB * 0.86
        torsoTop = to.q[0][0].y
        baseY = torsoTop + 1.6 * k                                    // 몸통 윗면 1.6px 아래(몸통 속)
        baseHW = hwB * 1.06; baseHD = hdB * 1.12                      // 아래로 조금 굵게(몸통보다 훨씬 가늘다)
        skin = st.mat; tone = st.tone * 0.9                           // 턱 밑 그늘 — 토막보다 조금 어둡게
        // 깃: 몸통 윗면보다 위로 솟은 몸통 조각 중 가장 좁은 것(어깨 보호대 같은 넓은 판은 뺀다)
        let ups = (m["torso"] ?? []).compactMap { p -> (Prism, Double)? in
            let py0 = p.q[0][0].y, hw = (p.q[0][1].x - p.q[0][0].x) / 2
            guard py0 < torsoTop - 0.5 * k, hw < 4.6 * k, p.mat != Mat.SKIN else { return nil }
            return (p, torsoTop - py0)
        }.sorted { ($0.0.q[0][1].x - $0.0.q[0][0].x) < ($1.0.q[0][1].x - $1.0.q[0][0].x) }
        if let (p, up) = ups.first { collar = (p.mat, p.tone, up) } else { collar = nil }
    }
}

/// 뼈 지역 좌표 → 몸 공간(비틀기 · 늘림 · 화면 회전 · 위치까지 — 구르기 · 회전 · 카메라 전)
@inline(__always) func bonePoint(_ bone: Bone, _ p: SIMD3<Double>) -> SIMD3<Double> {
    let cs = cos(bone.th), sn = sin(bone.th), yw = or(bone.yaw, 0), cyw = cos(yw), syw = sin(yw), sy = or(bone.sy, 1)
    let px = p.x * cyw - p.z * syw, pz = p.x * syw + p.z * cyw, py = p.y * sy
    return SIMD3(px * cs - py * sn + bone.x, px * sn + py * cs + bone.y, pz + bone.z)
}

public enum NeckRig {
    /// 목 길이 부드러운 한계: 머리 밑(목 토막 아래 가운데) ↔ 몸통 윗면 가운데 거리가 maxLen(배율 k 곱)을 넘으면
    /// 넘는 만큼의 (1 − give) 를 몸통 쪽으로 당긴다(머리 뼈만 옮김 — 얼굴 · 입 위치도 따라감). 돌려준 값 = 머리 이동(몸 공간 x · y)
    public static func soften(_ N: NeckSpec, _ sk: inout Skeleton, maxLen: Double, give: Double) -> SIMD2<Double> {
        guard maxLen > 0, let hi = sk.bones.firstIndex(where: { $0.name == "head" }), let tb = sk["torso"] else { return .zero }
        let hb = sk.bones[hi].bone
        let A = bonePoint(hb, N.headBase), T = bonePoint(tb, SIMD3(0, N.torsoTop, 0))
        let d = SIMD2(A.x - T.x, A.y - T.y), L = (d * d).sum().squareRoot(), Lm = maxLen * N.k
        guard L > Lm else { return .zero }
        let L2 = Lm + (L - Lm) * give, mv = d / L * (L2 - L)
        sk.bones[hi].bone.x += mv.x; sk.bones[hi].bone.y += mv.y
        return mv
    }

    /// 목 뼈 · 조각(이 프레임). 머리 · 몸통 뼈가 없으면 nil
    public static func pieces(_ N: NeckSpec, _ sk: Skeleton) -> (bone: Bone, prisms: [Prism])? {
        guard let hb = sk["head"], let tb = sk["torso"] else { return nil }
        let A = bonePoint(hb, N.top), B = bonePoint(tb, SIMD3(0, N.baseY, 0))
        let d = SIMD2(B.x - A.x, B.y - A.y), L = (d * d).sum().squareRoot()
        guard L > 0.05 else { return nil }
        // 목 뼈: 위 끝(머리)에서 아래 끝(몸통)으로 +y. 비틀기는 머리(ty/2)와 몸통(ty) 사이
        let bone = Bone(x: A.x, y: A.y, z: (A.z + B.z) / 2, th: -atan2(d.x, d.y), yaw: (or(hb.yaw, 0) + or(tb.yaw, 0)) / 2)
        var out = [prism(0, L, 0, N.topHW, N.topHD, 0, N.baseHW, N.baseHD, N.skin, N.tone, 1)]
        if let c = N.collar {   // 깃: 몸통 윗면 위로 c.up 만큼 목을 감싼다(목이 길어져도 깃 높이는 그대로)
            let tTop = L - (N.baseY - N.torsoTop)                    // 목 축 위 몸통 윗면 자리
            let y0 = max(0, tTop - c.up - 1.5 * N.k), w = 1.12             // 옷 깃보다 1.5px 더 올라와 늘어난 목을 감싼다(터틀넥)
            if y0 < L - 0.1 { out.append(prism(y0, L, 0, N.baseHW * w, N.baseHD * w, 0, N.baseHW * w * 1.04, N.baseHD * w * 1.04, c.mat, c.tone, 2)) }
        }
        return (bone, out)
    }

    /// 목을 메시로(emitModel 과 같은 경로 — 구르기 · 몸 회전 · 카메라 · 팔레트 스왑 · 번쩍임)
    public static func emit(_ N: NeckSpec, _ sk: Skeleton, at m: MeshPlacement, tables: AnimTables, into w: inout MeshWriter) {
        guard let (bone, ps) = pieces(N, sk) else { return }
        emitModel(["neck": ps], Skeleton(bones: [(name: "neck", bone: bone)], spin: sk.spin, roll: sk.roll), at: m, tables: tables, into: &w)
    }
}
