import Foundation
import BBCore
import BBContent
import BBAnim
import BBSim

// 화면 프레임 하나의 '보이는 상태' 조립(웹 render() 의 그리기 목록 부분). 렌더러를 모른다 — 결과 StageFrame 은 순수 값이고,
// BBRender FrameAssembly 가 RenderFrame 으로 옮긴다. G-버퍼 순서(웹과 같음):
//   배경(장면 구성) → 그림자(곱하기) → 인물 앞 2D(먼지) → 3D 인물(깊이 검사) → 앞 효과(승객 소품 · 고리 · 파편 · 불꽃 · 글리프 숫자)

public struct StageFrame: Sendable {
    public var scene: SceneFrame
    public var shadows: [SpriteDraw]
    public var preMesh: [SpriteDraw]
    public var mesh: [Float]
    public var front: [SpriteDraw]
    /// 장면 광원 뒤에 붙는 동적 광원(불꽃 · 휴대폰) — 합쳐서 8개까지
    public var extraLights: [SceneLight]
    /// 화면 흔들림(픽셀) · 화면 출력(크롭 · 줌)
    public var shake: Double
    public var view: StageView
    /// 셰이더 시간(웹 render(time) = gameTime)
    public var time: Double
    /// 네이티브 무대 픽셀 배경(눈 승강장 — 정점당 10 float). 배경 스프라이트 바로 뒤 · 그림자 앞에 그린다(웹 장면은 늘 비어 있다)
    public var backMesh: [Float] = []
    /// 네이티브 깊이 · 조명(무도장 — docs/10 §10). nil = 웹 그대로
    public var depth: DepthFX? = nil
    /// 네이티브 인물 가독성(0 = 웹 그대로 · 1 = 켬): 배경 밝기에 맞춘 바깥 테
    public var readability = 0.0
    public init(scene: SceneFrame, shadows: [SpriteDraw], preMesh: [SpriteDraw], mesh: [Float], front: [SpriteDraw], extraLights: [SceneLight],
                shake: Double, view: StageView, time: Double) {
        self.scene = scene; self.shadows = shadows; self.preMesh = preMesh; self.mesh = mesh; self.front = front
        self.extraLights = extraLights; self.shake = shake; self.view = view; self.time = time
    }
    /// 후처리를 쓰는가(지하철 · 타워 = 느와르 후처리)
    public var post: Bool { scene.unported == nil }
}

/// 스냅숏에 없는 장면 그리기 상태(웹은 GS 안에 두지만 그리기에만 쓰는 것) — StageDirector 가 프레임을 넘어 이어 간다
public struct SceneCarry: Sendable {
    /// 보너스 차 연기 · 김 · 불길 입자(웹 BN.pfx)
    public var puffs = BonusPuffs()
    /// 지난 그리기의 찌그러짐 수(웹 C.dentN — carBones 가 쓰고 다음 프레임 모델이 읽는다)
    public var dentN = 0
    /// 무도장 건널목 배경(웹 DJ.xc — 전차 · 단풍. 규칙 효과가 없어 표현이 돌린다)
    public var cross: CrossAmbience?
    public init() {}
}

