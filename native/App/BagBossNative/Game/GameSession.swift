import Foundation
import QuartzCore
import Observation
import UIKit
import BBCore
import BBContent
import BBAnim
import BBSim
import BBPresentation
import BBRender
import BBAudio
import BBHaptics
import BBPersistence
import BBUI

// 게임 한 판의 조립 지점(앱 쪽): 시뮬레이션 · 연출 감독 · 소리 · 진동 · 저장 · 가방 편집기를 한 화면 프레임 루프로 묶는다.
//   화면 프레임(MTKView draw) → GameLoopClock 이 고정 60Hz 틱 수를 정함 → Sim.step(의도) × n → 이벤트 모음
//   → StageDirector.apply(이벤트) → 소리 · 진동 · 저장 · 흐름 화면 → StageDirector.frame(스냅숏) → RenderFrame
// 화면(UIKit · SwiftUI)은 의도를 큐에 넣기만 한다 — 다음 틱에 시뮬레이션이 처리한다(docs/06 §2.1).
//
// 메타(웹 META) 흐름:
//   판 시작 — 저장 MetaState → SimConfig.initialMeta(SaveBridge.initialMeta)
//   metaChanged · towerEnded · bonusEnded · runEnded — Sim.meta 를 저장 메타에 단조 합치기(MetaRules.merge)
//   2초마다(웹 metaTick) — 누계(tot) 증가분 · 들른 역 · 시작 가방 해금
//   판 끝(지하철) — runs · best.score · 오늘의 노선 점수(웹 showResult)

/// 흐름 화면
enum GameScreen: Equatable { case title, playing }

/// 메뉴 탭(웹 openMenu tabs)
enum MenuTab: String, CaseIterable, Hashable { case run, daily, tower, codex, sound }
/// 도감 탭(웹 codexHTML tabs)
enum CodexTab: String, CaseIterable, Hashable { case foe, stn, item, link, cmb, spc, rec }

/// 새 판 요청(웹 RUNCFG + startTower opts)
struct RunRequest: Equatable {
    enum Mode: Equatable { case subway, tower, dojo }
    var mode: Mode = .subway
    var kit = "basic", stage = 0, daily = false, ot = 0
    /// 무도장 · 스킨 미리보기: 이 판만 입혀 볼 스킨(nil = 설정 스킨 — Features/FeatureHub)
    var skin: String? = nil
}

/// 결과 신문(웹 showResult 값 — 문구는 ResultViews 의 newsCopy)
struct NewsInfo: Equatable {
    var win: Bool
    var score: Int, kills: Int
    var stats: RunStats
    var stageIdx: Int, ci: Int
    var daily: Bool
    var newBest: Bool
    var unlocks: [String]
    var date = Date()
}

enum FlowResult: Equatable { case news(NewsInfo), tower(TowerResult) }

/// 확인 창(판 버리기)
enum ConfirmKind: Equatable {
    /// 이어 하기 저장(또는 진행 중인 판)을 버리고 새로 시작
    case replace(RunRequest)
    /// 진행 중인 판 포기(기록 없이 타이틀로)
    case abandon
}

/// 보너스 결산판(웹 drawBonusResult — owner 단계)
struct BonusBoard: Equatable { var result: BonusResult; var pt: Double; var skippable: Bool }

struct PerfStats: Equatable {
    var fps = 0.0, simMs = 0.0, frameMs = 0.0, gpuMs = 0.0, ticks = 0, actors = 0, particles = 0
}

/// 게임 설정(메뉴 '설정' 탭) — 저장: 소리 'dotlab-snd' · 옵션 'dotlab-opt'(autoSpc · shortCut · noFlash · vibe) ·
/// 언어 'dotlab-lang' · 네이티브 전용 'bbn-motion'(동작 강화) · 'bbn-sfx-sample'(녹음 타격음) · 'bbn-hurtk'(피격 진동 세기) · 'bbn-calm'(화면 흔들림 줄이기) ·
/// 개발자 'bbn-dev'(설정에 개발자 칸 보이기) · 'bbn-dev-perf'(성능 줄) · 'bbn-dev-badge'(AUTO 배지) · 'bbn-dev-tabs'(점검 탭) ·
/// 'bbn-pad'(직접 조작 패드 — "0" 이면 끔) · 'bbn-pad-left'(왼손 배치 "1") ·
/// 'bbn-layout'(게임 화면 배치 — "old" 면 예전 배치, 없거나 그 밖이면 새 배치 · docs/09)
struct GameSettings: Equatable {
    var master = 0.8, music = 0.55, sfx = 0.8
    var muted = false
    var vibration = true
    var hurtScale = 1.0
    var motionEnhance = true
    /// 녹음 타격음 겹치기(네이티브 · docs/11) — 'bbn-sfx-sample'("0" 이면 끔). 끄면 웹 합성 타격음 그대로
    var sampleHits = true
    var autoSpc = false, shortCut = true, noFlash = false
    /// 주인공 스킨(웹 OPT.skin — 유료 판매 대상, 지금은 시험으로 모두 고를 수 있다)
    var skin = "jw"
    /// 프롤로그(지하 복도 · 보스의 가방 — 웹 OPT.prologue, 기본 켬)
    var prologue = true
    /// 화면 흔들림 줄이기(흔들림 · 줌 펀치 약하게 + 번쩍임 끔). 저장값이 없으면 기기 '동작 줄이기'를 따른다
    var calm = false
    /// 개발자 칸(설정 › 버전 7번 누르기) · 성능 줄 · AUTO 배지 · 점검 탭 — 모두 기본 끔
    var devUnlocked = false, devPerf = false, devBadge = false, devTabs = false
    /// 게임 화면 새 배치(무대 우선 + 바텀시트 가방 · docs/09). 끄면 예전 배치(무대 4:3 · 행동 줄 · 가방 패널) — 비교용
    var layoutNew = true
    /// 직접 조작 패드(전투 중 접힌 시트 = ◀ ▶ · 숙이기 · 기술 버튼 — 'bbn-pad' "0" 이면 끔 → 콤보 카드 띠) · 왼손 배치('bbn-pad-left' "1")
    var padOn = true, padLefty = false
}

