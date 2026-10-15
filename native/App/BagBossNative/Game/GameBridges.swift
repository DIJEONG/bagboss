import Foundation
import BBSim
import BBContent
import BBPersistence
import BBPresentation
import BBAudio

// 표현 층 값 ↔ 아래 모듈 값 옮기기(한 줄씩). 매핑 '결정'은 BBPresentation(SoundDirector)에 있고 여기는 타입 변환만 한다.

// MARK: 소리

enum AudioBridge {
    static func sfx(_ c: SoundCue) -> SfxCue? {
        switch c {
        case .clack(let v): return .clack(speed: v)
        case .hit3(let t, let crit, let combo, let air, let big, _): return .hit3(tier: t, crit: crit, combo: combo, air: air, big: big)
        case .hitK(let k, let crit, let combo): return .hitK(SfxCue.HitKind(rawValue: k) ?? .big, crit: crit, combo: combo)
        case .hurt(let h): return .hurt(heavy: h)
        case .just: return .just
        case .floor(let p): return .floor(p)
        case .thud: return .thud
        case .swing: return .swing
        case .glass: return .glass
        case .boom: return .boom
        case .whoosh: return .whoosh
        case .dodge: return .dodge
        case .press: return .press
        case .click: return .click
        case .coin: return .coin
        case .clear: return .clear
        case .slowIn: return .slowIn
        case .gong: return .gong
        case .ready: return .ready
        case .brass: return .brass
        case .rage: return .rage
        case .pass: return .pass
        case .chime: return .chime
        case .door(let o): return .door(open: o)
        case .merge(let ok): return .merge(ok: ok)
        case .panClang: return .skTone(f0: 1600, f1: 1200, dur: 0.18, wave: .triangle, vol: 0.05)
        case .tetsu: return .skTone(f0: 72, f1: 38, dur: 0.38, wave: .sine, vol: 0.28)
        case .block, .guardCrash, .alert, .roofBlast, .roofThud, .paperRustle, .snowStep, .snowSkid, .snowBurst, .sandStep, .sandSkid, .sandBurst, .splash, .gull, .beamCharge, .beamFire, .beamEnd: return sfxAll(c).first
        case .other: return nil
        }
    }
    /// 한 이름표가 소리 여럿인 경우(철산고 진각 = 저음 사인 스윕 + 잡음)
    static func sfxAll(_ c: SoundCue) -> [SfxCue] {
        if c == .tetsu { return [.skTone(f0: 72, f1: 38, dur: 0.38, wave: .sine, vol: 0.28), .skNoise(dur: 0.22, f: 110, g: 0.14)] }
        switch c {   // 네이티브 공방(docs/08)
        case .block(let heavy, let parry, _):
            if parry { return [.skTone(f0: 1500, f1: 1150, dur: 0.12, wave: .triangle, vol: 0.05), .skNoise(dur: 0.03, f: 3200, g: 0.08)] }   // 쳐냄: 팔이 부딪는 금속성
            return heavy ? [.skTone(f0: 520, f1: 300, dur: 0.07, wave: .square, vol: 0.06), .skNoise(dur: 0.06, f: 1500, g: 0.16)]               // 무거운 막기: 낮은 '턱'
                         : [.skTone(f0: 980, f1: 620, dur: 0.045, wave: .square, vol: 0.05), .skNoise(dur: 0.035, f: 2600, g: 0.12)]            // 막기 '탁'
        case .guardCrash:
            return [.glass, .hitK(.big, crit: true, combo: 0), .skTone(f0: 140, f1: 60, dur: 0.3, wave: .sine, vol: 0.22)]                        // 깨짐 + 쾅 + 낮은 울림
        case .alert:
            return [.skTone(f0: 880, f1: 900, dur: 0.08, wave: .square, vol: 0.04), .skTone(f0: 1320, f1: 1340, dur: 0.1, wave: .square, vol: 0.04, delay: 0.09)]   // 경보 두 음
        case .roofBlast:   // 퇴근 승천권 지붕 뚫기: 큰 쾅 + 철판이 찢기는 금속성 + 오래 남는 낮은 울림
            return [.boom, .hitK(.big, crit: true, combo: 0), .skNoise(dur: 0.32, f: 2400, g: 0.12), .skTone(f0: 95, f1: 38, dur: 0.6, wave: .sine, vol: 0.3)]
        case .paperRustle: // 승천권 서류 회오리: 높은 대역 바스락 셋(엇갈려) + 낮은 휙 — 타격 소리 밑에 얇게
            return [.skNoise(dur: 0.09, f: 5200, g: 0.035), .skNoise(dur: 0.12, f: 3800, g: 0.03, delay: 0.05), .skNoise(dur: 0.1, f: 6000, g: 0.025, delay: 0.12), .skNoise(dur: 0.28, f: 900, g: 0.04)]
        case .snowStep(let run):   // 눈 밟는 뽀드득: 짧은 높은 잡음 둘(엇갈려) + 낮은 눌림 — 아주 작게
            return [.skNoise(dur: 0.035, f: 2400, g: run ? 0.035 : 0.022), .skNoise(dur: 0.03, f: 3600, g: run ? 0.025 : 0.015, delay: 0.025), .skNoise(dur: 0.06, f: 420, g: run ? 0.05 : 0.03)]
        case .snowSkid:            // 미끄러지며 눈 긁기: 긴 잡음 둘(높게 · 낮게)
            return [.skNoise(dur: 0.26, f: 1700, g: 0.05), .skNoise(dur: 0.2, f: 520, g: 0.05)]
        case .snowBurst:           // 쓰러져 눈에 파묻힘: 부드러운 '퍽'
            return [.skNoise(dur: 0.14, f: 260, g: 0.09), .skNoise(dur: 0.1, f: 1300, g: 0.03, delay: 0.02)]
        case .sandStep(let run, let wet):   // 모래 밟기: 마른 모래 = 부드러운 '사각'(중역 잡음 + 아주 작은 높은 알갱이) · 젖은 모래 = 둔한 '척'
            if wet { return [.skNoise(dur: 0.06, f: 330, g: run ? 0.05 : 0.032), .skNoise(dur: 0.03, f: 1500, g: run ? 0.018 : 0.01, delay: 0.015)] }
            return [.skNoise(dur: 0.07, f: 950, g: run ? 0.034 : 0.022), .skNoise(dur: 0.04, f: 2600, g: run ? 0.014 : 0.009, delay: 0.02), .skNoise(dur: 0.05, f: 380, g: run ? 0.026 : 0.016)]
        case .sandSkid:    // 모래 긁기: 길고 거친 잡음(중역 · 낮게)
            return [.skNoise(dur: 0.28, f: 1100, g: 0.05), .skNoise(dur: 0.22, f: 420, g: 0.045)]
        case .sandBurst:   // 모래에 쓰러짐: 둔한 '퍽' + 흩어지는 모래 '사르르'
            return [.skNoise(dur: 0.15, f: 230, g: 0.1), .skNoise(dur: 0.22, f: 1800, g: 0.025, delay: 0.05)]
        case .splash(let big):   // 첨벙: 물 때리는 짧은 중역 + 흩어지는 물방울(높은 잡음 · 늦게) + 낮은 '퐁'(사인 내리꽂기)
            return big ? [.skNoise(dur: 0.16, f: 1200, g: 0.1), .skNoise(dur: 0.32, f: 4200, g: 0.045, delay: 0.04), .skTone(f0: 240, f1: 110, dur: 0.12, wave: .sine, vol: 0.07)]
                       : [.skNoise(dur: 0.08, f: 1500, g: 0.045), .skNoise(dur: 0.16, f: 4600, g: 0.02, delay: 0.03), .skTone(f0: 420, f1: 260, dur: 0.06, wave: .sine, vol: 0.025)]
        case .gull:        // 멀리서 갈매기 '끼욱 끼욱': 높은 삼각파가 위에서 아래로 꺾이는 두 소리 + 거친 숨 — 아주 작게
            return [.skTone(f0: 1750, f1: 1250, dur: 0.22, wave: .triangle, vol: 0.016), .skNoise(dur: 0.18, f: 2300, g: 0.006),
                    .skTone(f0: 1950, f1: 1400, dur: 0.16, wave: .triangle, vol: 0.013, delay: 0.3), .skNoise(dur: 0.13, f: 2500, g: 0.005, delay: 0.3)]
        case .beamCharge:  // 야근 광선 모음: 낮은 데서 높이 차오르는 음 + 얇은 지직
            return [.skTone(f0: 320, f1: 1500, dur: 0.24, wave: .sine, vol: 0.06), .skTone(f0: 640, f1: 3000, dur: 0.24, wave: .triangle, vol: 0.02), .skNoise(dur: 0.2, f: 6000, g: 0.015)]
        case .beamFire:    // 발사: 지이잉(톱니 둘이 엇갈려 윙윙 · 0.45초) + 쏟아지는 잡음 + 낮은 쿵
            return [.skTone(f0: 1900, f1: 1300, dur: 0.45, wave: .sawtooth, vol: 0.035), .skTone(f0: 1950, f1: 1340, dur: 0.45, wave: .sawtooth, vol: 0.025),
                    .skNoise(dur: 0.42, f: 4200, g: 0.05), .skTone(f0: 110, f1: 55, dur: 0.3, wave: .sine, vol: 0.2)]
        case .beamEnd:     // 끊기 전 마지막 한 방: 지직 + 쾅
            return [.skNoise(dur: 0.12, f: 5200, g: 0.08), .skTone(f0: 900, f1: 200, dur: 0.18, wave: .square, vol: 0.04), .boom]
        case .roofThud:    // 지붕 위에 떨어지는 '…쿵'(멀리서 작게)
            return [.skTone(f0: 120, f1: 60, dur: 0.16, wave: .sine, vol: 0.12), .skNoise(dur: 0.08, f: 300, g: 0.05)]
        default: break
        }
        return sfx(c).map { [$0] } ?? []
    }