/// 장면 구성 입력 만들기(SimSnapshot → SceneInput). 웹 GS · TR 이름 그대로 옮긴다.
public enum SceneInputBuilder {
    public static func make(_ s: SimSnapshot, eye: EyeAdaptState, invF: Int, shake: Double, now: Double, playSpeed: Double,
                            carry: SceneCarry = SceneCarry()) -> SceneInput {
        var I = SceneInput()
        I.scene = "subway"; I.state = s.state
        I.time = s.gameTime; I.gsTime = s.time
        I.stage = s.stageIndex; I.stageIdx = Double(s.stageIndex)
        I.ci = Double(s.car); I.leg = Double(s.leg); I.legStart = s.legStart
        I.arriving = s.arriving; I.nextStop = s.nextStop; I.on = s.on
        I.oneBit = s.oneBit; I.invF = Double(invF); I.press = s.press; I.brakeGlow = s.brakeGlow
        I.props = s.props.map { .init(k: $0.kind, x: $0.x, ice: $0.ice) }
        I.cans = s.cans.map { .init(x: $0, v: 0) }
        I.shots = s.shotViews.map { .init(x: $0.x, y: $0.y, t: $0.t, vx: $0.vx, friendly: $0.friendly, kind: $0.kind.isEmpty ? nil : $0.kind) }
        I.items = s.floorItems.map { .init(kind: $0.kind, id: $0.id, x: $0.x, z: $0.z, t: $0.t) }
        I.passT = s.passTrain; I.lightK = s.lightK; I.emitK = s.emitK; I.hasBits = true
        var T = SceneInput.Train()
        T.ex = s.trainEx; T.dy = s.trainShakeY; T.v = s.trainSpeed; T.jolt = s.trainJolt; T.door = s.trainDoor
        T.t = s.trainT; T.a = s.trainAccel; T.strap = s.trainStrap; T.flickS = s.trainFlickS; T.stopAt = s.trainStopAt
        I.train = T
        I.straps = s.straps.map { .init(x: $0.x, a: $0.a) }
        if let H = s.actors.first(where: { $0.isHero }) { I.hero = .init(x: H.x, y: H.y, flip: H.flip, hidden: H.hidden) }
        I.foes = s.actors.filter { $0.isEnemy && !$0.hidden && $0.hp > 0 }.map {
            .init(x: $0.x, y: $0.y, flip: $0.flip, lamp: $0.enemyType == "lamp", down: CharacterStage.isDown($0), jug: $0.pose.hasJug)
        }
        I.eye = SceneInput.Eye(); I.eye.adT = eye.adT; I.eye.outS = eye.outS; I.eye.darkA = eye.darkA; I.eye.adA = eye.adA
        I.eye.now = now; I.eye.playSpeed = playSpeed
        I.shake = shake
        if let T = s.tower {   // 엘리베이터 타워(N5 모드 — 시뮬레이션이 채우면 장면 구성이 타워 갈래로 그린다)
            I.tower = .init(pos: T.pos, floor: T.floor, phase: T.phase, door: T.door, shk: T.shk, wreck: T.wreck, alarm: T.alarm,
                            fly: T.fly.map { .init(t: $0.t, dur: $0.dur, x0: $0.x0, x1: $0.x1, y0: $0.y0, y1: $0.y1, r0: $0.r0) },
                            sagV: T.sagV, limit: T.limit, over: T.over, panelT: T.panelT, kit: T.kit, dent: T.dent,
                            lamps: T.lamps.map { .init(a: $0.a, hang: $0.hang, flick: $0.flick) }, dark: T.dark,
                            fires: T.fires.map { .init(x: $0.x) }, fl: T.fl)
        }
        if let B = s.bonus { I.scene = "brawl"; I.brawl = bonusBrawl(s, B, carry: carry, now: now) }
        else if let C = s.cine { I.scene = "brawl"; I.brawl = cineBrawl(s, C, now: now) }
        else if s.scene == "brawl" { I.scene = "brawl"; I.brawl = SceneInput.Brawl(cam: s.cam, perfNow: now * 1000, crowd: crowd(s)) }
        if let P = s.prologue {   // 프롤로그 지하 복도(웹 GS.prologue — 거리 연출 중에도 남아 있지만 그땐 brawl 갈래가 먼저다)
            I.prologue = true
            I.corridor = .init(x: P.x, out: P.out, outT: P.outT, doors: P.doors.map { .init(wxc: Double($0.wxc), st: $0.st, t: $0.t) },
                               lamps: P.lamps.map { .init(wx: Double($0.wx), a: $0.a) })
        }
        if s.demo, let D = s.dojo {   // 무도장(웹 GS.demo && DJ.on)
            I.dojo = true
            I.dojoRoom = .init(bg: D.bg, sign: D.sign, lamps: D.lamps.isEmpty ? [0, 0] : D.lamps, bag: D.bagA,
                               walkers: D.walkers.map { .init(x: $0.x, v: $0.v, um: $0.um ? 1 : 0, t: $0.t) }, mook: D.mook, drum: D.drum, brd: D.brd, rack: D.rack,
                               xc: carry.cross?.state)
        }
        return I
    }

