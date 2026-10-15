import Foundation
import BBCore
import BBContent
import BBAnim

// 시뮬레이션의 바깥 계약(docs/06 §2.3 · §3). 표현 계층(BBPresentation · BBAudio · BBHaptics · BBUI)은 이 파일만 본다.
//   입력  : SimIntent(플레이어 의도 — 터치 시각 포함)
//   한 틱 : Sim.step(intents) → [SimEvent]   (1틱 = 1/60초 시뮬레이션 시간)
//   읽기  : Sim.snapshot (그리기용 읽기 전용 값)
// 규칙 코드는 소리 · 진동 · 글자 · 카메라를 직접 부르지 않는다 — 여기 이벤트로만 알린다.
// 이벤트는 '무슨 일이 일어났나'만 싣는다. 어떤 소리 · 진동 · 글자로 보일지는 표현 쪽 매핑이 정한다.

/// 플레이어 의도
public enum SimIntent: Sendable, Equatable {
    /// 무대 탭: 왼쪽(-1) · 오른쪽(+1). at = 터치 시각(시뮬레이션 시간, 초) — 저스트 판정은 이 시각 기준
    case tap(side: Int, at: Double)
    /// 화면 아래쪽 탭: 숙이기
    case duck(at: Double)
    /// 시작기 기회 '탭!' 응답
    case tapWindow(at: Double)
    case special
    case setSpeed(Double)
    case pause(Bool)
    /// 가방 편집(BBUI 의 BagEditor 가 만든 결과 상태를 그대로 넘긴다)
    case bagEdited
    /// 진행 화면 넘기기(매점 닫기 · 정리 끝 · 환승 카드 · 결과)
    case advance
    // ---- N3 에서 더함 ----
    /// 매점에서 k 번째 카드 고르기(-1 = 지나가기)
    case shopPick(Int)
    /// 매점 새로고침(토큰 2) · 각인 새기기(토큰 4)
    case shopReroll, shopCarve
    /// 대화 상자가 닫힘(skipTalks=false 일 때 멈춘 판을 다시 돌린다)
    case talkDone
    /// 가방 · 보류함 배치 통째로 바꾸기(BBUI BagEditor 결과): 같은 uid 의 자리 · 방향만 반영한다
    case bagLayout(bag: [BagItem], stash: [BagItem])
    /// 보류함 아이템 빈자리에 바로 넣기(웹 quickEquip)
    case quickEquip(uid: Int)
    /// 가방을 만지는 중(웹 bagTouch — 전투 중이면 시간이 0.2배로 느려진다)
    case bagTouch
    // ---- N4 에서 더함 ----
    /// 가방 편집기(합성 · 버리기)가 바꾼 토큰 수 반영 — bagLayout 과 함께 보낸다
    case bagTokens(Int)
    // ---- K(프롤로그 · 스토리 · 무도장)에서 더함 ----
    /// 대화 상자 탭(웹 tkNext — 고를 것이 떠 있으면 무시) · 고르기(웹 tkPick(k)). talkDone 은 건너뛰기(웹 tkSkip)
    case talkNext, talkPick(Int)
    /// 프롤로그 거리 연출 넘기기(웹 무대 탭 · 스페이스 — 0.6초 뒤부터). 무대 tap 도 연출 중이면 같은 일을 한다
    case cineSkip
    /// 무도장 · 콤보 실험실(웹 djDo · 패널 단추)
    case dojo(DojoCommand)
    /// 스킨 미리보기(웹 skinPvOpen · skinPvClose · 자세 편집기)
    case skinPreview(SkinPreviewCommand)
    /// 직접 조작 패드(네이티브 — World+NativePad). at = 터치 시각(저스트 판정)
    case pad(PadInput, at: Double)
}

/// 타격 무게(웹 ATK_FEEL.w · FOE_W)
public enum HitWeight: String, Sendable { case light = "L", medium = "M", heavy = "H" }

/// 액터 참조(이벤트 · 스냅숏에서 같은 인물을 가리키는 번호)
public typealias ActorID = Int

