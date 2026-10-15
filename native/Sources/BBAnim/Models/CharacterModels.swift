import Foundation

// 인물 생김새 → 모델 고르기 — 웹 27-actors.js defFor/LOOK_CACHE · PASS_MODEL, 13-rig-grammar.js skinModel/SKINS 이식.
// 모델은 순수 함수로 만들고, 캐시는 쓰는 쪽(CharacterModelCache — 표현 층 한 곳)이 가진다.

/// 생김새(웹 ETYPES[t].look 에서 머리 하나를 고른 것) — defFor 의 noirModel 입력
public struct LookSpec: Sendable, Hashable {
    public var hair: String?
    public var fat: Bool
    /// 코트 재질 이름(웹 L.coat — 없으면 COAT)
    public var coat: String
    public var boss: Bool
    public var tie: String?
    public var mandarin: Bool
    public init(hair: String? = nil, fat: Bool = false, coat: String = "COAT", boss: Bool = false, tie: String? = nil, mandarin: Bool = false) {
        self.hair = hair; self.fat = fat; self.coat = coat; self.boss = boss; self.tie = tie; self.mandarin = mandarin
    }

    /// BBSim ActorDef.look 열쇠(hair|fat|coat|boss|tie|mandarin — 웹 LOOK_CACHE 키 순서) 풀기. 머리 없음은 "undefined" 또는 빈 칸
    public init?(key: String) {
        let p = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 6 else { return nil }
        hair = (p[0].isEmpty || p[0] == "undefined" || p[0] == "null") ? nil : p[0]
        fat = p[1] == "true"
        coat = p[2].isEmpty ? "COAT" : p[2]
        boss = p[3] == "true"
        tie = p[4].isEmpty ? nil : p[4]
        mandarin = p[5] == "true"
    }

    /// 웹 defFor: noirModel({suit:true, coat:M[L.coat||'COAT'], hair, fat, tie, mandarin})
    public var options: NoirOptions {
        NoirOptions(suit: true, coat: Mat.byName[coat] ?? .nan, hair: hair, fat: fat, tie: tie, mandarin: mandarin)
    }
}

public enum CharacterModels {
    /// 웹 defFor 모델
    public static func look(_ L: LookSpec) -> Model3 {
        if let m = NativeLooks.model(L) {   // 네이티브 전용 적(nv_ 머리) — 몸 크기 배율도 모델에 입힌다(리그는 CharacterStage 가 같은 배율로)
            return NativeLooks.scale(hair: L.hair).map { NativeLooks.scaled(m, $0) } ?? m
        }
        return noirModel(L.options)
    }

    /// 웹 PASS_MODEL — 승객 세 가지(헌팅캡 코트 · 중절모 양복색 · 헌팅캡 양복)
    public static func passenger(_ i: Int) -> Model3 {
        switch ((i % 3) + 3) % 3 {
        case 0: return noirModel(NoirOptions(cap: true))
        case 1: return noirModel(NoirOptions(hatMat: Mat.SUIT))
        default: return noirModel(NoirOptions(coat: Mat.SUIT, cap: true))
        }
    }

    /// 기본 정의 모델(JW_HERO · JW_THUG · JW_BOSS · NOIR_THUG) — 생성물 CharacterDef.model3 와 같다
    public static func base(_ def: String) -> Model3? {
        switch def {
        case "JW_HERO": return noirModel(NoirOptions(suit: true, coat: Mat.SUIT, trou: Mat.SUIT))
        case "JW_THUG": return noirModel(NoirOptions(suit: true, coat: Mat.COAT, cap: true))
        case "JW_BOSS": return noirModel(NoirOptions(suit: true, coat: Mat.COAT))
        case "NOIR_THUG": return noirModel(NoirOptions(cap: true))
        default: return nil
        }
    }

    /// 주인공 스킨 목록(웹 SKINS 순서) — jw 는 기본(무료)
    public static let skins = ["jw", "gala", "rain", "chicago"]

