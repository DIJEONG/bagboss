import Testing
import Foundation
@testable import BBSim
import BBContent

/// 웹 가방 UI 픽스처(tools/js/extract/bagui.mjs · 150판)와 대조: 이름표 자리 · 연계 · 놓기 미리보기 · 보류함 미리보기 · 추천 칸 · 타일 표기 · 편집 행동
@Suite struct BagEditorParityTests {
    struct Fixture: Decodable { let labels: [String: [[Int]]]; let links: [[String]]; let cases: [Case] }
    struct Input: Decodable { let bag: [BagItem]; let stash: [BagItem]; let tokens: Int; let imprints: [String: String]; let uid: Int; let isNew: [Int] }
    struct St: Decodable { let dmg: Double; let cd: Double? }
    struct Prev: Decodable { let uid: Int, x: Int, y: Int, rot: Int; let ok: Bool
        let dp: Double?; let st0: St?; let st1: St?; let newL: [String]?; let newS: [String]?; let imp: [String]?; let routes: [[JSONValue]]? }
    struct Spot: Decodable { let sx: Int, sy: Int, rot: Int }
    struct SPrev: Decodable { let uid: Int, x: Int, y: Int, rot: Int; let ok0: Bool; let alt: Spot?; let cut: [String]; let dropSkill: Bool }
    struct Sug: Decodable { let uid: Int, rot: Int; let hits: [[Int]] }
    struct Tile: Decodable { let uid: Int; let dmg: String?; let cd: String?; let val: String?; let hasCd: Bool }
    struct After: Decodable { let bag: [BagItem]; let stash: [BagItem]; let tokens: Int; let sel: Int?; let undo: Int; let isNew: [Int] }
    struct Op: Decodable { let op: String; let uid: Int?; let src: Int?; let dst: Int?; let boost: Bool?; let roll: Double?; let x: Int?; let y: Int?; let rot: Int?; let after: After }
    struct Case: Decodable { let input: Input; let previews: [Prev]; let stashPrev: [SPrev]; let suggest: [Sug]; let tiles: [Tile]; let ops: [Op] }