/// 엿보기 줄 글(지금 콤보 경로 — BagController 가 채운다)
struct PeekInfo: Equatable {
    var name = "", step = 0, count = 0, next = "", routes = 0
    /// 판에서 실제로 도는 중(아니면 가방 첫 경로를 미리 보여 준다)
    var live = false
}

@MainActor @Observable
final class GameSession {
    // ---- 정적 데이터 ----
    @ObservationIgnored let store: ContentStore
    @ObservationIgnored let data: SimData
    @ObservationIgnored let atlas: AtlasMeta
    @ObservationIgnored let sceneContent: SceneContent
    @ObservationIgnored let director: StageDirector
    @ObservationIgnored let carFlags: [(flicker: Bool, key: String)]
    @ObservationIgnored let content: FlowContent

    // ---- 판 ----
    @ObservationIgnored private(set) var sim: Sim?
    @ObservationIgnored private(set) var snapshot = SimSnapshot()
    @ObservationIgnored private var pending: [SimIntent] = []
    @ObservationIgnored private var clock = GameLoopClock()
    @ObservationIgnored private var startMedia = CACurrentMediaTime()
    @ObservationIgnored private(set) var lastRenderFrame: RenderFrame?

    // ---- 바깥 장치 ----
    @ObservationIgnored let audio: AudioEngine
    @ObservationIgnored private var haptics = HapticPlanner()
    #if os(iOS)
    @ObservationIgnored private let hapticPlayer = HapticPlayer()
    #endif
    @ObservationIgnored let save: SaveStore?
    @ObservationIgnored let bag: BagController

    // ---- 준비(GameAssets — docs/06 §8 성능) ----
    /// 판을 그릴 GPU 자원(뒤 스레드에서 굽는다). 준비 전에는 nil — 타이틀 · 메뉴는 이미 쓸 수 있다
    @ObservationIgnored private(set) var render: GameRender?
    /// 출발 가능(render 준비 끝). 준비 전에 들어온 출발 요청은 붙잡아 두었다가 준비되면 바로 시작한다
    var assetsReady = false
    @ObservationIgnored private var pendingStart: (() -> Void)?

    /// GameRootView 가 GameAssets.render 를 받으면 부른다
    func attach(render r: GameRender) {
        guard render == nil else { return }
        render = r
        director.hud.art = r.art
        assetsReady = true
        BootTrace.mark("출발 가능")
        if let p = pendingStart { pendingStart = nil; p() }
    }

    /// 준비 전이면 f 를 붙잡아 두고 true(호출자는 그냥 돌아간다)
    private func deferUntilReady(_ f: @escaping () -> Void) -> Bool {
        guard !assetsReady else { return false }
        pendingStart = f
        BootTrace.mark("출발 요청 — 준비 기다림")
        return true
    }

    // ---- 화면이 보는 값(Observable) ----
    var screen: GameScreen = .title
    var hud = HUDState()
    var view = StageView()
    /// 판 상태(웹 GS.state) — 흐름 화면(매점 · 정리 · 환승 · 결과)을 고른다
    var phase = "idle"
    var shopCards: [SimSnapshot.ShopCardView] = []
    var tokens = 0
    var arrangeLeft = 0
    /// 정리 타이머 멈춤(웹 arrTouched — 가방을 만지면 자동 출발이 멈춘다)
    var arrangeHeld = false
    var transferTo = 0
    var paused = false
    var speed = 1.25
    var settings = GameSettings()
    /// 새 배치: 가방 시트 펼침(정리 중 — 전투면 시간이 느려진다) · 점수 · 정리 슬로 중 · 모드 HUD 없음 · 엿보기 줄
    var bagOpen = false
    var score = 0
    var slowed = false
    var hudPlain = true
    var peek = PeekInfo()
    /// 직접 조작 패드 보기(SimSnapshot.pad — 쿨타임은 1/30 단위로 끊어 바뀐 것만 내보낸다)
    var pad = SimSnapshot.PadView()
    /// 판이 패드 보기를 낸다(네이티브 판 — 화면 갱신용으로 관찰되는 값)
    var padLive = false
    /// 정리 단계가 시트를 연 것(나가면 닫는다)
    @ObservationIgnored private var bagAutoOpened = false
    @ObservationIgnored private var lastOpenTouch = 0.0
    var perf = PerfStats()
    var lastError: String?
    // 흐름(N5 L)
    /// 열린 메뉴 탭(nil = 닫힘). 판 중에 열면 일시정지 메뉴
    var menuTab: MenuTab?
    var codexTab: CodexTab = .foe
    var result: FlowResult?
    var newsPhoto: UIImage?
    var bonusBoard: BonusBoard?
    var confirm: ConfirmKind?
    /// 대화 상자(SimSnapshot.talk) · 글자 찍기
    var talk: TalkView?
    @ObservationIgnored let typer = TalkTyper()
    var hintCard: HintCard?
    /// 무도장 진행(SimSnapshot.dojo)
    var dojoView: DojoView?
    /// 저장 메타 사본(메뉴 · 도감 · 결과가 읽는다)
    var meta = MetaState()
    /// 이어 하기 저장(타이틀 버튼 글)
    var runSave: RunSave?
    var hasSave: Bool { runSave != nil }
    /// 새 판 설정(웹 RUNCFG) · 타워 야근 단계(웹 OPT.twOT)
    var runKit = "basic"
    var runStage = 0
    var towerOT = 0
    var lang = "ko"
    /// 개발: 모든 노선 고르기(기록은 바꾸지 않는다 — 웹 OPT.devLines)
    var devLines = false
    /// 개발: 예시 메타(-samplemeta)를 쓰는 동안 메타를 저장하지 않는다
    @ObservationIgnored var debugNoSave = false
    /// 지금 판(다시 하기용)
    @ObservationIgnored private(set) var current = RunRequest()

