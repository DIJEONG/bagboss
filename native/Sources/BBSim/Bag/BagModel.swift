import Foundation
import BBContent

/// 가방 · 보류함의 아이템 하나(웹 GS.bag / GS.stash 항목). 저장 형식(RunSave.Item)과 같은 필드.
public struct BagItem: Sendable, Equatable, Codable {
    public var id: String
    public var uid: Int
    public var tier: Int = 1
    /// 가방 자리(왼쪽 위 칸) — 가방에 있을 때
    public var x: Int = 0, y: Int = 0
    public var rot: Int = 0
    public var opt: ItemOption?
    /// 보류함 자리 — 보류함에 있을 때
    public var sx: Int?, sy: Int?
    /// 콤보 경로 고정 핀(다음으로 갈 블록 uid)
    public var pin: Int?
    /// 쿨다운 누적(초)
    public var t: Double = 0

    public init(id: String, uid: Int, tier: Int = 1, x: Int = 0, y: Int = 0, rot: Int = 0, opt: ItemOption? = nil) {
        self.id = id; self.uid = uid; self.tier = tier; self.x = x; self.y = y; self.rot = rot; self.opt = opt
    }
    enum CodingKeys: String, CodingKey { case id, uid, tier, x, y, rot, opt, sx, sy, pin, t }
    /// 웹 저장값은 필드가 빠져 있을 수 있다 — 없으면 웹 기본값(tier 1 · rot 0 · t 0)
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); uid = try c.decode(Int.self, forKey: .uid)
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 1
        x = try c.decodeIfPresent(Int.self, forKey: .x) ?? 0; y = try c.decodeIfPresent(Int.self, forKey: .y) ?? 0
        rot = try c.decodeIfPresent(Int.self, forKey: .rot) ?? 0
        opt = try c.decodeIfPresent(ItemOption.self, forKey: .opt)
        sx = try c.decodeIfPresent(Int.self, forKey: .sx); sy = try c.decodeIfPresent(Int.self, forKey: .sy)
        pin = try c.decodeIfPresent(Int.self, forKey: .pin)
        t = try c.decodeIfPresent(Double.self, forKey: .t) ?? 0
    }
}

/// 가방 격자 크기(웹 INV) · 등급 · 합성 상수
public enum BagSpec {
    public static let width = 6, height = 4, stashWidth = 2, stashHeight = 4
    public static let tierMax = 5
    public static let mergeBoost = 0.15, boostCost = 3, rerollCost = 2
    public static let critBase = 0.08, critDamageBase = 1.6
    /// 웹 tDmg · tCd: 등급 보정
    public static func tierDamage(_ t: Int) -> Double { 1 + 0.3 * Double(t - 1) }
    public static func tierCooldown(_ t: Int) -> Double { 1 - 0.06 * Double(t - 1) }
}

public struct Cell: Hashable, Sendable { public var x: Int, y: Int; public init(_ x: Int, _ y: Int) { self.x = x; self.y = y } }

/// 가방에 관한 판정 전부 — 상태를 바꾸지 않는 순수 함수(웹 26-bag-model · 33-bag-ui2 일부 · 27 sStats · 32 콤보 경로)
public struct BagRules: Sendable {
    public let items: OrderedTable<ItemDef>
    public let roles: OrderedTable<ComboRole>
    public let book: [ComboRecipe]
    /// 계열(웹 FAMS) — 순서가 세트 판정 순서
    public let families: [String]
    /// 콤보 이름 머리말(웹 CN)
    public let stateNames: [String: String]

    public init(_ c: GameContent, store: ContentStore) throws {
        items = c.items; roles = c.comboRoles; book = c.comboBook
        families = store.entries["FAMS"]?.keyOrder ?? ["fist", "foot", "grap"]
        stateNames = (try? store.decode("CN")) ?? ["A": "공중", "T": "걸어 넘기기", "C": "무너뜨리기", "Z": "반격", "P": "끌어치기", "D": "다운", "B": "등 돌리기", "K": "날리기", "G": "연속"]
    }

    func def(_ id: String) -> ItemDef? { items[id] }

    // MARK: 모양

    /// 웹 shapeOf: 회전(시계 반대 90°씩) 후 왼쪽 위로 붙인 칸들
    public func shape(_ id: String, rot: Int) -> [Cell] {
        var c = (def(id)?.shape ?? [[0, 0]]).map { Cell($0[0], $0[1]) }
        let r = ((rot % 4) + 4) % 4
        for _ in 0..<r { c = c.map { Cell(-$0.y, $0.x) } }
        let mx = c.map(\.x).min()!, my = c.map(\.y).min()!
        return c.map { Cell($0.x - mx, $0.y - my) }
    }
    public func cells(_ b: BagItem, x: Int? = nil, y: Int? = nil, rot: Int? = nil) -> [Cell] {
        let ox = x ?? b.x, oy = y ?? b.y
        return shape(b.id, rot: rot ?? b.rot).map { Cell(ox + $0.x, oy + $0.y) }
    }
    /// 웹 itemBox: 모양의 폭 · 높이
    public func box(_ b: BagItem, rot: Int? = nil) -> (w: Int, h: Int) {
        let c = shape(b.id, rot: rot ?? b.rot)
        return (c.map(\.x).max()! + 1, c.map(\.y).max()! + 1)
    }
    public func size(_ id: String) -> Int { def(id)?.shape.count ?? 1 }
    public func tokenValue(_ b: BagItem) -> Int { size(b.id) * b.tier }

