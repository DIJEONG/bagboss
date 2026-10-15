import Foundation
import BBContent

// 가방 미리보기 · 타일 표기 — 상태를 바꾸지 않는 순수 계산(웹 33-bag-ui2 previewPlace · showPreview · bagPower · labelRect · tileStats · linkMarks,
// 32-block-art rtScore · rtSuggest · routeLayer 의 앵커 · routeBadgeMap). UI 는 이 값을 그리기만 한다.

/// 콤보 경로 변화 한 줄(웹 showPreview 의 pv-c · pv-dn)
public enum RouteChange: Sendable, Equatable {
    /// 새 콤보 — color = 경로 순번(RT_COL 색 번호)
    case new(name: String, color: Int)
    case changed(from: String, to: String, color: Int)
    case cut(name: String)
}

/// 웹 previewPlace 결과 + 콤보 경로 변화
public struct PlacePreview: Sendable, Equatable {
    /// 가방 화력 변화율(0.12 = +12%)
    public var dp: Double
    /// 옮기는 기술의 지금 · 놓은 뒤 능력치(기술만)
    public var before: BagRules.ItemStats?, after: BagRules.ItemStats?
    /// 새로 생기는 연계 이름 · 세트 계열
    public var newLinks: [String], newSets: [String]
    /// 놓을 자리의 각인 종류(칸 순서)
    public var imprints: [String]
    public var routes: [RouteChange]
}

/// 웹 showPreview 의 보류함 분기
public struct StashPreview: Sendable, Equatable {
    /// 그 자리에 바로 둘 수 있나
    public var direct: Bool
    /// 못 두면(가방에서 온 것만) 빈 곳
    public var alt: Cell?
    public var altRot: Int?
    public var ok: Bool { direct || alt != nil }
    /// 가방에서 빠지면 끊기는 콤보
    public var cut: [String]
    /// 가방에서 빠지는 기술(쓰지 않게 됨)
    public var dropsSkill: Bool
}

/// 미리보기 툴팁 한 줄(웹 .inv-prev 줄 · 색 갈래)
public struct PreviewLine: Sendable, Equatable {
    public enum Style: String, Sendable { case up, down, even, info, link, imprint, bad, merge, combo }
    public var text: String, style: Style
    /// combo 줄의 경로 색 번호
    public var color: Int?
    public init(_ text: String, _ style: Style, color: Int? = nil) { self.text = text; self.style = style; self.color = color }
}

/// 타일 표기 값(웹 tileStats)
public struct TileStats: Sendable, Equatable {
    public var dmg: String?
    public var cd: String?
    public var val: String?
    public var valColor: String?
    public var hasCd: Bool
}

/// 이름표 자리(웹 labelRect): 모양 안 가장 큰 직사각형(최대 3×3)
public struct LabelRect: Sendable, Equatable { public var x: Int, y: Int, w: Int, h: Int }

/// 닿은 경계 표시(웹 linkMarks): nm 이름 붙은 연계 · ch 연쇄 · bf 보조
public struct LinkMark: Sendable, Equatable {
    public var type: String
    /// 가방 칸 좌표(소수) — vertical 이면 세로 막대(좌우로 닿음)
    public var x: Double, y: Double
    public var vertical: Bool
    public var name: String?
}

/// 경로 배지(웹 routeBadgeMap): 경로 안 순번 · 색 번호
public struct RouteBadge: Sendable, Equatable { public var n: Int, color: Int }

extension BagCatalog {
    /// 웹 DMG_K: 화면 표시 배율
    public static let dmgScale = 100.0

    func indexOf(_ uid: Int, _ bag: [BagItem]) -> Int? { bag.firstIndex { $0.uid == uid } }

    /// 웹 bagPower: 기술마다 피해/쿨다운 × 치명 기댓값의 합
    public func power(_ bag: [BagItem], sets: [String: [Int]], imprints: [String: String]) -> Double {
        var s = 0.0
        for (i, b) in bag.enumerated() where item(b.id)?.kind == "skill" {
            let st = rules.stats(i, bag: bag, sets: sets, imprints: imprints)
            s += st.dmg / max(0.3, st.cd ?? 0) * (1 + st.crit * max(0, st.critD - 1))
        }
        return s
    }

    /// 웹 linkNamesOf: 닿은 아이템과의 연계 이름(가방 순서 · 중복 없이)
    public func linkNames(_ i: Int, in bag: [BagItem]) -> [String] {
        var out: [String] = []
        for j in rules.adjacent(i, in: bag) { if let L = linkBetween(bag[i].id, bag[j].id), !out.contains(L.name) { out.append(L.name) } }
        return out
    }

