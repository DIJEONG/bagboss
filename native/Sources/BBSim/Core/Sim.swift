import Foundation
import BBCore
import BBContent
import BBAnim

/// 시뮬레이션 바깥 창구(docs/06 §2.3). 한 판의 World 를 소유하고, 1틱(1/60초 실제 시간)씩 웹 loop() 와 같은 순서로 돌린다.
///   dt = 1/60 × 게임 속도 × (슬로 0.28) × 필살기 시간 배율 × (가방 정리 0.2) → 애니메이션 칸(1/animFps, 한 틱에 최대 8칸) → gameUpdate(dt)
/// World 는 Sendable 이 아니다 — Sim 을 한 실행 흐름에서만 쓴다(스냅숏 · 이벤트는 값).
public final class Sim {
    let w: World

    /// - seed: 규칙 난수 씨앗(웹 하네스와 같은 mulberry32 — 같은 씨앗이면 같은 판)
    public init(data: SimData, seed: UInt32, config: SimConfig = SimConfig()) {
        w = World(data: data, seed: seed, config: config)
        if config.harnessWarmup {
            var c0 = config; c0.kit = "basic"; c0.stage = 0; c0.daily = false; c0.prologue = false; w.config = c0; w.startRun(); w.config = config
        }
        switch config.mode {   // N5: 시작 모드(Sim+Modes.swift)
        case .tower: w.startTower()
        case .bonus: w.startRun(devStart: false); w.jumpToBonus()
        case .subway: w.startRun()
        case .dojo: w.startDojo()
        }
        if let cb = config.customBag {
            w.bag = cb.map { b in let it = w.newItem(b.id, 1, nil); it.x = b.x; it.y = b.y; it.rot = b.rot; return it }
            w.fitBag(); w.renderBag()
        }
    }
    deinit { w.dispose() }

    /// 시뮬레이션 시계(초, 실제 시간 — 틱 수 / 60). 터치 시각(SimIntent.tap at)은 이 시계로 준다
    public var clock: Double { w.realTime }
    public var config: SimConfig { w.config }
    /// 지금 판 상태(웹 GS.state)
    public var state: String { w.state }
    public var stats: RunStats { w.stats }
    public var meta: SimMeta { w.meta }

    /// 한 틱 진행 → 이번 틱 이벤트
    @discardableResult
    public func step(_ intents: [SimIntent] = []) -> [SimEvent] {
        for i in intents { apply(i) }
        w.frame()
        if w.config.autoAdvance { w.autoAdvance() }
        w.frameNo += 1
        return w.events.drain()
    }

    func apply(_ i: SimIntent) {
        switch i {
        case .tap(let side, let at):
            if w.tapW != nil { w.tapFire(true); return }   // 웹 48-input: '탭!' 창이 열려 있으면 어디를 눌러도 탭
            if w.cine { w.cineSkip(); return }              // 웹 49-boot: 거리 연출 넘기기
            if w.skinPv != nil || w.talkActive { return }
            let lag = max(0, min(0.1, w.realTime - at)) * w.playSpeed
            w.manual(side < 0 ? -1 : 1, lag: lag)
        case .pad(let p, let at):
            if w.cine || w.skinPv != nil || w.talkActive { return }
            w.padInput(p, lag: max(0, min(0.1, w.realTime - at)) * w.playSpeed)
        case .duck: if w.tapW != nil { w.tapFire(true) } else { w.heroDuck(true) }
        case .tapWindow: w.tapFire(true)
        case .special: w.trySpecial()
        case .setSpeed(let v): if v > 0 { w.playSpeed = v; w.paused = false } else { w.paused = true }
        case .pause(let p): w.paused = p
        case .bagEdited: w.renderBag()
        case .advance:
            if w.cine { w.cineSkip() } else if w.state == "shop" { w.shopChoose(-1) } else if w.state == "arrange" { w.finishArrange() } else { w.bonusSkip() }
        case .shopPick(let k): w.shopChoose(k)
        case .shopReroll: w.shopReroll()
        case .shopCarve: w.shopCarve()
        case .talkDone: w.tkSkip()
        case .talkNext: w.tkTap()
        case .talkPick(let k): w.tkPick(k)
        case .cineSkip: w.cineSkip()
        case .dojo(let c): w.dojoCommand(c)
        case .skinPreview(let c): w.skinPreviewCommand(c)
        case .bagLayout(let bag, let stash): w.applyLayout(bag: bag, stash: stash)
        case .quickEquip(let u): w.quickEquip(u)
        case .bagTouch: w.bagTouch()
        case .bagTokens(let n): w.tokens = max(0, n); w.renderBag()
        }
    }

