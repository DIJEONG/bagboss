import Foundation
import simd

/// 웹 캡처(tools/js/extract/frames.mjs 의 frame.json) → RenderFrame.
/// 웹이 그 프레임에 실제로 넘긴 유니폼 값을 그대로 옮긴다 — 렌더러 대조 테스트와 DEBUG 장면 뷰어가 쓴다.
extension RenderFrame {
    public init(webCapture data: Data) throws {
        let c = try JSONDecoder().decode(Capture.self, from: data)
        let cu = c.composite.uniforms ?? [:]
        var comp = CompositeParams()
        let n = Int(cu.f("uLN") ?? 0)
        let LP = cu["uLP"] ?? [], LC = cu["uLC"] ?? [], LD = cu["uLD"] ?? []
        comp.lights = (0..<n).map { i in
            Light(position: v4(LP, i), color: v4(LC, i), shape: v4(LD, i))
        }
        comp.ambient = cu.f("uAmb") ?? comp.ambient
        comp.emitK = cu.f("uEmitK") ?? comp.emitK
        if let s = cu["uSun"], s.count == 2 { comp.sun = SIMD2(Float(s[0]), Float(s[1])) }
        var p = NoirPreset()
        p.lightAmb = cu.f("u2_amb") ?? p.lightAmb; p.lightGain = cu.f("u2_gain") ?? p.lightGain; p.rim = cu.f("u3_str") ?? p.rim
        p.rampPalette = cu.f("u7_pal") ?? p.rampPalette; p.tintAmount = cu.f("u7_tintAmt") ?? p.tintAmount; p.dither = cu.f("u7_dith") ?? p.dither
        p.linePalette = cu.f("u9_pal") ?? p.linePalette; p.outer = cu.f("u9_outer") ?? p.outer; p.inner = cu.f("u9_inner") ?? p.inner; p.select = cu.f("u9_sel") ?? p.select
        if let t = cu["u9_tint"], t.count == 3 { p.lineTint = SIMD3(Float(t[0]), Float(t[1]), Float(t[2])) }
        comp.preset = p

        var post: PostParams?
        if let pc = c.post, let u = pc.post {
            var f = PostParams()
            if let g = u["uGrade"], g.count == 3 { f.grade = SIMD3(Float(g[0]), Float(g[1]), Float(g[2])) }
            f.saturation = u.f("uSat") ?? 1; f.exposure = u.f("uExpo") ?? 1
            f.windowReflection = u.f("uWinR") ?? 0
            if let w = u["uWinY"], w.count == 2 { f.windowY = SIMD2(Float(w[0]), Float(w[1])) }
            f.pressure = u.f("uPress") ?? 0; f.bloom = u.f("uBloomK") ?? 0; f.reflectY = u.f("uReflY") ?? 0
            f.rain = u.f("uRain") ?? 0; f.vignette = u.f("uVig") ?? 0; f.fog = u.f("uFog") ?? 0
            if let fc = u["uFogC"], fc.count == 3 { f.fogColor = SIMD3(Float(fc[0]), Float(fc[1]), Float(fc[2])) }
            f.invert = (u.f("uInv") ?? 0) > 0.5
            f.wetMaterials = SIMD3(u.f("uWetA") ?? 42, u.f("uWetB") ?? 26, u.f("uWetC") ?? -1)
            let vn = Int(u.f("uVN") ?? 0), VP = u["uVP"] ?? [], VC = u["uVC"] ?? [], VD = u["uVD"] ?? []
            f.volumes = (0..<vn).map { (v4(VP, $0), v4(VC, $0), v4(VD, $0)) }
            let sn = Int(u.f("uSWN") ?? 0), SA = u["uSW"] ?? [], SB = u["uSWb"] ?? []
            f.shockwaves = (0..<sn).map { (v4(SA, $0), v4(SB, $0)) }
            f.smear = v4(u["uSM"] ?? [], 0); f.smearAmount = u.f("uSMk") ?? 0
            // 블러: (r,0) · (0,r) 짝마다 반경 하나
            f.blurRadii = stride(from: 0, to: pc.blur.count, by: 2).map { Float(pc.blur[$0].uniforms["uDir"]?.first ?? 1) }
            post = f
        }

        var blit = BlitParams(visibleWidth: c.blit?.f("uVW") ?? Float(c.width))
        if let b = c.blit {
            blit.zoom = b.f("uZoom") ?? 1; blit.cameraX = b.f("uCamX") ?? 0
            if let z = b["uZC"], z.count == 2 { blit.zoomCenter = SIMD2(Float(z[0]), Float(z[1])) }
        }

        self.init(width: c.width, height: c.height, time: Float(c.time), composite: comp, post: post, blit: blit)
        let su = c.sprite.uniforms ?? [:]
        if let s = su["uShake"], s.count == 2 { shake = SIMD2(Float(s[0]), Float(s[1])) }
        fixFlip = (su.f("uFix") ?? 1) > 0.5
        windowLight = su.f("uWin") ?? 0
        if let r = su["uRemap"], r.count == 48 { remap = r.map(Float.init) }
        spriteVertices = c.sprite.verts.map(Float.init)
        meshVertices = c.mesh.verts.map(Float.init)
        gbuffer = c.gbuffer.map { $0.kind == "mesh" ? .mesh(first: $0.first, count: $0.count) : .sprite(first: $0.first, count: $0.count, shadow: $0.shadow ?? false) }
    }
}

private func v4(_ a: [Double], _ i: Int) -> SIMD4<Float> {
    guard a.count >= i * 4 + 4 else { return .zero }
    return SIMD4(Float(a[i * 4]), Float(a[i * 4 + 1]), Float(a[i * 4 + 2]), Float(a[i * 4 + 3]))
}

private extension Dictionary where Key == String, Value == [Double] {
    func f(_ k: String) -> Float? { self[k]?.first.map(Float.init) }
}

private struct Capture: Decodable {
    struct Verts: Decodable { let uniforms: [String: [Double]]?; let verts: [Double] }
    struct Pass: Decodable { let kind: String; let first: Int; let count: Int; let shadow: Bool? }
    struct Comp: Decodable { let uniforms: [String: [Double]]? }
    struct Blur: Decodable { let uniforms: [String: [Double]] }
    struct Post: Decodable { let post: [String: [Double]]?; let blur: [Blur] }
    let width: Int, height: Int, time: Double
    let sprite: Verts, mesh: Verts
    let gbuffer: [Pass]
    let composite: Comp
    let post: Post?
    let blit: [String: [Double]]?
}
