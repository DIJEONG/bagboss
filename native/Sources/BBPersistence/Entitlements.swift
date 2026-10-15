// 2단계 A(에이전트 O): 유료 스킨 해금 캐시 · Game Center 리더보드 점수 규칙 — 앱(StoreKit · GameKit)과 떨어진 순수 규칙.
//   bbn-skins : 네이티브 전용 키. StoreKit 2 Transaction.currentEntitlements 에서 얻은 '가진 스킨' 캐시(오프라인 · 첫 화면용).
//               진짜 근거는 언제나 StoreKit 이다 — 캐시는 앱을 켠 직후 · 비행기 모드에서 이미 산 스킨을 잠그지 않으려고 둔다.
//   웹 OPT.skin(dotlab-opt.skin)은 '고른 스킨'이고 여기 캐시는 '가진 스킨'이다. 고른 스킨이 잠겨 있으면 기본(jw)으로 돌린다.
import Foundation

// MARK: - SkinUnlocks (bbn-skins)

/// 가진 유료 스킨 캐시(스킨 열쇠 목록 — 정렬해 저장해 같은 상태면 같은 바이트)
public struct SkinUnlocks: Codable, Sendable, Equatable {
    public static let storageKey = "bbn-skins"
    /// 기본 스킨(웹 SKINS.jw.free)
    public static let defaultSkin = "jw"

    public var owned: Set<String> = []
    public init(owned: Set<String> = []) { self.owned = owned }

    public init(from decoder: Decoder) throws { owned = Set(try decoder.singleValueContainer().decode([String].self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(owned.sorted()) }

    /// 깨졌거나 없으면 빈 캐시
    public static func load(webJSON raw: String?) -> SkinUnlocks {
        guard let raw, let d = raw.data(using: .utf8), let v = try? JSONDecoder().decode(SkinUnlocks.self, from: d) else { return SkinUnlocks() }
        return v
    }

    /// 이 스킨을 입을 수 있나(무료 · 가진 것)
    public func isUnlocked(_ key: String, free: Set<String>) -> Bool { free.contains(key) || owned.contains(key) }

    /// 고른 스킨을 실제로 입힐 스킨(잠겼거나 모르는 스킨이면 기본)
    public func effectiveSkin(selected: String?, free: Set<String>, known: Set<String>) -> String {
        guard let s = selected, known.contains(s), isUnlocked(s, free: free) else { return Self.defaultSkin }
        return s
    }
}

public extension SaveStore {
    func skinUnlocks() -> SkinUnlocks { SkinUnlocks.load(webJSON: string(forKey: SkinUnlocks.storageKey)) }
    func setSkinUnlocks(_ u: SkinUnlocks) { setJSON(u, forKey: SkinUnlocks.storageKey) }
}

// MARK: - 리더보드 점수(Game Center)

/// Game Center 에 올리는 정수 점수. 리더보드는 '높을수록 좋음' 하나의 정수만 비교하므로 타워는 층 + 시간을 한 수에 담는다.
public enum LeaderboardScore {
    /// 시간 칸(초) — 9999초(2시간 46분) 넘으면 같은 값
    public static let towerTimeCap = 9999

    /// 타워: 층 × 10000 + (9999 − 걸린 초). 높은 층이 먼저, 같은 층이면 빨리 오른 쪽이 위. 0층(못 오름)은 0
    public static func tower(floor: Int, seconds: Int) -> Int {
        guard floor > 0 else { return 0 }
        return floor * 10000 + (towerTimeCap - max(0, min(towerTimeCap, seconds)))
    }
    /// 거꾸로(표시 · 점검용)
    public static func decodeTower(_ v: Int) -> (floor: Int, seconds: Int) {
        guard v > 0 else { return (0, 0) }
        return (v / 10000, towerTimeCap - v % 10000)
    }

    /// 로그인했을 때 한꺼번에 올릴 지금까지의 기록(저장 메타에서) — 나중에 로그인해도 오프라인 기록이 빠지지 않는다
    public struct Bests: Sendable, Equatable {
        public var runScore: Int = 0
        /// 정시 · 야근 단계 모두 가운데 가장 좋은 타워 점수
        public var tower: Int = 0
        /// 오늘의 타워(그날 열쇠의 기록만)
        public var dailyTower: Int = 0
        public init() {}
    }

    public static func bests(_ M: MetaState, dailyKey: String) -> Bests {
        var b = Bests()
        b.runScore = max(0, Int(M.best.score.rounded()))
        if let T = M.tower {
            var top = T.best > 0 ? tower(floor: T.best, seconds: T.bestT > 0 ? Int(T.bestT.rounded()) : towerTimeCap) : 0
            for (_, r) in T.lv ?? [:] { top = max(top, tower(floor: r.f, seconds: Int(r.t.rounded()))) }
            b.tower = top
            if let d = T.daily?[dailyKey] { b.dailyTower = tower(floor: d.f, seconds: Int(d.t.rounded())) }
        }
        return b
    }
}
