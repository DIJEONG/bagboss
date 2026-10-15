import Foundation

// 네이티브 강화: 피격 반응 다양화(감독 승인 — 버추어 파이터식 타격감 검토 후속, docs/11 §9).
// 자동 전투라 같은 타격이 끝없이 반복된다 → 웹 반응 키 포즈(hit · hitB · rCross · rHook …)는 그대로 두고,
// 그 위에 '반응 변형'을 덧셈 자세(델타)로 얹어 맞은 자리 · 방향 · 세기 · 몸무게마다 다르게 보이게 한다.
// 원칙
//  · 보이는 층만 — 시뮬레이션의 동작 이름 · 칸 길이 · 경직(hitstun) · 넉백 · 판정은 그대로다. 규칙은 이 값을 모른다.
//  · 결정적 — 벽시계 · 전역 난수 없음. 고르기는 (인물 번호 · 게임 틱 · 그 인물의 피격 수)를 섞은 해시.
//  · 같은 인물에게 같은 변형이 두 번 연달아 나오지 않는다(후보에서 직전 것을 뺀다 — 후보는 늘 2개 이상).
//  · 머리 오프셋(h)은 ±1.2px 안(목 점검 — 큰 h 는 머리를 몸통에서 떼어 놓는다).
//  · 시간은 게임 시계(슬로 · 정지를 따른다). 피격 정지(히트스톱) 동안은 첫 '움찔' 자세에 머문다.

/// 맞은 자리
public enum HitZone: String, Sendable, CaseIterable { case head, body, legs }
/// 맞은 방향(맞는 쪽 기준): 앞 · 등 뒤 · 위에서 내려찍기 · 아래에서 올려 치기
public enum HitDir: String, Sendable, CaseIterable { case front, back, above, below }
/// 세기: 가벼움(잽) · 보통(치명 · 무게 M) · 무거움(무게 H · 받아치기 · 큰 타격) — 무거울수록 길게
public enum HitTier: Int, Sendable, CaseIterable, Comparable {
    case light = 0, medium, heavy
    public static func < (a: HitTier, b: HitTier) -> Bool { a.rawValue < b.rawValue }
}

/// 덧셈 자세(키 포즈 단위 그대로 — r · b · h 는 px(리그 배율 곱해짐), t · aF · aB 는 22.5°, ty 라디안, spin 바퀴, f? 는 다리 길이)
public struct ReactDelta: Sendable, Equatable {
    public var r = 0.0, bx = 0.0, by = 0.0, hx = 0.0, hy = 0.0, t = 0.0, ty = 0.0, spin = 0.0, air = 0.0
    public var fFx = 0.0, fFy = 0.0, fBx = 0.0, fBy = 0.0, aF = 0.0, aB = 0.0
    public init(r: Double = 0, bx: Double = 0, by: Double = 0, hx: Double = 0, hy: Double = 0, t: Double = 0, ty: Double = 0, spin: Double = 0, air: Double = 0,
                fFx: Double = 0, fFy: Double = 0, fBx: Double = 0, fBy: Double = 0, aF: Double = 0, aB: Double = 0) {
        self.r = r; self.bx = bx; self.by = by; self.hx = hx; self.hy = hy; self.t = t; self.ty = ty; self.spin = spin; self.air = air
        self.fFx = fFx; self.fFy = fFy; self.fBx = fBx; self.fBy = fBy; self.aF = aF; self.aB = aB
    }
    public static let zero = ReactDelta()
    public var isZero: Bool { self == .zero }
    static func + (a: ReactDelta, b: ReactDelta) -> ReactDelta {
        ReactDelta(r: a.r + b.r, bx: a.bx + b.bx, by: a.by + b.by, hx: a.hx + b.hx, hy: a.hy + b.hy, t: a.t + b.t, ty: a.ty + b.ty, spin: a.spin + b.spin, air: a.air + b.air,
                   fFx: a.fFx + b.fFx, fFy: a.fFy + b.fFy, fBx: a.fBx + b.fBx, fBy: a.fBy + b.fBy, aF: a.aF + b.aF, aB: a.aB + b.aB)
    }
    static func * (a: ReactDelta, k: Double) -> ReactDelta {
        ReactDelta(r: a.r * k, bx: a.bx * k, by: a.by * k, hx: a.hx * k, hy: a.hy * k, t: a.t * k, ty: a.ty * k, spin: a.spin * k, air: a.air * k,
                   fFx: a.fFx * k, fFy: a.fFy * k, fBx: a.fBx * k, fBy: a.fBy * k, aF: a.aF * k, aB: a.aB * k)
    }
    /// 좌우 거울(비틀기 · 회전 방향만 뒤집는다 — 앞뒤는 그대로)
    var mirrored: ReactDelta { var d = self; d.ty = -ty; d.spin = -spin; return d }
}

