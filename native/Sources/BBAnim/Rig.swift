import Foundation
import BBContent

/// 리그 치수(웹 d.rig) — 게임 인물은 모두 같은 3D 리그(RIG_3D)를 쓴다
public struct RigDims: Sendable, Equatable, Decodable {
    public var hip: Double
    public var head: V2, shF: V2, shB: V2, legF: V2, legB: V2
    public var upper: Double, fore: Double
    public var armLenF: Double, armLenB: Double
    public var thigh: Double?, shin: Double?
    public var glowLen: Double?
    public var sc: Double?
    public var leanK: Double?
}

/// 로우폴리 조각(웹 prism): 사각면 6개(각 4점) · 재질 · 톤 · 부위 번호 · 중심
public struct Prism: Sendable, Equatable, Decodable {
    public let q: [[SIMD3<Double>]]
    public let mat: Double
    public let tone: Double
    public let part: Double
    public let c: SIMD3<Double>
}

/// 인물 3D 모델(웹 model3): 뼈 이름 → 조각 목록
public typealias Model3 = [String: [Prism]]

/// 얼굴 · 반응 판정 등 애니메이션 표(웹 13-rig-grammar · 12-webgl)
public struct AnimTables: Sendable {
    public internal(set) var poses: [String: Pose]
    public let reacts: Set<String>
    public let falls: Set<String>
    public let loop: Set<String>
    public let faces: [String: [String]]
    public let faceEye: [String: Int]
    /// 얼굴 글자 → (재질, 톤)
    public let faceLegend: [Character: (Double, Double)]
    /// 팔레트 스왑 표(웹 REMAP) — 8세트 × 3쌍 × (원래, 바꿀)
    public let remap: [Double]

    public init(_ s: ContentStore) throws {
        poses = try s.decode("POSES")
        func set(_ n: String) throws -> Set<String> { Set(try s.decode(n, as: SetBox.self).items) }
        reacts = try set("REACTS"); falls = try set("FALLS"); loop = try set("LOOP")
        faces = try s.decode("FACES"); faceEye = try s.decode("FACE_EYE")
        let leg: [String: [Double]] = try s.decode("FACE_LEG")
        faceLegend = Dictionary(uniqueKeysWithValues: leg.map { (Character($0.key), ($0.value[0], $0.value[1])) })
        remap = [10, 12, 11, 7, 0, 0, 10, 8, 11, 22, 0, 0, 10, 7, 11, 12, 0, 0, 12, 6, 32, 33, 0, 0,
                 43, 47, 6, 12, 7, 22, 43, 29, 32, 33, 6, 4, 43, 44, 44, 7, 6, 20, 43, 20, 44, 20, 32, 33]
    }

    func pose(_ name: String?) -> Pose? { name.flatMap { poses[live: $0] } }

    /// 웹 c.remap 세트로 재질 바꾸기
    func remapMaterial(_ set: Int, _ m: Double) -> Double {
        guard set > 0 else { return m }
        let k = (set - 1) * 6
        for q in 0..<3 where remap[k + q * 2] > 0 && remap[k + q * 2] == m { return remap[k + q * 2 + 1] }
        return m
    }
}

/// 추출기의 Set 표기({"$set": [...]})
struct SetBox: Decodable {
    let items: [String]
    enum K: String, CodingKey { case set = "$set" }
    init(from d: Decoder) throws { items = try d.container(keyedBy: K.self).decode([String].self, forKey: .set) }
}