    /// 보조광 무리(웹 [hero, ...적(살아 있는)].slice(1) 중 안 숨은 것)
    static func crowd(_ s: SimSnapshot) -> [SceneInput.Pt] { s.actors.filter { $0.isEnemy && !$0.hidden && $0.hp > 0 }.map { .init(x: $0.x, y: $0.y) } }

    /// 프롤로그 뒤 비 오는 거리(웹 GS.cine — scene brawl · GS.cam 이 주인공을 따라간다)
    static func cineBrawl(_ s: SimSnapshot, _ C: CineView, now: Double) -> SceneInput.Brawl {
        SceneInput.Brawl(cam: C.cam, perfNow: now * 1000, crowd: crowd(s),
                         cine: .init(hammerIn: C.hammerIn, toss: C.tossT.map { .init(t: $0, x0: C.tossX0, y0: C.tossY0) }))
    }

    /// 보너스 차 부수기(웹 setScene('brawl') · GS.cam = 0) → brawl 입력
    static func bonusBrawl(_ s: SimSnapshot, _ B: BonusView, carry: SceneCarry, now: Double) -> SceneInput.Brawl {
        let C = B.car
        let car = SceneInput.Brawl.Bonus.Car(x: C.x, y: C.y, stage: C.stage, gone: C.gone, tilt: C.tilt, shake: C.shake, flash: C.flash, dmgF: C.dmgF,
                                             dentN: carry.dentN, debris: C.debris.map { .init(key: $0.key, x: $0.x, y: $0.y, z: $0.z, th: $0.th) })
        // 보조광 무리(웹 [hero, ...적(살아 있는)].slice(1) 중 안 숨은 것): 숨은 허수아비(invis — 웹은 hidden 이 아니라 포함)는 차 앞 x-50 · 주인공 높이에 있다
        var crowd = crowd(s)
        if B.phase != "owner", let H = s.actors.first(where: { $0.isHero }) { crowd.insert(.init(x: C.x - 50, y: H.y), at: 0) }
        return SceneInput.Brawl(cam: s.cam, stage: nil, perfNow: now * 1000, crowd: crowd, cine: nil,
                                bonus: .init(alarm: B.alarm, alarmOff: B.alarmOff, fire: B.fire, pfx: carry.puffs.items, car: car))
    }
}

