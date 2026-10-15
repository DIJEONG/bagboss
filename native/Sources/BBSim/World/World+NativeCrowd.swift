import Foundation
import BBContent

// 네이티브 공방 ① 군중 인공지능 — '쿵후 영화의 원'(docs/08 — SimConfig.nativeMoves && nativeGuard. 꺼지면 웹 foeAI 그대로).
//  · 공격권(토큰): 주인공 앞 · 뒤 쪽마다 1개(D 노선 1~4호차 · 타워 6층까지) · 2개(그 뒤 · 4 노선부터). 덩치 · 두목은 2칸을 쓴다.
//    공격권을 쥔 적만 붙어서 친다(연타 1~2번) — 웹 '둘 이상 붙으면 64px 에서 기다림' 규칙 대신.
//  · 공격권 넘김: 연타를 마쳤거나 맞아서(경직 · 띄움 · 넘어짐) 놓으면 한 걸음 물러선다 → 0.3~0.6초 숨 고르기 뒤 다음 적에게.
//    주인공이 등을 보인 쪽은 숨 고르기가 반(예고는 그대로 — 언제나 보고 막을 수 있다). 공격권을 쥔 적은 쿨다운 ×0.8(압박 유지).
//  · 대기하는 적: 쪽마다 48 · 66 · 84 · 102px 자리(서로 겹치지 않게)에서 가드를 올리고, 앞뒤로 셔플 · 가끔 페인트(파고드는 척)
//    · 몇몇은 도발. 병 던지는 놈은 계속 던지고, 치고 빠지는 놈은 페인트를 더 자주(들락날락).
//  · 상황 읽기: 주인공이 다른 적에게 긴 콤보 · 큰 기술을 쓰는 중이면 대기하던 적이 끼어들기를 노린다 — 무릎을 들어 바닥을 구르는
//    긴 예고(머리 위 '!')가 있어 탭 받아치기 기회. 주인공이 넘어지거나 일어나는 중이면 반 걸음 물러선다(몰매 없음).
//  · 협공(flankCall)은 양쪽 공격권 주인끼리 맞추는 박자 이벤트가 된다.
// 규칙 난수는 깃발 켜짐 경로에서만 쓴다.

extension World {
    /// 쪽마다 공격권 수(D 노선 1~4호차 · 타워 6층까지 1 · 그 뒤와 4 노선부터 2 — 감독 결정: 4 노선은 2개)
    func nvTokenCap() -> Int {
        if tower { return (tw?.floor ?? 1) >= 7 ? 2 : 1 }
        return stageIdx >= 1 || ci >= 4 ? 2 : 1
    }
    func nvTokenCost(_ a: Actor) -> Int { a.e?.heavy == true || a.e?.boss == true ? 2 : 1 }
    /// 군중 규칙을 따르는 적(병 던지는 놈 · 보너스 차 · 케인 · 타워 특수 행동 중 제외)
    func nvCrowdFoe(_ a: Actor) -> Bool {
        guard let e = a.e else { return false }
        return (e.def.range ?? 0) == 0 && !a.kane && !a.carDummy && !a.carOwner && !a.hidden && !e.tw.towerBusy
    }
    /// 주인공이 넘어졌거나 일어나는 중
    func nvHeroDown(_ H: Actor) -> Bool { data.falls.contains(H.anim) || H.anim == "getup" || H.anim == "getupP" || H.anim == "down" }
    func nvSideIdx(_ s: Double) -> Int { s < 0 ? 0 : 1 }

