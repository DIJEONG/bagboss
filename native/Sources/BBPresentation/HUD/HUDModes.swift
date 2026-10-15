import Foundation
import BBCore
import BBSim
import BBContent

// 모드별 HUD 입력(웹 drawUI 가 모드마다 읽는 값) — HUDFrame.modes 로 들어간다. 이름은 웹 그대로.
//   타워   drawTowerTop(24)     · 보너스 drawBonusHUD(43) · 무도장 drawDojoHUD(47)
//   거리 연출 GS.cine(47 drawUI 첫 갈래: 레터박스 22 · drawDmg · 하얀 빛 · 어둠)
//   복도   GS.prologue(47 'B2 CORRIDOR' 진행 막대 · 레터박스 20)
//   쇼 칸  drawShowLamps(29 · SHOW_LAMPS 전구 깜빡임)  · 만화 페이지 drawStory(39 — GS.cut k='story')
// 웹 캡처(tools/js/extract/hud.mjs)는 같은 JSON 을 쓴다 → HUDCapture 가 그대로 푼다.

public struct HUDModes: Sendable, Equatable, Codable {
    /// 웹 drawTowerTop 이 읽는 값
    public struct Tower: Sendable, Equatable, Codable {
        public var floor: Int, name: String
        public var daily: Bool, ot: Int
        /// 정원 무게(twWeight) · 한도(T.limit)
        public var weight: Int, limit: Int
        /// floor(GS.time − T.t0) · 최고 층(오늘/단계 기록과 지금 층 중 큰 것)
        public var secs: Int, best: Int
        /// T.phase === 'hold'(정원 초과 띠)
        public var hold: Bool
        /// 수리 기사 · 회계사 작업 막대 [x(세계), y, k(0..1), presser(0/1)]
        public var workers: [[Double]]
        public init(floor: Int, name: String, daily: Bool, ot: Int, weight: Int, limit: Int, secs: Int, best: Int, hold: Bool, workers: [[Double]]) {
            self.floor = floor; self.name = name; self.daily = daily; self.ot = ot; self.weight = weight; self.limit = limit
            self.secs = secs; self.best = best; self.hold = hold; self.workers = workers
        }
    }
    /// 웹 drawBonusHUD 가 읽는 값
    public struct Bonus: Sendable, Equatable, Codable {
        public var score: Int
        /// max(0, dur − t)
        public var left: Double
        /// phase === 'go'(남은 5초 깜빡임)
        public var go: Bool
        public var hp: Double, max: Double
        /// owner 단계 pt > 1.2 의 등급(S~D)
        public var grade: String?
        public init(score: Int, left: Double, go: Bool, hp: Double, max: Double, grade: String?) { self.score = score; self.left = left; self.go = go; self.hp = hp; self.max = max; self.grade = grade }
    }
    /// 웹 drawDojoHUD — 줄(이름 · 값 · 색)과 아래 오른쪽 상태 글
    public struct Dojo: Sendable, Equatable, Codable {
        public var rows: [[String]]
        public var status: String
        public var paused: Bool
        public init(rows: [[String]], status: String, paused: Bool) { self.rows = rows; self.status = status; self.paused = paused }
    }
    /// 웹 GS.cine(하얀 빛 · 어둠)
    public struct Cine: Sendable, Equatable, Codable {
        public var flash: Double, fade: Double
        public init(flash: Double, fade: Double) { self.flash = flash; self.fade = fade }
    }

    /// 웹 KE() 영어 쪽
    public var en = false
    public var tower: Tower?
    public var bonus: Bonus?
    public var dojo: Dojo?
    public var cine: Cine?
    /// 복도 진행률(GS.prologue.x / CORR_LEN) — 있으면 복도 HUD · 레터박스 20
    public var corridor: Double?
    /// 쇼 칸 전구 [x, k] — 있으면 drawShowLamps
    public var lamps: [[Double]]?
    /// 쇼 칸 불꽃(웹 showSpark 의 HITFX drop · flash — 전구와 같이 그린다)
    public var lampSparks: [HitFx]?
    /// 만화 페이지 진행 초(GS.cut k='story' 의 t) — 시뮬레이션 컷 대신 여기로도 띄울 수 있다(DEBUG -hudstory)
    public var story: Double?
    public init() {}