/// 시뮬레이션 → 표현 이벤트(웹에서 규칙 코드가 직접 부르던 연출 호출을 대신한다)
public enum SimEvent: Sendable, Equatable {
    // 전투
    case hit(HitInfo)
    case blocked(target: ActorID, kind: BlockKind)
    case evaded(target: ActorID)
    case heroHurt(weight: HitWeight)
    case foeDowned(target: ActorID, cause: DownCause, at: SIMD2<Double>)
    case justCounter(target: ActorID), counter(target: ActorID), perfectDodge(by: ActorID)
    case flankWarn(attacker: ActorID)
    case skillUsed(actor: ActorID, anim: String, itemUID: Int?)
    /// 동작 큐 프레임(잔상 · 초승달 · 먼지 등 동작 연출 시점)
    case actionCue(actor: ActorID, anim: String, cue: String)
    case groundImpact(x: Double, y: Double, power: Double)
    case comboStep(count: Int), comboEnded(count: Int, total: Int), comboRoute(name: String, step: Int, length: Int)
    case linkFired(source: Int, targets: [Int], link: String)
    case chainCharged(item: Int)
    // 가방 · 아이템
    case bagChanged, setChanged
    case itemDropped(kind: String, x: Double), pickedUp(kind: String, item: String?)
    // 진행
    case waveSpawned(types: [String], fromDoors: Bool)
    case bossAppear(actor: ActorID), bossRage(actor: ActorID), bossBreak(actor: ActorID)
    case bark(actor: ActorID, key: String)
    /// 안내 문구(say) — 번역 키(한국어 원문)와 자리 값
    case notice(title: String, body: String, seconds: Double)
    case stationApproach(station: String, quick: Bool, terminal: Bool)
    case arrived(onTime: Bool, bonus: Int), legCleared
    case railJoint, tunnelPressure, doors(open: Bool)
    case stageTransfer(stage: Int), runEnded(win: Bool)
    case specialReady, specialUsed
    case lightsTransition(toDark: Bool)
    // 카메라 · 화면 의도(실제 보간은 BBPresentation)
    case camera(CameraKick)
    case haptic(HitWeight)
    // 저장
    case metaChanged, runCheckpoint
    // ---- N5 모드에서 더함 ----
    /// 타워 층 도착(웹 twArrive — 층 이름 · 안내는 notice 로 따로 온다)
    case towerFloor(floor: Int)
    /// 타워 끝(웹 towerResult — 결과 카드 값)
    case towerEnded(TowerResult)
    /// 보너스 결산(웹 bonusUpdate 가 owner 단계로 넘어갈 때 — 등급 · 토큰 · 점수표)
    case bonusEnded(BonusResult)
    // ---- K(프롤로그 · 스토리 · 무도장)에서 더함 ----
    /// 대화 끝(웹 tkEnd — 고른 값). 시작은 talk(key:) — 줄 · 고를 것은 스냅숏 talk 로 읽는다
    case talkEnded(key: String, picked: String?)
    /// 콤보 쇼 '탭!' 창 열림 · 닫힘(just = 제때 눌렀다 — 웹 tapFire(true))
    case tapWindow(open: Bool, just: Bool)
    /// 프롤로그 · 무도장 장면 고비(표현 연출 신호): prologue · door:open:<wxc> · vault · exit · cine · toss · stairs · cineEnd · kane · bagScatter · kaneEnd · dojo · dojoEnd
    case storyBeat(String)
    /// 무도장 시연 결과(웹 dojoResult 글 — 'N타 중 M타 적중 · 공중 K타 · 최고 H')
    case dojoResult(text: String)
    // ---- N3 에서 더함(웹 직접 연출 호출을 그대로 옮긴 세부 신호 — 표현 쪽 매핑표가 소리 · 글자 · 입자로 바꾼다) ----
    /// 단독 효과음(웹 sfx.<id>(value)) — 위 이벤트에서 파생되지 않는 것만(swing · whoosh · clack · door · coin · glass · dodge · thud · floor · pass · press …)
    case sfx(id: String, value: Double)
    /// 무대 입자 · 잔상 의도(웹 HITFX · sparks · dusts · rings 푸시) — kind 는 웹 이름(dust · spark · ring · burst · crescent · axring · gdust …)
    case fx(kind: String, x: Double, y: Double, dir: Double)
    /// 만화 효과음 글자(웹 comicSFX) — 원문 그대로(번역 키)
    case comicWord(word: String, x: Double, y: Double)
    /// 말풍선(웹 comicSay · bark) — kind: speech · think · shout
    case speech(actor: ActorID, text: String, kind: String)
    /// 화면 가운데 상태 글자(웹 GS.flash: MISS · BLOCK · LINK · CLEAR · JUST! …)
    case statusFlash(text: String, seconds: Double)
    /// 피해 · 회복 숫자(웹 dmgPop) — value 는 화면 숫자(DMG_K 배), style: hit · crit · hurt · heal
    case damagePop(target: ActorID, value: Int, style: String, label: String?)
    /// 연타 합계(웹 'N HIT TOTAL')
    case comboTotal(hits: Int, damage: Int)
    /// 점수 · 토큰 글자(웹 pops '+300' · '!' · '서류!')
    case textPop(x: Double, y: Double, text: String)
    /// 도움말(웹 hint(k)) · 대화 요청(웹 talkSoon/talkOnce — key)
    case hint(key: String), talk(key: String)
    /// 컷인 시작(웹 GS.cut: spc · vs · rage) · 끝
    case cutIn(kind: String, actor: ActorID?, seconds: Double), cutInEnded(kind: String)
    /// 판 상태가 바뀜(웹 GS.state: fight · arrive · board · shop · arrange · final · end · transfer · over)
    case stateChanged(String)
    /// 매점 목록(아이템 id)
    case shopOpened(items: [String])
    /// 기술 이름 줄(웹 cmdPush/cmdSkill) — tag: crit · link · fist · foot · grap · env · sp
    case command(name: String, tag: String)
    /// 가방 타일 반짝임(웹 bagFire · pulseItem) — kind: fire · crit
    case bagPulse(uid: Int, kind: String)
    // ---- M(HUD 실제 값)에서 더함 ----
    /// 웹 `comicT=0` — 바로 뒤 comicWord 는 0.5초 간격을 무시하고 뜬다(받아치기 · 저스트 · 콰직 · 쿠웅 · 쾅 · 타워/보너스 알림 …)
    case comicReset
    /// 값이 더 필요한 HITFX(웹 HITFX.push 그 자리): crescent(회전 중심 = 리그 J.W2) · axv(칼날 x · y0=y · y1) · cyw(바퀴) · cystar(연타 별 s) · swirl(n = ph · big = 마지막 큰 소용돌이)
    case fxDetail(FxDetail)
    // ---- 공방(docs/08 — SimConfig.nativeMoves 켜짐에서만 난다) ----
    /// 가드로 막음(앉아 막기가 상단을 숙여 흘린 것도 — whiff) · 저스트 가드(just)
    case guardBlock(GuardInfo)
    /// 가드 크래시(게이지가 다 깎여 팔이 튕겨 열림 — 짧은 무방비)
    case guardCrash(GuardInfo)
    // ---- 퇴근 승천권(SimConfig.nativeMoves 켜짐에서만) ----
    /// 지붕 뚫기: 승천권 꼭대기 한 방으로 쓰러진 적이 천장을 뚫고 화면 위로 날아간다(드물게 — 8초에 한 번 이하)
    case roofBlast(RoofBlast)
    /// 지붕 뚫기 뒤 1.9초: 지붕 위에 떨어지는 '…쿵'(구멍에서 먼지 한 줌)
    case roofThud(RoofBlast)
    // ---- 타격감 묶음(docs/11 — SimConfig.nativeMoves 켜짐에서만) ----
    /// KO 마무리: 웨이브 · 칸의 마지막 적이나 두목을 주인공이 쓰러뜨림(웨이브마다 한 번) — 0.4초 0.25배 슬로 → 짧은 정지 → 표현이 한 박자 쉰다
    case koFinisher(KOFinisher)
}

