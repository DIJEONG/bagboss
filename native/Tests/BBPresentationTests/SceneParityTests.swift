import Foundation
import Testing
import BBContent
import BBPresentation
@testable import BBRender

// 장면 구성 웹 대조: tools/js/extract/scenes.mjs 가 실제로 도는 웹판에서 기록한 입력 → 같은 출력인지.
//  ① 함수별(drawSubwayBack · subwayLights · subwayFX): 쿼드 목록 정확히 · 광원/fx 1e-9 · 숨은 상태 변경(invF · 눈 적응 · 불꽃) · 난수 소비 개수
//  ② e2e: 같은 입력으로 웹 render() 전체를 돌린 G-버퍼 첫 그리기 정점 · 합성 · 후처리 유니폼 = 구성 → SceneAdapter 결과

private let fixtureDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/scenes")

private struct Fixture: Decodable {
    let name: String
    let input: SceneInput
    let rng: [Double]
    let rngSplit: [Int]
    let carKey: String
    let fn: Fn
    let render: Render
    struct Fn: Decodable {
        let quads: [[JSONValue]]
        let verts: [Double?]
        let lights: [SceneLight]
        let composed: Composed
        let fx: PostFX
        let after: After
    }
    struct Composed: Decodable { let lights: [SceneLight]; let ambient: Double; let emitK: Double }
    struct After: Decodable {
        let invF: Double
        let adT: Double?
        let outS: Double?
        let darkA: Double?
        let adA: Double?
        let sparks: [SceneEffects.Spark]
        let bits: [SceneEffects.Bit]
    }
    struct Render: Decodable {
        let input: SceneInput
        let random: Double
        let bgVerts: [Double]
        let composite: [String: [Double]]
        let post: [String: [Double]]?
    }
}

private enum Shared {
    static let content: SceneContent = try! SceneContent.bundled()
    static let names: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: fixtureDir.path())) ?? [])
        .filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
}

private func load(_ name: String) throws -> Fixture {
    try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureDir.appending(path: name + ".json")))
}

private func near(_ a: Double, _ b: Double, _ tol: Double) -> Bool { a == b || abs(a - b) <= tol * max(1, abs(b)) }
private func near(_ a: [Double]?, _ b: [Double]?, _ tol: Double) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    return a.count == b.count && zip(a, b).allSatisfy { near($0, $1, tol) }
}
private func lightDiff(_ a: SceneLight, _ b: SceneLight, _ tol: Double = 1e-9) -> String? {
    if !near(a.x, b.x, tol) || !near(a.y, b.y, tol) || !near(a.z, b.z, tol) || !near(a.r, b.r, tol) { return "위치 \(a) ≠ \(b)" }
    if !near(a.c, b.c, tol) || !near(a.i, b.i, tol) { return "색 · 세기 \(a.c) \(a.i) ≠ \(b.c) \(b.i)" }
    if !near(a.spot, b.spot, tol) || !near(a.cone.map { [$0] }, b.cone.map { [$0] }, tol) || !near(a.dirl, b.dirl, tol) { return "모양 \(a) ≠ \(b)" }
    if (a.em == true) != (b.em == true) { return "em \(a.em as Any) ≠ \(b.em as Any)" }
    return nil
}
private func fxDiff(_ a: PostFX, _ b: PostFX, _ tol: Double = 1e-9) -> String? {
    let pairs: [(String, [Double]?, [Double]?)] = [
        ("expo", a.expo.map { [$0] }, b.expo.map { [$0] }), ("winR", a.winR.map { [$0] }, b.winR.map { [$0] }), ("winY", a.winY, b.winY),
        ("press", a.press.map { [$0] }, b.press.map { [$0] }), ("bloom", [a.bloom], [b.bloom]), ("reflY", [a.reflY], [b.reflY]),
        ("rain", [a.rain], [b.rain]), ("vig", [a.vig], [b.vig]), ("fog", [a.fog], [b.fog]), ("fogC", a.fogC, b.fogC), ("inv", [a.inv], [b.inv]),
        ("grade", a.grade, b.grade), ("sat", a.sat.map { [$0] }, b.sat.map { [$0] }),
    ]
    for (k, x, y) in pairs where !near(x, y, tol) { return "\(k): \(x as Any) ≠ \(y as Any)" }
    if a.vols.count != b.vols.count { return "vols 개수 \(a.vols.count) ≠ \(b.vols.count)" }
    for (j, (u, v)) in zip(a.vols, b.vols).enumerated() {
        if !near([u.x, u.y, u.dx, u.dy, u.i, u.cone, u.len, u.halo] + u.c, [v.x, v.y, v.dx, v.dy, v.i, v.cone, v.len, v.halo] + v.c, tol) { return "vols[\(j)] \(u) ≠ \(v)" }
    }
    return nil
}

