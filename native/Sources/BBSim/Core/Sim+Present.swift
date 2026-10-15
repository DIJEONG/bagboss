import Foundation
import BBCore
import BBContent

// N4 통합: 표현 · 흐름 화면이 읽는 스냅숏 값 채우기 + 이어 하기(웹 resumeRun).
// 규칙은 바꾸지 않는다 — 읽기(fillPresentation)와 웹 resumeRun 과 같은 순서의 상태 복원만 있다.

/// 이어 하기 입력(웹 'dotlab-run-v1' 의 규칙 부분 — BBPersistence RunSave 에서 앱이 옮겨 담는다)
public struct SimResume: Sendable, Equatable {
    public var stageIdx = 0, ci = 0
    public var bag: [BagItem] = [], stash: [BagItem] = []
    public var tokens = 0, score = 0, kills = 0
    public var hp = 0.0, sp = 0.0
    public var imprints: [String: String] = [:]
    public var bonusDone = false
    /// 보너스 판을 이미 지난 노선 번호
    public var bonusStages: [Int] = []
    public init() {}
}

extension Sim {
    /// 웹 resumeRun(S): startRun(cfg) 뒤(= Sim 을 cfg 로 만든 직후)에 부른다. 직전 호차가 도착한 역에서 다음 호차를 탄다.
    public func resume(_ r: SimResume) { w.resume(r) }
}

extension World {
    func resume(_ S: SimResume) {
        if pr != nil || cn != nil || kn != nil || demo {   // 웹 resumeRun 은 GS.resuming 으로 프롤로그 없이 시작한다 — 이미 시작한 프롤로그 · 무도장은 걷고 새로
            let keep = config; var c = config; c.prologue = false; config = c; startRun(); config = keep
        }
        if S.stageIdx > 0 && S.stageIdx < data.game.stages.count { loadStage(S.stageIdx) }
        func make(_ b: BagItem) -> Item {
            let it = Item(id: b.id, uid: b.uid, tier: b.tier, opt: b.opt)
            it.x = b.x; it.y = b.y; it.rot = b.rot; it.sx = b.sx; it.sy = b.sy; it.pin = b.pin
            return it
        }
        bag = S.bag.filter { item($0.id) != nil }.map(make); stash = S.stash.filter { item($0.id) != nil }.map(make)
        uid = max(uid, (S.bag + S.stash).map(\.uid).max() ?? 0)   // 웹은 uid 를 저장하지 않는다 → max+1 부터(docs/06 §1.6)
        tokens = S.tokens; if !S.imprints.isEmpty { imprints = S.imprints; imprintsVersion &+= 1 }
        score = S.score; kills = S.kills; bonusDone = S.bonusDone
        bonusSt = [:]; for k in S.bonusStages { bonusSt[k] = true }; if S.bonusStages.isEmpty && S.bonusDone { bonusSt[1] = true }
        sp = S.sp
        fitBag(); maxHP = heroMax(); hp = max(1, min(maxHP, S.hp > 0 ? S.hp : maxHP)); lagH = hp
        if S.ci > 0 && S.ci < line.count {
            ci = S.ci - 1; ents = ents.filter { $0.e == nil }
            atStop = line[S.ci - 1].stop ?? startStop; stationDone = S.ci - 1
            startBoard()
        }
        renderBag()
        say("이어 하기", "\(stage.name) · \(S.ci + 1)호차부터", 2.6)
    }

    /// 스냅숏 N4 칸 채우기(Sim.snapshot 에서 부른다)
    func fillPresentation(_ s: inout SimSnapshot) {
        s.on = on; s.arriving = arriving; s.press = press; s.shoveX = shoveX; s.doorWant = doorWant
        s.trainT = tr.t; s.trainStopAt = tr.stopAt; s.trainFlick = tr.flick; s.trainFlickS = tr.flickS
        s.straps = straps.keys.sorted().map { SimSnapshot.StrapView(x: Double($0), a: straps[$0]!.a) }
        s.shotViews = shots.filter { !$0.dead }.map { .init(x: $0.x, y: $0.y, t: $0.t, vx: $0.vx, friendly: $0.friendly, kind: $0.kind) }
        for (i, it) in items.enumerated() where i < s.floorItems.count { s.floorItems[i].t = it.t }
        s.imprints = imprints
        s.shopCards = state == "shop" ? shopList.map { .init(id: $0.id, tier: $0.tier, opt: $0.opt) } : []
        s.rerolls = rerolls
        s.arrangeT = arrT; s.arrangeTouched = arrTouched; s.transferT = trT; s.transferTo = trNext
        s.talkActive = talkActive
        // M: HUD 가 추정하던 값(웹 drawUI 가 GS 에서 바로 읽는 것)
        s.manualT = manualT; s.bagSlowT = bagSlowT; s.inCombat = inCombat()
        s.fade = fade; s.lagH = lagH
        if let S = nvSnow, S.held { s.snowStage = S.station }
        s.beam = nvBeam.map { .init(phase: $0.phase == .charge ? "charge" : $0.phase == .fire ? "fire" : "fade", t: $0.t, f: $0.f, ang: $0.ang, len: World.nvBeamLen, hits: $0.hits) }
        if let C = nvCord, let H = hero {
            let ph: String = switch C.phase { case .hold: "hold"; case .fly: "fly"; case .pull: "pull"; case .reel: "reel"; case .stow: "stow" }
            s.cord = .init(phase: ph, t: C.t, hand: nvDialHand(H), tip: C.tip, f: H.f, hauled: C.hauled, foot: SIMD2(H.x, H.y))
        }
        s.duckReady = duckReady()
        if let H = hero {
            let inc = shots.contains { !$0.dead && !$0.dodged && jsSign(H.x - $0.x) == jsSign($0.vx) && abs($0.x - H.x) < 130 }
            s.duckWarn = inc && s.duckReady && !isDucking(H)
        }
        s.comboWin = comboWin(); s.lastHit = lastHit; s.comboDmg = comboDmg; s.justW = justW()
    }
}
