import Testing
import Foundation
import BBContent
import BBSim
import BBPresentation

// HUD 도트 그림 · 모델 검사:
//  · 컷인 원화(초상 · 눈매 · 주먹 · 구두 — 스킨 · 선글라스 포함)와 피해 숫자 글리프가 웹 캔버스와 픽셀 단위로 같은지(Fixtures/hud/art.json)
//  · HUDDirector 이벤트 → HITFX · 충격파 · 컷인 · 문 전환 · 기술 줄
@Suite struct HUDArtTests {
    static let fixture = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/hud/art.json")
    struct Art: Decodable {
        struct Img: Decodable { var key: String?; var skin: String?; var shades: Bool?; var style: String?; var ch: String?; var w: Int; var h: Int; var b64: String }
        var cut: [Img]; var glyph: [Img]
    }
    static func pixels(_ atlas: OverlayAtlas, _ e: OverlayAtlas.Entry) -> [UInt8] {
        atlas.withPixels { px, _ in
            var o: [UInt8] = []
            for y in 0..<e.h { let s = ((e.y + y) * OverlayAtlas.size + e.x) * 4; o += px[s..<(s + e.w * 4)] }
            return o
        }
    }
    /// 투명 픽셀의 RGB 는 무시
    static func same(_ a: [UInt8], _ b: [UInt8]) -> Int {
        var bad = 0
        for i in stride(from: 0, to: min(a.count, b.count), by: 4) {
            if a[i + 3] == 0 && b[i + 3] == 0 { continue }
            if a[i..<(i + 4)] != b[i..<(i + 4)] { bad += 1 }
        }
        return bad
    }

    @Test("컷인 원화 · 피해 숫자 글리프 = 웹 캔버스(정확 일치)") func artMatchesWeb() throws {
        let art = try HUDArt(store: try ContentStore.bundled())
        let A = try JSONDecoder().decode(Art.self, from: Data(contentsOf: Self.fixture))
        #expect(A.cut.count >= 20 && A.glyph.count >= 50)
        for c in A.cut {
            let e = try #require(art.cutArt(c.key!, skin: c.skin ?? "jw", shades: c.shades ?? false))
            let web = [UInt8](Data(base64Encoded: c.b64)!)
            #expect(e.w == c.w && e.h == c.h)
            let bad = Self.same(Self.pixels(art.atlas, e), web)
            #expect(bad == 0, "\(c.key!) \(c.skin ?? "") \(c.shades == true ? "선글라스" : ""): 다른 픽셀 \(bad)")
        }
        for g in A.glyph {
            let e = try #require(art.dGlyph(Character(g.ch!), g.style!))
            #expect(e.w == g.w && e.h == g.h)
            #expect(Self.same(Self.pixels(art.atlas, e), [UInt8](Data(base64Encoded: g.b64)!)) == 0, "\(g.style!) \(g.ch!)")
        }
    }

    static func snap() -> SimSnapshot {
        var s = SimSnapshot(); s.hp = 80; s.maxHP = 100; s.state = "fight"; s.on = true; s.time = 10
        s.actors = [(1, 100.0, true), (2, 140.0, false)].map { id, x, hero in
            var a = SimSnapshot.ActorView(id: id, def: hero ? "JW_HERO" : "JW_THUG", pose: .init(anim: hero ? "tetsu" : "hit", pose: "st0"), x: x, y: 222, flip: false,
                                          remap: 0, flash: 0, weaponSprite: nil, hidden: false, isHero: hero, isEnemy: !hero, isPassenger: false, shake: 0)
            a.hp = 40; a.maxHP = 50; a.enemyType = hero ? nil : "boss"; a.isBoss = !hero; return a
        }
        return s
    }

    @Test("타격 → 잔상 · 섬광 · 별 터짐 · 충격파(묵직한 기술) · 치명 X · 물방울") func hitEffects() throws {
        var h = HUDDirector(art: try HUDArt(store: try ContentStore.bundled()))
        let s = Self.snap()
        var hit = HitInfo(attacker: 1, target: 2, damage: 10, reaction: "hit"); hit.crit = true
        hit.attackerAnim = "tetsu"; hit.attackerIsHero = true; hit.targetAnim = "hit"; hit.at = [140, 222]; hit.big = true   // 규칙이 재는 값(M)
        h.apply([.hit(hit)], snapshot: s)
        let k = Set(h.state.hitFx.map(\.k))
        #expect(k.isSuperset(of: ["streak", "flash", "burst", "drop", "swpuff"]))   // tetsu = H · SW_T 3
        #expect(h.state.critFx.count == 1)
        #expect(h.state.shockwaves.count == 1 && h.state.smear != nil)
        // 0.07초 안 같은 자리 · 같은 단계 이하는 하나만
        h.apply([.hit(hit)], snapshot: s)
        #expect(h.state.shockwaves.count == 1)
        for _ in 0..<60 { h.advance(dt: 1.0 / 60, snapshot: s) }
        #expect(h.state.hitFx.isEmpty && h.state.critFx.isEmpty)
    }

    @Test("컷인 · 두목 분노 막대 · 문 전환 · 기술 줄 · 바닥 충격") func flowEffects() throws {
        let art = try HUDArt(store: try ContentStore.bundled())
        var h = HUDDirector(art: art)
        var s = Self.snap()
        h.apply([.command(name: "막차 러시", tag: "sp"), .cutIn(kind: "spc", actor: 1, seconds: 1.05)], snapshot: s)
        s.cutKind = "spc"; s.cutProgress = 0.5
        h.advance(dt: 1.0 / 60, snapshot: s)
        #expect(h.state.cut?.k == "spc" && h.state.cut?.kind == "fist" && abs((h.state.cut?.t ?? 0) - 0.525) < 1e-9)
        #expect(h.state.cmdLog.first?.sp == true)
        s.cutKind = nil; h.advance(dt: 1.0 / 60, snapshot: s)
        #expect(h.state.cut == nil)
        s.car = 1; h.advance(dt: 1.0 / 60, snapshot: s)
        #expect(h.state.wipe?.label == "→ 2호차")
        h.apply([.groundImpact(x: 100, y: 222, power: 1.6), .bossRage(actor: 2)], snapshot: s)
        #expect(Set(h.state.hitFx.map(\.k)).isSuperset(of: ["gdust", "debris", "crack"]))
        let F = h.frame(s, view: StageView(visibleWidth: 360, cameraX: 0), shake: 0)
        #expect(F.boss?.t == "boss" && F.boss?.raged == true)
        #expect(F.stops.count == art.stages[0].stops.count && F.timeBar != nil)
        // 그리기 목록이 나온다(오버레이 크기 = VW·3 × H·3)
        let L = HUDOverlay.build(h.state, F, art: art)
        #expect(L.width == 1080 && L.height == 810 && L.vertexCount > 100)
    }
}
