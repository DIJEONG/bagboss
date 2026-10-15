import Foundation

// 웹 HUD 캡처(tools/js/extract/hud.mjs 의 <순간>.json) → HUDState · HUDFrame. 대조 테스트 · DEBUG 뷰어가 쓴다.
public struct HUDCapture: Sendable {
    public var name: String, width: Int, height: Int
    public var state: HUDState
    public var frame: HUDFrame

    struct Raw: Decodable {
        struct Pop: Decodable { var x: Double, y: Double, val: Int, style: String, label: String?, labelCol: String?, stack: Int, age: Double, vx: Double, life: Double }
        struct Comic: Decodable { var k: String, x: Double, y: Double, word: String?, text: String?, age: Double, life: Double, rot: Double? }
        struct State: Decodable { var pops: [Pop]; var hitFx: [HitFx]; var critFx: [CritFx]; var comic: [Comic]; var cmdLog: [CmdView]; var cut: CutView?; var wipe: WipeView? }
        var name: String, width: Int, height: Int
        var state: State
        var frame: HUDFrame
    }

    public init(json data: Data) throws {
        let r = try JSONDecoder().decode(Raw.self, from: data)
        name = r.name; width = r.width; height = r.height; frame = r.frame
        var s = HUDState()
        var id = 0
        for p in r.state.pops { id += 1; s.pops.append(.init(id: id, x: p.x, y: p.y, value: p.val, style: p.style, label: p.label, stack: p.stack, age: p.age, life: p.life, vx: p.vx, labelCol: p.labelCol)) }
        for c in r.state.comic {
            id += 1
            if c.k == "sfx" { s.words.append(.init(id: id, x: c.x, y: c.y, word: c.word ?? "", rot: c.rot ?? 0, age: c.age, life: c.life)) }
            else { s.bubbles.append(.init(id: id, actor: -1, text: c.text ?? "", kind: c.k, age: c.age, life: c.life, x: c.x, y: c.y)) }
        }
        s.hitFx = r.state.hitFx; s.critFx = r.state.critFx; s.cmdLog = r.state.cmdLog; s.cut = r.state.cut; s.wipe = r.state.wipe
        state = s
    }
}
