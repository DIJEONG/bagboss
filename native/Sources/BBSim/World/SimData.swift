import Foundation
import BBCore
import BBContent
import BBAnim

// 시뮬레이션이 읽는 정적 데이터 묶음(한 번 읽어 여러 판이 같이 쓴다 — 바뀌지 않는 값만).
// 웹 원본 상수 이름을 그대로 둔다(ETYPES · GITEMS · JW_SEQ · POSES · ATK_FEEL · FOE_W …). 모두 '실행된 뒤의 값'(추출기가 굽은 것).

/// 웹 LAUNCH 항목(띄우는 반응의 초기 속도 · 자세)
public struct LaunchDef: Sendable, Decodable {
    public let vy: Double, vx: Double
    public let up: String, fall: String
    public let pts: Int
    public let roll: Double?, drag: Double?
    public let bounce: Bool?, trip: Bool?
}
/// 웹 AIRPOP 항목(공중 타격 무게별 다시 띄우기)
public struct AirPopDef: Sendable, Decodable { public let vy: Double, vx: Double, pts: Int }
/// 웹 SIG 항목(고유 콤보 마무리 효과)
public struct SigDef: Sendable, Decodable {
    public let w: String, k: String, r: Double, dmg: Double
    public let react: String?, stun: Double?
}
/// 웹 BOSS_INFO 항목
public struct BossInfo: Sendable, Decodable { public let n: String, nick: String, col: String, rage: String }
/// 웹 CAR_CONCEPTS 중 규칙이 읽는 것
public struct CarConcept: Sendable, Decodable {
    public let key: String, name: String
    public let desc: String?
    public let oneBit: Bool?, marquee: Bool?
}

public final class SimData: Sendable {
    public let store: ContentStore
    /// 네이티브 동작 개편 콘텐츠를 합친 묶음인가(SimConfig.nativeMoves — World 가 맞는 쪽을 고른다)
    public let nativeMoves: Bool
    private let variants = VariantBox()
    public let game: GameContent
    public let catalog: BagCatalog
    public let poses: [String: Pose]
    public let animTables: AnimTables
    /// 게임 인물 공통 3D 리그 치수(JW_HERO.rig) — lastP(그린 자세) 계산용
    public let heroRig: RigDims
    /// 3D 인물(jw) 동작 시퀀스(JW_SEQ) — 길이 ms
    let seqJW: [String: [SStep]]
    public let loop: Set<String>, falls: Set<String>, reacts: Set<String>, heavyRK: Set<String>
    // 13 rig-grammar
    public let jugG: Double, jugDecay: Double, jugGUp: Double, jugLimit: Double, jugScaleK: Double, jugScaleMin: Double, jugBounceV: Double, jugHitPose: Double
    public let launch: [String: LaunchDef]
    public let airPop: [String: AirPopDef]
    public let reactKB: [String: Double]
    /// 웹 G(동작 문법 기본 칸 수)
    public let grammar: [String: Int]
    // 28 attack-feel
    public let atkFeel: [String: AttackFeel]
    public let foeW: [String: String]
    public let foeTell: [String: Double], foeTellX: [String: Double]
    public let jwCue: [String: String]
    // 27 actors · 07 subway · 37 gimmicks · 32 block-art
    public let moveReach: [String: Double]
    public let strapX: [Double]
    public let spots: [(x: Double, pose: String)]
    public let passengers: [String: [(x: Double, pose: String)]]
    public let doors: [(Double, Double)]
    public let sbW: Double, sbH: Double, floorY: Double
    public let poles: [Double]
    public let sig: [String: SigDef]
    public let sepHF: Double, sepFF: Double
    public let bossInfo: [String: BossInfo]
    public let spcLift: Double
    public let cars: [CarConcept]
    public let dmgK: Double
    public let stations: [String: String]   // 역 id → 한국어 이름(안내 문구용)
    public let barks: [String]
    public let hints: Set<String>

