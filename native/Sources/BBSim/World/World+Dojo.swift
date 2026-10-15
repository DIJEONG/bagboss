import Foundation
import BBCore
import BBContent

// 웹 42-dojo.js(동작 무도장 · 콤보 실험실) + 08-art-dojo.js 규칙 부분(DJ 상태 · djTick 소품 충돌 · djJolt · DJ_POLES) + 13/15 스킨 미리보기(skinPvOpen · skinPvTick · skinPvClose).
// 무도장은 실전과 같은 경로(useSkill · damage · strapAir · foeStrike)로 동작을 재생한다 — 허수아비(dojo)는 막기 · 피하기를 끄고(dojoOff) 체력 99999.
// 패널 UI(탭 · 칩 끌기 · 속도 단추)는 표현 몫: 앱은 SimIntent.dojo(DojoCommand) 로 웹 djDo 와 같은 명령을 보낸다.
// 건널목 배경(DJ.bg 'cross' — xcTick: 전차 · 단풍)은 규칙 효과가 없어 표현 몫(소품 충돌도 웹처럼 'dojo' 배경에서만).

/// 무도장 한 단계(웹 [id, comboIdx?, 'scoop'?] · '@strap' = 손잡이 공중전)
public struct DojoStep: Sendable, Equatable {
    public var id: String
    public var combo: Int?
    public var scoop = false
    public init(_ id: String, _ combo: Int? = nil, scoop: Bool = false) { self.id = id; self.combo = combo; self.scoop = scoop }
    init?(json v: JSONValue) {
        guard let a = v.array, let id = a.first?.string else { return nil }
        self.id = id; combo = a.count > 1 ? a[1].int : nil; scoop = a.count > 2 && a[2].string == "scoop"
    }
    /// 웹 ccToStep('punch:0' · 'upper:scoop' · 'kick')
    public init(cc v: String) {
        let p = v.split(separator: ":", maxSplits: 1).map(String.init)
        id = p[0]
        if p.count > 1 { if p[1] == "scoop" { scoop = true } else { combo = Int(p[1]) } }
    }
}

/// 무도장 명령(웹 djDo 의 data-* 단추와 패널 단추)
public enum DojoCommand: Sendable, Equatable {
    /// 무도장 들어가기(웹 startDojo — 허수아비 종류 · 이어 하기 저장은 건드리지 않는다) · 나가기(웹 stopDojo → 새 판, 이어 하기는 앱이 Sim.resume)
    case start(dummy: String?), stop
    /// 콤보 시연 k(웹 DOJO.combo) · 주인공 기술(웹 dojoHero(id, combo)) · 기타 동작 · 필살기(fist/foot/grap) · 허수아비 반응 · 적 공격
    case combo(Int), hero(String, combo: Int?), misc(String), special(String), react(String), foe(String)
    /// 지금 가방의 콤보 경로 k(웹 dojoBagRoute) · 커스텀 콤보 실행(웹 dojoCustomRun) · 커스텀 순서 바꾸기(웹 GS.cc — 'punch:0' 꼴, 최대 CC_MAX)
    case bagRoute(Int), customRun, setCustom([String])
    /// 예시 가방 넣기(웹 dojoDemoBag) · 위치 초기화(웹 dojoReset(24)) · 상대 바꾸기(웹 dojoSetDummy)
    case demoBag(Int), reset, dummy(String)
    /// 반복(웹 DJ.rep) · 확대(웹 DJ.zoom 1/1.5/2) · 배경(dojo · cross) · 멈춘 채 한 프레임(웹 GS.stepReq)
    case loop(Bool), zoom(Double), background(String), step
    /// 부서지는 소품(네이티브 · World+NativeObj): 놓기(종류 · x — nil 이면 허수아비 뒤) · 옮기기 · 치우기 · 모두 치우기 · 모두 복구 · 저장본 통째로 놓기
    case objAdd(String, Double?), objMove(Int, Double), objRemove(Int), objClear, objRepair, objSet([DojoObjSpec])
    /// 치명타 켜기 · 끄기(네이티브 무도장 — 끄면 '항상 치명' 아이템도 치명이 없다)
    case crit(Bool)
}

/// 스킨 미리보기 명령(웹 skinPvOpen · skinPvClose · 자세 편집기 V.play/V.fixed/V.view/V.z1)
public enum SkinPreviewCommand: Sendable, Equatable {
    case open, close
    /// 동작 전체 재생(웹 V.play) · 한 자세 고정(웹 V.fixed — nil 이면 해제) · 보기 회전(도) · 확대 끔(z1)
    case play(String), fixed(String?), view(Double), z1(Bool)
}