    enum CodingKeys: String, CodingKey { case en, tower, bonus, dojo, cine, corridor, lamps, lampSparks, story }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        en = try c.decodeIfPresent(Bool.self, forKey: .en) ?? false
        tower = try c.decodeIfPresent(Tower.self, forKey: .tower); bonus = try c.decodeIfPresent(Bonus.self, forKey: .bonus)
        dojo = try c.decodeIfPresent(Dojo.self, forKey: .dojo); cine = try c.decodeIfPresent(Cine.self, forKey: .cine)
        corridor = try c.decodeIfPresent(Double.self, forKey: .corridor); lamps = try c.decodeIfPresent([[Double]].self, forKey: .lamps)
        lampSparks = try c.decodeIfPresent([HitFx].self, forKey: .lampSparks)
        story = try c.decodeIfPresent(Double.self, forKey: .story)
    }
    /// 아무 모드도 아니면 nil 로 둔다(지하철 판 프레임 값은 그대로)
    var isEmpty: Bool { tower == nil && bonus == nil && dojo == nil && cine == nil && corridor == nil && lamps == nil && story == nil }
}

/// 모드 HUD 가 프레임마다 이어 가는 표현 상태(HUDDirector.modeTracker) — 쇼 칸 전구 수열 · 무도장 동작 프레임 수
public struct HUDModeTracker: Sendable {
    /// 웹 SHOW_LAMPS 한 칸(x · k 밝기 · t 남은 초 · q 수열)
    public struct Lamp: Sendable { public var x: Double, k = 1.0, t = 0.0, q: [(Double, Double)] = [] }
    public private(set) var lamps: [Lamp] = []
    /// 쇼 칸 불꽃(웹 showSpark 의 HITFX drop · flash) — 전구 그리기와 같이 그린다
    public private(set) var sparks: [HitFx] = []
    public private(set) var lampsOn = false
    private var rng = SplitMix64(seed: 0x5A0_1A3B)
    /// 무도장 동작 추적(웹 c._djA · _djT · _djS — 동작이 시작된 뒤 지난 12fps 프레임 · 자세가 바뀐 횟수)
    struct DJTrack: Sendable { var anim: String, pose: String, t0: Int, si: Int }
    private var dj: [ActorID: DJTrack] = [:]
    private(set) var tick = 0
    public init() {}

    private mutating func r() -> Double { rng.next() }

    /// 웹 lampSeq()
    private mutating func lampSeq() -> [(Double, Double)] {
        let x = r(), idle = (1.0, 1.5 + r() * 3.5)
        var q: [(Double, Double)] = []
        if x < 0.55 { let n = 3 + Int(r() * 5); for _ in 0..<n { let u = r(); q.append((u < 0.5 ? 0 : u < 0.75 ? 0.35 + r() * 0.6 : 1.7, 0.03 + r() * 0.06)) } }
        else if x < 0.8 { q.append((1.9, 0.06)); q.append((0, 0.12 + r() * 0.15)) }
        else { q.append((0.2, 0.05)); q.append((0, 0.25 + r() * 0.5)); q.append((1.3, 0.05)) }
        q.append(idle)
        return q
    }