    // 메타 진행
    @ObservationIgnored private var tallySnap: [String: Int] = [:]
    @ObservationIgnored private var lastMetaTick = 0.0
    @ObservationIgnored private var runMerges = 0
    @ObservationIgnored private var newUnlocks: [String] = []
    @ObservationIgnored private var photoCap: NewsPhotoCapture?
    /// 오늘의 타워 조건 미리 보기(날짜 열쇠 → 조건 id)
    @ObservationIgnored private var dailyTowerMods: (String, [String])?

    static let speedCycle: [Double] = [1.25, 1.5, 2, 1]   // 웹 SPD_CYCLE
    #if DEBUG
    /// 실행 인자 -perflog: 0.5초마다 성능 값을 콘솔에(docs/06 §8 성능)
    static let perfLog = ProcessInfo.processInfo.arguments.contains("-perflog")
    #endif

    // 성능 측정
    @ObservationIgnored private var perfAcc = (frames: 0, sim: 0.0, frame: 0.0, ticks: 0, t0: CACurrentMediaTime())
    @ObservationIgnored var lastGPUms = 0.0

    /// 무거운 데이터는 GameAssets 가 뒤 스레드에서 미리 만든 것(core)을 받는다 — 여기는 저장 읽기 · 소리 · 가방만(docs/06 §8 성능)
    init(core: GameCore) {
        store = core.store; data = core.data; atlas = core.atlas; sceneContent = core.sceneContent
        director = core.director
        carFlags = sceneContent.cars.map { ($0.broken == true || $0.works == true, $0.key) }
        content = core.flow
        save = BootTrace.measure("SaveStore") { try? SaveStore() }
        audio = BootTrace.measure("AudioEngine") { AudioEngine(content: core.store) }
        bag = BootTrace.measure("BagController") { BagController(catalog: core.data.catalog) }
        if let save {
            let snd = save.sound()
            settings.master = snd.vol.master; settings.music = snd.vol.music; settings.sfx = snd.vol.sfx; settings.muted = snd.muted
            let o = save.options()
            settings.vibration = o.vibe ?? true
            settings.autoSpc = o.autoSpc; settings.shortCut = o.shortCut; settings.noFlash = o.noFlash
            settings.skin = o.skin ?? "jw"
            settings.prologue = o.extras["prologue"].map { $0 != .bool(false) } ?? true
            towerOT = o.extras["twOT"]?.intValue ?? 0
            settings.motionEnhance = save.string(forKey: "bbn-motion") != "0"
            settings.sampleHits = save.string(forKey: "bbn-sfx-sample") != "0"
            settings.hurtScale = save.string(forKey: "bbn-hurtk").flatMap(Double.init) ?? 1
            settings.calm = save.string(forKey: "bbn-calm").map { $0 == "1" } ?? UIAccessibility.isReduceMotionEnabled
            settings.devUnlocked = save.string(forKey: "bbn-dev") == "1"
            settings.devPerf = save.string(forKey: "bbn-dev-perf") == "1"
            settings.devBadge = save.string(forKey: "bbn-dev-badge") == "1"
            settings.devTabs = save.string(forKey: "bbn-dev-tabs") == "1"
            settings.layoutNew = save.string(forKey: "bbn-layout") != "old"
            settings.padOn = save.string(forKey: "bbn-pad") != "0"
            settings.padLefty = save.string(forKey: "bbn-pad-left") == "1"
            lang = save.language().rawValue
            meta = save.meta()
            runSave = save.runSave()
            if let c = runSave?.cfg { runKit = c.kit; runStage = c.stage }
        }
        L10n.lang = lang
        audio.settings = AudioBridge.settings(soundOptions(), sampleHits: settings.sampleHits)
        applyDeviceSettings()
        bag.session = self
        audio.onInterruptionBegan = { [weak self] in self?.willResignActive() }   // 전화 · 알람: 판을 멈추고 일시정지 메뉴(저절로 이어 하지 않는다)
        do { let a = audio; try BootTrace.measure("audio.start") { try a.start() } } catch { lastError = "소리 시작 실패: \(error)" }
        #if DEBUG
        print("[game] 준비 완료 · 소리 \(audio.isRunning ? "켜짐" : "꺼짐") · 저장 \(save != nil ? "있음" : "없음") · 이어 하기 \(hasSave)")
        #endif
        FeatureHub.shared.boot(self)   // 2단계 A(Features/): 스킨 해금 캐시 · StoreKit · Game Center — 비동기, 판 시작을 막지 않는다
    }

    private func soundOptions() -> SoundOptions {
        var s = save?.sound() ?? SoundOptions()
        s.vol.master = settings.master; s.vol.music = settings.music; s.vol.sfx = settings.sfx; s.muted = settings.muted
        return s
    }
    private func applyDeviceSettings() {
        haptics.settings.enabled = settings.vibration
        haptics.settings.heroHurtScale = settings.hurtScale
        director.characters.style = settings.motionEnhance ? .on : .off
        director.sound.hitDetail = settings.sampleHits   // 녹음 타격음: hit3 에 동작 · 카운터를 싣는다(끄면 이름표가 웹 그대로)
        director.camera.noFlash = settings.noFlash || settings.calm
        director.camera.motionScale = settings.calm ? 0.3 : 1
        director.hud.noFlash = settings.noFlash || settings.calm   // HUD 섬광 · 충격파도(웹 OPT.noFlash 와 같은 자리)
        director.hud.modeBadge = settings.devBadge
        director.characters.heroSkin = settings.skin
    }

    // MARK: 흐름

    private func baseConfig() -> SimConfig {
        var c = SimConfig()
        c.dateKey = DailyKey.today()
        c.initialMeta = SaveBridge.initialMeta(meta)
        c.seenCuts = Set((meta.seenCut ?? [:]).keys)
        c.autoSpecial = settings.autoSpc; c.shortCut = settings.shortCut
        c.skipTalks = false   // 대화 상자를 띄운다(대화 중엔 판이 멈춘다 — SimSnapshot.talk)
        c.skin = settings.skin
        c.nativeMoves = true   // 네이티브 동작 개편(이동 판단 · 뎀프시 러시 · 복싱 기술) — docs/06 §8
        c.nativeSnow = true    // 네이티브 눈 승강장(7호선 46번가 고가 승강장 구간) — docs/10
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-skiptalks") { c.skipTalks = true }
        #endif
        return c
    }

