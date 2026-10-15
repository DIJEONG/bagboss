import BBContent

/// 스프라이트 쿼드 쌓기(웹 17-light-frame quad · placeAt) — RenderFrame.spriteVertices 를 만든다
public struct SpriteBatch: Sendable {
    public private(set) var vertices: [Float] = []
    /// 지금 그리는 층의 깊이 · 화면 오프셋 · 팔레트 스왑 · 파츠 번호(웹 drawDepth · drawOX · drawRemap · drawPart)
    public var depth: Float = 0, offsetX: Float = 0, remap: Float = 0, part: Float = 0
    public init() {}
    public var vertexCount: Int { vertices.count / 9 }

    public mutating func quad(_ s: AtlasMeta.Sprite, x: Float, y: Float, flip: Bool = false, flash: Bool = false) {
        let x = x + offsetX, u0 = Float(s.x), v0 = Float(s.y), u1 = Float(s.x + s.w), v1 = Float(s.y + s.h)
        let ua = flip ? u1 : u0, ub = flip ? u0 : u1, x1 = x + Float(s.w), y1 = y + Float(s.h)
        let fl: Float = flip ? 1 : 0, fa: Float = flash ? 1 : 0
        for (px, py, u, v) in [(x, y, ua, v0), (x1, y, ub, v0), (x, y1, ua, v1), (x1, y, ub, v0), (x1, y1, ub, v1), (x, y1, ua, v1)] {
            vertices += [px, py, u, v, fl, fa, depth, remap, part]
        }
    }
    /// 피벗 기준 배치(웹 placeAt)
    public mutating func place(_ s: AtlasMeta.Sprite, at jx: Float, _ jy: Float, flip: Bool = false, flash: Bool = false) {
        let x = flip ? jx - (Float(s.w) - 1 - Float(s.px)) : jx - Float(s.px)
        quad(s, x: x, y: jy - Float(s.py), flip: flip, flash: flash)
    }
}
