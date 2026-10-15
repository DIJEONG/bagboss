import Foundation
import BBContent

// 네이티브 공방 ② 가드 · 높이 층(docs/08 — SimConfig.nativeMoves && nativeGuard. 꺼지면 이 파일은 불리지 않는다 → 웹 그대로).
// 버추어 파이터 문법: 서서 막기 = 상단 · 중단을 막고 하단에 진다 / 앉아 막기 = 하단을 막고 상단은 숙여 흘리며 중단에 진다 / 잡기는 가드를 무시.
//  · 막을 때마다 가드 게이지가 준다(무게 L 1 · M 1.5 · H 2.5 칸) → 0 이 되면 가드 크래시: 팔이 튕겨 열리고 휘청 · 짧은 슬로 ·
//    'GUARD BREAK!' · 깨지는 연출 → 잠깐 무방비(주인공의 다음 타격 치명 · ×1.25)
//  · 가드 부수기: 리버 블로(서서 막기 팔 아래로) · 코크스크루(관통)는 막히지 않고 3칸을 깎는다
//  · 권법가 · 스파링꾼은 막는 대신 쳐내고(parry — 주인공이 밀린다), 우산 · 프라이팬 · 손전등 · 라인배커는 서 있기만 해도 앞을 막는다(방패)
//  · 주인공 자동 전투가 가드를 읽는다: 막히면 다음 기술의 높이를 바꾸고(상단이 막히면 중단 · 하단 · 잡기 · 가드 부수기, 앉아 막으면 중단),
//    맞는 기술이 없으면 계속 두들겨 게이지를 깬다. 콤보 경로 · 가방 기술 안에서만 고른다
//  · 주인공 가드: 쉬는 중 앞에서 적이 공격을 예고하면 서서 막기를 올린다(상단 예고 + 쭈그리기 준비면 앉아 흘리기).
//    가드 중(또는 막은 직후 0.25초) 그쪽을 누르면 저스트 가드 → 바로 받아치기(웹 justCounter)
// 규칙 난수는 깃발 켜짐 경로에서만 쓴다(꺼짐은 소비 순서 그대로).

/// 인물 한 명의 공방 상태(주인공 · 적 공통 — 군중 칸은 적만 쓴다)
struct NvGuard {
    var inited = false
    /// 적 가드 성향(처음 볼 때 정한다)
    var style = NativeContent.GuardStyle()
    // ── 가드 ──
    /// 고른 자세: 0 없음 · 1 서서 막기 · 2 앉아 막기
    var stance = 0
    /// 가드 게이지(칸)
    var meter = 4.0, meterMax = 4.0
    /// 마지막으로 막은 시각 · 높이(NvHeight 값) · 연속으로 막은 수 · 때린 인물
    var blockAt = -9.0, blockH = 0, blockN = 0
    var blockBy: ActorID?
    /// 가드 크래시 무방비가 끝나는 시각
    var crashUntil = -9.0
    /// 막힘 → 무너뜨림 교환을 이번 연속 막기에서 이미 셌나
    var exchCounted = false
    /// 주인공: 가드를 이 시각까지는 유지(막은 직후 경직 · 페인트에 움찔)
    var hold = -9.0
    // ── 군중(적) ──
    /// 공격권(토큰)을 쥠 · 쥔 쪽(−1 왼쪽 · +1 오른쪽) · 남은 연타 수 · 마지막 공격 시각 · 공격 뒤 가드 판단 시각
    var tok = false, tokSide = 0.0, strikes = 0, struckAt = -9.0, rolledAt = -9.0
    /// 공격권을 놓은 시각 · 한 걸음 물러서는 끝 시각 · 공격권을 쥔 채 가드를 올리는 끝 시각
    var relAt = -9.0, backUntil = -9.0, guardUntil = -9.0
    /// 대기 자리(주인공과의 거리) · 셔플 앞뒤 · 다음 셔플 · 자세 다시 고르기 · 페인트 · 도발 시각
    var slot = 48.0, shuf = 0.0, shufAt = 0.0, stanceAt = 0.0, feintAt = 0.0, tauntAt = 0.0
    /// 끼어들기: 0 없음 · 1 예고(구르기) · 2 달려듦 · 3 공격 중 / 시작 시각 · 구르는 먼지를 냈나
    var cut = 0, cutAt = -9.0, cutStomp = false
    /// 공격권을 쥔 적이 이미 읽은(가드할지 정한) 주인공 공격
    weak var readKey: ActionReq?
}