    // MARK: 가방 배치

    func occupied(_ bag: [BagItem], except uid: Int?) -> Set<Cell> {
        var s = Set<Cell>()
        for b in bag where b.uid != uid { for c in cells(b) { s.insert(c) } }
        return s
    }
    /// 웹 canPlace
    public func canPlace(_ b: BagItem, x: Int, y: Int, rot: Int, in bag: [BagItem], except uid: Int? = nil) -> Bool {
        let m = occupied(bag, except: uid ?? b.uid)
        return cells(b, x: x, y: y, rot: rot).allSatisfy { $0.x >= 0 && $0.y >= 0 && $0.x < BagSpec.width && $0.y < BagSpec.height && !m.contains($0) }
    }
    /// 웹 findSpot: 지금 방향부터 네 방향, 위→아래 · 왼→오른쪽
    public func findSpot(_ b: BagItem, in bag: [BagItem]) -> (x: Int, y: Int, rot: Int)? {
        for rot in [b.rot, (b.rot + 1) % 4, (b.rot + 2) % 4, (b.rot + 3) % 4] {
            for y in 0..<BagSpec.height { for x in 0..<BagSpec.width where canPlace(b, x: x, y: y, rot: rot, in: bag) { return (x, y, rot) } }
        }
        return nil
    }
    /// 웹 adjItems: 가방 i 번째와 변으로 닿은 아이템들의 위치(가방 순서)
    public func adjacent(_ i: Int, in bag: [BagItem]) -> [Int] {
        guard bag.indices.contains(i) else { return [] }
        let mine = Set(cells(bag[i]))
        return bag.indices.filter { j in
            j != i && cells(bag[j]).contains { c in mine.contains(Cell(c.x + 1, c.y)) || mine.contains(Cell(c.x - 1, c.y)) || mine.contains(Cell(c.x, c.y + 1)) || mine.contains(Cell(c.x, c.y - 1)) }
        }
    }

    // MARK: 보류함(2×4) — 폭이 2를 넘는 방향은 2×2로 접어 둔다

    public func stashFoot(_ b: BagItem, rot: Int) -> (w: Int, h: Int, fold: Bool) {
        let (w, h) = box(b, rot: rot)
        return w <= BagSpec.stashWidth && h <= BagSpec.stashHeight ? (w, h, false) : (2, 2, true)
    }
    public func stashCells(_ b: BagItem, x: Int, y: Int, rot: Int) -> [Cell] {
        stashFoot(b, rot: rot).fold ? [Cell(x, y), Cell(x + 1, y), Cell(x, y + 1), Cell(x + 1, y + 1)] : cells(b, x: x, y: y, rot: rot)
    }
    public func canStash(_ b: BagItem, x: Int, y: Int, rot: Int, in stash: [BagItem], except uid: Int? = nil) -> Bool {
        var m = Set<Cell>()
        for o in stash where o.uid != (uid ?? b.uid) { if let sx = o.sx, let sy = o.sy { for c in stashCells(o, x: sx, y: sy, rot: o.rot) { m.insert(c) } } }
        return stashCells(b, x: x, y: y, rot: rot).allSatisfy { $0.x >= 0 && $0.y >= 0 && $0.x < BagSpec.stashWidth && $0.y < BagSpec.stashHeight && !m.contains($0) }
    }
    /// 웹 stashSpot: 접지 않는 방향 먼저, 그다음 접는 방향
    public func stashSpot(_ b: BagItem, in stash: [BagItem], rot0: Int? = nil) -> (sx: Int, sy: Int, rot: Int)? {
        let r0 = rot0 ?? b.rot, R = [r0, (r0 + 1) % 4, (r0 + 2) % 4, (r0 + 3) % 4]
        for pass in [false, true] { for rot in R where stashFoot(b, rot: rot).fold == pass {
            for y in 0..<BagSpec.stashHeight { for x in 0..<BagSpec.stashWidth where canStash(b, x: x, y: y, rot: rot, in: stash) { return (x, y, rot) } }
        } }
        return nil
    }

    // MARK: 세트 · 능력치

    /// 웹 computeSets: 같은 계열끼리 닿아 이어진 덩어리 안에 서로 다른 3종 이상 → 그 덩어리 uid 들(계열마다 마지막으로 찾은 덩어리)
    public func sets(_ bag: [BagItem]) -> [String: [Int]] {
        var on: [String: [Int]] = [:]
        for f in families {
            let its = bag.indices.filter { def(bag[$0].id)?.fam == f }
            var seen = Set<Int>()
            for s0 in its where !seen.contains(s0) {
                var comp = [s0], q = [s0]; seen.insert(s0)
                while let c = q.popLast() {
                    for o in adjacent(c, in: bag) where def(bag[o].id)?.fam == f && !seen.contains(o) { seen.insert(o); comp.append(o); q.append(o) }
                }
                if Set(comp.map { bag[$0].id }).count >= 3 { on[f] = comp.map { bag[$0].uid } }
            }
        }
        return on
    }

