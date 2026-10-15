import Foundation
import BBCore
import BBContent
import BBAnim

// 웹 GS(판 상태) + TR(열차) + 장면/노선(STAGE · LINE · STOPS) + 액터 목록을 한곳에 모은 참조 타입.
// 1단계(충실 이식): 웹 함수 이름 그대로 World 메서드로 옮긴다(파일은 웹 조각별 World+*.swift). 각 메서드 주석에 웹 함수 이름.
// 연출 호출(sfx · say · comicSFX · dmgPop · HITFX · shakeAmp · buzz · renderBag DOM …)은 SimEvent 로 바꾸거나(필요한 것) 버린다(순수 장식).
// 규칙에 영향을 주는 값(freeze · slowT · hs · spcTime · cut 일시정지)은 여기 상태로 남는다.

/// 판 설정(웹 RUNCFG + 하네스 정책)
public struct SimConfig: Sendable {
    public var kit = "basic"
    public var stage = 0
    public var daily = false
    /// 게임 속도(웹 GAME_SPD 1.25 — 타이틀에서 시작하면 이 값. 웹 자동 점검 하네스는 1)
    public var playSpeed = 1.25
    /// 세로 화면 무대 폭(웹 VW = H·4/3 = 360). 480 이면 가로(카메라 고정)
    public var viewWidth = 360.0
    /// 진행을 막는 화면(매점 · 정리 · 환승 카드)을 자동으로 넘긴다(매점은 첫 카드를 고른다 — 웹 simtrace 하네스 정책)
    public var autoAdvance = false
    /// 마지막으로 그린 자세(lastP)를 시뮬레이션이 대신 계산한다(웹은 그리기가 남김 → 자동 착지 다리 판단에 쓰인다).
    /// 웹 하네스(렌더 없음)와 비교할 때는 끈다.
    public var trackDrawnPose = true
    /// 대화(talkSoon) 를 건너뛴다(웹 자동 점검 환경과 같게). false 면 talk 이벤트를 내고 talkDone 까지 멈춘다
    public var skipTalks = true
    /// 옵션(웹 OPT): 필살기 자동 · 컷인 짧게 · 진동/섬광 끔은 표현 쪽
    public var autoSpecial = false
    public var shortCut = true
    /// 이미 본 컷인(웹 META.seenCut) — 두 번째부터 짧게
    public var seenCuts: Set<String> = []
    /// 웹 하네스 흉내: setMode('game') 가 먼저 기본 설정으로 startRun 을 한 번 부른다(난수 · uid 소비가 같아지게) — 락스텝 대조용
    public var harnessWarmup = false
    /// 규칙 난수 자리 기록(락스텝 대조)
    public var traceRandom = false
    /// 시작 가방을 통째로 바꾸기(id · x · y · rot 만 씀 — 시험 · 무도장용). 웹 하네스와 같이 startRun 뒤 newItem → fitBag → renderBag
    public var customBag: [BagItem]?
    // ---- N5 모드(타워 · 보너스)에서 더함 ----
    /// 시작 모드: 지하철 판(기본) · 엘리베이터 타워(웹 startTower) · 보너스 차 부수기 바로 가기(웹 jumpTo('bonus') — 개발용)
    public var mode: SimStartMode = .subway
    /// 타워 야근 단계(웹 opts.ot) — 실제 단계는 meta.tower.ot(열린 단계)로 잘린다(웹과 같게)
    public var towerOT = 0
    /// 오늘 날짜 열쇠(웹 todayKey() 'YYYY-MM-DD') — 오늘의 타워 · 오늘의 가방 시드. 시뮬레이션은 시계를 읽지 않으므로 바깥에서 준다
    public var dateKey: String?
    /// 시작 메타 기록(웹 META 중 규칙이 읽는 것 — 타워 열린 단계 · 기록). nil 이면 빈 기록
    public var initialMeta: SimMeta?
    // ---- K(프롤로그 · 스토리 · 무도장)에서 더함 ----
    /// 첫 노선 새 판을 지하 복도 프롤로그로 시작(웹 OPT.prologue !== false · 자동 점검 환경이 아님). 테스트 · 하네스 기본은 끔
    public var prologue = false
    /// 주인공 스킨(웹 OPT.skin — 스킨 미리보기 몸짓 gx_<skin>)
    public var skin = "jw"
    // ---- S(네이티브 동작 개편)에서 더함 ----
    /// 네이티브 동작 개편(웹과 일부러 다르게): 이동 판단(걷기 · 스텝 인 · 질주 · 미끄러져 서기) · 필살기 '막차 러시'를 뎀프시 롤 풍 연타로 ·
    /// 복싱 기술 5종(상점 · 서류 드롭에 나온다). 기본 꺼짐 = 웹과 같은 규칙(락스텝 · 분포 대조 기준). 앱은 켠다
    public var nativeMoves = false
    // ---- 공방(docs/08)에서 더함 ----
    /// 깃발(nativeMoves) 켜짐에서 공방 층(군중 공격권 · 가드/높이 · 가드 크래시 · 끼어들기)을 쓸지. 앱 · 기본은 켬 —
    /// 밸런스 비교 테스트가 '공방 전'(nativeMoves 만) 기준을 재려고 끈다. nativeMoves 가 꺼지면 아무 뜻이 없다(웹 그대로)
    public var nativeGuard = true
    // ---- 눈 승강장(docs/10)에서 더함 ----
    /// 깃발(nativeMoves) 켜짐에서 7호선 눈 승강장 구간(바깥 고가 승강장에서 싸우는 구간)을 쓸지. 기본 꺼짐 — 앱은 켠다.
    /// 꺼지면(또는 nativeMoves 가 꺼지면) 아무 뜻이 없다(웹 그대로)
    public var nativeSnow = false
    public init() {}
}

