// MetaRules — 저장 메타(MetaState) ↔ 규칙 메타(BBSim SimMeta) 사이의 중립 값과 웹 메타 진행 규칙.
//
// BBPersistence 는 BBSim 을 모른다(의존 방향: Persistence ← Core 만). 그래서 SimMeta 와 필드가 1:1 인 중립 값
// `MetaRuleView` 를 두고, 앱(GameBridges)은 SimMeta ↔ MetaRuleView 를 필드 복사만 한다. 의미 있는 변환
// (키 문자열 ↔ 정수 · {seen,ko} ↔ [seen,ko] · 선택 필드 nil 유지 · 모르는 필드 보존)은 전부 여기서 하고 여기서 시험한다.
//
// 합치기는 단조(최댓값 · 합집합)다 — 시뮬레이션은 판 시작 때 initialMeta(= 저장 메타의 ruleView)에서 출발하므로
// 같은 값을 여러 번 합쳐도 결과가 같다(metaChanged 가 몇 번 오든 안전). 지우기(도움말 다시 보기)는 저장 쪽에서만 한다.
//
// 웹 규칙(36-meta-menu · 34-shop · 30-train-env):
//   metaTick(2초마다): GS 누계(kills · stats.*)의 증가분을 META.tot 에 더하고, 역에 문이 열려 있으면 META.stns, KITS.cond 를 넘으면 META.kits 해금
//   showResult: META.runs++ · best.score = max · 오늘의 판이면 META.daily[오늘] = max
//   loadStage(k): META.lines[k]=1 · best.stage = max(best.stage, k)
import Foundation

/// BBSim SimMeta 와 필드 이름 · 모양이 같은 중립 값
public struct MetaRuleView: Sendable, Equatable {
    public struct FloorTime: Sendable, Equatable {
        public var f: Int, t: Int
        public init(f: Int, t: Int) { self.f = f; self.t = t }
    }
    /// 웹 META.tower — SimMeta.tower(TowerMeta) 와 같은 모양(초는 정수)
    public struct Tower: Sendable, Equatable {
        public var best = 0, bestT = 0, runs = 0, ot = 0
        public var lv: [Int: FloorTime] = [:]
        public var daily: [String: FloorTime] = [:]
        public init() {}
        public var isEmpty: Bool { best == 0 && bestT == 0 && runs == 0 && ot == 0 && lv.isEmpty && daily.isEmpty }
    }
    public var seenCut: Set<String> = []
    /// [etype: [seen, ko]]
    public var foes: [String: [Int]] = [:]
    public var items: [String: Int] = [:]
    public var links: Set<String> = []
    public var hints: Set<String> = []
    public var talks: Set<String> = []
    public var spc: [String: Int] = [:]
    /// [id: [n, best]]
    public var cbook: [String: [Int]] = [:]
    /// [key(ids 를 '>' 로 이음): [n, best]]
    public var combos: [String: [Int]] = [:]
    public var bossScenes: [String: Int] = [:]
    public var lines: Set<Int> = []
    public var tower = Tower()
    public var bonusBest = 0
    /// 오늘의 노선 최고 점수 [날짜: 점수] · 프롤로그에서 목격만 한 도감 콤보 · 콤보 노트 이름 [key: 이름]
    public var daily: [String: Int] = [:]
    public var cseen: Set<String> = []
    public var comboNames: [String: String] = [:]
    public init() {}
}

public extension MetaState {
    // MARK: 저장 → 규칙(판 시작 때 SimConfig.initialMeta 로)