/// 판 전체 군중 상태
struct NvCrowd {
    /// 쪽마다 다음 공격권을 줄 시각(nil = 아직 안 정함) · 방금 놓은 적
    var grantAt: [Double?] = [nil, nil]
    var lastRel: [ActorID?] = [nil, nil]
    /// 마지막 끼어들기 · 다음 끼어들기 검사 시각
    var cutAt = -9.0, cutCheck = 0.0
    /// 주인공이 가드 여부를 이미 정한 적 공격(동작 요청 하나에 한 번 — 약한 참조: 주소 재사용으로 다른 동작과 헷갈리지 않게 → 결정성)
    weak var decided: ActionReq?
    /// 주인공 기술이 막혔다 — 다음 판단에서 기술을 다시 고른다(높이 바꾸기)
    var repick = false
    /// 방금 damage 가 막혔다(heroSkill 이 경직 · 연계를 건너뛴다)
    var blockedNow = false
}

enum NvGuardResult { case none, blocked, crash }

extension World {
    /// 공방 층이 켜졌나(깃발 nativeMoves + nativeGuard)
    var nvG: Bool { config.nativeMoves && config.nativeGuard }
    static let nvGuardStill: Set<String> = ["nv_gdH", "nv_gdL"]
    static let nvBlockAnims: Set<String> = ["nv_gdHb", "nv_gdLb"]
    func nvIsGuardAnim(_ a: String) -> Bool { a == "nv_gdH" || a == "nv_gdL" }

    /// 처음 볼 때 가드 게이지 · 성향 · 타이머
    func nvInit(_ a: Actor) {
        guard !a.nvg.inited else { return }
        a.nvg.inited = true
        if let e = a.e {
            a.nvg.style = NativeContent.guardStyle(e.t, e.def)
            a.nvg.meterMax = a.nvg.style.meter + (e.boss ? 0 : min(2, Double(stageIdx) * 0.5))   // 뒤 노선일수록 조금 단단하게
            a.nvg.shufAt = time + 0.4 + 0.6 * rnd(); a.nvg.feintAt = time + 1.5 + 2 * rnd(); a.nvg.tauntAt = time + 2.5 + 3 * rnd()
        } else { a.nvg.meterMax = NativeContent.heroMeter }
        a.nvg.meter = a.nvg.meterMax
    }

    /// 지금 실제로 막는 자세(0 없음 · 1 서서 · 2 앉아)
    func nvGuardOf(_ a: Actor) -> Int {
        guard nvG, a.nvg.inited, !a.dead, !a.held, a.jug == nil, time >= a.nvg.crashUntil else { return 0 }
        switch a.anim {
        case "nv_gdH", "nv_gdHb": return 1
        case "nv_gdL", "nv_gdLb": return 2
        case "idle", "walk":
            guard a.e != nil, a.nvg.cut == 0 else { return 0 }
            if a.nvg.stance > 0 && (!a.nvg.tok || time < a.nvg.guardUntil) { return 1 }   // 대기 중 셔플 · 자리 잡기: 가드를 올린 채 걷는다
            let S = a.nvg.style
            if (S.shield || S.parry) && time - a.nvg.blockAt > 1.6 { return 1 }          // 방패 · 쳐내기형: 서 있기만 해도 앞을 막는다(1.6초에 한 번)
            return 0
        default: return 0
        }
    }

    // MARK: 막기 판정(damage 맨 앞)

