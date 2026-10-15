import Foundation

// 장면 연출 상태(규칙과 무관 — 웹은 GS.bonus.pfx 처럼 게임 상태 안에 두지만 그리기에만 쓰인다).
// 시뮬레이션은 '언제 · 어디서'만 이벤트(.fx carSmoke · carSteam · carFire)로 내고, 입자 속도 · 수명 · 흐름은 여기서 이어 간다.

/// 웹 43-fx-smoke.js pfxPush · pfxTick — 보너스 차 연기 · 김 · 불길 입자(drawPfx 는 NoirContext)
public struct BonusPuffs: Sendable, Equatable {
    public private(set) var items: [SceneInput.Brawl.Bonus.Puff] = []
    private var v: [SIMD2<Double>] = []
    public init() {}

    /// 웹 bonusUpdate 의 pfxPush 세 자리(연기 기둥 · 엔진 김 · 불길). kind = carSmoke · carSteam · carFire (위치는 시뮬레이션이 이미 정했다)
    public mutating func push<R: SceneRandom>(event kind: String, x: Double, y: Double, rng: inout R) {
        switch kind {
        case "carSmoke": let vx = (rng.next() - 0.3) * 8, vy = -20 - rng.next() * 10; add("smk", x, y, 3.0, vx, vy)
        case "carSteam": add("stm", x, y, 1.3, (rng.next() - 0.5) * 6, -26)
        case "carFire": let life = 0.5 + rng.next() * 0.5; add("fire", x, y, life, (rng.next() - 0.5) * 6, -10)
        default: break
        }
    }
    mutating func add(_ k: String, _ x: Double, _ y: Double, _ life: Double, _ vx: Double, _ vy: Double) {
        items.append(.init(k: k, x: x, y: y, t: 0, life: life)); v.append(SIMD2(vx, vy))
    }
    /// 웹 pfxTick(BN, dt) — 게임 시간 dt
    public mutating func advance(_ dt: Double) {
        guard dt > 0 else { return }
        for i in items.indices {
            items[i].t += dt; items[i].x += v[i].x * dt; items[i].y += v[i].y * dt
            if items[i].k != "fire" { v[i].x += sin(items[i].t * 2 + items[i].x) * 4 * dt }
        }
        let keep = items.indices.filter { items[$0].t < items[$0].life }
        items = keep.map { items[$0] }; v = keep.map { v[$0] }
    }
    public mutating func clear() { items = []; v = [] }
}

/// 웹 08-art-dojo.js xcTick · xcKick · xcSpark · xcReset — 무도장 '건널목' 배경 연출(노면 전차 · 경보 · 팬터그래프 불꽃 · 단풍).
/// 규칙 효과가 없어 시뮬레이션은 모른다(BBSim World+Dojo 주석) — 표현이 이어 가고, 그리기 입력(SceneInput.Cross)을 내준다.
/// 소리(경보 땡땡 · 레일 덜컹 · 지직)와 HITFX 'xcspark' 선 효과는 아직 내지 않는다(불꽃 자리는 sparks 로 나간다).
public struct CrossAmbience: Sendable {
    struct Leaf: Sendable { var x, gy, h, vx, vh, ph, rot, vr, c, s: Double }
    struct Fall: Sendable { var L: Leaf; var y, vy, sw: Double }
    struct Tram: Sendable { var dir, x, v, warn: Double; var kind: String; var dist: Double; var pp: [Double]? }
    var tr: Tram?
    var nextT = 0.0, bell = false, bellT = 0.0, bk = 0.0, bt = false, spk = 0.0, spkX = 0.0, fallT = 0.0
    var leaves: [Leaf] = [], fall: [Fall] = []
    var prev: [Int: Double] = [:]
    /// 이번 틱에 튄 팬터그래프 불꽃 자리(웹 sparks.push({x, y:XC_CW}) — 호출자가 FxLayer 로 옮긴다)
    public var newSparks: [SIMD2<Double>] = []