    /// 새 판을 요청 — 이어 하기 저장이나 진행 중인 판이 있으면 먼저 확인(웹은 타이틀에서 새로 출발하면 저장을 지운다)
    func request(_ r: RunRequest) {
        let live = sim != nil && phase != "over" && screen == .playing
        if r.mode == .subway && (hasSave || live) { confirm = .replace(r); return }
        if r.mode == .tower && live { confirm = .replace(r); return }
        begin(r)
    }

    /// 확인 없이 바로 시작
    func begin(_ r: RunRequest, seed: UInt32 = UInt32.random(in: 1...UInt32.max)) {
        confirm = nil; menuTab = nil
        if deferUntilReady({ [weak self] in self?.begin(r, seed: seed) }) { return }
        BootTrace.reset("첫 판 프레임"); BootTrace.mark("판 시작")
        switch r.mode {
        case .subway:
            var c = baseConfig(); c.kit = r.kit; c.stage = r.stage; c.daily = r.daily
            c.prologue = settings.prologue   // 웹 OPT.prologue !== false(시뮬레이션이 첫 노선 · 오늘의 판 아님 · 이어 하기 아님일 때만 연다)
            current = r
            start(Sim(data: data, seed: seed, config: c))
            save?.clearRunSave(); runSave = nil
        case .dojo:
            // 콤보 연구실(웹 jumpTo('dojo') — 이어 하기 저장은 건드리지 않는다. 나가면 타이틀)
            var c = baseConfig(); c.mode = .dojo; c.kit = runKit; c.skipTalks = true
            if let k = r.skin { c.skin = k }
            current = r
            start(Sim(data: data, seed: seed, config: c))
        case .tower:
            var c = baseConfig(); c.mode = .tower; c.daily = r.daily; c.kit = runKit; c.towerOT = r.daily ? 0 : r.ot
            current = r
            start(Sim(data: data, seed: seed, config: c))   // 타워는 본편 이어 하기 저장을 건드리지 않는다(웹과 같게)
        }
        audio.play(.chime)
    }

    func newRun(seed: UInt32 = UInt32.random(in: 1...UInt32.max)) { begin(RunRequest(kit: runKit, stage: runStage), seed: seed) }
    func newTower(daily: Bool) { begin(RunRequest(mode: .tower, daily: daily, ot: towerOT)) }
    /// 결과 화면 '다시 하기'
    func again() { begin(current) }

    func continueRun() {
        if deferUntilReady({ [weak self] in self?.continueRun() }) { return }
        BootTrace.reset("첫 판 프레임"); BootTrace.mark("판 시작(이어 하기)")
        guard let r = runSave ?? save?.runSave() else { newRun(); return }
        let (c0, res) = SaveBridge.resume(r)
        var c = baseConfig(); c.kit = c0.kit; c.stage = c0.stage; c.daily = c0.daily
        current = RunRequest(kit: c.kit, stage: c.stage, daily: c.daily)
        let s = Sim(data: data, seed: UInt32.random(in: 1...UInt32.max), config: c)
        s.resume(res)
        start(s)
        audio.play(.chime)
    }

    private func start(_ s: Sim) {
        sim = s; pending = []; result = nil; newsPhoto = nil; bonusBoard = nil; talk = nil; hintCard = nil; paused = false; speed = s.config.playSpeed
        bagOpen = false; bagAutoOpened = false
        director.hud.reset(); director.fx.clear(); director.characters.reset(); director.camera = CameraDirector(); director.eye = EyeAdaptState()
        applyDeviceSettings()   // 새 카메라에 섬광 · 흔들림 설정 다시
        director.playSpeed = speed
        clock.resync()
        snapshot = s.snapshot
        #if DEBUG
        debugTalkView = nil
        #endif
        tallySnap = [:]; runMerges = 0; newUnlocks = []; lastMetaTick = 0
        bag.sync(snapshot, force: true)
        screen = .playing
        audio.restartIfNeeded()
    }

    /// 타이틀로(진행 중인 지하철 판은 이어 하기로 저장)
    func toTitle(openMenu tab: MenuTab? = nil) {
        if let s = sim { metaTick(force: true); persistRun(s) }
        save?.flush()
        sim = nil; screen = .title; paused = false; result = nil; newsPhoto = nil; bonusBoard = nil; talk = nil; typer.sync(nil); hintCard = nil; dojoView = nil; phase = "idle"
        confirm = nil; menuTab = tab
        audio.setMusic(.off); audio.silenceAmbience()
    }

    /// 판 포기(기록 · 이어 하기 없이 타이틀로) — 누계는 이미 더해졌다
    func abandonRun() {
        if sim != nil { metaTick(force: true) }
        if current.mode == .subway { save?.clearRunSave(); runSave = nil }
        sim = nil
        toTitle()
    }

    private func persistRun(_ s: Sim) {
        guard s.state != "over", s.config.mode == .subway else { return }
        let r = SaveBridge.runSave(snapshot, config: s.config, catalog: data.catalog)
        save?.setRunSave(r); runSave = r
    }

    private func storeMeta(_ M: MetaState) {
        if !debugNoSave { save?.setMeta(M) }
    }

    // MARK: 메뉴 · 설정

    func openMenu(_ tab: MenuTab = .run) {
        if screen == .playing && sim != nil && phase != "over" { setPaused(true) }
        menuTab = tab
        audio.play(.click)
    }
    /// 메뉴 닫기: 판 중이면 이어서, 타이틀이면 타이틀로
    func closeMenu() {
        menuTab = nil
        if screen == .playing && sim != nil { setPaused(false) }
    }

