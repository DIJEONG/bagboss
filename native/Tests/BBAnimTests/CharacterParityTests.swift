import Testing
import Foundation
@testable import BBAnim
import BBContent

/// 웹 캐릭터 픽스처(tools/js/extract/characters.mjs)와 단계별 대조: 포즈 → 관절 → 뼈 → 메시 · 얼굴
@Suite(.serialized) struct CharacterParityTests {
    static let fixtureURL = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/characters.json.deflate")
    static let fx: Fixture = {
        let d = try! Data(contentsOf: fixtureURL)
        return try! JSONDecoder().decode(Fixture.self, from: (d as NSData).decompressed(using: .zlib) as Data)
    }()
    static let tables = try! AnimTables(ContentStore.bundled())

    // MARK: 픽스처 모양
    struct Fixture: Decodable { let models: [String: Model3]; let samples: [Sample] }
    struct Sample: Decodable {
        let scene: String, shot: Int, hero: Bool, model: String, rig: RigDims, gameTime: Double, shades: Bool
        let before: State, after: State
        let bones: BonesRec?
        let mesh: MeshRec?
        let face: FaceRec?
    }
    struct D: Decodable { let x: Double; let y: Double; let flip: Bool; let gait: Bool?; let jw: Bool? }
    struct Jug: Decodable { let roll: Double?; let kick: Double? }
    struct State: Decodable {
        let anim: String, pose: String, prev: String?, k: Int?, phaseN: Int?
        let gph: Double?, guardW: Double?, runU: Double?, legRun: Bool?, airOv: Double?, tilt: Double?, flash: Double?
        let _vr: Double?, _va: Double?, _vt: Double?, _an: String?, _rgo: Bool?, bT0: Double?, bDur: Double?, gres: Double?
        let bFrom: Pose?, lastP: Pose?, jug: Jug?, d: D, wpn: String?, remap: Int?
        var actor: ActorPose {
            var a = ActorPose(anim: anim, pose: pose)
            a.prev = prev; a.k = k ?? 0; a.phaseN = phaseN ?? 1; a.gph = gph; a.guardW = guardW; a.runU = runU; a.legRun = legRun ?? false
            if let jug { a.jug = (jug.roll, jug.kick) }
            a.airOv = airOv; a.tilt = tilt; a.vr = _vr; a.va = _va; a.vt = _vt; a.lastAnim = _an; a.rgo = _rgo
            a.blendFrom = bFrom; a.blendT0 = bT0; a.blendDur = bDur; a.lastPose = lastP; a.gres = gres
            return a
        }
    }
    struct J: Decodable {
        let hips: V2, neck: V2, head: V2, legF: V2, legB: V2, kneeF: V2, kneeB: V2, footF: V2, footB: V2
        let shF: V2, shB: V2, elbF: V2, elbB: V2, handF: V2, handB: V2, zF: Double, zB: Double, wpn: String?
    }
    struct BoneRec: Decodable { let x: Double?, y: Double?, z: Double?, th: Double?, yaw: Double?, sy: Double?, ab: Bone.Abduct?, px: Double?, py: Double?, c: Double?, s: Double? }
    struct BonesRec: Decodable { let j: J; let P: Pose; let tq: Double; let B: [String: BoneRec] }
    struct MeshRec: Decodable { let ox: Double, oy: Double, flash: Bool, remap: Int, verts: String }
    struct FaceRec: Decodable { let key: String, ox: Double, oy: Double, verts: String }