    /// 웹 xcReset()
    public init<R: SceneRandom>(rng: inout R) {
        let X = CrossGeom.reset(&rng)
        nextT = X.nextT
        leaves = X.leaves.map { Leaf(x: $0.x, gy: $0.gy, h: 0, vx: 0, vh: 0, ph: $0.ph, rot: $0.rot, vr: 0, c: $0.c, s: $0.s) }
    }
    static func leaf<R: SceneRandom>(_ x: Double, _ gy: Double, _ rng: inout R) -> Leaf {
        let L = CrossGeom.leaf(x, gy, &rng); return Leaf(x: x, gy: gy, h: 0, vx: 0, vh: 0, ph: L.ph, rot: L.rot, vr: 0, c: L.c, s: L.s)
    }

    /// 그리기 입력(웹 DJ.xc)
    public var state: SceneInput.Cross {
        SceneInput.Cross(tr: tr.map { .init(dir: $0.dir, x: $0.x, warn: $0.warn, kind: $0.kind, dist: $0.dist) }, bell: bell, spk: spk, spkX: spkX, nextT: nextT,
                         leaves: leaves.map { .init(x: $0.x, gy: $0.gy, h: $0.h, rot: $0.rot, c: $0.c, s: $0.s, ph: $0.ph) },
                         fall: fall.map { .init(x: $0.L.x, gy: $0.L.gy, y: $0.y, rot: $0.L.rot, c: $0.L.c, s: $0.L.s, ph: $0.L.ph) })
    }

    /// 웹 xcKick(x, gy, pw, rad): 발밑 · 충격 자리의 잎을 띄운다
    public mutating func kick<R: SceneRandom>(_ x: Double, _ gy: Double, _ pw: Double, _ rad: Double, rng: inout R) {
        for i in leaves.indices {
            if leaves[i].h > 0 { continue }
            let dx = leaves[i].x - x
            if abs(dx) > rad || abs(leaves[i].gy - gy) > 26 { continue }
            let k = 1 - abs(dx) / rad
            leaves[i].vh = (50 + rng.next() * 90) * pw * (0.5 + k)
            let sg: Double = dx > 0 ? 1 : dx < 0 ? -1 : (rng.next() < 0.5 ? -1 : 1)
            leaves[i].vx = sg * (30 + rng.next() * 80) * pw
            leaves[i].vr = (rng.next() - 0.5) * 14; leaves[i].h = 0.5
        }
    }
    /// 웹 xcSpark(x)
    mutating func spark(_ x: Double) { spk = 0.14; spkX = x; newSparks.append(SIMD2(x, XC.CW)) }