    /// 웹 dirRel: 두 칸 묶음이 세로 · 가로 · 대각으로 닿았나
    func dirRel(_ A: [Cell], _ B: [Cell]) -> (v: Bool, h: Bool, d: Bool) {
        var v = false, h = false, d = false
        for a in A { for b in B { let dx = abs(a.x - b.x), dy = abs(a.y - b.y)
            if dx == 0 && dy == 1 { v = true } else if dx == 1 && dy == 0 { h = true } else if dx == 1 && dy == 1 { d = true } } }
        return (v, h, d)
    }
    /// 웹 impOf: 이 아이템이 걸친 각인 칸 종류
    public func imprints(_ b: BagItem, _ map: [String: String]) -> Set<String> {
        Set(cells(b).compactMap { map["\($0.x),\($0.y)"] })
    }
    /// 웹 pv: 그 종류 보조 아이템 합산
    func passive(_ bag: [BagItem], kind: String, base: Double, per: Double) -> Double {
        bag.filter { def($0.id)?.kind == kind }.reduce(0) { $0 + base + per * Double($1.tier - 1) }
    }

    public struct ItemStats: Sendable, Equatable {
        public var dmg: Double
        /// 기술이 아닌 아이템은 없음(웹은 NaN)
        public var cd: Double?
        public var crit: Double, critD: Double
        public var set: Bool
        public var gem: Int, stone: Int, pins: Int, rings: Int, metros: Int, cuffs: Int
        public var imprints: Set<String>
    }

    /// 웹 sStats: 닿은 보조 아이템 · 방향 시너지 · 각인 · 옵션 · 세트 · 등급을 합친 실제 피해 · 쿨다운 · 치명
    public func stats(_ i: Int, bag: [BagItem], sets: [String: [Int]], imprints map: [String: String]) -> ItemStats {
        let b = bag[i], it = def(b.id)
        var gem = 0, stone = 0, gb = 0.0, sb = 0.0, cr = BagSpec.critBase, cdm2 = BagSpec.critDamageBase, pins = 0, rings = 0, metros = 0, cuffs = 0
        for o in adjacent(i, in: bag) {   // 닿은 부적 · 캔커피 · 넥타이핀 · 인장 반지
            let k = def(bag[o].id)?.kind, t = Double(bag[o].tier)
            if k == "gem" { gem += 1; gb += 0.25 + 0.08 * (t - 1) }
            if k == "stone" { stone += 1; sb += 0.18 + 0.05 * (t - 1) }
            if k == "crit" { pins += 1; cr += 0.12 + 0.04 * (t - 1) }
            if k == "critd" { rings += 1; cdm2 += 0.40 + 0.15 * (t - 1) }
        }
        let mc = cells(b)
        for o in bag where o.uid != b.uid {   // 메트로 카드(세로) · 커프스(대각)
            let k = def(o.id)?.kind; guard k == "metro" || k == "cuff" else { continue }
            let D = dirRel(mc, cells(o)), t = Double(o.tier)
            if k == "metro" && D.v { sb += 0.12 + 0.03 * (t - 1); metros += 1 }
            if k == "cuff" && D.d && !(D.v || D.h) { cr += 0.10 + 0.03 * (t - 1); cuffs += 1 }
        }
        let imp = imprints(b, map)
        if imp.contains("pocket") { cr += 0.08 }
        if let op = b.opt { if op.k == "crit" { cr += op.v }; if op.k == "critd" { cdm2 += op.v }; if op.k == "dmg" { gb += op.v }; if op.k == "cd" { sb += op.v } }
        let inSet = it?.fam.map { sets[$0]?.contains(b.uid) ?? false } ?? false
        let cdm = BagSpec.tierCooldown(b.tier) * (1 - min(0.6, sb)) * (1 - min(0.3, passive(bag, kind: "shoes", base: 0.10, per: 0.02)))
            * (inSet ? 0.9 : 1) * (imp.contains("holster") ? 0.9 : 1)
        let fistK = it?.fist == true ? 1 + passive(bag, kind: "knuckle", base: 0.25, per: 0.08) : 1
        let dmg = (it?.dmg ?? 0) * BagSpec.tierDamage(b.tier) * (1 + gb) * fistK * (inSet ? 1.2 : 1) * (imp.contains("worn") ? 0.8 : 1)
        let cd = it?.cd.map { max($0 * 0.35, $0 * cdm) }
        return ItemStats(dmg: dmg, cd: cd, crit: min(0.75, cr), critD: cdm2, set: inSet, gem: gem, stone: stone, pins: pins, rings: rings, metros: metros, cuffs: cuffs, imprints: imp)
    }
}