    /// 웹 showLampUpdate(dt) + showSpark — on = 쇼 칸(marquee) 지하철 판
    mutating func advanceLamps(dt: Double, on: Bool) {
        lampsOn = on
        for i in sparks.indices {
            sparks[i].t += dt; sparks[i].vy = (sparks[i].vy ?? 0) + 420 * dt
            sparks[i].x += (sparks[i].vx ?? 0) * dt; sparks[i].y += (sparks[i].vy ?? 0) * dt
        }
        sparks.removeAll { $0.t >= $0.life }
        guard on else { return }
        if lamps.isEmpty { lamps = [80.0, 200, 320, 440].map { var L = Lamp(x: $0); L.q = [(1, 0.5 + r() * 2)]; return L } }
        for i in lamps.indices {
            if lamps[i].t > 0 { lamps[i].t -= dt; if lamps[i].q.isEmpty && abs(lamps[i].k - 1) < 0.06 { lamps[i].k = 1 + (r() - 0.5) * 0.04 }; continue }
            if lamps[i].q.isEmpty { lamps[i].q = lampSeq() }
            let (k, d) = lamps[i].q.removeFirst(), was = lamps[i].k
            lamps[i].k = k; lamps[i].t = d
            if ((k < 0.15 && was > 0.6) || k > 1.4) && r() < 0.25 {   // 웹 showSpark
                let y = 140.0 + 12, n = 6 + Int(r() * 6)
                for _ in 0..<n {
                    var p = HitFx(k: "drop", x: lamps[i].x + (r() - 0.5) * 6, y: y, life: 0.45 + r() * 0.35)
                    p.vx = (r() - 0.5) * 150; p.vy = -30 - r() * 70; p.col = r() < 0.5 ? "#fff6c0" : "#ffcf5a"
                    sparks.append(p)
                }
                var f = HitFx(k: "flash", x: lamps[i].x, y: y, life: 0.08); f.big = false; sparks.append(f)
            }
        }
    }

    /// 웹 drawDojoHUD fr(c): 동작이 바뀌거나(반복 아닌 동작의) 단계가 처음으로 돌아가면 다시 센다
    mutating func advanceDojo(_ s: SimSnapshot) {
        tick = Int((s.gameTime * 12).rounded(.down))
        guard s.demo else { if !dj.isEmpty { dj = [:] }; return }
        for a in s.actors where a.isHero || a.dojo {
            if var T = dj[a.id], T.anim == a.pose.anim {
                if T.pose != a.pose.pose { T.si += 1; T.pose = a.pose.pose }
                dj[a.id] = T
            } else { dj[a.id] = DJTrack(anim: a.pose.anim, pose: a.pose.pose, t0: tick, si: 0) }
        }
    }
    func djInfo(_ a: SimSnapshot.ActorView) -> String {
        let T = dj[a.id], fr = tick - (T?.t0 ?? tick)
        return "\(a.pose.anim)  \((T?.si ?? 0) + 1)  \(a.pose.pose)  \(fr)f"
    }
}

/// JS 숫자 → 글자(정수면 소수점 없이 · 그 밖은 짧은 표기)
func jsNumStr(_ v: Double) -> String {
    if v.isFinite && v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
    var s = String(format: "%.12g", v)
    if s.contains("e") { s = String(v) }
    return s
}

extension SimSnapshot {
    /// 웹 charOX(brawl 카메라 = -round(GS.cam)) — 거리 연출 · 보너스 · brawl 장면에서 인물이 그만큼 밀려 그려진다.
    /// HUD 의 인물 기준 자리(말풍선 · 숫자 · 머리 위 막대 · 타격 효과)도 같이 밀어야 인물 위에 붙는다(장면 J 인계).
    public var hudCharOX: Double {
        if let C = cine { return -(C.cam + 0.5).rounded(.down) }
        if bonus != nil || scene == "brawl" { return -(cam + 0.5).rounded(.down) }
        return 0
    }
    /// 인물 x 를 charOX 만큼 민 스냅숏(HUD 전용 — 규칙 값은 그대로)
    public func hudShifted() -> SimSnapshot {
        let ox = hudCharOX
        guard ox != 0 else { return self }
        var s = self
        for i in s.actors.indices { s.actors[i].x += ox }
        return s
    }
}

extension HUDDirector {
    /// 영어 HUD(웹 KE) — BBContent Loc(앱이 설정과 함께 바꾼다). 캔버스 글자 번역(tr)은 OverlayPainter.fillText 가 한다
    static var hudEnglish: Bool { Loc.isEN }
    #if DEBUG
    /// DEBUG `-hudstory`: 만화 페이지를 7.1초마다 되풀이해 띄운다(시뮬레이션은 이 컷을 내지 않는다 — 웹도 지금은 거리 연출로 대신)
    static let debugStory = ProcessInfo.processInfo.arguments.contains("-hudstory")
    #endif

