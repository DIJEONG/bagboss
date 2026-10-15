import Foundation
import BBCore
import BBSim

// HUD 모델(순수): 시뮬레이션 이벤트 + 스냅숏 → 화면에 띄울 항목과 수명(웹 DPOPS · DSTACK · HITFX · COMIC · GS.critFx · GS.sw/smear · GS.cmdLog · GS.cut · GS.wipe).
// 그리기는 HUD/HUDDraw(HUDOverlay.build) → BBRender OverlayRenderer(Metal). SwiftUI 는 DOM 이던 것(행동 줄 · 안내 · 메뉴)만.
// 웹 원본: 45-hud dmgPop · hitFx · chFx · swPush · swHit · hmTrail · comicSpot · comicSFX · comicSay · drawHitFx(수명 · 물방울 물리)
//          · 47-special-ui drawDmg(DPOPS 수명) · spcFinish(SPECIAL 합계) · bossBar(lag) · drawCut0 · 27 startBoard(GS.wipe) · 33 cmdPush · 13 groundImpact(HITFX)
//          · 30-train-env 연타 합계(N HIT TOTAL) · abUpdate(행동 줄: 노선 · 남은 초 · 적 수 · 진행 막대 · 필살 게이지)
// 좌표는 장면 픽셀(무대). 시간: 웹처럼 두 시계 — 실제 시간(performance.now: 쌓기 · 만화 간격 · 기술 줄)과
//   HUD dt(= 실제 dt × 게임 속도, 최대 .05: 숫자 · 효과 · 만화 수명). 충격파는 게임 시계(GS.time).
// 연출 전용 무작위(웹 Math.random)는 고정 씨앗 SplitMix64 — 규칙 난수와 섞이지 않는다.

public struct HUDState: Sendable, Equatable {
    /// 네이티브 피해 숫자 크기 배율(HUDFrame.dmgScale — 웹 크기의 50%)
    public static let nativeDmgScale = 0.5
    public struct DamagePop: Sendable, Equatable, Identifiable {
        public let id: Int
        public var x: Double, y: Double
        public var value: Int
        /// hit · crit · hurt · heal · total
        public var style: String
        public var label: String?
        public var stack: Int
        public var age = 0.0, life: Double
        public var vx: Double
        /// 라벨 색(웹 labelCol — 없으면 #ffcf4a)
        public var labelCol: String?
        /// 떠오르는 거리 배율(네이티브 굴러 올라가는 숫자 0.55 — 짧게 뜬다)
        public var riseK = 1.0
        /// 네이티브 굴러 올라가는 숫자(연타 칸): 타격마다 값이 바뀌며 튄다 — 튐 세기(첫 타 0.3 · 잇는 타 0.35 · 마지막 큰 타 0.7) · 크기 배율 · 떠오르기 전 머묾(초)
        public var counter = false, popAmp = 0.0, sizeK = 1.0, hold = 0.0
        /// 굴러 올라가는 숫자 밑 작은 꼬리표('N HIT') · 남은 초
        public var tag: String?, tagT = 0.0
        public init(id: Int, x: Double, y: Double, value: Int, style: String, label: String?, stack: Int, age: Double = 0, life: Double, vx: Double, labelCol: String? = nil) {
            self.id = id; self.x = x; self.y = y; self.value = value; self.style = style; self.label = label; self.stack = stack
            self.age = age; self.life = life; self.vx = vx; self.labelCol = labelCol
        }
        /// 글자 크기 단(웹 DSTYLE.s): crit · total 3, 나머지 2
        public var scale: Double { style == "crit" || style == "total" ? 3 : 2 }
        /// 웹: 꽂히듯 커졌다가 매끄럽게 줄어든다 — 1 + k·(1−u)³
        public var pop: Double { counter ? sizeK * (1 + popAmp * HUDState.ease(age / 0.12)) : 1 + (style == "crit" ? 0.7 : 1) * HUDState.ease(age / 0.14) }
        /// 웹 rise: 빠르게 10px 떠오르고 0.7초 뒤 천천히 더 오른다
        public var rise: Double {
            let a = counter ? max(0, age - hold) : age
            return (-10 * (1 - exp(-a * 12)) - (a > 0.7 ? (a - 0.7) * 26 : 0)) * riseK
        }
        /// 굴러 올라가는 숫자: 값이 바뀐 직후 0.1초 1~2px 떨림
        public var jolt: Double { counter && age < 0.1 ? (Int(age * 60) % 2 == 0 ? 1.5 : -1.5) * (1 - age / 0.1) : 0 }
        public var alpha: Double { age > life - 0.3 ? max(0, (life - age) / 0.3) : 1 }
        /// 지금 그릴 기준점(장면 픽셀) — 글자 바닥 가운데
        public var anchor: SIMD2<Double> { [x + vx * min(age, 0.3), y - Double(stack) * (7 * scale + 3) + rise + (7 * scale + 2)] }
        public var text: String { (style == "heal" ? "+" : "") + String(value) }
    }
    public struct ComicWord: Sendable, Equatable, Identifiable {
        public let id: Int
        public var x: Double, y: Double, word: String, rot: Double
        public var age = 0.0, life = 0.6
        public init(id: Int, x: Double, y: Double, word: String, rot: Double, age: Double = 0, life: Double = 0.6) { self.id = id; self.x = x; self.y = y; self.word = word; self.rot = rot; self.age = age; self.life = life }
        public var scale: Double { HUDState.comicPop(age) }
        public var alpha: Double { (age > life - 0.25 ? max(0, (life - age) / 0.25) : 1) * (age > 0.2 ? 0.9 : 1) }
    }
    public struct Bubble: Sendable, Equatable, Identifiable {
        public let id: Int
        public var actor: ActorID
        public var text: String
        /// speech · think · shout
        public var kind: String
        public var age = 0.0, life: Double
        /// 인물 발(장면 픽셀) — 풍선은 그 위 104px
        public var x = 0.0, y = 0.0
        public init(id: Int, actor: ActorID, text: String, kind: String, age: Double = 0, life: Double, x: Double = 0, y: Double = 0) { self.id = id; self.actor = actor; self.text = text; self.kind = kind; self.age = age; self.life = life; self.x = x; self.y = y }
        public var scale: Double { HUDState.comicPop(age) }
        public var alpha: Double { age > life - 0.25 ? max(0, (life - age) / 0.25) : 1 }
    }
    public struct Notice: Sendable, Equatable, Identifiable {
        public let id: Int
        public var title: String, body: String
        public var age = 0.0, life: Double
        /// 타자기처럼 드러난 글자 수(초당 40자)
        public var shownChars: Int { Int(age * 40) }
        public var alpha: Double { age > life - 0.3 ? max(0, (life - age) / 0.3) : min(1, age / 0.12) }
    }
    public struct Flash: Sendable, Equatable { public var text: String; public var age = 0.0, life: Double }
    public struct TextPop: Sendable, Equatable, Identifiable {
        public let id: Int
        public var x: Double, y: Double, text: String
        public var age = 0.0, life = 1.2
    }
    public struct Banner: Sendable, Equatable {
        public var title: String, sub: String
        public var age = 0.0, life: Double
    }

    // 행동 줄 · 상단
    public var hp = 0.0, maxHP = 100.0, lagHP = 0.0
    public var special = 0.0
    public var specialReady: Bool { special >= 100 }
    public var score = 0, tokens = 0, kills = 0
    /// 연타 수(2 이상일 때만 보인다) · 마지막 타격 뒤 흐른 초
    public var combo = 0, comboAge = 9.0
    /// 마지막 타격 시각(웹 GS.lastHit — 전투 시계) · 연타 피해 합(웹 GS.comboDmg)
    public var comboLastHit = -9.0, comboDmg = 0
    public var comboRouteName: String?
    /// 상단 줄(노선 · 호차 · 칸 이름) · 아래 줄(남은 초 · 적 수 · 역) · 진행 0..1
    public var line = "", sub = "", progress = 0.0
    public var state = "idle"

    public var pops: [DamagePop] = []
    public var words: [ComicWord] = []
    public var bubbles: [Bubble] = []
    public var notice: Notice?
    public var flash: Flash?
    public var textPops: [TextPop] = []
    public var banner: Banner?
    // ---- 오버레이 패스(웹 #ui 캔버스) ----
    public var hitFx: [HitFx] = []
    /// 네이티브 퇴근 승천권 지붕 구멍(칸이 바뀔 때까지)
    public var roofHoles: [RoofHole] = []
    /// 네이티브 퇴근 승천권 종이 회오리(솟구침 → 흩날려 떨어짐, 2.5초 남짓)
    public var risePapers: [RisePaper] = []
    public var critFx: [CritFx] = []
    /// 투명 충격파 · 방향 번짐(후처리 uSW · uSM — FrameAssembly 가 옮긴다)
    public var shockwaves: [Shockwave] = []
    public var smear: Smear?
    /// 기술 이름 줄(웹 GS.cmdLog — 새것이 앞)
    public var cmdLog: [CmdView] = []
    public var cut: CutView?
    public var wipe: WipeView?
    /// 웹 #ui 캔버스는 lineCap 을 프레임마다 되돌리지 않는다 — 'streak' 이 한 번이라도 그려진 뒤로는 'round' 가 남는다
    /// (수플렉스 궤적 sxpath 의 점선이 둥근 끝으로 이어져 매끈한 굵은 호로 보이는 까닭). 오버레이 그리기 시작 상태
    public var capRound = false

