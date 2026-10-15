import Foundation
import Testing
import BBCore
import BBContent
import BBSim
@testable import BBPresentation
@testable import BBRender

// N4 연출 감독(순수 부분) 검사: 좌표 변환 · HUD 수명 · 소리 매핑표 · 입력 매핑 · 고정 스텝 구동 · G-버퍼 순서 · 실제 판 연기 연결.

@Suite struct StageGeometryTests {
    @Test("세로 크롭: 보이는 왼쪽 끝 = 0, 오른쪽 끝 = 1") func crop() {
        let v = StageView(visibleWidth: 360, cameraX: 60)
        #expect(v.toView([60, 0]) == [0, 0])
        #expect(v.toView([420, 270]) == [1, 1])
        #expect(v.toView([240, 135]) == [0.5, 0.5])
    }
    @Test("줌 펀치: 중심은 제자리 · 바깥은 밀려난다 · 왕복") func zoom() {
        var v = StageView(visibleWidth: 360, cameraX: 60); v.zoom = 1.1; v.zoomCenter = [0.5, 0.5]
        let c = v.toView([240, 135]); #expect(abs(c.x - 0.5) < 1e-12 && abs(c.y - 0.5) < 1e-12)
        let p = v.toView([300, 200])
        let q = v.toScene(p); #expect(abs(q.x - 300) < 1e-9 && abs(q.y - 200) < 1e-9)
        let edge = StageView(visibleWidth: 360, cameraX: 60).toView([400, 250])
        #expect(v.toView([400, 250]).x > edge.x)   // 확대하면 중심에서 먼 점이 더 바깥으로
        #expect(v.toView([400, 250]).y > edge.y)
    }
    @Test("포인트 변환") func points() {
        let v = StageView(visibleWidth: 360, cameraX: 0)
        #expect(v.toView([180, 135], size: [390, 292.5]) == [195, 146.25])
        #expect(v.pointsPerPixel(viewWidth: 390) == 390.0 / 360)
    }
}

@Suite struct HUDModelTests {
    func snap(_ actors: [(Int, Double, Bool)] = [(1, 100, true), (2, 160, false)]) -> SimSnapshot {
        var s = SimSnapshot(); s.hp = 100; s.maxHP = 120; s.state = "fight"; s.on = true
        s.actors = actors.map { id, x, hero in
            var a = SimSnapshot.ActorView(id: id, def: hero ? "JW_HERO" : "JW_THUG", pose: .init(anim: "idle", pose: "st0"), x: x, y: 225, flip: false,
                                          remap: 0, flash: 0, weaponSprite: nil, hidden: false, isHero: hero, isEnemy: !hero, isPassenger: false, shake: 0)
            a.hp = 50; a.maxHP = 50; return a
        }
        return s
    }