    func ruleView() -> MetaRuleView {
        var v = MetaRuleView()
        v.seenCut = Set((seenCut ?? [:]).keys)
        v.foes = foes.mapValues { [$0.seen, $0.ko] }
        v.items = items
        v.links = Set(links.keys)
        v.hints = Set((hints ?? [:]).keys)
        v.talks = Set((talks ?? [:]).keys)
        v.spc = spc ?? [:]
        v.cbook = (cbook ?? [:]).mapValues { [$0.n, $0.best] }
        v.combos = (combos ?? [:]).mapValues { [$0.n, $0.best] }
        v.bossScenes = bossScenes ?? [:]
        v.lines = Set(lines.keys.compactMap(Int.init))
        if let T = tower {
            var t = MetaRuleView.Tower()
            t.best = T.best; t.bestT = Int(T.bestT.rounded()); t.runs = T.runs; t.ot = T.ot ?? 0
            for (k, r) in T.lv ?? [:] { if let l = Int(k) { t.lv[l] = .init(f: r.f, t: Int(r.t.rounded())) } }
            for (k, r) in T.daily ?? [:] { t.daily[k] = .init(f: r.f, t: Int(r.t.rounded())) }
            v.tower = t
        }
        v.bonusBest = Int((bonusBest ?? 0).rounded())
        v.daily = daily.mapValues { Int($0.rounded()) }
        v.cseen = Set((cseen ?? [:]).keys)
        for (k, e) in combos ?? [:] where !e.name.isEmpty { v.comboNames[k] = e.name }
        return v
    }

    // MARK: 규칙 → 저장(metaChanged · towerEnded · bonusEnded · runEnded 때)

    /// 규칙 메타를 합친다(단조 — 최댓값 · 합집합). 바뀌었으면 true.
    @discardableResult
    mutating func merge(_ v: MetaRuleView) -> Bool {
        let before = self
        if !v.seenCut.isEmpty { var d = seenCut ?? [:]; for k in v.seenCut { d[k] = 1 }; seenCut = d }
        for (k, a) in v.foes {
            var r = foes[k] ?? FoeRecord()
            r.seen = max(r.seen, a.first ?? 0); r.ko = max(r.ko, a.count > 1 ? a[1] : 0)
            foes[k] = r
        }
        for (k, t) in v.items { items[k] = max(items[k] ?? 0, t) }
        for k in v.links { links[k] = 1 }
        if !v.hints.isEmpty { var d = hints ?? [:]; for k in v.hints { d[k] = 1 }; hints = d }
        if !v.talks.isEmpty { var d = talks ?? [:]; for k in v.talks { d[k] = 1 }; talks = d }
        if !v.spc.isEmpty { var d = spc ?? [:]; for (k, n) in v.spc { d[k] = max(d[k] ?? 0, n) }; spc = d }
        if !v.cbook.isEmpty {
            var d = cbook ?? [:]
            for (k, a) in v.cbook { var e = d[k] ?? ComboBookEntry(); e.n = max(e.n, a.first ?? 0); e.best = max(e.best, a.count > 1 ? a[1] : 0); d[k] = e }
            cbook = d
        }
        if !v.combos.isEmpty {
            var d = combos ?? [:]
            for (k, a) in v.combos {
                var e = d[k] ?? ComboRecord(name: "", ids: k.split(separator: ">").map(String.init))
                e.n = max(e.n, a.first ?? 0); e.best = max(e.best, a.count > 1 ? a[1] : 0); d[k] = e
            }
            combos = d
        }
        if !v.bossScenes.isEmpty { var d = bossScenes ?? [:]; for (k, n) in v.bossScenes { d[k] = max(d[k] ?? 0, n) }; bossScenes = d }
        for l in v.lines { lines[String(l)] = 1; best.stage = max(best.stage, l) }
        if !v.tower.isEmpty || tower != nil {
            var T = tower ?? TowerRecord()
            let t = v.tower
            T.best = max(T.best, t.best)
            // 최단 시간: 0 = 기록 없음(웹 !prevT)
            if t.bestT > 0 { T.bestT = T.bestT > 0 ? min(T.bestT, Double(t.bestT)) : Double(t.bestT) }
            T.runs = max(T.runs, t.runs)
            if t.ot > (T.ot ?? 0) || (T.ot == nil && t.ot > 0) { T.ot = t.ot }
            if !t.lv.isEmpty { var d = T.lv ?? [:]; for (l, r) in t.lv { d[String(l)] = Self.better(d[String(l)], r) }; T.lv = d }
            if !t.daily.isEmpty { var d = T.daily ?? [:]; for (k, r) in t.daily { d[k] = Self.better(d[k], r) }; T.daily = d }
            tower = T
        }
        if v.bonusBest > 0 { bonusBest = max(bonusBest ?? 0, Double(v.bonusBest)) }
        for (k, n) in v.daily { daily[k] = max(daily[k] ?? 0, Double(n)) }
        if !v.cseen.isEmpty { var d = cseen ?? [:]; for k in v.cseen { d[k] = 1 }; cseen = d }
        if !v.comboNames.isEmpty, var d = combos {
            for (k, n) in v.comboNames where d[k] != nil && d[k]!.name.isEmpty { d[k]!.name = n }
            combos = d
        }
        return self != before
    }