/// 반응 변형(표 — docs/11 §9)
public enum HitReactVariant: String, Sendable, CaseIterable {
    // 머리 · 앞
    case snapBack, headTurn, reelAway
    // 몸통 · 앞
    case doubleOver, sideCrunch, windOut
    // 다리
    case legBuckle, hopBack, shinFold
    // 등 뒤
    case archFwd, stumbleFwd, lookBack
    // 위에서
    case crunchDown, duckFlinch
    // 아래에서(올려 치기)
    case liftChin, tipBack
    // 무거운 타격(길게)
    case stagger, kneeBuckle, spinAround

    /// 변형 하나: 키(정규 시간 u · 델타) — u = 0 과 1 은 0(제자리). 길이는 '보통' 세기 기준 초
    public struct Spec: Sendable { public var dur: Double; public var keys: [(u: Double, d: ReactDelta)]; public var big: Bool }

    public var spec: Spec {
        typealias D = ReactDelta
        switch self {
        case .snapBack: return Spec(dur: 0.42, keys: [(0.14, D(r: -2, hx: -1.2, hy: -0.6, t: -1.3, aF: 1, aB: 0.8)), (0.45, D(r: -2.5, by: 1, hx: -0.5, t: -0.5))], big: false)
        case .headTurn: return Spec(dur: 0.42, keys: [(0.14, D(r: -1, hx: -0.8, t: -0.4, ty: 0.9, spin: 0.06, aB: -1)), (0.5, D(r: -1.5, ty: 0.4, spin: 0.03))], big: false)
        case .reelAway: return Spec(dur: 0.48, keys: [(0.16, D(r: -3, by: 1, hx: -0.6, t: -0.7, ty: -0.7, spin: -0.07, fFx: -0.12)), (0.55, D(r: -3.5, by: 1.5, t: -0.2, spin: -0.03, fBx: -0.08))], big: false)
        case .doubleOver: return Spec(dur: 0.5, keys: [(0.15, D(r: -2, bx: -1, by: 2, hy: 0.8, t: 1.5, aF: -1.2, aB: -1.2)), (0.55, D(r: -2.5, by: 2.5, t: 1, aF: -0.8, aB: -0.8))], big: false)
        case .sideCrunch: return Spec(dur: 0.46, keys: [(0.15, D(by: 1.5, hx: 0.5, t: 0.8, ty: -0.9, spin: 0.05, aB: -1.5)), (0.5, D(by: 1.5, t: 0.5, ty: -0.4))], big: false)
        case .windOut: return Spec(dur: 0.5, keys: [(0.12, D(r: -4, bx: -1.5, by: 1, t: 0.5, fBx: -0.12, aF: 1)), (0.5, D(r: -4.5, by: 2, t: 0.9))], big: false)
        case .legBuckle: return Spec(dur: 0.5, keys: [(0.14, D(r: -1, by: 3, t: 0.6, fFx: -0.08, fFy: -0.16)), (0.45, D(r: -1.5, by: 3.5, t: 0.4, fFy: -0.04))], big: false)
        case .hopBack: return Spec(dur: 0.45, keys: [(0.18, D(r: -3, t: -0.5, air: 2.5, fFy: -0.1, fBx: -0.12)), (0.5, D(r: -4, by: 1.5, t: 0.2))], big: false)
        case .shinFold: return Spec(dur: 0.5, keys: [(0.14, D(by: 2, t: 0.8, spin: 0.04, fBx: 0.1, fBy: -0.18)), (0.5, D(by: 2.5, t: 0.3))], big: false)
        case .archFwd: return Spec(dur: 0.48, keys: [(0.14, D(r: 3, bx: 1.5, hx: -1, hy: 0.3, t: -1, aF: 1.2, aB: 1.2)), (0.5, D(r: 3.5, t: -0.3))], big: false)
        case .stumbleFwd: return Spec(dur: 0.52, keys: [(0.15, D(r: 3, hy: 0.6, t: 1.2, fFx: 0.15, aF: -1)), (0.55, D(r: 4.5, by: 1.5, t: 0.6, fBx: 0.1))], big: false)
        case .lookBack: return Spec(dur: 0.5, keys: [(0.16, D(r: 2, t: -0.3, ty: 1, spin: 0.1)), (0.55, D(r: 2.5, ty: 0.5, spin: 0.05))], big: false)
        case .crunchDown: return Spec(dur: 0.48, keys: [(0.12, D(by: 4, hy: 1, t: 0.9, aF: 1, aB: 1)), (0.5, D(by: 3, t: 0.6))], big: false)
        case .duckFlinch: return Spec(dur: 0.46, keys: [(0.14, D(r: -1, by: 3, hy: 0.6, t: 1.3, ty: 0.4)), (0.5, D(by: 2, t: 0.7, ty: 0.2))], big: false)
        case .liftChin: return Spec(dur: 0.48, keys: [(0.15, D(hx: -0.8, hy: -0.8, t: -1.4, air: 1.5, fFy: -0.06, fBy: -0.06, aF: 1.5, aB: 1)), (0.5, D(r: -2, t: -0.6))], big: false)
        case .tipBack: return Spec(dur: 0.5, keys: [(0.15, D(r: -3, by: -1, t: -1, fFy: -0.14, aF: 1)), (0.5, D(r: -3.5, by: 1, t: -0.4))], big: false)
        case .stagger:
            return Spec(dur: 0.8, keys: [(0.12, D(r: -4, by: 1.5, t: -0.9, fFx: -0.1)), (0.35, D(r: -3, by: 3, t: 0.8, ty: 0.4, fBx: -0.12)),
                                         (0.6, D(r: -4, by: 2, t: -0.4, ty: -0.3, fFx: -0.08)), (0.8, D(r: -3.5, by: 1, t: 0.3))], big: true)
        case .kneeBuckle:
            return Spec(dur: 0.85, keys: [(0.1, D(r: -2, by: 3, t: 0.8)), (0.3, D(by: 8, hy: 0.8, t: 1.4, fFx: 0.06, fBx: -0.06, aF: -1, aB: -1)),
                                          (0.6, D(by: 7, t: 1.1)), (0.82, D(by: 2.5, t: 0.4))], big: true)
        case .spinAround:
            return Spec(dur: 0.75, keys: [(0.12, D(r: -2, t: -0.5, ty: 0.6, spin: 0.12)), (0.35, D(r: -3, by: 1.5, t: -0.2, ty: 0.4, spin: 0.3)),
                                          (0.6, D(r: -3.5, by: 2, spin: 0.2)), (0.85, D(r: -3, by: 1, spin: 0.05))], big: true)
        }
    }