/// 판 시작 모드(N5)
public enum SimStartMode: String, Sendable { case subway, tower, bonus
    /// 무도장(웹 startDojo — 설정 > 바로 가기 · 콤보 실험실)
    case dojo }

/// 웹 GS.stats
public struct RunStats: Sendable, Equatable {
    public var dealt = 0.0, taken = 0.0
    public var crits = 0, counters = 0, outs = 0
    public var maxCombo = 0, links = 0, justs = 0, dodges = 0, perfectDodges = 0
    public var combos = 0, walls = 0, bowls = 0, stag = 0, flanks = 0, onTime = 0, late = 0, sigs = 0, throws_ = 0, chits = 0
    public var breaks = 0, bossScenes = 0, comboKills = 0, finPages = 0, footSet = 0
    /// 반응 분포(개발용 — 웹 GS.stats.rk)
    public var rk: [String: Int] = [:]
    /// 타격음 등급 분포(웹 GS.stats.snd)
    public var snd = [0, 0, 0]
    /// 타워: 부순 층 · 천장 튕기기(웹 GS.stats.wrecks · ceils)
    public var wrecks = 0, ceils = 0
    /// 공방 기록(docs/08 — 깃발 켜짐에서만 센다)
    public var nvg = NvGuardStats()
    public init() {}
}

