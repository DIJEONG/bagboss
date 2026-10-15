import Foundation
import BBContent
import BBAnim

// 장면 구성이 읽는 정적 데이터: 스프라이트 크기 · 피벗(아틀라스) · 역 · 노선 · 객차 콘셉트 · 타워 층 · 노선 색 보정.
// 화면 기하 상수(SB · NY · BR · EL · TWR …)는 웹 원본 값 그대로 적는다(TWR 은 추출 표에 없다 — 09-art-tower.js 상수).

/// 웹 SB(07-art-subway-defs) — 객차 단면 480×270
enum SB {
    static let W = 480.0, H = 270.0, CAR_Y = 140.0, FLOOR = 222.0, WIN_Y0 = 160.0, WIN_Y1 = 190.0
}
/// 웹 DOORS — 옆문 두 칸(x 범위)
let DOORS: [(Double, Double)] = [(112, 146), (334, 368)]
/// 웹 POLES(37-gimmicks) — 세로 기둥
let POLES: [Double] = [98, 160, 240, 320, 382]
/// 웹 NY(11-art-stations) — 뉴욕 역 그림 기준선
enum NY { static let CEIL = 34.0, BAND = 112.0, TAB = 160.0, DIR = 182.0, CAP = 98.0, FLOOR = 226.0, LEN = 960.0 }
/// 웹 BR — 다리 구간 수평선 · 해
enum BR { static let HZ = 168.0; static let SUN: (Double, Double) = (352, 116) }
/// 웹 EL — 고가선 수평선
enum EL { static let HZ = 150.0 }
/// 웹 TWR(09-art-tower) — 엘리베이터 칸 · 승강로
enum TWR {
    static let L = 72.0, R = 408.0, G0 = 172.0, G1 = 308.0, GT = 126.0, CEIL = 104.0, PX = 330.0, FH = 300.0, CEIL_H = 62.0, CX = 56.0, CY = 88.0
}
let TW_NEEDLE: [Double] = [-80, -70, -60, -50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50, 60, 70, 80]
let TW_LAMP_A: [Double] = [-30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30]
let TW_LAMPX: [Double] = [128, 352]
let TW_TOP = 20.0, TW_LIMIT = 7.0
/// 클럽 칸 · 바 층 스트로브 색(웹 리터럴)
let STROBE_COLS: [[Double]] = [[1, 0.25, 0.85], [0.2, 0.95, 1], [1, 0.6, 0.15], [0.6, 0.3, 1]]

/// 웹 djIdx(08-art-dojo) — 가장 가까운 값의 첫 번호
func djIdx(_ arr: [Double], _ a: Double) -> Int {
    var k = 0, b = 1e9
    for (i, v) in arr.enumerated() { let d = abs(v - a); if d < b { b = d; k = i } }
    return k
}

/// 객차 콘셉트(웹 CAR_CONCEPTS 한 칸 중 장면 구성이 읽는 것)
public struct CarConcept: Sendable, Decodable, Equatable {
    public let key: String
    public let li: Double?
    public let light: [Double]
    public let oneBit: Bool?, broken: Bool?, works: Bool?, fans: Bool?, lanterns: Bool?, marquee: Bool?, gears: Bool?, strobe: Bool?, cab: Bool?
}

/// 역 그림 설정(웹 STN 한 칸)
public struct StationLook: Sendable, Equatable {
    public let vault: Bool, ruin: Bool, brick: Bool, band: Bool, big: Bool, tab: Bool
    public let beam: String
    init(_ v: JSONValue) {
        func t(_ k: String) -> Bool {
            switch v[k] {
            case .bool(let b)?: b
            case .string(let s)?: !s.isEmpty
            case .number(let n)?: n != 0 && !n.isNaN
            case .array?, .object?: true
            default: false
            }
        }
        vault = t("vault"); ruin = t("ruin"); brick = v["wall"]?.string == "brick"; band = t("band"); big = t("big"); tab = t("tab")
        beam = v["beam"]?.string ?? "undefined"
    }
}

/// 장면 구성 정적 데이터 묶음
public struct SceneContent: Sendable {
    public let sprites: [String: AtlasMeta.Sprite]
    public let stations: [String: StationLook]
    public let stages: [StageDef]
    public let cars: [CarConcept]
    /// 0번은 null(인덱스 = 층)
    public let towerFloors: [TowerFloor?]
    /// 노선별 색 보정(웹 LINE_GRADE)
    public let lineGrade: [(grade: [Double], sat: Double)]
    /// 아이템 아이콘(웹 GITEMS[id].icon)
    public let itemIcons: [String: String]
    /// 보너스 차 3D 모델(웹 CAR_MODEL — CAR_K 배 적용된 조각)
    public let carModel: Model3

    public init(store: ContentStore, atlas: AtlasMeta) throws {
        sprites = atlas.sprites
        let stn = try store.raw("STN").object ?? [:]
        stations = stn.mapValues(StationLook.init)
        stages = try store.decode("STAGES")
        cars = try store.decode("CAR_CONCEPTS")
        towerFloors = try store.decode("TW_FLOORS")
        lineGrade = (try store.raw("LINE_GRADE").array ?? []).map { g in
            ((g["grade"]?.array ?? []).compactMap(\.double), g["sat"]?.double ?? 1)
        }
        let items = try store.table("GITEMS", of: ItemDef.self)
        itemIcons = items.values.mapValues(\.icon)
        carModel = (try? store.decode("CAR_MODEL", as: Model3.self)) ?? [:]
    }

    public static func bundled() throws -> SceneContent {
        try SceneContent(store: .bundled(), atlas: .bundled())
    }
}

/// 스프라이트 그리기 목록 쌓기(웹 quad · placeAt + 층 상태 drawDepth · drawOX · drawRemap · drawPart)
struct Painter {
    let spr: [String: AtlasMeta.Sprite]
    var depth = 0.0, ox = 0.0, remap = 0.0, part = 0.0
    var out: [SpriteDraw] = []

    init(_ spr: [String: AtlasMeta.Sprite]) { self.spr = spr }

    /// 웹 quad: 스프라이트가 없으면 아무것도 하지 않는다
    mutating func quad(_ name: String, _ x: Double, _ y: Double, _ flip: Double = 0, _ flash: Double = 0) {
        guard spr[name] != nil else { return }
        out.append(SpriteDraw(name: name, x: x, y: y, flip: flip, flash: flash, depth: depth, offsetX: ox, remap: remap, part: part))
    }
    /// 웹 placeAt: 피벗 기준 배치
    mutating func placeAt(_ name: String, _ jx: Double, _ jy: Double, _ flip: Bool, _ flash: Double) {
        guard let s = spr[name] else { return }
        let x = flip ? jx - (Double(s.w) - 1 - s.px) : jx - s.px
        quad(name, x, jy - s.py, flip ? 1 : 0, flash)
    }
}