    public init() {}

    /// 웹 drawDmg ease: (1−u)³
    static func ease(_ t: Double) -> Double { let u = max(0, min(1, t)); return pow(1 - u, 3) }
    /// 웹 comicPop: 작게 → 살짝 넘치게 → 제 크기
    static func comicPop(_ t: Double) -> Double { t < 0.09 ? 0.45 + 0.75 * (t / 0.09) : t < 0.18 ? 1.2 - 0.2 * ((t - 0.09) / 0.09) : 1 }
}

/// HUD 에 쓰는 이름표(노선 · 칸 · 역) — SimData 에서 만든다
public struct HUDCatalog: Sendable {
    public var stageShort: [String] = [], stageName: [String] = []
    /// [노선][호차] → (칸 이름, 다음 역 id, 구간 길이 계산은 스냅숏 legDur)
    public var cars: [[(name: String, stop: String?)]] = []
    public var stations: [String: String] = [:]
    /// 타워 층 이름(웹 TW_FLOORS n · en) · [노선][호차] 쇼 칸(marquee) — 모드 HUD(HUDModes.swift)
    public var towerFloors: [(ko: String, en: String)] = []
    public var marquee: [[Bool]] = []
    /// 네이티브 동작 개편 묶음인가(SimData.nativeMoves — 피해 숫자 기둥 상한 · 승천권 숫자 합치기. 꺼짐 = 웹 그대로)
    public var native = false
    public init() {}
    public init(_ d: SimData) {
        stageShort = d.game.stages.map(\.short); stageName = d.game.stages.map(\.name)
        cars = d.game.stages.map { st in st.line.map { L in (d.cars.indices.contains(L.car) ? d.cars[L.car].name : "", L.stop) } }
        stations = d.stations
        towerFloors = d.game.towerFloors.map { ($0?.name ?? "", $0?.en ?? "") }
        marquee = d.game.stages.map { st in st.line.map { L in d.cars.indices.contains(L.car) ? (d.cars[L.car].marquee ?? false) : false } }
        native = d.nativeMoves
    }
}

public struct HUDDirector: Sendable {
    public private(set) var state = HUDState()
    public var catalog: HUDCatalog
    /// HUD 데이터 · 그림(없으면 오버레이 프레임 값 일부를 비운다 — 테스트용)
    public var art: HUDArt?
    /// 게임 속도(웹 playSpeed — HUD dt 배율). 앱이 프레임마다 맞춘다
    public var playSpeed = 1.0
    /// 세로 화면에서 보이는 폭(웹 VW)
    public var visibleWidth = 360.0
    /// 옵션(웹 OPT.noFlash · skin · shades)
    public var noFlash = false, skin = "jw", shades = false
    /// AUTO · MANUAL 배지 보이기(nil = 웹 그대로 보임 — 앱 출시판은 false)
    public var modeBadge: Bool?
    private var nextID = 0
    private var stack: [ActorID: (t: Double, n: Int)] = [:]
    private var quipT = -99.0, comicT = -99.0
    /// 네이티브 굴러 올라가는 숫자: 대상별 연타 칸(숫자 id · 마지막 타격 전투 시각 · 쪽)
    private var counters: [ActorID: (pop: Int, t: Double, side: Double, chain: Int)] = [:]
    /// 연타 사슬 번호(comboStep 이 1로 새로 시작할 때마다 +1 — 같은 사슬의 타격은 한 칸으로)
    private var chainID = 0
    /// 실제 시간(초, 일시정지면 멈춘다)
    public private(set) var now = 0.0
    private var quipTurn = 0
    private var rng = SplitMix64(seed: 0xC0_51C5)
    /// 연출 흔들림 전용 수열(웹 Math.random — 피해 숫자 ±7% · 만화 글자 자리 · 질주 속도선). 규칙 수열과 무관하고
    /// 기존 HUD 수열(rng)의 순서도 건드리지 않게 따로 둔다 — 세션마다 같은 씨앗이라 테스트가 결정적이다
    private var jit = SplitMix64(seed: 0x0D_15C0)
    /// 지붕 뚫기 연출 전용 수열(다른 HUD 수열과 섞이지 않게 — 깃발 꺼짐 대조 그대로)
    private var roofRng = SplitMix64(seed: 0x5_00F)
    /// 웹 dashFx(질주 속도선): 지난 runU · 주인공 x · 전투 시계 · 쌓인 시간(웹 c.dfx)
    private var dashRunU: Double?, dashX = 0.0, dashTime: Double?, dashAcc = 0.0
    private var actors: [ActorID: SimSnapshot.ActorView] = [:]
    private var camX = 0.0, gsTime = 0.0
    // 웹 GS.swLast · chT · faceMood/faceUntil · bossBreak · raged · lbox · 컷인 · 필살 종류 · 호차
    private var swLast: (t: Double, tier: Int, x: Double)?
    private var chT = -9.0
    /// 네이티브 공방: 마지막 '막!' 글자 시각
    private var guardTxtT = -9.0
    private var faceMood: String?, faceUntil = -9.0
    private var breakState: (actor: ActorID, t: Double, T0: Double)?
    private var raged: Set<ActorID> = []
    private var bossLag: [ActorID: Double] = [:]
    private var lbox = 0.0
    private var cutDur = 1.0, cutBoss: ActorID?, specialKind = "fist"
    private var lastCar: Int?
    /// 모드 HUD 표현 상태(쇼 칸 전구 · 무도장 동작 프레임) — HUDModes.swift
    public internal(set) var modeTracker = HUDModeTracker()

    public init(catalog: HUDCatalog = HUDCatalog(), art: HUDArt? = nil) { self.catalog = catalog; self.art = art }

    static let quips: [String: [String]] = [
        "wave": ["다음.", "이게 전부야?", "넥타이가 구겨졌잖아.", "몸 좀 풀렸네."],
        "clear": ["정시 도착이다.", "다음 역까지 한숨 돌리지."],
        "combo": ["리듬 좋고.", "이 정도는 해야지."],
        "rest": ["…이 도시는 잠들지 않는군.", "…다음 역까지 숨 좀 고르지.", "…막차는 늘 조용하다가 시끄럽지.", "…넥타이 좀 고쳐 매야겠어.", "…창밖 불빛이 빨리도 지나가네."],
        "think": ["…커피 한 잔 하고 싶군.", "…다음은 어떤 놈들이려나.", "…넥타이를 새로 맬까."],
        "cheer": ["와!", "대박!", "찍었어!"],   // 웹 구경꾼 환호(5 · 10 · 15 연타 — 웹은 QUIPS 밖 배열). 없으면 열쇠 'quip:cheer'가 그대로 보였다
    ]
    /// 웹 SW_T · SWP(art 가 없을 때)
    static let swT: [String: Int] = ["tetsu": 3, "axe": 3, "axe_air": 3, "suplex": 3, "round": 3, "round_air": 3, "charge": 3, "charge_air": 3, "fkick": 3, "throw": 3,
                                     "upper": 2, "kick": 2, "knee": 2, "cycle": 2, "renkan": 2, "hook": 2, "bkick": 2, "uthrust": 2, "sweep": 2, "stomp": 2]
    static let swP: [Int: (r0: Double, r1: Double, w: Double, amp: Double, dark: Double, life: Double)] = [2: (5, 22, 6, 2.6, 0.08, 0.12), 3: (8, 36, 9, 4.2, 0.17, 0.17)]

    private mutating func id() -> Int { nextID += 1; return nextID }
    private mutating func rnd() -> Double { rng.next() }

    /// 대사 열쇠(quip:wave …)를 문장으로. 같은 열쇠는 차례로 돈다(결정적)
    mutating func resolve(_ text: String) -> String {
        guard text.hasPrefix("quip:") else { return text }
        let k = String(text.dropFirst(5)), L = Self.quips[k] ?? [text]
        quipTurn += 1
        return L[quipTurn % L.count]
    }

    // MARK: 웹 swPush · hitFx · chFx · groundImpact(HITFX 부분)

    /// 웹 swPush(x, y, tier, f) — 게임 시계 기준
    mutating func swPush(_ x: Double, _ y: Double, _ tier: Int, _ f: Double) {
        guard tier > 0 else { return }
        let t = gsTime
        if let L = swLast, t >= L.t, t - L.t < 0.07, tier <= L.tier, abs(L.x - x) < 30 { return }   // 연타가 겹치면 하나만
        swLast = (t, tier, x)
        let k = noFlash ? 0.35 : 1
        let shape = art?.swShape ?? Self.swP
        func add(_ P: (r0: Double, r1: Double, w: Double, amp: Double, dark: Double, life: Double), _ d: Double, _ sc: Double) {
            state.shockwaves.append(Shockwave(x: x, y: y, t0: t + d, life: P.life * sc, r0: P.r0 * sc, r1: P.r1 * sc, w: P.w * sc, amp: P.amp * k, dark: P.dark * k))
        }
        if tier >= 4 { add(shape[3]!, 0, 1); add(shape[3]!, 0.07, 1.35) } else if let P = shape[tier] { add(P, 0, 1) }
        if tier >= 3 {
            if k == 1 { state.smear = Smear(x: x, y: y, f: f, t0: t, life: 0.07, R: 30) }
            var p = HitFx(k: "swpuff", x: x - f * 2, y: y - 4, life: 0.6); p.f = f
            p.b = (0..<4).map { _ in HitFx.Puff(dx: (rnd() - 0.5) * 12 + f * 4, dy: (rnd() - 0.5) * 8, r: 2.5 + rnd() * 2.5, vy: 10 + rnd() * 12, vx: (rnd() - 0.5) * 8) }
            state.hitFx.append(p)
        }
        if state.shockwaves.count > 8 { state.shockwaves.removeFirst(state.shockwaves.count - 8) }
    }

