import Foundation
import Compression

// 웹 데이터 표의 타입 모델. 필드 이름은 JSON(웹 원본) 그대로 두고, 짧은 이름만 Swift 이름으로 바꾼다.
// 모르는 필드는 무시된다 — 새 필드가 생기면 추출 diff 에 보이므로 그때 더한다.

// MARK: 아이템 (GITEMS · 23-game-items)

public struct ItemDef: Sendable, Decodable, Equatable {
    public let name: String
    public let icon: String
    /// 계열(세트 판정) — 보조 아이템 · 해머 기술에는 없다
    public let fam: String?
    /// 칸 좌표 [[x, y]] (회전 0 기준)
    public let shape: [[Int]]
    public let kind: String
    public let desc: String
    public let dmg: Double?
    public let cd: Double?
    public let anim: String?
    public let cue: String?
    public let reach: Double?
    public let cond: String?
    public let react: String?
    public let wpn: String?
    public let stun: Double?
    public let heal: Double?
    public let sn: String?
    public let fcol: String?
    public let fist: Bool?
    public let combo: Bool?
    public let block: Bool?
    public let area: Bool?
    public let knock: Bool?
    public let crit: Bool?
    public let low: Bool?
    public let back: Bool?
    /// 프롤로그 전용 아이템
    public let pro: Bool?

    enum CodingKeys: String, CodingKey {
        case name = "n", icon, fam, shape, kind, desc, dmg, cd, anim, cue, reach, cond, react, wpn, stun, heal, sn, fcol,
             fist, combo, block, area, knock, crit, low, back, pro
    }
}

/// 발동 조건(COND) — 설명용 표
public struct ConditionDef: Sendable, Decodable, Equatable {
    public let tag: String
    public let ko: String
}

// MARK: 적 (ETYPES · 27 + 24 타워 확장)

public struct EnemyDef: Sendable, Decodable, Equatable {
    public let name: String
    public let hp: Double
    public let dmg: Double
    public let cd: Double
    public let spd: Double
    public let remap: Int
    public let moves: [String]
    public let reach: Double
    public let dash: Double?
    public let range: Double?
    public let evade: Double?
    public let wpn: String?
    /// 동작 문법 덮어쓰기 {pre, hit, stop, fol, rec} (12fps 칸)
    public let grammar: [String: Int]?
    public let look: JSONValue?
    public let shield: Bool?, heavy: Bool?, hitrun: Bool?, boss: Bool?, parry: Bool?, lamp: Bool?, meat: Bool?,
               tech: Bool?, janitor: Bool?, pan: Bool?, presser: Bool?, flambe: Bool?

    enum CodingKeys: String, CodingKey {
        case name = "n", hp, dmg, cd, spd, remap, moves, reach, dash, range, evade, wpn, grammar, look,
             shield, heavy, hitrun, boss, parry, lamp, meat, tech, janitor, pan, presser, flambe
    }
}

// MARK: 시작 가방 (KITS · 36-meta-menu)

public struct ItemOption: Sendable, Codable, Equatable {
    public init(k: String, v: Double) { self.k = k; self.v = v }
    public let k: String
    public let v: Double
}

/// 가방 칸 하나 — 웹은 [id, x, y, rot, opt?] 배열
public struct KitSlot: Sendable, Decodable, Equatable {
    public let id: String
    public let x: Int
    public let y: Int
    public let rot: Int
    public let opt: ItemOption?
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        id = try c.decode(String.self)
        x = try c.decode(Int.self); y = try c.decode(Int.self)
        rot = c.isAtEnd ? 0 : try c.decode(Int.self)
        opt = c.isAtEnd ? nil : try c.decodeIfPresent(ItemOption.self)
    }
}

public struct KitUnlock: Sendable, Decodable, Equatable {
    /// META.tot 의 키(crits · footSet · throws …)
    public let k: String
    public let n: Int
    public let t: String
}

public struct KitDef: Sendable, Decodable, Equatable {
    public let id: String
    public let name: String
    public let desc: String
    public let bag: [KitSlot]
    public let cond: KitUnlock?
    enum CodingKeys: String, CodingKey { case id, name = "n", desc, bag, cond }
}