    /// 정규 시간 u(0~1)의 델타 — 키 사이는 천천히 출발해 천천히 도착(smoothstep)
    public func delta(at u: Double) -> ReactDelta {
        let ks = spec.keys
        guard u > 0, u < 1, !ks.isEmpty else { return .zero }
        var pu = 0.0, pd = ReactDelta.zero
        for (ku, kd) in ks + [(1.0, ReactDelta.zero)] {
            if u <= ku { let x = (u - pu) / max(1e-6, ku - pu), e = x * x * (3 - 2 * x); return pd + (kd + pd * -1) * e }
            pu = ku; pd = kd
        }
        return .zero
    }
}

/// 몸무게(적 종류마다 — 표로 고친다): 가벼우면 크게 휘청 · 길게, 무거우면 덜 밀린다. spin = 빙글 도는 변형을 쓰나
public struct HitMass: Sendable, Equatable {
    public var amp: Double, dur: Double, spin: Bool
    public init(amp: Double, dur: Double, spin: Bool = true) { self.amp = amp; self.dur = dur; self.spin = spin }
    public static let normal = HitMass(amp: 1, dur: 1)
}

/// 피격 반응 고르기 · 표
public enum HitReact {
    /// 몸무게 표(열쇠 = 적 종류 ETYPES 키 · 주인공은 "hero" · 두목 기본은 "boss*"). 없으면 normal.
    ///   신문팔이 소년(몸 0.8배) 1.4 · 라인배커(1.08배) 0.5 — 감독 '가벼운 적은 더 휘청, 무거운 적은 덜'
    public static let mass: [String: HitMass] = {
        var m: [String: HitMass] = [
            "hero": HitMass(amp: 0.85, dur: 0.95),
            "nv_newsboy": HitMass(amp: 1.4, dur: 1.2), "nv_spar": HitMass(amp: 1.0, dur: 1.0), "nv_lineback": HitMass(amp: 0.5, dur: 0.8, spin: false),
            "boss*": HitMass(amp: 0.5, dur: 0.85, spin: false),
        ]
        for k in ["pick", "accountant", "waiter", "valet", "skater", "thrower", "weasel", "stick"] { m[k] = HitMass(amp: 1.15, dur: 1.05) }
        for k in ["heavy", "brute", "bguard", "neonbig", "bouncer", "butcher"] { m[k] = HitMass(amp: 0.65, dur: 0.9, spin: false) }
        for k in ["boss", "boss2", "boss3", "boss4", "kaneB", "headchef", "mgr"] { m[k] = HitMass(amp: 0.5, dur: 0.85, spin: false) }
        return m
    }()
    public static func mass(type: String?, hero: Bool, boss: Bool) -> HitMass {
        if hero { return mass["hero"]! }
        if let t = type, let m = mass[t] { return m }
        return boss ? mass["boss*"]! : .normal
    }

