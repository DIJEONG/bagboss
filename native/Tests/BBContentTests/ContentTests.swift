import Testing
import Foundation
@testable import BBContent

@Suite struct ContentTests {
    let store: ContentStore
    let game: GameContent
    init() throws { store = try ContentStore.bundled(); game = try GameContent(store) }

    @Test func everyNameDecodesAsJSON() throws {
        for n in store.names { _ = try store.raw(n) }
        #expect(store.names.count > 200)
    }

    @Test func tablesKeepWebKeyOrder() throws {
        #expect(game.items.keys.first == "punch")
        #expect(game.items.count == game.items.values.count)
        #expect(game.enemies.count == game.enemies.values.count)
    }

    @Test func coreTableSizes() {
        #expect(game.items.count == 40)
        #expect(game.enemies.count == 40)
        #expect(game.stages.count == 5)
        #expect(game.kits.count == 6)
        #expect(game.links.count == 14)
        #expect(game.towerFloors.count == 21 && game.towerFloors[0] == nil)
        #expect(game.mergeChance.count == 5)
    }

    // 참조 무결성: 데이터끼리 가리키는 id 가 실제로 있는지 — 웹 데이터 버그를 이식 전에 잡는다
    @Test func stageWavesReferToKnownEnemies() {
        for s in game.stages {
            for car in s.line {
                for w in car.waves { for e in w { #expect(game.enemies[e] != nil, "\(s.key) car\(car.car): \(e)") } }
                for e in car.fight ?? [] { #expect(game.enemies[e] != nil, "\(s.key) fight: \(e)") }
            }
            for e in s.reinf { #expect(game.enemies[e] != nil, "\(s.key) reinf: \(e)") }
        }
    }

    @Test func towerFloorsReferToKnownEnemies() {
        for case let f? in game.towerFloors { for e in f.w ?? [] { #expect(game.enemies[e] != nil, "\(f.name): \(e)") } }
    }

    @Test func kitsAndRecipesReferToKnownItems() {
        for k in game.kits { for s in k.bag { #expect(game.items[s.id] != nil, "kit \(k.id): \(s.id)") } }
        for r in game.comboBook { for id in r.route { #expect(game.items[id] != nil, "recipe \(r.id): \(id)") } }
        for (id, _) in game.comboRoles.ordered { #expect(game.items[id] != nil, "role: \(id)") }
    }

    @Test func lambdasAreResolvable() {
        for l in game.links { #expect(store.lambdaSource(l.a) != nil && store.lambdaSource(l.b) != nil, "\(l.id)") }
        for m in game.towerMods { #expect(store.lambdaSource(m.ap) != nil, "\(m.name)") }
    }
}

@Suite struct AtlasTests {
    let meta: AtlasMeta
    init() throws { meta = try AtlasMeta.bundled() }

    @Test func pixelFilesMatchMeta() throws {
        let a = try meta.loadAtlasA(), n = try meta.loadAtlasN(), p = try meta.loadPalette()
        #expect((a.width, a.height) == (meta.atlas.width, meta.atlas.height))
        #expect(n.bytes.count == a.bytes.count)
        #expect(p.height == 240 && p.width == 6)
    }

    @Test func spritesInsideAtlasAndNonOverlappingRows() {
        #expect(meta.sprites.count > 3000)
        for (k, s) in meta.sprites {
            #expect(s.x >= 0 && s.y >= 0 && s.x + s.w <= meta.atlas.width && s.y + s.h <= meta.atlas.height, "\(k)")
        }
        #expect(meta.materials["INK"] == 1)
    }

    @Test func atlasAndContentComeFromSameSource() throws {
        #expect(try ContentStore.bundled().sourceSha16 == meta.sourceSha16)
    }
}

/// 아틀라스는 색이 아니라 데이터다. 노멀 아틀라스의 알파(rel)가 0인 픽셀도 RGB 가 살아 있어야 한다.
/// (iOS 이미지 디코더는 이런 픽셀의 RGB 를 지운다 — 그래서 PNG 대신 raw DEFLATE 로 굽는다)
@Suite struct AtlasDecodeTests {
    @Test func normalAtlasKeepsRGBWhereAlphaIsZero() throws {
        let n = try AtlasMeta.bundled().loadAtlasN()
        let p = n.pixel(1346, 12)                       // node 로 찾은 픽셀: (1346, 12) = [128,166,128,0]
        #expect([p.0, p.1, p.2, p.3] == [128, 166, 128, 0])
    }
}