    /// 웹 skinModel(k): 기본 검은 양복 + 3종(실루엣 · 소품). 모르는 열쇠는 기본(jw)
    public static func skin(_ k: String) -> Model3 {
        let M = Mat.self
        switch k {
        case "gala":
            var m = suitModel(NoirOptions(suit: true, coat: M.CANVAS, trou: M.SUIT, noTie: true))
            m["torso", default: []] += [prism(1, 9.6, 4.2, 0.32, 2.8, 3.88, 0.32, 1.0, M.SUIT, 0.42, 2),                          // 검은 새틴 숄 라펠
                                        prism(1.15, 2.45, 4.42, 0.34, 1.6, 4.42, 0.34, 1.6, M.SUIT, 0.36, 2),
                                        prism(1.45, 2.15, 4.66, 0.3, 0.45, 4.66, 0.3, 0.45, M.SUIT, 0.24, 2),                     // 나비넥타이 · 매듭
                                        prism(4.1, 5.5, 3.98, 0.3, 0.85, 3.96, 0.3, 0.85, M.RED, 0.62, 2, -1.5)]                // 가슴 행커치프
            for (pt, pn) in [("thighF", 9.0), ("thighB", 11)] { m[pt, default: []] += [prism(-1, 11, 0, 0.14, 2.86, 0, 0.14, 2.56, M.SUIT, 0.66, pn)] }   // 새틴 줄
            for (pt, pn) in [("shinF", 10.0), ("shinB", 12)] { m[pt, default: []] += [prism(0, 11, 0, 0.14, 2.46, 0, 0.14, 2.16, M.SUIT, 0.64, pn)] }
            for (pt, pn) in [("farmF", 6.0), ("farmB", 8)] {
                m[pt, default: []] += [prism(6.5, 7.3, 0, 1.86, 1.86, 0, 1.86, 1.86, M.FRAME, 0.82, pn), prism(6.6, 7.2, 1.9, 0.22, 0.5, 1.9, 0.22, 0.5, M.GOLD, 0.86, pn)]   // 흰 소매 · 금 커프스
            }
            return m
        case "rain":
            var m = suitModel(NoirOptions(suit: true, coat: M.COAT, trou: M.SUIT, hatMat: M.WOODD, hair: "fedora", tie: "WOODD", bandMat: M.MDARK))
            m["skirtF"] = [prism(-0.5, 14, 0, 4.2, 3.0, 0.6, 5.3, 4.0, M.COAT, 0.46, 3, 2.6)]        // 무릎까지 오는 코트 자락
            m["skirtB"] = [prism(-0.5, 14, 0, 4.2, 3.0, 0.6, 5.3, 4.0, M.COAT, 0.4, 4, -2.6)]
            m["torso", default: []] += [prism(-1.6, 2.6, 0.2, 3.05, 4.1, 0.2, 3.95, 5.4, M.COAT, 0.6, 2),                    // 세운 깃
                                        prism(9.6, 11.2, 0, 3.95, 6.65, 0, 3.93, 6.55, M.COAT, 0.24, 2),
                                        prism(9.8, 11, 3.98, 0.3, 0.95, 3.98, 0.3, 0.95, M.GOLD, 0.82, 2)]                   // 허리띠 · 금 버클
                + [3.6, 6.6].flatMap { y in [-1.15, 1.15].map { l in prism(y, y + 0.75, 4.06, 0.25, 0.46, 4.04, 0.25, 0.46, M.WOODD, 0.4, 2, l) } }   // 더블 단추
                + [prism(1.5, 4.5, -3.9, 0.25, 6.0, -3.7, 0.25, 5.6, M.COAT, 0.52, 2)]                                          // 등 덮개
            for (pt, pn) in [("farmF", 6.0), ("farmB", 8)] { m[pt, default: []] += [prism(5.4, 6.2, 0, 1.9, 1.9, 0, 1.9, 1.9, M.COAT, 0.28, pn)] }   // 소매 끈
            return m
        case "chicago":
            var m = suitModel(NoirOptions(suit: true, coat: M.SUIT, trou: M.SUIT, hatMat: M.SUIT, hair: "fedora", tie: "RED", bandMat: M.FRAME))
            let st = 0.34, S = M.FRAME                                                                       // 핀스트라이프
            m["torso", default: []] += [-2.8, -1.4, 0, 1.4, 2.8].map { x in prism(2, 16.6, x, 0.07, 7.56, x * 0.88, 0.07, 5.76, S, st, 2) }
                + [prism(10.4, 11.4, 3.92, 0.25, 2.6, 3.88, 0.25, 2.2, M.GOLD, 0.82, 2)]                                      // 금 시곗줄
            for (pt, pn) in [("thighF", 9.0), ("thighB", 11)] { m[pt, default: []] += [-1.7, -0.6, 0.6, 1.7].map { x in prism(-1, 11, x, 0.06, 2.82, x * 0.86, 0.06, 2.52, S, st, pn) } }
            for (pt, pn) in [("shinF", 10.0), ("shinB", 12)] { m[pt, default: []] += [-1.4, -0.45, 0.45, 1.4].map { x in prism(0, 11, x, 0.06, 2.42, x * 0.875, 0.06, 2.12, S, st, pn) } }
            for (pt, pn) in [("uarmF", 5.0), ("uarmB", 7)] { m[pt, default: []] += [-1.2, 0, 1.2].map { x in prism(-1, 8, x, 0.06, 2.42, x * 0.83, 0.06, 2.12, S, st, pn) } }
            for (pt, pn) in [("footF", 10.0), ("footB", 12)] { m[pt, default: []] += [prism(-2.5, -0.3, 1.3, 4.12, 2.14, 1.5, 4.22, 2.16, M.FRAME, 0.72, pn)] }   // 흰 각반
            return m
        default:
            return base("JW_HERO")!
        }
    }
}

/// 모델 캐시(웹 LOOK_CACHE · SKIN_CACHE) — 표현 층이 하나 들고 쓴다(값 타입 · 스레드 공유 안 함)
public struct CharacterModelCache: Sendable {
    private var looks: [String: Model3] = [:]
    private var skins: [String: Model3] = [:]
    private var passengers: [Int: Model3] = [:]
    public init() {}

    /// ActorDef.look 열쇠 → 모델(열쇠를 못 풀면 nil)
    public mutating func look(key: String) -> Model3? {
        if let m = looks[key] { return m }
        guard let L = LookSpec(key: key) else { return nil }
        let m = CharacterModels.look(L); looks[key] = m; return m
    }
    public mutating func skin(_ k: String) -> Model3 {
        let k = CharacterModels.skins.contains(k) ? k : "jw"
        if let m = skins[k] { return m }
        let m = CharacterModels.skin(k); skins[k] = m; return m
    }
    public mutating func passenger(_ i: Int) -> Model3 {
        let i = ((i % 3) + 3) % 3
        if let m = passengers[i] { return m }
        let m = CharacterModels.passenger(i); passengers[i] = m; return m
    }
}