    /// 막았으면 .blocked(피해 없음) · 게이지가 깨지면 .crash(피해는 들어가고 damage 끝에서 크래시 반응) · 아니면 .none
    func nvGuardCheck(_ att: Actor, _ tgt: Actor, _ dmg: Double, _ o: HitOpts) -> NvGuardResult {
        guard nvG, !demo, !bonus, spc == nil, cut == nil, !o.splash, !o.counter, !o.just, let H = hero else { return .none }
        let heroAtk = att === H && tgt.e != nil, foeAtk = tgt === H && att.e != nil
        guard heroAtk || foeAtk else { return .none }
        nvInit(tgt)
        let mv = heroAtk ? att.anim : (att.lastMove ?? att.anim)
        let h = heroAtk ? NativeContent.heroHeight(mv) : NativeContent.foeHeight(mv)
        if h == .grab { return .none }
        let stance = nvGuardOf(tgt)
        guard stance > 0, inFront(tgt, att, 44) else { return .none }
        let w = heroAtk ? (data.atkFeel[mv]?.w ?? "L") : (data.foeW[mv] ?? "L")
        let f: Double = tgt.x >= att.x ? 1 : -1   // 때린 쪽 → 맞은 쪽
        var info = GuardInfo(attacker: att.id, target: tgt.id)
        info.height = h.name; info.stance = stance; info.heavy = w == "H"; info.heroBlocked = foeAtk; info.dir = f
        info.at = SIMD2(tgt.x - f * 7, tgt.y - (stance == 2 ? 24 : 42))
        if heroAtk && (o.pierce || (stance == 1 && NativeContent.underGuard.contains(mv))) {   // 가드 부수기: 막히지 않고 크게 깎는다
            tgt.nvg.meter -= NativeContent.breakerDrain; tgt.nvg.blockAt = time; tgt.nvg.blockH = h.rawValue
            stats.nvg.pierces += 1
            info.pierced = true; info.meter = max(0, tgt.nvg.meter / tgt.nvg.meterMax)
            if tgt.nvg.meter <= 0 { return .crash }
            emit(.guardBlock(info))
            return .none
        }
        if h.whiffs(stance) {   // 앉아 막기: 상단이 머리 위로 지나간다
            info.whiff = true; stats.nvg.whiffs += 1
            nvNoteBlock(tgt, att, h)
            if heroAtk { nvc.repick = true } else { tgt.nvg.hold = time + 0.12 }
            emit(.guardBlock(info))
            return .blocked
        }
        guard h.blockedBy(stance) else {
            if foeAtk && h == .low && stance == 1 { stats.nvg.lowBeats += 1 }
            return .none
        }
        let parry = tgt.nvg.style.parry && w != "H" && tgt.e != nil
        tgt.nvg.meter -= (NativeContent.drainW[w] ?? 1) * (parry ? 0.6 : 1)
        nvNoteBlock(tgt, att, h)
        info.meter = max(0, tgt.nvg.meter / tgt.nvg.meterMax); info.streak = tgt.nvg.blockN; info.parry = parry
        if tgt.nvg.meter <= 0 { return .crash }
        if heroAtk, let e = tgt.e {   // 적은 막아도 조금 깎인다(피해의 40% — 숫자는 띄우지 않는다). 그걸로 쓰러질 한 방이면 가드째 부순다
            let chip = jsRound(dmg * NativeContent.chipK)
            if e.hp - chip <= 0 { return .crash }
            e.hp -= chip; stats.dealt += chip; score += jsRoundI(chip * 10 * crowdK()); spcGain(2)   // 막혀도 급행 게이지는 친 만큼 찬다
        }
        nvBlockReact(att, tgt, stance: stance, parry: parry, heavy: w == "H", f: f)
        if foeAtk { stats.nvg.heroBlocks += 1 } else { stats.nvg.blocks += 1; if parry { stats.nvg.parries += 1 }; nvc.repick = true }
        emit(.guardBlock(info))
        if let e = tgt.e, e.lamp || e.pan {   // 손전등(눈부심) · 프라이팬(깡) 맛은 그대로
            emit(.blocked(target: tgt.id, kind: e.lamp ? .lamp : .pan)); flashText(e.lamp ? "BLIND" : "CLANG", 0.4)
        }
        return .blocked
    }

    func nvNoteBlock(_ tgt: Actor, _ att: Actor, _ h: NvHeight) {
        let fresh = time - tgt.nvg.blockAt >= 2.5
        tgt.nvg.blockN = fresh ? 1 : tgt.nvg.blockN + 1
        if fresh { tgt.nvg.exchCounted = false }
        tgt.nvg.blockAt = time; tgt.nvg.blockH = h.rawValue; tgt.nvg.blockBy = att.id
    }