/// 연출 감독: 카메라 · 입자 · 인물 · HUD · 소리 매핑을 한 화면 프레임 단위로 돌린다(앱 루프가 소유).
public final class StageDirector {
    public let content: SceneContent
    public let characters: CharacterStage
    public var camera = CameraDirector()
    public var fx = FxLayer()
    public var hud: HUDDirector
    public var sound: SoundDirector
    public var eye = EyeAdaptState()
    public var playSpeed = 1.25
    private var rng = FxRandom(SplitMix64(seed: 0x5CE7E))
    private let glyphs: Set<String>
    private var lastCar = -1, lastStage = -1
    /// 스냅숏에 없는 장면 그리기 상태(보너스 연기 입자 · 찌그러짐 수)
    public private(set) var carry = SceneCarry()
    private var lastGameTime: Double?
    /// 지난 프레임 인물 머리 자리(종이 회오리가 얼굴 둘레를 비운다)
    private var lastHeads: [ActorID: SIMD2<Double>] = [:]
    private var lastMouths: [ActorID: (p: SIMD2<Double>, fwd: SIMD2<Double>)] = [:]
    /// 네이티브 눈 승강장(docs/10): 내리는 눈 · 바닥 자국 · 튀는 눈 · 입김
    var snow = SnowFx()
    /// 네이티브 해변 도장(docs/12): 바다 · 밀려오는 물 · 젖은 모래 · 모래 자국 · 튀는 모래 · 물
    var beach = BeachFx()
    /// 네이티브 바닥 충격(깃발 켜짐 — 웹 HUD 균열 · 고리 대신 무대 픽셀)
    var impact = ImpactFx()
    /// 무도장 부서지는 소품 파편(네이티브 — DojoObjArt)
    var objFx = DojoObjFx()
    /// 직장인 세 기술 효과(네이티브 — 서류 · 결재 도장 · 박치기 별 · 어질어질 — NativeOfficeArt)
    var office = NativeOfficeFx()
    /// 타격감 묶음(docs/11 — KO 마무리 카메라 · 펀치인 · 찌그러짐 · 열기 · 발놀림 먼지). 깃발 켜짐(HUDCatalog.native)에서만
    var feel = ImpactFeel()
    /// 타격감 묶음 스위치(기본 켬 — 성능 비교 · 점검용)
    public var impactPack = true
    /// 피격 반응 다양화 스위치(기본 켬 — 깃발 켜짐에서만 걸린다 · 비교 띠용)
    public var hitReact = true
    /// 인물 가독성 스위치(기본 켬 — 깃발 켜짐에서만: 배경 밝기에 맞춘 테 · 발밑 접지 그림자 · 비교 띠용)
    public var readable = true { didSet { characters.contactShadow = readable } }
    /// 무도장 깊이 · 조명 세기(docs/10 §10 — 0 = 꺼짐 = 웹 그대로 · 1 = 적정). 깃발 켜짐(HUDCatalog.native) + 무도장에서만 걸린다
    public var dojoDepth = 1.0
    var depth = DojoDepth()
    func depthK(_ s: SimSnapshot) -> Double { hud.catalog.native && s.demo && s.dojo != nil ? max(0, dojoDepth) : 0 }
    var feelOn: Bool { impactPack && hud.catalog.native }
    /// KO 마무리의 조용한 한 박자가 시작됐나(한 번 — 앱이 배경음 · 환경음을 낮춘다)
    public func takeHush() -> Bool { feelOn && feel.takeHush() }
    /// 발 먼지 바닥 재질(눈은 SnowFx)
    static func dustFloor(_ s: SimSnapshot) -> FootDustFx.Floor {
        if s.demo, let D = s.dojo { return D.bg == "cross" ? .platform : .wood }
        if s.tower != nil { return .tower }
        if s.bonus != nil || s.cine != nil || s.prologue != nil || s.scene == "brawl" { return .platform }
        return .car
    }
    /// 바닥 충격 재질: 눈 · 무도장 나무 · 건널목 · 타워 · 보너스(돌) · 객차(금속 판)
    static func impactFloor(_ s: SimSnapshot) -> ImpactFx.Floor {
        if isSnow(s) { return .snow }
        if s.demo, let D = s.dojo { return D.bg == "cross" ? .stone : .wood }
        if s.tower != nil || s.bonus != nil { return .stone }
        return .metal
    }
    /// 눈 승강장인가(규칙 snowStage · 무도장 배경 'snow')
    public static func isSnow(_ s: SimSnapshot) -> Bool { s.snowStage != nil || (s.demo && s.dojo?.bg == "snow") }
    /// 해변 도장 시간대(무도장 배경 'beach' · 'beach_dusk' · 'beach_night' — 아니면 nil)
    public static func beachTime(_ s: SimSnapshot) -> BeachTime? { s.demo ? BeachTime.of(s.dojo?.bg) : nil }
    /// 해변 파도 소리 세기(0 = 해변 아님 — 밀려올 때 차오르고 빠질 때 잦아든다)
    public var surf: Double { beach.on ? beach.surf : 0 }
    /// 눈 승강장 바람 세기(소리 — 0 = 눈 승강장 아님)
    public var snowWind: Double { snow.on ? 0.45 + 0.55 * snow.gust : 0 }
    /// 지난 프레임에 쌓인 눈 소리(발 디딤 · 미끄러짐 · 쓰러짐)를 꺼낸다
    public func takeSnowCues() -> [SoundCue] { defer { snow.sounds = []; beach.sounds = [] }; return snow.sounds + beach.sounds }   // 해변 발소리 · 첨벙 · 갈매기도 같이