    /// 웹 impAt: 그 자리 칸들의 각인(칸 순서 · 중복 없이)
    public func imprintsAt(_ b: BagItem, x: Int, y: Int, rot: Int, _ map: [String: String]) -> [String] {
        var out: [String] = []
        for c in rules.cells(b, x: x, y: y, rot: rot) { if let t = map["\(c.x),\(c.y)"], !out.contains(t) { out.append(t) } }
        return out
    }

    /// 웹 routesOf 의 색 번호까지
    public func routes(_ list: [BagItem]) -> [(route: ComboRoute, color: Int)] {
        rules.routes(list).enumerated().map { ($1, $0 % BagCatalog.routeColors.count) }
    }

    /// 웹 previewPlace + showPreview 경로 줄: uid 를 (x, y, rot) 에 놓으면
    public func previewPlace(_ s: BagState, uid: Int, x: Int, y: Int, rot: Int) -> PlacePreview? {
        guard let b = s.item(uid) else { return nil }
        let sk = item(b.id)?.kind == "skill", i0 = indexOf(uid, s.bag)
        let bag0 = s.bag, sets0 = rules.sets(bag0), p0 = power(bag0, sets: sets0, imprints: s.imprints)
        let l0 = i0.map { linkNames($0, in: bag0) } ?? []
        let st0 = (i0 != nil && sk) ? rules.stats(i0!, bag: bag0, sets: sets0, imprints: s.imprints) : nil
        var bag1 = bag0, moved = b
        moved.x = x; moved.y = y; moved.rot = rot
        if let i = i0 { bag1[i] = moved } else { bag1.append(moved) }
        let i1 = i0 ?? bag1.count - 1
        let sets1 = rules.sets(bag1), p1 = power(bag1, sets: sets1, imprints: s.imprints)
        let l1 = linkNames(i1, in: bag1)
        let st1 = sk ? rules.stats(i1, bag: bag1, sets: sets1, imprints: s.imprints) : nil
        // 콤보 경로: 웹은 '빼고 맨 뒤에 붙인' 가설 가방으로 본다
        let hyp = bag0.filter { $0.uid != uid } + [moved]
        let R0 = routes(bag0), R1 = routes(hyp)
        var rl: [RouteChange] = []
        for (r, col) in R1 {
            if let o = R0.first(where: { $0.route.uids.first == r.uids.first }) {
                if o.route.key != r.key { rl.append(.changed(from: o.route.name, to: r.name, color: col)) }
            } else { rl.append(.new(name: r.name, color: col)) }
        }
        for (o, _) in R0 where !R1.contains(where: { $0.route.uids.first == o.uids.first }) { rl.append(.cut(name: o.name)) }
        return PlacePreview(dp: p0 > 0 ? p1 / p0 - 1 : (p1 > 0 ? 1 : 0), before: st0, after: st1,
                            newLinks: l1.filter { !l0.contains($0) }, newSets: rules.families.filter { sets1[$0] != nil && sets0[$0] == nil },
                            imprints: imprintsAt(b, x: x, y: y, rot: rot, s.imprints), routes: rl)
    }

    /// 웹 showPreview 의 보류함 분기
    public func previewStash(_ s: BagState, uid: Int, x: Int, y: Int, rot: Int) -> StashPreview? {
        guard let b = s.item(uid) else { return nil }
        let fromBag = s.inBag(uid)
        let direct = rules.canStash(b, x: x, y: y, rot: rot, in: s.stash)
        let alt = (!direct && fromBag) ? rules.stashSpot(b, in: s.stash, rot0: rot) : nil
        var cut: [String] = []
        let ok = direct || alt != nil
        if ok && fromBag {
            let hyp = s.bag.filter { $0.uid != uid }, R1 = rules.routes(hyp)
            for o in rules.routes(s.bag) where !R1.contains(where: { $0.key == o.key }) { cut.append(o.name) }
        }
        return StashPreview(direct: direct, alt: alt.map { Cell($0.sx, $0.sy) }, altRot: alt?.rot, cut: cut,
                            dropsSkill: ok && fromBag && item(b.id)?.kind == "skill")
    }

    /// 웹 rtScore: 경로 길이 합(마무리로 끝나면 +1)
    public func routeScore(_ list: [BagItem]) -> Int {
        rules.routes(list).reduce(0) { acc, r in
            let last = list.first { $0.uid == r.uids.last }!
            return acc + r.uids.count + (rules.role(last.id) == "F" ? 1 : 0)
        }
    }