    /// 막는 순간: 밀려나고 팔을 조인다(쳐내기는 주인공을 밀어낸다) · 아주 짧은 경직
    func nvBlockReact(_ att: Actor, _ tgt: Actor, stance: Int, parry: Bool, heavy: Bool, f: Double) {
        tgt.action = nil; tgt.queue = []
        if parry {
            setAnim(tgt, "parry")
            att.kb = -f * 26; att.hs = max(att.hs, 5); att.hs0 = att.hs
            emit(.blocked(target: tgt.id, kind: .parry))
        } else {
            setAnim(tgt, stance == 2 ? "nv_gdLb" : "nv_gdHb"); tgt.after = stance == 2 ? "nv_gdL" : "nv_gdH"
        }
        tgt.nvg.stance = stance
        tgt.kb = f * (heavy ? 24 : 15) * (tgt.e?.heavy == true || tgt.e?.boss == true ? 0.5 : 1)   // 3~6px 밀림
        tgt.hs = max(tgt.hs, heavy ? 3 : 2); tgt.hs0 = tgt.hs; tgt.shkA = 0.6
        if att.def.jw { att.hs = max(att.hs, heavy ? 3 : 2); att.hs0 = att.hs }
        if tgt === hero { tgt.nvg.hold = time + 0.18 }
        if let e = tgt.e {
            e.cdT = max(e.cdT, e.cd * NativeContent.Crowd.holderCD - 0.35)   // 막은 쪽이 곧 받아친다(공격권을 쥐었다면)
            if tgt.nvg.tok { tgt.nvg.guardUntil = max(tgt.nvg.guardUntil, time + 0.3) }
        }
        var k = CameraKick(); k.shake = heavy ? 1.6 : 0.8; emit(.camera(k))
    }

    /// 가드 크래시(damage 끝 — 반응을 정한 뒤): 팔이 튕겨 열리고 휘청 · 짧은 슬로 · 'GUARD BREAK!' · 무방비
    func nvGuardCrash(_ att: Actor, _ tgt: Actor, dead: Bool) {
        let isH = tgt === hero, f: Double = tgt.x >= att.x ? 1 : -1
        tgt.nvg.crashUntil = time + (isH ? 0.9 : 1.5); tgt.nvg.meter = 0; tgt.nvg.blockN = 0; tgt.nvg.stance = 0
        if isH { stats.nvg.heroCrashes += 1 } else { stats.nvg.crashes += 1; nvCountExchange(tgt) }
        var info = GuardInfo(attacker: att.id, target: tgt.id)
        info.dir = f; info.at = SIMD2(tgt.x - f * 6, tgt.y - 40); info.heroBlocked = isH; info.meter = 0
        info.height = (isH ? NativeContent.foeHeight(att.lastMove ?? att.anim) : NativeContent.heroHeight(att.anim)).name
        emit(.guardCrash(info))
        if !dead && tgt.jug == nil && !tgt.held && !data.falls.contains(tgt.anim) {
            tgt.action = nil; tgt.queue = []; tgt.after = nil; setAnim(tgt, "nv_gcrash")
            tgt.kb = f * 30 * (tgt.e?.heavy == true ? 0.5 : 1)
            if let e = tgt.e { e.stun = max(e.stun, 1.15); e.next = nil }
        }
        if tgt.nvg.tok { nvRelease(tgt, step: false) }
        tgt.nvg.cut = 0
        freeze = max(freeze, 3); slowT = max(slowT, 0.32)
        if !isH { spcGain(4) }
        var k = CameraKick(); k.zoom = 0.07; k.zoomMode = .add(cap: 0.1); k.focus = SIMD2(tgt.x, tgt.y - 40); k.shake = 3.2; emit(.camera(k))
        comicSFX(tgt.x, tgt.y - 94, "GUARD BREAK!", force: true)
    }

    /// 막힘 → 무너뜨림(높이를 바꿔 맞힘 · 크래시) 한 번 세기
    func nvCountExchange(_ t: Actor) {
        guard t.nvg.blockN > 0 || time - t.nvg.blockAt < 3, !t.nvg.exchCounted else { return }
        t.nvg.exchCounted = true; stats.nvg.exchanges += 1
    }

