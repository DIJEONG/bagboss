import Foundation
import BBCore

// N5 모드(엘리베이터 타워 · 보너스 차 부수기)의 바깥 계약 — 스냅숏 · 결과 · 메타 기록 값 타입.
// 규칙은 World+Tower.swift · World+Bonus.swift. 여기 타입은 SimAPI 에 '더하기만' 한 필드(SimSnapshot.tower/bonus · SimMeta.tower/bonusBest ·
// SimEvent.towerFloor/towerEnded/bonusEnded)가 쓴다. 필드 이름은 웹 GS.tower · GS.bonus 이름을 따른다.

/// 웹 META.tower — 타워 기록(저장 · 불러오기는 BBPersistence 몫, 바뀌면 metaChanged)
public struct TowerMeta: Sendable, Equatable {
    /// 층 · 걸린 초 기록
    public struct Rec: Sendable, Equatable { public var f: Int, t: Int; public init(f: Int, t: Int) { self.f = f; self.t = t } }
    /// 최고 층 · 꼭대기 최단 초 · 판 수 · 열린 야근 단계
    public var best = 0, bestT = 0, runs = 0, ot = 0
    /// 야근 단계별 기록(웹 META.tower.lv) · 오늘의 타워 기록(웹 META.tower.daily — 날짜 열쇠)
    public var lv: [Int: Rec] = [:]
    public var daily: [String: Rec] = [:]
    public init() {}
}

/// 웹 towerResult 결과 카드 값
public struct TowerResult: Sendable, Equatable {
    public var win = false
    /// 도달 층 · 걸린 초 · 쓰러뜨린 적 · 문밖으로 날림 · 천장 튕기기 · 부순 층
    public var floor = 0, seconds = 0, kills = 0, outs = 0, ceils = 0, wrecks = 0
    public var newRecord = false
    /// 이번에 열린 야근 단계(0 = 없음)
    public var unlocked = 0
    public var ot = 0
    public var daily: String? = nil
    /// 오늘의 타워 조건(TW_MODS id)
    public var mods: [String] = []
    /// 최고 층(전체) · 이 단계 최고 · 오늘 최고
    public var best = 0
    public var levelBest: TowerMeta.Rec? = nil, dailyBest: TowerMeta.Rec? = nil
    public init() {}
}

/// 웹 bonusGrade + 결산표(tally)
public struct BonusResult: Sendable, Equatable {
    /// S · A · B · C · D
    public var grade = "D"
    public var tokens = 0, points = 0
    public var left = 0.0, done = false, pct = 0.0, dps = 0.0
    /// 타격 · 부품 · 파괴 · 시간 · 최대 연타 보너스 · 합계
    public var hit = 0, part = 0, destroy = 0, time = 0, combo = 0, total = 0
    /// 새 최고 기록(웹 T.best)
    public var best = false
    public init() {}
}

/// 타워 진행(그리기 · HUD) — BBPresentation SceneInput.Tower 의 필드를 그대로 채울 수 있다
public struct TowerView: Sendable, Equatable {
    public struct Fly: Sendable, Equatable { public var t: Double, dur: Double, x0: Double, x1: Double, y0: Double, y1: Double, r0: Double }
    public struct Lamp: Sendable, Equatable { public var a: Double, hang: Bool, flick: Double }
    public struct Fire: Sendable, Equatable { public var x: Double, t: Double }
    // SceneInput.Tower 와 같은 이름
    public var pos = 0.0, floor = 1, phase = "arrive", door = 0.0, shk = 0.0
    /// 부서진 층 번호(오름차순)
    public var wreck: [Int] = []
    public var alarm = 0.0
    public var fly: [Fly] = []
    public var sagV = 0.0, limit = 7.0, over = false, panelT = 0.0, kit = true
    public var dent: [Double] = []
    public var lamps: [Lamp] = []
    public var dark = false
    public var fires: [Fire] = []
    public var fl = 0.0
    // HUD(웹 drawTowerTop · 45-hud) · 소리
    public var t = 0.0, vel = 0.0, sag = 0.0
    /// 정원 무게(웹 twWeight)
    public var weight = 0
    public var lurchT = 0.0, blackT = 0.0, gust = 0.0, gdir = 1.0
    /// 차 경보 깜빡임 위상(웹 T.alH)
    public var alarmHigh = false
    public var ot = 0
    public var daily: String? = nil
    public var mods: [String] = []
    /// 경과 초(웹 GS.time - T.t0) · 문밖으로 날림 · 천장 튕기기 · 부순 층 · 최고 층(웹 drawTowerTop best)
    public var seconds = 0.0, outs = 0, ceilN = 0, wrecks = 0, best = 0
    /// 진행률 0..1(웹 45-hud: pos / ((TW_TOP-1)·FH))
    public var progress = 0.0
    public var result: TowerResult? = nil
    public init() {}
}

/// 보너스 차 부수기 진행(그리기 · HUD) — 차 그림은 carBones(stage · dmgF · gone · tilt · shake)로 만든다
public struct BonusView: Sendable, Equatable {
    public struct Debris: Sendable, Equatable { public var key: String, x: Double, y: Double, z: Double, th: Double }
    public struct Car: Sendable, Equatable {
        public var x = 330.0, y = 226.0
        /// 파손 단계 0~8(웹 C.stage — CAR_STAGES 문턱)
        public var stage = 0
        /// 떨어져 나간 부품(웹 C.gone 키)
        public var gone: [String] = []
        public var tilt = 0.0, shake = 0.0, flash = 0.0, dmgF = 0.0
        /// 찌그러짐 개수(웹 carBones 의 dentN = min(18, round(dmgF·24)))
        public var dentN = 0
        public var debris: [Debris] = []
        public init() {}
    }
    /// intro · go · owner
    public var phase = "intro"
    public var t = 0.0, dur = 30.0, left = 30.0, pt = 0.0
    public var hp = 460.0, max = 460.0, dealt = 0.0
    public var score = 0, hitPts = 0, partPts = 0, maxCombo = 0, hits = 0
    /// 경보 · 경보 끔 · 불길
    public var alarm = false, alarmOff = false, fire = false
    public var car = Car()
    /// 차 주인(쓰러져 우는 사람) · 무릎 꿇음 · 탭으로 넘길 수 있음(웹 pt > 2.4)
    public var owner: ActorID? = nil, knelt = false, skippable = false
    public var result: BonusResult? = nil
    public init() {}
}

extension World {
    /// 스냅숏 N5 칸 채우기(Sim.snapshot 끝에서 부른다)
    func fillModes(_ s: inout SimSnapshot) {
        s.props = props.map { var p = SimSnapshot.PropView(kind: $0.k, x: $0.x); p.ice = $0.ice; return p }
        if let T = tw {
            s.tower = towerView(T)
            for i in s.actors.indices {
                guard let a = ents.first(where: { $0.id == s.actors[i].id }), let e = a.e, e.tw.work > 0, e.def.tech == true || e.def.presser == true else { continue }
                let p = e.def.presser == true
                s.actors[i].work = min(1, e.tw.work / (p ? 3 : 5)); s.actors[i].workKind = p ? "presser" : "tech"
            }
        }
        if let B = bn { s.bonus = bonusView(B) }
    }
}