/// 웹 GS.dojoSeq
final class DojoSeq {
    let steps: [DojoStep]
    var i = 0, t = 0.0
    let name: String
    let custom: Bool, single: Bool
    var hits: [Int: Int] = [:]
    var airs: Set<Int> = []
    var maxH = 0.0
    var cur: Int?
    init(steps: [DojoStep], name: String, custom: Bool, single: Bool) { self.steps = steps; self.name = name; self.custom = custom; self.single = single }
}
/// 웹 DJ + 무도장 GS 값(dojoPole · cc · ccRes)
final class DojoState {
    var seq: DojoSeq?
    var pole = false
    var hit: DojoView.Hit?
    var last: DojoCommand?
    var rep = false, repT = 0.0
    var zoom = 1.0, bg = "dojo", dummyType = "punk"
    var stepReq = 0
    var cc: [String] = ["punch:3", "punch:0", "punch:1", "punch:2", "round"]   // 웹 ccLoad 기본값(저장은 앱 몫)
    var ccRes: [String]?
    var result: String?
    // 08-art-dojo 소품(표현용 스프링 · 깨짐)
    var sign = (a: 0.0, v: 0.0), lamps = [(a: 0.0, v: 0.0), (a: 0.0, v: 0.0)], bagS = (a: 0.0, v: 0.0)
    var mook = 0.0, drum = 0.0, brd = false, rack = false
    var walkers: [DojoView.Walker] = []
    var wt = 2.0
    /// 부서지는 소품(네이티브 — 사용자가 놓는다) · 번호 · 이번 비행에 이미 부딪힌 '적번호:소품번호'
    var objs: [DojoObj] = [], objSeq = 0, objHits: Set<String> = []
    /// 치명타 켜짐(네이티브 무도장 — DojoCommand.crit)
    var crit = true
    /// 웹 djReset()
    func reset() { sign = (0, 0); lamps = [(0, 0), (0, 0)]; bagS = (0, 0); mook = 0; drum = 0; brd = false; rack = false }
}
/// 웹 GS.skinPv
final class SkinPv {
    var t = 0.0, ph = -1
    let x: Double, y: Double, flip: Bool, wpn: String?, fade: Double
    let hid: [Actor]
    let cx: Double
    var wq: [Double]?
    var spin = 0.0
    var play: String?, playing = false
    /// 자세 편집기 '질주' 재생: 제자리 달리기 남은 초(시퀀스가 없는 동작 — 보폭 위상으로 그린다)
    var runT = 0.0
    var fixed: String?
    var view = 0.0, z1 = false
    init(x: Double, y: Double, flip: Bool, wpn: String?, fade: Double, hid: [Actor], cx: Double) { self.x = x; self.y = y; self.flip = flip; self.wpn = wpn; self.fade = fade; self.hid = hid; self.cx = cx }
}

extension World {
    /// 웹 dojoDummy()
    func dojoDummy() -> Actor? { ents.first { $0.e != nil && $0.dojo } }
    /// 무도장 전용 가방 칸(웹 { id, uid, t, tier, x:0, y:0, rot:0, combo:0, last:-9 })
    func dojoItem(_ id: String, _ uid: Int, t: Double, tier: Int, combo: Int? = 0, last: Double? = -9) -> Item {
        let it = Item(id: id, uid: uid, tier: tier, opt: nil); it.t = t; it.combo = combo; it.last = last; return it
    }

    // MARK: 시작 · 끝

