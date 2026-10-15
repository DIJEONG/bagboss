import Foundation
import BBContent
import BBAnim

// 웹 액터 객체(mkActor) · 적 상태(e) · 저글(jug) · 동작 요청(action) · 가방 아이템을 그대로 옮긴 참조 타입.
// 웹 코드가 객체 정체성(indexOf · ===)에 기대므로 값 타입이 아니라 클래스로 둔다. World 안에서만 쓴다(Sendable 아님).

/// 인물 정의(웹 d = {...JW_HERO|JW_THUG|JW_BOSS|NOIR_THUG}) 중 규칙이 읽는 것 + 그리기 열쇠
struct ActorDef {
    /// 정의 이름: JW_HERO · JW_THUG · JW_BOSS · NOIR_THUG
    var key: String
    var name: String
    /// 3D 동작 표(JW_SEQ) 사용 · 시퀀스 길이 ms · MMA 옛 표
    var jw: Bool, msT: Bool, mma: Bool
    /// 생김새 열쇠(웹 defFor 의 LOOK_CACHE 키: hair|fat|coat|boss|tie|mandarin) — 없으면 기본 모델
    var look: String?
    /// 승객 모델 번호(웹 def.model3 = PASS_MODEL[…]) — 표현이 고른다
    var passModel: Int?
    static func hero() -> ActorDef { ActorDef(key: "JW_HERO", name: "존", jw: true, msT: true, mma: true) }
    static func passenger(model: Int? = nil) -> ActorDef { var d = ActorDef(key: "NOIR_THUG", name: "승객", jw: false, msT: false, mma: true); d.passModel = model; return d }
}

/// 웹 requestAction 의 opts — cue 자세에 들어서는 순간 onCue, cues[자세] 는 그 자세마다 한 번
final class ActionReq {
    var cue: String?
    var onCue: ((Actor) -> Void)?
    var cues: [String: (Actor) -> Void] = [:]
    var firedCues: Set<String> = []
    var wpn: String?
    /// 저스트 예고(첫 준비 자세에 더하는 초)
    var tell: Double = 0
    var fired = false
    init(cue: String? = nil, wpn: String? = nil, tell: Double = 0, onCue: ((Actor) -> Void)? = nil) {
        self.cue = cue; self.wpn = wpn; self.tell = tell; self.onCue = onCue
    }
}

/// 적 상태(웹 a.e = { t, ...ETYPES[t], hp, dmg, cd, cdT, … })
final class Enemy {
    let t: String
    let def: EnemyDef
    var hp: Double, max: Double, dmg: Double, cd: Double, spd: Double
    var cdT: Double, shieldT = 0.0, stun = 0.0
    var next: String?
    var flankAt = 0.0, flankHit = false, fl = false
    var retreatT = 0.0
    var raged = false, brk = 0, stagD = false
    var shotsRange: Double? { def.range }
    var boss: Bool { def.boss == true }
    var heavy: Bool { def.heavy == true }
    var shield: Bool { !dojoOff && def.shield == true }
    var parry: Bool { !dojoOff && def.parry == true }
    var evade: Double? { dojoOff ? 0 : def.evade }
    /// 무도장 허수아비(웹 dojoMakeDummy: shield · parry · evade 를 끈다)
    var dojoOff = false
    var hitrun: Bool { def.hitrun == true }
    var wpn: String? { def.wpn }
    var moves: [String] { def.moves }
    var dash: Double? { def.dash }
    var meat: Bool { def.meat == true }
    var lamp: Bool { def.lamp == true }
    var pan: Bool { def.pan == true }
    /// 타워 특수 행동 상태(수리 기사 · 회계사 · 주방장 · 청소부 · 관리인 — World+Tower)
    var tw = TowerFoe()
    init(t: String, def: EnemyDef, hp: Double, dmg: Double, cd: Double, cdT: Double) {
        self.t = t; self.def = def; self.hp = hp; self.max = hp; self.dmg = dmg; self.cd = cd; self.cdT = cdT; self.spd = def.spd
    }
}

/// 공중 콤보 상태(웹 t.jug)
final class Jug {
    var h: Double, vy: Double, vx: Double
    var n = 0, pts: Double
    var spin = 0.0, spinR = 0.0, roll = 0.0, rollT: Double, rollR = 0.0, jerkT: Double
    var up: String, fall: String
    var bounced = false, hitT = 0.0, t = 0.0, drag: Double, forceB: Bool, trip: Bool
    var src: Int?
    var gk: Double?
    var kv = 0.0, kick = 0.0
    var die = false
    var gb = false, gbReady = false, gbSrc: Int?
    var wallB = false, wallP = 0.0
    var px: Double?
    /// 퇴근 승천권 지붕 뚫기: 천장을 뚫고 화면 위로 날아간다(중력 없이 빨라지며 돈다 — 화면 밖에서 사라진다)
    var roofOut = false
    /// 네이티브 무릎 올려치기 날림(World+NativeVF): 몸을 눕히는 목표 회전(바퀴 — nil = 웹 그대로) · 가로 속도 감쇠(초당 남는 비율 — nil = 웹 0.02)
    var nvRollT: Double?, nvKeep: Double?
    /// 네이티브 결재 쌍장 날림(World+NativeOffice): 벽에 닿으면 박힌다 · 서류가방 내려찍기: 바닥 튕김 때 충격파 · 더 높이
    var nvWall = false, nvSlam = false
    init(h: Double, vy: Double, vx: Double, pts: Double, rollT: Double, jerkT: Double, up: String, fall: String, drag: Double, forceB: Bool, trip: Bool, src: Int?) {
        self.h = h; self.vy = vy; self.vx = vx; self.pts = pts; self.rollT = rollT; self.jerkT = jerkT; self.up = up; self.fall = fall
        self.drag = drag; self.forceB = forceB; self.trip = trip; self.src = src
    }
}