// MARK: 콤보 (COMBO_ROLE · COMBO_BOOK · 32-block-art)

public struct ComboRole: Sendable, Decodable, Equatable {
    /// S 시작기 · L 이음기 · F 마무리기 · X 경로 밖(duck)
    public let r: String
    /// 입력 상태(G/A/T/C/D/B/K/P/Z, '*' = 아무거나) — 없으면 '*' (웹 stIn)
    public let i: String
    /// 출력 상태 — 없으면 '=' 그대로 유지 (웹 stOut)
    public let o: String
    enum CodingKeys: String, CodingKey { case r, i, o }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        r = try c.decode(String.self, forKey: .r)
        i = try c.decodeIfPresent(String.self, forKey: .i) ?? "*"
        o = try c.decodeIfPresent(String.self, forKey: .o) ?? "="
    }
}

public struct ComboRecipe: Sendable, Decodable, Equatable {
    public let id: String
    public let name: String
    public let route: [String]
    public let desc: String
    enum CodingKeys: String, CodingKey { case id, name = "n", route = "r", desc = "d" }
}

/// 연계(LINKS) — a · b 는 술어 함수라 원문 참조만 갖는다(Swift 로 손으로 옮긴다)
public struct LinkDef: Sendable, Decodable, Equatable {
    public let id: String
    public let name: String
    public let on: String
    public let desc: String
    public let a: FunctionRef
    public let b: FunctionRef
    enum CodingKeys: String, CodingKey { case id, name = "n", on, desc, a, b }
}

// MARK: 노선 (STAGES · 25-lines)

public struct CarDef: Sendable, Decodable, Equatable {
    public let car: Int
    public internal(set) var waves: [[String]]
    public let stop: String?
    public let shop: Bool?
    public let end: Bool?
    public internal(set) var fight: [String]?
    /// 다리 구간 {b0, len}
    public let bridge: Bridge?
    /// 교행 [[역, 거리]]
    public let passes: [JSONValue]?
    /// 짧은 정차 [[역, 거리, 적 목록]]
    public internal(set) var quick: [JSONValue]?
    public struct Bridge: Sendable, Decodable, Equatable { public let b0: Double; public let len: Double }
}

public struct StageDef: Sendable, Decodable, Equatable {
    public let key: String
    public let short: String
    public let color: String
    public let name: String
    public let start: String
    public internal(set) var line: [CarDef]
    public internal(set) var reinf: [String]
    public let intro: String
    /// 고가선 여부 — true 또는 구간 문자열
    public let el: JSONValue?
    /// 환승 카드 문구 4줄
    public let card: [String]?
}

// MARK: 타워 (TW_* · 24-tower)

public struct TowerFloor: Sendable, Decodable, Equatable {
    public let name: String
    public let en: String
    /// 층 풍경 스프라이트 접미사(fs_<fs>, 파손판 fs_<fs>_b)
    public let fs: String
    public let col: [Double]
    /// 등장 적
    public let w: [String]?
    public let desc: String
    public let black: Bool?, rest: Bool?, boss: Bool?, flame: Bool?, ice: Bool?, strobe: Bool?, wind: Bool?
    enum CodingKeys: String, CodingKey { case name = "n", en, fs, col, w, desc = "d", black, rest, boss, flame, ice, strobe, wind }
}

public struct TowerRule: Sendable, Decodable, Equatable {
    public let id: String?
    public let name: String
    public let en: String
    /// 적용 함수(원문 참조)
    public let ap: FunctionRef
    enum CodingKeys: String, CodingKey { case id, name = "n", en, ap }
}

// MARK: 타격감 (ATK_FEEL · 28-attack-feel)

public struct AttackFeel: Sendable, Decodable, Equatable {
    /// 무게 L · M · H
    public let w: String
    public let load: String?
    public let hit: String?
    /// 히트스톱(애니메이션 칸)
    public let hs: Double
    public let shake: Double
    public let zoom: Double
    public let step: Double
    public let dust: Double?
}