    /// 웹 startDojo(): 개발 시작(이어 하기 · 노선 기록을 건드리지 않는다) → 무도장 · 허수아비
    func startDojo(_ dummy: String? = nil) {
        let keep = config; startRun(devStart: true); config = keep
        pr = nil
        let S = dj ?? DojoState(); if let d = dummy { S.dummyType = d }
        demo = true; dj = S
        setState("fight")
        for a in ents where a !== hero { retire(a) }
        ents = [hero]; cans = []; items = []; shots = []; ev = nil; wave = 99; nextWaveAt = 1e9; departT = 0; tr.phase = "stop"; tr.v = 0
        maxHP = 9999; hp = 9999; ents.append(dojoMakeDummy(S.dummyType)); S.hit = nil; S.last = nil; S.repT = 0; S.stepReq = 0
        let H = hero!; H.x = 250; H.flip = false; H.hidden = false; H.wpn = nil; setAnim(H, "idle")
        playSpeed = 1; paused = false   // 웹 setGameSpeed(1)
        emit(.storyBeat("dojo"))
    }
    /// 웹 stopDojo(): 나가면 새 판(이어 하기 저장이 있으면 앱이 Sim.resume 으로 되돌린다)
    func stopDojo() {
        demo = false; dj?.rep = false; dj?.stepReq = 0; dj = nil
        startRun(); playSpeed = config.playSpeed
        emit(.storyBeat("dojoEnd"))
    }
    /// 웹 dojoMakeDummy(t): 막기 · 피하기를 끈 허수아비(체력 99999)
    func dojoMakeDummy(_ t0: String) -> Actor {
        let t = data.enemy(t0) != nil ? t0 : "punk"
        let T = data.enemy(t)!
        let e = Enemy(t: t, def: T, hp: 99999, dmg: T.dmg, cd: T.cd, cdT: 0); e.dojoOff = true
        let D = mkActor(defFor(T, 0), x: 274, z: 0, flip: true, pose: "st0", remap: T.remap, e: e)
        D.dojo = true; setAnim(D, "idle"); return D
    }
    /// 웹 dojoSetDummy(t)
    func dojoSetDummy(_ t: String) {
        guard data.enemy(t) != nil, let S = dj else { return }
        S.dummyType = t
        let old = ents.filter { $0.e != nil && $0.dojo }; old.forEach(retire)
        ents = ents.filter { !($0.e != nil && $0.dojo) }; ents.append(dojoMakeDummy(t)); S.hit = nil; dojoReset(24)
    }

    // MARK: 재생

