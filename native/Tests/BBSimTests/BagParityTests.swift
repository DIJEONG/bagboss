import Testing
import Foundation
@testable import BBSim
import BBContent

/// 웹 가방 픽스처(tools/js/extract/fixtures.mjs · 200판)와 대조: 모양 · 배치 · 인접 · 세트 · 능력치 · 빈자리 · 콤보 경로
@Suite struct BagParityTests {
    struct Fixture: Decodable { let shapes: [String: [[[Int]]]]; let cases: [Case] }
    struct Case: Decodable { let input: Input; let out: Out }
    struct Input: Decodable { let bag: [BagItem]; let stash: [BagItem]; let imprints: [String: String] }
    struct Stat: Decodable { let dmg: Double; let cd: Double?; let crit: Double; let critD: Double; let set: Bool
        let gem: Int, stone: Int, pins: Int, rings: Int, metros: Int, cuffs: Int; let imp: [String: Bool] }
    struct Probe: Decodable { let uid: Int, x: Int, y: Int, rot: Int, ok: Bool }
    struct Spot: Decodable { let x: Int?, y: Int?, rot: Int?; let sx: Int?, sy: Int? }
    struct SpotFor: Decodable { let id: String; let rot: Int; let bag: Spot?; let stash: Spot? }
    struct Route: Decodable { let uids: [Int]; let key: String; let name: String }
    struct Out: Decodable { let adj: [[Int]]; let sets: [String: [Int]]; let stats: [Stat]; let probes: [Probe]; let spotFor: SpotFor; let routes: [Route] }

    static let fx: Fixture = try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf:
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/bag.json")))
    static let rules: BagRules = { let s = try! ContentStore.bundled(); return try! BagRules(try! GameContent(s), store: s) }()
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= 2e-6 * max(1, abs(b)) }

    @Test func shapesMatch() {
        for (id, rots) in Self.fx.shapes { for (r, cells) in rots.enumerated() {
            #expect(Self.rules.shape(id, rot: r).map { [$0.x, $0.y] } == cells, "\(id) rot \(r)") } }
    }

    @Test func placementAdjacencySetsStatsMatch() {
        var fails: [String] = []
        for (n, c) in Self.fx.cases.enumerated() {
            let bag = c.input.bag, R = Self.rules
            for p in c.out.probes { let b = bag.first { $0.uid == p.uid }!
                if R.canPlace(b, x: p.x, y: p.y, rot: p.rot, in: bag) != p.ok { fails.append("#\(n) canPlace \(p)") } }
            let adj = bag.indices.map { R.adjacent($0, in: bag).map { bag[$0].uid } }
            if adj != c.out.adj { fails.append("#\(n) adj \(adj) ≠ \(c.out.adj)") }
            let sets = R.sets(bag)
            if sets != c.out.sets { fails.append("#\(n) sets \(sets) ≠ \(c.out.sets)") }
            for (i, w) in c.out.stats.enumerated() {
                let s = R.stats(i, bag: bag, sets: c.out.sets, imprints: c.input.imprints)
                let ok = Self.close(s.dmg, w.dmg) && (s.cd == nil) == (w.cd == nil) && (s.cd == nil || Self.close(s.cd!, w.cd!)) && Self.close(s.crit, w.crit)
                    && Self.close(s.critD, w.critD) && s.set == w.set && s.gem == w.gem && s.stone == w.stone && s.pins == w.pins && s.rings == w.rings
                    && s.metros == w.metros && s.cuffs == w.cuffs && s.imprints == Set(w.imp.filter(\.value).keys)
                if !ok { fails.append("#\(n) stats[\(i)] \(bag[i].id): \(s) ≠ \(w)") }
            }
        }
        #expect(fails.isEmpty, "\(fails.count) 불일치: \(fails.prefix(4))")
    }

    @Test func freeSpotsMatch() {
        var fails: [String] = []
        for (n, c) in Self.fx.cases.enumerated() {
            let sf = c.out.spotFor, uid = (c.input.bag + c.input.stash).map(\.uid).max().map { $0 + 1 } ?? 1
            let item = BagItem(id: sf.id, uid: uid, rot: sf.rot)
            let b = Self.rules.findSpot(item, in: c.input.bag)
            if b?.x != sf.bag?.x || b?.y != sf.bag?.y || b?.rot != sf.bag?.rot { fails.append("#\(n) 가방 빈자리 \(String(describing: b)) ≠ \(String(describing: sf.bag))") }
            let s = Self.rules.stashSpot(item, in: c.input.stash)
            if s?.sx != sf.stash?.sx || s?.sy != sf.stash?.sy || s?.rot != sf.stash?.rot { fails.append("#\(n) 보류함 \(String(describing: s)) ≠ \(String(describing: sf.stash))") }
        }
        #expect(fails.isEmpty, "\(fails.count) 불일치: \(fails.prefix(4))")
    }

    @Test func comboRoutesMatch() {
        var fails: [String] = [], total = 0
        for (n, c) in Self.fx.cases.enumerated() {
            let r = Self.rules.routes(c.input.bag); total += r.count
            let mine = r.map { "\($0.key) \($0.name)" }, web = c.out.routes.map { "\($0.key) \($0.name)" }
            if mine != web { fails.append("#\(n) \(mine) ≠ \(web)") }
        }
        #expect(total > 100 && fails.isEmpty, "\(fails.count) 불일치(경로 \(total)): \(fails.prefix(4))")
    }
}