    /// 자리 · 방향별 후보(앞에서부터 대표). 무거운 타격은 bigPool 이 앞선다
    public static func pool(_ z: HitZone, _ d: HitDir) -> [HitReactVariant] {
        switch (d, z) {
        case (.back, .legs): return [.stumbleFwd, .legBuckle, .lookBack]
        case (.back, _): return [.archFwd, .stumbleFwd, .lookBack]
        case (.above, _): return [.crunchDown, .duckFlinch, .legBuckle]
        case (.below, _): return [.liftChin, .tipBack, .snapBack]
        case (.front, .head): return [.snapBack, .headTurn, .reelAway]
        case (.front, .body): return [.doubleOver, .sideCrunch, .windOut]
        case (.front, .legs): return [.legBuckle, .hopBack, .shinFold]
        }
    }
    /// 무거운 타격 후보(빙글 돌기는 무거운 몸이면 뺀다) — 등 뒤면 앞으로 고꾸라짐도
    public static func heavyPool(_ z: HitZone, _ d: HitDir, mass: HitMass) -> [HitReactVariant] {
        var p: [HitReactVariant] = d == .back ? [.stumbleFwd, .stagger, .kneeBuckle] : z == .legs || d == .above ? [.kneeBuckle, .stagger, .spinAround] : [.stagger, .spinAround, .kneeBuckle]
        if !mass.spin { p.removeAll { $0 == .spinAround }; if p.count < 2 { p.append(pool(z, d)[0]) } }
        return p
    }

    /// SplitMix64 한 번(결정적 해시)
    @inlinable public static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9; z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// 씨앗: 인물 번호 · 게임 틱 · 그 인물 피격 수
    public static func seed(actor: Int, tick: Int, count: Int) -> UInt64 {
        mix(mix(UInt64(bitPattern: Int64(actor)) &* 0x1000_0001 ^ UInt64(bitPattern: Int64(tick))) ^ UInt64(count))
    }

    /// 고르기: 후보에서 직전 변형을 빼고 해시로 하나 + 거울(좌우) 여부
    public static func choose(zone: HitZone, dir: HitDir, tier: HitTier, mass: HitMass, last: HitReactVariant?, seed: UInt64) -> (HitReactVariant, mirror: Bool) {
        var c = tier == .heavy ? heavyPool(zone, dir, mass: mass) : pool(zone, dir)
        if let l = last, c.count > 1 { c.removeAll { $0 == l } }
        let h = mix(seed)
        return (c[Int(h % UInt64(c.count))], (h >> 32) & 1 == 1)
    }

    /// 세기 배율(진폭 · 길이)
    public static func tierScale(_ t: HitTier, big: Bool) -> (amp: Double, dur: Double) {
        switch t {
        case .light: return (0.8, 0.8)
        case .medium: return (1, 1)
        case .heavy: return big ? (1, 1) : (1.15, 1.3)
        }
    }

    /// 변형을 이어 가도 되는 동작(서서 맞는 반응 · 대기 · 걷기 · 휘청 · 가드 대기) — 그 밖(공격 · 쓰러짐 · 잡힘)으로 바뀌면 0.08초에 빠진다
    public static let carryAnims: Set<String> = ["idle", "walk", "hit", "hitB", "rCross", "rHook", "rKnee", "rElbow", "stagger", "staggerX", "nv_gdH", "nv_gdL"]
    /// 변형을 거는 반응(서서 맞는 것만 — 쓰러짐 · 띄움 · 메치기 · 돌려 세우기는 웹 그대로)
    public static let standing: Set<String> = ["hit", "hitB", "rCross", "rHook", "rKnee", "rElbow", "stagger", "staggerX"]
}

/// 맞는 쪽 한 명의 반응 상태(CharacterRig 가 들고 간다)
public struct HitReactState: Sendable, Equatable {
    public private(set) var current: HitReactVariant?
    /// 직전에 고른 변형(연달아 같은 것 막기)
    public private(set) var last: HitReactVariant?
    /// 이 인물이 변형을 받은 수(해시 씨앗)
    public private(set) var count = 0
    var t0 = 0.0, dur = 1.0, hold = 0.0, amp = 1.0, mirror = false
    var carry = ReactDelta.zero, carryT0 = -9.0
    var fadeT0: Double?
    public init() {}

