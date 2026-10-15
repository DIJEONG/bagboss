import Foundation
import BBContent

// 개발자 도구 · 자세 편집기 핵심(웹 14-pose-editor.js — PE_FIELDS · peDiff · peApplySaved · peToFK · PE_CTL).
//   · 수정분(diff): 자세 하나당 PE_FIELDS 중 원본과 다른 필드만(없어진 필드는 null) — 웹 localStorage 'dotlab-poseEdits' 와 같은 모양
//   · 실행 중 덮어쓰기 층(PoseOverrides): 편집한 자세를 이름으로 끼워 넣는다. 시뮬레이션(SimData.poses — 큐 · 공중 판정)과
//     그리기(AnimTables — BBPresentation 리그)가 모두 `poses[live: 이름]` 으로 읽어 고친 값이 스튜디오 · 실전에 바로 보인다.
//     덮어쓴 것이 없으면(active 거짓) 조회는 원래 사전 조회 그대로다 → 기본 동작 · 웹 대조 · 감사(BB_AUDIT) 결과가 바이트 단위로 같다.
// 이 파일은 UI 를 모른다 — 앱 쪽 PoseEditorPanel(Features/)이 화면 · 저장('bbn-pose-edits')을 맡는다.

/// 실행 중 자세 덮어쓰기(개발 전용 — 자세 편집기). 이름 → 편집한 자세 전체.
public final class PoseOverrides: @unchecked Sendable {
    /// 덮어쓴 자세가 하나라도 있나(빠른 길 — 거짓이면 잠그지도 않는다)
    nonisolated(unsafe) public private(set) static var active = false
    private static let lock = NSLock()
    nonisolated(unsafe) private static var table: [String: Pose] = [:]

    /// 이름의 덮어쓰기(없으면 nil)
    public static func pose(_ name: String) -> Pose? {
        guard active else { return nil }
        return lock.withLock { table[name] }
    }
    /// 덮어쓰기 넣기 · 빼기(nil)
    public static func set(_ name: String, _ p: Pose?) {
        lock.withLock {
            if let p { table[name] = p } else { table.removeValue(forKey: name) }
            active = !table.isEmpty
        }
    }
    /// 모두 지우기 → 원래 표 그대로
    public static func removeAll() { lock.withLock { table.removeAll(); active = false } }
    /// 지금 덮어쓴 것 전부(복사본)
    public static var all: [String: Pose] { lock.withLock { table } }
}

extension Dictionary where Key == String, Value == Pose {
    /// 자세 편집기 덮어쓰기를 거친 조회 — 표에 있는 이름만 덮는다(웹 peApplySaved: POSES 에 없는 이름은 건너뛴다)
    @inline(__always) public subscript(live name: String) -> Pose? {
        if PoseOverrides.active, let o = PoseOverrides.pose(name), self[name] != nil { return o }
        return self[name]
    }
}

public enum PoseEdit {
    /// 웹 PE_FIELDS — 편집기가 고치는 필드(수정분은 이것만 담는다) + roll(몸 전체 기울기 — 네이티브 편집기 추가, 웹 렌더러도 roll 을 그린다)
    public static let fields = ["spin", "roll", "hn", "hy", "t", "ty", "air", "legH", "legFK", "lFT", "lFK", "lBT", "lBK", "sprF", "sprB", "spr", "armFK", "uF", "lF", "uB", "lB"]
    /// 자세 하나의 수정분(필드 → 값 · 없어진 필드는 .null)
    public typealias Diff = [String: JSONValue]

    // MARK: 필드 읽기 · 쓰기(JSON 값으로)

    static func numKP(_ f: String) -> WritableKeyPath<Pose, Double?>? {
        switch f {
        case "spin": \.spin
        case "roll": \.roll
        case "hn": \.hn
        case "hy": \.hy
        case "t": \.t
        case "ty": \.ty
        case "air": \.air
        case "legH": \.legH
        case "lFT": \.lFT
        case "lFK": \.lFK
        case "lBT": \.lBT
        case "lBK": \.lBK
        case "sprF": \.sprF
        case "sprB": \.sprB
        case "spr": \.spr
        case "uF": \.uF
        case "lF": \.lF
        case "uB": \.uB
        case "lB": \.lB
        default: nil
        }
    }
    static func boolKP(_ f: String) -> WritableKeyPath<Pose, Bool?>? {
        switch f {
        case "legFK": \.legFK
        case "armFK": \.armFK
        default: nil
        }
    }