    static let fx: Fixture = try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf:
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/bagui/bagui.json")))
    static let cat: BagCatalog = { let s = try! ContentStore.bundled(); return try! BagCatalog(try! GameContent(s), store: s) }()
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= 2e-6 * max(1, abs(b)) }
    static func state(_ i: Input) -> BagState {
        BagState(bag: i.bag, stash: i.stash, tokens: i.tokens, imprints: i.imprints, uid: i.uid, newUids: Set(i.isNew))
    }

    @Test func labelRectsMatch() {
        for (id, rots) in Self.fx.labels { for (r, w) in rots.enumerated() {
            let L = Self.cat.labelRect(id, rot: r); #expect([L.x, L.y, L.w, L.h] == w, "\(id) rot \(r)") } }
    }

    @Test func linksMatch() {
        let ids = Self.cat.rules.items.keys
        var mine: [[String]] = []
        for a in ids { for b in ids { if let L = Self.cat.linkBetween(a, b) { mine.append([a, b, L.id]) } } }
        #expect(mine == Self.fx.links)
    }

    @Test func placePreviewsMatch() {
        var fails: [String] = [], n = 0
        for (ci, c) in Self.fx.cases.enumerated() {
            let s = Self.state(c.input)
            for p in c.previews {
                let b = s.item(p.uid)!
                #expect(Self.cat.rules.canPlace(b, x: p.x, y: p.y, rot: p.rot, in: s.bag) == p.ok)
                guard p.ok, let P = Self.cat.previewPlace(s, uid: p.uid, x: p.x, y: p.y, rot: p.rot) else { continue }
                n += 1
                let stOK = { (a: BagRules.ItemStats?, w: St?) in (a == nil) == (w == nil) && (a == nil || (Self.close(a!.dmg, w!.dmg) && Self.close(a!.cd ?? -1, w!.cd ?? -1))) }
                let routes: [[JSONValue]] = P.routes.map { switch $0 {
                    case .new(let n, let c): [.string("new"), .string(n), .string(BagCatalog.routeColors[c])]
                    case .changed(let a, let b, let c): [.string("chg"), .string(a), .string(b), .string(BagCatalog.routeColors[c])]
                    case .cut(let n): [.string("cut"), .string(n)] } }
                if !Self.close(P.dp, p.dp!) || !stOK(P.before, p.st0) || !stOK(P.after, p.st1) || P.newLinks != p.newL! || P.newSets != p.newS! || P.imprints != p.imp! || routes != p.routes! {
                    fails.append("#\(ci) \(p.uid)@\(p.x),\(p.y)r\(p.rot): \(P) ≠ \(p)") }
            }
        }
        #expect(n > 100 && fails.isEmpty, "\(fails.count) 불일치(\(n)건): \(fails.prefix(3))")
    }

    @Test func stashPreviewsAndSuggestMatch() {
        var fails: [String] = []
        for (ci, c) in Self.fx.cases.enumerated() {
            let s = Self.state(c.input)
            for p in c.stashPrev {
                let P = Self.cat.previewStash(s, uid: p.uid, x: p.x, y: p.y, rot: p.rot)!
                let alt = P.alt.map { Spot(sx: $0.x, sy: $0.y, rot: P.altRot!) }
                if P.direct != p.ok0 || alt?.sx != p.alt?.sx || alt?.sy != p.alt?.sy || alt?.rot != p.alt?.rot || P.cut != p.cut || P.dropsSkill != p.dropSkill {
                    fails.append("#\(ci) 보류함 \(P) ≠ \(p)") }
            }
            for g in c.suggest {
                let r = Self.cat.routeSuggest(s, uid: g.uid, rot: g.rot)
                if r.hits.map({ [$0.x, $0.y, $0.v] }) != g.hits { fails.append("#\(ci) 추천 \(r.hits) ≠ \(g.hits)") }
            }
            for t in c.tiles {
                let T = Self.cat.tileStats(s.item(t.uid)!, in: s)
                if T.dmg != t.dmg || T.cd != t.cd || T.val != t.val || T.hasCd != t.hasCd { fails.append("#\(ci) 타일 \(t.uid) \(T) ≠ \(t)") }
            }
        }
        #expect(fails.isEmpty, "\(fails.count) 불일치: \(fails.prefix(4))")
    }

    @Test func editOpsMatch() {
        var fails: [String] = [], n = 0
        func key(_ b: BagItem, _ inBag: Bool) -> String {
            "\(b.id)#\(b.uid)★\(b.tier) r\(b.rot) " + (inBag ? "\(b.x),\(b.y)" : "s\(b.sx ?? -1),\(b.sy ?? -1)") + " \(b.opt.map { "\($0.k)\($0.v)" } ?? "-") t\(b.t) p\(b.pin ?? -1)"
        }
        for (ci, c) in Self.fx.cases.enumerated() {
            var E = BagEditor(catalog: Self.cat, state: Self.state(c.input))
            for (k, o) in c.ops.enumerated() {
                switch o.op {
                case "rotate": E.apply(.rotate(uid: o.uid!))
                case "quickEquip": E.apply(.quickEquip(uid: o.uid!))
                case "discard": E.apply(.discard(uid: o.uid!))
                case "merge": E.apply(.merge(src: o.src!, dst: o.dst!, boost: o.boost!, roll: o.roll!))
                case "undo": E.apply(.undo)
                case "autoPack": E.apply(.autoPack)
                case "toBag": E.apply(.move(uid: o.uid!, to: .bag(x: o.x!, y: o.y!, rot: o.rot!)))
                case "toStash": E.apply(.move(uid: o.uid!, to: .stash(x: o.x!, y: o.y!, rot: o.rot!)))
                default: Issue.record("모르는 행동 \(o.op)")
                }
                n += 1
                let s = E.state, w = o.after
                let mine = s.bag.map { key($0, true) } + ["|"] + s.stash.map { key($0, false) }
                let web = w.bag.map { key($0, true) } + ["|"] + w.stash.map { key($0, false) }
                if mine != web || s.tokens != w.tokens || s.selUid != w.sel || E.undoStack.count != w.undo || s.newUids != Set(w.isNew) {
                    fails.append("#\(ci).\(k) \(o.op): \(mine) tok \(s.tokens) sel \(String(describing: s.selUid)) undo \(E.undoStack.count) new \(s.newUids) ≠ \(web) tok \(w.tokens) sel \(String(describing: w.sel)) undo \(w.undo) new \(w.isNew)")
                    break
                }
            }
        }
        #expect(n > 300 && fails.isEmpty, "\(fails.count) 불일치(\(n)건): \(fails.prefix(3))")
    }
}

/// 편집기 단위 검사(웹 규칙을 손으로 짠 상황으로)
@Suite struct BagEditorUnitTests {
    static let cat = BagEditorParityTests.cat

    @Test func mergeInheritsAndCapsOption() {
        let a = BagItem(id: "punch", uid: 1, tier: 2, opt: ItemOption(k: "crit", v: 0.30))
        var b = BagItem(id: "punch", uid: 2, tier: 2, opt: ItemOption(k: "crit", v: 0.2)); b.sx = 0; b.sy = 0
        var E = BagEditor(catalog: Self.cat, state: BagState(bag: [a], stash: [b], tokens: 5))
        let r = E.apply(.merge(src: 2, dst: 1, boost: true, roll: 0.0))
        #expect(r.merged == true && E.state.bag[0].tier == 3 && E.state.stash.isEmpty)
        #expect(E.state.bag[0].opt == ItemOption(k: "crit", v: 0.35))   // 0.30 + 0.1 → 상한 0.35
        #expect(E.state.tokens == 2)                                      // 부스트 3개
        #expect(E.mergeChance(dst: 1, boost: true) == min(0.95, Self.cat.mergeChance(tier: 3) + 0.15))
    }

    @Test func mergeFailureRefundsToken() {
        var E = BagEditor(catalog: Self.cat, state: BagState(bag: [BagItem(id: "kick", uid: 1), BagItem(id: "kick", uid: 2, x: 2)], tokens: 0))
        let r = E.apply(.merge(src: 2, dst: 1, boost: true, roll: 0.99))
        #expect(r.merged == false && E.state.tokens == 1 && E.state.bag.map(\.uid) == [1] && E.state.bag[0].tier == 1)
        E.apply(.undo)
        #expect(E.state.bag.count == 2 && E.state.tokens == 0)
    }

    @Test func discardRefundsTokenValueAndUndoCaps() {
        var E = BagEditor(catalog: Self.cat, state: BagState(bag: [BagItem(id: "throw", uid: 1, tier: 2)]))
        E.apply(.discard(uid: 1))
        #expect(E.state.tokens == 10 && E.state.bag.isEmpty)   // 5칸 × ★2
        for _ in 0..<30 { E.apply(.autoPack) }
        #expect(E.undoStack.count == BagEditor.undoMax)
    }

    @Test func rotateNudgesToFit() {
        // 가로 3칸 다리걸기를 아래쪽에서 돌리면 세로 3칸 — 넘치면 위로 한 칸 민다
        var E = BagEditor(catalog: Self.cat, state: BagState(bag: [BagItem(id: "sweep", uid: 1, x: 3, y: 2)]))
        E.apply(.rotate(uid: 1))
        let b = E.state.bag[0]
        #expect(b.rot == 1 && Self.cat.rules.canPlace(b, x: b.x, y: b.y, rot: b.rot, in: E.state.bag) && b.y == 1)
    }

    @Test func lockedEditorRefuses() {
        var E = BagEditor(catalog: Self.cat, state: BagState(bag: [BagItem(id: "punch", uid: 1)]))
        E.canEdit = false
        let r = E.apply(.discard(uid: 1))
        #expect(!r.changed && r.message == BagEditor.lockNote && E.state.bag.count == 1)
    }

    @Test func jsFormatMatchesJS() {
        #expect(JSFormat.fixed(0.25, 1) == "0.3" && JSFormat.fixed(2.35, 1) == "2.4" && JSFormat.fixed(1.05, 1) == "1.1")   // 1.05 는 2진수로 1.0500000000000000444
        #expect(JSFormat.round(-0.5) == 0 && JSFormat.round(2.5) == 3)
        #expect(BagCatalog.formatDamage(123.456) == "12.3k" && BagCatalog.formatDamage(26) == "2600")
    }
}