/// 공방 기록(막기 · 가드 크래시 · 높이 바꾸기 · 끼어들기 · 동시 공격자)
public struct NvGuardStats: Sendable, Equatable {
    /// 적이 막음 · 주인공이 막음 · 앉아 막기가 상단을 흘림 · 쳐내기
    public var blocks = 0, heroBlocks = 0, whiffs = 0, parries = 0
    /// 적 가드 크래시 · 주인공 가드 크래시 · 가드 부수기 기술로 뚫음
    public var crashes = 0, heroCrashes = 0, pierces = 0
    /// 주인공이 막힌 뒤 높이를 바꿔 친 수 · 막힘 → 무너뜨림(높이 바꿔 맞힘 또는 크래시) 교환 수
    public var heightSwitches = 0, exchanges = 0
    /// 끼어들기 · 저스트 가드 · 페인트 · 도발 · 하단으로 서서 막기를 뚫음
    public var cutIns = 0, justGuards = 0, feints = 0, taunts = 0, lowBeats = 0
    /// 동시 공격자(공격 동작 중인 적 수 — 적이 있는 틱마다 더함) · 최댓값 · 공격권 넘김 수
    public var atkSum = 0.0, atkTicks = 0.0, atkMax = 0, grants = 0
    /// 공격 중인 틱 · 그중 둘 이상이 함께 공격한 틱(몰매 비율)
    public var atkBusy = 0.0, atkPile = 0.0
    /// 퇴근 승천권: 쓴 수 · 막기 되받아치기 · 대공 · 무적 칸에서 흘린 공격 · 지붕 뚫기
    public var rises = 0, riseReversals = 0, riseAntiAir = 0, riseInvuln = 0, roofBlasts = 0
    public init() {}
    public var avgAttackers: Double { atkTicks > 0 ? atkSum / atkTicks : 0 }
}

/// 열차(웹 TR)
struct TrainState {
    var v = 0.0, a = 0.0, ex = 0.0
    var phase = "stop"
    var t = 0.0, joint = 0.0
    var bumps: [Double] = []
    var jolt = 0.0, dy = 0.0, strap = 0.0, strapV = 0.0, door = 0.0
    var station = -1, stopAt = 0.0, flick = 0.0, flickS = 0.0
}

/// 바닥 물건(웹 GS.items: 고기 · 동전 · 서류)
struct FloorItem { var kind: String; var id: String?; var tier: Int?; var x: Double; var z: Double; var t = 0.0 }
/// 병 · 상자 투사체(웹 GS.shots)
struct Shot { var x: Double; var y: Double; var vx: Double; var t = 0.0; var friendly = false; var dead = false; var dodged = false; var ai = false
    /// 모양(네이티브 전용 — "" 병 · "news" 신문 뭉치: 신문팔이 소년)
    var kind = "" }
/// 바닥 캔(웹 GS.cans)
struct Can { var x: Double; var v = 0.0 }
/// 바닥 소품(웹 GS.props: 커피 웅덩이 · 짐 상자)
struct Prop { var k: String; var x: Double; var ice = false }

/// 실행 중 콤보 경로(웹 GS.croute)
final class ComboRun {
    var uids: [Int]
    var k: Int
    var key: String
    var name: String
    var mul: Double
    var t: Double
    weak var T: Actor?
    var hits = 0
    var chain: Int
    var fin = false, sig = false, branch = false
    var book: String?
    init(uids: [Int], k: Int, key: String, name: String, mul: Double, t: Double, T: Actor?, chain: Int) {
        self.uids = uids; self.k = k; self.key = key; self.name = name; self.mul = mul; self.t = t; self.T = T; self.chain = chain
    }
}

/// 컷인(웹 GS.cut) — pause 면 전투가 멈춘다
struct CutState { var k: String; var kind: String?; var boss: Actor?; var t = 0.0; var dur: Double; var pause = true }

/// 필살기 진행(웹 GS.spc)
final class SpecialRun {
    let kind: String
    var t = 0.0
    var hits: [ObjectIdentifier: Int] = [:], hl: [ObjectIdentifier: Double] = [:]
    var x0: Double, n = 0
    var dir = 1.0, x1 = 0.0
    var pole = 0.0
    var tgt: Actor?
    var sw: Int?, tk: Int?
    var carry: [Actor] = []
    var fin = false, finT: Double?
    var grab = false, lift = false, slam = false, dustT = 0.0
    /// 네이티브 막차 러시(World+NativeRush): 지금 박자 · 박자 안 단계 · 마무리 시작 시각
    var nvBeat = -1, nvStage = 0
    var nvFin0: Double?
    init(kind: String, x0: Double) { self.kind = kind; self.x0 = x0 }
}

/// 승객 이벤트(웹 GS.ev)
final class LegEventState {
    let k: String
    var t = 0.0
    let dur: Double
    var actors: [Actor] = []
    var heal = 0.0
    var lastCheer: Int?
    init(k: String, dur: Double) { self.k = k; self.dur = dur }
}