    public init(content: SceneContent, store: ContentStore, tables: AnimTables, catalog: HUDCatalog, heavyReactions: Set<String>, style: MotionStyle = .on) throws {
        self.content = content
        characters = try CharacterStage(store: store, tables: tables, style: style)
        hud = HUDDirector(catalog: catalog)
        sound = SoundDirector(heavyReactions: heavyReactions)
        glyphs = Set(content.sprites.keys.filter { $0.hasPrefix("g") && $0.count <= 4 })
        fx.impactPoses = Set(tables.poses.filter { $0.value.impact == true }.keys)
        RoofSourcePixels.shared.warm()   // 지붕 구멍 둘레 천장 띠 픽셀(뒤에서 미리 푼다)
        SnowArt.shared.warm()   // 눈 승강장 정지 그림(뒤에서 미리 그린다)
    }

    /// 한 틱(또는 한 프레임에 모인 여러 틱)의 이벤트 — 소리 이름표를 돌려준다
    public func apply(_ events: [SimEvent], snapshot s: SimSnapshot, now: Double) -> [SoundCue] {
        if s.car != lastCar || s.stageIndex != lastStage { fx.clear(); impact = ImpactFx(); office = NativeOfficeFx(); feel.dust = FootDustFx(); feel.embers = []; lastCar = s.car; lastStage = s.stageIndex }
        if feelOn { feel.apply(events, s, calm: camera.motionScale < 1, noFlash: hud.noFlash) }   // 타격감 묶음(docs/11)
        if hud.catalog.native && hitReact { characters.react(events, s) }   // 피격 반응 다양화(docs/11 §9 — 깃발 꺼짐 = 웹 그대로)
        // 네이티브 퇴근 승천권(깃발 켜짐에만 있는 동작) 동안은 화면 반전(임팩트 흰 화면)을 뺀다 — 섬광 줄임
        if s.actors.contains(where: { $0.isHero && $0.pose.anim == "nv_rise" }) {
            camera.apply(events.map { e in if case .camera(var k) = e, k.invertFrames > 0 { k.invertFrames = 0; return .camera(k) }; return e })
        } else { camera.apply(events) }
        if s.bonus != nil {                                                   // 보너스 차 연기 · 김 · 불길(위치는 시뮬레이션, 흐름은 여기)
            for case let .fx(kind, x, y, _) in events where kind.hasPrefix("car") { carry.puffs.push(event: kind, x: x, y: y, rng: &rng) }
        }
        if s.demo, s.dojo?.bg == "cross", var X = carry.cross {               // 건널목: 바닥 충격 · 먼지 자리의 단풍이 튄다(웹 groundImpact → xcKick · 먼지 → xcKick)
            for e in events {
                switch e {
                case let .groundImpact(x, y, p): let q = max(0.3, p); X.kick(x, y, 1 + q * 0.6, 10 + 30 * q, rng: &rng); X.kick(x, y, 0.8, 22, rng: &rng)
                case let .fx(kind, x, y, _) where kind == "dust": X.kick(x, y, 0.8, 22, rng: &rng)
                default: break
                }
            }
            carry.cross = X
        }
        fx.apply(events, actors: s.actors, glyphs: glyphs)
        fx.track(s)
        if s.demo, s.dojo != nil {   // 무도장 부서지는 소품(네이티브 · World+NativeObj): 깨지는 순간 파편
            let gy = s.actors.first(where: { $0.isHero })?.y ?? 222
            for case let .fx(k, x, y, d) in events where k.hasPrefix("objBreak:") { objFx.spawn(kind: String(k.dropFirst(9)), x: x, y: y, dir: d, gy: gy) }
        }
        if Self.isSnow(s) { snow.apply(events, s) }   // 눈 승강장: 쓰러짐 · 바닥 충격 · 무거운 타격에 눈이 튄다
        let beachy = Self.beachTime(s) != nil
        if beachy { beach.apply(events, s) }          // 해변: 쓰러짐 · 바닥 충격 · 무거운 타격에 모래 · 물이 튄다(바닥 충격 자국도 해변이 그린다)
        if hud.catalog.native {   // 직장인 세 기술: 서류 · 결재 도장 · 박치기 별(NativeOfficeArt)
            office.calm = hud.noFlash; office.apply(events, gy: s.actors.first(where: { $0.isHero })?.y ?? 222)
        }
        if hud.catalog.native && !beachy {   // 깃발 켜짐: 바닥 충격 자국 · 부스러기 · 고리를 무대 픽셀로(HUD 벡터 균열 · 주황 고리는 HUDModel 이 뺀다 — 해변은 BeachFx 구덩이)
            impact.floor = Self.impactFloor(s); impact.calm = hud.noFlash
            for e in events {
                switch e {
                case let .groundImpact(x, y, p): impact.impact(x, y, power: p)
                case let .fx(k, x, y, _) where k == "tsring" || k == "axring": impact.ring(x, y, big: k == "tsring")
                case let .fx(k, x, y, d) where k == "wallImpact": impact.wall(x, y, dir: d, power: 1.6, gy: s.actors.first(where: { $0.isHero })?.y ?? 222)   // 네이티브 벽꿍(World+NativeGrab · wallCheck)
                default: break
                }
            }
        }
        hud.apply(events, snapshot: s)
        var cues = sound.cues(for: events, now: now)
        if feelOn && feel.quiet != nil { cues.removeAll { feel.muted($0) } }   // KO 마무리 한 박자: 타격음 끊김
        return cues
    }

