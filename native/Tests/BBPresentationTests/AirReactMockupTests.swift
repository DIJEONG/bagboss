import Testing
import Foundation
import BBCore
import BBContent
@testable import BBAnim
@testable import BBSim
@testable import BBRender
import BBPresentation

/// 공중(저글) 피격 반응 다양화 — 자세 목업만(감독 결정 전 · 게임 경로에 연결하지 않는다). BB_DUMP=1 일 때만
/// → tools/js/out/hitreact/air_mockup.png
///   줄 1 기준(웹 공중 자세 air_up · air_hit · air_back · air_fall)
///   줄 2 A 타격마다 움찔(정점) A1 머리 · A2 몸통 접힘 · A3 올려 치기(다리가 머리 위로) · A4 위에서 눌림
///   줄 3 A2 전 → 정점 → 돌아옴(0.25)
///   줄 4 B 저글 누적 무너짐 B1 1타 웅크림 · B2 2~3타 풀림 · B3 꼭대기 축 늘어짐 · B4 떨어지며 머리부터
///   줄 5~6 C 몸무게(A2 · B3) — 신문팔이(×1.4) · 불량배(×1) · 라인배커(×0.5)
/// 칸마다 오른쪽에 같은 자세 + 저글 구르기 0.15바퀴. 칸 아래: 이름 · 목 틈/길이(목 켬)
@Suite(.serialized) struct AirReactMockupTests {
    typealias D = ReactDelta
    /// 목업 자세: (이름, 기준 웹 자세, 델타)
    static let A: [(String, String, D)] = [
        ("A1 머리", "air_hit", D(hx: -1, hy: -0.5, t: -1.6, aF: 2.5, aB: 2.2)),
        ("A2 몸통 ㄱ자", "air_back", D(r: 2, by: -2, hx: 1, hy: 1, t: 5.2, fFx: 0.15, fFy: -0.55, fBx: 0.2, fBy: -0.6, aF: -3, aB: -3)),
        ("A3 올려 치기", "air_back", D(r: 3, by: 1, t: -3.6, fFx: -0.45, fFy: -1.1, fBx: -0.35, fBy: -1.0, aF: 1.5, aB: 1.5)),
        ("A4 위에서", "air_fall", D(by: 4, hy: 0.6, t: 1.2, fFx: -0.1, fFy: -0.5, fBx: -0.2, fBy: -0.4, aF: 3, aB: 3.4)),
    ]
    static let B: [(String, String, D)] = [
        ("B1 1타 웅크림", "air_up", D(r: 2, hy: 0.5, t: 2.6, fFx: -0.1, fFy: -0.35, fBx: 0.05, fBy: -0.45, aF: -4, aB: -3.6)),
        ("B2 2~3타 풀림", "air_back", D(t: 0.4, fFx: 0.15, fFy: 0.15, fBx: -0.45, fBy: -0.25, aF: 2.6, aB: -2.4)),
        ("B3 꼭대기 축", "air_back", D(by: 1, hx: -0.5, t: -1.2, fFx: 0.2, fFy: 0.25, fBx: -0.3, fBy: 0.25, aF: 3.4, aB: 4.2)),
        ("B4 머리부터", "air_fall", D(r: 3, hy: 1, t: -2.4, fFx: -0.3, fFy: -0.6, fBx: -0.2, fBy: -0.5, aF: 3, aB: 3.6)),
    ]

    static func pose(_ T: AnimTables, _ base: String, _ d: D) -> Pose { var P = T.poses[base]!; HitReactState.add(d, to: &P); return P }

    struct Cell { var mesh: [Float]; var label: String; var gap: Double; var len: Double }

    /// 자세 하나 그리기(공중 12px · 구르기) + 목 재기
    static func cell(_ C: HitReactStripTests.Ctx, _ S: NeckAuditTests.Subject, _ P: Pose, _ name: String, roll: Double) -> Cell {
        var T = C.tables; T.poses["__mock"] = P
        var r = NeckAuditTests.rig(S)
        r.actor = ActorPose(anim: "jug", pose: "__mock"); r.actor.airOv = 12
        if roll != 0 { r.actor.hasJug = true; r.actor.jugRoll = roll }
        var w = MeshWriter(); r.emit(time: 10, dt: 1.0 / 60, style: .on, tables: T, into: &w)
        let m = NeckAuditTests.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220)
        return Cell(mesh: w.floats, label: name + (roll != 0 ? " +구름" : "") + String(format: " 틈%.1f 목%.1f", m.gap, m.len), gap: m.gap, len: m.len)
    }

    @Test(.enabled(if: HitReactStripTests.dump)) func airMockup() throws {
        let C = try HitReactStripTests.Ctx()
        let thug = C.subject("불량배"), news = C.subject("신문팔이"), line = C.subject("라인배커")
        var rows: [(String, [Cell])] = []
        func pair(_ S: NeckAuditTests.Subject, _ P: Pose, _ n: String) -> [Cell] { [Self.cell(C, S, P, n, roll: 0), Self.cell(C, S, P, n, roll: 0.15)] }
        rows.append(("1 · 기준(웹 공중 자세) — 칸마다 오른쪽 = 구르기 0.15바퀴", ["air_up", "air_hit", "air_back", "air_fall"].flatMap { pair(thug, C.tables.poses[$0]!, $0) }))
        rows.append(("2 · A 타격마다 움찔(정점 · 0.1~0.2초 덧셈)", Self.A.flatMap { pair(thug, Self.pose(C.tables, $0.1, $0.2), $0.0) }))
        let a2 = Self.A[1]
        rows.append(("3 · A2 전 → 정점 → 돌아옴(정점의 25%)", [Self.cell(C, thug, C.tables.poses[a2.1]!, "전 \(a2.1)", roll: 0), Self.cell(C, thug, Self.pose(C.tables, a2.1, a2.2), "정점", roll: 0),
                                                       Self.cell(C, thug, Self.pose(C.tables, a2.1, a2.2 * 0.25), "돌아옴", roll: 0)]))
        rows.append(("4 · B 저글 누적 무너짐", Self.B.flatMap { pair(thug, Self.pose(C.tables, $0.1, $0.2), $0.0) }))
        for (lab, pick) in [("A2", Self.A[1]), ("B3", Self.B[2])] {
            var cs: [Cell] = []
            for (nm, S, key) in [("신문팔이×1.4", news, "nv_newsboy"), ("불량배×1", thug, "punk"), ("라인배커×0.5", line, "nv_lineback")] {
                let k = HitReact.mass(type: key, hero: false, boss: false).amp
                cs += pair(S, Self.pose(C.tables, pick.1, pick.2 * k), "\(lab) \(nm)")
            }
            rows.append(("\(rows.count + 1) · C 몸무게 — \(lab)", cs))
        }
        // 목 표(콘솔)
        for (t, cs) in rows { for c in cs { print(String(format: "[air] %@ | %@ | 틈 %.1f · 목 %.1f", t.prefix(12).description, c.label, c.gap, c.len)) } }
        try HitReactStripTests.sheet(C, rows: rows.map { ($0.0, $0.1.map { ($0.mesh, $0.label) }) }, name: "air_mockup", bw: 84, bh: 96)
        for (_, cs) in rows { for c in cs { #expect(c.gap == 0, "\(c.label)") } }
    }
}
