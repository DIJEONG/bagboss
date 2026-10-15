import Foundation
import BBSim

// 소리 매핑표(순수): 시뮬레이션 이벤트 → 효과음 이름표 · 열차 루프 입력 · 배경음 긴장도.
// BBPresentation 은 BBAudio 를 모른다(BBAudio 가 위층) — 여기서는 '무엇을 낼지'만 SoundCue 로 정하고,
// 앱이 SoundCue → BBAudio.SfxCue 로 한 줄씩 옮긴다(docs/06 §3 '어떤 소리를 낼지는 표현 쪽 매핑표가 정한다').
// 웹 원본: 27-actors damage()(hit3 · hitK · hurt) · 45-hud comicSFX(KA-BOOM → boom · WHOOSH → whoosh) · 13 groundImpact(floor ≥ .6)
//          · 29 justCounter(just) · 32 bossBreak(hitK big) · 27 pan 막기(skTone) · 30 레일 이음매(clack) · sfx.<id> 단독 소리

public enum SoundCue: Sendable, Equatable, Hashable {
    case clack(speed: Double)
    /// detail: 때린 동작 · 카운터(네이티브 녹음 타격음이 스타일을 고르는 데만 쓴다 — SoundDirector.hitDetail 이 켜졌을 때만 채운다)
    case hit3(tier: Int, crit: Bool, combo: Int, air: Bool, big: Bool, detail: HitDetail? = nil)
    /// 웹 hitK — kind: jab · punch · hammer · kick · big
    case hitK(kind: String, crit: Bool, combo: Int)
    case hurt(heavy: Bool)
    case just
    case floor(Double)
    case thud, swing, glass, boom, whoosh, dodge, press, click, coin, clear, slowIn, gong, ready, brass, rage, pass, chime
    case door(open: Bool)
    case merge(ok: Bool)
    /// 프라이팬 막기 '깡'(웹 skTone(1600,1200,.18,'triangle',.05))
    case panClang
    /// 철산고 진각 '쿵' — 낮은 울림(웹 skTone(72,38,.38,'sine',.28) + skNoise(.22,110,.14))
    case tetsu
    /// 네이티브 공방(docs/08): 막기 '탁'(무거우면 낮게 · 쳐내기는 금속성 · 저스트는 맑게) · 가드 크래시(깨짐 + 쿵) · 끼어들기 예고(경보 두 음)
    case block(heavy: Bool, parry: Bool, just: Bool)
    case guardCrash
    case alert
    /// 네이티브 퇴근 승천권 지붕 뚫기: 쾅(철판 찢김 + 낮은 울림) · 1.9초 뒤 지붕 위 '…쿵'(작게)
    case roofBlast, roofThud
    /// 퇴근 승천권 솟구침: 서류가 터져 나오는 바스락 · 휙(타격 소리 밑에 얇게)
    case paperRustle
    /// 네이티브 야근 광선: 모음(차오르는 높은 음) · 발사(지이잉 — 톱니 윙윙 + 잡음 + 낮은 쿵) · 끊기 전 마지막 한 방(지직)
    case beamCharge, beamFire, beamEnd
    /// 네이티브 눈 승강장(docs/10): 눈 밟는 뽀드득(달리면 조금 크게) · 미끄러지며 눈 긁는 소리 · 쓰러져 눈에 파묻히는 퍽
    case snowStep(run: Bool), snowSkid, snowBurst
    /// 네이티브 해변 도장(docs/12): 모래 밟는 사각(마른 · 젖은) · 모래 긁기 · 모래에 쓰러짐 · 물 첨벙(작게 · 크게) · 멀리서 갈매기
    case sandStep(run: Bool, wet: Bool), sandSkid, sandBurst, splash(big: Bool), gull
    /// 알 수 없는 단독 소리 id(앱이 무시하거나 가까운 소리로)
    case other(String)
}

/// 열차 루프 입력(BBAudio.TrainSoundInput 과 같은 칸)
public struct TrainSoundState: Sendable, Equatable {
    public var speed = 0.0
    /// accel · cruise · brake · stop
    public var phase = "stop"
    public var brakeGlow = 0.0
    public var outdoors = false
    public var atStop = false
    public var door = 0.0
    public var doorWant: Bool?
    public var flickeryCar = false
    public var flicker = 0.0
    public var oneBit = false
    public var time = 0.0
    /// 눈 승강장 바람(0 = 없음)
    public var snowWind = 0.0
    /// 해변 파도(0 = 없음 — 밀려올 때 차오르고 빠질 때 잦아든다)
    public var surf = 0.0
    public init() {}
}

/// 배경음 입력(BBAudio.MusicInput 과 같은 칸)
public struct MusicState: Sendable, Equatable {
    public var enabled = false
    /// 1 평온 · 2 전투 · 2.5 위기 · 3 두목(웹 musicTick 목표)
    public var intensity = 1.0
    public init(enabled: Bool = false, intensity: Double = 1) { self.enabled = enabled; self.intensity = intensity }
}

/// 타격음의 덧붙임 정보(네이티브 녹음 타격음 스타일 고르기용 — docs/11 §녹음 타격음)
public struct HitDetail: Sendable, Equatable, Hashable {
    /// 때린 동작(웹 att.anim)
    public var move: String
    /// 카운터 · 받아치기
    public var counter: Bool
    public init(move: String, counter: Bool) { self.move = move; self.counter = counter }
}