    @Test("피해 숫자: 수명(보통 1.05 · 치명 1.35) · 같은 대상 연속은 위로 쌓인다") func damagePops() {
        var h = HUDDirector(); let s = snap()
        h.apply([.damagePop(target: 2, value: 120, style: "hit", label: nil)], snapshot: s)
        h.advance(dt: 0.1, snapshot: s)
        h.apply([.damagePop(target: 2, value: 340, style: "crit", label: "CRITICAL")], snapshot: s)
        #expect(h.state.pops.count == 2)
        #expect(h.state.pops[1].stack == 1)
        #expect(h.state.pops[0].x == 160 && h.state.pops[0].y == 225 - 58)
        for _ in 0..<10 { h.advance(dt: 0.1, snapshot: s) }   // 1.1초 · 보통은 1.05 넘어 사라짐, 치명은 1.0초
        #expect(h.state.pops.count == 1 && h.state.pops[0].style == "crit")
        for _ in 0..<4 { h.advance(dt: 0.1, snapshot: s) }
        #expect(h.state.pops.isEmpty)
    }
    @Test("피해 숫자 모양: 떠오름 · 사라짐") func popShape() {
        var p = HUDState.DamagePop(id: 1, x: 0, y: 0, value: 9, style: "hit", label: nil, stack: 0, life: 1.05, vx: 0)
        #expect(p.alpha == 1 && p.rise == 0)
        p.age = 0.5; #expect(p.rise < -9 && p.alpha == 1)
        p.age = 1.0; #expect(p.alpha < 0.2 && p.rise < -17)
        #expect(HUDState.DamagePop(id: 2, x: 0, y: 0, value: 5, style: "heal", label: nil, stack: 0, life: 1, vx: 0).text == "+5")
    }
    @Test("만화 글자: 0.5초 안 두 번째는 버린다 · 앞 글자는 접힌다") func comic() {
        var h = HUDDirector(); let s = snap()
        h.apply([.comicWord(word: "WHAM!", x: 100, y: 100)], snapshot: s)
        h.apply([.comicWord(word: "KRAK!", x: 100, y: 100)], snapshot: s)
        #expect(h.state.words.count == 1)
        h.advance(dt: 0.55, snapshot: s)
        h.apply([.comicWord(word: "SLAM!", x: 100, y: 100)], snapshot: s)
        #expect(h.state.words.last?.word == "SLAM!")
        h.advance(dt: 0.1, snapshot: s)
        #expect(h.state.words.count == 1 && h.state.words[0].word == "SLAM!")   // WHAM 은 0.6 수명 — 접혀서 사라짐
    }
    @Test("M: 강제 만화 글자(comicReset) · 규칙이 잰 HITFX(fxDetail) · 스냅숏 값 → HUDFrame") func realValues() {
        var h = HUDDirector(); var s = snap()
        h.apply([.comicWord(word: "WHAM!", x: 100, y: 100), .comicReset, .comicWord(word: "받아치기!", x: 100, y: 100)], snapshot: s)
        #expect(h.state.words.map(\.word) == ["WHAM!", "받아치기!"])   // 웹 comicT=0 — 간격 무시
        h.apply([.fxDetail(FxDetail(kind: "axv", x: 120, y: 100, dir: 1, y1: 196)), .fxDetail(FxDetail(kind: "cystar", x: 90, y: 150, s: 1.25)),
                 .fxDetail(FxDetail(kind: "swirl", x: 200, y: 190, n: 99, big: true))], snapshot: s)
        let ax = h.state.hitFx.first { $0.k == "axv" }, st = h.state.hitFx.first { $0.k == "cystar" }, sw = h.state.hitFx.first { $0.k == "swirl" }
        #expect(ax?.y0 == 100 && ax?.y1 == 196 && ax?.x == 120 && st?.s == 1.25 && sw?.big == true && sw?.ph == 99 && sw?.life == 0.5)
        s.manualT = 1.2; s.fade = 0.4; s.lagH = 80; s.bagSlowT = 0.3; s.inCombat = true; s.justW = 0.2
        let F = h.frame(s, view: StageView(visibleWidth: 360, cameraX: 0), shake: 0)
        #expect(F.manual && F.fade == 0.4 && F.lagH == 80 && F.bagSlow == true && F.justW == 0.2)
    }
    @Test("말풍선: 혼잣말은 5초에 한 번 · 외침은 언제나 · 대사 열쇠는 문장으로") func bubbles() {
        var h = HUDDirector(); let s = snap()
        h.apply([.speech(actor: 1, text: "quip:clear", kind: "speech")], snapshot: s)
        #expect(h.state.bubbles.count == 1 && !h.state.bubbles[0].text.hasPrefix("quip:"))
        h.apply([.speech(actor: 1, text: "또?", kind: "think")], snapshot: s)
        #expect(h.state.bubbles.count == 1)
        h.apply([.speech(actor: 2, text: "이놈!", kind: "shout")], snapshot: s)
        #expect(h.state.bubbles.count == 2)
        for _ in 0..<25 { h.advance(dt: 0.1, snapshot: s) }
        #expect(h.state.bubbles.isEmpty)
    }
    @Test("안내 · 상태 글자 · 체력 지연 막대") func noticeAndHP() {
        var h = HUDDirector(); var s = snap()
        h.apply([.notice(title: "곧 도착", body: "", seconds: 1.0), .statusFlash(text: "CLEAR", seconds: 0.5)], snapshot: s)
        h.advance(dt: 0.6, snapshot: s)
        #expect(h.state.notice != nil && h.state.flash == nil)
        h.advance(dt: 0.5, snapshot: s)
        #expect(h.state.notice == nil)
        s.hp = 60; s.lagH = 92; h.advance(dt: 0.1, snapshot: s)
        #expect(h.state.hp == 60 && h.state.lagHP == 92)   // 지연 체력은 규칙 값(웹 GS.lagH)을 그대로
        s.lagH = 60; h.advance(dt: 0.1, snapshot: s)
        #expect(h.state.lagHP == 60)
    }
    @Test("연타: comboStep 으로 켜지고 2.4초 뒤 꺼진다 · 연타 합계") func combo() {
        var h = HUDDirector(); let s = snap()
        h.apply([.comboStep(count: 4), .comboTotal(hits: 4, damage: 900)], snapshot: s)
        #expect(h.state.combo == 4)
        #expect(h.state.pops.contains { $0.style == "total" && $0.label == "4 HIT TOTAL" && $0.value == 900 })
        h.advance(dt: 2.5, snapshot: s)
        #expect(h.state.combo == 0)
    }
}