/// 조명 전환(웹 GS.trans)
struct LightTrans { var to: Bool; var t = 0.0; var switched = false }

/// 메타 기록 중 규칙이 읽거나 쓰는 부분(웹 META) — 저장은 BBPersistence 몫, 바뀌면 metaChanged 이벤트
public struct SimMeta: Sendable, Equatable {
    public var seenCut: Set<String> = []
    public var foes: [String: [Int]] = [:]      // [seen, ko]
    public var items: [String: Int] = [:]
    public var links: Set<String> = []
    public var hints: Set<String> = []
    public var talks: Set<String> = []
    public var spc: [String: Int] = [:]
    public var cbook: [String: [Int]] = [:]     // [n, best]
    public var combos: [String: [Int]] = [:]    // [n, best]
    public var bossScenes: [String: Int] = [:]
    public var lines: Set<Int> = []
    /// 엘리베이터 타워 기록(웹 META.tower) · 보너스 최고 점수(웹 META.bonusBest)
    public var tower = TowerMeta()
    public var bonusBest = 0
    // ---- K 에서 더함 ----
    /// 오늘의 노선 최고 점수(웹 META.daily — 날짜 열쇠) · 프롤로그에서 목격만 한 도감 콤보(웹 META.cseen) · 콤보 노트 이름(웹 META.combos[key].name)
    public var daily: [String: Int] = [:]
    public var cseen: Set<String> = []
    public var comboNames: [String: String] = [:]
    public init() {}
}

final class World {
    let data: SimData
    var config: SimConfig
    var rng: Mulberry32
    /// 픽스처 대조용: 정하면 모든 규칙 난수가 이 값(웹 Math.random 고정과 같게)
    var rndFixed: Double?
    /// 락스텝 대조용 규칙 난수 기록(프레임, 웹 함수 이름)
    var rtLog: [(Int, String)]?
    var frameNo = 0
    var events = EventBuffer<SimEvent>()
    var meta = SimMeta()
    /// 연출 전용 난수(타워 전등 흔들림 · 날아간 적 회전 · 보너스 연기 위치 등) — 규칙 수열과 따로라 락스텝에 영향이 없다
    var fxr: Mulberry32
    /// 픽스처 대조용: 정하면 연출 난수(fxRnd)가 이 값(웹 Math.random 고정과 같게 — 전등 흔들림 등)
    var fxFixed: Double?
    func fxRnd() -> Double { fxFixed ?? fxr.next() }
    /// 타워 판(웹 GS.tower) · 보너스 판(웹 GS.bonus) — 진행 중일 때만 있다(tower · bonus 깃발과 함께 바뀐다)
    var tw: TowerRun?
    var bn: BonusRun?
    lazy var twd = TowerData(data)

    // ---- 시간(웹 loop · 16-anim) ----
    let animFps = 20.0          // 게임 모드(48-input setMode('game') → animFps=20)
    var playSpeed: Double
    var paused = false
    /// 네이티브 잡기 2차 다듬기(벽꿍 · 무거운 호 · 회복 · 종착역 끌기 — World+NativeGrab). 깃발 켜짐에서만 읽는다 · 밸런스 비교 테스트만 끈다
    var nvGrabTune = true
    /// 밸런스 측정용 부분 끄기(벽꿍 · 회복) — 기본 켬
    var nvGrabWall = true, nvGrabRec = true
    var gameTime = 0.0, acc = 0.0, tick = 0
    var freeze = 0
    var realTime = 0.0
    var scheduled: [(at: Double, run: (World) -> Void)] = []

    // ---- 장면 · 노선(웹 STAGE · LINE · START_STOP · STOPS · CAMX) ----
    var stageIdx = 0
    var stage: StageDef { data.game.stages[stageIdx] }
    var line: [CarDef] { stage.line }
    var camX = 0.0
    var viewW: Double
    let W = 480.0, H = 270.0

