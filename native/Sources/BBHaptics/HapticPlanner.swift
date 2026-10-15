import Foundation
import BBSim

// BBHaptics — 시뮬레이션 이벤트 → 진동.
// 웹 셸은 buzz(ms) 를 세기 3단계 충격으로만 냈다(docs/03 햅틱 표). 네이티브는 Core Haptics 로
// 세기(intensity) · 날카로움(sharpness) · 짧은 여운(continuous)을 따로 줘서 타격의 '무게'를 구분한다.
// 계획(이 파일)은 순수 로직 — macOS 테스트로 확인하고, 재생(HapticPlayer)은 iOS 에서만.

/// 진동 한 번(같은 묶음 안에서 offset 초 뒤)
public struct HapticPulse: Sendable, Equatable {
    public var offset: Double
    /// 0~1 세기 · 0~1 날카로움(높을수록 '탁', 낮을수록 '둥')
    public var intensity: Double, sharpness: Double
    /// 0 이면 순간 충격, 그 이상이면 뒤에 붙는 여운(초)
    public var tail: Double
    public init(offset: Double = 0, intensity: Double, sharpness: Double, tail: Double = 0) {
        self.offset = offset; self.intensity = intensity; self.sharpness = sharpness; self.tail = tail
    }
}

/// 설정(웹 OPT.vibe + 네이티브 세분)
public struct HapticSettings: Sendable, Equatable {
    public var enabled = true
    /// 주인공 피격(가장 잦음) 세기 배율 — 피곤하면 낮춘다(docs/04 체크리스트)
    public var heroHurtScale = 1.0
    /// 이 간격 안의 연속 진동은 하나로(다단 히트가 웅웅거리지 않게) — 웹 셸과 같은 45ms
    public var minInterval = 0.045
    /// 네이티브 강화: 무거운 타격에 짧은 여운(둥—)을 붙인다. 끄면 웹 셸과 같은 순간 충격만
    public var richTails = true
    public init() {}
}

/// 이벤트 → 진동 계획. 상태: 마지막 진동 시각(뭉개기)
public struct HapticPlanner: Sendable {
    public var settings = HapticSettings()
    private var lastAt = -Double.infinity
    private var comicT = -99.0
    public init() {}

    /// 한 틱의 이벤트들 → 진동 묶음. now = 화면 시각(초, 단조 증가)
    public mutating func plan(_ events: [SimEvent], now: Double) -> [HapticPulse] {
        guard settings.enabled else { return [] }
        // 한 틱에 여러 개면 가장 무거운 것 하나만(웹도 한 프레임에 buzz 가 겹치면 마지막 하나만 체감된다)
        // 웹 comicSFX 간격(0.5초 · comicT=0 이면 바로): 걸러진 만화 글자는 진동도 없다
        var evs: [SimEvent] = []
        for e in events {
            switch e {
            case .comicReset: comicT = -99
            case .comicWord:
                if now - comicT < 0.5 { continue }
                comicT = now; evs.append(e)
            default: evs.append(e)
            }
        }
        guard let best = evs.compactMap(pattern(for:)).max(by: { weight($0) < weight($1) }) else { return [] }
        if now - lastAt < settings.minInterval { return [] }
        lastAt = now
        return best
    }

    private func weight(_ p: [HapticPulse]) -> Double { p.map { $0.intensity * (1 + $0.tail * 4) }.reduce(0, +) }

    /// 주인공이 적을 때린 타격 중 진동이 나는 것(웹 그대로 — 무게 H 라도 넉백 · 치명 · 띄우기가 아니면 없다)
    public static func heroHitBuzzes(_ h: HitInfo) -> Bool { h.attackerIsHero && !h.heroWasHit && (h.knock || h.crit || h.reactOpt == "launch") }

