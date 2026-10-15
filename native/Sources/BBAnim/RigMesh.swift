import Foundation

/// 뼈 하나: 원점 · 화면 평면 회전(th) · 비틀기(yaw) · 길이 늘림(sy) · 다리 벌리기 축(ab)
public struct Bone: Sendable, Equatable {
    public var x: Double, y: Double, z: Double, th: Double
    public var yaw: Double? = nil, sy: Double? = nil
    public var ab: Abduct? = nil
    public struct Abduct: Sendable, Equatable, Decodable { public var py: Double, pz: Double, c: Double, s: Double }
}
/// 몸 전체 회전(돌려차기 360°) · 화면 안 구르기
public struct BodySpin: Sendable, Equatable { public var px: Double, c: Double, s: Double }
public struct BodyRoll: Sendable, Equatable { public var px: Double, py: Double, c: Double, s: Double }

/// 뼈 묶음 — 순서가 정점 순서를 정한다(웹 객체 키 순서와 같게)
public struct Skeleton: Sendable, Equatable {
    public var bones: [(name: String, bone: Bone)]
    public var spin: BodySpin?, roll: BodyRoll?
    public subscript(_ n: String) -> Bone? { bones.first { $0.name == n }?.bone }
    public static func == (a: Skeleton, b: Skeleton) -> Bool {
        a.bones.map(\.name) == b.bones.map(\.name) && zip(a.bones, b.bones).allSatisfy { $0.bone == $1.bone } && a.spin == b.spin && a.roll == b.roll
    }
}

/// 웹 charBones: 관절 → 3D 뼈(조각의 +y 가 뼈 방향)
public func makeSkeleton(_ j: Joints, pose P: Pose) -> Skeleton {
    func seg(_ A: V2, _ B: V2, _ z: Double) -> Bone { Bone(x: A.x, y: A.y, z: z, th: -atan2(B.x - A.x, B.y - A.y)) }
    var tor = seg(j.neck, j.hips, 0)
    let thF = seg(j.legF, j.kneeF, 2.8), thB = seg(j.legB, j.kneeB, -2.8), shnF = seg(j.kneeF, j.footF, 2.8), shnB = seg(j.kneeB, j.footB, -2.8)
    let ty = or(P.ty, 0); tor.yaw = ty   // 몸통 비틀기: 펀치 때 어깨가 앞으로 돈다
    var thighF = thF; thighF.sy = or(P.strL, 1)
    var shinF = shnF; shinF.sy = or(P.strL, 1)
    var farmF = seg(j.elbF, j.handF, j.zF); farmF.sy = or(P.strF, 1)
    var farmB = seg(j.elbB, j.handB, j.zB); farmB.sy = or(P.strB, 1)
    var B: [(String, Bone)] = [
        ("torso", tor), ("head", Bone(x: j.head.x, y: j.head.y, z: 0, th: tor.th + or(P.hn, 0) * .pi / 180, yaw: ty * 0.5 + or(P.hy, 0) * .pi / 180)),   // 고개 hn · hy(네이티브 — 없으면 웹 그대로)
        ("skirtF", Bone(x: j.hips.x, y: j.hips.y, z: 0, th: thF.th * 0.55 + tor.th * 0.45, yaw: ty * 0.5)),
        ("skirtB", Bone(x: j.hips.x, y: j.hips.y, z: 0, th: thB.th * 0.55 + tor.th * 0.45, yaw: ty * 0.5)),
        ("thighF", thighF), ("shinF", shinF), ("thighB", thB), ("shinB", shnB),
        ("footF", Bone(x: j.footF.x, y: j.footF.y, z: 2.8, th: shnF.th * 0.25)), ("footB", Bone(x: j.footB.x, y: j.footB.y, z: -2.8, th: shnB.th * 0.25)),
        ("uarmF", seg(j.shF, j.elbF, j.zF)), ("farmF", farmF), ("uarmB", seg(j.shB, j.elbB, j.zB)), ("farmB", farmB),
    ]
    if let w = j.weapon { B.append((w, Bone(x: j.handF.x, y: j.handF.y, z: j.zF, th: -or(P.w, 4) * .pi / 8))) }
    // 다리 좌우 벌리기(도) — 다리마다 따로, 없으면 spr 공통
    let sF = P.sprF ?? P.spr ?? 0, sB = P.sprB ?? P.spr ?? 0
    if truthy(sF) { let a = sF * .pi / 180, ab = Bone.Abduct(py: j.legF.y, pz: 2.8, c: cos(a), s: sin(a))
        for i in B.indices where ["thighF", "shinF", "footF"].contains(B[i].0) { B[i].1.ab = ab } }
    if truthy(sB) { let a = sB * .pi / 180, ab = Bone.Abduct(py: j.legB.y, pz: -2.8, c: cos(a), s: -sin(a))
        for i in B.indices where ["thighB", "shinB", "footB"].contains(B[i].0) { B[i].1.ab = ab } }
    var sk = Skeleton(bones: B.map { (name: $0.0, bone: $0.1) })
    if truthy(P.spin) { let a = P.spin! * 2 * .pi; sk.spin = BodySpin(px: j.hips.x, c: cos(a), s: sin(a)) }
    if truthy(P.roll) { let a = P.roll! * 2 * .pi; sk.roll = BodyRoll(px: (j.hips.x + j.neck.x) / 2, py: (j.hips.y + j.neck.y) / 2, c: cos(a), s: sin(a)) }
    return sk
}