    /// 녹음 타격음 맥락(때린 동작 · 카운터) — hit3 에 detail 이 있을 때만(SoundDirector.hitDetail)
    static func hitContext(_ c: SoundCue) -> HitContext? {
        if case .hit3(_, _, _, _, _, let d?) = c { return HitContext(move: d.move, counter: d.counter) }
        return nil
    }

    static func train(_ t: TrainSoundState) -> TrainSoundInput {
        var o = TrainSoundInput()
        o.speed = t.speed; o.phase = TrainSoundInput.Phase(rawValue: t.phase) ?? .stop; o.brakeGlow = t.brakeGlow; o.outdoors = t.outdoors
        o.atStop = t.atStop; o.door = t.door; o.doorWant = t.doorWant; o.flickeryCar = t.flickeryCar; o.flicker = t.flicker
        o.oneBit = t.oneBit; o.time = t.time; o.snowWind = t.snowWind; o.surf = t.surf
        return o
    }

    static func music(_ m: MusicState) -> MusicInput { m.enabled ? MusicInput(enabled: true, intensity: m.intensity) : .off }

    /// sampleHits: 네이티브 녹음 타격음(설정 'bbn-sfx-sample' — 'dotlab-snd' 와 따로)
    static func settings(_ s: SoundOptions, sampleHits: Bool = true) -> SoundSettings {
        SoundSettings(vol: .init(master: s.vol.master, music: s.vol.music, sfx: s.vol.sfx), muted: s.muted, sampleHits: sampleHits)
    }
}