@Suite("장면 구성 웹 대조") struct SceneParityTests {
    @Test("픽스처가 있다") func hasFixtures() {
        #expect(Shared.names.count >= 10, Comment(rawValue: "native/Tests/Fixtures/scenes — node tools/js/extract/scenes.mjs 로 찍는다"))
    }

    @Test("함수별 대조(쿼드 · 광원 · fx · 숨은 변경)", arguments: Shared.names)
    func functions(_ name: String) throws {
        let F = try load(name), K = Shared.content, I = F.input
        var rng = ReplayRandom(F.rng)
        var eff = SceneEffects(invF: Int(I.invF), eye: EyeAdaptState(adT: I.eye.adT, outS: I.eye.outS, darkA: I.eye.darkA, adA: I.eye.adA))

        // ① 배경 쿼드
        let back = SceneComposer.background(I, K, &eff, &rng)
        #expect(rng.used == F.rngSplit[0], Comment(rawValue: "배경 난수 소비 \(rng.used) ≠ \(F.rngSplit[0])"))
        let want = F.fn.quads
        #expect(back.count == want.count, Comment(rawValue: "\(name): 쿼드 수 \(back.count) ≠ \(want.count)"))
        var bad = 0
        for (j, (q, w)) in zip(back, want).enumerated() {
            let wn = [w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8]].map { $0.double ?? .nan }
            let got = [q.x, q.y, q.flip, q.flash, q.depth, q.offsetX, q.remap, q.part]
            let same = q.name == w[0].string && zip(got, wn).allSatisfy { $0 == $1 || ($0.isNaN && $1.isNaN) }
            if !same { bad += 1; if bad <= 5 { Issue.record("\(name) 쿼드[\(j)] \(q.name) \(got) ≠ \(w[0].string ?? "?") \(wn)") } }
        }
        #expect(bad == 0)

        // 배경 정점(SceneAdapter → SpriteBatch) = 웹 vdata
        var batch = SpriteBatch(); batch.append(back, atlas: K.sprites)
        let wv = F.fn.verts.map { Float($0 ?? .nan) }
        #expect(batch.vertices.count == wv.count)
        #expect(zip(batch.vertices, wv).allSatisfy { $0 == $1 || ($0.isNaN && $1.isNaN) }, Comment(rawValue: "\(name): 배경 정점 불일치"))

        // ② 광원
        let lights = SceneComposer.sceneLights(I, K, &rng)
        #expect(rng.used == F.rngSplit[1], Comment(rawValue: "광원까지 난수 소비 \(rng.used) ≠ \(F.rngSplit[1])"))
        #expect(lights.count == F.fn.lights.count, Comment(rawValue: "\(name): 광원 수 \(lights.count) ≠ \(F.fn.lights.count)"))
        for (j, (a, b)) in zip(lights, F.fn.lights).enumerated() { if let d = lightDiff(a, b) { Issue.record("\(name) 광원[\(j)] \(d)") } }

        let lit = SceneComposer.lighting(I, lights)
        #expect(lit.lights.count == F.fn.composed.lights.count)
        for (j, (a, b)) in zip(lit.lights, F.fn.composed.lights).enumerated() { if let d = lightDiff(a, b) { Issue.record("\(name) 합성 광원[\(j)] \(d)") } }
        #expect(near(lit.ambient, F.fn.composed.ambient, 1e-9), Comment(rawValue: "uAmb \(lit.ambient) ≠ \(F.fn.composed.ambient)"))
        #expect(near(lit.emitK, F.fn.composed.emitK, 1e-9))