    /// nativeFoes: 네이티브 새 적(스파링꾼 · 라인배커 · 신문팔이)과 노선 배치를 넣을지 — 밸런스 비교 테스트만 끈다(앱 · 기본은 nativeMoves 를 따라 켬)
    public init(store s: ContentStore, nativeMoves nv: Bool = false, nativeFoes: Bool = true) throws {
        store = s; nativeMoves = nv
        let g0 = try GameContent(s)
        let g1 = nv ? g0.adding(items: NativeContent.items, roles: NativeContent.roles, book: NativeContent.book, feel: NativeContent.feel) : g0
        game = nv && nativeFoes ? g1.adding(enemies: NativeContent.enemies, patches: NativeContent.stagePatches) : g1
        catalog = try BagCatalog(game, store: s)
        let anim = nv ? try AnimTables(s).withNativeMoves() : try AnimTables(s)
        animTables = anim
        heroRig = try CharacterDef.load(s, "JW_HERO").rig
        poses = anim.poses; loop = anim.loop; falls = anim.falls; reacts = anim.reacts
        let seq = nv ? try SequenceTable(s).withNativeMoves() : try SequenceTable(s)
        seqJW = seq.jw.mapValues { $0.map { SStep($0.pose, $0.length, $0.blink) } }
        heavyRK = Set(try s.decode("HEAVY_RK", as: SetBox.self).items)
        let jug: [String: Double] = try s.decode("JUG")
        jugG = jug["G"]!; jugDecay = jug["decay"]!; jugGUp = jug["gUp"]!; jugLimit = jug["limit"]!
        jugScaleK = jug["scaleK"]!; jugScaleMin = jug["scaleMin"]!; jugBounceV = jug["bounceV"]!; jugHitPose = jug["hitPose"]!
        launch = try s.decode("LAUNCH"); airPop = try s.decode("AIRPOP"); reactKB = try s.decode("REACT_KB")
        grammar = try s.decode("G")
        atkFeel = Dictionary(uniqueKeysWithValues: game.attackFeel.ordered.map { ($0.key, $0.value) })
        let foeW0: [String: String] = try s.decode("FOE_W")
        foeW = nv ? foeW0.merging(NativeContent.foeW) { a, _ in a } : foeW0   // 네이티브 적 하단기(다리걸기 · 로킥) 예고 무게
        foeTell = try s.decode("FOE_TELL"); foeTellX = try s.decode("FOE_TELLX")
        let cue0: [String: String] = try s.decode("JW_CUE"), reach0: [String: Double] = try s.decode("MOVE_REACH")
        jwCue = nv ? cue0.merging(NativeMoves.cues) { a, _ in a }.merging(NativeMoves.guardCues) { a, _ in a }.merging(NativeMoves.overrideCues) { _, b in b }.merging(NativeMoves.grabCues) { _, b in b } : cue0
        moveReach = nv ? reach0.merging(NativeContent.moveReach) { a, _ in a } : reach0
        strapX = try s.decode("STRAP_X")
        func xp(_ v: [JSONValue]) -> (Double, String) { (v[0].double ?? 0, v[1].string ?? "") }
        let sp: [[JSONValue]] = try s.decode("SPOTS"); spots = sp.map { let p = xp($0); return (p.0, p.1) }
        let pg: [String: [[JSONValue]]] = try s.decode("PASSENGERS")
        passengers = pg.mapValues { $0.map { let p = xp($0); return (p.0, p.1) } }
        let dr: [[Double]] = try s.decode("DOORS"); doors = dr.map { ($0[0], $0[1]) }
        let sb: [String: Double] = try s.decode("SB"); sbW = sb["W"]!; sbH = sb["H"]!; floorY = sb["FLOOR"]!
        poles = try s.decode("POLES")
        sig = try s.decode("SIG")
        sepHF = try s.decode("SEP_HF"); sepFF = try s.decode("SEP_FF")
        bossInfo = try s.decode("BOSS_INFO")
        spcLift = try s.decode("SPC_LIFT")
        cars = try s.decode("CAR_CONCEPTS")
        dmgK = (try? s.decode("DMG_K", as: Double.self)) ?? 100
        if case .object(let stn)? = try? s.raw("STN") {
            var m: [String: String] = [:]
            for (k, v) in stn { if case .object(let o) = v, case .string(let ko)? = o["ko"] { m[k] = ko } }
            stations = m
        } else { stations = [:] }
        barks = (try? s.decode("BARKS")) ?? []
        if case .object(let h)? = try? s.raw("HINTS") { hints = Set(h.keys) } else { hints = [] }
    }