public struct SoundDirector: Sendable {
    /// 웹 HEAVY_RK — 큰 반응이면 3단 타격음이 덕킹(big)
    public var heavyReactions: Set<String>
    /// hit3 에 HitDetail(동작 · 카운터)을 채운다 — 기본 끔(끄면 이름표가 웹 매핑 그대로). 앱이 녹음 타격음을 켤 때 켠다
    public var hitDetail = false
    private var combo = 0
    private var comicT = -99.0
    public init(heavyReactions: Set<String> = []) { self.heavyReactions = heavyReactions }

    /// 한 틱 이벤트 → 효과음들. now = 화면 시각(만화 글자 0.5초 간격 규칙)
    public mutating func cues(for events: [SimEvent], now: Double) -> [SoundCue] {
        var out: [SoundCue] = []
        for e in events {
            switch e {
            case .comboStep(let n): combo = n
            case .hit(let h):
                if h.heroWasHit { continue }   // 주인공 피격음은 heroHurt 가 낸다
                guard let kind = h.soundKind else { continue }   // 주인공이 적을 때린 경우만(웹 att===GS.hero && tgt.e)
                if kind == "hammer" { out.append(.hitK(kind: "hammer", crit: h.crit, combo: combo)); continue }
                let big = h.soundTier == 2 && (h.dead || heavyReactions.contains(h.reaction) || h.reaction == "rBlast")
                out.append(.hit3(tier: h.soundTier, crit: h.crit, combo: combo, air: h.airborne, big: big,
                                 detail: hitDetail ? HitDetail(move: h.attackerAnim, counter: h.counter) : nil))
            case .heroHurt(let w): out.append(.hurt(heavy: w == .heavy))
            case .justCounter: out.append(.just)
            case .groundImpact(_, _, let p): if p >= 0.6 { out.append(.floor(p)) }
            case .blocked(_, let k): if k == .pan { out.append(.panClang) }
            case .guardBlock(let g):
                if g.whiff { out.append(.whoosh) } else if !g.pierced { out.append(.block(heavy: g.heavy, parry: g.parry, just: g.just)) }
                if g.just { out.append(.just) }
            case .guardCrash: out.append(.guardCrash)
            case .roofBlast: out.append(.roofBlast)
            case .roofThud: out.append(.roofThud)
            case .actionCue(_, _, let cue) where cue == "rs_launch": out.append(.paperRustle)   // 네이티브 승천권(깃발 켜짐에만 있는 큐)
            case .actionCue(_, let anim, let cue) where anim == "nv_beam":   // 네이티브 야근 광선(깃발 켜짐에만 있는 기술)
                if cue == "bm_charge" { out.append(.beamCharge) } else if cue == "bm_fire" { out.append(.beamFire) } else if cue == "bm_end" { out.append(.beamEnd) }
            case .bossBreak: out.append(.hitK(kind: "big", crit: true, combo: 0))
            case .railJoint: break   // 속도가 필요 — railJoint(speed:) 는 앱이 스냅숏 속도로(clack(speed:))
            case .comicReset: comicT = -99   // 웹 comicT=0 — 바로 뒤 글자는 간격 무시
            case .comicWord(let w, _, _):
                if now - comicT < 0.5 { continue }
                comicT = now
                if w == "KA-BOOM!" { out.append(.boom) } else if w == "WHOOSH!" { out.append(.whoosh) }
            case .sfx(let id, _): out.append(Self.cue(sfx: id))
            default: break
            }
        }
        return out
    }

    /// 웹 sfx.<id>() 이름 → 소리
    public static func cue(sfx id: String) -> SoundCue {
        switch id {
        case "thud": .thud
        case "swing", "throw": .swing
        case "glass": .glass
        case "boom": .boom
        case "whoosh": .whoosh
        case "dodge": .dodge
        case "press": .press
        case "click": .click
        case "coin": .coin
        case "clear": .clear
        case "slowIn": .slowIn
        case "gong": .gong
        case "ready": .ready
        case "brass": .brass
        case "rage": .rage
        case "pass": .pass
        case "chime": .chime
        case "door": .door(open: true)
        case "clack": .clack(speed: 400)
        case "tetsu": .tetsu   // 웹 29 철산고 onCue: 금속 hitK 가 아니라 낮은 울림
        case "carHit": .hit3(tier: 2, crit: false, combo: 0, air: false, big: false)
        case "nv_alert": .alert
        default: .other(id)
        }
    }

    /// 열차 루프 입력(매 프레임) — flickeryCar = 고장 · 공사 칸, outdoors = 다리 · 고가 구간
    public static func train(_ s: SimSnapshot, flickeryCar: Bool, outdoors: Bool, now: Double) -> TrainSoundState {
        var t = TrainSoundState()
        t.speed = s.trainSpeed; t.phase = s.trainPhase; t.brakeGlow = s.brakeGlow; t.outdoors = outdoors
        t.atStop = s.atStop != nil; t.door = s.trainDoor; t.doorWant = s.doorWant
        t.flickeryCar = flickeryCar; t.flicker = s.trainFlickS; t.oneBit = s.oneBit; t.time = now
        return t
    }

    /// 배경음 긴장도(웹 musicTick: 두목 3 · 위기 2.5 · 전투 2 · 평온 1). 판 밖(타이틀 · 결과)이면 꺼짐
    public static func music(_ s: SimSnapshot) -> MusicState {
        guard s.on, s.state != "over", s.state != "idle" else { return MusicState(enabled: false) }
        let foes = s.actors.filter { $0.isEnemy && !$0.hidden && $0.hp > 0 }
        let boss = foes.contains { $0.isBoss }, danger = s.hp < s.maxHP * 0.3
        let lv = boss ? 3 : (danger && !foes.isEmpty) ? 2.5 : !foes.isEmpty ? 2 : 1
        return MusicState(enabled: true, intensity: lv)
    }
}
