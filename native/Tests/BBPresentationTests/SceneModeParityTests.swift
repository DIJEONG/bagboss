import Foundation
import Testing
import BBContent
@testable import BBPresentation
@testable import BBRender

// N5 장면(brawl 보너스 · 비 오는 거리 · 프롤로그 복도 · 무도장/건널목) 웹 대조: tools/js/extract/scenes.mjs 가 실제로 도는 웹판에서 기록한
// native/Tests/Fixtures/scenes/modes/<이름>.json 과 같은 출력인지.
//  ① 함수별: 배경 쿼드 · 배경 정점 · (brawl) 그림자 뒤 층 쿼드 · 3D 차 정점 · 맨 앞 쿼드 · 동적 광원 / (복도 · 무도장) 인물 앞 쿼드 ·
//           장면 광원 · 렌더 합성 · fx · 숨은 변경(invF · dentN · 복도 전등 생성 · 건널목 생성) · 난수 소비 개수
//  ② e2e: 같은 입력으로 웹 render() 전체를 돌린 스프라이트 그리기 구간 · 3D 정점 · uWin · 합성 · 후처리 유니폼 = 구성 → SceneAdapter 결과

private let modeDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/scenes/modes")

private struct ModeFixture: Decodable {
    let name: String
    let kind: String
    let input: SceneInput
    let rng: [Double]
    let rngSplit: [Int]
    let fn: Fn
    let render: Render
    struct Fn: Decodable {
        let quads: [[JSONValue]]
        let verts: [Double?]
        let mid: [[JSONValue]]
        let mesh: [Double]
        let front: [[JSONValue]]
        let dyn: [SceneLight]
        let lights: [SceneLight]
        let composed: Composed
        let fx: PostFX
        let after: After
    }
    struct Composed: Decodable { let lights: [SceneLight]; let ambient: Double; let emitK: Double }
    struct After: Decodable {
        let invF: Double
        let dentN: Int?
        let newLamps: [SceneInput.Corridor.Lamp]?
        let xc: SceneInput.Cross?
    }
    struct Render: Decodable {
        let input: SceneInput
        let random: Double
        let sprite: [[Double]]
        let mesh: [Double]
        let spriteU: [String: [Double]]
        let composite: [String: [Double]]
        let post: [String: [Double]]?
    }
}

private enum ModeShared {
    static let content: SceneContent = try! SceneContent.bundled()
    static let names: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: modeDir.path())) ?? [])
        .filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
}