    /// 매 틱(적 인공지능 앞): 공격권 놓기 · 주기 · 대기 자리 · 끼어들기 · 게이지 회복 · 측정
    func nvCrowdTick(_ dt: Double) {
        guard let H = hero else { return }
        nvInit(H)
        nvGuardTick(dt)
        if H.dead || demo { return }
        let F = foes().filter(nvCrowdFoe)
        for a in F { nvInit(a) }
        let cap = nvTokenCap(), down = nvHeroDown(H)
        // ① 놓기 · 끼어들기 정리
        for a in F {
            let e = a.e!, hurt = a.held || a.jug != nil || data.falls.contains(a.anim)
            if a.nvg.cut > 0 {
                if hurt || e.stun > 0 || (data.reacts.contains(a.anim) && a.anim != "parry") || (a.nvg.cut == 3 && a.action == nil && canAct(a)) { a.nvg.cut = 0; a.nvg.backUntil = time + 0.6 }
                else if a.nvg.cut == 1 && a.pose == "ci_st1" && !a.nvg.cutStomp { a.nvg.cutStomp = true; groundImpact(a.x + a.f * 4, a.y, 0.5); fx("dust", a.x, a.y, a.f) }
            }
            guard a.nvg.tok else { continue }
            let s: Double = a.x >= H.x ? 1 : -1
            if hurt || e.stun > 0.25 || e.retreatT > 0 { nvRelease(a, step: !hurt) }
            else if s != a.nvg.tokSide && abs(a.x - H.x) > 12 { nvRelease(a, step: false) }        // 반대쪽으로 넘어감
            else if a.nvg.strikes <= 0 && a.action == nil && canAct(a) { nvRelease(a, step: true) } // 연타 끝
        }
        // ② 주기 · 대기 자리
        for si in 0..<2 {
            let s: Double = si == 0 ? -1 : 1
            let side = F.filter { ($0.x >= H.x ? 1.0 : -1.0) == s }
            let used = side.filter { $0.nvg.tok }.reduce(0) { $0 + min(cap, nvTokenCost($1)) }
            if used >= cap || down { continue }
            let waiting = side.filter { a in !a.nvg.tok && a.nvg.cut == 0 && nvCanTakeToken(a) }
            if waiting.isEmpty { continue }
            if nvc.grantAt[si] == nil { nvc.grantAt[si] = time + nvGrantDelay(s) + (used > 0 ? 0.6 : 0) }
            guard time >= nvc.grantAt[si]! else { continue }
            let room = cap - used, last = nvc.lastRel[si]
            let cands = waiting.filter { min(cap, nvTokenCost($0)) <= room }
            guard let pick = stableSortD(cands, { a, b in
                func sc(_ x: Actor) -> Double { abs(x.x - H.x) + (x.id == last && waiting.count > 1 ? 70 : 0) }
                return sc(a) - sc(b)
            }).first else { continue }
            nvGrant(pick, s)
            nvc.grantAt[si] = nil
        }
        nvCutInCheck(H, F, down)
        // 대기 자리(공격권 · 끼어들기를 정한 뒤): 쪽마다 가까운 순으로 36 · 55 · 74 …(공격권 주인 · 끼어드는 적은 빼고 — 서로 겹치지 않게).
        // 적이 많아 칸 끝까지 모자라면 간격을 줄이고(최소 17px — 인물 몸통 폭만큼), 그래도 넘치면 자리를 칸 끝 너머(화면 밖 근처)까지 17px 씩 이어 놓는다.
        for s in [-1.0, 1.0] {
            let wait = stableSortD(F.filter { ($0.x >= H.x ? 1.0 : -1.0) == s && !$0.nvg.tok && $0.nvg.cut == 0 }, { abs($0.x - H.x) - abs($1.x - H.x) })
            let room = (s > 0 ? AW1() - 2 - H.x : H.x - AW0() - 2) - NativeContent.Crowd.slot0
            let gap = wait.count > 1 ? max(NativeContent.Crowd.slotMin, min(NativeContent.Crowd.slotGap, room / Double(wait.count - 1))) : NativeContent.Crowd.slotGap
            for (k, a) in wait.enumerated() { a.nvg.slot = NativeContent.Crowd.slot0 + gap * Double(k) }
        }
    }

    /// 측정: 동시 공격자(공격 동작 중인 적 — 던지기 포함). 깃발 켜짐이면 공방 층과 상관없이 센다(전/후 비교) — 난수 · 상태를 건드리지 않는다
    func nvSampleAttackers() {
        let all = foes()
        guard !all.isEmpty else { return }
        let n = all.filter { $0.action != nil && data.foeW[$0.anim] != nil }.count
        stats.nvg.atkSum += Double(n); stats.nvg.atkTicks += 1; stats.nvg.atkMax = max(stats.nvg.atkMax, n)
        if n > 0 { stats.nvg.atkBusy += 1; if n >= 2 { stats.nvg.atkPile += 1 } }
    }