// MARK: 저장(웹 v1 키 · 모양 — BBPersistence)

enum SaveBridge {
    /// 웹 saveRun(): 판 상태 → 'dotlab-run-v1'
    static func runSave(_ s: SimSnapshot, config: SimConfig, catalog: BagCatalog? = nil) -> RunSave {
        var r = RunSave()
        r.at = Date().timeIntervalSince1970 * 1000
        r.cfg = .init(kit: config.kit, stage: config.stage, daily: config.daily)
        r.stageIdx = s.stageIndex; r.ci = s.car
        // 웹 saveRun: 가방에 프롤로그 전용(pro — 장도리 등)이 있으면 맡겨 둔 시작 가방(pKit)을 저장한다
        let hasPro = s.bag.contains { catalog?.item($0.id)?.pro == true }
        r.bag = (hasPro ? s.pKit ?? s.bag : s.bag).map(saved); r.stash = s.stash.map(saved)
        r.tokens = s.tokens; r.score = Double(s.score); r.hp = s.hp; r.sp = s.special; r.kills = s.kills
        let st = s.stats
        r.stats = ["dealt": st.dealt, "taken": st.taken, "crits": Double(st.crits), "counters": Double(st.counters), "outs": Double(st.outs),
                   "maxCombo": Double(st.maxCombo), "links": Double(st.links), "justs": Double(st.justs), "dodges": Double(st.dodges),
                   "onTime": Double(st.onTime), "late": Double(st.late)]
        r.imprints = s.imprints
        return r
    }
    static func saved(_ b: BagItem) -> SavedItem {
        var o = SavedItem(id: b.id, tier: b.tier, uid: b.uid, t: b.t, rot: b.rot, opt: b.opt.map { .init(k: $0.k, v: $0.v) })
        if b.sx != nil { o.sx = b.sx; o.sy = b.sy } else { o.x = b.x; o.y = b.y }
        o.pin = b.pin
        return o
    }
    static func bagItem(_ s: SavedItem) -> BagItem {
        var b = BagItem(id: s.id, uid: s.uid, tier: s.tier, x: s.x ?? 0, y: s.y ?? 0, rot: s.rot, opt: s.opt.map { ItemOption(k: $0.k, v: $0.v) })
        b.sx = s.sx; b.sy = s.sy; b.pin = s.pin; b.t = s.t
        return b
    }
    /// 이어 하기: RunSave → (설정, 복원 값)
    static func resume(_ r: RunSave) -> (SimConfig, SimResume) {
        var c = SimConfig(); c.kit = r.cfg.kit; c.stage = r.cfg.stage; c.daily = r.cfg.daily
        var s = SimResume()
        s.stageIdx = r.stageIdx; s.ci = r.ci; s.bag = r.bag.filter { $0.x != nil }.map(bagItem); s.stash = r.stash.map(bagItem)
        s.tokens = r.tokens; s.score = Int(r.score); s.kills = r.kills; s.hp = r.hp; s.sp = r.sp; s.imprints = r.imprints; s.bonusDone = r.bonusDone
        s.bonusStages = r.bonusSt.keys.compactMap(Int.init)
        return (c, s)
    }