    /// 필드 값(없음 = .null)
    public static func value(_ P: Pose, _ f: String) -> JSONValue {
        if let k = numKP(f) { return P[keyPath: k].map { .number($0) } ?? .null }
        if let k = boolKP(f) { return P[keyPath: k].map { .bool($0) } ?? .null }
        return .null
    }
    /// 필드 쓰기(.null = 지우기)
    public static func setValue(_ P: inout Pose, _ f: String, _ v: JSONValue) {
        if let k = numKP(f) { P[keyPath: k] = v.double }
        else if let k = boolKP(f) { P[keyPath: k] = v.bool }
    }

    // MARK: 수정분(웹 peDiff · peApplySaved)

    /// 원본 O 와 다른 PE_FIELDS 만
    public static func diff(_ P: Pose, from O: Pose) -> Diff {
        var d: Diff = [:]
        for f in fields { let v = value(P, f); if v != value(O, f) { d[f] = v } }
        return d
    }
    /// 원본에 수정분을 얹는다(null = 그 필드 지우기).
    ///   웹 peApplySaved 는 null 필드를 버리고 합쳐 '원본에 있던 값을 지운 수정'(예: 골반을 바닥에 맞추기로 legH 를 지움)이
    ///   다시 켤 때 되살아난다 — 네이티브는 지운 그대로 둔다(diff → apply 왕복이 같은 자세).
    public static func apply(_ d: Diff, to O: Pose) -> Pose {
        var P = O
        for (f, v) in d { setValue(&P, f, v) }
        return P
    }

    // MARK: 옛 방식 → 각도 값(웹 peToFK)

    /// 옛 방식(팔 IK · 발 목표) 자세를 같은 모양의 각도 값으로. 이미 각도 값인 쪽은 그대로.
    ///   웹과 같게: 팔은 toFK(소수 둘째 자리) · 다리는 solveLeg 로 무릎 · 발을 풀어 허벅지 · 무릎 각도(소수 첫째 자리)와 골반 높이 legH.
    ///   네이티브 보정(관절 위치가 1px 안에서 그대로 남게 — 웹은 빠뜨려 처음 고칠 때 자세가 튈 수 있다):
    ///     팔은 관절 풀이가 고른 해에서 각도를 읽고(팔꿈치를 드는 upF · upB · 곧게 위로 뻗은 팔도 그대로),
    ///     다리 벌리기(spr)는 관절 풀이와 같이 발 목표 높이를 늘인다.
    ///   (팔 · 다리 늘이기 strF · strB · strL 은 각도 값으로 담을 수 없어 웹처럼 길이가 원래대로 돌아온다 — 각도만 같다)
    public static func toFK(_ P: Pose, rig R: RigDims) -> Pose {
        var o = P
        if P.armFK != true {
            func ang(_ A: V2, _ B: V2) -> Double { atan2(B.x - A.x, B.y - A.y) / (Double.pi / 8) }
            func r2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
            // 관절 풀이(solveJoints)가 실제로 고른 팔꿈치에서 각도를 읽는다 — 팔을 곧게 위로 뻗은 자세(aF≈8)는 두 해의 높이가 같아
            // 어깨 자리에 따라 고르는 쪽이 갈린다(웹 toFK 처럼 원점에서 다시 풀면 팔꿈치가 반대로 접힐 수 있다)
            let J = solveJoints(P, rig: R, input: JointInput(tilt: nil, airOv: nil, walkResidual: nil, weaponSprite: nil)).0
            o.armFK = true
            o.uF = r2(ang(J.shF, J.elbF)); o.lF = r2(ang(J.elbF, J.handF)); o.uB = r2(ang(J.shB, J.elbB)); o.lB = r2(ang(J.elbB, J.handB))
        }
        if P.legFK != true {
            let sc = or(R.sc, 1), L1 = or(R.thigh, 6), L2 = or(R.shin, 7), LL = L1 + L2
            let pb = P.b ?? V2(.nan, .nan)
            let hips = V2(jsRound(pb.x * sc), R.hip + jsRound(pb.y * sc)), kL = or(P.strL, 1)
            func r1(_ x: Double) -> Double { (x * 10).rounded() / 10 }
            func leg(_ fp: V2?, _ base: V2, _ k: Double, _ spr: Double) -> (Double, Double) {
                let Hj = hips + base
                var T = V2(base.x + (fp?.x ?? 0) * LL, min(0, (fp?.y ?? 0) * LL))
                let sk = 1 / cos(spr * .pi / 180)
                if sk != 1 { T = V2(T.x, Hj.y + (T.y - Hj.y) * sk) }   // 관절 풀이 tgtS 와 같게(웹 peToFK 에는 없음)
                let q = solveLeg(Hj, T, L1 * k, L2 * k), th = q.aT * 22.5, ps = q.aS * 22.5
                return (r1(th - 90), r1(ps - th))
            }
            let (a, b) = leg(P.fF, R.legF, kL, P.sprF ?? P.spr ?? 0), (c2, d2) = leg(P.fB, R.legB, 1, P.sprB ?? P.spr ?? 0)
            o.legFK = true; o.lFT = a; o.lFK = b; o.lBT = c2; o.lBK = d2; o.legH = -hips.y
        }
        return o
    }