    /// 웹 hitFx(tgt, f, o, big, att) + swHit + chFx — 값은 전부 HitInfo(규칙이 그 순간 잰 것)에서
    mutating func hitFx(_ h: HitInfo, tgt T: SimSnapshot.ActorView) {
        let f = h.dir, big = h.big, attAnim = h.attackerAnim, tx = h.at.x, ty = h.at.y
        let head = !h.low && !["hitB", "rKnee", "rKick", "rSwept"].contains(h.targetAnim)
        let y = ty + (h.low ? -20 : head ? -50 : -40), x = tx - f * 3, n = big ? 7 : 4
        if catalog.native && h.attackerIsHero && attAnim == "nv_rise" {   // 네이티브 승천권: 섬광을 작게 — 맞닿은 자리 작은 십자 불꽃(꼭대기만 · 0.05초) + 짧은 선 몇 개
            let apex = h.reactOpt != "head"   // 솟는 두 타 = 가벼운 'head' 반응
            for _ in 0..<(apex ? 4 : 2) {
                let a = (rnd() - 0.5) * 1.4, sp = 200 * (0.6 + rnd() * 0.5)
                var p = HitFx(k: "streak", x: x, y: y + (rnd() - 0.5) * 4, life: 0.08); p.vx = f * cos(a) * sp; p.vy = sin(a) * sp; p.col = "#ffd34a"; p.a = noFlash ? 0.5 : 0.85
                state.hitFx.append(p)
            }
            if apex && !noFlash { state.hitFx.append(HitFx(k: "flash", x: x, y: y, life: 0.05)) }
            if apex && !h.splash { swPush(x, y - h.targetJugH - h.targetAirOv, 2, f) }
            return
        }
        for _ in 0..<(n + 2) {
            let a = (rnd() - 0.5) * 1.7, sp = (big ? 320.0 : 240) * (0.6 + rnd() * 0.6)
            var p = HitFx(k: "streak", x: x, y: y + (rnd() - 0.5) * 6, life: big ? 0.2 : 0.14)
            p.vx = f * cos(a) * sp; p.vy = sin(a) * sp; p.col = h.crit ? "#ff7a3a" : "#ffd34a"
            state.hitFx.append(p)
        }
        var fl = HitFx(k: "flash", x: x, y: y, life: big ? 0.12 : 0.08); fl.big = big; state.hitFx.append(fl)
        if h.attackerIsHero, let w = art?.atkWeight[attAnim] {   // 웹 ATK_FEEL[att.anim].w
            if w == "H" { var p = HitFx(k: "burst", x: x, y: y, life: 0.3); p.f = f; p.n = 14; p.r0 = 8; p.r1 = 44; state.hitFx.append(p) }
            else if w == "M" { var p = HitFx(k: "ring", x: x, y: y, life: 0.16); p.r1 = 14; state.hitFx.append(p) }
        }
        if h.attackerIsHero && !h.splash {   // 웹 swHit: 기술 무게별 충격파(연환퇴 2타 띄우기는 묵직)
            var tier = (art?.swTier ?? Self.swT)[attAnim] ?? 0
            if attAnim == "renkan" && h.reaction == "launch" { tier = 3 }
            if tier > 0 { swPush(x, y - h.targetJugH - h.targetAirOv, tier, f) }
        }
        if head && T.isEnemy {
            for _ in 0..<(big ? 6 : 3) {
                var p = HitFx(k: "drop", x: tx + f * 2, y: y - 4, life: 0.5)
                p.vx = f * (30 + rnd() * 70); p.vy = -(40 + rnd() * 60); p.col = "#cfe8ff"
                state.hitFx.append(p)
            }
        }
        if h.attackerIsHero && T.isEnemy && h.crit { state.critFx.append(CritFx(x: tx, y: ty - 38, big: h.bigCrit, f: f)) }
        if h.chit {   // 웹 chFx: 작은 충격파 · 반짝(규칙이 1.2초에 한 번 고른 것 — chitFlash)
            let cy = ty - 32 - h.targetJugH - h.targetAirOv
            swPush(tx - f * 2, cy, 2, f)
            if h.chitFlash && !noFlash { state.hitFx.append(HitFx(k: "chstar", x: tx - f * 3, y: cy, life: 0.24)) }
        }
        if h.attackerIsHero && h.just { swPush(tx, ty - 32, 3, f) }
    }

    mutating func groundImpact(_ x: Double, _ y: Double, _ p0: Double) {
        if catalog.native { return }   // 깃발 켜짐: 먼지 · 파편 · 균열은 무대 픽셀(StageDirector.impact · 눈은 SnowFx)
        let p = max(0.3, p0), n = Int((6 + 8 * p).rounded())
        var g = HitFx(k: "gdust", x: x, y: y, life: 0.55 + 0.3 * p)
        g.puffs = (0..<n).map { i in
            let side: Double = i % 2 != 0 ? 1 : -1
            return HitFx.GPuff(dx: side * (2 + rnd() * 6), vx: side * (14 + rnd() * 26) * p, rise: 3 + rnd() * 7 * p, r: (2.4 + rnd() * 3) * (0.7 + p * 0.5), d: rnd() * 0.12)
        }
        state.hitFx.append(g)
        var d = HitFx(k: "debris", x: x, y: y, life: 0.6)
        d.parts = (0..<Int((3 + 5 * p).rounded())).map { _ in HitFx.Part(vx: (rnd() * 2 - 1) * (40 + 50 * p), vy: 60 + rnd() * 90 * p, s: rnd() < 0.5 ? 1 : 2) }
        state.hitFx.append(d)
        if p > 1.05 {
            var pts: [[Double]] = []
            var cx = -10 - 8 * p
            while cx < 10 + 8 * p { pts.append([cx, (rnd() * 2 - 1) * 1.2]); cx += 2 + rnd() * 3 }
            var c = HitFx(k: "crack", x: x, y: y, life: 1.1); c.pts = pts; state.hitFx.append(c)
        }
    }

    mutating func cracks(_ n: Int, _ spread: Double) -> [HitFx.Crack] { (0..<n).map { k in HitFx.Crack(sd: k % 2 != 0 ? 1 : -1, a: (rnd() - 0.5) * spread, n: 3 + (k % 3)) } }

    /// 네이티브 연출(막차 러시 · 코크스크루) — 규칙이 그 자리에서 잰 값(FxDetail)으로
    mutating func nvFx(_ d: FxDetail) {
        let f = d.dir == 0 ? 1 : d.dir
        switch d.kind {
        case "nv_speed":   // 속도선 + 잔상(뒤에 남는 몸 그림자 둘)
            for _ in 0..<(8 + min(6, d.n)) {
                var p = HitFx(k: "streak", x: d.x - f * (6 + rnd() * 10), y: d.y - 14 + rnd() * 34, life: 0.16 + rnd() * 0.08)
                p.vx = -f * (320 + rnd() * 200); p.vy = (rnd() - 0.5) * 8; p.col = rnd() < 0.5 ? "#fffbe8" : "#cfe8ff"; p.a = 0.8; state.hitFx.append(p)
            }
            for (k, dx) in [12.0, 24, 36].enumerated() where k < 2 + min(1, d.n / 3) {
                var g = HitFx(k: "nv_ghost", x: d.x - f * dx, y: d.y + 34, life: 0.16 + 0.05 * Double(k)); g.f = f; g.a = 0.42 - 0.12 * Double(k); g.ph = Double(d.n % 2)
                state.hitFx.append(g)
            }
        case "nv_hook":    // 박자마다: 훅 궤적 · 불꽃 고리(박자가 갈수록 크게) · 뒤쪽 박자는 충격파
            var a = HitFx(k: "arc", x: d.x - f * 10, y: d.y + 2, life: 0.18); a.f = f; a.kind = d.big ? "b" : "h"; state.hitFx.append(a)
            var r = HitFx(k: "ring", x: d.x + f * 4, y: d.y, life: 0.16); r.r1 = 10 + 3 * Double(d.n); state.hitFx.append(r)
            var fl = HitFx(k: "flash", x: d.x + f * 4, y: d.y, life: 0.08); fl.big = d.n >= 3; state.hitFx.append(fl)
            if d.n >= 4 { swPush(d.x + f * 4, d.y, d.n >= 6 ? 3 : 2, f) }
        case "nv_finish":  // 마무리 올려치기: 큰 충격파 · 별 터짐 · 위로 치솟는 선 · 섬광
            swPush(d.x, d.y, 4, f)
            var b = HitFx(k: "burst", x: d.x, y: d.y, life: 0.42); b.f = f; b.n = 20; b.r0 = 10; b.r1 = 70; state.hitFx.append(b)
            if !noFlash { state.hitFx.append(HitFx(k: "sig_flash", x: d.x, y: d.y, life: 0.14)) }
            for _ in 0..<14 {
                var p = HitFx(k: "streak", x: d.x + (rnd() - 0.5) * 40, y: d.y + 10 + rnd() * 20, life: 0.22 + rnd() * 0.1)
                p.vx = f * rnd() * 60; p.vy = -(380 + rnd() * 220); p.col = rnd() < 0.5 ? "#ffe27a" : "#ffffff"; state.hitFx.append(p)
            }
        case "nv_cork":    // 코크스크루: 비틀린 소용돌이 · 앞으로 뚫고 나가는 선
            var s = HitFx(k: "swirl", x: d.x + f * 8, y: d.y, life: 0.28); s.ph = 2; state.hitFx.append(s)
            for _ in 0..<6 {
                var p = HitFx(k: "streak", x: d.x + f * 6, y: d.y + (rnd() - 0.5) * 10, life: 0.16)
                p.vx = f * (420 + rnd() * 160); p.vy = (rnd() - 0.5) * 20; p.col = "#ffd2a0"; state.hitFx.append(p)
            }
        default: break
        }
    }