    /// 그리기용 상태
    public var snapshot: SimSnapshot { w.snapshot() }
}

extension World {
    /// 웹 loop() 한 화면 프레임(렌더 · UI 제외) — 실제 시간 1/60초
    func frame() {
        let rdt = SimTime.dt
        realTime += rdt
        if on && slowT > 0 { slowT -= rdt }
        if let W = tapW { W.t += min(0.1, rdt); if W.t > 1.5 { tapFire(false) } }   // 웹 render-loop: 탭 창 1.5초 안에 안 누르면 자동
        if on { spcCamTick(rdt) }
        camTick(rdt)
        bagSlowT = max(0, bagSlowT - rdt)
        let slowK = nvKOT > 0 ? World.nvKOSlowK : 0.28   // 네이티브 KO 마무리 슬로(깃발 켜짐에서만 nvKOT > 0)
        if nvKOT > 0 { nvKOT -= rdt }
        let dt = rdt * playSpeed * ((on && slowT > 0) ? slowK : 1) * (on ? spcTime : 1) * ((on && bagSlowT > 0) ? 0.2 : 1)
        gameTime += dt; acc += dt
        let step = 1 / animFps
        var n = 0
        while acc >= step && n < 8 { acc -= step; n += 1; if !paused { stepAnim() } }
        if !paused { gameUpdate(dt) }
        if acc > step { acc = 0 }
        if !paused { cutAdvance(min(0.1, rdt) * playSpeed) }   // 웹은 그리기(drawCut0)가 컷인 시간을 민다
        if paused { djStepFrame() }   // 무도장: 멈춘 채 한 프레임씩
        if config.trackDrawnPose, let H = hero { H.lastP = drawnPose(H) }   // 웹 drawChar0 가 남기는 lastP
        if !scheduled.isEmpty {
            let due = scheduled.filter { $0.at <= realTime }
            scheduled.removeAll { $0.at <= realTime }
            for s in due { s.run(self) }
        }
    }
    /// 하네스 정책(웹 simtrace): 매점은 첫 카드를 고르고, 정리는 바로 출발
    func autoAdvance() {
        if state == "shop" { shopChoose(0) }
        if state == "arrange" { finishArrange() }
    }
    /// 웹 bagTouch: 전투 중 가방을 만지면 0.2배 슬로
    func bagTouch() { if inCombat() { bagSlowT = 0.6 }; if state == "arrange" { arrTouched = true } }
    /// BagEditor 결과 반영: 같은 uid 의 자리 · 방향 · 핀만 옮긴다(옮긴 기술은 전투 중이면 쿨다운 처음부터)
    func applyLayout(bag nb: [BagItem], stash ns: [BagItem]) {
        let all = bag + stash
        func find(_ u: Int) -> Item? { all.first { $0.uid == u } }
        var newBag: [Item] = [], newStash: [Item] = []
        for b in nb { guard let it = find(b.uid) else { continue }
            let moved = it.x != b.x || it.y != b.y || it.rot != b.rot || !bag.contains(where: { $0 === it })
            it.x = b.x; it.y = b.y; it.rot = b.rot; it.pin = b.pin; it.tier = b.tier; newBag.append(it); if moved { cdReset(it) } }
        for b in ns { guard let it = find(b.uid) else { continue }; it.sx = b.sx; it.sy = b.sy; it.rot = b.rot; it.tier = b.tier; newStash.append(it) }
        // 목록에 없는 것(버린 것)은 사라진다
        bag = newBag; stash = newStash
        if state == "arrange" { arrTouched = true }
        renderBag()
    }
    /// 순환 참조(동작 요청 클로저 ↔ 인물) 끊기
    func dispose() {
        for a in ents { a.action = nil; a.queue = []; a.heldBy = nil }
        hero?.action = nil; hero?.queue = []
        croute = nil; spc = nil; cut = nil; bossBreak = nil; ev = nil; scheduled = []
        ents = []
    }