    /// 웹 dojoReset(dx, down): 둘을 제자리에(허수아비는 dx 만큼 떨어져)
    func dojoReset(_ dx: Double, _ down: Bool = false) {
        guard let H = hero, let D = dojoDummy() else { return }
        cut = nil; spc = nil; slowT = 0
        dj?.seq = nil; dj?.pole = false; dj?.reset()
        for c in [H, D] {
            c.action = nil; c.queue = []; c.dash = 0; c.dashT = 0; c.kb = 0; c.airOv = 0; c.hs = 0; c.heldBy = nil; c.heldT0 = nil
            c.dead = false; c.hidden = false; c.flash = 0; c.jug = nil; c.legRun = false
        }
        H.x = 250; H.flip = false; setAnim(H, "idle")
        D.x = 250 + dx; D.flip = dx > 0; D.e!.hp = 99999; D.e!.max = 99999; D.e!.stun = 0; D.after = nil
        setAnim(D, down ? "down" : "idle"); if down { D.pose = "kd5" }
    }
    /// 웹 dojoHero(id, combo): 실전처럼 허수아비 자리로 다가가 친다(뒤 공격 · 선 채 밟기는 자리를 맞춰 바로)
    func dojoHero(_ id: String, _ combo: Int?) {
        guard let D = dojoDummy(), hero != nil else { return }
        if nv && nvDojoHero(id, combo) { return }   // 네이티브: 시연 조건(눕히기 · 띄우기 · 거리)을 먼저 맞춘다(World+NativeDojo)
        let back = item(id)?.back == true
        if !back && !(id == "stomp" && !data.falls.contains(D.anim) && D.jug == nil) {
            bag = [dojoItem(id, 9900, t: 99, tier: 2)]
            dj?.seq = DojoSeq(steps: [DojoStep(id, combo)], name: "", custom: false, single: true); return
        }
        dojoHeroReset(id, combo)
    }
    /// 웹 dojoHeroReset(id, combo)
    func dojoHeroReset(_ id: String, _ combo: Int?) {
        let gap = id == "fkick", back = item(id)?.back == true, rc = item(id)?.reach ?? 24
        dojoReset(gap ? 85 : back ? -max(12, rc - 6) : id == "throw" ? 18 : max(12, min(rc > 30 ? rc - 6 : 24, rc - 3)), id == "stomp")
        guard let D = dojoDummy() else { return }
        bag = [dojoItem(id, 9900, t: 99, tier: 2, combo: combo != nil ? (combo! + 3) % 4 : 0, last: combo != nil && combo! > 0 ? time : -9)]
        if combo == 0 { bag[0].last = -9 }
        useSkill(0, D, true)
    }
    /// 웹 dojoCombo(k)
    func dojoCombo(_ k: Int) { guard sd.dojoCombo.indices.contains(k) else { return }; let C = sd.dojoCombo[k]; dojoRun(C.steps, C.name) }
    /// 웹 dojoCustomRun()
    func dojoCustomRun() {
        guard let S = dj, !S.cc.isEmpty else { return }
        S.ccRes = nil; dojoRun(S.cc.map(DojoStep.init(cc:)), "커스텀 콤보", true)
    }
    /// 웹 dojoRun(steps, name, custom): 단계마다 실전과 같은 경로(useSkill)로 친다
    func dojoRun(_ steps: [DojoStep], _ name: String, _ custom: Bool = false) {
        guard let first = steps.first else { return }
        dojoReset(first.id == "throw" ? 18 : first.id == "umb" ? 36 : 20)
        guard let D = dojoDummy(), let H = hero else { return }
        if steps.contains(where: { $0.id == "@strap" }) {   // 손잡이 아래에서 시작
            let sx = stableSortD(data.strapX) { abs($0 - 250) - abs($1 - 250) }[0]; H.x = sx; D.x = sx + 20
        }
        var ids: [String] = []; for s in steps where !s.id.hasPrefix("@") && !ids.contains(s.id) { ids.append(s.id) }
        bag = ids.enumerated().map { n, id in dojoItem(id, 9910 + n, t: 99, tier: 2) }
        dj?.seq = DojoSeq(steps: steps, name: name, custom: custom, single: false)
        dj?.pole = name.contains("기둥"); if dj?.pole == true { H.x = 318; D.x = 342 }
        if !nv { say(custom ? "커스텀 콤보" : "콤보 시연", name, 1.4) }   // 네이티브: 화면 가운데 알림을 띄우지 않는다(감독 2026-10-14 — 화면을 가린다)
    }
    /// 웹 dojoResult(S): 단계별 적중 · 공중 · 최고 높이
    func dojoResult(_ S: DojoSeq) {
        let n = S.steps.count, hit = S.steps.indices.filter { (S.hits[$0] ?? 0) > 0 }.count, air = S.steps.indices.filter { S.airs.contains($0) }.count
        let txt = "\(n)타 중 \(hit)타 적중 · 공중 \(air)타 · 최고 \(jsRoundI(S.maxH))"
        dj?.result = txt
        if S.custom { dj?.ccRes = S.steps.indices.map { (S.hits[$0] ?? 0) > 0 ? (S.airs.contains($0) ? "air" : "hit") : "miss" } }
        emit(.dojoResult(text: txt))
        if !S.single && !nv { say(S.name.isEmpty ? "콤보" : S.name, txt, 2.2) }   // 네이티브: 결과는 패널(dj.result)에만
    }
    /// 웹 dojoDummyTick(dt): 날아가면 일어나 주인공 앞으로 걸어와 멈춘다
    func dojoDummyTick(_ dt: Double) {
        if nv { nvDojoKeepAlive() }   // 네이티브: 무도장 주인공은 죽지 않는다(I8)
        guard let D = dojoDummy(), let H = hero, !D.dead, !D.held, D.jug == nil else { return }
        if nv && dj?.seq != nil && D.anim == "walk" { setAnim(D, "idle") }   // 네이티브: 시연 중엔 허수아비가 마중 오지 않는다(접근 거리감)
        if D.anim == "idle" || D.anim == "walk" {
            if nv && dj?.seq != nil { return }
            let dx = H.x - D.x, d = abs(dx)
            if d > 30 { face(D, H.x); moveTo(D, H.x - jsSign(dx) * 22, 70, dt) } else if D.anim == "walk" { setAnim(D, "idle"); face(D, H.x) }
        }
    }
    /// 웹 dojoSeqTick(dt)
    func dojoSeqTick(_ dt: Double) {
        guard let S = dj?.seq, let H = hero, let D = dojoDummy() else { dj?.seq = nil; return }
        S.t += dt; S.maxH = max(S.maxH, D.jug?.h ?? 0)
        if S.i >= S.steps.count { if (S.t > 1.4 && D.jug == nil) || S.t > 4 { dojoResult(S); dj?.seq = nil }; return }
        if S.t > 6 { dojoResult(S); dj?.seq = nil; return }   // 안전장치
        let st = S.steps[S.i], id = st.id, air = D.jug != nil
        if nv && S.single && id == "stomp" && !air && isFalling(D) && !isDown(D) { return }   // 네이티브 단독 밟기: 바닥에 눕고 나서
        if id == "@strap" {
            if !(air && D.jug!.h >= 20) { return }
            if !canAct(H) { if let A = H.action, A.fired, !heroAirborne(H) { H.action = nil; H.queue = []; setAnim(H, "idle") } else { return } }
            let sx = stableSortD(data.strapX) { abs($0 - H.x) - abs($1 - H.x) }[0]
            if H.anim == "walk" { setAnim(H, "idle") }
            S.cur = S.i; strapAir(H, D, abs(sx - H.x) < 40 ? sx : H.x); S.i += 1; S.t = 0; return
        }
        if id == "stomp" && air && (D.jug!.h > 30 || D.jug!.vy > 0) { return }   // 밟기는 떨어지며 낮아질 때
        guard let it = item(id) else { S.i += 1; return }
        let busy = !canAct(H), cancel = busy && (H.action?.fired ?? false) && !heroAirborne(H) && (air || data.falls.contains(D.anim))
        if busy && !cancel { return }
        if air && D.jug!.h > 60 { return }   // 너무 높으면 내려올 때까지
        let base: Double = it.combo == true ? (st.combo.flatMap { [0, 1, 2, 3].contains($0) ? data.moveReach[["jab", "cross", "hook", "upper"][$0]] : nil } ?? .nan) : (it.reach ?? .nan)
        let rc = base + (air ? 8 : 0), dx = D.x - H.x, d = abs(dx)
        if id == "fkick" {   // 날아차기: 거리를 벌렸다가 날아든다
            if d < 34 { if busy { return }; moveTo(H, D.x - (dx == 0 ? 1 : jsSign(dx)) * 72, heroSpd() * 1.8, dt); return }
            if d > 110 { if busy { return }; face(H, D.x); moveTo(H, D.x - jsSign(dx) * 80, heroSpd() * 1.8, dt); return }
        } else if d > rc + 5 && id != "charge" {
            if busy { if heroAirborne(H) { return }; H.action = nil; H.queue = []; setAnim(H, "idle") }   // 공중 동작은 내려앉은 뒤에 다가간다
            face(H, D.x); approach(H, D.x - jsSign(dx) * max(data.sepHF, rc - 4), heroSpd() * 1.8, dt, heroSpd() * 3.4); return
        }
        if busy { H.action = nil; H.queue = []; setAnim(H, "idle") }
        guard let bi = bag.firstIndex(where: { $0.id == id }) else { S.i += 1; return }
        let b = bag[bi]; b.t = 99
        if it.combo == true { b.combo = ((st.combo ?? 0) + 3) % 4; b.last = time }
        if st.scoop { H.scoopNext = true }
        if H.anim == "walk" { setAnim(H, "idle") }
        S.cur = S.i; face(H, D.x); useSkill(bi, D, true); S.i += 1; S.t = 0
    }
    /// 웹 dojoMisc(k): 쭈그리기 · 기둥 회전차기 · 매달려 차기 · 장도리 동작(피해 없이 동작만)
    func dojoMisc(_ k: String) {
        guard let H = hero else { return }
        if nv && nvDojoMisc(k) { return }   // 네이티브: 기둥 · 손잡이 옆에서(World+NativeDojo)
        dojoReset(30)
        if k == "duck" { bag = [dojoItem("duck", 9901, t: 99, tier: 1, combo: nil, last: nil)]; heroDuck(true); return }
        if k.hasPrefix("hm_") { requestAction(H, k, ActionReq(cue: data.jwCue[k], wpn: "w_hammer") { _ in }); return }
        requestAction(H, k, ActionReq { _ in })
    }
    /// 웹 dojoSpc(fam): 필살기(가방 계열 하나 · 게이지 100)
    func dojoSpc(_ fam: String) {
        dojoReset(30)
        bag = [dojoItem(["fist": "punch", "foot": "kick", "grap": "knee"][fam] ?? "punch", 9902, t: 0, tier: 2, combo: nil, last: nil)]
        sp = 100; _ = trySpecial()
    }
    /// 웹 dojoReact(r): 허수아비 반응 동작
    func dojoReact(_ r: String) {
        guard let D = dojoDummy(), let H = hero else { return }
        if nv { nvDojoReact(r); return }   // 네이티브: 읽기 좋은 거리 · 꽂기는 높이에서(World+NativeDojo)
        dojoReset(24); face(D, H.x); setAnim(D, r)
        if ["fall", "launch", "rKick", "rSpin", "rSwept", "rCharge", "rSlam", "rStomp", "crumple"].contains(r) { D.after = "getup" }
        if r == "rSpike" { D.after = "getupP" }
    }
    /// 웹 dojoFoe(mv): 허수아비가 주인공을 공격(가방엔 쭈그리기만)
    func dojoFoe(_ mv: String) {
        let gap = mv == "fkick"
        dojoReset(gap ? 85 : max(12, wpnReach(mv, data.enemy("punk")?.wpn) - 4))
        guard let D = dojoDummy() else { return }
        D.e!.cdT = 0; bag = [dojoItem("duck", 9903, t: 99, tier: 1, combo: nil, last: nil)]; manualT = 9; foeStrike(D, mv)
    }
    /// 웹 dojoBagRoute(k): 지금 가방의 콤보 경로 시연(주먹 콤보는 잽 → 크로스 → 훅 → 어퍼 순)
    func dojoBagRoute(_ k: Int) {
        let R = rules.routes(bagStructs()); guard R.indices.contains(k) else { return }
        var pc = 0
        let steps = R[k].uids.compactMap { u in bag.first { $0.uid == u }?.id }.map { id -> DojoStep in
            if id == "punch" { defer { pc += 1 }; return DojoStep("punch", pc % 4) }; return DojoStep(id)
        }
        dojoRun(steps, R[k].name)
    }
    /// 웹 dojoDemoBag(k): 예시 가방 넣기
    func dojoDemoBag(_ k: Int) {
        guard !sd.demoBags.isEmpty else { return }
        let D = sd.demoBags.indices.contains(k) ? sd.demoBags[k] : sd.demoBags[0]
        bag = D.L.filter { item($0.id) != nil }.map { s in let it = newItem(s.id, 1, nil); it.x = s.x; it.y = s.y; it.rot = s.rot; return it }
        renderBag()
        if nv { maxHP = 9999; hp = 9999 }   // 네이티브: renderBag 이 체력을 heroMax(120)로 되돌리던 것(I8 — 웹 같음)
    }
    /// 웹 djDo(a): 재생 명령(마지막 것은 반복용으로 기억)
    func djDo(_ c: DojoCommand) {
        nvObjRepair(force: false)   // 네이티브 소품: 깨진 것은 다음 시연에서 다시 선다
        switch c {
        case .combo(let k): dojoCombo(k)
        case .hero(let id, let combo): dojoHero(id, combo)
        case .misc(let k): dojoMisc(k)
        case .special(let f): dojoSpc(f)
        case .react(let r): dojoReact(r)
        case .foe(let mv): dojoFoe(mv)
        case .bagRoute(let k): dojoBagRoute(k)
        case .customRun: dojoCustomRun()
        default: break
        }
    }
    /// SimIntent.dojo — 웹 무도장 패널 클릭 처리
    func dojoCommand(_ c: DojoCommand) {
        switch c {
        case .start(let d): startDojo(d)
        case .stop: if demo { stopDojo() }
        case .combo, .hero, .misc, .special, .react, .foe, .bagRoute, .customRun:
            guard demo, let S = dj else { return }
            if nv { nvDojoRevive() }   // 네이티브: 시연마다 체력을 채우고, 쓰러져 있었다면 일으킨다(I8)
            S.last = c; S.repT = 0; djDo(c)
        case .setCustom(let L): dj?.cc = Array(L.prefix(sd.ccMax)); dj?.ccRes = nil
        case .demoBag(let k): if demo { dojoDemoBag(k) }
        case .reset: if demo { dojoReset(24); dj?.hit = nil }
        case .dummy(let t): if demo { dojoSetDummy(t) }
        case .loop(let on): dj?.rep = on; dj?.repT = 0
        case .zoom(let z): dj?.zoom = z
        case .background(let b): dj?.bg = b
        case .step: if paused && demo { dj?.stepReq += 1 }
        case .objAdd, .objMove, .objRemove, .objClear, .objRepair, .objSet: nvObjCommand(c)
        case .crit(let on): dj?.crit = on
        }
    }
    /// 웹 render-loop: 멈춘 채 한 프레임(1/animFps)씩 — stepAnim 한 번 + gameUpdate 4번
    func djStepFrame() {
        guard let S = dj, paused, on, S.stepReq > 0 else { return }
        S.stepReq -= 1
        let s1 = 1 / animFps
        stepAnim(); for _ in 0..<4 { gameUpdate(s1 / 4) }
    }
    /// 웹 djRepTick(dt): 반복 — 둘 다 가만히 선 채 0.8초 지나면 마지막 동작을 다시
    func djRepTick(_ dt: Double) {
        guard let S = dj, S.rep, let last = S.last, let H = hero, let D = dojoDummy() else { return }
        let calm = S.seq == nil && spc == nil && cut == nil && canAct(H) && H.anim == "idle" && D.jug == nil && !D.held && D.anim == "idle" && !(D.action != nil && !D.action!.fired)
        if !calm { S.repT = 0; return }
        S.repT += dt; if S.repT > 0.8 { S.repT = 0; djDo(last) }
    }
    /// 웹 djMoveName(): 지금 기술 이름(마지막 타격 표시)
    func djMoveName() -> String {
        if let u = curSrc, let b = bag.first(where: { $0.uid == u }), let it = item(b.id) { return it.name }
        return hero?.anim ?? ""
    }