/// KO 마무리 값 — 쓰러진 몸 자리 · 날아간 방향 · 두목인가 · 슬로(실제 초) · 정지(애니 칸)
public struct KOFinisher: Sendable, Equatable {
    public var target: ActorID
    public var x: Double, y: Double
    public var dir: Double
    public var boss: Bool
    public var slow: Double, freezeFrames: Int
    public init(target: ActorID, x: Double, y: Double, dir: Double, boss: Bool, slow: Double, freezeFrames: Int) {
        self.target = target; self.x = x; self.y = y; self.dir = dir; self.boss = boss; self.slow = slow; self.freezeFrames = freezeFrames
    }
}

/// 지붕 뚫기 값 — 구멍을 낼 자리(x · 천장 y)와 무대 종류
public struct RoofBlast: Sendable, Equatable {
    public var target: ActorID
    /// 구멍 가운데 x · 천장 선 y(무대 픽셀)
    public var x: Double, y: Double
    /// car(객차 천장) · hatch(엘리베이터 비상 해치) · tile(프롤로그 복도 천장 타일) · none(천장이 안 보이는 곳 — 빛줄기만)
    public var kind: String
    /// 날아가는 방향(+1 오른쪽)
    public var dir: Double
    public init(target: ActorID, x: Double, y: Double, kind: String, dir: Double) { self.target = target; self.x = x; self.y = y; self.kind = kind; self.dir = dir }
}