/// 쉬는 동작(웹 H.rest)
struct RestState { var mode: String; var x: Double; var t = 0.0; var door: Double?; var on = false; var said = false }

final class Actor {
    let id: ActorID
    var def: ActorDef
    // d
    var x: Double, y: Double, flip: Bool
    // 시퀀스 진행
    var anim = "idle", si = 0, hold = 6
    var pose: String, prev: String?
    var k = 0, phaseN = 6
    var flash = 0.0, blink = false
    var hidden = false, dead = false, keepBody = false
    var remap: Int
    var wpn: String?
    var grammar: [String: Int]?
    var action: ActionReq?
    var queue: [(anim: String, opts: ActionReq)] = []
    var after: String?
    var seqOv: (anim: String, seq: [SStep])?
    // 몸
    var z: Double, kb = 0.0
    var e: Enemy?
    var gph = 0.0
    var pass: Bool
    var tilt = 0.0, tiltS = 0.0
    var hs = 0, hs0 = 0, shkA = 1.0, shk = 0.0
    var lastMove: String?, windup: Double?
    var heldBy: Actor?, heldT0: Double?
    /// 네이티브 잡기 붙이기 상태(World+NativeGrab — 깃발 켜짐만)
    var nvHold: NvHold?
    var jug: Jug?
    var spike: (h0: Double, t: Double, dur: Double)?
    var airOv = 0.0, dash = 0.0, dashT = 0.0, runU = 0.0
    var rest: RestState?
    var pick: Int?
    var scoopNext = false
    var guardW = 0.0
    var landP: String?
    var bowlT = 0.0, bwx: Double?, bwt: Double?
    var slipT = 0.0, tripLandT: Double?
    var finKill = false, sigKill = false
    var wallT: Double?
    var legRun = false
    var uid: Int?
    /// 네이티브 이동 상태(SimConfig.nativeMoves — World+NativeMove)
    var nvm = NvMove()
    /// 네이티브 공방 상태(가드 · 공격권 · 대기 자리 — World+NativeGuard · NativeCrowd)
    var nvg = NvGuard()
    // 승객 · 댄서
    var passPose: String?, idleAct: String?
    var goal: Double?, goalZ: Double?, exiting = false
    var handDX: Double?, strapX: Double?
    var dancer = false, filming = false
    var ringSeen = false
    /// 마지막으로 그린 자세(웹 c.lastP — 그리기가 남긴 값을 규칙이 읽는다: 자동 착지 다리 판단)
    var lastP: Pose?
    /// 그리기 상태(lastP 계산용 — 웹 drawChar0 가 들고 다니는 값)
    var drawState: ActorPose?
    var isHero = false
    /// 보너스: 피해 측정용 숨은 허수아비(웹 carDummy · invis) · 차 주인(carOwner) — AI · 벽 · 몸 밀기에서 빠진다
    var carDummy = false, carOwner = false, invis = false
    // ---- K(프롤로그 · 스토리 · 무도장)에서 더함 ----
    /// 프롤로그 콤보 쇼 대상(웹 a.sc — CORR_WAVES 의 쇼 열쇠) · 케인(웹 a.kane) · 무도장 허수아비(웹 a.dojo)
    var sc: String?
    var kane = false, dojo = false
    /// 무도장 소품에 이미 부딪힌 것(웹 D._djHit)
    var djHit: Set<String>?

    init(id: ActorID, def: ActorDef, x: Double, y: Double, flip: Bool, z: Double, pose: String, remap: Int, grammar: [String: Int]?, e: Enemy?, pass: Bool) {
        self.id = id; self.def = def; self.x = x; self.y = y; self.flip = flip; self.z = z
        self.pose = pose; self.prev = pose; self.remap = remap; self.grammar = grammar; self.e = e; self.pass = pass
    }
    var held: Bool { heldBy != nil }
    /// 웹 c.d.flip ? -1 : 1
    var f: Double { flip ? -1 : 1 }
}

/// 가방 · 보류함 아이템(웹 GS.bag/GS.stash 항목 — 같은 객체가 오간다)
final class Item {
    let id: String
    let uid: Int
    var tier: Int
    var x = 0, y = 0, rot = 0
    var opt: ItemOption?
    var sx: Int?, sy: Int?
    var pin: Int?
    var t = 0.0
    // 실행 중 표시(웹 b.combo · b.last · b.emp · b.opener · b.linkMark · b.isNew)
    var combo: Int?
    var last: Double?
    var emp = false, opener = false, linkMark = false, isNew = false
    init(id: String, uid: Int, tier: Int, opt: ItemOption?) { self.id = id; self.uid = uid; self.tier = tier; self.opt = opt }
    var bagItem: BagItem {
        var b = BagItem(id: id, uid: uid, tier: tier, x: x, y: y, rot: rot, opt: opt)
        b.sx = sx; b.sy = sy; b.pin = pin; b.t = t
        return b
    }
}