    // MARK: 08-art-dojo 소품

    /// 웹 djJolt(p): 간판 · 전등이 흔들린다(연출 수열)
    func djJolt(_ p: Double) {
        guard let S = dj else { return }
        func r() -> Double { fxRnd() < 0.5 ? -1 : 1 }
        S.sign.v += r() * (0.22 + p * 0.28)
        for k in S.lamps.indices { S.lamps[k].v += r() * (0.4 + p * 0.5) }
    }
    /// 웹 djTick(dt): 소품 스프링 · 지나가는 행인(표현) · 날아간 허수아비가 소품에 부딪힘(규칙: 저글 속도가 줄어든다)
    func djTick(_ dt: Double) {
        guard let S = dj else { return }
        if S.bg == "cross" || S.bg == "snow" || S.bg.hasPrefix("beach") { return }   // 건널목(xcTick) · 눈 승강장 · 해변(네이티브)은 표현 몫
        func spring(_ s: inout (a: Double, v: Double), _ k: Double, _ c: Double) { s.v += (-k * s.a - c * s.v) * dt; s.a += s.v * dt }
        spring(&S.sign, 26, 2.4); for k in S.lamps.indices { spring(&S.lamps[k], 18, 1.6) }; spring(&S.bagS, 7, 0.55)
        S.mook = max(0, S.mook - dt); S.drum = max(0, S.drum - dt)
        S.wt -= dt
        if S.wt <= 0 { let left = fxRnd() < 0.5; S.walkers.append(.init(x: left ? 96 : 384, v: (left ? 1 : -1) * (9 + fxRnd() * 7), um: fxRnd() < 0.35, t: 0)); S.wt = 4 + fxRnd() * 6 }
        for k in S.walkers.indices { S.walkers[k].x += S.walkers[k].v * dt; S.walkers[k].t += dt }
        S.walkers = S.walkers.filter { $0.x > 80 && $0.x < 400 }
        guard let D = dojoDummy(), let J = D.jug else { dojoDummy()?.djHit = nil; return }
        let spd = abs(J.vx); if D.djHit == nil { D.djHit = [] }
        if spd < 90 { return }
        for P in sd.djProps {
            if D.djHit!.contains(P.id) || abs(D.x - P.x) > P.hw || J.h > P.top { continue }
            D.djHit!.insert(P.id)
            let f = J.vx == 0 ? 1 : jsSign(J.vx), y = D.y - 20 - J.h
            if P.id == "bag" { S.bagS.v += f * min(3.2, spd / 90); comicSFX(P.x, y - 20, "THUD!") }
            else if P.id == "mook" { S.mook = 0.45; fx("debris", P.x, D.y - 24); comicSFX(P.x, y - 16, "CLACK!"); J.vx *= 0.55 }
            else if P.id == "brd" && !S.brd { S.brd = true; fx("debris", P.x, D.y - 42); comicSFX(P.x, y - 24, "CRACK!"); J.vx *= 0.8 }
            else if P.id == "drum" { S.drum = 0.55; comicSFX(P.x, y - 20, "BOOM!"); shake(2.2) }
            else if P.id == "rack" && !S.rack { S.rack = true; fx("debris", P.x, D.y - 20); comicSFX(P.x, y - 16, "CLATTER!"); J.vx *= 0.7 }
            sfx("clack"); djJolt(0.8)
        }
    }