    /// 화면 프레임 조립. dt = 화면 프레임 길이(초) · now = 벽시계(눈 적응)
    public func frame(_ s: SimSnapshot, dt: Double, now: Double, hudPaused: Bool = false) -> StageFrame {
        var cam = camera.frame(s, dt: dt)
        // 장면 연출 상태 이어 가기(게임 시간 — 웹 pfxTick 은 gameUpdate dt)
        let gdt = lastGameTime.map { max(0, s.gameTime - $0) } ?? 0; lastGameTime = s.gameTime
        let feelOn = self.feelOn
        if feelOn {   // 타격감 묶음: KO 마무리 · 펀치인 카메라 · 발 먼지(눈 바닥은 SnowFx)
            feel.advance(dt: dt, gdt: gdt)
            feel.shape(&cam.view, s, motion: camera.motionScale)
            if !Self.isSnow(s) && Self.beachTime(s) == nil { feel.dust.ground = Self.dustFloor(s); feel.dust.track(s, dt: gdt) } else if !feel.dust.isEmpty { feel.dust = FootDustFx() }
        }
        if s.bonus == nil { if !carry.puffs.items.isEmpty || carry.dentN != 0 { carry.puffs.clear(); carry.dentN = 0 } } else { carry.puffs.advance(gdt) }
        if s.demo, let D = s.dojo {                                           // 무도장: 건널목 상태는 처음 들어올 때 만든다(웹 xcEnsure → xcReset)
            if carry.cross == nil { carry.cross = CrossAmbience(rng: &rng) }
            if D.bg == "cross", var X = carry.cross {                          // 웹 djTick → xcTick(게임 시간)
                X.tick(gdt, actors: s.actors.filter { $0.isHero || $0.isEnemy }.map { (id: $0.id, x: $0.x, y: $0.y, skip: $0.hidden || $0.pose.hasJug) }, rng: &rng)
                for p in X.newSparks { fx.sparks.append(.init(x: p.x, y: p.y, age: 0)) }
                X.newSparks = []; carry.cross = X
            }
        }
        let I = SceneInputBuilder.make(s, eye: eye, invF: camera.invF, shake: cam.shake, now: now, playSpeed: playSpeed, carry: carry)
        let snowy = Self.isSnow(s), beachT = Self.beachTime(s)
        var backMesh: [Float] = [], snowMesh: [Float] = []
        var scene: SceneFrame
        if beachT == nil && beach.on { beach = BeachFx() }
        if let bt = beachT {   // 네이티브 해변 도장: 정지 그림 + 바다 · 물가 · 자국(인물 뒤) · 튀는 모래 · 물(인물과 깊이 검사)
            if snow.on { snow = SnowFx() }
            if !beach.on || beach.time != bt { beach.reset(bt) }
            beach.advance(gdt); beach.track(s)
            var C = BeachContext(I: I, K: content, camX: cam.view.cameraX, time: bt); C.depthK = depthK(s)
            scene = C.compose()
            backMesh = BeachArt.shared.mesh(bt, camX: cam.view.cameraX) + beach.seaMesh(camX: cam.view.cameraX, visibleWidth: cam.view.visibleWidth)
                + beach.groundMesh(camX: cam.view.cameraX, visibleWidth: cam.view.visibleWidth)
            snowMesh = beach.mesh()
        } else if snowy {   // 네이티브 눈 승강장: 무대 픽셀 배경 · 광원 · 후처리(웹 장면 구성을 거치지 않는다)
            if !snow.on { snow.reset() }
            snow.advance(gdt); snow.track(s, mouths: lastMouths)
            var C = SnowContext(I: I, K: content, camX: cam.view.cameraX); C.depthK = depthK(s)
            scene = C.compose()
            backMesh = SnowArt.shared.mesh(camX: cam.view.cameraX) + snow.markMesh()
            snowMesh = snow.mesh(camX: cam.view.cameraX, visibleWidth: cam.view.visibleWidth, risePapers: hud.state.risePapers)
        } else {
            if snow.on { snow = SnowFx() }
            scene = SceneComposer.compose(I, content: content, rng: &rng)
        }
        impact.advance(gdt, wind: snowy ? snow.windNow : 0)
        // 무도장 부서지는 소품(네이티브): 소품은 인물 바로 뒤 · 파편은 인물 앞
        var objMesh: [Float] = []
        if s.demo, let D = s.dojo, !(D.objs.isEmpty && objFx.isEmpty) {
            let gy = s.actors.first(where: { $0.isHero })?.y ?? 222, zc = 0.9 - gy / 300
            objFx.advance(gdt, gy: gy)
            objMesh = DojoObjFx.objects(D.objs, gy: gy, z: zc + 0.05) + objFx.mesh(z: zc - 0.06)
        } else if !objFx.isEmpty { objFx = DojoObjFx() }
        if !impact.isEmpty { backMesh += impact.decalMesh(); snowMesh += impact.mesh() }
        office.advance(gdt)
        eye = scene.effects.eye; camera.invF = scene.effects.invF
        if let d = scene.effects.dentN { carry.dentN = d }
        for b in scene.effects.bits { fx.bits.append(.init(x: b.x, y: b.y, vx: b.vx, vy: b.vy, t: b.t)) }
        for sp in scene.effects.sparks { fx.sparks.append(.init(x: sp.x, y: sp.y, age: sp.age)) }
        fx.advance(gameTime: s.gameTime)
        // 네이티브 퇴근 승천권(지붕 구멍 · 종이 회오리): 지난 프레임까지의 HUD 상태로 무대 픽셀을 만든다(천장을 뚫고 나가는 몸은 천장 입술 뒤로)
        let rise = NativeRiseArt.build(hud.state, s, background: scene.background, sprites: content.sprites, heads: lastHeads, noFlash: hud.noFlash)
        if !rise.vols.isEmpty { scene.post.vols = Array((rise.vols + scene.post.vols).prefix(6)) }
        let chars = characters.build(s, dt: dt, zBack: rise.zBack)
        lastHeads = chars.heads; lastMouths = chars.mouths
        // 네이티브 야근 광선: 그린 머리에서 눈 자리를 잡아 도트 광선 · 광원(인물보다 조금 앞)
        var beam = NativeBeamLayer()
        if let B = s.beam, let H = s.actors.first(where: { $0.isHero }), let ey = chars.eyes[H.id] {
            beam = NativeBeamArt.build(B, eye: ey + SIMD2(B.f * 1.5, 0), z: 0.9 - H.y / 300 - 0.08, time: s.gameTime, calm: hud.noFlash)
            if !beam.vols.isEmpty { scene.post.vols = Array((beam.vols + scene.post.vols).prefix(6)) }
        }
        // 네이티브 내선 연결: 꼬인 전화선 · 수화기(인물보다 조금 앞)
        var cord = NativeCordLayer()
        if let C = s.cord, let H = s.actors.first(where: { $0.isHero }) {
            cord = NativeCordArt.build(C, z: 0.9 - H.y / 300 - 0.08, time: s.gameTime, calm: hud.noFlash)
        }
        // 직장인 세 기술 효과: 인물 앞 · 벽 도장(배경 바로 앞) · 광원
        var officeMesh: [Float] = [], officeLights: [SceneLight] = []
        if !office.isEmpty {
            let gy = s.actors.first(where: { $0.isHero })?.y ?? 222
            let o = office.build(heads: chars.heads, zc: 0.9 - gy / 300, time: s.gameTime)
            officeMesh = o.front; backMesh += o.back; officeLights = o.lights
        }
        let front = fx.frontDraws(content.sprites)
        if !hudPaused { hud.advance(dt: dt, snapshot: s) }
        // 웹 G-버퍼 순서: 배경 → 그림자 → [장면 mid(brawl 소품 · 입자 · 물건)] → 먼지 → [장면 3D(차)] + 인물 3D → 승객 소품 · [장면 front(단풍)] · 효과 → [장면 top(앞 차)]
        // brawl 카메라(charOX)는 인물 · 그림자 · 효과 · 동적 광원을 함께 민다(웹 drawOX = charOX · dyn[i].x += charOX)
        let ox = scene.charOX
        func shift(_ d: [SpriteDraw]) -> [SpriteDraw] { ox == 0 ? d : d.map { var q = $0; q.offsetX += ox; return q } }
        func shift(_ L: [SceneLight]) -> [SceneLight] { ox == 0 ? L : L.map { var l = $0; if l.dirl == nil { l.x += ox }; return l } }
        var mesh = chars.mesh
        var feelMesh: [Float] = []
        if feelOn && feel.busy { feel.deform(&mesh, ranges: chars.ranges, s); feelMesh = feel.mesh(s, ranges: chars.ranges, bodyMesh: mesh) }
        if ox != 0 { let f = Float(ox); for i in stride(from: 0, to: mesh.count, by: 10) { mesh[i] += f }; for i in stride(from: 0, to: feelMesh.count, by: 10) { feelMesh[i] += f }; for i in stride(from: 0, to: beam.mesh.count, by: 10) { beam.mesh[i] += f }; for i in stride(from: 0, to: officeMesh.count, by: 10) { officeMesh[i] += f }; for i in stride(from: 0, to: cord.mesh.count, by: 10) { cord.mesh[i] += f } }
        var out = StageFrame(scene: scene, shadows: shift(chars.shadows), preMesh: scene.mid + (snowy || beachT != nil ? [] : shift(fx.dustDraws(content.sprites))),   // 눈 승강장 · 해변: 회색 먼지 대신 눈 · 모래가 튄다
                             mesh: scene.mesh + mesh + rise.mesh + snowMesh + feelMesh + objMesh + beam.mesh + officeMesh + cord.mesh,
                             front: shift(chars.props) + scene.front + shift(front.draws) + scene.top, extraLights: rise.lights + shift(chars.lights + front.lights + beam.lights + officeLights + cord.lights),
                             shake: cam.shake, view: cam.view, time: s.gameTime)
        out.backMesh = backMesh
        out.readability = hud.catalog.native && readable ? 1 : 0
        let dk = depthK(s)
        if dk > 0, let D = s.dojo {   // 무도장 깊이 · 조명(docs/10 §10)
            let bg = snowy ? "snow" : D.bg
            DojoDepth.editScene(&out.scene, bg: bg, k: dk, t: s.gameTime)   // 무도장: 등롱 떨림 · 빛무리 · 달빛 기둥 · 블룸
            out.depth = depth.params(s, bg: bg, k: dk, view: cam.view, shake: cam.shake, hud: hud.state, cross: carry.cross?.state)
        }
        return out
    }
}