// MARK: 아틀라스 (atlas.json · tools/js/extract/atlas.mjs)

public struct AtlasMeta: Sendable, Decodable {
    public struct Image: Sendable, Decodable { public let width: Int; public let height: Int; public let a: String; public let n: String }
    public struct Palette: Sendable, Decodable { public let file: String; public let steps: Int; public let materials: Int; public let palettes: Int }
    public struct Sprite: Sendable, Decodable, Equatable {
        public let x: Int, y: Int, w: Int, h: Int
        /// 피벗(스프라이트 안 좌표)
        public let px: Double, py: Double
        /// 0.5 배경 · 1 캐릭터
        public let mask: Double
    }
    public let sourceSha16: String
    public let atlas: Image
    public let palette: Palette
    /// 재질 이름 → 번호(M)
    public let materials: [String: Int]
    public let sprites: [String: Sprite]

    public static func bundled() throws -> AtlasMeta {
        try JSONDecoder().decode(AtlasMeta.self, from: Data(contentsOf: GeneratedResources.url.appending(path: "atlas.json")))
    }

    public func loadAtlasA() throws -> RGBA8Image { try RGBA8Image.load(atlas.a, width: atlas.width, height: atlas.height) }
    public func loadAtlasN() throws -> RGBA8Image { try RGBA8Image.load(atlas.n, width: atlas.width, height: atlas.height) }
    public func loadPalette() throws -> RGBA8Image {
        try RGBA8Image.load(palette.file, width: palette.steps, height: palette.materials * palette.palettes)
    }
}

/// 데이터 픽셀(RGBA8, 행 우선 · 위→아래). 이미지 코덱을 거치지 않는다 — 알파 미리 곱하기 · 색 관리가 끼어들 수 없다.
/// 생성물 형식: raw DEFLATE(RFC 1951) = Foundation `NSData.CompressionAlgorithm.zlib`.
public struct RGBA8Image: Sendable {
    public let width: Int
    public let height: Int
    public let bytes: [UInt8]

    public static func load(_ file: String, width: Int, height: Int) throws -> RGBA8Image {
        let packed = try Data(contentsOf: GeneratedResources.url.appending(path: file))
        let raw = try (packed as NSData).decompressed(using: .zlib) as Data
        guard raw.count == width * height * 4 else { throw ContentError.badPixelData(file, raw.count, width * height * 4) }
        return RGBA8Image(width: width, height: height, bytes: [UInt8](raw))
    }

    /// 풀어서 바로 dst(width·height·4 바이트)에 쓴다 — [UInt8] 사본 없이(렌더러가 MTLBuffer 로 바로 받는다).
    /// Compression 프레임워크 COMPRESSION_ZLIB = raw DEFLATE(RFC 1951) — NSData.decompressed(.zlib) 와 같은 바이트.
    public static func decompress(_ file: String, width: Int, height: Int, into dst: UnsafeMutableRawPointer) throws {
        let packed = try Data(contentsOf: GeneratedResources.url.appending(path: file), options: .mappedIfSafe)
        let want = width * height * 4
        let got = packed.withUnsafeBytes { src -> Int in
            compression_decode_buffer(dst.assumingMemoryBound(to: UInt8.self), want,
                                      src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
        }
        guard got == want else { throw ContentError.badPixelData(file, got, want) }
    }

    @inlinable public func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let i = (y * width + x) * 4
        return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
    }
}

// MARK: 묶음 읽기

/// 자주 쓰는 표를 타입으로 한 번에 읽는다.
public struct GameContent: Sendable {
    public internal(set) var items: OrderedTable<ItemDef>
    public let conditions: OrderedTable<ConditionDef>
    public internal(set) var enemies: OrderedTable<EnemyDef>
    public let kits: [KitDef]
    public internal(set) var comboRoles: OrderedTable<ComboRole>
    public internal(set) var comboBook: [ComboRecipe]
    public let links: [LinkDef]
    public let mergeChance: [Double]
    public internal(set) var stages: [StageDef]
    /// 웹은 1층부터 쓰려고 0번이 null — 그대로 둔다(인덱스 = 층)
    public let towerFloors: [TowerFloor?]
    public let towerOvertime: [TowerRule?]
    public let towerMods: [TowerRule]
    public internal(set) var attackFeel: OrderedTable<AttackFeel>