    // MARK: 스킨 미리보기(15-skin-chars · 13-rig-grammar)

    /// 웹 skinPvOpen(): 세상은 멈추고 주인공만 화면 가운데 스튜디오에
    func skinPvOpen() {
        if !on || hero == nil { startDojo() }
        guard let H = hero, skinPv == nil else { return }
        if talkRun != nil { tkSkip() }
        let P = SkinPv(x: H.x, y: H.y, flip: H.flip, wpn: H.wpn, fade: fade, hid: ents.filter { $0 !== H && !$0.hidden }, cx: jsRound(W / 2))
        skinPv = P; H.wpn = nil
        P.hid.forEach { $0.hidden = true }
        H.flip = false; H.x = P.cx; H.y = jsRound(self.H * 0.47 + 34); setAnim(H, "idle")
    }
    /// 웹 skinPvClose()
    func skinPvClose() {
        guard let P = skinPv else { return }
        P.hid.forEach { $0.hidden = false }
        if let H = hero { H.x = P.x; H.y = P.y; H.flip = P.flip; H.wpn = P.wpn; H.seqOv = nil; setAnim(H, "idle") }
        skinPv = nil; camZ = 1; fade = P.fade
    }
    /// 웹 skinPvTick(dt): 서기 → 좌우로 걷기 → 몸짓(gx_스킨) → 한 바퀴 돌기 → 돌려차기(9.2초 주기)
    func skinPvTick(_ dt: Double) {
        guard let P = skinPv else { return }
        guard let Hh = hero else { skinPvClose(); return }
        P.t += dt; let t = P.t.truncatingRemainder(dividingBy: 9.2); fade = 0
        if P.play == "nv_run" {   // 자세 편집기: 질주(시퀀스 없음 — 걷기 동작 + 질주 표시 runU + 보폭 위상 gph 를 질주 속도로 돌린다) 2초 제자리 달리기
            if !P.playing { P.playing = true; P.runT = 2.0; Hh.x = P.cx; Hh.flip = false; setAnim(Hh, "walk") }
            P.runT -= dt; Hh.x = P.cx; Hh.runU = gameTime + 0.09; Hh.gph += 156 * dt / 62; Hh.anim = "walk"
            if P.runT <= 0 { P.play = nil; P.playing = false; setAnim(Hh, "idle") }
            camZ = P.z1 ? 1 : 3; camC = SIMD2(P.cx / W, (Hh.y - 34) / H); return
        }
        if let play = P.play {   // 자세 편집기: 동작 전체 재생
            if !P.playing { P.playing = true; Hh.x = P.cx; Hh.flip = false; setAnim(Hh, play) } else if Hh.anim == "idle" { P.play = nil; P.playing = false }
            camZ = P.z1 ? 1 : 3; camC = SIMD2(P.cx / W, (Hh.y - 34) / H); return
        }
        if let fx0 = P.fixed {   // 한 자세로 고정해 크게 본다(공중 자세는 카메라도 함께 올라간다)
            if Hh.anim != "__hold" || Hh.pose != fx0 { Hh.seqOv = ("__hold", [SStep(fx0, 999_999)]); setAnim(Hh, "__hold"); Hh.prev = fx0 }
            Hh.x = P.cx; Hh.flip = false; camZ = P.z1 ? 1 : 3
            camC = SIMD2(Hh.x / W, (Hh.y - 34 - (data.poses[live: fx0]?.air ?? 0)) / H); return
        }
        let ph = t < 1.2 ? 0 : t < 3.6 ? 1 : t < 5.6 ? 2 : t < 7.8 ? 3 : 4
        if ph != P.ph {
            P.ph = ph; P.wq = ph == 1 ? [P.cx + 16, P.cx - 16, P.cx] : nil
            if ph != 1 { Hh.x = P.cx; Hh.flip = false }
            setAnim(Hh, ph == 2 ? "gx_" + config.skin : ph == 4 ? "round" : "idle")
        }
        if ph == 1, let q = P.wq, let tx = q.first {   // 실제로 걸어서 보폭이 맞는다
            if abs(Hh.x - tx) < 1.5 { P.wq!.removeFirst(); if P.wq!.isEmpty { Hh.flip = false; setAnim(Hh, "idle") } }
            else { Hh.flip = tx < Hh.x; moveTo(Hh, tx, 34, dt) }
        }
        P.spin = ph == 3 ? (t - 5.6) / 2.2 : 0
        camZ = 3; camC = SIMD2(Hh.x / W, (Hh.y - 34) / H)
    }
    /// SimIntent.skinPreview
    func skinPreviewCommand(_ c: SkinPreviewCommand) {
        switch c {
        case .open: skinPvOpen()
        case .close: skinPvClose()
        case .play(let a): if let P = skinPv { P.play = a; P.playing = false }
        case .fixed(let p): if let P = skinPv { P.fixed = p; P.play = nil; P.playing = false; if p == nil, let H = hero { H.seqOv = nil; setAnim(H, "idle"); P.ph = -1 } }
        case .view(let v): skinPv?.view = v
        case .z1(let z): skinPv?.z1 = z
        }
    }
}
