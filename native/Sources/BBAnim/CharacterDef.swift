import Foundation
import BBContent

/// 인물 정의(웹 JW_HERO · JW_THUG · JW_BOSS · NOIR_THUG …) 중 그리기에 쓰는 것
public struct CharacterDef: Sendable, Decodable {
    public let name: String
    public let rig: RigDims
    public let model3: Model3
    public let gait: Bool?
    public let jw: Bool?
    public let face: Bool?

    public static func load(_ s: ContentStore, _ constName: String) throws -> CharacterDef { try s.decode(constName) }

    /// 대기 자세로 선 인물 하나
    public func instance(x: Double, y: Double, flip: Bool, isHero: Bool, sequences: SequenceTable, tables: AnimTables) -> (CharacterRig, SequencePlayer) {
        var a = ActorPose(anim: "idle", pose: "st0")
        var p = SequencePlayer()
        p.set("idle", on: &a, table: sequences, loop: tables.loop)
        var r = CharacterRig(model: model3, rig: rig, traits: ActorTraits(gait: gait ?? false, jw: jw ?? false, isHero: isHero), actor: a, x: x, y: y, flip: flip)
        r.hasFace = face ?? false
        return (r, p)
    }
}