    public init(_ s: ContentStore) throws {
        items = try s.table("GITEMS")
        conditions = try s.table("COND")
        enemies = try s.table("ETYPES")
        kits = try s.decode("KITS")
        comboRoles = try s.table("COMBO_ROLE")
        comboBook = try s.decode("COMBO_BOOK")
        links = try s.decode("LINKS")
        mergeChance = try s.decode("MERGE_P")
        stages = try s.decode("STAGES")
        towerFloors = try s.decode("TW_FLOORS")
        towerOvertime = try s.decode("TW_OT")
        towerMods = try s.decode("TW_MODS")
        attackFeel = try s.table("ATK_FEEL")
    }
}

// MARK: 네이티브 전용 콘텐츠 합치기(SimConfig.nativeMoves — 웹에 없는 기술 · 콤보 역할 · 손맛)

extension OrderedTable {
    /// 뒤에 항목을 더한 복사본(이미 있는 키는 그대로 둔다)
    public func appending(_ extra: [(String, T)]) -> OrderedTable<T> {
        var k = keys, v = values
        for (key, val) in extra where v[key] == nil { k.append(key); v[key] = val }
        return OrderedTable(keys: k, values: v)
    }
}

extension GameContent {
    /// 네이티브 기술을 더한 복사본 — 기본(웹 대조) 콘텐츠는 바꾸지 않는다
    public func adding(items extraItems: [(String, ItemDef)], roles extraRoles: [(String, ComboRole)], book extraBook: [ComboRecipe],
                       feel extraFeel: [(String, AttackFeel)]) -> GameContent {
        var c = self
        c.items = items.appending(extraItems); c.comboRoles = comboRoles.appending(extraRoles)
        c.comboBook = comboBook + extraBook; c.attackFeel = attackFeel.appending(extraFeel)
        return c
    }
}

// MARK: 네이티브 전용 적(SimConfig.nativeMoves — 웹에 없는 적 종류 · 노선 웨이브 바꿔 넣기)

/// 노선 적 목록 한 곳 바꾸기(웨이브 · 서서 싸우는 정차 · 짧은 정차 · 증원). 바꾸는 쪽(BBSim NativeContent)이 목록을 통째로 준다
public struct StagePatch: Sendable {
    public enum Target: Sendable { case wave(car: Int, wave: Int), fight(car: Int), quick(car: Int, stop: Int), reinf }
    public let stage: String
    public let target: Target
    public let types: [String]
    public init(_ stage: String, _ target: Target, _ types: [String]) { self.stage = stage; self.target = target; self.types = types }
}

extension GameContent {
    /// 새 적 종류를 더하고 노선 적 목록을 바꾼 복사본 — 기본(웹 대조) 콘텐츠는 바꾸지 않는다. 맞는 자리가 없는 바꾸기는 건너뛴다
    public func adding(enemies extra: [(String, EnemyDef)], patches: [StagePatch]) -> GameContent {
        var c = self
        c.enemies = enemies.appending(extra)
        for P in patches {
            guard let si = c.stages.firstIndex(where: { $0.key == P.stage }) else { continue }
            switch P.target {
            case .reinf: c.stages[si].reinf = P.types
            case .wave(let car, let w):
                guard c.stages[si].line.indices.contains(car), c.stages[si].line[car].waves.indices.contains(w) else { continue }
                c.stages[si].line[car].waves[w] = P.types
            case .fight(let car):
                guard c.stages[si].line.indices.contains(car) else { continue }
                c.stages[si].line[car].fight = P.types
            case .quick(let car, let k):
                guard c.stages[si].line.indices.contains(car), var q = c.stages[si].line[car].quick, q.indices.contains(k),
                      var row = q[k].array, row.count >= 3 else { continue }
                row[2] = .array(P.types.map { .string($0) }); q[k] = .array(row)
                c.stages[si].line[car].quick = q
            }
        }
        return c
    }
}