    func setTowerOT(_ l: Int) {
        towerOT = l
        if var o = save?.options() { o.extras["twOT"] = .number(Double(l)); save?.setOptions(o) }
    }

    func setLanguage(_ l: String) {
        guard l != lang else { return }
        lang = l; L10n.lang = l
        save?.setLanguage(Language(rawValue: l))
    }

    func resetHints() {
        meta.resetHints(); storeMeta(meta)
    }

    /// 오늘의 타워 조건(웹 twDaily(dk).mods) — 시뮬레이션의 실제 계산을 쓰려고 빈 타워 판을 하나 만들어 스냅숏에서 읽는다(날짜당 한 번)
    func dailyTowerModIDs() -> [String] {
        let dk = DailyKey.today()
        if let d = dailyTowerMods, d.0 == dk { return d.1 }
        var c = SimConfig(); c.mode = .tower; c.daily = true; c.dateKey = dk; c.skipTalks = true
        let ids = Sim(data: data, seed: 1, config: c).snapshot.tower?.mods ?? []
        dailyTowerMods = (dk, ids)
        return ids
    }

    // MARK: 콤보 연구실(무도장)

    /// 무도장 열기 — route 가 있으면 그 순서로 시연(웹 cb-demo: punch 는 0~3 칸을 돌려 쓴다)
    func openDojo(route: [String]? = nil, skin: String? = nil) {
        let fromRun = sim != nil && current.mode == .subway && phase != "over"
        if current.mode != .dojo || sim == nil { FeatureHub.shared.noteDojoEntry(fromRun: fromRun, menu: menuTab) }   // 나가면 되돌아갈 곳
        if fromRun { metaTick(); if let s = sim { persistRun(s) } }
        begin(RunRequest(mode: .dojo, skin: skin))
        guard let route else { return }
        var pc = 0
        let steps = route.map { id -> String in if id == "punch" { defer { pc += 1 }; return "punch:\(pc % 4)" }; return id }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            self?.enqueue(.dojo(.setCustom(steps))); self?.enqueue(.dojo(.customRun))
        }
    }
    func dojo(_ c: DojoCommand) { enqueue(.dojo(c)); audio.play(.click) }

    // MARK: 의도(화면 → 큐)

    func enqueue(_ i: SimIntent) { pending.append(i) }

    /// 무대 터치: 위치(뷰 안 0..1) · 터치 시각(미디어 시계)
    func stageTouch(_ p: SIMD2<Double>, timestamp: Double) {
        guard sim != nil, !paused else { return }
        if talk != nil { talkTap(); return }   // 대화 중: 무대 탭도 대화 넘기기(웹 tkBox 클릭)
        if let b = bonusBoard, b.skippable { enqueue(.advance); return }   // 보너스 결산: 탭으로 넘기기(웹 pt > 2.4)
        let at = InputMapper.simTime(touch: timestamp, frameMedia: clock.frameMedia, frameSimClock: clock.frameSimClock)
        if padActive {   // 직접 조작 패드: 무대 탭은 공격하지 않는다 — 시작기 '탭!' 창 · 거리 연출 넘기기만
            enqueue(snapshot.cine != nil ? .tap(side: 1, at: at) : .tapWindow(at: at)); return
        }
        enqueue(InputMapper.intent(at: p, simTime: at))
    }

    /// 패드를 쓰는 중인가(새 배치 · 설정 켬 · 네이티브 패드 보기가 있음)
    var padActive: Bool { settings.layoutNew && settings.padOn && padLive }

    /// 패드 입력(누르는 순간) — 터치 시각은 지금(미디어 시계)으로. 기술 · 기본기 · 숙이기는 가벼운 진동
    func padInput(_ p: PadInput, feedback: Bool = true) {
        guard sim != nil, !paused else { return }
        let at = InputMapper.simTime(touch: CACurrentMediaTime(), frameMedia: clock.frameMedia, frameSimClock: clock.frameSimClock)
        enqueue(.pad(p, at: at))
        #if os(iOS)
        if feedback && settings.vibration { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5) }
        #endif
    }

    func cycleSpeed() {
        let i = Self.speedCycle.firstIndex(of: speed) ?? -1
        speed = Self.speedCycle[(i + 1) % Self.speedCycle.count]
        director.playSpeed = speed
        enqueue(.setSpeed(speed))
        audio.play(.click)
    }

    func special() { enqueue(.special) }

    /// 새 배치: 가방 시트 펼치기 · 접기
    func setBagOpen(_ open: Bool) {
        guard bagOpen != open else { return }
        bagOpen = open
        if !open { bagAutoOpened = false }
        else if snapshot.inCombat && snapshot.state != "arrange" { lastOpenTouch = CACurrentMediaTime(); enqueue(.bagTouch) }   // 펼치는 순간부터 느리게
    }

    /// 도트 단추 피드백(PixelButton): 딸깍(소리 켜짐) · 가벼운 진동(진동 켜짐)
    func buttonFeedback(sound: Bool) {
        if sound { audio.play(.click) }
        #if os(iOS)
        if settings.vibration { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }
        #endif
    }

    func setPaused(_ p: Bool) {
        guard sim != nil else { return }
        paused = p
        if !p { clock.resync(); audio.restartIfNeeded() }
        if p { if let s = sim { metaTick(force: true); persistRun(s) }; save?.flush() }
    }

    func applySettings() {
        if save?.string(forKey: "bbn-layout") != nil || !settings.layoutNew { save?.setString(settings.layoutNew ? "new" : "old", forKey: "bbn-layout") }
        audio.settings = AudioBridge.settings(soundOptions(), sampleHits: settings.sampleHits)
        save?.setSound(soundOptions())
        if var o = save?.options() {
            o.vibe = settings.vibration; o.autoSpc = settings.autoSpc; o.shortCut = settings.shortCut; o.noFlash = settings.noFlash
            if settings.skin != "jw" || o.skin != nil { o.skin = settings.skin }
            if !settings.prologue || o.extras["prologue"] != nil { o.extras["prologue"] = .bool(settings.prologue) }
            save?.setOptions(o)
        }
        applyDeviceSettings()
        save?.setString(settings.motionEnhance ? "1" : "0", forKey: "bbn-motion")
        if !settings.sampleHits || save?.string(forKey: "bbn-sfx-sample") != nil { save?.setString(settings.sampleHits ? "1" : "0", forKey: "bbn-sfx-sample") }
        save?.setString(String(settings.hurtScale), forKey: "bbn-hurtk")
        if !settings.padOn || save?.string(forKey: "bbn-pad") != nil { save?.setString(settings.padOn ? "1" : "0", forKey: "bbn-pad") }
        if settings.padLefty || save?.string(forKey: "bbn-pad-left") != nil { save?.setString(settings.padLefty ? "1" : "0", forKey: "bbn-pad-left") }
        // 흔들림 줄이기: 기기 '동작 줄이기'에서 온 기본값은 고르기 전까지 저장하지 않는다(나중에 기기 설정을 바꿔도 따라가게)
        if save?.string(forKey: "bbn-calm") != nil || settings.calm != UIAccessibility.isReduceMotionEnabled {
            save?.setString(settings.calm ? "1" : "0", forKey: "bbn-calm")
        }
        for (k, v) in [("bbn-dev", settings.devUnlocked), ("bbn-dev-perf", settings.devPerf), ("bbn-dev-badge", settings.devBadge), ("bbn-dev-tabs", settings.devTabs)]
            where v || save?.string(forKey: k) != nil {
            save?.setString(v ? "1" : "0", forKey: k)
        }
    }

    /// 앱이 백그라운드로: 멈추고 저장 — 돌아와도 일시정지 메뉴 그대로(저절로 이어 하지 않는다)
    func didEnterBackground() {
        if sim != nil && screen == .playing && phase != "over" { paused = true; if menuTab == nil { menuTab = .run } }
        if let s = sim { metaTick(force: true); persistRun(s) }
        save?.flush()
        audio.stop()
    }
    /// 잠깐 가려짐(제어 센터 · 전화 · 소리 중단): 멈추고 일시정지 메뉴
    func willResignActive() {
        if sim != nil && screen == .playing && phase != "over" && !paused { setPaused(true); if menuTab == nil { menuTab = .run } }
    }
    func willEnterForeground() { audio.restartIfNeeded(); clock.resync() }

    // MARK: 대화 · 도움말

    /// 대화 상자 탭(웹 tkBox 클릭): 치는 중이면 다 보이기, 고르는 중이면 무시, 아니면 다음 줄
    func talkTap() {
        guard let t = talk, t.choices == nil else { return }
        if typer.typing { typer.finish() } else { enqueue(.talkNext) }
    }
    func talkPick(_ k: Int) {
        if let c = talk?.choices, k < c.count, let ch = c[k].first, !settings.muted { audio.play(blipCue("me", ch)) }
        enqueue(.talkPick(k))
    }
    func talkSkip() { enqueue(.talkDone) }

    // MARK: 화면 프레임

    /// 한 화면 프레임: 틱 돌리기 → 연출 → 그리기 값. sim 이 없으면 nil
    func frame(media: Double) -> RenderFrame? {
        let f0 = CACurrentMediaTime()
        guard let sim else { return nil }
        let (n0, dt) = clock.begin(media: media)
        let n = paused ? 0 : n0
        var events: [SimEvent] = []
        let s0 = CACurrentMediaTime()
        for k in 0..<n {
            let ev = sim.step(k == 0 ? pending : [])
            if k == 0 { pending = [] }
            events += ev
        }
        let simMs = (CACurrentMediaTime() - s0) * 1000
        if n > 0 || snapshot.actors.isEmpty { snapshot = sim.snapshot }
        clock.end(media: media, simClock: sim.clock)
        let now = media - startMedia

        var capture = false
        if !events.isEmpty {
            capture = handleFlow(events, sim: sim)
            events += injected; injected = []
            let cues = director.apply(events, snapshot: snapshot, now: now)
            for c in cues { let ctx = AudioBridge.hitContext(c); for s in AudioBridge.sfxAll(c) { audio.play(s, context: ctx) } }
            for e in events { if case .railJoint = e { audio.play(.clack(speed: snapshot.trainSpeed)) } }
            #if os(iOS)
            let pulses = haptics.plan(events, now: now)
            if !pulses.isEmpty { hapticPlayer.play(pulses) }
            #endif
        }
        if !paused && sim.clock - lastMetaTick >= 2 { metaTick() }
        // 소리: 열차 루프 · 배경음
        if !paused {
            let carIdx = snapshotCarConcept()
            var ts = SoundDirector.train(snapshot, flickeryCar: carIdx?.flicker ?? false, outdoors: false, now: now)
            ts.snowWind = director.snowWind   // 눈 승강장 바람(아니면 0 — 그대로)
            ts.surf = director.surf           // 해변 파도(아니면 0)
            audio.updateTrain(AudioBridge.train(ts))
            audio.setMusic(AudioBridge.music(SoundDirector.music(snapshot)))
        }
        let stage = director.frame(snapshot, dt: paused ? 0 : dt, now: now, hudPaused: paused)
        if !paused { for c in director.takeSnowCues() { for s in AudioBridge.sfxAll(c) { audio.play(s) } } }   // 눈 승강장 발소리 · 긁힘 · 퍽
        if director.takeHush() { audio.duck(Duck(k: 0.3, hold: 0.75, rel: 0.45)) }   // KO 마무리 한 박자: 배경음 · 환경음을 낮춘다(docs/11)
        let rf = RenderFrame(stage: stage, atlas: sceneContent.sprites)
        lastRenderFrame = rf
        if capture { capturePhoto(rf) }
        // 화면 값 내보내기(바뀐 것만 — SwiftUI 다시 그리기 줄이기)
        // SwiftUI 가 읽는 HUD 값(안내 상자 · 행동 줄)이 바뀔 때만 내보낸다 — 매 프레임 넣으면 GameView 본문 전체가 매 프레임 다시 계산된다
        // (HUDState 는 피해 숫자 나이 등으로 매 프레임 달라진다). 캔버스 HUD 는 director.hud.state 를 직접 읽는다(StageRenderer).
        // ※ SwiftUI 에서 hud 의 다른 필드를 새로 읽게 되면 아래 비교에 더할 것
        let H = director.hud.state
        if H.notice?.id != hud.notice?.id || H.line != hud.line || H.sub != hud.sub || H.specialReady != hud.specialReady
            || Int(H.special) != Int(hud.special) || abs(H.progress - hud.progress) >= 0.002 || (H.progress == 0) != (hud.progress == 0) { hud = H }
        if view != stage.view { view = stage.view }
        if phase != snapshot.state {
            // 정리 단계(가방이 주인공)는 시트를 펼쳐 둔다 — 나가면 닫는다(손으로 연 것은 그대로)
            if snapshot.state == "arrange" && !bagOpen { bagOpen = true; bagAutoOpened = true }
            else if phase == "arrange" && bagAutoOpened { bagOpen = false; bagAutoOpened = false }
            // 새 배치 매점: 무대 자리에 매점 판을 띄운다 — 시트는 접어 둔다(펼친 채면 무대가 작아 카드가 좁다)
            if snapshot.state == "shop" && settings.layoutNew && bagOpen { bagOpen = false; bagAutoOpened = false }
            phase = snapshot.state
        }
        if score != snapshot.score { score = snapshot.score }
        if padLive != (snapshot.pad != nil) { padLive = snapshot.pad != nil }
        if var P = snapshot.pad {   // 패드: 쿨타임 · 수동 초는 끊어서(바뀐 것만 — 매 프레임 다시 그리지 않게)
            for k in P.skills.indices { P.skills[k].cd = (P.skills[k].cd * 30).rounded(.up) / 30; P.skills[k].wait = (P.skills[k].wait * 10).rounded(.up) / 10 }
            P.manual = (P.manual * 10).rounded(.up) / 10
            if P != pad { pad = P }
        }
        let sl = snapshot.bagSlowT > 0 && snapshot.inCombat; if slowed != sl { slowed = sl }
        let plain = snapshot.tower == nil && snapshot.bonus == nil && snapshot.prologue == nil && snapshot.cine == nil && snapshot.dojo == nil
        if hudPlain != plain { hudPlain = plain }
        // 새 배치: 시트를 펼친 동안은 가방을 만지는 것과 같다 — 같은 길(SimIntent.bagTouch → 웹 bagSlowT 0.2배)로 0.25초마다.
        // 시뮬레이션 규칙은 그대로(전투 중일 때만 느려진다). 정리 단계에선 보내지 않는다(웹 arrTouched — 정리 타이머가 멈추므로)
        if settings.layoutNew && bagOpen && !paused && snapshot.inCombat && snapshot.state != "arrange" && menuTab == nil {
            if media - lastOpenTouch > 0.25 { lastOpenTouch = media; enqueue(.bagTouch) }
        }
        if tokens != snapshot.tokens { tokens = snapshot.tokens }
        if snapshot.state == "shop", shopCards != snapshot.shopCards { shopCards = snapshot.shopCards }
        let al = Int(snapshot.arrangeT.rounded(.up)); if arrangeLeft != al { arrangeLeft = al }
        if arrangeHeld != snapshot.arrangeTouched { arrangeHeld = snapshot.arrangeTouched }
        if transferTo != snapshot.transferTo { transferTo = snapshot.transferTo }
        let bb: BonusBoard? = snapshot.bonus.flatMap { B in B.phase == "owner" ? B.result.map { BonusBoard(result: $0, pt: B.pt, skippable: B.skippable) } : nil }
        #if DEBUG
        if debugBonusBoard != nil { debugBonusBoard!.pt += paused ? 0 : dt; if bonusBoard != debugBonusBoard { bonusBoard = debugBonusBoard } }
        else if bonusBoard != bb { bonusBoard = bb }
        #else
        if bonusBoard != bb { bonusBoard = bb }
        #endif
        bag.frame(snapshot, events: events)
        // 대화 · 도움말(시뮬레이션 스냅숏 — 웹 hint 는 0.4초 뒤에 보인다)
        if dojoView != snapshot.dojo { dojoView = snapshot.dojo }
        var tv = snapshot.talk
        #if DEBUG
        if tv == nil, let d = debugTalkView { tv = d }
        #endif
        if talk != tv { talk = tv; typer.sync(tv) }
        let hv: HintCard? = snapshot.hint.flatMap { h in h.age >= 0.4 ? HintCard(id: h.key, title: h.title, body: h.body) : nil }
        if hintCard != hv { hintCard = hv }
        // 성능
        perfAcc.frames += 1; perfAcc.sim += simMs; perfAcc.ticks += n; perfAcc.frame += (CACurrentMediaTime() - f0) * 1000
        let el = media - perfAcc.t0
        if el >= 0.5 {
            perf = PerfStats(fps: Double(perfAcc.frames) / el, simMs: perfAcc.sim / Double(max(1, perfAcc.frames)), frameMs: perfAcc.frame / Double(max(1, perfAcc.frames)),
                             gpuMs: lastGPUms, ticks: perfAcc.ticks, actors: snapshot.actors.count, particles: director.fx.count)
            perfAcc = (0, 0, 0, 0, media)
            #if DEBUG
            if Self.perfLog { print(String(format: "[perf] fps %.1f · 틱 %.2fms · 프레임(CPU) %.2fms · GPU %.2fms · 인물 %d · 입자 %d", perf.fps, perf.simMs, perf.frameMs, perf.gpuMs, perf.actors, perf.particles)) }
            #endif
        }
        return rf
    }

    /// 표현 쪽에 더 내보낼 이벤트(가방 해금 안내 등 — 앱이 만든 안내 문구)
    @ObservationIgnored private var injected: [SimEvent] = []
    #if DEBUG
    @ObservationIgnored var debugBonusBoard: BonusBoard?
    #endif

    private func snapshotCarConcept() -> (flicker: Bool, key: String)? {
        let st = snapshot.stageIndex, ci = snapshot.car
        guard st < data.game.stages.count, ci < data.game.stages[st].line.count else { return nil }
        let k = data.game.stages[st].line[ci].car
        return k < carFlags.count ? carFlags[k] : nil
    }

    /// 저장 · 결과 · 흐름 이벤트. 보도 사진을 찍어야 하면 true
    private func handleFlow(_ events: [SimEvent], sim: Sim) -> Bool {
        var metaDirty = false, capture = false
        for e in events {
            switch e {
            case .runCheckpoint:
                persistRun(sim)
            case .metaChanged:
                metaDirty = true
            case .towerEnded(let t):
                metaDirty = true
                result = .tower(t)
                GameCenterService.shared.reportTower(t)   // 로그인 안 됐으면 아무것도 안 한다
            case .bonusEnded:
                metaDirty = true
            case .runEnded(let win):
                guard sim.config.mode == .subway else { metaDirty = true; continue }   // 타워 결과는 towerEnded 가 맡는다(웹 showResult 를 안 거침)
                metaTick(force: true)
                var M = meta
                SaveBridge.merge(sim.meta, into: &M)
                let newBest = M.recordRunEnd(score: snapshot.score, dailyKey: sim.config.daily ? sim.config.dateKey : nil)
                meta = M; storeMeta(M)
                result = .news(NewsInfo(win: win, score: snapshot.score, kills: snapshot.kills, stats: snapshot.stats, stageIdx: snapshot.stageIndex,
                                        ci: snapshot.car, daily: sim.config.daily, newBest: newBest, unlocks: newUnlocks))
                GameCenterService.shared.reportRun(score: snapshot.score)
                save?.clearRunSave(); runSave = nil; save?.flush()
                capture = true
                metaDirty = false
            default: break
            }
        }
        if metaDirty {
            var M = meta
            if SaveBridge.merge(sim.meta, into: &M) { meta = M; storeMeta(M) }
        }
        return capture
    }

    /// 웹 metaTick(2초마다): 누계 증가분 · 역 · 시작 가방 해금
    private func metaTick(force: Bool = false) {
        guard let sim, sim.config.mode == .subway || sim.config.mode == .tower else { return }   // 무도장 · 개발 보너스는 누계에 넣지 않는다
        lastMetaTick = sim.clock
        var M = meta
        var ch = M.addTally(SaveBridge.tally(snapshot, merges: runMerges), snap: &tallySnap)
        if snapshot.atStop != nil && snapshot.trainDoor > 0.9 { ch = M.visitStation(snapshot.atStop) || ch }
        let opened = M.unlockKits(SaveBridge.kitConditions(content.kits))
        for id in opened {
            guard let k = content.kits.first(where: { $0.id == id }) else { continue }
            newUnlocks.append(tr(k.name))
            injected.append(.notice(title: tr("새 시작 가방 해금!"), body: "\(tr(k.name)) — \(tr(k.desc))", seconds: 3))
            audio.play(.unlock)
        }
        if SaveBridge.merge(sim.meta, into: &M) { ch = true }
        if ch || !opened.isEmpty { meta = M; storeMeta(M) }
        _ = force
    }

    /// 합성 성공(가방 편집기) — 웹 GS.stats.merges
    func noteMerge(ok: Bool) { if ok { runMerges += 1 } }

    // MARK: 보도 사진(웹 newsPhoto — 판이 끝난 순간의 화면을 4×4 순서 디더로)

    private func capturePhoto(_ rf: RenderFrame) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.photoCap == nil { self.photoCap = NewsPhotoCapture(atlas: self.atlas) }
            self.newsPhoto = self.photoCap?.capture(rf).map { UIImage(cgImage: $0) }
        }
    }

    #if DEBUG
    /// 점검용: 지금 장면으로 결과 신문을 띄운다(판 끝 경로와 같은 코드)
    func debugShowNews(win: Bool) {
        guard let sim else { return }
        result = .news(NewsInfo(win: win, score: snapshot.score, kills: snapshot.kills, stats: snapshot.stats, stageIdx: snapshot.stageIndex,
                                ci: snapshot.car, daily: sim.config.daily, newBest: true, unlocks: ["치명 가방"]))
        phase = "over"; paused = true
        if let rf = lastRenderFrame { capturePhoto(rf) }
    }
    func debugShowTower() {
        var t = TowerResult(); t.win = false; t.floor = 14; t.seconds = 251; t.kills = 41; t.outs = 12; t.ceils = 9; t.wrecks = 6
        t.newRecord = true; t.ot = 2; t.best = 18; t.levelBest = .init(f: 14, t: 251)
        result = .tower(t); phase = "over"; paused = true
    }
    func debugShowBonus() {
        var r = BonusResult(); r.grade = "A"; r.tokens = 3; r.hit = 12840; r.part = 4200; r.destroy = 3000; r.time = 1500; r.combo = 1800; r.total = 23340; r.best = true
        debugBonusBoard = BonusBoard(result: r, pt: 1.6, skippable: false)
    }
    /// 점검용 대화(실제 대화는 시뮬레이션이 연다 — 화면 모양만 본다)
    @ObservationIgnored var debugTalkView: TalkView?
    func debugTalk(_ key: String = "intro") {
        var v = TalkView(); v.key = key; v.count = 5; v.who = "minnie"; v.name = content.cast["minnie"]?.n ?? "미니"; v.color = content.cast["minnie"]?.c ?? "#ff8a5a"
        v.text = "호외요, 호외! <b>보스의 가방</b>이 막차에서 터졌대요! …손님 거죠, 그 가방?"
        debugTalkView = v
    }
    func debugHint(_ key: String = "just") {
        guard let h = content.hints[key], h.count >= 2 else { return }
        hintCard = HintCard(id: key, title: h[0], body: h[1])
    }
    #endif
}