/// 막기 · 가드 크래시 값(HitInfo 꼴 — 표현이 불꽃 · 밀림 · 소리 · 진동 · 글자를 고른다)
public struct GuardInfo: Sendable, Equatable {
    public var attacker: ActorID, target: ActorID
    /// 맞닿은 자리(가드한 팔 높이) · 때린 쪽 방향(+1 오른쪽으로)
    public var at: SIMD2<Double> = .zero
    public var dir = 1.0
    /// 공격 높이 high · mid · low · 가드 자세 1 서서 · 2 앉아
    public var height = "high", stance = 1
    /// 무거운 공격(H) · 쳐내기(권법가 · 스파링꾼) · 저스트 가드 · 앉아 막기로 상단을 흘림 · 주인공이 막음 · 가드 부수기 기술(리버 · 코크스크루)로 깎임
    public var heavy = false, parry = false, just = false, whiff = false, heroBlocked = false, pierced = false
    /// 막은 뒤 남은 가드 게이지(0..1) · 연속으로 막은 수
    public var meter = 1.0, streak = 1
    public init(attacker: ActorID, target: ActorID) { self.attacker = attacker; self.target = target }
}

/// 웹 HITFX 한 칸의 규칙 쪽 값(표현은 수명 · 그림을 정한다)
public struct FxDetail: Sendable, Equatable {
    public var kind: String
    public var x: Double, y: Double
    /// 방향(웹 f)
    public var dir = 1.0
    /// axv 칼날 끝 y(웹 y1 — y 는 y0)
    public var y1: Double? = nil
    /// 크기 배율(웹 cystar s) · 번호(웹 swirl ph) · 큰 것(웹 swirl big)
    public var s = 1.0, n = 0, big = false
    public init(kind: String, x: Double, y: Double, dir: Double = 1, y1: Double? = nil, s: Double = 1, n: Int = 0, big: Bool = false) {
        self.kind = kind; self.x = x; self.y = y; self.dir = dir; self.y1 = y1; self.s = s; self.n = n; self.big = big
    }
}