    /// 앱 번들 데이터로 한 번 만든 공유본
    public static func bundled() throws -> SimData { try SimData(store: ContentStore.bundled()) }

    /// 네이티브 동작 개편을 켠(끈) 묶음 — 같은 저장소로 한 번만 만들어 둔다. 이미 그 쪽이면 자기 자신
    public func variant(nativeMoves nv: Bool) -> SimData {
        if nv == nativeMoves { return self }
        return variants.get { try! SimData(store: store, nativeMoves: nv) }
    }

    func item(_ id: String) -> ItemDef? { game.items[id] }
    func enemy(_ t: String) -> EnemyDef? { game.enemies[t] }
    func pose(_ n: String?) -> Pose? { n.flatMap { poses[live: $0] } }

    // MARK: 자세 편집기(개발 — 웹 14-pose-editor pePoses · peUses · peMoves)

    /// 동작의 키 자세(JW_SEQ 에 나온 순서 · 겹침 없이 · POSES 에 있는 것만)
    public func seqPoses(_ anim: String) -> [String] {
        var seen = Set<String>(), r: [String] = []
        for s in seqJW[anim] ?? [] where poses[s.pose] != nil && seen.insert(s.pose).inserted { r.append(s.pose) }
        return r
    }
    /// 이 자세를 쓰는 동작 수(공용 자세 표시)
    public func poseUses(_ pose: String) -> Int {
        seqJW.reduce(0) { n, e in e.key != "__hold" && e.value.contains { $0.pose == pose } ? n + 1 : n }
    }
    /// 무도장 주인공 기술 → 동작 이름(웹 peMoves: 주먹은 콤보 순번으로 잽 · 크로스 · 훅 · 어퍼) — JW_SEQ 에 없으면 nil
    public func heroMoveAnim(_ id: String, combo: Int?) -> String? {
        let an = id == "punch" ? ["jab", "cross", "hook", "upper"][min(3, max(0, combo ?? 0))] : item(id)?.anim
        guard let an, seqJW[an] != nil else { return nil }
        return an
    }
}

/// 다른 쪽 묶음 하나를 게으르게 들고 있는 상자(여러 스레드에서 불려도 한 번만 만든다)
private final class VariantBox: @unchecked Sendable {
    private let lock = NSLock()
    private var other: SimData?
    func get(_ make: () -> SimData) -> SimData {
        lock.lock(); defer { lock.unlock() }
        if let o = other { return o }
        let o = make(); other = o; return o
    }
}

/// 웹 Set 직렬화({"$set": [...]})
struct SetBox: Decodable {
    let items: [String]
    enum K: String, CodingKey { case set = "$set" }
    init(from d: Decoder) throws { items = try d.container(keyedBy: K.self).decode([String].self, forKey: .set) }
}

/// 시퀀스 한 칸(웹 [pose, n, flag]) — n 은 3D 인물(msT)이면 ms, 옛 표면 12fps 칸
struct SStep {
    let pose: String, n: Double, blink: Bool
    init(_ pose: String, _ n: Double, _ blink: Bool = false) { self.pose = pose; self.n = n; self.blink = blink }
}
