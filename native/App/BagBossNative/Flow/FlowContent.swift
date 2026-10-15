import Foundation
import BBContent
import BBSim

// 흐름 화면(타이틀 · 메뉴 5탭 · 도감 · 결과 · 대화)이 읽는 정적 데이터 — 생성물(Generated/content)에서 한 번 읽는다.
// 웹 이름: KITS · STAGES · ETYPES · STN · GITEMS(REAL_ITEMS) · LINKS · COMBO_BOOK · SIG · BOSS_INFO · SPC · FAMS · HINTS · CAST · TW_*

struct FlowContent {
    struct Station: Decodable { let n: String; let ko: String }
    struct Special: Decodable { let n: String; let en: String }
    struct Family: Decodable { let n: String; let c: String }
    struct Sig: Decodable { let w: String; let d: String }
    struct Boss: Decodable { let n: String; let nick: String; let col: String }
    struct Cast: Decodable { let n: String; let c: String }
    struct Inv: Decodable { let W: Int; let H: Int }
    /// 주인공 양복 스킨(웹 SKINS — 이름 · 부제 · 견본 3색 · 무료)
    struct Skin: Decodable { let n: String; let sub: String; let sw: [String]; let free: Bool? }

    let game: GameContent
    let catalog: BagCatalog
    let kits: [KitDef]
    let stages: [StageDef]
    let stations: [String: Station]
    /// 도감 역 순서(웹 codexHTML stn: 노선별 시작 · 정차 · 짧은 정차 · 교행 — 중복 제거)
    let stationOrder: [String]
    /// 웹 REAL_ITEMS(): 프롤로그 전용(pro)을 뺀 아이템(웹 키 순서)
    let realItems: [String]
    /// 이름이 같은 연계는 하나만(웹 seen)
    let linkGroups: [(name: String, desc: String, ids: [String])]
    let sig: [String: Sig]
    let bossKeys: [String]
    let boss: [String: Boss]
    let specialKeys: [String]
    let specials: [String: Special]
    let families: [String: Family]
    let hints: [String: [String]]
    let cast: [String: Cast]
    let inv: Inv
    let towerTop: Int
    let skinKeys: [String]
    let skins: [String: Skin]

    init(store: ContentStore, data: SimData) throws {
        game = data.game
        catalog = data.catalog
        kits = game.kits
        stages = game.stages
        let stn: [String: Station] = try store.decode("STN")
        stations = stn
        let items = data.game.items
        var order: [String] = [], seen = Set<String>()
        func add(_ s: String?) { if let s, !seen.contains(s) { seen.insert(s); order.append(s) } }
        for S in data.game.stages {
            add(S.start)
            for L in S.line {
                add(L.stop)
                for q in (L.quick ?? []) + (L.passes ?? []) { if case .string(let id)? = q[0] { add(id) } }
            }
        }
        stationOrder = order.filter { stn[$0] != nil }
        realItems = items.keys.filter { items[$0]?.pro != true }
        var groups: [(String, String, [String])] = []
        for L in data.game.links {
            if let i = groups.firstIndex(where: { $0.0 == L.name }) { groups[i].2.append(L.id) } else { groups.append((L.name, L.desc, [L.id])) }
        }
        linkGroups = groups.map { (name: $0.0, desc: $0.1, ids: $0.2) }
        sig = (try? store.decode("SIG")) ?? [:]
        bossKeys = store.entries["BOSS_INFO"]?.keyOrder ?? []
        boss = (try? store.decode("BOSS_INFO")) ?? [:]
        specialKeys = store.entries["SPC"]?.keyOrder ?? ["fist", "foot", "grap"]
        specials = (try? store.decode("SPC")) ?? [:]
        families = (try? store.decode("FAMS")) ?? [:]
        hints = (try? store.decode("HINTS")) ?? [:]
        cast = (try? store.decode("CAST")) ?? [:]
        inv = (try? store.decode("INV")) ?? Inv(W: 6, H: 4)
        towerTop = (try? store.decode("TW_TOP", as: Int.self)) ?? 20
        skinKeys = store.entries["SKINS"]?.keyOrder ?? ["jw"]
        skins = (try? store.decode("SKINS")) ?? [:]
    }

    var towerOTMax: Int { max(0, game.towerOvertime.count - 1) }
    func otName(_ l: Int) -> String { l > 0 ? KE("야근 \(l)단계", "Overtime \(l)") : KE("정시", "Regular") }
    func otRule(_ l: Int) -> TowerRule? { l > 0 && l < game.towerOvertime.count ? game.towerOvertime[l] : nil }
    func mod(_ id: String) -> TowerRule? { game.towerMods.first { $0.id == id } }
    func floorName(_ f: Int) -> String {
        guard f >= 0, f < game.towerFloors.count, let F = game.towerFloors[f] else { return "" }
        return KE(F.name, F.en)
    }
    func stationName(_ id: String?) -> String { id.flatMap { stations[$0] }.map { tr($0.ko) } ?? "" }
    func itemName(_ id: String) -> String { tr(game.items[id]?.name ?? id) }
    /// 계열 색(가방 타일 색과 같은 규칙: fcol → 계열 → 회색)
    func itemColor(_ id: String) -> String {
        let it = game.items[id]
        return it?.fcol ?? it?.fam.flatMap { families[$0]?.c } ?? "#8a90a8"
    }
    func roleGlyph(_ id: String) -> String { BagCatalog.roleGlyph[game.comboRoles[id]?.r ?? ""] ?? "" }
}