    /// 매 틱: 게이지 회복(1.2초 막지 않으면 3초에 가득) · 크래시가 끝나면 가득
    func nvGuardTick(_ dt: Double) {
        for a in ents where a.nvg.inited && !a.pass {
            if a.nvg.meter <= 0 { if time >= a.nvg.crashUntil { a.nvg.meter = a.nvg.meterMax } }
            else if time - a.nvg.blockAt > 1.2 { a.nvg.meter = min(a.nvg.meterMax, a.nvg.meter + a.nvg.meterMax / 3 * dt) }
        }
    }

    // MARK: 주인공 — 가드 읽기 · 높이 바꾸기

    /// pickSkill 가중: 대상의 가드(지금 자세 · 방금 막은 높이)를 이기는 높이를 고른다
    func nvHeightWeight(_ i: Int, _ T: Actor?) -> Double {
        guard let T, T.e != nil, T.nvg.inited, let it = item(bag[i].id) else { return 1 }
        let st = nvGuardOf(T), recent = time - T.nvg.blockAt < 2.5 ? T.nvg.blockH : 0
        let anim = nvSkillAnim(i)
        if time < T.nvg.crashUntil { return it.knock == true || it.react == "launch" || anim == "upper" ? 3 : 1.2 }   // 무방비: 띄우기 · 넘기기
        if st == 0 && recent == 0 { return 1 }
        let eff = st > 0 ? st : (recent == NvHeight.low.rawValue ? 2 : 1)
        var h = NativeContent.heroHeight(anim)
        if it.combo == true && eff == 2 { h = .mid }   // 앉아 막으면 주먹 콤보는 어퍼로 바꿔 친다(useSkill)
        if h == .grab { return it.cond == "grab" ? 4 : 1 }
        if eff == 1 && (NativeContent.underGuard.contains(anim) || anim == "nv_cork") { return 4 }
        if h.whiffs(eff) { return 0.1 }
        if h.blockedBy(eff) { return (recent == h.rawValue ? 0.3 : 0.65) * (data.atkFeel[anim]?.w == "H" ? 1.8 : 1) }
        return 4   // 높이가 맞는다
    }
    /// 가방 기술 i 를 지금 쓰면 나갈 동작(주먹 콤보는 다음 단계)
    func nvSkillAnim(_ i: Int) -> String {
        let b = bag[i]; guard let it = item(b.id) else { return "jab" }
        if it.combo == true { let n = time - (b.last ?? -9) < 2.4 ? ((b.combo ?? 0) + 1) % 4 : 0; return ["jab", "cross", "hook", "upper"][n] }
        return it.anim ?? "jab"
    }
    /// useSkill: 높이 바꾸기 세기(막힌 뒤 2.5초 안에 다른 높이로)
    func nvNoteSwitch(_ T: Actor, _ anim: String) {
        guard T.nvg.inited, T.nvg.blockH != 0, time - T.nvg.blockAt < 2.5 else { return }
        if NativeContent.heroHeight(anim).rawValue != T.nvg.blockH || NativeContent.underGuard.contains(anim) || anim == "nv_cork" { stats.nvg.heightSwitches += 1 }
    }