// 3/4 시점 + 살짝 내려다봄(모자 윗면이 보이게)
let YAW = 30 * Double.pi / 180, CY = cos(YAW), SY = sin(YAW), PIT = 14 * Double.pi / 180, CP = cos(PIT), SP = sin(PIT)

/// 웹 boneT: 조각 좌표 → (비틀기 · 늘림 · 화면 회전 · 위치) → (다리 벌리기 · 구르기 · 몸 회전) → 카메라
@inline(__always) func boneTransform(_ bone: Bone, _ sp: BodySpin?, _ rl: BodyRoll?, _ p: SIMD3<Double>) -> SIMD3<Double> {
    let cs = cos(bone.th), sn = sin(bone.th), yw = or(bone.yaw, 0), cyw = cos(yw), syw = sin(yw), sy = or(bone.sy, 1)
    let px = p.x * cyw - p.z * syw, pz = p.x * syw + p.z * cyw, py = p.y * sy
    var x = px * cs - py * sn + bone.x, z = pz + bone.z, y = px * sn + py * cs + bone.y
    if let A = bone.ab { let dy = y - A.py, dz = z - A.pz; y = A.py + dy * A.c - dz * A.s; z = A.pz + dy * A.s + dz * A.c }
    if let rl { let dx = x - rl.px, dy = y - rl.py; x = rl.px + dx * rl.c - dy * rl.s; y = rl.py + dx * rl.s + dy * rl.c }
    if let sp { let dx = x - sp.px, z0 = z; x = sp.px + dx * sp.c - z0 * sp.s; z = dx * sp.s + z0 * sp.c }
    let xr = x * CY - z * SY, zr = x * SY + z * CY
    return SIMD3(xr, y * CP + zr * SP, -y * SP + zr * CP)
}

/// 3D 정점 출력(렌더러 meshVS 입력: 10 float/정점)
public struct MeshWriter: Sendable {
    public private(set) var floats: [Float] = []
    public init() {}
    mutating func vertex(_ x: Double, _ y: Double, _ z: Double, _ nx: Double, _ ny: Double, tone: Double, mat: Double, part: Double, depth: Double, emit: Double) {
        floats.append(contentsOf: [Float(x), Float(y), Float(z), Float(nx), Float(ny), Float(tone), Float(mat), Float(part), Float(depth), Float(emit)])
    }
    public var vertexCount: Int { floats.count / 10 }
}

public struct MeshPlacement: Sendable {
    /// 화면 위치(발 x · 발 y) · 좌우 반전 · 팔레트 스왑 세트 · 번쩍임
    public var x: Double, y: Double, flip: Bool, remap: Int, flash: Bool
    public init(x: Double, y: Double, flip: Bool, remap: Int, flash: Bool) { self.x = x; self.y = y; self.flip = flip; self.remap = remap; self.flash = flash }
}