public struct HitInfo: Sendable, Equatable {
    public var attacker: ActorID, target: ActorID
    public var damage: Int
    public var crit = false, bigCrit = false, counter = false, just = false, back = false
    public var reaction: String
    public var weight: HitWeight = .light
    public var dead = false, airborne = false, heroWasHit = false
    /// 소리 등급(웹 hitTier 0~2) · 종류(hitKind)
    public var soundTier = 0, soundKind: String?
    public var at: SIMD2<Double> = .zero
    /// 맞은 쪽 정지 칸(웹 tgt.hs — 애니메이션 칸 단위)
    public var freezeFrames = 0
    // ---- M(HUD 실제 값)에서 더함 — 웹 hitFx · swHit · chFx 가 읽는 값 ----
    /// 웹 o.low(낮은 타격) · o.splash(곁다리 — 충격파 없음) · big(웹 damage 의 big = crit || knock || react 'launch')
    public var low = false, splash = false, big = false
    /// 받아치기(웹 chit — 적이 치려고 준비하는 순간에 맞힘) · 그때 큰 연출(웹 chFx 의 반짝 · 1.2초에 한 번)을 냈나
    public var chit = false, chitFlash = false
    /// 때린 쪽 동작(웹 att.anim — 타격 순간) · 맞은 쪽 반응 뒤 동작(웹 hitFx 의 tgt.anim) · 때린 쪽이 주인공
    public var attackerAnim = "", targetAnim = "", attackerIsHero = false
    /// 방향(웹 f = 때린 쪽 방향 × (등 뒤면 −1))
    public var dir = 1.0
    /// 맞은 쪽 저글 높이(웹 tgt.jug.h — 반응 뒤, 없으면 0) · 떠 있는 높이(웹 tgt.airOv)
    public var targetJugH = 0.0, targetAirOv = 0.0
    // ---- U(표현 정리)에서 더함 — 웹 damage() 의 연출 갈래가 읽는 타격 옵션 그대로 ----
    /// 웹 o.knock(넘어뜨리는 타격) · o.react(옵션 반응 — 'launch' · 'head' …, reaction 은 reactKey 뒤 실제 반응)
    public var knock = false, reactOpt: String? = nil
    public init(attacker: ActorID, target: ActorID, damage: Int, reaction: String) {
        self.attacker = attacker; self.target = target; self.damage = damage; self.reaction = reaction
    }
}
public enum BlockKind: String, Sendable { case parry, shield, lamp, pan }
public enum DownCause: String, Sendable { case ko, doorOut, last, boss }

/// 카메라 의도(웹 shakeAmp · zoomK · zoomC · slowT · freeze · invF 를 직접 쓰던 것)
public struct CameraKick: Sendable, Equatable {
    /// 줌 펀치 합치기(웹 자리마다 식이 다르다):
    ///  add(cap) = min(cap, zoomK + zoom) · max(cap) = min(cap, max(zoomK, zoom)) · set = zoomK = zoom
    ///  legacy = 예전 추정(값 크기로 상한을 고름 — 아직 모드를 안 정한 호출 자리)
    public enum ZoomMode: Sendable, Equatable { case legacy, add(cap: Double), max(cap: Double), set }
    public var shake = 0.0, zoom = 0.0, focus: SIMD2<Double>? = nil
    public var slowmo = 0.0, freezeFrames = 0, invertFrames = 0, shove = 0.0
    public var zoomMode: ZoomMode = .legacy
    /// 흔들림 세기 덮어쓰기(웹 shakeAmp = v). 꺼짐(기본)이면 웹 대부분 자리처럼 shakeAmp = max(shakeAmp, v)
    public var shakeSet = false
    public init() {}
}