    /// 웹 xcTick(dt) — actors: 주인공 · 적(웹 [hero, ...적 · 무도장 허수아비]) 의 (id, x, y, 숨음 · 저글)
    public mutating func tick<R: SceneRandom>(_ dt: Double, actors: [(id: Int, x: Double, y: Double, skip: Bool)], rng: inout R) {
        nextT -= dt
        if tr == nil && nextT <= 0 {                                           // 14~24초마다 전차 · 오기 2초 전부터 경보
            let dir: Double = rng.next() < 0.5 ? 1 : -1
            let v = 260 + rng.next() * 60, kind = rng.next() < 0.7 ? "A" : "B"
            tr = Tram(dir: dir, x: dir > 0 ? -520 : SB.W + 520, v: v, warn: 2.0, kind: kind, dist: 0, pp: nil); bell = true
        }
        if var T = tr {
            if T.warn > 0 { T.warn -= dt } else { let mv = T.v * dt; T.x += T.dir * mv; T.dist += mv }
            if T.warn <= 0 { _ = rng.next() }                                    // 웹: 바퀴 소리 난수(소리는 아직)
            if T.warn <= 0 {
                let view = SceneInput.Cross.Tram(dir: T.dir, x: T.x, warn: T.warn, kind: T.kind, dist: T.dist)
                let cars = CrossGeom.cars(view), pp = cars.map(\.cx)
                if let p0 = T.pp {
                    for (i, x) in pp.enumerated() where i < p0.count {
                        let x0 = p0[i]
                        for sx in XC.CS where (sx - x0) * (sx - x) <= 0 && x0 != x { spark(sx) }   // 팬터그래프가 가선 기둥을 지날 때 불꽃
                    }
                }
                T.pp = pp
                if cars.contains(where: { $0.cx > -120 && $0.cx < SB.W + 120 }) && rng.next() < dt * 0.5 { spark(cars[0].cx) }   // 가끔 작은 불꽃
                if abs(T.x - SB.W / 2) < SB.W / 2 + 260 {                        // 전차 바람: 바닥 단풍이 가는 쪽으로 쓸려 날린다
                    for i in leaves.indices {
                        if leaves[i].h <= 0 {
                            if rng.next() < dt * 1.7 * (leaves[i].gy < 240 ? 1 : 0.45) {
                                leaves[i].vh = 40 + rng.next() * 80; leaves[i].vx = T.dir * (80 + rng.next() * 130); leaves[i].vr = (rng.next() - 0.5) * 16; leaves[i].h = 0.5
                            }
                        } else { leaves[i].vx += T.dir * 120 * dt }
                    }
                    for i in fall.indices { fall[i].L.x += T.dir * 80 * dt }
                }
            }
            tr = T
            if (T.dir > 0 && T.x > SB.W + 420) || (T.dir < 0 && T.x < -420) { tr = nil; nextT = 14 + rng.next() * 10; bellT = 0.8 }
        }
        if bellT > 0 { bellT -= dt; if bellT <= 0 { bell = false } }
        if spk > 0 { spk = max(0, spk - dt) }
        if bell { bk += dt; if bk >= 0.42 { bk = 0; bt.toggle() } }
        fallT -= dt
        if fallT <= 0 && fall.count < 22 {                                      // 떨어지는 단풍
            fallT = 0.35 + rng.next() * 0.6
            let x = rng.next() * SB.W, gy = rng.next() < 0.6 ? 223 + rng.next() * 12 : 236 + rng.next() * 26
            let L = Self.leaf(x, gy, &rng)
            let y = 40 + rng.next() * 80, vy = 16 + rng.next() * 14, sw = 8 + rng.next() * 10
            fall.append(Fall(L: L, y: y, vy: vy, sw: sw))
        }
        for i in fall.indices {
            fall[i].L.ph += dt * 3; fall[i].y += fall[i].vy * dt; fall[i].L.x += sin(fall[i].L.ph) * fall[i].sw * dt + 10 * dt; fall[i].L.rot = fall[i].L.ph * 1.3
        }
        var keep: [Fall] = []
        for F in fall {
            if F.y < F.L.gy { keep.append(F); continue }
            var L = Self.leaf(F.L.x, F.L.gy, &rng); L.c = F.L.c; L.s = F.L.s; leaves.append(L)
        }
        fall = keep
        if leaves.count > 96 { leaves.removeFirst(leaves.count - 96) }
        for i in leaves.indices where leaves[i].h > 0 {                          // 날린 잎: 펄럭이며 다시 내려앉는다
            leaves[i].vh -= 230 * dt; leaves[i].h += leaves[i].vh * dt; leaves[i].ph += dt * 7
            leaves[i].x += leaves[i].vx * dt + sin(leaves[i].ph) * 6 * dt; leaves[i].vx *= pow(0.25, dt); leaves[i].rot += leaves[i].vr * dt
            if leaves[i].h <= 0 { leaves[i].h = 0; leaves[i].vh = 0; leaves[i].vx = 0; leaves[i].vr = 0 }
            leaves[i].x = min(SB.W - 4, max(4, leaves[i].x))
        }
        for a in actors where !a.skip {                                         // 움직이면 발밑 잎이 날린다
            let px = prev[a.id]; prev[a.id] = a.x
            guard let px else { continue }
            let sp = abs(a.x - px) / max(dt, 1e-3)
            if sp > 40 { kick(a.x, a.y, min(1.6, sp / 130), 14 + min(14, sp / 25), rng: &rng) }
        }
    }
}