    // MARK: 메타(SimMeta ↔ MetaState) — 의미 있는 변환은 BBPersistence MetaRules(시험됨), 여기는 필드 복사만

    /// SimMeta → 중립 값(필드 1:1)
    static func ruleView(_ m: SimMeta) -> MetaRuleView {
        var v = MetaRuleView()
        v.seenCut = m.seenCut; v.foes = m.foes; v.items = m.items; v.links = m.links; v.hints = m.hints; v.talks = m.talks
        v.spc = m.spc; v.cbook = m.cbook; v.combos = m.combos; v.bossScenes = m.bossScenes; v.lines = m.lines
        var t = MetaRuleView.Tower()
        t.best = m.tower.best; t.bestT = m.tower.bestT; t.runs = m.tower.runs; t.ot = m.tower.ot
        t.lv = m.tower.lv.mapValues { .init(f: $0.f, t: $0.t) }; t.daily = m.tower.daily.mapValues { .init(f: $0.f, t: $0.t) }
        v.tower = t; v.bonusBest = m.bonusBest
        v.daily = m.daily; v.cseen = m.cseen; v.comboNames = m.comboNames
        return v
    }
    /// 중립 값 → SimMeta(판 시작 때 SimConfig.initialMeta)
    static func simMeta(_ v: MetaRuleView) -> SimMeta {
        var m = SimMeta()
        m.seenCut = v.seenCut; m.foes = v.foes; m.items = v.items; m.links = v.links; m.hints = v.hints; m.talks = v.talks
        m.spc = v.spc; m.cbook = v.cbook; m.combos = v.combos; m.bossScenes = v.bossScenes; m.lines = v.lines
        var t = TowerMeta()
        t.best = v.tower.best; t.bestT = v.tower.bestT; t.runs = v.tower.runs; t.ot = v.tower.ot
        t.lv = v.tower.lv.mapValues { .init(f: $0.f, t: $0.t) }; t.daily = v.tower.daily.mapValues { .init(f: $0.f, t: $0.t) }
        m.tower = t; m.bonusBest = v.bonusBest
        m.daily = v.daily; m.cseen = v.cseen; m.comboNames = v.comboNames
        return m
    }
    static func initialMeta(_ M: MetaState) -> SimMeta { simMeta(M.ruleView()) }

    /// SimMeta(규칙이 쓰는 메타) → 저장 메타에 합치기(단조). 바뀌었으면 true
    @discardableResult
    static func merge(_ m: SimMeta, into M: inout MetaState) -> Bool { M.merge(ruleView(m)) }

    /// 웹 metaTick 의 cur — 판 시작부터의 누계(웹 GS.kills · GS.stats.*)
    static func tally(_ s: SimSnapshot, merges: Int) -> [String: Int] {
        let st = s.stats
        return ["kills": s.kills, "crits": st.crits, "dodges": st.dodges, "links": st.links, "throws": st.throws_, "outs": st.outs,
                "onTime": st.onTime, "merges": merges, "footSet": st.footSet]
    }

    /// 시작 가방 해금 조건(KITS[].cond)
    static func kitConditions(_ kits: [KitDef]) -> [MetaState.KitCondition] {
        kits.compactMap { k in k.cond.map { .init(id: k.id, key: $0.k, n: $0.n) } }
    }
}