    /// 웹 buzz 호출 지점과 같은 순간(docs/03 햅틱 표). 세기 · 날카로움은 무게에 맞춰 나눴다
    func pattern(for e: SimEvent) -> [HapticPulse]? {
        let rich = settings.richTails
        switch e {
        case .hit(let h) where !h.heroWasHit:
            // 웹 27-actors damage: att===hero && (o.knock || o.crit || o.react==='launch') → buzz(o.bigCrit ? 28 : 16)
            guard Self.heroHitBuzzes(h) else { return nil }
            if h.bigCrit { return [HapticPulse(intensity: 0.85, sharpness: 0.75, tail: rich ? 0.05 : 0)] }
            return [HapticPulse(intensity: 0.6, sharpness: 0.85)]
        case .heroHurt(let w):
            // 주인공 피격(buzz 25): 무거운 공격일수록 둔하고 길게
            let s = settings.heroHurtScale
            switch w {
            case .light: return [HapticPulse(intensity: 0.6 * s, sharpness: 0.5)]
            case .medium: return [HapticPulse(intensity: 0.8 * s, sharpness: 0.4, tail: rich ? 0.04 : 0)]
            case .heavy: return [HapticPulse(intensity: 0.95 * s, sharpness: 0.3, tail: rich ? 0.09 : 0)]
            }
        case .comicWord(let w, _, _) where w == "KA-BOOM!":
            // 웹 comicSFX: 'KA-BOOM!' 글자가 뜨면 buzz(50) — 마지막 적 · 두목 마무리 · 종착역 필살기 끝
            return [HapticPulse(intensity: 0.9, sharpness: 0.5, tail: rich ? 0.12 : 0)]
        case .bossAppear:
            // 두목 등장(buzz 70): 낮고 길게 울린 뒤 한 번 더
            return rich ? [HapticPulse(intensity: 1, sharpness: 0.2, tail: 0.18), HapticPulse(offset: 0.24, intensity: 0.7, sharpness: 0.3)]
                        : [HapticPulse(intensity: 1, sharpness: 0.5)]
        case .specialUsed:
            // 필살기([40,30,60]): 두 번 — 두 번째가 더 무겁게
            return [HapticPulse(intensity: 0.9, sharpness: 0.6), HapticPulse(offset: 0.07, intensity: 0.9, sharpness: 0.4, tail: rich ? 0.08 : 0)]
        case .guardBlock(let g) where !g.whiff:
            // 네이티브 공방: 막기 = 가볍고 날카롭게 '톡'(무거우면 조금 세게) · 저스트 가드 = 또렷하게 두 번
            if g.just { return [HapticPulse(intensity: 0.8, sharpness: 0.95), HapticPulse(offset: 0.06, intensity: 0.6, sharpness: 0.9)] }
            return [HapticPulse(intensity: g.heavy ? 0.5 : 0.35, sharpness: 0.9)]
        case .guardCrash:
            // 가드 크래시: 깨지는 '탁' 뒤 무거운 '쿵'
            return [HapticPulse(intensity: 0.85, sharpness: 0.8), HapticPulse(offset: 0.07, intensity: 1, sharpness: 0.3, tail: rich ? 0.1 : 0)]
        case .roofBlast:
            // 퇴근 승천권 지붕 뚫기: 날카로운 '쾅' 뒤 길게 울리는 무거운 진동(가장 센 것)
            return [HapticPulse(intensity: 1, sharpness: 0.85), HapticPulse(offset: 0.06, intensity: 1, sharpness: 0.2, tail: rich ? 0.22 : 0)]
        case .roofThud:
            // 지붕 위 '…쿵': 멀리서 작게
            return [HapticPulse(intensity: 0.3, sharpness: 0.25)]
        case .fxDetail(let d) where d.kind == "nv_alert":
            // 끼어들기 예고: 짧게 두 번(탭 받아치기 기회)
            return [HapticPulse(intensity: 0.45, sharpness: 0.7), HapticPulse(offset: 0.09, intensity: 0.45, sharpness: 0.7)]
        case .haptic(let w):
            // 규칙이 직접 요청한 진동(차 부수기 등 — 모드가 늘면 쓴다)
            switch w { case .light: return [HapticPulse(intensity: 0.5, sharpness: 0.8)]
                       case .medium: return [HapticPulse(intensity: 0.75, sharpness: 0.6)]
                       case .heavy: return [HapticPulse(intensity: 0.9, sharpness: 0.4), HapticPulse(offset: 0.08, intensity: 1, sharpness: 0.3, tail: rich ? 0.1 : 0)] }
        default:
            return nil
        }
    }
}
