import Testing
import Foundation
import Metal
import ImageIO
@preconcurrency import CoreText
import UniformTypeIdentifiers
import BBCore
import BBContent
@testable import BBAnim
@testable import BBSim
@testable import BBRender
import BBPresentation

/// 목 점검(감독 '몸통과 머리 사이 목이 없어 특정 액션에서 머리가 떠 보인다' — docs/07 7-X). BB_DUMP=1 일 때만.
/// 모든 포즈(웹 POSES + 네이티브) · 모든 동작 시퀀스(주인공 스킨 4 + 적 생김새 · 승객 — 머리 · 몸통 모양이 같은 것은 하나로)를
/// 실제 메시(emit — 3D 투영 · 구르기 · 몸 회전 · 강화 스프링까지)로 만들어 머리(부위 1) ↔ 몸통(부위 2) 사이 빈 픽셀을 잰다(게임 1배 픽셀 · 2배 표본).
///   gap   = 머리 실루엣과 몸통 실루엣 사이 가장 가까운 빈 거리(px) — 0 이면 맞닿음
///   along = 머리 밑(목 토막 아래 가운데) ↔ 몸통 윗면 가운데, 몸통 축 방향(+ = 위로 떨어짐)
///   perp  = 같은 것의 몸통 축 옆 방향(+ = 앞) — 머리가 몸통 위에서 미끄러진 정도
/// 세 갈래: web = 강화 끔 · 웹 표(웹 기준선) / before = 강화 켬 · 목 없음(지금 앱) / after = 강화 켬 · 목
/// 결과: tools/js/out/rig/neck_audit.md · neck_worst.png · neck_before_after.png · neck_ingame.png
@Suite(.serialized) struct NeckAuditTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let out = root.appending(path: "tools/js/out/rig")

    // MARK: 대상

    struct Subject { var name: String; var members: [String]; var model: Model3; var rig: RigDims; var hero: Bool; var anims: Set<String> }

    static func subjects(store: ContentStore, base: AnimTables, seqs: SequenceTable) throws -> [Subject] {
        let hero = try CharacterDef.load(store, "JW_HERO"), thug = try CharacterDef.load(store, "JW_THUG"), noir = try CharacterDef.load(store, "NOIR_THUG")
        let all = Set(seqs.jw.keys).union(["walk"])
        var out: [Subject] = []
        for k in CharacterModels.skins { out.append(Subject(name: "주인공 \(k)", members: ["hero:\(k)"], model: CharacterModels.skin(k), rig: hero.rig, hero: true, anims: all)) }
        // 적: 생김새 열쇠마다(머리 변형 포함) — 머리 · 몸통 조각 모양 + 배율이 같으면 한 대상으로 묶는다
        let data = try SimData.bundled().variant(nativeMoves: true)
        var c = SimConfig(); c.nativeMoves = true
        let sim = Sim(data: data, seed: 1, config: c)
        let common: Set<String> = base.reacts.union(base.falls).union(["idle", "walk", "run", "held", "pulled", "jug", "getup", "getupP", "stagger", "staggerX", "duck", "evade", "parry"])
        var bySig: [String: Int] = [:]
        for t in data.game.enemies.keys.sorted() {
            let T = data.game.enemies[t]!
            var keys: [String] = []
            for k in 0..<8 { if let L = sim.w.defFor(T, k).look, !keys.contains(L) { keys.append(L) } }
            for L in keys {
                guard let spec = LookSpec(key: L) else { continue }
                let m = CharacterModels.look(spec), sc = NativeLooks.scale(hair: spec.hair)
                let r = sc.map { NativeLooks.scaled(thug.rig, $0) } ?? thug.rig
                let sig = signature(m, r)
                let anims = common.union(T.moves).intersection(all)
                let who = "\(T.name)(\(t)\(keys.count > 1 ? "·" + (spec.hair ?? "-") : ""))"
                if let i = bySig[sig] { out[i].members.append(who); out[i].anims.formUnion(anims) }
                else { bySig[sig] = out.count; out.append(Subject(name: who, members: [who], model: m, rig: r, hero: false, anims: anims)) }
            }
        }
        for i in 0..<3 {
            let m = CharacterModels.passenger(i), sig = signature(m, noir.rig)
            if let j = bySig[sig] { out[j].members.append("승객 \(i)") } else { bySig[sig] = out.count; out.append(Subject(name: "승객 \(i)", members: ["승객 \(i)"], model: m, rig: noir.rig, hero: false, anims: ["idle", "walk", "hit"])) }
        }
        return out
    }

    /// 머리 · 몸통 조각 모양(재질 빼고) + 리그 배율
    static func signature(_ m: Model3, _ r: RigDims) -> String {
        var h = Hasher()
        for k in ["head", "torso"] { for p in m[k] ?? [] { for q in p.q { for v in q { h.combine(v.x); h.combine(v.y); h.combine(v.z) } } } }
        h.combine(r.sc ?? 1)
        return "\(h.finalize())"
    }

    // MARK: 재기

    struct Meas { var gap = 0.0, gapAny = 0.0, along = 0.0, perp = 0.0, len = 0.0, neckPt = SIMD2<Double>(0, 0), hb = SIMD2<Double>(0, 0), tt = SIMD2<Double>(0, 0) }

    /// 메시(정점 10 float) → 머리 · 몸통 실루엣 거리 + 뼈 기준 목 축 값
    static func measure(_ f: [Float], sk: Skeleton, model: Model3, x: Double, y: Double) -> Meas {
        var M = Meas()
        // 뼈 기준점(화면): 머리 밑 = 목 토막 아래 단면 가운데 · 몸통 윗면 · 몸통 아래
        if let st = model["head"]?.first, let to = model["torso"]?.first, let hb = sk["head"], let tb = sk["torso"] {
            let b = st.q[1], cx = (b[0].x + b[1].x) / 2
            func scr(_ bone: Bone, _ p: SIMD3<Double>) -> SIMD2<Double> { let q = boneTransform(bone, sk.spin, sk.roll, p); return [x + q.x, y + q.y] }
            let Hb = scr(hb, [cx, b[0].y, 0]), Tt = scr(tb, [0, to.q[0][0].y, 0]), Tb = scr(tb, [0, to.q[1][0].y, 0])
            var u = Tt - Tb; let n = (u * u).sum().squareRoot(); u = n > 0.01 ? u / n : [0, -1]
            var nv = SIMD2(-u.y, u.x); if nv.x < 0 { nv = -nv }      // 앞(+x) 쪽
            let D = Hb - Tt
            M.along = (D * u).sum(); M.perp = (D * nv).sum(); M.len = (D * D).sum().squareRoot(); M.hb = Hb; M.tt = Tt; M.neckPt = (Hb + Tt) / 2
        }
        // 실루엣(2배 표본 · 목 둘레 ±18px 만 — 디버그 빌드에서도 빨리)
        let S = 2.0
        var tris: [(SIMD2<Double>, SIMD2<Double>, SIMD2<Double>, Int)] = []
        var lo = SIMD2(1e9, 1e9), hi = SIMD2(-1e9, -1e9)
        for i in stride(from: 0, to: f.count / 10 - 2, by: 3) {
            let part = Int(f[(i + 2) * 10 + 7].rounded())
            guard part >= 1 && part <= 12 else { continue }
            let a = SIMD2(Double(f[i * 10]), Double(f[i * 10 + 1])), b = SIMD2(Double(f[(i + 1) * 10]), Double(f[(i + 1) * 10 + 1])), c = SIMD2(Double(f[(i + 2) * 10]), Double(f[(i + 2) * 10 + 1]))
            tris.append((a, b, c, part))
            if part <= 2 { lo = pointwiseMin(lo, pointwiseMin(a, pointwiseMin(b, c))); hi = pointwiseMax(hi, pointwiseMax(a, pointwiseMax(b, c))) }
        }
        guard hi.x > lo.x else { return M }
        lo -= 3; hi += 3
        if M.neckPt != .zero { lo = pointwiseMax(lo, M.neckPt - 18); hi = pointwiseMin(hi, M.neckPt + 18) }
        guard hi.x > lo.x, hi.y > lo.y else { return M }
        let W = Int(((hi.x - lo.x) * S).rounded(.up)), H = Int(((hi.y - lo.y) * S).rounded(.up))
        var mask = [UInt8](repeating: 0, count: W * H)   // 1 머리 · 2 몸통 · 4 그 밖 몸
        for (a, b, c, part) in tris {
            let bit: UInt8 = part == 1 ? 1 : part == 2 ? 2 : 4
            let mn = pointwiseMin(a, pointwiseMin(b, c)), mx = pointwiseMax(a, pointwiseMax(b, c))
            if mx.x < lo.x || mx.y < lo.y || mn.x > hi.x || mn.y > hi.y { continue }
            let x0 = max(0, Int(((mn.x - lo.x) * S).rounded(.down))), x1 = min(W - 1, Int(((mx.x - lo.x) * S).rounded(.up)))
            let y0 = max(0, Int(((mn.y - lo.y) * S).rounded(.down))), y1 = min(H - 1, Int(((mx.y - lo.y) * S).rounded(.up)))
            guard x0 <= x1, y0 <= y1 else { continue }
            func e(_ p: SIMD2<Double>, _ q: SIMD2<Double>, _ r: SIMD2<Double>) -> Double { (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x) }
            let area = e(a, b, c); if abs(area) < 1e-9 { continue }
            for yy in y0...y1 { for xx in x0...x1 {
                let p = SIMD2(lo.x + (Double(xx) + 0.5) / S, lo.y + (Double(yy) + 0.5) / S)
                let w0 = e(b, c, p), w1 = e(c, a, p), w2 = e(a, b, p)
                if (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0) { mask[yy * W + xx] |= bit }
            } }
        }
        // 거리 변환(3-4 체임퍼) — 몸통만 · 몸통 + 팔다리
        func dist(_ bits: UInt8) -> Double {
            let INF = Int32.max / 4
            var d = [Int32](repeating: INF, count: W * H)
            for i in 0..<W * H where mask[i] & bits != 0 { d[i] = 0 }
            for yy in 0..<H { for xx in 0..<W { var v = d[yy * W + xx]
                if xx > 0 { v = min(v, d[yy * W + xx - 1] + 3) }
                if yy > 0 { v = min(v, d[(yy - 1) * W + xx] + 3); if xx > 0 { v = min(v, d[(yy - 1) * W + xx - 1] + 4) }; if xx < W - 1 { v = min(v, d[(yy - 1) * W + xx + 1] + 4) } }
                d[yy * W + xx] = v } }
            for yy in stride(from: H - 1, through: 0, by: -1) { for xx in stride(from: W - 1, through: 0, by: -1) { var v = d[yy * W + xx]
                if xx < W - 1 { v = min(v, d[yy * W + xx + 1] + 3) }
                if yy < H - 1 { v = min(v, d[(yy + 1) * W + xx] + 3); if xx < W - 1 { v = min(v, d[(yy + 1) * W + xx + 1] + 4) }; if xx > 0 { v = min(v, d[(yy + 1) * W + xx - 1] + 4) } }
                d[yy * W + xx] = v } }
            var best = INF
            for i in 0..<W * H where mask[i] & 1 != 0 && mask[i] & bits == 0 { best = min(best, d[i]) }
            if best == INF { return 0 }                                   // 머리가 몸통에 다 덮였거나 머리가 없다
            return max(0, (Double(best) / 3 - 1) / S)
        }
        M.gap = dist(2); M.gapAny = dist(6)
        return M
    }

    // MARK: 돌리기

    enum Pass: String { case web, before, after }
    static func style(_ p: Pass) -> MotionStyle {
        switch p { case .web: return .off
        case .before: var s = MotionStyle.on; s.neck = false; return s
        case .after: return .on }
    }

    static func rig(_ S: Subject) -> CharacterRig {
        var r = CharacterRig(model: S.model, rig: S.rig, traits: ActorTraits(gait: true, jw: true, isHero: S.hero), actor: ActorPose(anim: "idle", pose: "st0"), x: 170, y: 220, flip: false)
        r.hasFace = true
        return r
    }

    /// 포즈 하나(섞기 없이 그 자세 그대로)
    static func posed(_ S: Subject, _ pose: String, tables: AnimTables, style: MotionStyle) -> (MeshWriter, CharacterRig) {
        var r = rig(S)
        r.actor = ActorPose(anim: "audit", pose: pose)
        var w = MeshWriter(); r.emit(time: 10, dt: 1.0 / 60, style: style, tables: tables, into: &w)
        return (w, r)
    }

    /// 피격 반응 변형 키 하나(그 변형이 골라지는 입력을 찾아 — 결정적 — 키 시각에 그린다). 가장 세게: 신문팔이 몸무게(×1.4) · 무거운 세기
    static func reactPosed(_ S: Subject, _ pose: String, _ v: HitReactVariant, key: Int, tables: AnimTables, style: MotionStyle) -> (MeshWriter, CharacterRig) {
        var r = rig(S)
        r.actor = ActorPose(anim: "hit", pose: pose)
        let zd: [(HitZone, HitDir)] = HitZone.allCases.flatMap { z in HitDir.allCases.map { (z, $0) } }
        search: for tier in [HitTier.heavy, .medium] { for n in 0..<600 {
            var st = HitReactState(); let (z, d) = zd[n % zd.count]
            if st.trigger(actor: n, zone: z, dir: d, tier: tier, mass: HitReact.mass["nv_newsboy"]!, time: 10, hold: 0) == v { r.react = st; break search }
        } }
        var w = MeshWriter()
        r.emit(time: 10 + v.spec.keys[key].u * r.react.dur, dt: 1.0 / 60, style: style, tables: tables, into: &w)
        return (w, r)
    }

    /// 동작 하나: 대기 0.2초 → 동작(20fps 칸 · 60Hz 그리기) → 끝나고 0.1초. 화면 프레임마다 visit(칸 번호, 메시, 리그)
    static func play(_ S: Subject, _ anim: String, tables: AnimTables, seqs: SequenceTable, style: MotionStyle, _ visit: (Int, MeshWriter, CharacterRig) -> Void) {
        var r = rig(S), pl = SequencePlayer(), t = 10.0
        pl.set("idle", on: &r.actor, table: seqs, loop: tables.loop)
        for k in 0..<12 { var w = MeshWriter(); r.emit(time: t, dt: 1.0 / 60, style: style, tables: tables, into: &w); t += 1.0 / 60; if k % 3 == 2 { pl.advance(&r.actor, table: seqs, loop: tables.loop) } }
        pl.set(anim, on: &r.actor, table: seqs, loop: tables.loop)
        let total = (seqs.steps(anim) ?? []).reduce(0) { $0 + min($1.length, 300) }
        let frames = min(150, Int((max(total, 400) / 1000 * 60).rounded(.up)) + 6)
        for k in 0..<frames {
            if anim == "run" { r.actor.gph = (r.actor.gph ?? 0) + 156 / 60 / 65.5 }
            if anim == "walk" { r.actor.gph = (r.actor.gph ?? 0) + 2.4 / 40 }
            var w = MeshWriter(); r.emit(time: t, dt: 1.0 / 60, style: style, tables: tables, into: &w); t += 1.0 / 60
            visit(k, w, r)
            if k % 3 == 2 { pl.advance(&r.actor, table: seqs, loop: tables.loop) }
        }
    }

    struct Row { var subj: Int; var what: String; var frame: Int; var pose: String; var web: Meas?; var before: Meas; var after: Meas; var native: Bool }

    // MARK: 점검

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_DUMP"] == "1"))
    func neckAudit() throws {
        let store = try ContentStore.bundled()
        let baseT = try AnimTables(store), baseS = try SequenceTable(store)
        let nvT = baseT.withNativeMoves(), nvS = baseS.withNativeMoves()
        var subs = try Self.subjects(store: store, base: baseT, seqs: nvS)
        if let n = ProcessInfo.processInfo.environment["BB_NECK_N"].flatMap(Int.init) { subs = Array(subs.prefix(n)) }   // 빠른 확인용
        print("[neck] 대상 \(subs.count): " + subs.map { "\($0.name)×\($0.members.count)" }.joined(separator: " · "))
        let webPoses = Set(baseT.poses.keys)
        var poseRows: [Row] = [], actRows: [Row] = []
        let t0 = Date()
        // ① 포즈 표
        for (si, S) in subs.enumerated() {
            for name in nvT.poses.keys.sorted() {
                let isWeb = webPoses.contains(name)
                func m(_ p: Pass, _ T: AnimTables) -> Meas { let (w, r) = Self.posed(S, name, tables: T, style: Self.style(p)); return Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220) }
                poseRows.append(Row(subj: si, what: name, frame: 0, pose: name, web: isWeb ? m(.web, baseT) : nil, before: m(.before, nvT), after: m(.after, nvT), native: !isWeb))
            }
        }
        // ①-2 피격 반응 변형(HitReact — docs/11 §9): 변형마다 키 정점(진폭 1.4 = 가장 가벼운 몸 · 무거운 세기 1.15 까지 덮게 몸무게 신문팔이)
        for (si, S) in subs.enumerated() {
            for v in HitReactVariant.allCases { for base in ["hh1", "hbd0", "rh1"] { for ki in v.spec.keys.indices {
                func m(_ p: Pass) -> Meas { let (w, r) = Self.reactPosed(S, base, v, key: ki, tables: nvT, style: Self.style(p)); return Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220) }
                poseRows.append(Row(subj: si, what: "hr:\(v.rawValue)#\(ki)@\(base)", frame: 0, pose: "hr:\(v.rawValue)@\(base)", web: nil, before: m(.before), after: m(.after), native: true))
            } } }
        }
        print("[neck] 포즈 \(poseRows.count) — \(Int(Date().timeIntervalSince(t0)))초")
        // ② 동작 시퀀스(대상이 실제로 쓰는 것)
        for (si, S) in subs.enumerated() {
            for anim in S.anims.sorted() {
                let isWeb = baseS.steps(anim) != nil && NativeMoves.overrideSequences[anim] == nil && NativeMoves.grabSequences[anim] == nil
                var web: [Int: Meas] = [:], bef: [Int: (Meas, String)] = [:], aft: [Int: Meas] = [:]
                if isWeb || baseS.steps(anim) != nil { Self.play(S, anim, tables: baseT, seqs: baseS, style: Self.style(.web)) { k, w, r in web[k] = Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220) } }
                Self.play(S, anim, tables: nvT, seqs: nvS, style: Self.style(.before)) { k, w, r in bef[k] = (Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220), r.actor.pose) }
                Self.play(S, anim, tables: nvT, seqs: nvS, style: Self.style(.after)) { k, w, r in aft[k] = Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220) }
                for k in bef.keys.sorted() { actRows.append(Row(subj: si, what: anim, frame: k, pose: bef[k]!.1, web: web[k], before: bef[k]!.0, after: aft[k] ?? Meas(), native: !isWeb)) }
            }
        }
        print("[neck] 동작 프레임 \(actRows.count) — \(Int(Date().timeIntervalSince(t0)))초")
        try FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        try Self.report(subs, poseRows, actRows)
        // ③ 그림: 가장 나쁜 24 프레임(동작 · 대상 · 동작 하나당 최악 한 칸)
        var worst: [Row] = []
        var seen = Set<String>()
        for r in actRows.sorted(by: { Self.score($0.before) > Self.score($1.before) }) where !seen.contains(r.pose) {   // 포즈마다 한 칸(같은 포즈 · 다른 대상 반복 없이)
            seen.insert(r.pose); worst.append(r); if worst.count == 24 { break }
        }
        let P = try Painter()
        func grab(_ r: Row, _ p: Pass, scene: Bool = false) throws -> ([UInt8], Meas) {
            let T = p == .web ? baseT : nvT, Sq = p == .web ? baseS : nvS
            var got: ([Float], Skeleton)?
            Self.play(subs[r.subj], r.what, tables: T, seqs: Sq, style: Self.style(p)) { k, w, rg in if k == r.frame { got = (w.floats, rg.skeleton!) } }
            let (fl, sk) = got!
            return (try P.render(fl, inScene: scene), Self.measure(fl, sk: sk, model: subs[r.subj].model, x: 170, y: 220))
        }
        var cellsW: [Cell] = [], cellsBA: [Cell] = []
        for (i, r) in worst.enumerated() {
            let lab = "\(i + 1). \(subs[r.subj].name) · \(r.what)#\(r.frame) \(r.pose)"
            let (pb, mb) = try grab(r, .before)
            cellsW.append(Cell(px: pb, m: mb, label: lab, sub: String(format: "틈 %.1fpx · 축 %+.1f · 옆 %+.1f", mb.gap, mb.along, mb.perp)))
            let (pa, ma) = try grab(r, .after)
            cellsBA.append(Cell(px: pb, m: mb, label: lab, sub: String(format: "전 틈 %.1f", mb.gap)))
            cellsBA.append(Cell(px: pa, m: mb, label: "  → 목", sub: String(format: "후 틈 %.1f", ma.gap)))
        }
        try P.sheet(cellsW, cols: 6, zoom: 5, name: "neck_worst", markers: true)
        try P.sheet(cellsBA, cols: 8, zoom: 5, name: "neck_before_after", markers: false)
        // ④ 게임 크기(1배 · 3배): 피격 · 어퍼컷 · 퇴근 승천권 · 잡힌 몸 · 질주 — 각 동작에서 전(목 없음) 가장 큰 틈 칸
        let picks: [(String, Int, String)] = [("피격 hit", 4, "hit"), ("어퍼컷 upper", 0, "upper"), ("승천권 nv_rise", 0, "nv_rise"), ("무릎 올려치기 nv_kneelift", 0, "nv_kneelift"), ("파고들어 올려치기 nv_duckup", 0, "nv_duckup"), ("잡힌 몸 held", 4, "held"), ("뒤로 날기 launch", 4, "launch"), ("질주 run", 0, "run")]
        var game: [(String, [UInt8], [UInt8], Meas, Meas)] = []
        for (lab, si0, anim) in picks {
            let si = min(si0, subs.count - 1)
            guard let r = actRows.filter({ $0.subj == si && $0.what == anim }).max(by: { Self.score($0.before) < Self.score($1.before) }) else { continue }
            let (pb, mb) = try grab(r, .before, scene: true), (pa, ma) = try grab(r, .after, scene: true)
            game.append(("\(lab) · \(subs[si].name) #\(r.frame) \(r.pose)", pb, pa, mb, ma))
        }
        // 잡힌 몸 포즈(메치기 휘두름 · 수플렉스 거꾸로) — 포즈 표에서
        for pn in ["nv_hl_sw", "nv_hl_ov", "hl1"] where nvT.poses[pn] != nil {
            let S = subs[min(4, subs.count - 1)]
            let (wb, rb) = Self.posed(S, pn, tables: nvT, style: Self.style(.before)), (wa, ra) = Self.posed(S, pn, tables: nvT, style: Self.style(.after))
            game.append(("잡힌 몸 \(pn) · \(S.name)", try P.render(wb.floats, inScene: true), try P.render(wa.floats, inScene: true),
                         Self.measure(wb.floats, sk: rb.skeleton!, model: S.model, x: 170, y: 220), Self.measure(wa.floats, sk: ra.skeleton!, model: S.model, x: 170, y: 220)))
        }
        try P.ingame(game, name: "neck_ingame")
        print("[neck] 끝 — \(Int(Date().timeIntervalSince(t0)))초")
    }


    /// 목 비용(BB_BENCH=1): 실제 판 600프레임(PerfBench frames 와 같은 씨앗 · 자동 전투) — 목 끔 ↔ 켬, 인물 정점 수 · 연출(인물 층 포함) CPU
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_BENCH"] == "1"))
    func neckCost() throws {
        let store = try ContentStore.bundled(), data = try SimData(store: store, nativeMoves: true), atlas = try AtlasMeta.bundled()
        let scene = try SceneContent(store: store, atlas: atlas)
        for (name, neck) in [("목 끔", false), ("목 켬", true), ("목 끔", false), ("목 켬", true)] {
            var st = MotionStyle.on; st.neck = neck
            let d = try StageDirector(content: scene, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK, style: st)
            var cfg = SimConfig(); cfg.skipTalks = true; cfg.nativeMoves = true; cfg.autoAdvance = true
            let sim = Sim(data: data, seed: 4242, config: cfg)
            var dir = 0.0, verts = 0, vmax = 0, actors = 0
            let N = 600
            for k in 0..<N {
                let ev = sim.step(), s = sim.snapshot
                let t0 = DispatchTime.now().uptimeNanoseconds
                _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
                let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
                dir += Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
                let v = f.mesh.count / 10; verts += v; vmax = max(vmax, v); actors += s.actors.filter { !$0.hidden }.count
            }
            print(String(format: "[neck bench] %@ · 연출 %.3f ms/프레임 · 인물 정점 평균 %d · 최대 %d · 인물 평균 %.1f", name, dir / Double(N), verts / N, vmax, Double(actors) / Double(N)))
        }
    }


    /// 생김새별 목(BB_DUMP=1): 줄 = 대표 생김새, 칸 = [쉼 · 극단 포즈들] 전 | 후 — 6배. tools/js/out/rig/neck_looks.png
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_DUMP"] == "1"))
    func neckLooks() throws {
        let store = try ContentStore.bundled()
        let baseT = try AnimTables(store), nvT = baseT.withNativeMoves(), nvS = try SequenceTable(store).withNativeMoves()
        let subs = try Self.subjects(store: store, base: baseT, seqs: nvS)
        let want = ["주인공 jw", "주인공 gala", "주인공 rain", "주인공 chicago", "승객 0", "권법가", "네온 덩치", "라인배커", "스파링꾼", "신문팔이", "기어단(gear·tophat)"]
        let pick = want.compactMap { w in subs.first { $0.name.hasPrefix(w) || $0.members.contains { $0.hasPrefix(w) } } }
        let poses = ["st0", "ru0", "air_arch", "rc0", "cr2", "wl0", "sk_over", "hh1"]
        let P = try Painter()
        var cells: [Cell] = []
        for S in pick { for pn in poses {
            for p in [Pass.before, .after] {
                let (w, r) = Self.posed(S, pn, tables: nvT, style: Self.style(p))
                let m = Self.measure(w.floats, sk: r.skeleton!, model: S.model, x: 170, y: 220)
                cells.append(Cell(px: try P.render(w.floats), m: m, label: p == .before ? "\(S.name.prefix(12)) \(pn)" : "→ 목", sub: String(format: "틈 %.1f · 길이 %.1f", m.gap, m.len)))
            }
        } }
        try P.sheet(cells, cols: poses.count * 2, zoom: 4, name: "neck_looks", markers: false)
    }

    /// 순위 점수: 틈(px) 먼저, 같으면 축 방향 떨어짐 · 옆 미끄러짐
    static func score(_ m: Meas) -> Double { m.gap * 10 + max(0, m.along) + max(0, abs(m.perp) - 3) * 0.5 }

    // MARK: 표

    static func report(_ subs: [Subject], _ poses: [Row], _ acts: [Row]) throws {
        func f1(_ v: Double) -> String { String(format: "%.1f", v) }
        func stats(_ rows: [Row], _ get: (Row) -> Meas?) -> String {
            let ms = rows.compactMap(get), n = max(1, ms.count)
            let g1 = ms.filter { $0.gap >= 1 }.count, g2 = ms.filter { $0.gap >= 2 }.count, g05 = ms.filter { $0.gap >= 0.5 }.count
            let mx = ms.map(\.gap).max() ?? 0, mxA = ms.map(\.gapAny).max() ?? 0
            return "\(ms.count) | \(g05) (\(f1(Double(g05) * 100 / Double(n)))%) | \(g1) (\(f1(Double(g1) * 100 / Double(n)))%) | \(g2) | **\(f1(mx))** | \(f1(mxA)) | \(f1(ms.map(\.along).max() ?? 0)) | \(f1(ms.map { abs($0.perp) }.max() ?? 0)) | \(f1(ms.map(\.len).max() ?? 0)) | \(ms.filter { $0.len > 4 }.count)"
        }
        var s = "# 목 점검(머리 ↔ 몸통 틈) — NeckAuditTests\n\n"
        s += "게임 1배 픽셀 · 2배 표본 실루엣 거리(0.5px 단위). `틈` = 머리(부위 1) ↔ 몸통(부위 2) 사이 빈 거리 · `팔다리 포함` = 몸통 대신 몸 전체(팔이 가려 주는 경우) · `축` = 머리 밑 ↔ 몸통 윗면(몸통 축, + 위로 떨어짐) · `옆` = 몸통 축 옆으로 미끄러짐(|값|).\n"
        s += "web = 강화 끔 · 웹 표(웹 기준선) · before = 강화 켬 · 목 없음(이전 앱) · after = 강화 켬 · 목(Neck.swift).\n\n"
        s += "대상(머리 · 몸통 모양이 같은 생김새는 묶음): " + subs.map { "**\($0.name)**" + ($0.members.count > 1 ? "(\($0.members.count))" : "") }.joined(separator: " · ") + "\n\n"
        s += "## 요약\n\n| 묶음 | 갈래 | 표본 | 틈 ≥ 0.5 | 틈 ≥ 1px | 틈 ≥ 2px | 최대 틈 | 최대(팔다리 포함) | 최대 축 | 최대 옆 | 최대 목 길이 | 목 길이 > 4px |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n"
        let wp = poses.filter { !$0.native }, np = poses.filter { $0.native }, wa = acts.filter { !$0.native }, na = acts.filter { $0.native }
        s += "| 포즈(웹 \(wp.count)) | web | \(stats(wp) { $0.web }) |\n| | before | \(stats(wp) { $0.before }) |\n| | after | \(stats(wp) { $0.after }) |\n"
        s += "| 포즈(네이티브 \(np.count)) | before | \(stats(np) { $0.before }) |\n| | after | \(stats(np) { $0.after }) |\n"
        s += "| 동작(웹 시퀀스) | web | \(stats(wa) { $0.web }) |\n| | before | \(stats(wa) { $0.before }) |\n| | after | \(stats(wa) { $0.after }) |\n"
        s += "| 동작(네이티브 · 덮어쓴 시퀀스) | before | \(stats(na) { $0.before }) |\n| | after | \(stats(na) { $0.after }) |\n\n"
        func table(_ title: String, _ rows: [Row], _ n: Int, dedupe: Bool) -> String {
            var t = "## \(title)\n\n| # | 대상 | 동작 · 칸 | 포즈 | 웹 틈 | 전 틈 | 전 팔다리 포함 | 전 축 | 전 옆 | **후 틈** | 목 길이 전 → 후 |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
            var seen = Set<String>(), k = 0
            for r in rows.sorted(by: { score($0.before) > score($1.before) }) {
                let key = dedupe ? "\(r.what)|\(r.pose)" : "\(r.what)"
                if seen.contains(key) { continue }; seen.insert(key); k += 1
                t += "| \(k) | \(subs[r.subj].name) | \(r.what)\(dedupe ? " #\(r.frame)" : "")\(r.native ? " ⁿ" : "") | \(r.pose) | \(r.web.map { f1($0.gap) } ?? "—") | \(f1(r.before.gap)) | \(f1(r.before.gapAny)) | \(f1(r.before.along)) | \(f1(r.before.perp)) | **\(f1(r.after.gap))** | \(f1(r.before.len)) → \(f1(r.after.len)) |\n"
                if k == n { break }
            }
            return t + "\n"
        }
        s += table("가장 나쁜 동작 프레임(동작 · 포즈마다 가장 나쁜 대상 한 칸, 40)", acts, 40, dedupe: true)
        s += table("가장 나쁜 포즈(포즈마다 가장 나쁜 대상, 40)", poses, 40, dedupe: false)
        // 버추어 파이터 참고 두 기술(docs/07 §7-VF): 새 포즈 · 동작 칸 전부(주인공 대상)
        let vf = { (n: String) in n.hasPrefix("kl_") || n.hasPrefix("du_") }
        s += table("무릎 올려치기 · 파고들어 올려치기 포즈", poses.filter { vf($0.pose) && subs[$0.subj].hero }, 40, dedupe: false)
        s += table("무릎 올려치기 · 파고들어 올려치기 동작 칸", acts.filter { ($0.what == "nv_kneelift" || $0.what == "nv_duckup") && subs[$0.subj].hero }, 40, dedupe: true)
        // 동작별 최악(주인공 jw) — 감독이 보는 동작 위주
        s += "## 동작별 최악 틈(전 → 후, 대상 전부 중 최대)\n\n| 동작 | 웹 | 전 | 후 | 전 ≥1px 프레임 비율 |\n|---|---|---|---|---|\n"
        let byAnim = Dictionary(grouping: acts, by: \.what)
        for (a, rs) in byAnim.sorted(by: { ($0.value.map(\.before.gap).max() ?? 0) > ($1.value.map(\.before.gap).max() ?? 0) }) {
            let w = rs.compactMap(\.web).map(\.gap).max(), b = rs.map(\.before.gap).max() ?? 0, af = rs.map(\.after.gap).max() ?? 0
            guard b >= 0.5 else { continue }
            s += "| \(a) | \(w.map(f1) ?? "—") | \(f1(b)) | \(f1(af)) | \(f1(Double(rs.filter { $0.before.gap >= 1 }.count) * 100 / Double(rs.count)))% |\n"
        }
        s += "\nⁿ = 네이티브 동작(깃발 켜짐 — 웹 기준선 없음).\n"
        try s.write(to: out.appending(path: "neck_audit.md"), atomically: true, encoding: .utf8)
        print("[neck] 표 → \(out.appending(path: "neck_audit.md").path)")
    }

    // MARK: 그리기

    struct Cell { var px: [UInt8]; var m: Meas; var label: String; var sub: String }

    final class Painter {
        let renderer: FrameRenderer, tmpl: RenderFrame, bgCount: Int, targets: FrameRenderer.Targets, q: MTLCommandQueue
        init() throws {
            let device = MTLCreateSystemDefaultDevice()!
            renderer = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled())
            var t = try RenderFrame(webCapture: Data(contentsOf: NeckAuditTests.root.appending(path: "native/Tests/Fixtures/frames/subway/frame.json")))
            guard case .sprite(_, let n, _) = t.gbuffer.first else { throw CocoaError(.featureUnsupported) }
            t.spriteVertices = Array(t.spriteVertices.prefix(n * 9)); t.shake = .zero
            tmpl = t; bgCount = n
            targets = try FrameRenderer.Targets(device: device, width: t.width, height: t.height)
            q = device.makeCommandQueue()!
        }
        var W: Int { tmpl.width }
        /// 인물만 그리고(지하철 조명 그대로) 빈 곳은 평평한 회청색 — 틈이 배경 무늬에 묻히지 않게. inScene = 지하철 배경까지(게임 크기 그림)
        func render(_ mesh: [Float], inScene: Bool = false) throws -> [UInt8] {
            func draw(_ m: [Float], bg: Bool) throws -> [UInt8] {
                var f = tmpl; f.time = 10; f.meshVertices = m
                f.gbuffer = (bg ? [GBufferDraw.sprite(first: 0, count: bgCount, shadow: false)] : []) + (m.isEmpty ? [] : [GBufferDraw.mesh(first: 0, count: m.count / 10)])
                let cb = q.makeCommandBuffer()!; try renderer.encode(f, targets: targets, into: cb); cb.commit(); cb.waitUntilCompleted()
                return try renderer.readBack(targets.output(for: f), queue: q)
            }
            var px = try draw(mesh, bg: true)
            if inScene { return px }
            // 인물 덮개(정점 삼각형 · 픽셀 중심) + 외곽선 1px — 밖은 평평한 회청색
            let Wd = tmpl.width, Hd = tmpl.height
            var cov = [Bool](repeating: false, count: Wd * Hd)
            for i in stride(from: 0, to: mesh.count / 10 - 2, by: 3) {
                let P = (0..<3).map { SIMD2(Double(mesh[(i + $0) * 10]), Double(mesh[(i + $0) * 10 + 1])) }
                let mn = pointwiseMin(P[0], pointwiseMin(P[1], P[2])), mx = pointwiseMax(P[0], pointwiseMax(P[1], P[2]))
                func e(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> Double { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
                for y in max(0, Int(mn.y))...min(Hd - 1, Int(mx.y) + 1) { for x in max(0, Int(mn.x))...min(Wd - 1, Int(mx.x) + 1) {
                    let c = SIMD2(Double(x) + 0.5, Double(y) + 0.5), w0 = e(P[1], P[2], c), w1 = e(P[2], P[0], c), w2 = e(P[0], P[1], c)
                    if (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0) { cov[y * Wd + x] = true }
                } }
            }
            for y in 0..<Hd { for x in 0..<Wd {
                let i = (y * Wd + x) * 4
                var near = false
                for dy in -1...1 { for dx in -1...1 { let xx = x + dx, yy = y + dy; if xx >= 0, yy >= 0, xx < Wd, yy < Hd, cov[yy * Wd + xx] { near = true } } }
                if near { px[i] = Self.lift(px[i]); px[i + 1] = Self.lift(px[i + 1]); px[i + 2] = Self.lift(px[i + 2]) } else { px[i] = 46; px[i + 1] = 58; px[i + 2] = 72 }
            } }
            return px
        }
        static func lift(_ v: UInt8) -> UInt8 { UInt8(min(255, Double(v) * 1.9 + 4)) }   // 어두운 지하철 조명을 밝게(보기용)

        /// 목 둘레(36×36 장면 px)를 zoom 배로 — 칸 아래 글자 두 줄
        func sheet(_ cells: [Cell], cols: Int, zoom: Int, name: String, markers: Bool) throws {
            let box = 36, cw = box * zoom + 6, ch = box * zoom + 30
            let rows = (cells.count + cols - 1) / cols
            let Wd = cols * cw, Hd = rows * ch
            var img = [UInt8](repeating: 20, count: Wd * Hd * 4)
            var labels: [(String, Int, Int, Bool)] = []
            for (i, c) in cells.enumerated() {
                let ox = (i % cols) * cw + 3, oy = (i / cols) * ch + 2
                let cx = Int(c.m.neckPt.x.rounded()) - box / 2, cy = Int(c.m.neckPt.y.rounded()) - box / 2 - 4
                for y in 0..<box * zoom { for x in 0..<box * zoom {
                    let sx = cx + x / zoom, sy = cy + y / zoom
                    guard sx >= 0, sy >= 0, sx < W, sy < tmpl.height else { continue }
                    let s = (sy * W + sx) * 4, d = ((oy + y) * Wd + ox + x) * 4
                    img[d] = c.px[s]; img[d + 1] = c.px[s + 1]; img[d + 2] = c.px[s + 2]; img[d + 3] = 255
                } }
                if markers {   // 머리 밑(빨강) · 몸통 윗면(하늘) — 작은 점
                    for (p, col) in [(c.m.hb, (255, 60, 60)), (c.m.tt, (60, 220, 255))] {
                        let mx = ox + Int((p.x - Double(cx)) * Double(zoom)), my = oy + Int((p.y - Double(cy)) * Double(zoom))
                        for dy in -1...1 { for dx in -1...1 {
                            let x = mx + dx, y = my + dy; guard x >= ox, y >= oy, x < ox + box * zoom, y < oy + box * zoom else { continue }
                            let d = (y * Wd + x) * 4; img[d] = UInt8(col.0); img[d + 1] = UInt8(col.1); img[d + 2] = UInt8(col.2)
                        } }
                    }
                }
                labels.append((c.label, ox, oy + box * zoom + 1, false)); labels.append((c.sub, ox, oy + box * zoom + 13, c.m.gap >= 1))
            }
            try NeckAuditTests.png(img, Wd, Hd, name, labels: labels)
        }

        /// 게임 크기: 줄마다 [전 1배 | 후 1배 | 전 3배 | 후 3배] (장면 64×72 px)
        func ingame(_ rows: [(String, [UInt8], [UInt8], Meas, Meas)], name: String) throws {
            let bw = 64, bh = 72, Wd = bw * 2 + bw * 3 * 2 + 40, rh = bh * 3 + 16
            let Hd = rows.count * rh + 4
            var img = [UInt8](repeating: 20, count: Wd * Hd * 4)
            var labels: [(String, Int, Int, Bool)] = []
            for (r, row) in rows.enumerated() {
                let cx = Int(row.3.neckPt.x.rounded()) - bw / 2, cy = Int(row.3.neckPt.y.rounded()) - 24
                let oy = r * rh + 14
                for (k, (px, z, ox)) in [(row.1, 1, 4), (row.2, 1, 4 + bw + 6), (row.1, 3, 4 + bw * 2 + 20), (row.2, 3, 4 + bw * 2 + 26 + bw * 3)].enumerated() {
                    _ = k
                    for y in 0..<bh * z { for x in 0..<bw * z {
                        let sx = cx + x / z, sy = cy + y / z
                        guard sx >= 0, sy >= 0, sx < W, sy < tmpl.height else { continue }
                        let s = (sy * W + sx) * 4, d = ((oy + y) * Wd + ox + x) * 4
                        img[d] = Self.lift(px[s]); img[d + 1] = Self.lift(px[s + 1]); img[d + 2] = Self.lift(px[s + 2]); img[d + 3] = 255
                    } }
                }
                labels.append((row.0 + String(format: "   (전 틈 %.1fpx → 후 %.1fpx)   왼쪽 1배 [전|후] · 오른쪽 3배 [전|후]", row.3.gap, row.4.gap), 4, oy - 13, row.3.gap >= 1))
            }
            try NeckAuditTests.png(img, Wd, Hd, name, labels: labels)
        }
    }

    static func png(_ px0: [UInt8], _ W: Int, _ H: Int, _ name: String, labels: [(String, Int, Int, Bool)]) throws {
        var px = px0
        let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for (s, x, y, hot) in labels {
            let font = CTFontCreateWithName("AppleSDGothicNeo-Bold" as CFString, 10, nil)
            let col = hot ? CGColor(red: 1, green: 0.8, blue: 0.3, alpha: 1) : CGColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
            let attr = NSAttributedString(string: s, attributes: [kCTFontAttributeName as NSAttributedString.Key: font, kCTForegroundColorAttributeName as NSAttributedString.Key: col])
            ctx.textPosition = CGPoint(x: x, y: H - y - 10)
            CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
        }
        let url = out.appending(path: name + ".png")
        let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        print("[neck] \(name) → \(url.path)")
    }
}
