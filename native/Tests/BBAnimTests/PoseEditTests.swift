import Testing
import Foundation
@testable import BBAnim
import BBContent

/// 자세 편집기 핵심(PoseEdit · PoseOverrides — 웹 14-pose-editor.js) 점검:
///   수정분 왕복(diff → 저장 글 → 읽기 → apply) · 되돌리기 · 옛 방식 → 각도 값 변환이 관절 위치를 1px 안에서 지키는지 · 덮어쓰기 층이 꺼지면 같은 자세
/// 덮어쓰기 층은 프로세스 전역이다 — 다른 테스트와 겹치지 않게 이 묶음만 쓰는 가짜 이름(__pe_test)으로만 덮는다.
@Suite(.serialized) struct PoseEditTests {
    static let store = try! ContentStore.bundled()
    static let tables = try! AnimTables(store).withNativeMoves()
    static let rig = try! CharacterDef.load(store, "JW_HERO").rig
    static func ctl(_ n: String) -> PoseEdit.Control { PoseEdit.controls.first { $0.name == n }! }

    @Test("수정분 왕복: 고친 자세 → diff → 저장 글 → 읽기 → apply 가 같은 자세 · 되돌리면 원본")
    func diffRoundTrip() throws {
        for name in ["kl_hit", "du_jab", "ts_hit"] {
            let O = try #require(Self.tables.poses[name], "\(name) 없음")
            var P = PoseEdit.edit(O, Self.ctl("앞 위팔"), 45, rig: Self.rig)
            P = PoseEdit.edit(P, Self.ctl("뒤 무릎"), -60, rig: Self.rig)
            P = PoseEdit.edit(P, Self.ctl("몸 회전"), 30, rig: Self.rig)
            P = PoseEdit.edit(P, Self.ctl("공중 높이"), 7, rig: Self.rig)
            let d = PoseEdit.diff(P, from: O)
            #expect(!d.isEmpty)
            #expect(Set(d.keys).isSubset(of: Set(PoseEdit.fields)))
            let text = PoseEdit.encode([name: d, "빈것": [:]])
            let back = PoseEdit.decode(text)
            #expect(back.keys.sorted() == [name])   // 빈 수정분은 저장하지 않는다
            #expect(PoseEdit.apply(try #require(back[name]), to: O) == P)
            // 골반을 바닥에 맞추기(legH 지우기)도 왕복
            let F = PoseEdit.floor(P, rig: Self.rig)
            #expect(F.legH == nil)
            let dF = PoseEdit.decode(PoseEdit.encode([name: PoseEdit.diff(F, from: O)]))[name] ?? [:]
            #expect(PoseEdit.apply(dF, to: O) == F)
            // 되돌리기 = 수정분 없음
            #expect(PoseEdit.diff(O, from: O).isEmpty)
            #expect(PoseEdit.apply([:], to: O) == O)
        }
        #expect(PoseEdit.decode("깨진 글").isEmpty)
        #expect(PoseEdit.decode(nil).isEmpty)
    }

    @Test("조절값 매핑(웹 PE_CTL): 슬라이더에 쓴 값이 그대로 읽힌다 · 위팔을 돌려도 굽힘은 그대로")
    func controlMapping() throws {
        let O = try #require(Self.tables.poses["kl_hit"])
        for c in PoseEdit.controls {
            let v = (c.min + c.max) / 2 + 7
            let P = PoseEdit.edit(O, c, v, rig: Self.rig)
            #expect(abs(try #require(c.read(P)) - v) < 1e-9, "\(c.name)")
            #expect(PoseEdit.shown(c, P) == Int(jsRound(v)))
        }
        let A = PoseEdit.edit(O, Self.ctl("앞 굽힘"), 40, rig: Self.rig), B = PoseEdit.edit(A, Self.ctl("앞 위팔"), -20, rig: Self.rig)
        #expect(PoseEdit.shown(Self.ctl("앞 굽힘"), B) == 40)
        // 옛 방식 자세의 다리 무리는 0 으로 보인다(웹과 같게)
        let du = try #require(Self.tables.poses["du_jab"])
        #expect(PoseEdit.shown(Self.ctl("앞 허벅지"), du) == 0)
    }

    /// 관절 풀이 결과를 비교한다(늘인 팔 · 다리 끝은 각도 값으로 담을 수 없어 뺀다)
    static func compare(_ name: String, _ P: Pose) -> (worst: Double, at: String) {
        let input = JointInput(tilt: nil, airOv: nil, walkResidual: nil, weaponSprite: nil)
        let a = solveJoints(P, rig: rig, input: input).0, b = solveJoints(PoseEdit.toFK(P, rig: rig), rig: rig, input: input).0
        var pts: [(String, V2, V2)] = [("hips", a.hips, b.hips), ("head", a.head, b.head), ("neck", a.neck, b.neck),
                                       ("kneeB", a.kneeB, b.kneeB), ("footB", a.footB, b.footB)]
        if P.armFK != true {
            // 늘인 아래팔(str ≠ 1)은 IK 가 늘인 길이로 팔꿈치를 풀어 팔꿈치 · 손 모두 각도 값으로 담을 수 없다
            if or(P.strF, 1) == 1 { pts += [("handF", a.handF, b.handF), ("elbF", a.elbF, b.elbF)] }
            if or(P.strB, 1) == 1 { pts += [("handB", a.handB, b.handB), ("elbB", a.elbB, b.elbB)] }
        }
        if or(P.strL, 1) == 1 { pts += [("kneeF", a.kneeF, b.kneeF), ("footF", a.footF, b.footF)] }
        var w = (0.0, "")
        for (n, p, q) in pts where p.x.isFinite && p.y.isFinite {
            let d = max(abs(p.x - q.x), abs(p.y - q.y)); if d > w.0 { w = (d, n) }
        }
        return w
    }