    /// 네이티브 공방(docs/08): 막기 = 파랗고 흰 불꽃 · 방패 호 · 가끔 '막!' / 흘림 = 머리 위 바람 / 저스트 = 흰 고리 / 가드 부수기 = 금 /
    /// 크래시 = 깨진 조각 · 큰 고리 · 섬광(글자 'GUARD BREAK!' 은 규칙이 comicWord 로)
    mutating func guardFx(_ g: GuardInfo, crash: Bool) {
        let x = g.at.x, y = g.at.y, f = g.dir == 0 ? 1 : g.dir
        if crash {
            var r = HitFx(k: "burst", x: x, y: y, life: 0.36); r.f = f; r.n = 16; r.r0 = 8; r.r1 = 44; r.kind = "guard"; state.hitFx.append(r)
            var sh = HitFx(k: "gshatter", x: x, y: y, life: 0.6); sh.f = f
            var parts: [HitFx.Part] = []
            for k in 0..<12 {
                let side: Double = k % 3 == 0 ? -0.6 : 1
                let vx: Double = -f * (30 + rnd() * 130) * side, vy: Double = -(40 + rnd() * 150)
                let col = k % 2 == 0 ? "#cfe8ff" : "#ffffff", rot: Double = rnd() * 6.3, spin: Double = (rnd() - 0.5) * 18
                parts.append(HitFx.Part(vx: vx, vy: vy, s: 1 + Double(k % 3), c: col, a: rot, l: spin))
            }
            sh.parts = parts
            state.hitFx.append(sh)
            if !noFlash && !g.heroBlocked { state.hitFx.append(HitFx(k: "sig_flash", x: x, y: y, life: 0.1)) }
            if g.heroBlocked { faceMood = "flinch"; faceUntil = now + 0.5 }
            return
        }
        if g.just {
            var r = HitFx(k: "gjust", x: x, y: y, life: 0.3); r.f = f; state.hitFx.append(r)
            var t = HitFx(k: "txt", x: x, y: y - 26, life: 0.7); t.text = "JUST GUARD"; t.col = "#fff2a8"; state.hitFx.append(t)
            return
        }
        if g.whiff {   // 앉아 막기: 상단이 머리 위로 지나간다
            for k in 0..<4 {
                var p = HitFx(k: "streak", x: x - f * 4, y: y - 4 + Double(k) * 3, life: 0.16); p.vx = f * (260 + rnd() * 80); p.vy = 0; p.col = "#e8f4ff"; p.a = 0.8; state.hitFx.append(p)
            }
            if now - guardTxtT > 1.0 { guardTxtT = now; var t = HitFx(k: "txt", x: x, y: y - 20, life: 0.55); t.text = "휙"; t.col = "#e8f4ff"; state.hitFx.append(t) }
            return
        }
        if g.pierced { var p = HitFx(k: "gblock", x: x, y: y, life: 0.2); p.f = f; p.red = true; state.hitFx.append(p); return }
        var p = HitFx(k: "gblock", x: x, y: y, life: g.heavy ? 0.24 : 0.18); p.f = f; p.big = g.heavy; p.n = g.stance; state.hitFx.append(p)
        if g.streak == 1 || now - guardTxtT > 1.2 {   // '막!' 은 연속 막기 처음 · 1.2초에 한 번만(글자 홍수 없이)
            guardTxtT = now
            var t = HitFx(k: "txt", x: x - f * 14, y: y + 2, life: 0.5); t.text = g.parry ? "쳐냄!" : "막!"; t.col = g.heroBlocked ? "#9ad8ff" : "#cfe8ff"; state.hitFx.append(t)
        }
    }

    /// 웹 hmTrail(H, k)
    mutating func arcTrail(_ H: SimSnapshot.ActorView, _ k: String) {
        let f = H.flip ? -1.0 : 1
        var p = HitFx(k: "arc", x: H.x + f * 3, y: H.y - (k == "d" ? 44 : 38), life: 0.2); p.f = f; p.kind = k
        state.hitFx.append(p)
    }

    /// 네이티브 퇴근 승천권 지붕 뚫기: 구멍 · 빛 · 파편 · 먼지는 무대 G-버퍼가 그린다(NativeRiseArt — RoofHole 값만 세운다).
    /// 여기선 겹친 피해 숫자(굴러 올라가는 숫자 칸)를 하나로 모아 구멍 옆으로 비킨다(구멍을 가리지 않게) · 종이 회오리 몇 장을 구멍으로 빨아올린다
    mutating func roofFx(_ r: RoofBlast, _ s: SimSnapshot) {
        let x = r.x, f = r.dir == 0 ? 1 : r.dir
        var h = RoofHole(x: x, y: r.y, kind: r.kind); h.f = f
        h.seed = roofRng.nextUInt64()
        h.target = r.target; h.dy0 = s.trainShakeY; h.scroll0 = s.prologue?.x ?? 0
        h.stage = s.stageIndex; h.car = s.car; h.floor = s.tower?.floor ?? -1
        state.roofHoles.removeAll { abs($0.x - x) < 10 }
        state.roofHoles.append(h)
        // 피해 숫자: 구멍 둘레에 쌓인 승천권 숫자(오름 2타 · 꼭대기)를 큰 숫자 하나로 — 날아가는 반대쪽 옆, 천장 띠 아래
        let near = state.pops.indices.filter { abs(state.pops[$0].x - x) < 30 && state.pops[$0].age < 0.6 && state.pops[$0].style != "total" && state.pops[$0].style != "hurt" && state.pops[$0].style != "heal" }
        if let top = near.max(by: { state.pops[$0].value < state.pops[$1].value }) {
            var p = state.pops[top]
            let hx = s.actors.first { $0.isHero }?.x ?? x - f
            let side: Double = x >= hx ? 1 : -1   // 주인공에서 먼 쪽(주인공 · 용 실루엣을 덮지 않게)
            p.x = max(camX + 16, min(camX + visibleWidth - 16, x + side * 40)); p.y = r.kind == "none" ? p.y : r.y + 12
            p.stack = 0; p.vx = side * 4; p.age = 0; p.life = 1.35; p.riseK = 0.55; if !p.counter { p.style = "crit" }
            let ids = Set(near.map { state.pops[$0].id }); state.pops.removeAll { ids.contains($0.id) }
            state.pops.append(p)
        }
        if let i = state.risePapers.lastIndex(where: { $0.age < 0.6 }) { state.risePapers[i].roof = [x, r.y] }
    }
    /// 지붕 위에 떨어지는 '…쿵' — 구멍에서 먼지 한 줌(무대가 그린다 · 구멍이 지워졌으면 글자도 없이)
    mutating func roofThudFx(_ r: RoofBlast) {
        if let i = state.roofHoles.firstIndex(where: { abs($0.x - r.x) < 10 }) { state.roofHoles[i].thud = 0 }
        else if r.kind != "none" { return }   // 다른 칸으로 넘어갔다
        var t = HitFx(k: "txt", x: r.x + 8, y: r.y - 8, life: 0.9); t.text = "…쿵"; t.col = "#e8dcc8"; state.hitFx.append(t)
    }

    // MARK: 이벤트