    // MARK: 조절값(웹 PE_CTL — 범위 · 값 바꾸기 그대로)

    public struct Control: Sendable {
        /// 무리(몸 · 다리 · 팔)
        public let group: String
        public let name: String
        public let min: Double, max: Double
        /// 단위 글자(° 또는 없음 — 공중 · 골반 높이는 px)
        public let unit: String
        let get: @Sendable (Pose) -> Double?
        let put: @Sendable (inout Pose, Double) -> Void
        /// 화면에 보일 값(각도 값 자세 기준 — 웹: 각도 값이 아닌 자세의 다리 · 팔은 0)
        public func read(_ P: Pose) -> Double? { get(P) }
        public func write(_ P: inout Pose, _ v: Double) { put(&P, v) }
    }

    /// 웹 peNrm: −180~180
    public static func nrm(_ a: Double) -> Double { jsMod(jsMod(a, 360) + 540, 360) - 180 }

    public static let groups = ["몸", "다리", "팔"]
    public static let controls: [Control] = [
        Control(group: "몸", name: "몸 회전", min: -180, max: 180, unit: "°", get: { nrm(($0.spin ?? 0) * 360) }, put: { $0.spin = $1 / 360 }),
        // 몸 전체 기울기: 머리부터 발끝까지 통째로 앞(+) · 뒤(−) — roll(바퀴), 축은 몸통 가운데(웹 12-webgl _roll 과 같다)
        Control(group: "몸", name: "몸 전체 기울기", min: -90, max: 90, unit: "°", get: { nrm(($0.roll ?? 0) * 360) }, put: { $0.roll = $1 == 0 ? nil : $1 / 360 }),
        // 고개(얼굴 각도 — 네이티브 추가): 숙임 + · 젖힘 − / 돌림(얼굴을 화면 쪽 + · 안쪽 −) · 0 이면 필드를 지운다
        Control(group: "몸", name: "고개 숙임", min: -60, max: 60, unit: "°", get: { $0.hn ?? 0 }, put: { $0.hn = $1 == 0 ? nil : $1 }),
        Control(group: "몸", name: "고개 돌림", min: -90, max: 90, unit: "°", get: { $0.hy ?? 0 }, put: { $0.hy = $1 == 0 ? nil : $1 }),
        Control(group: "몸", name: "상체 기울기", min: -90, max: 90, unit: "°", get: { ($0.t ?? 0) * 13.5 }, put: { $0.t = $1 / 13.5 }),
        Control(group: "몸", name: "몸통 비틀기", min: -180, max: 180, unit: "°", get: { ($0.ty ?? 0) * 180 / .pi }, put: { $0.ty = $1 * .pi / 180 }),
        Control(group: "몸", name: "공중 높이", min: 0, max: 40, unit: "", get: { $0.air ?? 0 }, put: { $0.air = $1 }),
        Control(group: "몸", name: "골반 높이", min: 0, max: 30, unit: "", get: { $0.legH ?? 0 }, put: { $0.legH = $1 }),
        Control(group: "다리", name: "앞 허벅지", min: -180, max: 180, unit: "°", get: { $0.lFT }, put: { $0.lFT = $1 }),
        Control(group: "다리", name: "앞 무릎", min: -170, max: 170, unit: "°", get: { $0.lFK }, put: { $0.lFK = $1 }),
        Control(group: "다리", name: "앞 벌리기", min: -30, max: 80, unit: "°", get: { $0.sprF ?? $0.spr ?? 0 }, put: { $0.sprF = $1 }),
        Control(group: "다리", name: "뒤 허벅지", min: -180, max: 180, unit: "°", get: { $0.lBT }, put: { $0.lBT = $1 }),
        Control(group: "다리", name: "뒤 무릎", min: -170, max: 170, unit: "°", get: { $0.lBK }, put: { $0.lBK = $1 }),
        Control(group: "다리", name: "뒤 벌리기", min: -30, max: 80, unit: "°", get: { $0.sprB ?? $0.spr ?? 0 }, put: { $0.sprB = $1 }),
        Control(group: "팔", name: "앞 위팔", min: -180, max: 180, unit: "°", get: { nrm(raw($0.uF) * 22.5 - 90) },
                put: { let bd = raw($0.lF) - raw($0.uF); $0.uF = ($1 + 90) / 22.5; $0.lF = $0.uF! + bd }),
        Control(group: "팔", name: "앞 굽힘", min: -180, max: 180, unit: "°", get: { nrm((raw($0.lF) - raw($0.uF)) * 22.5) }, put: { $0.lF = raw($0.uF) + $1 / 22.5 }),
        Control(group: "팔", name: "뒤 위팔", min: -180, max: 180, unit: "°", get: { nrm(raw($0.uB) * 22.5 - 90) },
                put: { let bd = raw($0.lB) - raw($0.uB); $0.uB = ($1 + 90) / 22.5; $0.lB = $0.uB! + bd }),
        Control(group: "팔", name: "뒤 굽힘", min: -180, max: 180, unit: "°", get: { nrm((raw($0.lB) - raw($0.uB)) * 22.5) }, put: { $0.lB = raw($0.uB) + $1 / 22.5 }),
    ]

