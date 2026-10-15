import Testing
import Foundation
@testable import BBRender
@testable import BBPresentation
import BBContent
import BBSim
import BBAnim

/// 모드 HUD 대조(N5 모드 HUD): tools/js/extract/hud.mjs 의 모드 순간(타워 · 보너스 · 무도장 · 거리 연출 · 복도 · 쇼 칸 전구 · 만화 페이지)을
/// 같은 입력(HUDState · HUDFrame.modes)으로 그려 웹 #ui 픽셀과 비교한다. 비교 · 덤프는 HUDParityTests 와 같다(BB_DUMP=1 · BB_HUD_PROBE).
@Suite(.serialized) struct ModeHUDParityTests {
    /// 순간 → (정확, ±32, 3×3 칸)
    // 측정(2026-10-09): 차이는 글자 가장자리(갈무리 AA 끔 · Anton) 뿐 — 자리 · 크기 · 색은 같다
    //  tower_over 95.0/96.1/92.5 · tower_daily 96.6/97.0/96.8 · bonus_go 95.4/97.7/95.7 · bonus_owner 91.9/95.5/94.3 · dojo_hit 93.4/93.8/92.7
    //  cine 98.8/99.3/99.1 · corridor 99.96/100/100 · show_lamps 94.9/100/100 · story_p1~end 95.8~97.3 / 98.4~99.6 / 97.7~99.5
    static let moments: [String: (exact: Double, near: Double, block: Double)] = [
        "tower_over": (0.94, 0.95, 0.915), "tower_daily": (0.955, 0.96, 0.955),
        "bonus_go": (0.945, 0.965, 0.945), "bonus_owner": (0.91, 0.945, 0.935),
        "dojo_hit": (0.925, 0.93, 0.915), "cine": (0.98, 0.985, 0.98), "corridor": (0.995, 0.995, 0.995), "show_lamps": (0.94, 0.995, 0.995),
        "story_p1": (0.96, 0.985, 0.985), "story_p2": (0.95, 0.98, 0.975), "story_p3": (0.95, 0.975, 0.97), "story_end": (0.95, 0.98, 0.98),
    ]