    /// 층 기록 비교(웹 towerResult: 더 높은 층, 같은 층이면 더 짧은 시간) — 원래 값의 모르는 필드는 남긴다
    private static func better(_ cur: TowerRecord.FloorTime?, _ r: MetaRuleView.FloorTime) -> TowerRecord.FloorTime {
        guard var c = cur else { return .init(f: r.f, t: Double(r.t)) }
        if r.f > c.f || (r.f == c.f && Double(r.t) < c.t) { c.f = r.f; c.t = Double(r.t) }
        return c
    }

    // MARK: 웹 metaTick · showResult

    /// 누계에 쓰는 키(웹 metaTick 의 cur — tot 의 9개 키와 같다)
    static let tallyKeys = Totals.keys

    /// 판 진행 누계(current — 판 시작부터의 값)에서 지난번(snap) 이후 증가분만 tot 에 더한다. 바뀌었으면 true
    @discardableResult
    mutating func addTally(_ current: [String: Int], snap: inout [String: Int]) -> Bool {
        var changed = false
        for k in Self.tallyKeys {
            let c = current[k] ?? 0, d = c - (snap[k] ?? 0)
            if d > 0 { tot[k] = tot[k] + d; changed = true }
            snap[k] = c
        }
        return changed
    }

    /// 시작 가방 해금 조건(웹 KITS[].cond)
    struct KitCondition: Sendable, Equatable {
        public var id: String, key: String, n: Int
        public init(id: String, key: String, n: Int) { self.id = id; self.key = key; self.n = n }
    }

    /// 조건을 넘은 가방을 연다 — 새로 열린 id(순서 유지)
    mutating func unlockKits(_ conds: [KitCondition]) -> [String] {
        var out: [String] = []
        for c in conds where kits[c.id] == nil && tot[c.key] >= c.n { kits[c.id] = 1; out.append(c.id) }
        return out
    }

    /// 가방 해금 진행률(0..1) · 지금 값(조건 상한으로 자름)
    func kitProgress(_ c: KitCondition) -> (ratio: Double, value: Int) {
        let v = tot[c.key]
        return (min(1, Double(v) / Double(max(1, c.n))), min(v, c.n))
    }

    /// 들른 역(웹 metaStn). 바뀌었으면 true
    @discardableResult
    mutating func visitStation(_ id: String?) -> Bool {
        guard let id, !id.isEmpty, stns[id] == nil else { return false }
        stns[id] = 1; return true
    }

    /// 판 끝(웹 showResult): 판 수 · 최고 점수 · 오늘의 판 점수. 최고 기록을 넘었으면 true
    @discardableResult
    mutating func recordRunEnd(score: Int, dailyKey: String?) -> Bool {
        let newBest = Double(score) > best.score
        runs += 1
        best.score = max(best.score, Double(score))
        if let dk = dailyKey { daily[dk] = max(daily[dk] ?? 0, Double(score)) }
        return newBest
    }

    /// 도움말 다시 보기(웹 META.hints = {})
    mutating func resetHints() { hints = [:] }
}

// MARK: 오늘의 판 열쇠 · 해시(웹 todayKey · hashStr · dailyKit)

public enum DailyKey {
    /// 웹 todayKey(): 현지 날짜 'YYYY-MM-DD'
    public static func today(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }
    /// 웹 hashStr(s): FNV-1a 32비트(문자마다 UTF-16 첫 단위) — BBSim World.hashStr 와 같은 값
    public static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for ch in s.unicodeScalars { h ^= UInt32(String(ch).utf16.first!); h = h &* 16_777_619 }
        return h
    }
    /// 웹 dailyKit(): KITS[hashStr(todayKey()) % KITS.length] 의 번호
    public static func kitIndex(_ key: String, count: Int) -> Int { count > 0 ? Int(hash(key) % UInt32(count)) : 0 }
}