    /// 주인공 가드: 쉬는 중 앞에서 적이 공격을 예고하면 올린다. 가드 중이면 위협이 끝날 때까지 유지. true = 이번 틱은 가드(인공지능 끝)
    func nvHeroGuard(_ H: Actor, _ live: [Actor]) -> Bool {
        nvInit(H)
        if time < H.nvg.crashUntil { return false }
        if World.nvBlockAnims.contains(H.anim) { _ = nvRiseReversal(H, live); return true }   // 막는 순간 경직(압박이면 퇴근 승천권으로 되받아친다 — World+NativeRise)
        let guarding = nvIsGuardAnim(H.anim)
        // 자기 기술의 회복 칸(타격은 끝남)이면 가드로 끊을 수 있다 — 공중 · 잡기 · 반응 중은 안 된다
        let recov = H.action?.fired == true && !data.falls.contains(H.anim) && !data.reacts.contains(H.anim) && !heroAirborne(H) && !holding(H)
            && !["throw", "suplex", "duck", "nv_skid", "nv_go", "nv_rise"].contains(H.anim)   // 승천권 착지 빈틈은 가드로 끊지 않는다
        if !guarding && !canAct(H) && !recov { return false }
        var best: (a: Actor, tt: Double)?
        for a in live {
            guard let A = a.action, !A.fired, let e = a.e, data.foeW[a.anim] != nil, let tt = timeToCue(a) else { continue }
            if !inFront(a, H, wpnReach(a.lastMove, e.wpn) + 10) { continue }
            if best == nil || tt < best!.tt { best = (a, tt) }
        }
        if guarding {
            if best != nil || time < H.nvg.hold { return true }
            H.nvg.stance = 0; setAnim(H, "idle"); return false
        }
        guard let (a, tt) = best, tt <= 0.45, let A = a.action else { return false }
        if nvc.decided === A { return false }
        nvc.decided = A
        if behindOf(H, a) && tt < 0.18 { return false }   // 돌아설 틈이 없다
        if nvRiseAntiAirGuard(H, a) { return true }   // 뛰어드는 적(날아차기): 가드 대신 대공 승천권
        // 받아치기 기술(팔꿈치 · 숄더 롤)이 준비돼 있으면 그쪽(조건 기술의 몫)
        if bag.indices.contains(where: { k in item(bag[k].id)?.cond == "counter" && bag[k].t >= cdOf(k) && !soloSkip(bag[k]) && abs(a.x - H.x) <= (item(bag[k].id)?.reach ?? 0) + 4 }) { return false }
        if rnd() >= (manualT > 0 ? 0.4 : 0.6) { return false }
        let h = NativeContent.foeHeight(a.lastMove ?? a.anim)
        var stance = 1
        if h == .low { stance = rnd() < 0.35 ? 2 : 1 }   // 하단 예고는 가끔만 읽는다(서서 막기를 하단으로 뚫을 수 있게)
        else if h == .high && duckReady() { let i = duckSlot(); bag[i].t = 0; emit(.bagPulse(uid: bag[i].uid, kind: "fire")); stance = 2 }   // 상단은 숙여 흘린다
        face(H, a.x); H.action = nil; H.queue = []; H.dash = 0; H.dashT = 0
        setAnim(H, stance == 2 ? "nv_gdL" : "nv_gdH"); H.nvg.stance = stance; H.nvg.hold = time + 0.1
        return true
    }

    /// 페인트에 움찔: 쉬는 주인공이 앞에서 파고드는 척하는 적을 보고 잠깐 가드를 올린다
    func nvHeroFeintReact(_ a: Actor) {
        guard let H = hero, !H.dead, canAct(H), !nvIsGuardAnim(H.anim), H.action == nil, abs(a.x - H.x) < 70, !behindOf(H, a), time >= H.nvg.crashUntil else { return }
        if rnd() < 0.5 { nvInit(H); setAnim(H, "nv_gdH"); H.nvg.stance = 1; H.nvg.hold = time + 0.35 }
    }

    /// 직접 조작: 가드 중(또는 막은 직후 0.25초) 그쪽을 누르면 저스트 가드 → 바로 받아치기. true = 처리함
    func nvJustGuard(_ side: Double, lag: Double) -> Bool {
        guard nvG, let H = hero, !H.dead else { return false }
        let guarding = nvIsGuardAnim(H.anim) || World.nvBlockAnims.contains(H.anim) || time - H.nvg.blockAt < 0.25
        guard guarding else { return false }
        let near = foes().filter { jsSign($0.x - H.x) == side && abs($0.x - H.x) < 50 && $0.anim != "death" && $0.e?.boss != true && !$0.held }
        let A = near.first { $0.id == H.nvg.blockBy && time - H.nvg.blockAt < 0.25 }
            ?? near.first { a in guard a.action.map({ !$0.fired }) == true, data.foeW[a.anim] != nil, let tt = timeToCue(a) else { return false }; return tt + lag <= justW() * 1.6 }
        guard let A else { return false }
        stats.nvg.justGuards += 1
        var info = GuardInfo(attacker: A.id, target: H.id)
        let f: Double = H.x >= A.x ? 1 : -1
        info.just = true; info.heroBlocked = true; info.dir = f; info.at = SIMD2(H.x - f * 7, H.y - 42); info.meter = 1
        info.height = NativeContent.foeHeight(A.lastMove ?? A.anim).name
        emit(.guardBlock(info))
        H.nvg.meter = H.nvg.meterMax
        justCounter(A)
        flashText("JUST GUARD!", 0.9)
        return true
    }
}