        // ③ fx + 숨은 상태 변경
        let fx = SceneComposer.postFX(I, K, &eff)
        if let d = fxDiff(fx, F.fn.fx) { Issue.record("\(name) fx \(d)") }
        #expect(rng.used == F.rng.count, Comment(rawValue: "난수 소비 \(rng.used) ≠ \(F.rng.count)"))
        let A = F.fn.after
        #expect(Double(eff.invF) == A.invF, Comment(rawValue: "invF \(eff.invF) ≠ \(A.invF)"))
        #expect(near(eff.eye.adT.map { [$0] }, A.adT.map { [$0] }, 1e-12) && near(eff.eye.outS.map { [$0] }, A.outS.map { [$0] }, 1e-9)
                && near(eff.eye.darkA.map { [$0] }, A.darkA.map { [$0] }, 1e-9) && near(eff.eye.adA.map { [$0] }, A.adA.map { [$0] }, 1e-9), Comment(rawValue: "눈 적응 \(eff.eye) ≠ \(A)"))
        #expect(eff.sparks == A.sparks, Comment(rawValue: "불꽃 \(eff.sparks) ≠ \(A.sparks)"))
        #expect(eff.bits.count == A.bits.count && zip(eff.bits, A.bits).allSatisfy { near([$0.x, $0.y, $0.vx, $0.vy, $0.t], [$1.x, $1.y, $1.vx, $1.vy, $1.t], 1e-12) })
    }

    @Test("e2e: 구성 → RenderFrame 조각 = 웹 render() 유니폼 · 배경 정점", arguments: Shared.names)
    func endToEnd(_ name: String) throws {
        let F = try load(name), K = Shared.content, R = F.render, I = R.input
        var rng = ConstantRandom(R.random)
        let S = SceneComposer.compose(I, content: K, rng: &rng)
        #expect(S.unported == nil)

        // G-버퍼 첫 그리기(배경) 정점
        var batch = SpriteBatch(); batch.append(S.background, atlas: K.sprites)
        let wv = R.bgVerts.map { Float($0) }
        #expect(batch.vertices.count == wv.count, Comment(rawValue: "\(name): 배경 정점 수 \(batch.vertices.count / 9) ≠ \(wv.count / 9)"))
        #expect(batch.vertices == wv, Comment(rawValue: "\(name): 배경 정점 불일치"))

        // 합성: 장면 광원(앞쪽) · 환경광 · 발광
        var comp = CompositeParams()
        comp.apply(S.lighting, shake: I.shake)
        let cu = R.composite, n = Int(cu["uLN"]?[0] ?? 0), k = min(n, comp.lights.count)
        #expect(k == comp.lights.count || n == 8, Comment(rawValue: "광원 수: 웹 \(n) · 장면 \(comp.lights.count)"))
        let LP = cu["uLP"] ?? [], LC = cu["uLC"] ?? [], LD = cu["uLD"] ?? []
        for i in 0..<k {
            let L = comp.lights[i]
            let got = [L.position, L.color, L.shape].flatMap { [$0.x, $0.y, $0.z, $0.w].map(Double.init) }
            let want = Array(LP[i * 4..<i * 4 + 4]) + Array(LC[i * 4..<i * 4 + 4]) + Array(LD[i * 4..<i * 4 + 4])
            #expect(near(got, want.map { Double(Float($0)) }, 1e-6), Comment(rawValue: "\(name) uL[\(i)] \(got) ≠ \(want)"))
        }
        #expect(near(Double(comp.ambient), Double(Float(cu["uAmb"]?[0] ?? -1)), 1e-6), "uAmb \(comp.ambient) ≠ \(cu["uAmb"] ?? [])")
        #expect(near(Double(comp.emitK), Double(Float(cu["uEmitK"]?[0] ?? -1)), 1e-6))

        // 후처리
        guard let pu = R.post else { Issue.record("\(name): 웹 후처리 없음"); return }
        let P = PostParams(scene: S.post, impactInvert: I.impactInvert, shake: I.shake)
        func f(_ k: String) -> [Double] { (pu[k] ?? []).map { Double(Float($0)) } }
        let d = { (v: Float) in Double(v) }
        #expect(near([d(P.exposure), d(P.windowReflection), d(P.windowY.x), d(P.windowY.y), d(P.pressure), d(P.bloom), d(P.reflectY)],
                     f("uExpo") + f("uWinR") + f("uWinY") + f("uPress") + f("uBloomK") + f("uReflY"), 1e-6), "\(name): 노출 · 창 · 블룸")
        #expect(near([d(P.grade.x), d(P.grade.y), d(P.grade.z), d(P.saturation), d(P.rain), P.invert ? 1 : 0, d(P.vignette), d(P.fog),
                      d(P.fogColor.x), d(P.fogColor.y), d(P.fogColor.z)],
                     f("uGrade") + f("uSat") + f("uRain") + f("uInv") + f("uVig") + f("uFog") + f("uFogC"), 1e-6), "\(name): 색 · 비 · 안개")
        let vn = Int(pu["uVN"]?[0] ?? 0)
        #expect(P.volumes.count == vn, Comment(rawValue: "\(name): 빛줄기 수 \(P.volumes.count) ≠ \(vn)"))
        let VP = f("uVP"), VC = f("uVC"), VD = f("uVD")
        for i in 0..<min(vn, P.volumes.count) {
            let (a, b, c) = P.volumes[i]
            let got = [a, b, c].flatMap { [$0.x, $0.y, $0.z, $0.w].map(Double.init) }
            #expect(near(got, Array(VP[i * 4..<i * 4 + 4]) + Array(VC[i * 4..<i * 4 + 4]) + Array(VD[i * 4..<i * 4 + 4]), 1e-6), Comment(rawValue: "\(name) 빛줄기[\(i)]"))
        }
    }

    @Test("이식 안 한 갈래는 알린다") func unported() {
        var I = SceneInput(); I.prologue = true
        var r = ConstantRandom(0)
        #expect(SceneComposer.compose(I, content: Shared.content, rng: &r).unported == "prologue")
    }
}