    func snapshot() -> SimSnapshot {
        var s = SimSnapshot()
        s.time = time; s.gameTime = gameTime; s.state = state; s.stageIndex = stageIdx; s.car = ci
        s.hp = hp; s.maxHP = maxHP; s.score = score; s.tokens = tokens; s.combo = combo; s.special = sp
        s.trainSpeed = tr.v; s.trainPhase = tr.phase; s.trainDoor = tr.door; s.trainShakeY = tr.dy; s.trainAccel = tr.a
        s.lightK = lightK; s.emitK = emitK; s.oneBit = oneBit ?? false
        s.trainEx = tr.ex; s.legStart = legStart; s.legT = legT; s.legDur = ci < line.count ? legDur(line[ci]) : 0; s.trainStrap = tr.strap; s.trainJolt = tr.jolt
        s.atStop = atStop; s.nextStop = nextStop; s.express = expr; s.leg = leg; s.wave = wave; s.waves = ci < line.count ? line[ci].waves.count : 0
        s.kills = kills; s.maxCombo = stats.maxCombo
        s.camX = camX; s.camZoom = camZ; s.slowT = max(0, slowT); s.freeze = freeze
        if let C = cut { s.cutKind = C.k; s.cutProgress = min(1, C.t / max(0.001, C.dur)) }
        s.specialActive = spc != nil
        s.floorItems = items.map { .init(kind: $0.kind, id: $0.id, x: $0.x, z: $0.z) }
        s.shots = shots.map { SIMD2($0.x, $0.y) }; s.cans = cans.map(\.x); s.props = props.map { .init(kind: $0.k, x: $0.x) }
        s.passTrain = pt; s.brakeGlow = brakeGlow
        s.stats = stats; s.bag = bag.map(\.bagItem); s.stash = stash.map(\.bagItem)
        if let C = croute { s.comboRoute = C.uids; s.comboStep = C.k; s.comboName = C.name }
        if nv { s.pad = padView() }   // 네이티브 직접 조작 패드(World+NativePad)
        fillPresentation(&s)   // N4: 표현 · 흐름 화면용 값(Sim+Present.swift)
        s.actors = ents.map { a in
            var p = ActorPose(anim: a.anim, pose: a.pose); p.prev = a.prev; p.k = a.k; p.phaseN = a.phaseN
            p.gph = a.gph; p.guardW = a.guardW; p.runU = a.runU; p.legRun = a.legRun; p.airOv = a.airOv; p.tilt = a.tilt
            if let J = a.jug { p.hasJug = true; p.jugRoll = J.roll; p.jugKick = J.kick }
            var v = SimSnapshot.ActorView(id: a.id, def: a.def.key, pose: p, x: a.x, y: a.y, flip: a.flip, remap: a.remap, flash: a.flash,
                                          weaponSprite: a.wpn ?? (a.action?.wpn), hidden: a.hidden || a.invis, isHero: a.isHero, isEnemy: a.e != nil, isPassenger: a.pass, shake: a.shk)
            v.look = a.def.look; v.enemyType = a.e?.t; v.name = a.def.name; v.hp = a.e?.hp ?? (a.isHero ? hp : 0); v.maxHP = a.e?.max ?? (a.isHero ? maxHP : 0)
            v.isBoss = a.e?.boss ?? false; v.z = a.z; v.airOv = a.airOv
            if a.e != nil, let A = a.action, !A.fired, let w = data.foeW[a.anim] { v.tellWeight = w; v.timeToCue = timeToCue(a) }
            v.idleProp = a.idleAct; v.stunned = (a.e?.stun ?? 0) > 0
            v.passModel = a.def.passModel
            if nvG && a.nvg.inited {   // 네이티브 공방(docs/08): 가드 자세 · 게이지 · 크래시 · 공격권 · 끼어들기 예고
                v.guardStance = nvGuardOf(a); v.guardMeter = a.nvg.meter / max(0.001, a.nvg.meterMax); v.guardSince = time - a.nvg.blockAt
                v.guardCrash = time < a.nvg.crashUntil; v.attackToken = a.nvg.tok; v.cutInTell = a.nvg.cut == 1
            }
            return v
        }
        fillModes(&s)          // N5: 타워 · 보너스(Sim+Modes.swift)
        fillStory(&s)          // K: 프롤로그 · 대화 · 무도장(Sim+Story.swift)
        return s
    }
}