    /// 한 틱 이벤트(이번 틱 뒤 스냅숏의 인물 위치로 자리를 잡는다)
    public mutating func apply(_ events: [SimEvent], snapshot s: SimSnapshot) {
        let s = s.hudShifted()   // brawl 카메라(charOX)만큼 인물 기준 자리를 민다(HUDModes.swift)
        actors = Dictionary(s.actors.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        camX = s.camX; gsTime = s.time
        func actor(_ id: ActorID) -> SimSnapshot.ActorView? { actors[id] }
        let hero = s.actors.first { $0.isHero }
        let hitWordSpots: [SIMD2<Double>] = events.compactMap { if case .hit(let h) = $0, h.attackerIsHero, !h.heroWasHit { return [h.at.x, h.at.y - 86] }; return nil }
        if let H = hero { dashFx(H, s) }
        for e in events {
            switch e {
            case .damagePop(let t, let v, let style, let label):
                if style == "heal" && v <= 0 { continue }
                guard let A = actor(t) else { continue }
                var v = v
                // 웹 damage(): shown = round(dmg·DMG_K·(.93 + random·.14)) — 타격 숫자만(회복 · 합계는 그대로)
                if style == "hit" || style == "crit" || style == "hurt" { v = max(1, Int((Double(v) * (0.93 + jit.next() * 0.14) + 0.5).rounded(.down))) }
                // 네이티브 굴러 올라가는 숫자: 같은 적이 0.4초 안에 또 맞으면 한 칸의 값이 타격 순간 바로 늘며 튄다(+N 잔상) — 적의 먼 쪽(주인공 반대) 옆 · 가슴 높이
                if catalog.native, A.isEnemy, style == "hit" || style == "crit", let H = hero {
                    let lc: String? = label.map { $0 == "COUNTER" || $0 == "JUST!" ? "#ffe27a" : $0.hasPrefix("BACK") ? "#7ad7ff" : "#ff9a4a" }
                    // 같은 연타 사슬(규칙 comboStep — 이번 틱 타격보다 먼저 온다)이면 1.0초까지, 사슬 정보가 없으면 0.4초까지 한 칸
                    let chained = state.comboLastHit == s.time
                    if let c = counters[t], s.time - c.t <= (chained && c.chain == chainID ? 1.0 : 0.4), let j = state.pops.firstIndex(where: { $0.id == c.pop }) {
                        var p = state.pops[j]
                        p.value += v; p.age = 0; p.popAmp = 0.35; p.life = 1.0; p.hold = 0.35
                        if style == "crit" { p.style = "crit"; p.popAmp = 0.7; p.sizeK = 1 }
                        if let l = label { p.label = l; p.labelCol = lc }
                        p.y = A.y - 44 - A.airOv
                        state.pops[j] = p
                        counters[t] = (c.pop, s.time, c.side, chained ? chainID : -1)
                        if state.combo >= 3 { state.pops[j].tag = "\(state.combo) HIT"; state.pops[j].tagT = 0.85 }   // 칸 밑 작은 'N HIT'(머묾 0.35 + 0.5초)
                        var g = HitFx(k: "nv_ghost_n", x: p.x + c.side * 10, y: p.y - 4, life: 0.3); g.text = "+\(v)"; g.f = c.side; state.hitFx.append(g)
                    } else {
                        let side: Double = A.x != H.x ? (A.x > H.x ? 1 : -1) : (H.flip ? -1 : 1)
                        let cx = max(camX + 14, min(camX + visibleWidth - 14, A.x + side * 26))
                        var y = A.y - 44 - A.airOv
                        for _ in 0..<4 {   // 동시에 맞은 다른 적 칸과 겹치면 위로 비킨다
                            let hitIt = state.pops.contains { q in q.counter && q.age < q.life && abs(q.x - cx) < 26 && abs(q.y - y) < 12 }
                            if !hitIt { break }; y -= 13
                        }
                        var p = HUDState.DamagePop(id: id(), x: cx, y: y, value: v, style: style, label: label, stack: 0, life: 1.0, vx: 0, labelCol: lc)
                        p.counter = true; p.popAmp = style == "crit" ? 0.7 : 0.3; p.sizeK = style == "crit" ? 1 : 0.75; p.hold = 0.35; p.riseK = 0.55
                        state.pops.append(p)
                        counters[t] = (p.id, s.time, side, state.comboLastHit == s.time ? chainID : -1)
                    }
                    state.comboDmg = (state.combo > 1 ? state.comboDmg : 0) + v
                    continue
                }
                // 웹 dmgPop: 같은 대상 0.6초 안이면 한 층 위 · 다른 숫자와 가로로 겹치면 또 위로
                var st0 = 0
                if let p = stack[t], now - p.t < 0.6 { st0 = p.n + 1 }
                stack[t] = (now, min(st0, 5))
                func sOf(_ style: String) -> Double { style == "crit" || style == "total" ? 3 : 2 }
                let w0 = Double(String(v).count) * (5 * sOf(style) - 1), VW = visibleWidth
                let cx = max(camX + w0 / 2 + 3, min(camX + VW - w0 / 2 - 3, A.x))
                var st = min(st0, 5)
                for _ in 0..<4 {
                    let clash = state.pops.contains { p in
                        p.age < 0.6 && p.stack == st && abs(max(camX + 3, min(camX + VW - 3, p.x)) - cx) < (w0 + Double(String(p.value).count) * (5 * sOf(p.style) - 1)) / 2 + 2
                    }
                    if !clash { break }; st += 1
                }
                let lc: String? = label.map { $0 == "COUNTER" || $0 == "JUST!" ? "#ffe27a" : $0.hasPrefix("BACK") ? "#7ad7ff" : "#ff9a4a" }
                // 네이티브: 한 사람 위 숫자 기둥은 둘까지 — 셋째부터는 맨 위 숫자에 더해 다시 튀게(주인공 · 적 몸을 덮는 높은 기둥 없이)
                if catalog.native, style == "hit" || style == "crit" || style == "hurt", st >= 2,
                   let j = state.pops.indices.filter({ abs(state.pops[$0].x - A.x) < 18 && state.pops[$0].age < 0.6 && state.pops[$0].style != "total" && state.pops[$0].style != "heal" }).max(by: { state.pops[$0].stack < state.pops[$1].stack }) {
                    state.pops[j].value += v; state.pops[j].age = min(state.pops[j].age, 0.05)
                    if style == "crit" { state.pops[j].style = "crit" }
                    if style == "hit" || style == "crit" { state.comboDmg = (state.combo > 1 ? state.comboDmg : 0) + v }
                    continue
                }
                state.pops.append(.init(id: id(), x: A.x, y: A.y - 58, value: v, style: style, label: label, stack: min(st, 7),
                                        life: style == "crit" || style == "total" ? 1.35 : 1.05, vx: (rnd() - 0.5) * 14, labelCol: lc))
                if style == "hit" || style == "crit" { state.comboDmg = (state.combo > 1 ? state.comboDmg : 0) + v }
            case .comboStep(let n):
                if n <= 1 { chainID += 1 }
                state.combo = n; state.comboAge = 0; state.comboLastHit = s.time
            case .comboTotal(let hits, let dmg):
                if dmg == 0 {   // 필살기 마무리(웹 spcFinish: 화면 위 가운데 'SPECIAL · 이름')
                    let nm = art?.spc[specialKind]?.n
                    state.pops.append(.init(id: id(), x: 240, y: 70, value: hits, style: "total", label: nm.map { "SPECIAL · \($0)" } ?? "SPECIAL", stack: 0, life: 1.6, vx: 0, labelCol: "#ffe27a"))
                } else if catalog.native, counters.values.contains(where: { $0.t >= state.comboLastHit - 1e-6 }) {
                    // 네이티브: 굴러 올라가는 숫자의 마지막 금색 값이 곧 합계 — 머리 위 'N HIT TOTAL' 숫자는 내지 않는다('N HIT' 는 타격 때 칸 밑에 이미)
                } else if hits >= 3, let H = hero {
                    // 웹 GS.comboDmg = 흔들린 표시값의 합 — HUD 가 같은 값을 쌓아 두었으면 그것으로
                    state.pops.append(.init(id: id(), x: H.x, y: H.y - 104, value: state.comboDmg > 0 ? state.comboDmg : dmg, style: "total", label: "\(hits) HIT TOTAL", stack: 0, life: 1.5, vx: 0, labelCol: "#ffe27a"))
                }
                state.comboDmg = 0
            case .comicReset:   // 웹 comicT=0(강제 글자)
                comicT = -99
            case .comicWord(let word, var x, let y):
                if now - comicT < 0.5 { continue }
                comicT = now
                // 웹 damage(): 타격 만화 글자는 x ± (10 + random·8) — 이번 틱 주인공 타격의 (맞은 x, y−86) 자리로 알아본다
                if hitWordSpots.contains(where: { $0.x == x && $0.y == y }) { x += (jit.next() < 0.5 ? -1 : 1) * (10 + jit.next() * 8) }
                for i in state.words.indices where state.words[i].age < state.words[i].life - 0.1 { state.words[i].age = state.words[i].life - 0.1 }   // 한 번에 하나만
                let p = comicSpot(x, y, word, s)
                state.words.append(.init(id: id(), x: p.x, y: p.y, word: word, rot: (rnd() - 0.5) * 0.3))
            case .speech(let a, let text, let kind):
                if kind != "shout" && now - quipT < 5 { continue }
                if kind != "shout" { quipT = now }
                for i in state.bubbles.indices where state.bubbles[i].actor == a { state.bubbles[i].age = max(state.bubbles[i].age, state.bubbles[i].life - 0.15) }
                var b = HUDState.Bubble(id: id(), actor: a, text: resolve(text), kind: kind, life: kind == "shout" ? 1.8 : 2.4)
                if let A = actor(a) { b.x = A.x; b.y = A.y }
                state.bubbles.append(b)
            case .bark(let a, let key):
                for i in state.bubbles.indices where state.bubbles[i].actor == a { state.bubbles[i].age = max(state.bubbles[i].age, state.bubbles[i].life - 0.15) }
                var b = HUDState.Bubble(id: id(), actor: a, text: resolve(key), kind: "shout", life: 1.8)
                if let A = actor(a) { b.x = A.x; b.y = A.y }
                state.bubbles.append(b)
            case .notice(let title, let body, let sec):
                if title.isEmpty && body.isEmpty { continue }
                state.notice = .init(id: id(), title: title, body: body, life: max(0.8, sec))
            case .statusFlash(let text, let sec):
                state.flash = .init(text: text, life: max(0.3, sec))
            case .textPop(let x, let y, let text):
                // 숫자는 무대 글리프(FxLayer)가 그린다 — 한글은 웹도 글리프가 없어 그리지 않는다(기록만)
                if text.unicodeScalars.contains(where: { $0.value > 0x7F }) { state.textPops.append(.init(id: id(), x: x, y: y, text: text)) }
            case .command(let name, let tag):
                if tag == "sp", let k = art?.spc.first(where: { $0.value.n == name })?.key { specialKind = k }
                let fam = ["fist", "foot", "grap"].contains(tag) ? tag : nil
                state.cmdLog.insert(CmdView(name: name, age: 0, sp: tag == "sp", crit: tag == "crit", link: tag == "link", fam: fam), at: 0)
                if state.cmdLog.count > 5 { state.cmdLog.removeLast(state.cmdLog.count - 5) }
            case .cutIn(let kind, let a, let sec):
                cutDur = max(0.05, sec); cutBoss = kind == "spc" ? nil : a
                if kind == "spc" { faceMood = "shout"; faceUntil = now + 1.6 }
                state.cut = CutView(k: kind, kind: kind == "spc" ? specialKind : nil, boss: a.flatMap { actor($0)?.enemyType }, t: 0, dur: cutDur)
            case .cutInEnded:
                state.cut = nil
            case .bossRage(let a):
                raged.insert(a)
            case .bossBreak(let a):
                if let A = actor(a) {
                    swPush(A.x, A.y - 40, 4, hero?.flip == true ? -1 : 1)
                    breakState = (a, 3.2, 3.2)
                    var p = HitFx(k: "sig_ring", x: A.x, y: A.y - 30, life: 0.6); p.r = 74; state.hitFx.append(p)
                }
            case .hit(let h):
                guard let T = actor(h.target) else { continue }
                hitFx(h, tgt: T)
                // 굴러 올라가는 숫자: 마지막 큰 타(띄움 · 넘어뜨림 · 처치 · 큰 타격 · 승천권 꼭대기)는 크게 튀며 금색(치명은 제 색 그대로)
                if catalog.native, h.attackerIsHero, let c = counters[h.target], let j = state.pops.firstIndex(where: { $0.id == c.pop }), state.pops[j].age == 0,
                   h.big || h.knock || h.dead || h.reactOpt == "launch" || (h.attackerAnim == "nv_rise" && h.reactOpt != "head") {
                    if state.pops[j].style != "crit" { state.pops[j].style = "total" }
                    state.pops[j].popAmp = 0.7; state.pops[j].sizeK = 1
                }
            case .heroHurt(let w):
                faceMood = "flinch"; faceUntil = now + 0.35
                if w == .heavy, let H = hero { var p = HitFx(k: "burst", x: H.x, y: H.y - 44, life: 0.26); p.f = 1; p.n = 12; p.r0 = 7; p.r1 = 34; p.red = true; state.hitFx.append(p) }
            case .justCounter(let t):
                if let T = actor(t), let H = hero {
                    let f: Double = T.x >= H.x ? 1 : -1
                    state.hitFx.append(HitFx(k: "tapok", x: T.x, y: T.y - 34, life: 0.32))
                    if !noFlash { state.hitFx.append(HitFx(k: "chstar", x: T.x - f * 3, y: T.y - 36, life: 0.26)) }
                }
            case .groundImpact(let x, let y, let p):
                groundImpact(x, y, p)
            case .guardBlock(let g): guardFx(g, crash: false)
            case .guardCrash(let g): guardFx(g, crash: true)
            case .roofBlast(let r): roofFx(r, s)
            case .roofThud(let r): roofThudFx(r)
            case .actionCue(let a, _, let cue):
                guard let A = actor(a) else { continue }
                let f = A.flip ? -1.0 : 1
                switch cue {
                case "h_smear", "ut_hit_ft", "r_spin2", "r_smear": arcTrail(A, "h")
                case "hm_dhit": arcTrail(A, "d")
                case "hm_hit": arcTrail(A, "h")
                case "hm_bhit": arcTrail(A, "b")
                case "fk_smear":   // 웹 fkLines
                    for _ in 0..<6 {
                        var p = HitFx(k: "streak", x: A.x - f * (4 + rnd() * 6), y: A.y - 34 + rnd() * 18, life: 0.16 + rnd() * 0.06)
                        p.vx = -f * (300 + rnd() * 160); p.vy = (rnd() - 0.5) * 20; p.col = "#fffbe8"; state.hitFx.append(p)
                    }
                case "sx_lift":
                    var p = HitFx(k: "sxpath", x: A.x - f * 4, y: A.y - 26, life: 0.55); p.r = 36; p.f = f; state.hitFx.append(p)
                // 네이티브 복싱 기술(SimConfig.nativeMoves) — 휘두름 궤적
                case "fl_smear", "ck_smear":   // 채찍 · 비틀어 꽂기: 앞으로 뻗는 속도선
                    for _ in 0..<(cue == "ck_smear" ? 7 : 5) {
                        var p = HitFx(k: "streak", x: A.x + f * (10 + rnd() * 8), y: A.y - 40 + rnd() * 6, life: 0.12 + rnd() * 0.05)
                        p.vx = f * (340 + rnd() * 160); p.vy = (rnd() - 0.5) * 16; p.col = cue == "ck_smear" ? "#ffd2a0" : "#fffbe8"; state.hitFx.append(p)
                    }
                    if cue == "ck_smear" { arcTrail(A, "b") }
                case "lv_smear", "sr_smear": arcTrail(A, "h")
                case "sm_smear": arcTrail(A, "b")
                case "rs_launch":   // 퇴근 승천권: 발밑에서 아래로 빠지는 바람 + 종이 회오리(무대가 그린다) + '칼퇴!'
                    for k in 0..<5 {
                        var q = HitFx(k: "streak", x: A.x + f * (Double(k) * 3 - 6), y: A.y - 20 - Double(k) * 4, life: 0.16); q.vx = 0; q.vy = 260 + Double(k) * 40; q.col = "#fffbe8"; q.a = 0.7
                        state.hitFx.append(q)
                    }
                    if A.isHero {
                        var pp = RisePaper(actor: A.id, f: f, x: A.x, y: A.y); pp.calm = noFlash; pp.seed = roofRng.nextUInt64()
                        state.risePapers.removeAll { $0.actor == A.id }; state.risePapers.append(pp)
                        for i in state.words.indices where state.words[i].age < state.words[i].life - 0.1 { state.words[i].age = state.words[i].life - 0.1 }
                        comicT = now   // 오름 타격 글자가 덮지 않게(꼭대기 '퇴근해라!!'는 강제 글자라 끼어든다)
                        state.words.append(.init(id: id(), x: A.x - f * 30, y: A.y - 92, word: NvRiseText.launch, rot: -f * 0.12, life: 0.5))
                    }
                case "rs_apex": break   // 꼭대기: 섬광은 맞닿은 자리 작은 불꽃 하나(hitFx) — 주먹 끝 큰 섬광 · 고리는 뺐다
                case "sr_roll":   // 숄더 롤: 뒤로 흘리는 바람
                    for _ in 0..<4 {
                        var p = HitFx(k: "streak", x: A.x - f * 6, y: A.y - 46 + rnd() * 12, life: 0.14)
                        p.vx = -f * (180 + rnd() * 80); p.vy = (rnd() - 0.5) * 10; p.col = "#cfe8ff"; state.hitFx.append(p)
                    }
                default: break
                }
            case .fx(let kind, let x, let y, let dir):
                switch kind {
                case let k where (k == "axring" || k == "tsring") && catalog.native: break   // 깃발 켜짐: 바닥 면 픽셀 고리(StageDirector.impact)
                case "axring": var p = HitFx(k: "axring", x: x, y: y, life: 0.6); p.cr = cracks(6, 0.5); state.hitFx.append(p)
                case "tsring": var p = HitFx(k: "tsring", x: x, y: y, life: 0.7); p.cr = cracks(8, 0.6); state.hitFx.append(p)
                case "sxboom":
                    if !noFlash { state.hitFx.append(HitFx(k: "sig_flash", x: x, y: y - 22, life: 0.12)) }
                    state.hitFx.append(HitFx(k: "sxboom", x: x, y: y, life: 0.34))
                case "wave": state.hitFx.append(HitFx(k: "wave", x: x, y: y, life: 0.55))
                case "twfall":
                    var p = HitFx(k: "twfall", x: x, y: y, life: 1.1)
                    p.parts = (0..<9).map { _ in HitFx.Part(vx: (rnd() * 2 - 1) * 50, vy: -(20 + rnd() * 80), s: rnd() < 0.5 ? 1 : 2, c: rnd() < 0.5 ? "#6e726d" : "#2c2a1d") }
                    state.hitFx.append(p)
                case let k where k.hasPrefix("sig_"):
                    let sk = String(k.dropFirst(4)), f = dir == 0 ? 1 : dir
                    // 웹 sigFire: 고유 마무리 — 이중 충격파 + 종류별 그림
                    swPush(x, y, 4, f)
                    if sk == "moon" || sk == "moon2", let H = hero {
                        var p = HitFx(k: "crescent", x: H.x + f * 6, y: H.y - 44, life: 0.34); p.r = 56; p.w = 18; p.f = f; p.a0 = 84 * .pi / 180; p.a1 = -104 * .pi / 180
                        state.hitFx.append(p)
                        if sk == "moon2" { var q = p; q.r = 40; q.w = 12; q.t = -0.08; q.life = 0.3; state.hitFx.append(q) }
                    } else if !(sk == "flash" && noFlash) {
                        var p = HitFx(k: "sig_" + sk, x: x, y: y, life: sk == "stamp" ? 1.1 : 0.6); p.f = f; p.r = art?.sigR[sk] ?? 72
                        state.hitFx.append(p)
                    }
                    if sk == "stamp" {   // 웹 pagesBurst
                        var p = HitFx(k: "pages", x: x, y: y, life: 2.4)
                        p.P = (0..<30).map { k in HitFx.Bit(vx: (k % 2 != 0 ? 1 : -1) * (70 + rnd() * 200), vy: -(30 + rnd() * 140), r: rnd() * 6.3, vr: (rnd() - 0.5) * 14, ph: rnd() * 6) }
                        state.hitFx.append(p)
                    }
                default: break
                }
            case .fxDetail(let d):   // 규칙이 그 자리에서 잰 HITFX(웹 useSkill 큐 · 필살기)
                var p = HitFx(k: d.kind, x: d.x, y: d.y, life: 0.2); p.f = d.dir
                switch d.kind {
                case "crescent": p.life = 0.22; p.r = 34; p.w = 13; p.a0 = 84 * .pi / 180; p.a1 = -104 * .pi / 180
                case "axv": p.y = 0; p.y0 = d.y; p.y1 = d.y1; p.f = nil; p.life = 0.22
                case "cyw": p.r = 9
                case "cystar": p.f = nil; p.life = 0.14; p.s = d.s
                case "swirl": p.f = nil; p.life = d.big ? 0.5 : 0.4; p.ph = Double(d.n); if d.big { p.big = true }
                case "nv_speed", "nv_hook", "nv_finish", "nv_cork": nvFx(d); continue   // 네이티브 막차 러시 · 코크스크루
                case "nv_alert": p.life = 0.75; p.f = nil                                // 네이티브 끼어들기 예고: 머리 위 '!'
                default: break
                }
                state.hitFx.append(p)
            default: break
            }
        }
        if state.hitFx.count > 400 { state.hitFx.removeFirst(state.hitFx.count - 400) }
        if !state.capRound && state.hitFx.contains(where: { $0.k == "streak" }) { state.capRound = true }
    }

    /// 웹 27 dashFx(c, md, start, dt): 주인공이 달리는(runTo — runU 를 매 틱 미는) 동안 0.06초마다 흰 속도선 둘.
    /// 출발 먼지 · whoosh 는 규칙이 낸다. 깃발 켜짐(nativeMoves) 질주도 runU 를 밀어 같이 나온다
    mutating func dashFx(_ H: SimSnapshot.ActorView, _ s: SimSnapshot) {
        defer { dashRunU = H.pose.runU; dashX = H.x; dashTime = s.time }
        guard let ru = H.pose.runU, let t0 = dashTime, ru != dashRunU, ru > s.gameTime else { return }
        let mx = H.x - dashX, md: Double = mx > 0 ? 1 : mx < 0 ? -1 : 0
        guard md != 0 else { return }
        dashAcc += max(0, s.time - t0)
        if dashAcc < 0.06 { return }
        dashAcc = 0
        for _ in 0..<2 {
            var p = HitFx(k: "streak", x: H.x - md * (5 + jit.next() * 6), y: H.y - 12 - jit.next() * 26, life: 0.13 + jit.next() * 0.05)
            p.vx = -md * (140 + jit.next() * 80); p.vy = 0; p.col = "#f4efe2"; p.a = 0.5
            state.hitFx.append(p)
        }
    }

    /// 웹 comicSpot: 인물 몸 · 피해 숫자를 피해 맞은 쪽 옆(머리 높이) → 위쪽 순으로 빈자리 · 화면 안
    func comicSpot(_ x: Double, _ y: Double, _ word: String, _ s: SimSnapshot) -> SIMD2<Double> {
        let tw = Double(word.utf16.count) * 7.4, hw = tw * 0.58 + 10, hh = (tw * 0.58 + 9) * 0.62 + 1
        let live = s.actors.filter { !$0.hidden && !$0.isPassenger && ($0.isEnemy || $0.isHero) && abs($0.x - x) < 100 }
        func box(_ a: SimSnapshot.ActorView) -> [Double] { [a.x - 12, a.y - 58 - a.airOv, a.x + 12, a.y + 2] }
        var B = live.map(box)
        for p in state.pops where p.age < p.life && abs(p.x - x) < 100 {
            let S = p.scale, hw2 = Double(String(p.value).count) * (5 * S - 1) * 0.6 + 4, top = p.y - Double(p.stack) * (7 * S + 3) - 10 - (p.label != nil ? 10 : 0)
            B.append([p.x - hw2, top, p.x + hw2, p.y + 7 * S + 4])
        }
        let H = s.actors.first { $0.isHero }
        let T = live.filter { $0.id != H?.id }.min { abs($0.x - x) < abs($1.x - x) } ?? live.first
        let cx0 = T?.x ?? x
        var dir = 1.0
        if let T, let H, T.id != H.id { let d = T.x - H.x; dir = d > 0 ? 1 : d < 0 ? -1 : 1 }
        let top = live.isEmpty ? y : live.map { box($0)[1] }.min()!
        let L = camX + hw + 2, R = camX + visibleWidth - hw - 2
        func fit(_ cx: Double, _ cy: Double) -> SIMD2<Double> { [max(L, min(R, cx)), max(hh + 3, cy)] }
        func ov(_ cx: Double, _ cy: Double) -> Double {
            B.reduce(0) { s, b in s + max(0, min(cx + hw, b[2]) - max(cx - hw, b[0])) * max(0, min(cy + hh, b[3]) - max(cy - hh, b[1])) }
        }
        let C: [(Double, Double)] = [(cx0 + dir * (hw + 14), top + hh - 2), (cx0 + dir * (hw + 14), top - hh * 0.3), (cx0 - dir * (hw + 14), top + hh - 2), (cx0 - dir * (hw + 14), top - hh * 0.3),
                                     (cx0 + dir * (hw * 0.5), top - hh - 14), (cx0, top - hh - 26), (cx0 - dir * (hw * 0.5), top - hh - 40), (cx0, top - hh - 56)]
        var best: SIMD2<Double>?, bo = 1e9
        for (cx, cy) in C { let q = fit(cx, cy), o = ov(q.x, q.y); if o <= 0 { return q }; if o < bo { bo = o; best = q } }
        return best ?? fit(x.isFinite ? x : camX + visibleWidth / 2, y.isFinite ? y : 120)
    }

    // MARK: 시간

    /// 화면 시간 진행 + 스냅숏 값(체력 · 게이지 · 행동 줄) 반영. dt = 실제 프레임 초
    public mutating func advance(dt: Double, snapshot s: SimSnapshot) {
        let s = s.hudShifted()
        modeTracker.advanceLamps(dt: dt * playSpeed, on: showCarOn(s)); modeTracker.advanceDojo(s)
        let rdt = dt * playSpeed, hdt = rdt   // 웹 drawDmg: rdt = min(.1, 실제)·속도, dt = min(.05, rdt) — 끊김 보정 자르기는 생략(60Hz 에선 같다)
        let gdt = max(0, s.time - gsTime)
        now += dt
        camX = s.camX; gsTime = s.time
        state.state = s.state
        // 체력 · 지연 체력(웹 GS.lagH — 규칙이 lagH += (hp − lagH)·min(1, dt·2.5) 로 민다)
        state.hp = s.hp; state.maxHP = max(1, s.maxHP); state.lagHP = s.lagH
        state.special = min(100, s.special); state.score = s.score; state.tokens = s.tokens; state.kills = s.kills
        state.comboAge += dt
        if state.comboAge > 2.4 { state.combo = 0 }
        state.comboRouteName = s.comboName
        for i in state.pops.indices { state.pops[i].age += hdt; if state.pops[i].tagT > 0 { state.pops[i].tagT -= hdt } }; state.pops.removeAll { $0.age > $0.life }
        for i in state.words.indices { state.words[i].age += hdt }; state.words.removeAll { $0.age > $0.life }
        for i in state.textPops.indices { state.textPops[i].age += dt }; state.textPops.removeAll { $0.age > $0.life }
        for i in state.cmdLog.indices { state.cmdLog[i].age += dt }; state.cmdLog.removeAll { $0.age > 4.5 }
        for i in state.bubbles.indices {
            state.bubbles[i].age += hdt
            if let A = s.actors.first(where: { $0.id == state.bubbles[i].actor }) {
                state.bubbles[i].x = A.x; state.bubbles[i].y = A.y
                if A.hidden || (A.isEnemy && A.hp <= 0) { state.bubbles[i].age = max(state.bubbles[i].age, state.bubbles[i].life - 0.2) }
            }
        }
        state.bubbles.removeAll { $0.age > $0.life }
        // HITFX: 나이 · 물방울 물리(웹 drawHitFx 가 그리며 민다)
        for i in state.hitFx.indices {
            state.hitFx[i].t += hdt
            if state.hitFx[i].k == "drop" {
                state.hitFx[i].vy = (state.hitFx[i].vy ?? 0) + 420 * hdt
                state.hitFx[i].x += (state.hitFx[i].vx ?? 0) * hdt; state.hitFx[i].y += (state.hitFx[i].vy ?? 0) * hdt
            }
        }
        state.hitFx.removeAll { $0.t >= $0.life }
        for i in state.roofHoles.indices { state.roofHoles[i].age += hdt; if let t = state.roofHoles[i].thud { state.roofHoles[i].thud = t + hdt } }
        for i in state.risePapers.indices { state.risePapers[i].age += hdt }; state.risePapers.removeAll { $0.age > 3.2 }
        let fl = s.tower?.floor ?? -1   // 칸 · 층 · 노선이 바뀌면 구멍을 지운다(새 칸은 멀쩡한 천장)
        state.roofHoles.removeAll { $0.car != s.car || $0.stage != s.stageIndex || $0.floor != fl || !s.on }
        for i in state.critFx.indices { state.critFx[i].t += hdt }; state.critFx.removeAll { $0.t >= 0.16 }
        state.shockwaves.removeAll { !(s.time < $0.t0 + $0.life && s.time > $0.t0 - 1) }
        if let m = state.smear, s.time - m.t0 >= m.life || s.time - m.t0 < -1 { state.smear = nil }
        if var n = state.notice { n.age += dt; state.notice = n.age > n.life ? nil : n }
        if var f = state.flash { f.age += dt; state.flash = f.age > f.life ? nil : f }
        if var b = state.banner { b.age += dt; state.banner = b.age > b.life ? nil : b }
        // 컷인: 시뮬레이션이 민 진행(웹은 그리기가 민다 — 규칙이 쓰는 값이라 Sim 이 갖는다)
        if let k = s.cutKind {
            if state.cut == nil || state.cut?.k != k { state.cut = CutView(k: k, kind: k == "spc" ? specialKind : nil, boss: cutBoss.flatMap { actors[$0]?.enemyType }, t: 0, dur: cutDur) }
            let d = state.cut?.dur ?? cutDur; state.cut?.t = s.cutProgress * d
        } else { state.cut = nil }
        // 칸 이동: 통로 문(웹 startBoard 의 GS.wipe)
        if let c = lastCar, s.car == c + 1, s.on { state.wipe = WipeView(t: 0, label: "→ \(s.car + 1)호차") }
        lastCar = s.car
        if var w = state.wipe { w.t += rdt; state.wipe = w.t >= 0.5 ? nil : w }
        // 두목 무너짐 · 두목 막대 지연 · 레터박스
        if var b = breakState { b.t -= gdt; breakState = b.t > 0 && (actors[b.actor].map { $0.hp > 0 } ?? false) ? b : nil }
        for a in s.actors where a.isBoss { let k = max(0, a.hp) / max(1, a.maxHP); let l = bossLag[a.id] ?? k; bossLag[a.id] = l + (k - l) * (1 - pow(0.94, dt * 60)) }
        let lt: Double = s.specialActive || s.camZoom > 1.001 || s.prologue != nil ? 1 : 0   // 웹 47: … || GS.prologue
        lbox += (lt - lbox) * min(1, rdt * 8)
        // 행동 줄(웹 abUpdate)
        let st = s.stageIndex, ci = s.car
        let short = st < catalog.stageShort.count ? catalog.stageShort[st] : ""
        let car = st < catalog.cars.count && ci < catalog.cars[st].count ? catalog.cars[st][ci] : (name: "", stop: nil)
        state.line = "\(short) · \(ci + 1)호차 · \(car.name)"
        let nf = s.actors.filter { $0.isEnemy && !$0.hidden && $0.hp > 0 }.count
        func nm(_ k: String?) -> String { k.flatMap { catalog.stations[$0] } ?? "" }
        if let at = s.atStop { state.sub = "정차 중 · 적 \(nf) · \(nm(at))" }
        else { let left = max(0, Int((s.legDur - s.legT).rounded(.up))); state.sub = "\(left)초 · 적 \(nf) · \(nm(car.stop))까지" }
        if let T = s.tower {   // 엘리베이터 타워(웹 abUpdate 타워 갈래)
            state.line = "타워 · \(T.floor)F"
            state.sub = "정원 \(T.weight)/\(Int(T.limit)) · 적 \(nf) · 최고 \(max(T.best, T.floor))F"
            state.progress = min(1, max(0, T.progress)); return
        }
        state.progress = s.atStop == nil && ["fight", "arrive", "board", "final"].contains(s.state) ? min(1, s.legT / max(1, s.legDur)) : 1
    }

    // MARK: 오버레이 프레임 값

    /// drawUI 가 읽는 값(웹 GS · CAMX · VW …) — 스냅숏 · 카메라 출력에서
    public func frame(_ s: SimSnapshot, view: StageView, shake: Double, manual: Bool? = nil) -> HUDFrame {
        let s = s.hudShifted()
        var F = HUDFrame()
        F.vw = view.visibleWidth; F.h = view.sceneHeight; F.w = view.sceneWidth
        F.camX = view.cameraX; F.viewZ = view.zoom; F.viewC = [view.zoomCenter.x, view.zoomCenter.y]; F.shv = shake
        F.now = now; F.time = s.time
        if catalog.native { F.dmgScale = HUDState.nativeDmgScale }
        F.on = s.on || !s.actors.isEmpty
        let H = s.actors.first { $0.isHero }
        F.hero = H != nil; F.heroX = H?.x
        F.lbox = lbox
        F.tower = s.tower != nil; F.bonus = s.bonus != nil
        let foes = s.actors.filter { $0.isEnemy && !$0.hidden && $0.hp > 0 }
        if let art, s.stageIndex < art.stages.count {
            let S = art.stages[s.stageIndex]
            F.stageColor = S.color
            F.stops = S.stops.enumerated().map { i, id in
                HUDFrame.Stop(label: art.stationCap[id] ?? "", here: s.atStop == id, passed: i < s.leg && s.atStop != id, next: s.nextStop == id && s.atStop == nil)
            }
            let end = s.car < S.ends.count ? S.ends[s.car] : false
            if (s.state == "fight" && !end) || s.arriving { F.timeBar = max(0, 1 - s.legT / max(1e-6, s.legDur)) }
        }
        F.score = s.score; F.foesLeft = foes.count; F.manual = manual ?? (s.manualT > 0)   // 웹 GS.manualT > 0 → MANUAL
        let r = s.hp / max(1, s.maxHP), tr = faceUntil > now ? faceMood : nil
        let m = tr ?? (r > 0.7 ? "" : r > 0.4 ? "strain" : r > 0.15 ? "hurt" : "crit")
        F.portrait = "face:hero" + (m.isEmpty ? "" : "_" + m)
        F.portraitDX = tr == "flinch" ? (Double(Int(now * 60) % 3) - 1) : 0
        F.hp = s.hp; F.max = s.maxHP; F.lagH = s.lagH; F.sp = s.special
        F.justW = s.justW; F.fade = s.fade
        F.bagSlow = s.bagSlowT > 0 && s.inCombat   // 웹 정리 중 테두리
        if s.duckWarn, let H, Int((s.time * 8).rounded(.down)) % 2 == 0 { F.duck = [H.x, H.y] }   // 웹 DUCK 경고(깜빡임 8Hz)
        if let W = s.tapWindow, W.target != nil { F.tapW = .init(x: W.x, y: W.y + 34, t: W.t) }   // 웹 GS.tapW.T.d
        if let B = foes.first(where: { $0.isBoss && (art?.bossInfo[$0.enemyType ?? ""] != nil) }), let t = B.enemyType {
            F.boss = .init(t: t, hp: B.hp, max: max(1, B.maxHP), raged: raged.contains(B.id), lag: bossLag[B.id] ?? max(0, B.hp) / max(1, B.maxHP))
        }
        if let H, let m = H.guardMeter, H.guardStance > 0 || H.guardSince < 1 || H.guardCrash { F.heroGuard = [H.x, H.y, Double(H.guardStance), m, H.guardSince] }
        F.foes = foes.map { a in
            var f = HUDFrame.Foe(x: a.x, y: a.y, hp: a.hp, max: max(1, a.maxHP))
            f.boss = a.isBoss; f.bossInfo = art?.bossInfo[a.enemyType ?? ""] != nil
            f.hasAction = a.tellWeight != nil; f.w = a.tellWeight; f.tt = a.timeToCue
            if let m = a.guardMeter { f.gd = [Double(a.guardStance), m, a.guardSince, a.guardCrash ? 1 : 0, a.cutInTell ? 1 : 0] }
            return f
        }
        F.flash = state.flash?.text
        F.stagger = foes.filter { $0.pose.anim == "stagger" || $0.pose.anim == "staggerX" }.map { [$0.x, $0.y - 48 - $0.airOv, s.gameTime * 5.5] }
        if let b = breakState, let A = actors[b.actor] { F.bossBreak = .init(x: A.x, y: A.y, k: max(0, b.t / b.T0)) }
        F.doze = s.actors.filter { $0.isPassenger && !$0.hidden && $0.idleProp == "doze" }.map { a in [a.x, a.y, (now * 0.6 + a.x * 0.013).truncatingRemainder(dividingBy: 1)] }
        if s.combo >= 2 { F.combo = .init(n: s.combo, since: s.time - (s.lastHit ?? 0), win: s.comboWin, dmg: s.comboDmg) }   // 웹 GS.combo · lastHit · comboWin() · comboDmg
        F.skin = skin; F.shades = shades; F.noFlash = noFlash; F.modeBadge = modeBadge
        F.modes = modesFrame(s)
        return F
    }

    /// 판을 새로 시작할 때
    public mutating func reset() {
        let keep = (catalog, art, playSpeed, visibleWidth, noFlash, skin, shades, modeBadge)
        self = HUDDirector(catalog: keep.0, art: keep.1)
        playSpeed = keep.2; visibleWidth = keep.3; noFlash = keep.4; skin = keep.5; shades = keep.6; modeBadge = keep.7
    }
}