    static let boneOrder = ["torso", "head", "skirtF", "skirtB", "thighF", "shinF", "thighB", "shinB", "footF", "footB", "uarmF", "farmF", "uarmB", "farmB"]
    static func skeleton(_ B: [String: BoneRec]) -> Skeleton {
        let extra = B.keys.filter { !boneOrder.contains($0) && !$0.hasPrefix("_") }
        let names = boneOrder + extra
        var sk = Skeleton(bones: names.compactMap { n in B[n].map { (name: n, bone: Bone(x: $0.x!, y: $0.y!, z: $0.z ?? 0, th: $0.th ?? 0, yaw: $0.yaw, sy: $0.sy, ab: $0.ab)) } })
        if let s = B["_spin"] { sk.spin = BodySpin(px: s.px!, c: s.c!, s: s.s!) }
        if let r = B["_roll"] { sk.roll = BodyRoll(px: r.px!, py: r.py!, c: r.c!, s: r.s!) }
        return sk
    }
    static func floats(_ b64: String) -> [Float] {
        let d = Data(base64Encoded: b64)!
        return d.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
    static func close(_ a: Double?, _ b: Double?, _ eps: Double = 1e-9) -> Bool {
        let an = a.map { $0.isNaN ? nil : $0 } ?? nil, bn = b.map { $0.isNaN ? nil : $0 } ?? nil
        switch (an, bn) { case (nil, nil): return true; case let (x?, y?): return abs(x - y) <= eps * max(1, abs(x), abs(y)); default: return false }
    }
    static func close(_ a: V2?, _ b: V2?, _ eps: Double = 1e-9) -> Bool { close(a?.x, b?.x, eps) && close(a?.y, b?.y, eps) }

    static func poseDiff(_ a: Pose, _ b: Pose) -> [String] {
        var bad: [String] = []
        let d: [(String, KeyPath<Pose, Double?>)] = [("r", \.r), ("t", \.t), ("ty", \.ty), ("air", \.air), ("spin", \.spin), ("roll", \.roll), ("aF", \.aF), ("aB", \.aB),
            ("eF", \.eF), ("eB", \.eB), ("strF", \.strF), ("strB", \.strB), ("w", \.w), ("uF", \.uF), ("lF", \.lF), ("uB", \.uB), ("lB", \.lB), ("strL", \.strL),
            ("spr", \.spr), ("sprF", \.sprF), ("sprB", \.sprB), ("lFT", \.lFT), ("lFK", \.lFK), ("lBT", \.lBT), ("lBK", \.lBK), ("legH", \.legH), ("tail", \.tail)]
        for (n, k) in d where !close(a[keyPath: k], b[keyPath: k]) { bad.append("\(n) \(String(describing: a[keyPath: k])) ≠ \(String(describing: b[keyPath: k]))") }
        let v: [(String, KeyPath<Pose, V2?>)] = [("b", \.b), ("h", \.h), ("fF", \.fF), ("fB", \.fB)]
        for (n, k) in v where !close(a[keyPath: k], b[keyPath: k]) { bad.append("\(n) \(String(describing: a[keyPath: k])) ≠ \(String(describing: b[keyPath: k]))") }
        if (a.armFK ?? false) != (b.armFK ?? false) { bad.append("armFK") }
        if a.smear != b.smear { bad.append("smear") }
        return bad
    }

    static func vertsDiff(_ mine: [Float], _ web: [Float]) -> String? {
        guard mine.count == web.count else { return "정점 수 \(mine.count / 10) ≠ \(web.count / 10)" }
        for i in mine.indices where abs(mine[i] - web[i]) > 1e-4 * max(1, abs(web[i])) { return "#\(i / 10)[\(i % 10)] \(mine[i]) ≠ \(web[i])" }
        return nil
    }

    var samples: [Sample] { Self.fx.samples.filter { $0.bones != nil } }

    // MARK: ④ 메시 · 얼굴
    @Test func meshMatchesWeb() throws {
        var fails: [String] = []
        for s in samples { guard let B = s.bones?.B, let m = s.mesh, let model = Self.fx.models[s.model] else { continue }
            var w = MeshWriter()
            emitModel(model, Self.skeleton(B), at: MeshPlacement(x: m.ox, y: m.oy, flip: s.before.d.flip, remap: m.remap, flash: m.flash), tables: Self.tables, into: &w)
            if let e = Self.vertsDiff(w.floats, Self.floats(m.verts)) { fails.append("\(s.scene)#\(s.shot) \(s.before.anim): \(e)") } }
        #expect(fails.isEmpty, "\(fails.count)/\(samples.count) 불일치: \(fails.prefix(3))")
    }

    @Test func faceMatchesWeb() throws {
        var fails: [String] = [], n = 0
        for s in samples { guard let f = s.face, let B = s.bones?.B else { continue }; n += 1
            let key = faceKey(anim: s.before.anim, flash: s.before.flash, footX: s.before.d.x, time: s.gameTime, tables: Self.tables)
            if key != f.key { fails.append("표정 \(key) ≠ \(f.key)"); continue }
            var w = MeshWriter()
            emitFace(key: f.key, head: Self.skeleton(B)["head"]!, at: MeshPlacement(x: f.ox, y: f.oy, flip: s.before.d.flip, remap: 0, flash: false),
                     shades: s.shades, isHero: s.hero, tables: Self.tables, into: &w)
            if let e = Self.vertsDiff(w.floats, Self.floats(f.verts)) { fails.append("\(s.before.anim): \(e)") } }
        #expect(n > 10 && fails.isEmpty, "\(fails.count)/\(n) 불일치: \(fails.prefix(3))")
    }

    // MARK: ③ 뼈
    @Test func skeletonMatchesWeb() throws {
        var fails: [String] = []
        for s in samples { let r = s.bones!
            let j = Joints(hips: r.j.hips, neck: r.j.neck, head: r.j.head, legF: r.j.legF, legB: r.j.legB, kneeF: r.j.kneeF, kneeB: r.j.kneeB,
                           footF: r.j.footF, footB: r.j.footB, shF: r.j.shF, shB: r.j.shB, elbF: r.j.elbF, elbB: r.j.elbB, handF: r.j.handF, handB: r.j.handB,
                           zF: r.j.zF, zB: r.j.zB, weapon: r.j.wpn)
            let mine = makeSkeleton(j, pose: r.P), web = Self.skeleton(r.B)
            for (n, b) in web.bones { guard let m = mine[n] else { fails.append("뼈 없음 \(n)"); continue }
                if !(Self.close(m.x, b.x) && Self.close(m.y, b.y) && Self.close(m.z, b.z) && Self.close(m.th, b.th) && Self.close(m.yaw, b.yaw) && Self.close(m.sy, b.sy) && m.ab == b.ab) {
                    fails.append("\(s.before.anim) \(n): \(m) ≠ \(b)") } }
            if mine.bones.map(\.name) != web.bones.map(\.name) { fails.append("순서 \(mine.bones.map(\.name))") }
            if (mine.spin == nil) != (web.spin == nil) || (mine.roll == nil) != (web.roll == nil) { fails.append("spin/roll") } }
        #expect(fails.isEmpty, "\(fails.count) 불일치: \(fails.prefix(3))")
    }

    // MARK: ② 관절
    @Test func jointsMatchWeb() throws {
        var fails: [String] = []
        for s in samples { let r = s.bones!, b = s.before
            let walkG = (b.d.gait ?? false) && b.anim == "walk" && !((b.runU ?? -.infinity) > s.gameTime)
            let (j, tq) = solveJoints(r.P, rig: s.rig, input: JointInput(tilt: b.tilt, airOv: b.airOv, walkResidual: walkG ? s.after.gres : nil, weaponSprite: b.wpn))
            let pairs: [(String, V2, V2)] = [("hips", j.hips, r.j.hips), ("neck", j.neck, r.j.neck), ("head", j.head, r.j.head), ("kneeF", j.kneeF, r.j.kneeF),
                ("kneeB", j.kneeB, r.j.kneeB), ("footF", j.footF, r.j.footF), ("footB", j.footB, r.j.footB), ("shF", j.shF, r.j.shF), ("shB", j.shB, r.j.shB),
                ("elbF", j.elbF, r.j.elbF), ("elbB", j.elbB, r.j.elbB), ("handF", j.handF, r.j.handF), ("handB", j.handB, r.j.handB)]
            let bad = pairs.filter { !Self.close($0.1, $0.2, 1e-7) }.map { "\($0.0) \($0.1) ≠ \($0.2)" }
            if !bad.isEmpty || !Self.close(tq, r.tq) || j.weapon != r.j.wpn { fails.append("\(b.anim)/\(b.pose): \(bad.prefix(2)) tq \(tq)/\(r.tq) wpn \(String(describing: j.weapon))/\(String(describing: r.j.wpn))") } }
        #expect(fails.isEmpty, "\(fails.count)/\(samples.count) 불일치: \(fails.prefix(3))")
    }

    // MARK: ① 포즈 평가(보간 · 보행 · 블렌드 · 주인공 추종)
    @Test func poseMatchesWeb() throws {
        var fails: [String] = []
        for s in samples { let r = s.bones!
            var a = s.before.actor
            let traits = ActorTraits(gait: s.before.d.gait ?? false, jw: s.before.d.jw ?? false, isHero: s.hero)
            let ev = evaluatePose(&a, traits: traits, rig: s.rig, time: s.gameTime, tables: Self.tables)
            let pd = Self.poseDiff(ev.pose, r.P)
            var st: [String] = []
            let after = s.after
            if a.lastAnim != after._an { st.append("_an") }
            if !Self.close(a.vr, after._vr) || !Self.close(a.va, after._va) { st.append("_vr/_va \(String(describing: a.vr))/\(String(describing: after._vr))") }
            if (a.blendFrom == nil) != (after.bFrom == nil) { st.append("bFrom") }
            if !Self.close(a.blendDur, after.bDur) || !Self.close(a.blendT0, after.bT0) { st.append("bDur/bT0") }
            if !Self.close(a.gres, after.gres) { st.append("gres") }
            if !pd.isEmpty || !st.isEmpty { fails.append("\(s.before.anim)/\(s.before.pose)\(s.hero ? "(주인공)" : "") 포즈 \(pd.prefix(3)) 상태 \(st)") } }
        #expect(fails.isEmpty, "\(fails.count)/\(samples.count) 불일치: \(fails.prefix(4))")
    }
}