    /// 웹 슬라이더 표시값: 다리 · 팔 무리는 각도 값 자세일 때만(아니면 0) · 반올림
    public static func shown(_ c: Control, _ P: Pose) -> Int {
        let ok = (P.legFK == true || c.group != "다리") && (P.armFK == true || c.group != "팔")
        guard ok, let v = c.read(P), !v.isNaN else { return 0 }
        return Int(jsRound(v))
    }

    /// 슬라이더 한 번(웹 data-ctl oninput): 각도 값으로 바꾼 뒤 그 조절값을 쓴다
    public static func edit(_ P: Pose, _ c: Control, _ v: Double, rig R: RigDims) -> Pose {
        var n = toFK(P, rig: R); c.write(&n, v); return n
    }
    /// 골반을 바닥에 맞추기(웹 data-pe="floor"): 각도 값으로 바꾸고 골반 높이 지정을 지운다(자동 — 발이 바닥에 닿게)
    public static func floor(_ P: Pose, rig R: RigDims) -> Pose {
        var n = toFK(P, rig: R); n.legH = nil; return n
    }

    // MARK: 저장 · 복사 글

    /// 저장 문자열(이름 → 수정분) — 빈 수정분은 뺀다
    public static func encode(_ all: [String: Diff]) -> String {
        let o = all.filter { !$0.value.isEmpty }
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        return (try? e.encode(o)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    /// 저장 문자열 읽기(깨졌으면 빈 것 — 웹 peLoad)
    public static func decode(_ s: String?) -> [String: Diff] {
        guard let s, let d = s.data(using: .utf8), let v = try? JSONValue.parse(d), let o = v.object else { return [:] }
        var r: [String: Diff] = [:]
        for (k, x) in o { if let m = x.object { r[k] = m.filter { fields.contains($0.key) } } }
        return r
    }

    /// JS 숫자 글(JSON.stringify 처럼 정수는 소수점 없이)
    static func js(_ x: Double) -> String {
        if x.isNaN || x.isInfinite { return "null" }
        if x == x.rounded(), abs(x) < 1e15 { return String(Int(x)) }
        return "\(x)"
    }
    static func swiftNum(_ x: Double) -> String { x.isNaN ? ".nan" : js(x) }

    /// 자세의 모든 필드(웹 POSES 키 이름 · 값이 있는 것만) — 웹 값 복사 줄과 Swift 줄이 같이 쓴다
    static func entries(_ P: Pose) -> [(String, JSONValue)] {
        var a: [(String, JSONValue)] = []
        func n(_ k: String, _ v: Double?) { if let v { a.append((k, .number(v))) } }
        func b(_ k: String, _ v: Bool?) { if let v { a.append((k, .bool(v))) } }
        func s(_ k: String, _ v: String?) { if let v { a.append((k, .string(v))) } }
        func p(_ k: String, _ v: V2?) { if let v { a.append((k, .array([.number(v.x), .number(v.y)]))) } }
        n("r", P.r); p("b", P.b); p("h", P.h); n("t", P.t); n("ty", P.ty); n("air", P.air); n("spin", P.spin); n("roll", P.roll); n("hn", P.hn); n("hy", P.hy)
        n("aF", P.aF); n("eF", P.eF); n("aB", P.aB); n("eB", P.eB); n("strF", P.strF); n("strB", P.strB); b("upF", P.upF); b("upB", P.upB); n("w", P.w)
        b("armFK", P.armFK); n("uF", P.uF); n("lF", P.lF); n("uB", P.uB); n("lB", P.lB)
        p("fF", P.fF); p("fB", P.fB); n("strL", P.strL); n("spr", P.spr); n("sprF", P.sprF); n("sprB", P.sprB)
        b("legFK", P.legFK); n("lFT", P.lFT); n("lFK", P.lFK); n("lBT", P.lBT); n("lBK", P.lBK); n("legH", P.legH)
        s("smear", P.smear); s("smearAt", P.smearAt); n("tail", P.tail)
        b("snap", P.snap); b("impact", P.impact); b("charge", P.charge); b("frontB", P.frontB); n("tv", P.tv)
        return a
    }
    static func jsonText(_ v: JSONValue) -> String {
        switch v {
        case .null: "null"
        case .bool(let b): b ? "true" : "false"
        case .number(let x): js(x)
        case .string(let s): "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        case .array(let a): "[" + a.map(jsonText).joined(separator: ",") + "]"
        case .object(let o): "{" + o.keys.sorted().map { "\"\($0)\":" + jsonText(o[$0]!) }.joined(separator: ",") + "}"
        }
    }

    /// 웹 값 복사 줄: `이름: {자세 전체 JSON},`
    public static func webLine(_ name: String, _ P: Pose) -> String {
        "\(name): {" + entries(P).map { "\"\($0.0)\":" + jsonText($0.1) }.joined(separator: ",") + "},"
    }
    /// 수정분 JSON 줄: `이름: {수정분},`(저장 모양과 같다)
    public static func diffLine(_ name: String, _ d: Diff) -> String { "\(name): " + jsonText(.object(d)) + "," }
    /// Swift 줄(네이티브 포즈 표 — NativeMoves.poses 같은 [String: Pose] 사전에 그대로 붙인다)
    public static func swiftLine(_ name: String, _ P: Pose) -> String {
        let body = entries(P).map { k, v -> String in
            switch v {
            case .bool(let b): return "p.\(k) = \(b)"
            case .number(let x): return "p.\(k) = \(swiftNum(x))"
            case .string(let s): return "p.\(k) = \"\(s)\""
            case .array(let a): return "p.\(k) = V2(\(swiftNum(a[0].double ?? .nan)), \(swiftNum(a[1].double ?? .nan)))"
            default: return ""
            }
        }.joined(separator: "; ")
        return "\"\(name)\": { var p = Pose(); \(body); return p }(),"
    }
}