@Suite struct SoundMappingTests {
    func hit(tier: Int, kind: String?, dead: Bool = false, reaction: String = "hit", heroHit: Bool = false) -> SimEvent {
        var h = HitInfo(attacker: 1, target: 2, damage: 10, reaction: reaction)
        h.soundTier = tier; h.soundKind = kind; h.dead = dead; h.heroWasHit = heroHit; h.crit = tier == 2
        return .hit(h)
    }
    @Test("타격음: 3단 등급 · 연타 수 · 큰 반응이면 덕킹 · 망치는 hitK") func hits() {
        var d = SoundDirector(heavyReactions: ["fall"])
        #expect(d.cues(for: [.comboStep(count: 3), hit(tier: 1, kind: "punch")], now: 0) == [.hit3(tier: 1, crit: false, combo: 3, air: false, big: false)])
        #expect(d.cues(for: [hit(tier: 2, kind: "kick", dead: true)], now: 0) == [.hit3(tier: 2, crit: true, combo: 3, air: false, big: true)])
        #expect(d.cues(for: [hit(tier: 2, kind: "kick", reaction: "fall")], now: 0).first == .hit3(tier: 2, crit: true, combo: 3, air: false, big: true))
        #expect(d.cues(for: [hit(tier: 0, kind: "hammer")], now: 0) == [.hitK(kind: "hammer", crit: false, combo: 3)])
        #expect(d.cues(for: [hit(tier: 0, kind: nil)], now: 0).isEmpty)   // 적끼리 · 주인공이 아닌 타격은 소리 없음
        #expect(d.cues(for: [hit(tier: 1, kind: "punch", heroHit: true)], now: 0).isEmpty)
    }
    @Test("녹음 타격음: hitDetail 을 켜면 hit3 에 때린 동작 · 카운터를 싣는다(끄면 웹 그대로)") func hitDetail() {
        var d = SoundDirector(heavyReactions: [])
        var h = HitInfo(attacker: 1, target: 2, damage: 10, reaction: "hit")
        h.soundTier = 2; h.soundKind = "heavy"; h.attackerAnim = "nv_kneelift"; h.counter = true
        #expect(d.cues(for: [.hit(h)], now: 0) == [.hit3(tier: 2, crit: false, combo: 0, air: false, big: false)])
        d.hitDetail = true
        #expect(d.cues(for: [.hit(h)], now: 0) == [.hit3(tier: 2, crit: false, combo: 0, air: false, big: false, detail: HitDetail(move: "nv_kneelift", counter: true))])
    }
    @Test("피격 · 저스트 · 바닥 충격 문턱 · 프라이팬") func others() {
        var d = SoundDirector()
        #expect(d.cues(for: [.heroHurt(weight: .heavy), .heroHurt(weight: .light)], now: 0) == [.hurt(heavy: true), .hurt(heavy: false)])
        #expect(d.cues(for: [.justCounter(target: 2)], now: 0) == [.just])
        #expect(d.cues(for: [.groundImpact(x: 0, y: 0, power: 0.5), .groundImpact(x: 0, y: 0, power: 1.2)], now: 0) == [.floor(1.2)])
        #expect(d.cues(for: [.blocked(target: 2, kind: .pan), .blocked(target: 2, kind: .shield)], now: 0) == [.panClang])
    }
    @Test("만화 글자 소리: KA-BOOM → boom · 0.5초 간격") func comic() {
        var d = SoundDirector()
        #expect(d.cues(for: [.comicWord(word: "KA-BOOM!", x: 0, y: 0)], now: 1) == [.boom])
        #expect(d.cues(for: [.comicWord(word: "WHOOSH!", x: 0, y: 0)], now: 1.2).isEmpty)
        #expect(d.cues(for: [.comicWord(word: "WHOOSH!", x: 0, y: 0)], now: 1.6) == [.whoosh])
    }
    @Test("단독 소리 id 표") func sfxTable() {
        let want: [String: SoundCue] = ["swing": .swing, "throw": .swing, "thud": .thud, "coin": .coin, "door": .door(open: true), "gong": .gong, "brass": .brass, "clear": .clear, "dodge": .dodge, "ready": .ready]
        for (k, v) in want { #expect(SoundDirector.cue(sfx: k) == v, "\(k)") }
        #expect(SoundDirector.cue(sfx: "???") == .other("???"))
    }
    @Test("열차 루프 · 배경음 긴장도") func trainMusic() {
        var s = SimSnapshot(); s.on = true; s.state = "fight"; s.trainSpeed = 300; s.trainPhase = "cruise"; s.hp = 20; s.maxHP = 100
        let t = SoundDirector.train(s, flickeryCar: true, outdoors: false, now: 5)
        #expect(t.speed == 300 && t.phase == "cruise" && t.flickeryCar && !t.atStop && t.time == 5)
        #expect(SoundDirector.music(s) == MusicState(enabled: true, intensity: 1))
        var foe = SimSnapshot.ActorView(id: 3, def: "JW_THUG", pose: .init(anim: "idle", pose: "st0"), x: 0, y: 0, flip: false, remap: 0, flash: 0, weaponSprite: nil,
                                        hidden: false, isHero: false, isEnemy: true, isPassenger: false, shake: 0)
        foe.hp = 10; s.actors = [foe]
        #expect(SoundDirector.music(s).intensity == 2.5)   // 체력 30% 아래 + 적
        s.hp = 80; #expect(SoundDirector.music(s).intensity == 2)
        s.actors[0].isBoss = true; #expect(SoundDirector.music(s).intensity == 3)
        s.state = "over"; #expect(!SoundDirector.music(s).enabled)
    }
}

@Suite struct InputMappingTests {
    @Test("무대 탭: 왼쪽 반 · 오른쪽 반 · 아래 1/3 숙이기 · 탭 창") func sides() {
        #expect(InputMapper.intent(at: [0.2, 0.3], simTime: 1) == .tap(side: -1, at: 1))
        #expect(InputMapper.intent(at: [0.8, 0.6], simTime: 1) == .tap(side: 1, at: 1))
        #expect(InputMapper.intent(at: [0.5, 0.8], simTime: 2) == .duck(at: 2))
        #expect(InputMapper.intent(at: [0.1, 0.1], simTime: 3, tapWindowOpen: true) == .tapWindow(at: 3))
    }
    @Test("터치 시각 → 시뮬레이션 시계(±0.1초로 자른다)") func time() {
        #expect(abs(InputMapper.simTime(touch: 10.008, frameMedia: 10, frameSimClock: 5) - 5.008) < 1e-9)
        #expect(abs(InputMapper.simTime(touch: 9.5, frameMedia: 10, frameSimClock: 5) - 4.9) < 1e-12)
        #expect(abs(InputMapper.simTime(touch: 11, frameMedia: 10, frameSimClock: 5) - 5.1) < 1e-12)
    }
    @Test("고정 스텝: 60Hz 는 1틱 · 120Hz 는 번갈아 · 멈칫은 상한") func loop() {
        var c = GameLoopClock(), total = 0
        _ = c.begin(media: 0)
        for k in 1...60 { total += c.begin(media: Double(k) / 60).ticks }
        #expect(abs(total - 60) <= 1)
        var d = GameLoopClock(); _ = d.begin(media: 0); var t2 = 0
        for k in 1...120 { t2 += d.begin(media: Double(k) / 120).ticks }
        #expect(abs(t2 - 60) <= 1)
        var e = GameLoopClock(); _ = e.begin(media: 0)
        #expect(e.begin(media: 0.5).ticks == e.maxTicksPerFrame)
    }
}

@Suite struct StageDirectorTests {
    static let data: SimData = try! SimData.bundled()
    static let content: SceneContent = try! SceneContent.bundled()