    /// 숨 고르기(초): 0.3~0.6 · 주인공이 등을 보인 쪽은 반
    func nvGrantDelay(_ s: Double) -> Double {
        let d = NativeContent.Crowd.grantMin + NativeContent.Crowd.grantSpread * rnd()
        return hero.map { $0.f != s } == true ? d * 0.5 : d
    }
    func nvCanTakeToken(_ a: Actor) -> Bool {
        guard let e = a.e else { return false }
        return (canAct(a) || World.nvBlockAnims.contains(a.anim)) && !a.held && a.jug == nil && !(e.stun > 0) && !(e.retreatT > 0) && time >= a.nvg.crashUntil
    }
    func nvGrant(_ a: Actor, _ s: Double) {
        guard let e = a.e else { return }
        a.nvg.tok = true; a.nvg.tokSide = s; a.nvg.guardUntil = -9; a.nvg.backUntil = -9
        let fast = e.cd <= 1.8
        a.nvg.strikes = nvTokenCost(a) >= 2 ? 1 : 1 + (rnd() < (fast ? 0.45 : 0.25) ? 1 : 0)   // 연타 1~2번(빠른 적이 더 자주 2번)
        stats.nvg.grants += 1
        if nvIsGuardAnim(a.anim) { setAnim(a, "idle") }
    }
    /// 공격권 놓기(step = 한 걸음 물러선다) — 그쪽 다음 공격권은 숨 고르기 뒤
    func nvRelease(_ a: Actor, step: Bool) {
        guard a.nvg.tok, let H = hero else { return }
        let si = nvSideIdx(a.nvg.tokSide)
        a.nvg.tok = false; a.nvg.relAt = time; a.nvg.strikes = 0; a.nvg.guardUntil = -9
        if step { a.nvg.backUntil = time + 0.6 }
        nvc.lastRel[si] = a.id
        nvc.grantAt[si] = time + nvGrantDelay(a.nvg.tokSide)
        _ = H
    }

    // MARK: 적 근접 인공지능(foeAI 의 근접 갈래 대신)

    func nvMelee(_ a: Actor, _ e: Enemy, _ H: Actor, _ dt: Double) {
        nvInit(a)
        let side: Double = a.x >= H.x ? 1 : -1, dist = abs(a.x - H.x); face(a, H.x)
        let rs = e.boss ? e.spd * 2 : max(e.dash ?? 0, min(120, max(90, e.spd * 2.6)))   // 웹과 같은 질주 속도
        if a.nvg.cut > 0 { nvCutTick(a, e, H, dt, side, dist, rs); return }
        if a.nvg.tok { nvHolder(a, e, H, dt, side, dist, rs); return }
        nvWait(a, e, H, dt, side, dist, rs)
    }

    /// 다음 공격 고르기(웹 규칙 + 하단기: 주인공이 서서 막고 있으면 하단을 더 자주)
    func nvPickMove(_ a: Actor, _ e: Enemy, _ dist: Double) {
        if e.next == nil {
            let ms = e.moves; var m = ms[rndInt(ms.count)]
            if ms.count > 1 && m == a.lastMove && rnd() < 0.75 { let alt = ms.filter { $0 != a.lastMove }; m = alt[rndInt(alt.count)] }
            if let lm = a.nvg.style.lowMove, let H = hero {
                let p = nvGuardOf(H) == 1 ? 0.6 : a.nvg.style.lowUse
                if rnd() < p { m = lm }
            }
            e.next = m
        }
        if e.next == "fkick" && dist < 50 { let alt = e.moves.filter { $0 != "fkick" }; let r = rndInt(alt.count); e.next = alt.indices.contains(r) ? alt[r] : "jab" }
    }
    func nvStrike(_ a: Actor, _ mv: String, tell: Double = 0) { a.nvg.struckAt = time; foeStrike(a, mv, extraTell: tell) }
    func nvSetGuardAnim(_ a: Actor) {
        if a.nvg.stance == 0 { a.nvg.stance = 1 }
        let want = a.nvg.stance == 2 ? "nv_gdL" : "nv_gdH"
        if a.anim != want && canAct(a) { setAnim(a, want) }
    }