    @Test("옛 방식 → 각도 값(peToFK): kl_hit · du_jab · 웹 자세들의 관절이 1px 안에서 그대로")
    func toFKKeepsJoints() throws {
        for name in ["kl_hit", "du_jab", "ts_hit", "du_up", "kl_drive", "dr_hL", "dr_wL"] {
            let P = try #require(Self.tables.poses[name], "\(name) 없음")
            let r = Self.compare(name, P)
            #expect(r.worst <= 1, "\(name): \(r.at) \(r.worst)px")
            let F = PoseEdit.toFK(P, rig: Self.rig)
            #expect(F.armFK == true && F.legFK == true)
            if P.legFK != true { #expect(F.legH != nil) }
            #expect(PoseEdit.toFK(F, rig: Self.rig) == F)   // 이미 각도 값이면 그대로
        }
        // 표 전체(관절이 유한한 자세만): 늘이기 없는 관절은 모두 1px 안
        var bad: [String] = []
        for (name, P) in Self.tables.poses where P.b != nil {
            let r = Self.compare(name, P)
            if r.worst > 1 { bad.append("\(name):\(r.at)=\(String(format: "%.2f", r.worst))") }
        }
        #expect(bad.isEmpty, "\(bad.sorted().prefix(20))")
    }

    @Test("덮어쓰기 층: 비어 있으면 원래 조회와 같다 · 넣으면 그 이름만 · 지우면 다시 같다")
    func overrideLayer() throws {
        PoseOverrides.removeAll()
        #expect(!PoseOverrides.active)
        for (k, P) in Self.tables.poses { #expect(Self.tables.poses[live: k] == P) }
        // 이 테스트 전용 표(다른 테스트가 같은 이름을 읽지 않는다)
        let O = try #require(Self.tables.poses["kl_hit"])
        let mine: [String: Pose] = ["__pe_test": O, "__pe_other": O]
        let E = PoseEdit.edit(O, Self.ctl("공중 높이"), 30, rig: Self.rig)
        PoseOverrides.set("__pe_test", E)
        PoseOverrides.set("__pe_absent", E)
        #expect(PoseOverrides.active)
        #expect(mine[live: "__pe_test"] == E)
        #expect(mine[live: "__pe_other"] == O)
        #expect(mine[live: "__pe_absent"] == nil)   // 표에 없는 이름은 덮지 않는다
        // 자세 평가(그리기 경로)도 덮은 값을 쓴다
        var t = Self.tables; t.poses = mine
        var s = ActorPose(anim: "__hold", pose: "__pe_test")
        let ev = evaluatePose(&s, traits: ActorTraits(gait: false, jw: true, isHero: false), rig: Self.rig, time: 0, tables: t)
        #expect(ev.pose.air == 30)
        PoseOverrides.set("__pe_test", nil); PoseOverrides.set("__pe_absent", nil)
        #expect(!PoseOverrides.active)
        #expect(mine[live: "__pe_test"] == O)
        var s2 = ActorPose(anim: "__hold", pose: "__pe_test")
        #expect(evaluatePose(&s2, traits: ActorTraits(gait: false, jw: true, isHero: false), rig: Self.rig, time: 0, tables: t).pose == O)
    }

    @Test("값 복사 글: 웹 줄(이름: {…},) · 수정분 줄 · Swift 줄")
    func copyLines() throws {
        let O = try #require(Self.tables.poses["du_jab"])
        let P = PoseEdit.edit(O, Self.ctl("앞 위팔"), 0, rig: Self.rig)
        let w = PoseEdit.webLine("du_jab", P)
        #expect(w.hasPrefix("du_jab: {") && w.hasSuffix("},"))
        #expect(w.contains("\"armFK\":true") && w.contains("\"legFK\":true"))
        let json = String(w.dropFirst("du_jab: ".count).dropLast())
        let v = try JSONValue.parse(Data(json.utf8))
        #expect(v["uF"]?.double == P.uF)
        #expect(v["b"]?.array?.count == 2)
        let s = PoseEdit.swiftLine("du_jab", P)
        #expect(s.hasPrefix("\"du_jab\": { var p = Pose(); ") && s.hasSuffix("return p }(),"))
        #expect(s.contains("p.armFK = true") && s.contains("p.b = V2("))
        #expect(PoseEdit.diffLine("du_jab", PoseEdit.diff(P, from: O)).contains("\"armFK\":true"))
    }
}