    @Test("G-버퍼 순서: 배경 → 그림자 → 인물 앞 2D → 3D → 앞 효과") func gbufferOrder() {
        var r = ConstantRandom(0.5)
        let scene = SceneComposer.compose(SceneInput(), content: Self.content, rng: &r)
        let f = StageFrame(scene: scene, shadows: [SpriteDraw(name: "shadow", x: 10, y: 200)], preMesh: [SpriteDraw(name: "dust0", x: 20, y: 210)],
                           mesh: [Float](repeating: 0, count: 30), front: [SpriteDraw(name: "spark0", x: 30, y: 150)], extraLights: [],
                           shake: 2, view: StageView(visibleWidth: 360, cameraX: 40), time: 3)
        let rf = RenderFrame(stage: f, atlas: Self.content.sprites)
        guard rf.gbuffer.count == 5 else { Issue.record("그리기 \(rf.gbuffer)"); return }
        if case .sprite(_, _, let sh) = rf.gbuffer[0] { #expect(!sh) } else { Issue.record("배경") }
        if case .sprite(_, let n, let sh) = rf.gbuffer[1] { #expect(sh && n == 6) } else { Issue.record("그림자") }
        if case .sprite(_, let n, let sh) = rf.gbuffer[2] { #expect(!sh && n == 6) } else { Issue.record("먼지") }
        if case .mesh(_, let n) = rf.gbuffer[3] { #expect(n == 3) } else { Issue.record("3D") }
        if case .sprite(_, let n, _) = rf.gbuffer[4] { #expect(n == 6) } else { Issue.record("앞 효과") }
        #expect(rf.shake.x == 2 && rf.blit.cameraX == 40 && rf.blit.visibleWidth == 360)
        #expect(rf.post != nil)
    }

    @Test("실제 판 연기: 20초 — 인물 메시 · 그림자 · HUD 숫자 · 소리 이름표가 나온다") func playthrough() throws {
        let store = try ContentStore.bundled()
        let d = try StageDirector(content: Self.content, store: store, tables: Self.data.animTables, catalog: HUDCatalog(Self.data), heavyReactions: Self.data.heavyRK)
        let sim = Sim(data: Self.data, seed: 77, config: SimConfig())
        var pops = 0, cues = 0, maxMesh = 0, shadows = 0, words = 0
        for k in 0..<(20 * 60) {
            var intents: [SimIntent] = []
            if sim.state == "shop" { intents = [.shopPick(0)] } else if sim.state == "arrange" { intents = [.advance] }
            if k % 40 == 0 { intents.append(.tap(side: k % 80 == 0 ? 1 : -1, at: sim.clock)) }
            let ev = sim.step(intents)
            let s = sim.snapshot
            cues += d.apply(ev, snapshot: s, now: Double(k) / 60).count
            let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            pops = max(pops, d.hud.state.pops.count); words = max(words, d.hud.state.words.count)
            maxMesh = max(maxMesh, f.mesh.count / 10); shadows = max(shadows, f.shadows.count)
            #expect(f.scene.unported == nil)
            #expect(f.view.cameraX >= 0 && f.view.cameraX <= 120)
        }
        #expect(maxMesh > 1000)
        #expect(shadows >= 2)
        #expect(pops > 0)
        #expect(cues > 0)
        #expect(d.characters.liveRigs > 0)
        _ = words
    }

    @Test("이어 하기: 저장 값으로 노선 · 호차 · 가방 · 토큰이 돌아온다") func resume() {
        let a = Sim(data: Self.data, seed: 5, config: SimConfig())
        let s0 = a.snapshot
        var r = SimResume(); r.stageIdx = 0; r.ci = 2; r.bag = s0.bag; r.stash = []; r.tokens = 7; r.score = 1234; r.hp = 50; r.kills = 9
        let b = Sim(data: Self.data, seed: 6, config: SimConfig())
        b.resume(r)
        for _ in 0..<5 { b.step() }
        let s = b.snapshot
        #expect(s.car == 2)
        #expect(s.tokens == 7 && s.score >= 1234 && s.kills == 9)
        #expect(Set(s.bag.map(\.uid)) == Set(s0.bag.map(\.uid)))
    }
}

// U(표현 정리 — docs/07 I1 · I2 · I3 · I6 · I12): 웹 27-actors damage · dashFx · 45-hud 규칙 그대로인지
@Suite struct WebFeelRuleTests {
    func actor(_ id: Int, _ x: Double, hero: Bool) -> SimSnapshot.ActorView {
        SimSnapshot.ActorView(id: id, def: hero ? "JW_HERO" : "JW_THUG", pose: .init(anim: "idle", pose: "st0"), x: x, y: 225, flip: false,
                              remap: 0, flash: 0, weaponSprite: nil, hidden: false, isHero: hero, isEnemy: !hero, isPassenger: false, shake: 0)
    }
    func heroHit(knock: Bool = false, react: String? = nil, crit: Bool = false, dead: Bool = false) -> SimEvent {
        var h = HitInfo(attacker: 1, target: 2, damage: 10, reaction: "hit"); h.attackerIsHero = true; h.knock = knock; h.reactOpt = react
        h.crit = crit; h.dead = dead; h.dir = 1; h.at = [160, 225]; h.weight = .heavy
        return .hit(h)
    }

    @Test("I3 줌: ATK_FEEL 은 최댓값(상한 .12) · 넉백은 더하기(상한 .09) · 마지막 일격은 .12") func zoomModes() {
        var c = CameraDirector()
        func kick(_ z: Double, _ m: CameraKick.ZoomMode) -> SimEvent { var k = CameraKick(); k.zoom = z; k.zoomMode = m; return .camera(k) }
        c.apply([kick(0.055, .add(cap: 0.09)), kick(0.07, .max(cap: 0.12))])
        #expect(abs(c.zoomK - 0.07) < 1e-12)                       // 웹 돌려차기: max(.055, .07) — 예전 가산은 .09
        c.apply([kick(0.055, .add(cap: 0.09))]); #expect(abs(c.zoomK - 0.09) < 1e-12)
        c.apply([kick(0.12, .set)]); #expect(c.zoomK == 0.12)
        var e = CameraDirector(); e.apply([kick(0.02, .max(cap: 0.12)), kick(0.02, .max(cap: 0.12))])
        #expect(abs(e.zoomK - 0.02) < 1e-12)                       // 팔꿈치 연타: 0.02 그대로(예전 0.036)
    }
    @Test("흔들림: damage 는 덮어쓰기 · 그 밖은 최댓값 · 바닥 충격 1+1.6p") func shakeModes() {
        var c = CameraDirector()
        var k = CameraKick(); k.shake = 3; k.shakeSet = true; c.apply([.camera(k)]); #expect(c.shakeAmp == 3)
        c.apply([.groundImpact(x: 0, y: 0, power: 1.8)]); #expect(abs(c.shakeAmp - 3.88) < 1e-9)
        var m = CameraKick(); m.shake = 3; c.apply([.camera(m)]); #expect(abs(c.shakeAmp - 3.88) < 1e-9)
        var s = CameraKick(); s.shake = 1; s.shakeSet = true; c.apply([.camera(s)]); #expect(c.shakeAmp == 1)
    }
    @Test("I1 넉백: 별 터짐 고리 + 파편 8 + 맞은 자리 먼지 · 무게 H 만으로는 없음") func knockFx() {
        let A = [actor(1, 100, hero: true), actor(2, 160, hero: false)]
        var f = FxLayer(); f.apply([heroHit(knock: true)], actors: A, glyphs: [])
        #expect(f.rings.filter(\.burst).count == 1 && f.bits.count == 8 && f.dusts.count == 1)
        var g = FxLayer(); g.apply([heroHit()], actors: A, glyphs: [])
        #expect(g.rings.filter(\.burst).isEmpty && g.bits.isEmpty && g.dusts.isEmpty)   // 다리걸기 · 도끼 차기(H, 넉백 아님)
        var h = FxLayer(); h.apply([heroHit(crit: true, dead: true)], actors: A, glyphs: [])
        #expect(h.bits.count == 8 && h.dusts.isEmpty)                                    // 치명 마무리: 고리 · 파편만(먼지 없음)
    }
    @Test("I4 큐 먼지: 섬머솔트 이륙 둘 · 돌려차기 마무리 하나") func cueDust() {
        let A = [actor(1, 100, hero: true)]
        var f = FxLayer(); f.apply([.actionCue(actor: 1, anim: "skick", cue: "sk_jump"), .actionCue(actor: 1, anim: "round", cue: "r_hit_rt")], actors: A, glyphs: [])
        #expect(f.dusts.count == 3)
    }
    @Test("I6 피해 숫자 ±7% · 같은 씨앗이면 같은 수열") func dmgJitter() {
        var s = SimSnapshot(); s.actors = [actor(1, 100, hero: true), actor(2, 160, hero: false)]
        var a = HUDDirector(), b = HUDDirector()
        var vals: Set<Int> = []
        for _ in 0..<12 { a.apply([.damagePop(target: 2, value: 1000, style: "hit", label: nil)], snapshot: s); b.apply([.damagePop(target: 2, value: 1000, style: "hit", label: nil)], snapshot: s) }
        for p in a.state.pops { #expect(p.value >= 930 && p.value <= 1070); vals.insert(p.value) }
        #expect(vals.count > 3 && a.state.pops.map(\.value) == b.state.pops.map(\.value))
        var h = HUDDirector(); h.apply([.damagePop(target: 1, value: 5, style: "heal", label: nil)], snapshot: s)
        #expect(h.state.pops.first?.value == 5)
    }
    @Test("I2 질주 속도선: runU 를 미는 동안 0.06초마다 흰 선 둘") func dashLines() {
        var h = HUDDirector()
        var n = 0
        for k in 0..<30 {
            var s = SimSnapshot(); s.time = Double(k) / 60; s.gameTime = s.time
            var H = actor(1, 100 + Double(k) * 3, hero: true); H.pose.runU = s.gameTime + 0.09
            s.actors = [H]; h.apply([], snapshot: s)
            n = h.state.hitFx.filter { $0.k == "streak" && $0.col == "#f4efe2" }.count
        }
        #expect(n >= 12 && n <= 16)   // 29틱 ≈ 0.48초 → 7~8번 × 2
        #expect(h.state.capRound)
    }
    @Test("I12 철산고 진각은 낮은 울림") func tetsuSound() {
        #expect(SoundDirector.cue(sfx: "tetsu") == .tetsu)
    }
}