    public var active: Bool { current != nil || !carry.isZero }

    /// 새 피격 — 고르고 시작(지금 남은 변형은 0.08초에 걸쳐 빠지며 섞인다)
    @discardableResult
    public mutating func trigger(actor: Int, zone: HitZone, dir: HitDir, tier: HitTier, mass: HitMass, time: Double, hold: Double) -> HitReactVariant {
        let (v, mir) = HitReact.choose(zone: zone, dir: dir, tier: tier, mass: mass, last: last, seed: HitReact.seed(actor: actor, tick: Int((time * 60).rounded()), count: count))
        carry = delta(time: time); carryT0 = time
        let sp = v.spec, k = HitReact.tierScale(tier, big: sp.big)
        current = v; last = v; count += 1
        t0 = time; dur = sp.dur * k.dur * mass.dur; amp = k.amp * mass.amp; mirror = mir; fadeT0 = nil
        self.hold = max(0, min(0.15, hold))
        return v
    }

    /// 지금 델타(인물 쪽 좌표 — x 앞)
    public func delta(time: Double) -> ReactDelta {
        var out = ReactDelta.zero
        let cu = (time - carryT0) / 0.08
        if !carry.isZero && cu < 1 { out = carry * (1 - cu) }
        guard let v = current else { return out }
        // 정지(hold) 동안은 첫 키로 들어가 머문다
        let attack = v.spec.keys.first.map { $0.u * dur } ?? 0
        var te = time - t0
        if te > attack { te = te < attack + hold ? attack : te - hold }
        let u = te / max(0.01, dur)
        var d = v.delta(at: u) * amp
        if mirror { d = d.mirrored }
        if let f = fadeT0 { d = d * max(0, 1 - (time - f) / 0.08) }
        return out + d
    }

    /// 보이는 자세에 얹는다(동작이 공격 · 쓰러짐으로 바뀌면 빠진다)
    public mutating func apply(_ P: inout Pose, time: Double, anim: String) {
        guard active else { return }
        if current != nil {
            if fadeT0 == nil && !HitReact.carryAnims.contains(anim) { fadeT0 = time }
            let end = t0 + hold + dur
            if time >= end || (fadeT0.map { time - $0 >= 0.08 } ?? false) { current = nil; fadeT0 = nil }
        }
        if !carry.isZero && time - carryT0 >= 0.08 { carry = .zero }
        let d = delta(time: time)
        if d.isZero { return }
        HitReactState.add(d, to: &P)
    }

    static func add(_ d: ReactDelta, to P: inout Pose) {
        P.r = (P.r ?? 0) + d.r
        if d.bx != 0 || d.by != 0 { let b = P.b ?? .zero; P.b = V2((b.x.isNaN ? 0 : b.x) + d.bx, (b.y.isNaN ? 0 : b.y) + d.by) }
        if d.hx != 0 || d.hy != 0 { let h = P.h ?? .zero; P.h = V2((h.x.isNaN ? 0 : h.x) + d.hx, (h.y.isNaN ? 0 : h.y) + d.hy) }
        P.t = (P.t ?? 0) + d.t
        P.ty = (P.ty ?? 0) + d.ty
        if d.spin != 0 { P.spin = (P.spin ?? 0) + d.spin }
        if d.air != 0 { P.air = max(0, (P.air ?? 0) + d.air) }
        if P.legFK != true {
            if d.fFx != 0 || d.fFy != 0 { let f = P.fF ?? .zero; P.fF = V2((f.x.isNaN ? 0 : f.x) + d.fFx, (f.y.isNaN ? 0 : f.y) + d.fFy) }
            if d.fBx != 0 || d.fBy != 0 { let f = P.fB ?? .zero; P.fB = V2((f.x.isNaN ? 0 : f.x) + d.fBx, (f.y.isNaN ? 0 : f.y) + d.fBy) }
        }
        if P.armFK == true {   // 섞는 중(FK 팔): 위팔 · 아래팔을 같이 돌린다
            if d.aF != 0 { P.uF = (P.uF ?? 0) + d.aF; P.lF = (P.lF ?? 0) + d.aF * 0.6 }
            if d.aB != 0 { P.uB = (P.uB ?? 0) + d.aB; P.lB = (P.lB ?? 0) + d.aB * 0.6 }
        } else {
            if d.aF != 0, let a = P.aF, !a.isNaN { P.aF = a + d.aF }
            if d.aB != 0, let a = P.aB, !a.isNaN { P.aB = a + d.aB }
        }
    }
}