    // ---- GS ----
    var on = false
    var state = "idle"
    var ci = 0, wave = 0
    var waveT = 0.0, nextWaveAt = 0.0, legT = 0.0
    var clearT: Double?
    var arriving = false
    var fade = 0.0
    var items: [FloorItem] = []
    var shots: [Shot] = []
    var cans: [Can] = []
    var props: [Prop] = []
    var hero: Actor!
    var ents: [Actor] = []
    var filler = 0
    var bag: [Item] = []
    var stash: [Item] = []
    var uid = 0
    var actorSeq = 0
    var tokens = 0
    var score = 0
    var kills = 0
    var hp = 100.0, maxHP = 100.0, lagH = 100.0
    var stats = RunStats()
    var time = 0.0
    var leg = 0, legStart = 0.0, qi = 0
    var boardT = 0.0
    var doorWant = false
    var nextStop: String?
    var atStop: String?
    var departT = 0.0
    var quickStop: [JSONValue]?
    var qDwell: Double?
    var boarded = false
    var prevEx: Double?
    var press = 0.0
    var expr = false, exprSaid = false
    var trans: LightTrans?
    var lightK = 1.0, emitK = 1.0
    var oneBit: Bool?
    var cut: CutState?
    var spc: SpecialRun?
    var sp = 0.0
    var shoveX = 0.0
    var mcd = 0.0, manualT = 0.0
    var flashT = 0.0
    var combo = 0
    var lastHit: Double?
    var comboDmg = 0
    var hurtAt: Double?
    var bossBreak: (a: Actor, t: Double, T0: Double)?
    var croute: ComboRun?
    /// 네이티브 직접 조작 패드(World+NativePad)
    var pad = NvPad()
    var comboCD = 0.0
    var comboUse: [String: Int] = [:]
    var lastCombo: String?
    var comboIdle = 0.0
    var curSrc: Int?
    var sets: [String: [Int]] = [:]
    var linkAt: [String: Double] = [:]
    var dodgeEmp = 0.0
    var engageT: Double?
    var flankT: Double?
    var justEarly: Double?
    var slowT = 0.0
    var spcTime = 1.0
    var spcRel: Double?
    var spcHitT = 0.0
    var camZ = 1.0
    var bagSlowT = 0.0
    /// 네이티브 KO 마무리(World+NativeKO — 깃발 켜짐에서만 읽는다): 웨이브마다 한 번 · 슬로 남은 실제 초(0.25배) · 무도장 시연 허용
    var nvKOArmed = true, nvKOT = 0.0, nvKODemo = false
    var ev: LegEventState?
    var pt: Double?          // 교행 열차 진행(웹 GS.pt.t)
    var ptT = 0.0
    var ptNext: Double?
    var envCD = 0.0
    var hangT2: Double?
    var hangX: Double?
    var poleT: Double?
    var chT: Double?
    var wait = 0.0
    var prevFoes = 0
    var idleT = 0.0
    var thought = false
    var equipHint: (uid: Int, t: Double)?
    var selUid: Int?
    var stationDone = -1
    var shopList: [(id: String, tier: Int, opt: ItemOption?)] = []
    var rerolls = 0
    var arrT = 0.0, arrTouched = false, arrOpen = false
    var trT = 0.0, trLoaded = false, trNext = 0
    var bonusDone = false
    var bonusSt: [Int: Bool] = [:]
    var daily = false
    var imprints: [String: String] = [:]
    /// 대화 대기열(웹 GS.talkSoon — 열쇠 · 도감 콤보 id) · 진행 중 대화(웹 GS.talk) · 대화 줄(웹 GS.talkQ) — World+Story
    var talkQueue: [(key: String, arg: String?)] = []
    var talkRun: TalkRun?
    var talkQ: [TalkRun] = []
    /// 마지막 도움말(웹 hint → say('도움말 · …') — 표현용)
    var lastHint: (key: String, at: Double)?
    var brakeGlow = 0.0
    var routeSetsCache: (time: Double, S: Set<Int>, M: Set<Int>)?
    var statsCache: [Int: BagRules.ItemStats] = [:]
    var setsVersion = 0, imprintsVersion = 0
    var contrib: [Int: (dmg: Double, n: Int)] = [:], contribRun: [Int: (dmg: Double, n: Int)] = [:]
    var lastSay: (String, String)?
    // 모드 갈고리(지금은 지하철 판만 — 타워 · 보너스 · 프롤로그 · 무도장은 다음 단계)
    var tower = false, bonus = false, demo = false, devRun = false
    // ---- K(프롤로그 · 스토리 · 무도장) — World+Prologue/Story/Dojo ----
    /// 웹 GS.prologue · GS.cine · GS.kane(진행 중일 때만)
    var pr: PrologueRun?
    var cn: CineRun?
    var kn: KaneRun?
    /// 웹 GS.pBag(보스의 가방 쇼 ~ 케인 장면) · GS.pKit(맡겨 둔 시작 가방)
    var pBag = false
    var pKit: [Item]?
    /// 웹 GS.tapW(콤보 쇼 '탭!' 창)
    var tapW: TapWindow?
    /// 네이티브 공방: 군중 공격권 · 끼어들기 · 주인공 가드 판단(World+NativeCrowd · NativeGuard)
    var nvc = NvCrowd()
    /// 퇴근 승천권: 마지막 지붕 뚫기 시각(8초 간격) · 막기 되받아치기를 이미 굴려 본 막기 시각(막기 한 번에 한 번)
    var nvRoofAt = -99.0, nvRiseRollAt = -99.0
    /// 네이티브 야근 광선(World+NativeBeam — 모음 · 발사 · 사라짐 동안만)
    var nvBeam: NvBeam?
    /// 네이티브 내선 연결: 전화선 · 수화기(World+NativeDial)
    var nvCord: NvCord?
    /// 내선 연결로 마지막에 끌려와 도착한 적 · 시각(패드 기본기 → 어퍼컷 창)
    var nvDialLast: (id: ActorID, t: Double)?
    /// 네이티브 눈 승강장 구간(World+NativeSnow — 깃발 꺼짐이면 늘 nil)
    var nvSnow: SnowLeg?
    /// 웹 무도장(GS.dojoSeq · DJ · GS.cc · GS.ccRes) · 스킨 미리보기(GS.skinPv)
    var dj: DojoState?
    var skinPv: SkinPv?
    /// 웹 scene('subway' · 프롤로그 거리 'brawl') · GS.cam(거리 카메라) · GS.camC(확대 중심, 표현용)
    var scene = "subway"
    var cam = 0.0
    var camC: SIMD2<Double>?
    lazy var sd = StoryData(data)