    /// 공격권을 쥔 적: 붙어서 연타(쿨다운 ×0.8) · 공격 사이 가끔 가드 · 주인공이 넘어지면 물러선다
    func nvHolder(_ a: Actor, _ e: Enemy, _ H: Actor, _ dt: Double, _ side: Double, _ dist: Double, _ rs: Double) {
        nvPickMove(a, e, dist)
        let gapMv = e.next == "fkick", inGap = dist >= 50 && dist <= 110
        let rch = wpnReach(e.next, e.wpn)
        let spd = (e.dash ?? 0) != 0 && dist > 60 ? e.dash! : e.spd
        if nvHeroDown(H) {   // 몰매 없음: 반 걸음 물러서 기다린다
            if nvIsGuardAnim(a.anim) { setAnim(a, "idle") }
            let tx = H.x + side * 44
            if abs(a.x - tx) > 2 { approach(a, tx, e.spd, dt, rs) } else if a.anim == "walk" { setAnim(a, "idle") }
            return
        }
        if e.flankAt != 0 && time >= e.flankAt {   // 협공: 반대편 공격권 주인과 박자를 맞춘다
            e.flankAt = 0
            if !gapMv && dist <= rch + 4 { e.cdT = 0; let mv = e.next!; e.next = nil; e.fl = true; a.nvg.strikes -= 1; nvStrike(a, mv); return }
        }
        if a.action == nil && a.nvg.struckAt > a.nvg.rolledAt {   // 공격 사이: 가끔 가드를 올리고 버틴다
            a.nvg.rolledAt = time
            if a.nvg.strikes > 0 && rnd() < a.nvg.style.holdP {
                a.nvg.guardUntil = time + 0.45 + 0.45 * rnd(); a.nvg.stance = rnd() < a.nvg.style.lowP ? 2 : 1
            }
        }
        if a.action == nil, let HA = H.action, !HA.fired, H.anim != "duck", inFront(H, a, 46) {   // 주인공이 치려 한다 → 가끔 가드로 맞선다(높이는 짐작 — 틀리면 맞는다)
            if a.nvg.readKey !== HA {
                a.nvg.readKey = HA
                if rnd() < a.nvg.style.holdP { a.nvg.guardUntil = time + 0.5 + 0.3 * rnd(); a.nvg.stance = rnd() < a.nvg.style.lowP ? 2 : 1 }
            }
        }
        if time < a.nvg.guardUntil {
            if dist > rch + 8 { if nvIsGuardAnim(a.anim) { setAnim(a, "idle") }; approach(a, H.x + side * max(data.sepHF, rch - 3), spd, dt, rs) }
            else { nvSetGuardAnim(a) }
            return
        }
        if nvIsGuardAnim(a.anim) { setAnim(a, "idle") }
        let inR = !gapMv && dist <= rch && dist >= data.sepHF - 1
        if inR && a.anim == "walk" { setAnim(a, "idle") }
        let there = gapMv ? (dist <= 110 || approach(a, H.x + side * 90, spd, dt, rs)) : inR ? true : approach(a, H.x + side * max(data.sepHF, rch - 3), spd, dt, rs)
        if gapMv && inGap && a.anim == "walk" { setAnim(a, "idle") }
        if (gapMv ? inGap : ((there || dist <= rch) && dist <= rch + 4)) && e.cdT >= e.cd * NativeContent.Crowd.holderCD {
            e.cdT = 0; let mv = e.next!; e.next = nil; a.nvg.strikes -= 1; nvStrike(a, mv)
        }
    }

    /// 대기하는 적: 자리 잡기 · 가드 · 셔플 · 페인트 · 도발
    func nvWait(_ a: Actor, _ e: Enemy, _ H: Actor, _ dt: Double, _ side: Double, _ dist: Double, _ rs: Double) {
        let st = a.nvg.style, down = nvHeroDown(H)
        if time >= a.nvg.stanceAt { a.nvg.stanceAt = time + 1.6 + 1.6 * rnd(); a.nvg.stance = st.lowP > 0 && rnd() < st.lowP ? 2 : 1 }
        if time >= a.nvg.shufAt { a.nvg.shufAt = time + 0.8 + 0.8 * rnd(); a.nvg.shuf = a.nvg.shuf > 0 ? -3 : 3 }
        let back = time < a.nvg.backUntil ? 10.0 : 0
        // 자리가 칸 끝을 넘으면 칸 끝 너머(웹 문 밖 · 화면 가장자리)에서 기다린다 — 벽에 붙여 겹치지 않게 17px 씩 이어 놓는다
        let edge = tower ? (side > 0 ? AW1() - 2 : AW0() + 2) : side > 0 ? data.sbW + 26 : -26   // 타워는 엘리베이터 벽 안
        let tx = clamp(H.x + side * (a.nvg.slot + (a.nvg.stance == 1 ? a.nvg.shuf : 0) + back + (down ? 22 : 0)), min(AW0() + 2, edge), max(AW1() - 2, edge))
        let gap = abs(tx - a.x)
        if gap > 3.5 {
            if nvIsGuardAnim(a.anim) { setAnim(a, "idle") }
            let retreat = abs(a.x - H.x) < abs(tx - H.x)   // 자리보다 안쪽: 가드를 올린 채 빠르게 물러선다(주인공이 밀고 들어와도 자리를 지킨다)
            if gap > 46 && !retreat { approach(a, tx, e.spd, dt, rs) } else { moveTo(a, tx, max(26, e.spd) * (retreat ? 1.5 : 0.9), dt) }
            return
        }
        if a.anim == "walk" { setAnim(a, "idle") }
        if !down && time >= a.nvg.feintAt {   // 페인트: 파고드는 척 한 걸음(치고 빠지는 놈은 더 깊게 · 자주)
            a.nvg.feintAt = time + 2.4 + 2.6 * rnd()
            let hr = e.hitrun
            if (st.feint || hr) && rnd() < (hr ? 0.55 : 0.3) && dist < 110 {
                stats.nvg.feints += 1
                let d = hr ? 22.0 : 13
                setAnim(a, "nv_step"); a.dash = -side * d / 0.11; a.dashT = 0.11; a.nvg.backUntil = time + 0.5
                fx("dust", a.x + side * 5, a.y, -side)
                nvHeroFeintReact(a)
                return
            }
        }
        if !down && st.taunt && time >= a.nvg.tauntAt {   // 도발
            a.nvg.tauntAt = time + 4.5 + 4 * rnd()
            if rnd() < 0.35 && dist > 44 {
                stats.nvg.taunts += 1
                setAnim(a, rnd() < 0.5 ? "nv_taunt1" : "nv_taunt2")
                if rnd() < 0.35 { comicSay(a, "덤벼!", "shout") }
                return
            }
        }
        nvSetGuardAnim(a)
    }