    /// 웹 rtSuggest: 기술을 rot 방향으로 놓을 수 있는 칸마다 콤보 점수 증가(>0 만). best = 가장 큰 증가
    public func routeSuggest(_ s: BagState, uid: Int, rot: Int) -> (hits: [(x: Int, y: Int, v: Int)], best: Int) {
        guard let b = s.item(uid), item(b.id)?.kind == "skill" else { return ([], 0) }
        let base = s.bag.filter { $0.uid != uid }, s0 = routeScore(base)
        var hits: [(x: Int, y: Int, v: Int)] = [], best = 0
        for y in 0..<BagSpec.height { for x in 0..<BagSpec.width where rules.canPlace(b, x: x, y: y, rot: rot, in: s.bag) {
            var m = b; m.x = x; m.y = y; m.rot = rot
            let v = routeScore(base + [m]) - s0
            if v > 0 { hits.append((x, y, v)); best = max(best, v) }
        } }
        return (hits, best)
    }

    /// 웹 fmtD: 표시 피해(×100 · 1만 넘으면 k)
    public static func formatDamage(_ v: Double) -> String {
        let n = JSFormat.round(v * dmgScale)
        return n >= 10000 ? JSFormat.fixed(Double(n) / 1000, n >= 100000 ? 0 : 1) + "k" : String(n)
    }

    /// 웹 tileStats
    public func tileStats(_ b: BagItem, in s: BagState) -> TileStats {
        guard let it = item(b.id) else { return TileStats(hasCd: false) }
        let t = b.tier, k = it.kind
        let P = { (v: Double) in "\(JSFormat.round(v * 100))%" }
        if k == "skill" || k == "dodge" {
            var dmg: Double, cd: Double
            if let i = indexOf(b.uid, s.bag) {
                let st = rules.stats(i, bag: s.bag, sets: rules.sets(s.bag), imprints: s.imprints); dmg = st.dmg; cd = st.cd ?? 0
            } else {
                dmg = (it.dmg ?? 0) * BagSpec.tierDamage(t) * (1 + (b.opt?.k == "dmg" ? b.opt!.v : 0))
                cd = (it.cd ?? 0) * BagSpec.tierCooldown(t) * (1 - (b.opt?.k == "cd" ? b.opt!.v : 0))
            }
            return TileStats(dmg: (it.dmg ?? 0) != 0 ? Self.formatDamage(dmg) + (it.combo == true ? "+" : "") : nil, cd: JSFormat.fixed(cd, 1), hasCd: true)
        }
        let d = Double(t - 1)
        let V: (String, String)? = switch k {
        case "crit": ("+" + P(0.12 + 0.04 * d), "#ff8a7a")
        case "critd": ("+" + P(0.40 + 0.15 * d), "#ffb067")
        case "gem": ("+" + P(0.25 + 0.08 * d), "#ffe27a")
        case "stone": ("−" + P(0.18 + 0.05 * d), "#8cc4ff")
        case "metro": ("↕−" + P(0.12 + 0.03 * d), "#8cc4ff")
        case "cuff": ("⤡+" + P(0.10 + 0.03 * d), "#ff8a7a")
        case "knuckle": ("+" + P(0.25 + 0.08 * d), "#ffe27a")
        case "shoes": ("−" + P(0.10 + 0.02 * d), "#8cc4ff")
        case "armor": ("+" + JSFormat.string(30 + 15 * d), "#8dff9a")
        case "heal": ("+" + JSFormat.string((it.heal ?? 0) + 6 * d), "#8dff9a")
        case "gum": ("+" + JSFormat.fixed(1.5 + 0.3 * d, 1) + "초", "#e8d6a8")
        case "ear": ("+" + P(0.6 + 0.15 * d), "#e8d6a8")
        case "watch": ("+" + P(0.30 + 0.05 * d), "#d4b4ff")
        default: nil
        }
        return TileStats(cd: k == "heal" ? JSFormat.string((it.cd ?? 0) - d) : nil, val: V?.0, valColor: V?.1, hasCd: k == "heal")
    }

    /// 웹 linkMarks: 닿은 쌍마다 첫 맞닿은 경계 한 곳
    public func linkMarks(_ bag: [BagItem]) -> [LinkMark] {
        let BUFF: Set<String> = ["gem", "stone", "crit", "critd"]
        var out: [LinkMark] = []
        for i in bag.indices { for j in rules.adjacent(i, in: bag) where j > i {
            let A = bag[i], B = bag[j], ka = item(A.id)?.kind ?? "", kb = item(B.id)?.kind ?? ""
            let L = linkBetween(A.id, B.id), sk = { (k: String) in k == "skill" || k == "dodge" }
            let type: String? = L != nil ? "nm" : (ka == "skill" && kb == "skill") ? "ch" : ((BUFF.contains(ka) && sk(kb)) || (BUFF.contains(kb) && sk(ka))) ? "bf" : nil
            guard let ty = type else { continue }
            let cb = rules.cells(B)
            search: for a in rules.cells(A) { for c in cb where abs(a.x - c.x) + abs(a.y - c.y) == 1 {
                out.append(a.x != c.x ? LinkMark(type: ty, x: Double(max(a.x, c.x)), y: Double(a.y) + 0.5, vertical: true, name: L?.name)
                                      : LinkMark(type: ty, x: Double(a.x) + 0.5, y: Double(max(a.y, c.y)), vertical: false, name: L?.name))
                break search
            } }
        } }
        return out
    }