/// 웹 pushModel: 뼈마다 조각을 변환해 앞면만 삼각형으로(깊이 · 노멀 · 재질 · 부위 번호)
public func emitModel(_ model: Model3, _ sk: Skeleton, at m: MeshPlacement, tables: AnimTables, into w: inout MeshWriter) {
    let f: Double = m.flip ? -1 : 1, footY = m.y
    for (key, bone) in sk.bones {
        guard let pieces = model[key] else { continue }
        for pc in pieces {
            let cc = boneTransform(bone, sk.spin, sk.roll, pc.c)
            let mat = m.flash ? 13 : tables.remapMaterial(m.remap, pc.mat), tone = m.flash ? 1 : pc.tone, emit: Double = m.flash ? 1 : 0
            for qd in pc.q {
                let P = qd.map { boneTransform(bone, sk.spin, sk.roll, $0) }
                let u = P[1] - P[0], v = P[2] - P[0]
                var n = SIMD3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
                let L = jsHypot(n.x, n.y, n.z); n /= (L == 0 ? 1 : L)
                let mid = (P[0] + P[2]) / 2 - cc
                if (n * mid).sum() < 0 { n = -n }          // 바깥쪽을 보게
                if n.z <= 0.02 { continue }                  // 뒷면은 버린다
                for tri in [[0, 1, 2], [0, 2, 3]] {
                    for k in tri { let p = P[k]
                        w.vertex(m.x + f * p.x, m.y + p.y, 0.9 - footY / 300 - p.z / 600, f * n.x, -n.y,
                                 tone: tone, mat: mat, part: pc.part, depth: 0.5 + p.z / 60, emit: emit) }
                }
            }
        }
    }
}

/// V8 Math.hypot 과 같은 방식(최댓값으로 나눠 제곱합 — Kahan 보정)
@inline(__always) func jsHypot(_ a: Double, _ b: Double, _ c: Double) -> Double {
    let x = abs(a), y = abs(b), z = abs(c), mx = max(x, y, z)
    if mx == 0 { return 0 }
    var sum = 0.0, comp = 0.0
    for v in [x, y, z] { let r = v / mx, s = r * r - comp, prelim = sum + s; comp = (prelim - sum) - s; sum = prelim }
    return sqrt(sum) * mx
}

/// 얼굴 표정 키(웹 faceOf)
public func faceKey(anim a: String, flash: Double?, footX: Double, time: Double, tables: AnimTables) -> String {
    if tables.falls.contains(a) || a.hasSuffix("D") || ["death", "down", "deathFwd", "held"].contains(a) { return "ko" }
    if (flash ?? 0) > 0 || tables.reacts.contains(a) { return "hurt" }
    if ["jab", "cross", "hook", "upper", "kick", "round", "bat", "hbutt"].contains(a) { return "atk" }
    let xi = Double(Int32(truncatingIfNeeded: Int64(footX.isFinite ? footX.rounded(.towardZero) : 0)))
    return jsMod(time * 1000 + xi * 37, 3400) < 130 ? "blink" : "neutral"
}

/// 웹 pushFace: 머리 뼈 앞면에 얼굴 픽셀을 붙인다(머리 기울기는 90° 단위)
/// - spin · roll: 몸 전체 회전(강화 — 웹 pushFace 는 이것을 빼고 변환해 몸이 돌아도 얼굴만 원래 방향에 남는다 · nil = 웹 그대로)
public func emitFace(key: String, head: Bone, spin: BodySpin? = nil, roll: BodyRoll? = nil, at m: MeshPlacement, shades: Bool, isHero: Bool, tables: AnimTables, into w: inout MeshWriter) {
    guard var rows = tables.faces[key], let ey = tables.faceEye[key] else { return }
    let f: Double = m.flip ? -1 : 1, footY = m.y
    if shades && isHero { rows[ey] = key == "hurt" ? "sgsss" : "gssss" }
    func T(_ p: SIMD3<Double>) -> SIMD3<Double> { boneTransform(head, spin, roll, p) }
    let A = T([4.3, -8.6, 3.2]), N0 = T([0, 0, 0]), NF = T([1, 0, 0]), NU = T([0, -1, 0])
    if NF.z - N0.z < 0.04 { return }                       // 얼굴이 돌아가 안 보이면 그리지 않음
    let ang = atan2(NU.x - N0.x, -(NU.y - N0.y)), qt = Int(jsMod(jsMod(jsRound(ang / (.pi / 2)), 4) + 4, 4))
    let ax = jsRound(m.x + f * A.x), ay = jsRound(m.y + A.y), nx = f * (NF.x - N0.x), ny = -(NF.y - N0.y)
    for (j, r) in rows.enumerated() {
        for (i, ch) in r.enumerated() {
            guard let L = tables.faceLegend[ch] else { continue }
            var dx = Double(i), dy = Double(j - ey)
            for _ in 0..<qt { let t = dx; dx = -dy; dy = t }
            let X = ax + f * dx, Y = ay + dy, z = 0.9 - footY / 300 - (A.z + 1.2) / 600
            for (u, v) in [(0.0, 0.0), (1, 0), (1, 1), (0, 0), (1, 1), (0, 1)] {
                w.vertex(X + u, Y + v, z, nx, ny, tone: L.1, mat: L.0, part: 1, depth: 0.5 + A.z / 60, emit: 0)
            }
        }
    }
}