    // ---- 열차 ----
    var tr = TrainState()
    // ---- 교행 · 손잡이 ----
    var straps: [Int: (a: Double, v: Double, cd: Double)] = [:]

    init(data: SimData, seed: UInt32, config: SimConfig) {
        self.data = data.variant(nativeMoves: config.nativeMoves); self.config = config
        rng = Mulberry32(seed: Int32(bitPattern: seed))
        playSpeed = config.playSpeed
        viewW = config.viewWidth
        fxr = Mulberry32(seed: Int32(bitPattern: seed ^ 0x5bd1_e995))
        if let m0 = config.initialMeta { meta = m0 }
        meta.seenCut.formUnion(config.seenCuts)
        if config.traceRandom { rtLog = [] }
    }

    // MARK: 난수(웹 Math.random — 규칙 스트림)
    func rnd(_ site: String = #function) -> Double {
        if rtLog != nil { rtLog!.append((frameNo, World.siteName(site))) }
        return rndFixed ?? rng.next()
    }
    /// Math.floor(Math.random()*n)
    func rndInt(_ n: Int, _ site: String = #function) -> Int { Int((rnd(site) * Double(n)).rounded(.down)) }
    /// 락스텝 대조: Swift 함수 이름 → 웹 함수 이름(난수 자리)
    static func siteName(_ f: String) -> String {
        let n = String(f.prefix { $0 != "(" })
        switch n { case "randomSort": return "boardAt"; case "spot": return "propsInit"; default: return n }
    }

    // MARK: 이벤트
    @inline(__always) func emit(_ e: SimEvent) { events.emit(e) }
    /// 웹 say(제목, 본문, 초) — 안내 상자
    func say(_ title: String, _ body: String, _ sec: Double) { lastSay = (title, body); emit(.notice(title: title, body: body, seconds: sec)) }
    func sfx(_ id: String, _ v: Double = 0) { emit(.sfx(id: id, value: v)) }
    func fx(_ kind: String, _ x: Double, _ y: Double, _ dir: Double = 0) { emit(.fx(kind: kind, x: x, y: y, dir: dir)) }
    /// force = 웹 `comicT=0; comicSFX(…)`(간격 무시) — comicReset 을 먼저 낸다
    func comicSFX(_ x: Double, _ y: Double, _ word: String, force: Bool = false) { if force { emit(.comicReset) }; emit(.comicWord(word: word, x: x, y: y)) }
    /// 값이 더 필요한 HITFX(웹 HITFX.push) — 표현 몫
    func fxD(_ d: FxDetail) { emit(.fxDetail(d)) }
    func comicSay(_ a: Actor?, _ text: String, _ kind: String = "speech") { if let a { emit(.speech(actor: a.id, text: text, kind: kind)) } }
    func flashText(_ text: String, _ t: Double) { flashT = t; emit(.statusFlash(text: text, seconds: t)) }
    func shake(_ amp: Double) { var k = CameraKick(); k.shake = amp; emit(.camera(k)) }
    /// 웹 hint(k): 처음 한 번 — 컷 · 보너스 · 보스의 가방 쇼 · 케인 장면 동안엔 미룬다(기록하지 않고 false)
    @discardableResult
    func hint(_ k: String) -> Bool {
        guard !meta.hints.contains(k), data.hints.contains(k), !cine, !bonus, !pBag, !kane else { return false }
        meta.hints.insert(k); emit(.hint(key: k)); emit(.metaChanged)
        // 웹은 0.4초 뒤 say('도움말 · '+제목, 본문, 4.2) — 앱은 hint 이벤트로 도움말 카드를 띄우므로 안내(notice)는 따로 내지 않고 스냅숏 hint 로만 남긴다
        if sd.hints[k] != nil { schedule(after: 0.4) { w in w.lastHint = (k, w.realTime) } }
        return true
    }
    /// 웹 setTimeout(fn, ms) — 규칙 시계(실제 경과 시간) 기준 예약
    func schedule(after sec: Double, _ run: @escaping (World) -> Void) { scheduled.append((realTime + sec, run)) }

    // MARK: 웹 공용 작은 함수
    /// 웹 BF(n): 12fps 칸 수 → 지금 animFps 칸 수
    func BF(_ n: Double) -> Int { n <= 0 ? 0 : max(1, Int(jsRound(n * animFps / 12))) }
    var Gstop: Double { Double(data.grammar["stop"] ?? 4) }
    /// 웹 foes()
    func foes() -> [Actor] { ents.filter { $0.e != nil && !$0.dead } }
    /// 웹 ACT(): 애니메이션을 돌리는 인물들
    func animActors() -> [Actor] { ents }
    func item(_ id: String) -> ItemDef? { data.item(id) }
    var car: CarConcept { data.cars[line[min(ci, line.count - 1)].car] }
    /// 웹 AW0/AW1: 싸울 수 있는 좌우 끝(타워는 칸 벽)
    func AW0() -> Double { tower ? TWR.L + 8 : 14 }
    func AW1() -> Double { tower ? TWR.R - 8 : data.sbW - 14 }
    func newActorID() -> ActorID { actorSeq += 1; return actorSeq }
}

// MARK: JS 수 규칙
@inline(__always) func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
@inline(__always) func jsRoundI(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }
@inline(__always) func jsSign(_ x: Double) -> Double { x > 0 ? 1 : x < 0 ? -1 : 0 }
@inline(__always) func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, x)) }