    /// 웹 routeBadgeMap
    public func routeBadges(_ bag: [BagItem]) -> [Int: RouteBadge] {
        var M: [Int: RouteBadge] = [:]
        for (r, col) in routes(bag) { for (n, u) in r.uids.enumerated() where M[u] == nil { M[u] = RouteBadge(n: n + 1, color: col) } }
        return M
    }

    /// 웹 routeLayer 앵커: 타일 역할 배지 자리(가방 칸 좌표)
    public func routeAnchor(_ b: BagItem) -> (x: Double, y: Double) {
        let L = labelRect(b.id, rot: b.rot)
        return (Double(b.x + L.x) + 0.3, Double(b.y + L.y) + 0.26)
    }

    /// 웹 labelRect
    public func labelRect(_ id: String, rot: Int) -> LabelRect {
        let c = rules.shape(id, rot: rot), S = Set(c), W = c.map(\.x).max()! + 1, H = c.map(\.y).max()! + 1
        var best: (LabelRect, Double)?
        for y in 0..<H { for x in 0..<W { for h in 1...3 { for w in 1...3 {
            var ok = true
            outer: for yy in y..<(y + h) { for xx in x..<(x + w) where !S.contains(Cell(xx, yy)) { ok = false; break outer } }
            if !ok { continue }
            let sc = Double(w * h * 10 + (h >= 2 ? 3 : 0)) - Double(y) * 0.5 - Double(x) * 0.1
            if best == nil || sc > best!.1 { best = (LabelRect(x: x, y: y, w: w, h: h), sc) }
        } } } }
        return best!.0
    }

    /// 미리보기 툴팁 줄(웹 showPreview 문구 그대로)
    public func previewLines(_ P: PlacePreview) -> [PreviewLine] {
        let pct = JSFormat.round(P.dp * 100), fmt = { (v: Double) in Self.formatDamage(v) }
        var L = [PreviewLine("가방 화력 \(pct > 0 ? "+" : "")\(pct)%", pct > 0 ? .up : pct < 0 ? .down : .even)]
        if let a = P.after {
            if let b = P.before { L.append(PreviewLine("피해 \(fmt(b.dmg))→\(fmt(a.dmg)) · 쿨 \(JSFormat.fixed(b.cd ?? 0, 1))→\(JSFormat.fixed(a.cd ?? 0, 1))초", .info)) }
            else { L.append(PreviewLine("피해 \(fmt(a.dmg)) · 쿨 \(JSFormat.fixed(a.cd ?? 0, 1))초", .info)) }
        }
        for n in P.newLinks { L.append(PreviewLine("새 연계: \(n)", .link)) }
        for f in P.newSets { L.append(PreviewLine("\(families[f]?.n ?? f) 세트 완성!", .link)) }
        for t in P.imprints {
            let d = (Self.imprintDesc[t] ?? "").replacingOccurrences(of: "이 칸에 걸친 기술 ", with: "")
            L.append(PreviewLine("각인 · \(Self.imprintNames[t] ?? t): \(d)", t == "worn" ? .down : .imprint))
        }
        for r in P.routes {
            switch r {
            case .new(let n, let c): L.append(PreviewLine("새 콤보: \(n)", .combo, color: c))
            case .changed(let a, let b, let c): L.append(PreviewLine("\(a) → \(b)", .combo, color: c))
            case .cut(let n): L.append(PreviewLine("\(n) 끊김", .down))
            }
        }
        return L
    }

    public func stashLines(_ P: StashPreview) -> [PreviewLine] {
        var L = [P.direct ? PreviewLine("보류함에 잠시 두기", .even) : P.alt != nil ? PreviewLine("보류함 빈 곳에 두기", .even) : PreviewLine("보류함에 자리가 모자라요", .bad)]
        for n in P.cut { L.append(PreviewLine("\(n) 끊김", .down)) }
        if P.dropsSkill { L.append(PreviewLine("가방에서 빠지면 쓰지 않아요", .down)) }
        return L
    }

    public func mergeLines(tier t: Int) -> [PreviewLine] {
        [PreviewLine("합성 ★\(t) → ★\(t + 1)", .merge), PreviewLine("성공 \(JSFormat.round(mergeChance(tier: t) * 100))% · 실패해도 토큰 1개", .info)]
    }
}