/// 그리기용 읽기 전용 상태(한 틱 끝)
public struct SimSnapshot: Sendable {
    public struct ActorView: Sendable {
        public var id: ActorID
        /// 인물 정의 이름(JW_HERO · JW_THUG …) — BBAnim CharacterDef 조회
        public var def: String
        public var pose: ActorPose
        public var x: Double, y: Double, flip: Bool
        public var remap: Int, flash: Double, weaponSprite: String?
        public var hidden: Bool, isHero: Bool, isEnemy: Bool, isPassenger: Bool
        public var shake: Double
        // ---- N3 에서 더함(기본값이 있어 기존 init 그대로 쓸 수 있다) ----
        /// 생김새 열쇠(웹 defFor LOOK_CACHE 키 hair|fat|coat|boss|tie|mandarin) — nil 이면 def 기본 모델
        public var look: String? = nil
        /// 적 종류(ETYPES 키) · 이름
        public var enemyType: String? = nil
        public var name: String = ""
        public var hp: Double = 0, maxHP: Double = 0
        public var isBoss = false
        /// 깊이(웹 a.z — 그리기 순서) · 떠 있는 높이(웹 airOv)
        public var z: Double = 0, airOv: Double = 0
        /// 공격 예고(웹 a.action && !fired && FOE_W) — 무게 L/M/H · 타격까지 남은 초(저스트 고리)
        public var tellWeight: String? = nil, timeToCue: Double? = nil
        /// 승객 동작(paper · phone · doze) · 댄서 · 촬영 중
        public var idleProp: String? = nil
        public var stunned = false
        /// 타워 특수 행동 진행 0..1(수리 기사 배선 끊기 5초 · 회계사 버튼 3초 — 웹 drawTowerTop 의 머리 위 막대) · 종류 tech · presser
        public var work: Double? = nil, workKind: String? = nil
        /// 프롤로그 콤보 쇼 대상(웹 a.sc) · 빅터 케인(웹 a.kane) · 무도장 허수아비(웹 a.dojo)
        public var sc: String? = nil, kane = false, dojo = false
        /// 승객 모델 번호(웹 PASS_MODEL[k%3] — enterCar · [(k+GS.uid)%3] — boardAt). 승객이 아니면 nil
        public var passModel: Int? = nil
        // ---- 공방(docs/08)에서 더함 ----
        /// 가드 자세(0 없음 · 1 서서 · 2 앉아) · 가드 게이지(0..1, 깃발 꺼짐이면 nil) · 마지막으로 막은 뒤 지난 초 · 가드 크래시 무방비 중 · 공격권(토큰)을 쥠 · 끼어들기 예고 중
        public var guardStance = 0
        public var guardMeter: Double? = nil, guardSince = 99.0
        public var guardCrash = false, attackToken = false, cutInTell = false
        public init(id: ActorID, def: String, pose: ActorPose, x: Double, y: Double, flip: Bool, remap: Int, flash: Double, weaponSprite: String?,
                    hidden: Bool, isHero: Bool, isEnemy: Bool, isPassenger: Bool, shake: Double) {
            self.id = id; self.def = def; self.pose = pose; self.x = x; self.y = y; self.flip = flip; self.remap = remap; self.flash = flash
            self.weaponSprite = weaponSprite; self.hidden = hidden; self.isHero = isHero; self.isEnemy = isEnemy; self.isPassenger = isPassenger; self.shake = shake
        }
    }
    public var time: Double = 0           // 전투 시계(웹 GS.time)
    public var gameTime: Double = 0       // 애니메이션 시계(웹 gameTime)
    public var state: String = "idle"     // 웹 GS.state
    public var stageIndex = 0, car = 0
    public var hp = 0.0, maxHP = 0.0, score = 0, tokens = 0, combo = 0, special = 0.0
    public var actors: [ActorView] = []
    /// 열차 상태(장면 그리기 · 열차 소리 입력)
    public var trainSpeed = 0.0, trainPhase = "stop", trainDoor = 0.0, trainShakeY = 0.0, trainAccel = 0.0
    public var lightK = 1.0, emitK = 1.0, oneBit = false
    // ---- N3 에서 더함 ----
    /// 열차 누적 거리 · 구간 시작 거리 · 구간 진행(초) · 구간 길이(초) · 지금 선 역 · 다음 역 · 급행
    public var trainEx = 0.0, legStart = 0.0, legT = 0.0, legDur = 0.0, trainStrap = 0.0, trainJolt = 0.0
    public var atStop: String? = nil, nextStop: String? = nil, express = false
    public var leg = 0, wave = 0, waves = 0
    public var kills = 0, maxCombo = 0
    /// 카메라(세로 화면 크롭 왼쪽 x) · 확대(필살기) · 슬로 남은 초 · 화면 정지 칸
    public var camX = 0.0, camZoom = 1.0, slowT = 0.0, freeze = 0
    /// 컷인(spc · vs · rage) 진행 0..1
    public var cutKind: String? = nil, cutProgress = 0.0
    public var specialActive = false
    /// 바닥 물건 · 투사체 · 캔 · 소품(그리기용)
    public var floorItems: [FloorItemView] = [], shots: [SIMD2<Double>] = [], cans: [Double] = [], props: [PropView] = []
    /// 교행 열차 진행(초) · 제동 불꽃 세기
    public var passTrain: Double? = nil, brakeGlow = 0.0
    public var stats = RunStats()
    public var bag: [BagItem] = [], stash: [BagItem] = []
    /// 실행 중 콤보 경로(uid 들 · 진행 칸)
    public var comboRoute: [Int] = [], comboStep = 0, comboName: String? = nil
    // ---- N4 에서 더함(표현 · 소리 · 흐름 화면이 읽는 값 — Sim+Present.swift 가 채운다) ----
    /// 웹 GS.on · GS.arriving · GS.press(터널 압력) · GS.shoveX(맞은 쪽으로 미는 화면) · GS.doorWant
    public var on = false, arriving = false, press = 0.0, shoveX = 0.0, doorWant: Bool? = nil
    /// 열차 시계 TR.t · 정차 목표 TR.stopAt · 형광등 깜빡임 TR.flick · flickS
    public var trainT = 0.0, trainStopAt = 0.0, trainFlick = 0.0, trainFlickS = 0.0
    /// 손잡이 흔들림(웹 STRAPS[x].a)
    public var straps: [StrapView] = []
    /// 투사체 상세(그리기용 — shots 는 위치만)
    public var shotViews: [ShotView] = []
    /// 가방 칸 각인(웹 GS.imprints "x,y" → holster · pocket · worn)
    public var imprints: [String: String] = [:]
    /// 매점 카드(웹 GS.shopList) · 새로고침 횟수
    public var shopCards: [ShopCardView] = []
    public var rerolls = 0
    /// 정리 남은 초(웹 GS.arrT) · 환승 진행 초(웹 GS.trT) · 환승해 갈 노선
    public var arrangeT = 0.0, transferT = 0.0, transferTo = 0
    /// 다음 웨이브까지 남은 시간 판정용(웹 GS.legT 는 legT) · 정리 화면을 만졌나
    public var arrangeTouched = false
    /// 대화 상자 대기(skipTalks=false 일 때)
    public var talkActive = false
    // ---- N5 모드에서 더함(타입은 Core/SimModes.swift · World+Tower/Bonus 가 채운다) ----
    /// 엘리베이터 타워 진행(웹 GS.tower) — 타워 판일 때만
    public var tower: TowerView? = nil
    /// 보너스 차 부수기 진행(웹 GS.bonus) — 보너스 중일 때만
    public var bonus: BonusView? = nil
    // ---- K(프롤로그 · 스토리 · 무도장)에서 더함(타입은 Core/Sim+Story.swift) ----
    /// 장면(웹 scene: subway · 프롤로그 거리 brawl) · 거리 카메라(웹 GS.cam) · 확대 중심(웹 GS.camC, 화면 비율 0..1)
    public var scene = "subway", cam = 0.0
    public var camC: SIMD2<Double>? = nil
    /// 지하 복도(웹 GS.prologue) · 거리 연출(웹 GS.cine) · 케인 장면(웹 GS.kane) — 진행 중일 때만
    public var prologue: PrologueView? = nil
    public var cine: CineView? = nil
    public var kane: KaneView? = nil
    /// 보스의 가방 쇼 ~ 케인 장면(웹 GS.pBag) · 맡겨 둔 시작 가방(웹 GS.pKit — 이어 하기 저장은 가방에 장도리가 있으면 이것을 쓴다: 웹 saveRun)
    public var pBag = false
    public var pKit: [BagItem]? = nil
    /// 콤보 쇼 '탭!' 창(웹 GS.tapW)
    public var tapWindow: TapWindowView? = nil
    /// 대화 상자(웹 GS.talk) · 마지막 도움말(웹 hint → say)
    public var talk: TalkView? = nil
    public var hint: HintView? = nil
    /// 무도장(웹 GS.demo · GS.dojoSeq · DJ) · 스킨 미리보기(웹 GS.skinPv)
    public var demo = false
    public var dojo: DojoView? = nil
    public var skinPv: SkinPreviewView? = nil
    // ---- M(HUD 실제 값)에서 더함 ----
    /// 직접 조작 남은 초(웹 GS.manualT — > 0 이면 MANUAL) · 가방 정리 슬로 남은 초(웹 GS.bagSlowT) · 전투 중(웹 inCombat())
    public var manualT = 0.0, bagSlowT = 0.0, inCombat = false
    /// 암전(웹 GS.fade 0..1 — 칸 들어갈 때 1 → 초당 2 씩) · 지연 체력(웹 GS.lagH — 체력 칸 크림색)
    public var fade = 0.0, lagH = 0.0
    /// 네이티브 눈 승강장(docs/10): 바깥 고가 승강장에서 싸우는 동안 그 역 id(열차가 붙잡혀 있다) — 깃발 꺼짐이면 늘 nil
    public var snowStage: String? = nil
    /// 네이티브 야근 광선(World+NativeBeam — 깃발 꺼짐이면 늘 nil): 단계(charge 모음 · fire 발사 · fade 사라짐) · 단계 안 시간 · 방향 · 각도(라디안, + 위) · 길이 · 최근 맞은 자리
    public struct BeamView: Sendable, Equatable {
        public var phase: String, t: Double, f: Double, ang: Double, len: Double
        public var hits: [SIMD2<Double>]
    }
    public var beam: BeamView? = nil
    /// 네이티브 내선 연결(World+NativeDial — 깃발 꺼짐이면 늘 nil): 단계(hold 손에 · fly 날아감 · pull 끌어옴 · reel 튕겨 돌아옴 · stow 다시 손에) · 단계 안 시간 ·
    /// 수화기를 쥔 손 · 수화기 자리(장면 좌표) · 방향 · 끌어온 거리(px — 발밑에 감기는 선) · 발 자리(x · 바닥 y)
    public struct CordView: Sendable, Equatable {
        public var phase: String, t: Double
        public var hand: SIMD2<Double>, tip: SIMD2<Double>
        public var f: Double, hauled: Double, foot: SIMD2<Double>
    }
    public var cord: CordView? = nil
    /// 직접 조작 패드(네이티브 · World+NativePad): 가방 기술 버튼 · 받아치기 · 큰 공격 · 수동 남은 초
    public struct PadView: Sendable, Equatable {
        public struct Btn: Sendable, Equatable {
            public var uid: Int, id: String, name: String, fam: String
            /// 쿨타임 남은 몫(0 = 준비됨 · 1 = 막 씀) · 남은 초
            public var cd: Double, wait: Double
            /// 콤보 경로 순서(1부터 — 경로 밖이면 nil) · 경로의 다음 차례이고 준비됨
            public var order: Int?, next: Bool
        }
        public var skills: [Btn] = []
        public var counter = false, heavy = false
        public var manual = 0.0
        public init() {}
    }
    public var pad: PadView? = nil
    /// 숙이기 준비(웹 duckReady()) · DUCK 경고(웹 drawUI: 다가오는 투사체 && duckReady && !isDucking — 깜빡임은 표현)
    public var duckReady = false, duckWarn = false
    /// 연타 창(웹 comboWin()) · 마지막 타격 시각(웹 GS.lastHit) · 연타 피해 합(웹 GS.comboDmg) · 저스트 창(웹 JUST_W())
    public var comboWin = 2.2, lastHit: Double? = nil, comboDmg = 0, justW = 0.16
    public struct StrapView: Sendable, Equatable { public var x: Double, a: Double }
    public struct ShotView: Sendable, Equatable { public var x: Double, y: Double, t: Double, vx: Double, friendly: Bool
        /// 모양(네이티브 전용 — "" 병 · "news" 신문 뭉치)
        public var kind = "" }
    public struct ShopCardView: Sendable, Equatable { public var id: String, tier: Int, opt: ItemOption? }
    public init() {}
    public struct FloorItemView: Sendable { public var kind: String, id: String?, x: Double, z: Double; public var t: Double = 0 }
    public struct PropView: Sendable { public var kind: String, x: Double
        /// 타워 냉동 창고의 언 바닥(웹 props[].ice)
        public var ice = false }
}