private func load(_ name: String) throws -> ModeFixture {
    try JSONDecoder().decode(ModeFixture.self, from: Data(contentsOf: modeDir.appending(path: name + ".json")))
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
private func lightsDiff(_ name: String, _ what: String, _ a: [SceneLight], _ b: [SceneLight]) {
    #expect(a.count == b.count, Comment(rawValue: "\(name) \(what) 수 \(a.count) ≠ \(b.count)"))
    for (j, (x, y)) in zip(a, b).enumerated() { if let d = lightDiff(x, y) { Issue.record("\(name) \(what)[\(j)] \(d)") } }
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
/// 쿼드 목록 정확히 같은지([이름, x, y, flip, flash, depth, ox, remap, part])
private func quadsDiff(_ name: String, _ what: String, _ got: [SpriteDraw], _ want: [[JSONValue]]) {
    #expect(got.count == want.count, Comment(rawValue: "\(name) \(what): 쿼드 수 \(got.count) ≠ \(want.count)"))
    var bad = 0
    for (j, (q, w)) in zip(got, want).enumerated() {
        let wn = [w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8]].map { $0.double ?? .nan }
        let g = [q.x, q.y, q.flip, q.flash, q.depth, q.offsetX, q.remap, q.part]
        if !(q.name == w[0].string && zip(g, wn).allSatisfy { $0 == $1 || ($0.isNaN && $1.isNaN) }) {
            bad += 1; if bad <= 5 { Issue.record("\(name) \(what)[\(j)] \(q.name) \(g) ≠ \(w[0].string ?? "?") \(wn)") }
        }
    }
    #expect(bad == 0)
}
private func verts(_ d: [SpriteDraw]) -> [Float] { var b = SpriteBatch(); b.append(d, atlas: ModeShared.content.sprites); return b.vertices }
/// 3D 정점(10 float) 비교 — 위치 · 깊이는 1e-3 px, 나머지(노멀 · 재질 · 톤 · 부위 · 발광)는 1e-4
private func meshDiff(_ name: String, _ got: [Float], _ want: ArraySlice<Double>) -> Bool {
    guard got.count == want.count else { Issue.record("\(name): 3D 정점 수 \(got.count / 10) ≠ \(want.count / 10)"); return false }
    var bad = 0
    for (i, (g, w)) in zip(got, want).enumerated() where abs(Double(g) - w) > (i % 10 < 3 ? 1e-3 : 1e-4) {
        bad += 1; if bad <= 5 { Issue.record("\(name) 3D[\(i / 10)].\(i % 10) \(g) ≠ \(w)") }
    }
    return bad == 0
}

@Suite("N5 장면 구성 웹 대조(brawl · 복도 · 무도장)") struct SceneModeParityTests {
    @Test("픽스처가 있다") func hasFixtures() {
        #expect(ModeShared.names.count >= 10, Comment(rawValue: "native/Tests/Fixtures/scenes/modes — node tools/js/extract/scenes.mjs 로 찍는다"))
        #expect(ModeShared.content.carModel.count >= 20, "CAR_MODEL 을 못 읽음")
    }

    @Test("함수별 대조(쿼드 · 3D · 광원 · fx · 숨은 변경)", arguments: ModeShared.names)
    func functions(_ name: String) throws {
        let F = try load(name), K = ModeShared.content, I = F.input
        var rng = ReplayRandom(F.rng)
        var eff = SceneEffects(invF: Int(I.invF), eye: EyeAdaptState(adT: I.eye.adT, outS: I.eye.outS, darkA: I.eye.darkA, adA: I.eye.adA))
        #expect(SceneComposer.unported(I) == nil)

        if F.kind == "brawl" {
            let B = try #require(I.brawl), N = NoirContext(I: I, K: K, B: B)
            let back = N.background()
            quadsDiff(name, "배경", back, F.fn.quads)
            #expect(verts(back) == F.fn.verts.map { Float($0 ?? .nan) }, Comment(rawValue: "\(name): 배경 정점"))
            #expect(rng.used == F.rngSplit[0])
            var P = Painter(K.sprites), mesh: [Float] = [], dyn: [SceneLight] = []
            N.drawMid(&P, &mesh, &dyn, &eff, &rng)
            quadsDiff(name, "소품 · 입자 · 물건", P.out, F.fn.mid)
            #expect(meshDiff(name, mesh, F.fn.mesh[...]))
            lightsDiff(name, "동적 광원", dyn, F.fn.dyn)
            #expect(rng.used == F.rngSplit[1], Comment(rawValue: "난수 소비 \(rng.used) ≠ \(F.rngSplit[1])"))
            quadsDiff(name, "맨 앞 차", N.drawTop(), F.fn.front)
            let raw = N.noirLights()
            lightsDiff(name, "noirLights", raw, F.fn.lights)
            let lit = N.lighting(raw, dyn: dyn)
            lightsDiff(name, "합성 광원", lit.lights, F.fn.composed.lights)
            #expect(lit.ambient == F.fn.composed.ambient && lit.emitK == F.fn.composed.emitK)
            if let d = fxDiff(N.fx(), F.fn.fx) { Issue.record("\(name) fx \(d)") }
            #expect(eff.dentN == F.fn.after.dentN, Comment(rawValue: "dentN \(eff.dentN as Any) ≠ \(F.fn.after.dentN as Any)"))
            #expect(rng.used == F.rng.count)
            return
        }

        // 복도 · 무도장: 지하철 장면 함수가 갈래를 고른다
        let back = SceneComposer.background(I, K, &eff, &rng)
        quadsDiff(name, "배경", back, F.fn.quads)
        #expect(verts(back) == F.fn.verts.map { Float($0 ?? .nan) }, Comment(rawValue: "\(name): 배경 정점"))
        #expect(rng.used == F.rngSplit[0], Comment(rawValue: "배경 난수 소비 \(rng.used) ≠ \(F.rngSplit[0])"))
        let I2 = SceneComposer.applyEffects(I, eff)
        let lights = SceneComposer.sceneLights(I2, K, &rng)
        #expect(rng.used == F.rngSplit[1])
        lightsDiff(name, "장면 광원", lights, F.fn.lights)
        let lit = SceneComposer.lighting(I2, lights)
        lightsDiff(name, "합성 광원", lit.lights, F.fn.composed.lights)
        #expect(near(lit.ambient, F.fn.composed.ambient, 1e-9), Comment(rawValue: "uAmb \(lit.ambient) ≠ \(F.fn.composed.ambient)"))
        #expect(near(lit.emitK, F.fn.composed.emitK, 1e-9))
        let fx = SceneComposer.postFX(I2, K, &eff)
        if let d = fxDiff(fx, F.fn.fx) { Issue.record("\(name) fx \(d)") }
        quadsDiff(name, "인물 앞", SceneComposer.front(I2, K), F.fn.front)
        #expect(rng.used == F.rng.count, Comment(rawValue: "난수 소비 \(rng.used) ≠ \(F.rng.count)"))
        #expect(Double(eff.invF) == F.fn.after.invF, Comment(rawValue: "invF \(eff.invF) ≠ \(F.fn.after.invF)"))
        // 숨은 변경: 복도 전등 처음 만들기 · 건널목 처음 만들기
        let wantLamps = F.fn.after.newLamps ?? []
        #expect(eff.corridorLamps.map(\.wx).sorted() == wantLamps.map(\.wx).sorted(), Comment(rawValue: "새 전등 \(eff.corridorLamps) ≠ \(wantLamps)"))
        for L in wantLamps { if let g = eff.corridorLamps.first(where: { $0.wx == L.wx }), g.a != L.a { Issue.record("\(name) 전등 \(L.wx) 각 \(g.a) ≠ \(L.a)") } }
        if let X = F.fn.after.xc {
            let G = try #require(eff.cross, "건널목 상태를 만들지 않음")
            #expect(G.nextT == X.nextT && G.leaves.count == X.leaves.count)
            #expect(zip(G.leaves, X.leaves).allSatisfy { $0.x == $1.x && $0.gy == $1.gy && $0.ph == $1.ph && $0.rot == $1.rot && $0.c == $1.c && $0.s == $1.s },
                    "건널목 단풍(xcReset) 불일치")
        } else { #expect(eff.cross == nil) }
    }

    @Test("e2e: 구성 → RenderFrame 조각 = 웹 render() 그리기 · 유니폼", arguments: ModeShared.names)
    func endToEnd(_ name: String) throws {
        let F = try load(name), K = ModeShared.content, R = F.render, I = R.input
        var rng = ConstantRandom(R.random)
        let S = SceneComposer.compose(I, content: K, rng: &rng)
        #expect(S.unported == nil)
        // 스프라이트 그리기 구간: [0] 배경 · [1] 그림자 · [2] 그림자 뒤(장면 mid 가 앞머리) · [3] 3D 뒤 앞 효과(장면 front 포함 · top 이 꼬리)
        #expect(R.sprite.count >= 3)
        #expect(verts(S.background) == R.sprite[0].map { Float($0) }, Comment(rawValue: "\(name): 배경 정점(\(S.background.count) 쿼드 · 웹 \(R.sprite[0].count / 54))"))
        let mid = verts(S.mid).map(Double.init)
        #expect(R.sprite[2].count >= mid.count && Array(R.sprite[2].prefix(mid.count)).map { Double(Float($0)) } == mid, Comment(rawValue: "\(name): 그림자 뒤 층 앞머리"))
        let last = R.sprite.count > 3 ? R.sprite[3] : []
        let top = verts(S.top).map(Double.init)
        #expect(last.count >= top.count && Array(last.suffix(top.count)).map { Double(Float($0)) } == top, Comment(rawValue: "\(name): 맨 앞 층 꼬리"))
        let fr = verts(S.front).map(Double.init)
        if !fr.isEmpty {
            let lf = last.map { Double(Float($0)) }
            let found = lf.count >= fr.count && stride(from: 0, through: lf.count - fr.count, by: 9).contains { Array(lf[$0..<$0 + fr.count]) == fr }
            #expect(found, Comment(rawValue: "\(name): 인물 앞 층(단풍)이 웹 앞 효과 구간에 없음"))
        }
        // 3D: 장면 차가 인물보다 먼저
        #expect(R.mesh.count >= S.mesh.count)
        if !S.mesh.isEmpty { #expect(meshDiff(name + " e2e", S.mesh, R.mesh[0..<S.mesh.count])) }
        if let w = R.spriteU["uWin"]?.first { #expect(Float(w) == Float(S.windowLight), Comment(rawValue: "uWin \(S.windowLight) ≠ \(w)")) }

        // 합성: 장면 광원(앞쪽) · 환경광 · 발광
        var comp = CompositeParams()
        comp.apply(S.lighting, shake: I.shake)
        let cu = R.composite, n = Int(cu["uLN"]?[0] ?? 0), k = min(n, comp.lights.count)
        let LP = cu["uLP"] ?? [], LC = cu["uLC"] ?? [], LD = cu["uLD"] ?? []
        for i in 0..<k {
            let L = comp.lights[i]
            let got = [L.position, L.color, L.shape].flatMap { [$0.x, $0.y, $0.z, $0.w].map(Double.init) }
            let want = Array(LP[i * 4..<i * 4 + 4]) + Array(LC[i * 4..<i * 4 + 4]) + Array(LD[i * 4..<i * 4 + 4])
            #expect(near(got, want.map { Double(Float($0)) }, 1e-6), Comment(rawValue: "\(name) uL[\(i)] \(got) ≠ \(want)"))
        }
        #expect(near(Double(comp.ambient), Double(Float(cu["uAmb"]?[0] ?? -1)), 1e-6), "uAmb \(comp.ambient) ≠ \(cu["uAmb"] ?? [])")
        #expect(near(Double(comp.emitK), Double(Float(cu["uEmitK"]?[0] ?? -1)), 1e-6))

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

    @Test("그리기 상태가 없으면 알린다") func unportedBranches() {
        var r = ConstantRandom(0)
        var I = SceneInput(); I.scene = "brawl"
        #expect(SceneComposer.compose(I, content: ModeShared.content, rng: &r).unported == "brawl")
        I = SceneInput(); I.dojo = true
        #expect(SceneComposer.compose(I, content: ModeShared.content, rng: &r).unported == "dojo")
        I.dojoRoom = .init()
        let f = SceneComposer.compose(I, content: ModeShared.content, rng: &r)
        #expect(f.unported == nil && !f.background.isEmpty && f.effects.cross != nil)
    }
}
