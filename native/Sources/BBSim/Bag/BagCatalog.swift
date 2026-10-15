import Foundation
import BBContent

// 가방 편집 · 미리보기가 쓰는 데이터 묶음: 규칙(BagRules) + 연계(LINKS) 술어 + 합성 확률(MERGE_P) + 옵션(OPTS) + 계열(FAMS)
// 연계 술어는 웹 원문이 함수라 생성물에는 참조만 있다 → 여기 손으로 옮긴다(웹 26-bag-model.js LINKS · lambdas.json 과 1:1).

/// 연계 하나(웹 LINKS 항목) — a 쪽 아이템과 b 쪽 아이템이 닿으면 이름 붙은 연계
public struct BagLink: Sendable {
    public let id: String, name: String, on: String, desc: String
    let a: @Sendable (String) -> Bool
    let b: @Sendable (String) -> Bool
}

/// 아이템 옵션 정의(웹 OPTS) — 이름 · 색 · 굴림 범위 · 합성 상한
public struct BagOptionDef: Sendable, Decodable, Equatable {
    public let n: String, c: String, lo: Double, hi: Double, cap: Double
}

/// 계열(웹 FAMS)
public struct BagFamilyDef: Sendable, Decodable, Equatable {
    public let n: String, c: String
    public let guard_: Double?
    enum CodingKeys: String, CodingKey { case n, c, guard_ = "guard" }
}

public struct BagCatalog: Sendable {
    public let rules: BagRules
    public let links: [BagLink]
    /// 웹 MERGE_P — 지금 등급(1…4)의 합성 성공 확률
    public let mergeChance: [Double]
    public let options: [String: BagOptionDef]
    public let families: [String: BagFamilyDef]

    /// 웹 RT_COL: 콤보 경로 색(경로 순번 % 3)
    public static let routeColors = ["#ff9a3c", "#5fc8ff", "#8dff7a"]
    /// 웹 TIER_COL
    public static let tierColors = ["", "#8a90a8", "#5fd08a", "#5aa8ff", "#c77dff", "#ffcf4a"]
    /// 웹 IMP_NAME · IMP_DESC
    public static let imprintNames = ["holster": "권총집", "pocket": "비밀 주머니", "worn": "해진 안감"]
    public static let imprintDesc = ["holster": "이 칸에 걸친 기술 10% 빨리 발동", "pocket": "이 칸에 걸친 기술 치명 +8%p", "worn": "이 칸에 걸친 기술 피해 −20%"]
    /// 웹 ROLE_G: 역할 배지 글자
    public static let roleGlyph = ["S": "▶", "L": "●", "F": "■", "X": "◇"]

    public init(_ c: GameContent, store: ContentStore) throws {
        let rules = try BagRules(c, store: store)
        self.rules = rules
        mergeChance = c.mergeChance
        options = (try? store.decode("OPTS")) ?? [
            "crit": .init(n: "치명", c: "#ff6a6a", lo: 0.08, hi: 0.14, cap: 0.35), "critd": .init(n: "치피", c: "#ffa04a", lo: 0.25, hi: 0.45, cap: 1.0),
            "dmg": .init(n: "피해", c: "#ffd34a", lo: 0.10, hi: 0.18, cap: 0.45), "cd": .init(n: "쿨", c: "#62a8ee", lo: 0.06, hi: 0.12, cap: 0.3)]
        families = (try? store.decode("FAMS")) ?? [:]
        let knockers: [String] = (try? store.decode("KNOCKERS")) ?? ["kick", "round", "case", "sweep", "charge", "throw"]
        let items = c.items
        let skill: @Sendable (String) -> Bool = { items[$0]?.kind == "skill" }
        let back: @Sendable (String) -> Bool = { items[$0]?.back == true }
        let any: @Sendable ([String]) -> @Sendable (String) -> Bool = { ids in { ids.contains($0) } }
        // 웹 lambdas.json LINKS[n].a/b 그대로
        let preds: [String: (@Sendable (String) -> Bool, @Sendable (String) -> Bool)] = [
            "down": (any(knockers), any(["stomp"])),
            "air": (any(["upper", "skick"]), any(["round", "kick", "fkick"])),
            "grab": (any(["knee"]), any(["throw"])),
            "rush": (any(["elbow"]), any(["punch"])),
            "flank": ({ skill($0) && !back($0) }, back),
            "flank2": (back, { skill($0) && !back($0) }),
            "dodge": (any(["duck"]), skill),
            "scoop": (any(["sweep"]), any(["upper", "punch"])),
            "crumple": (any(["knee"]), any(["upper", "punch"])),
            "airgrab": (any(["upper", "punch", "skick"]), any(["throw"])),
            "spinout": (any(["punch"]), { skill($0) && $0 != "punch" && !back($0) }),
            "gbounce": (any(["stomp"]), any(["upper", "punch"])),
            "pull": (any(["umb"]), any(["punch", "upper"])),
            "pole": (any(["charge", "kick", "round"]), any(["punch", "upper"])),
        ]
        links = c.links.compactMap { L in preds[L.id].map { BagLink(id: L.id, name: L.name, on: L.on, desc: L.desc, a: $0.0, b: $0.1) } }
    }

    public func item(_ id: String) -> ItemDef? { rules.items[id] }

    /// 웹 linkBetween: 두 아이템 사이 이름 붙은 연계(LINKS 순서로 처음 맞는 것)
    public func linkBetween(_ a: String, _ b: String) -> BagLink? {
        links.first { ($0.a(a) && $0.b(b)) || ($0.a(b) && $0.b(a)) }
    }

    /// 웹 MERGE_P[tier]
    public func mergeChance(tier: Int) -> Double { mergeChance.indices.contains(tier) ? mergeChance[tier] : 0 }

    /// 웹 optTag 의 긴 꼴(OPTS[k].f): "치명 +12%"
    public func optionText(_ o: ItemOption) -> String {
        let p = JSFormat.round(o.v * 100)
        switch o.k {
        case "crit": return "치명 +\(p)%"
        case "critd": return "치명 피해 +\(p)%"
        case "dmg": return "피해 +\(p)%"
        case "cd": return "쿨다운 −\(p)%"
        default: return "\(o.k) +\(p)%"
        }
    }
}

/// JS 숫자 서식을 그대로 흉내 낸다(Math.round · toFixed · String(number)) — 웹과 같은 글자가 나와야 하는 곳에서 쓴다
public enum JSFormat {
    /// Math.round: 절반은 +∞ 쪽
    public static func round(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }
    /// Number.prototype.toFixed: 정확한 십진 전개 기준, 딱 절반이면 큰 쪽
    public static func fixed(_ x: Double, _ digits: Int) -> String {
        let s = String(format: "%.\(digits)f", x)
        // printf 는 정확히 절반일 때 짝수 쪽으로 간다 → 전개를 길게 찍어 절반인지 본다
        let long = String(format: "%.60f", abs(x))
        guard let dot = long.firstIndex(of: ".") else { return s }
        let frac = Array(long[long.index(after: dot)...])
        guard frac.count > digits, frac[digits] == "5", frac[(digits + 1)...].allSatisfy({ $0 == "0" }) else { return s }
        let scale = pow(10.0, Double(digits))
        let up = (abs(x) * scale).rounded(.up) / scale
        return String(format: "%.\(digits)f", x < 0 ? -up : up)
    }
    /// String(number): 정수면 소수점 없이
    public static func string(_ x: Double) -> String {
        if x == x.rounded(), abs(x) < 1e15 { return String(Int(x)) }
        return "\(x)"
    }
}