    // MARK: 끼어들기

    static let nvLongAnims: Set<String> = ["cycle", "renkan", "tetsu", "axe", "axe_air", "skick", "suplex", "throw", "nv_cork", "nv_liver", "nv_rise", "nv_kneelift", "nv_duckup", "nv_beam", "nv_slam", "nv_stamp", "nv_dial", "nv_punt", "nv_headbutt", "charge", "round", "fkick", "hangkick", "upper", "knee"]

    /// 주인공이 다른 적에게 긴 콤보 · 큰 기술을 쓰는 중 → 대기하던 적 하나가 끼어들기를 노린다(5초에 한 번 이하)
    func nvCutInCheck(_ H: Actor, _ F: [Actor], _ down: Bool) {
        guard !down, time - nvc.cutAt > NativeContent.Crowd.cutGap, time >= nvc.cutCheck else { return }
        nvc.cutCheck = time + 0.5
        let busyT = croute?.T
        let locked = (croute != nil && busyT != nil && !busyT!.dead) || (H.action != nil && World.nvLongAnims.contains(H.anim))
        guard locked else { return }
        let cands = stableSortD(F.filter { a in
            guard let e = a.e else { return false }
            let d = abs(a.x - H.x)
            return !a.nvg.tok && a.nvg.cut == 0 && canAct(a) && !(e.stun > 0) && !e.heavy && !e.boss && d >= 36 && d <= 130 && a !== busyT && time >= a.nvg.crashUntil
        }) { a, b in (behindOf(H, a) ? 0 : 40) + abs(a.x - H.x) - ((behindOf(H, b) ? 0 : 40) + abs(b.x - H.x)) }
        guard let c = cands.first, rnd() < 0.55 else { return }
        nvc.cutAt = time; stats.nvg.cutIns += 1
        c.nvg.cut = 1; c.nvg.cutAt = time; c.nvg.cutStomp = false
        face(c, H.x); c.action = nil; c.queue = []; setAnim(c, "nv_stomp")
        fxD(FxDetail(kind: "nv_alert", x: c.x, y: c.y - 70, dir: c.f)); sfx("nv_alert")
    }

    /// 끼어드는 적: 예고(구르기)가 끝나면 달려들어 긴 예고로 친다 → 끝나면 물러선다
    func nvCutTick(_ a: Actor, _ e: Enemy, _ H: Actor, _ dt: Double, _ side: Double, _ dist: Double, _ rs: Double) {
        if a.nvg.cut == 1 { a.nvg.cut = 2 }   // 구르기 동작이 끝났다(인공지능은 쉬는 동안만 불린다)
        guard a.nvg.cut == 2 else { return }
        if time - a.nvg.cutAt > 3 || nvHeroDown(H) { a.nvg.cut = 0; return }   // 놓쳤다
        nvPickMove(a, e, dist)
        let rch = wpnReach(e.next, e.wpn), gapMv = e.next == "fkick"
        if gapMv { e.next = "jab" }
        if dist > rch { approach(a, H.x + side * max(data.sepHF, rch - 3), e.spd, dt, max(rs, 130), true); return }
        if a.anim == "walk" { setAnim(a, "idle") }
        e.cdT = 0; let mv = e.next!; e.next = nil; a.nvg.cut = 3
        nvStrike(a, mv, tell: NativeContent.Crowd.cutTell)
    }
}