    @Test(arguments: moments.keys.sorted())
    func modeMatchesWeb(name: String) throws {
        let fx = HUDParityTests.fixtures
        let url = fx.appending(path: "\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { Issue.record("픽스처 없음: \(name) — node tools/js/extract/hud.mjs \(name)"); return }
        let cap = try HUDCapture(json: Data(contentsOf: url))
        let web = [UInt8](try (Data(contentsOf: fx.appending(path: "\(name).rgba.deflate")) as NSData).decompressed(using: .zlib) as Data)
        let (r, q, art) = try HUDParityTests.setup()
        let list = HUDOverlay.build(cap.state, cap.frame, art: art)
        let mine = try r.render(list, atlas: art.atlas, queue: q)
        #expect(mine.count == web.count)
        guard mine.count == web.count else { return }
        let s = HUDParityTests.compare(mine, web, w: cap.width, h: cap.height)
        print("[HUD \(name)] \(s) · 정점 \(list.vertexCount) · 묶음 \(list.batches.count)")
        if ProcessInfo.processInfo.environment["BB_DUMP"] == "1" {
            HUDParityTests.dump(mine, w: cap.width, h: cap.height, to: HUDParityTests.dumpDir.appending(path: "native_\(name).png"))
            HUDParityTests.dump(HUDParityTests.diff(mine, web), w: cap.width, h: cap.height, to: HUDParityTests.dumpDir.appending(path: "diff_\(name).png"))
        }
        if let probe = ProcessInfo.processInfo.environment["BB_HUD_PROBE"], probe == name {
            var n = 0
            for i in stride(from: 0, to: mine.count, by: 4) {
                let x = HUDParityTests.pm(mine, i), y = HUDParityTests.pm(web, i)
                if max(abs(x.0 - y.0), abs(x.1 - y.1), abs(x.2 - y.2), abs(x.3 - y.3)) > 32 && n < 60 {
                    n += 1; print("  (\((i / 4) % cap.width),\((i / 4) / cap.width)) 나 \(Array(mine[i..<i + 4])) 웹 \(Array(web[i..<i + 4]))")
                }
            }
        }
        let want = Self.moments[name]!
        #expect(s.exact >= want.exact, "정확 \(s.exact)")
        #expect(s.near >= want.near, "±32 \(s.near)")
        #expect(s.block >= want.block, "3×3 \(s.block)")
    }

    /// 만화 페이지 원화(웹 storyArt p1~p3 · pShade 까지) — 픽셀 완전 일치
    @Test func storyArtMatchesWeb() throws {
        struct Raw: Decodable { struct E: Decodable { var key: String, w: Int, h: Int, b64: String }; var story: [E] }
        let url = HUDParityTests.fixtures.appending(path: "story_art.json")
        guard FileManager.default.fileExists(atPath: url.path) else { Issue.record("픽스처 없음: story_art.json"); return }
        let raw = try JSONDecoder().decode(Raw.self, from: Data(contentsOf: url))
        let (_, _, art) = try HUDParityTests.setup()
        #expect(raw.story.count == 3)
        for e in raw.story {
            let web = [UInt8](Data(base64Encoded: e.b64)!)
            let ent = try #require(art.storyArt(e.key))
            #expect(ent.w == e.w && ent.h == e.h)
            var bad = 0
            art.atlas.withPixels { px, _ in
                for y in 0..<e.h { for x in 0..<e.w {
                    let o = ((ent.y + y) * OverlayAtlas.size + ent.x + x) * 4, w = (y * e.w + x) * 4
                    if web[w + 3] == 0 && px[o + 3] == 0 { continue }
                    if (0..<4).contains(where: { px[o + $0] != web[w + $0] }) { bad += 1 }
                } }
            }
            print("[story \(e.key)] \(e.w)×\(e.h) 다른 픽셀 \(bad)")
            #expect(bad == 0, "\(e.key) 다른 픽셀 \(bad)")
        }
    }

    /// 모델: 스냅숏 → HUDFrame.modes(타워 · 보너스 · 거리 연출 · 복도 · charOX 밀기)
    @Test func modesFromSnapshot() {
        var s = SimSnapshot(); s.on = true
        var hero = SimSnapshot.ActorView(id: 1, def: "hero", pose: .init(anim: "idle", pose: "st1"), x: 200, y: 222, flip: false, remap: 0, flash: 0, weaponSprite: nil,
                                         hidden: false, isHero: true, isEnemy: false, isPassenger: false, shake: 0)
        hero.hp = 100; hero.maxHP = 100
        s.actors = [hero]
        var T = TowerView(); T.floor = 5; T.weight = 9; T.limit = 7; T.phase = "hold"; T.seconds = 75.7; T.best = 3; T.ot = 1
        s.tower = T
        var D = HUDDirector(); D.advance(dt: 1 / 60, snapshot: s)
        let F = D.frame(s, view: StageView(), shake: 0)
        let M = F.modes?.tower
        #expect(M?.floor == 5 && M?.secs == 75 && M?.best == 5 && M?.hold == true && M?.weight == 9 && M?.limit == 7)
        s.tower = nil
        var C = CineView(); C.cam = 140.4; C.flash = 0.5; C.fade = 0.1
        s.cine = C; s.scene = "brawl"
        #expect(s.hudCharOX == -140)
        let F2 = D.frame(s, view: StageView(), shake: 0)
        #expect(F2.modes?.cine == HUDModes.Cine(flash: 0.5, fade: 0.1))
        #expect(F2.heroX == 60)   // 인물 기준 자리는 charOX 만큼 밀린다
        s.cine = nil; s.scene = "subway"; var P = PrologueView(); P.progress = 0.3; s.prologue = P
        #expect(D.frame(s, view: StageView(), shake: 0).modes?.corridor == 0.3)
        s.prologue = nil
        #expect(D.frame(s, view: StageView(), shake: 0).modes == nil)
    }
}