    /// 모드 HUD 값(웹 drawUI 의 모드 갈래들이 읽는 것)
    func modesFrame(_ s: SimSnapshot) -> HUDModes? {
        var M = HUDModes()
        M.en = Self.hudEnglish
        if let T = s.tower {
            let names = catalog.towerFloors
            let nm = T.floor >= 0 && T.floor < names.count ? (M.en ? names[T.floor].en : names[T.floor].ko) : ""
            let workers: [[Double]] = s.actors.compactMap { a in
                guard a.isEnemy, !a.hidden, a.hp > 0, let k = a.work, k > 0 else { return nil }
                return [a.x, a.y, k, a.workKind == "presser" ? 1 : 0]
            }
            M.tower = .init(floor: T.floor, name: nm, daily: T.daily != nil, ot: T.ot, weight: T.weight, limit: Int(T.limit),
                            secs: max(0, Int(T.seconds.rounded(.down))), best: max(T.best, T.floor), hold: T.phase == "hold", workers: workers)
        }
        if let B = s.bonus {
            let g = B.phase == "owner" && B.pt > 1.2 ? B.result?.grade : nil
            M.bonus = .init(score: B.score, left: max(0, B.dur - B.t), go: B.phase == "go", hp: B.hp, max: max(1, B.max), grade: g)
        }
        if let C = s.cine { M.cine = .init(flash: C.flash, fade: C.fade) }
        else if let P = s.prologue { M.corridor = P.progress }
        if s.demo, let D = s.dojo, let H = s.actors.first(where: { $0.isHero }) {
            func tr(_ k: String) -> String { Loc.tr(k) }   // 웹 drawDojoHUD 의 tr — 줄 글은 이어 붙인 뒤라 fillText 번역에 맡기지 않는다
            let Dm = D.dummy.flatMap { id in s.actors.first { $0.id == id } }
            var rows = [[tr("주인공"), modeTracker.djInfo(H), "#ffd34a"]]
            if let Dm { rows.append([tr("상대"), modeTracker.djInfo(Dm) + (Dm.pose.hasJug ? "  ↑\(Int((Dm.airOv + 0.5).rounded(.down)))" : ""), "#ff9a7a"]) }
            var dist = Dm.map { String(Int((abs($0.x - H.x) + 0.5).rounded(.down))) } ?? "-"
            if let L = D.hit {
                dist += "   \(L.me ? tr("맞음") : tr("타격")) \(L.n) \(jsNumStr(L.dmg))" + (L.crit ? " " + tr("치명") : "") + (L.air ? " " + tr("공중") : "") + (L.r.isEmpty ? "" : " · " + L.r)
            }
            rows.append([tr("거리"), dist, "#9fd6ff"])
            let st = jsNumStr((playSpeed * 100).rounded() / 100) + "×" + (D.rep ? "  " + tr("반복") : "") + (D.zoom > 1 ? "  \(tr("확대")) \(jsNumStr(D.zoom))×" : "")
            M.dojo = .init(rows: rows, status: st, paused: false)
        }
        if modeTracker.lampsOn { M.lamps = modeTracker.lamps.map { [$0.x, $0.k] }; M.lampSparks = modeTracker.sparks }
        #if DEBUG
        if Self.debugStory { M.story = now.truncatingRemainder(dividingBy: 7.6) }
        #endif
        return M.isEmpty ? nil : M
    }

    /// 쇼 칸(marquee) 지하철 판인가(웹 drawShowLamps 조건)
    func showCarOn(_ s: SimSnapshot) -> Bool {
        guard s.on, s.scene == "subway", s.tower == nil, s.bonus == nil, s.prologue == nil, s.cine == nil, !s.demo else { return false }
        return s.stageIndex < catalog.marquee.count && s.car < catalog.marquee[s.stageIndex].count && catalog.marquee[s.stageIndex][s.car]
    }
}
