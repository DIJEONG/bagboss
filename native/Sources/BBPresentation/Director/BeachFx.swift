import Foundation
import BBCore
import BBContent
import BBSim

// 해변 도장 움직이는 층(docs/12) — 표현 몫(규칙 상태 없음 · 씨앗 고정 · 게임 시간으로만 흐른다 → 멈춤 · 배속을 그대로 따른다).
//  1) 바다(seaMesh): 수평선 → 물가 줄마다 시차(0.04 → 0.9)와 물결 크기가 다르다(원근) · 해(달) 아래 반짝임 길(물결 마루에서 낱 픽셀이 깜빡인다) ·
//     물가로 다가와 부서지는 파도(흰 마루 + 짙은 앞면) · 밤 원더휠 불빛 · 낮 갈매기
//  2) 밀려오는 물(groundMesh): 정해진 주기(7.2초)로 밀려와 모래를 덮었다 빠진다 — 세 번에 한 번쯤 큰 파도가 싸움 줄(발)까지 온다.
//     물 끝은 둥근 혀 모양으로 고르지 않다 · 앞 테에 거품 · 빠질 때 거품 레이스가 남았다 꺼진다.
//     물이 지나간 모래는 젖어(짙고 하늘이 비친다 — 젖은 바닥 반사) 2초에 1px 씩 마른다.
//  3) 자국: 마른 모래 발자국(밀린 모래 테) · 젖은 모래 발자국(짙고 물이 고여 반짝) · 미끄러진 줄 · 쓰러진 몸 자국 · 충격 구덩이 — 물이 지나가면 지워진다
//  4) 튀는 것: 마른 모래(덩이 + 가루) · 젖은 모래 덩이 · 물방울 · 물보라 · 물 위 동심원 — 발이 물에 있으면 발 디딤마다 물이 튀고, 밀려온 물이 발에 닿는 순간 물보라
// 모든 그림은 정수 픽셀(무대 픽셀 쿼드). 난수는 씨앗 고정 SplitMix64 · 해시만.

struct BeachFx {
    struct Mark { var x: Int, y: Int, w: Int, age: Double, wet: Bool, kind: Kind, wash = 0.0
        enum Kind { case step, drag, body, crater } }
    enum PartKind { case sand, dust, clod, drop, spray }
    struct Part { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, kind: PartKind, gy: Double, front: Bool }
    struct Ring { var x: Double, y: Double, age: Double, big: Bool }
    struct Track { var gph: Double?; var air: Double, anim: String, x: Double, y: Double }

    var on = false
    var time: BeachTime = .day
    var t = 0.0
    var marks: [Mark] = []
    var parts: [Part] = []
    var rings: [Ring] = []
    var tracks: [ActorID: Track] = [:]
    /// 열마다: 지금 물 끝 y · 이번 주기 가장 멀리 온 y · 젖은 모래 끝 y(마르며 물가로 물러난다)
    var edge = BeachGeo.shoreLine.map(Double.init)
    var reach = BeachGeo.shoreLine.map(Double.init)
    var wetTop = (0..<BeachGeo.W).map { BeachFx.damp($0) }
    var cycle = -1
    var rng = SplitMix64(seed: 0xBEAC4)
    /// 파도 소리 세기(0..1 — 밀려올 때 차오르고 빠질 때 잦아든다)
    var surf = 0.0
    /// 이번에 낼 소리(StageDirector.takeSnowCues 가 꺼낸다) · 발소리 · 첨벙 간격 · 다음 갈매기
    var sounds: [SoundCue] = []
    var stepSndT = -9.0, splashSndT = -9.0, nextGull = 5.0
    mutating func sound(_ c: SoundCue) { if sounds.count < 4 { sounds.append(c) } }

    /// 늘 젖어 있는 물가 띠 끝(물가선 + 3~7px — 고르지 않게)
    static func damp(_ x: Int) -> Double { Double(BeachGeo.shoreLine[x]) + 3 + 4 * SnowPaint.n1(Double(x) / 13, 234) }
    static let period = 7.2, dryRate = 0.55, uprush = 0.3, backwash = 0.78
    /// 바닥 층 깊이(BeachFloor.D 와 같다)
    static let D = Double(BeachFloor.D)

    mutating func R() -> Double { rng.next() }

    mutating func reset(_ tm: BeachTime) {
        self = BeachFx(); on = true; time = tm
    }

    // MARK: 파도(결정적 — 게임 시간만)

    /// k 번째 주기의 큰 파도 여부 · 최대 거리(px)
    static func swell(_ k: Int) -> Double {
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: k &* 7919 &+ 31))
        let big = g.next() < 0.34 || k % 4 == 2
        return big ? 25 + g.next() * 6 : 9 + g.next() * 7
    }
    /// 오르내림 0..1(오름: 빠르게 차올라 늦춰지고 · 내림: 천천히 빠진다 · 그 뒤 잠잠)
    static func run(_ ph: Double) -> Double {
        if ph < 0 { return 0 }
        if ph < uprush { let u = ph / uprush; return 1 - pow(1 - u, 2.2) }
        if ph < backwash { let u = (ph - uprush) / (backwash - uprush); return 1 - u * u * (3 - 2 * u) }
        return 0
    }
    /// 열 x 의 물 끝(장면 y) — 혀 모양(느린 잡음) · 비스듬히 닿는 시간 차 · 앞 테 잔물결
    static func edgeAt(_ x: Int, t: Double) -> Double {
        let X = Double(x), c = t / period, k = Int(floor(c))
        var ph = c - Double(k)
        let lag = 0.06 * SnowPaint.n1(X / 90 + Double(k) * 1.3, 203)
        ph -= lag
        var kk = k
        if ph < 0 { ph += 1; kk -= 1 }
        let r = run(ph)
        let s0 = Double(BeachGeo.shoreLine[max(0, min(BeachGeo.W - 1, x))])
        guard r > 0 else { return s0 }
        let lobe = 0.72 + 0.56 * SnowPaint.n1(X / 34 + Double(kk) * 1.7, 201)
        let fringe = (SnowPaint.n1(X / 4.5 + Double(kk) * 3.3 + t * 0.8, 202) - 0.5) * 1.6
        return min(Double(BeachGeo.shore) + 32, s0 + swell(kk) * lobe * r + fringe * min(1, r * 3))   // 큰 파도도 앞 발(230)까지
    }
    /// 이번 주기 위상(0..1)
    var phase: Double { let c = t / Self.period; return c - floor(c) }

    // MARK: 흐름

    mutating func advance(_ dt: Double) {
        guard on, dt > 0 else { return }
        t += dt
        let k = Int(floor(t / Self.period))
        if k != cycle { cycle = k; for x in 0..<BeachGeo.W { reach[x] = Double(BeachGeo.shoreLine[x]) } }
        for x in 0..<BeachGeo.W {
            let e = Self.edgeAt(x, t: t)
            edge[x] = e
            reach[x] = max(reach[x], e)
            wetTop[x] = max(Self.damp(x), max(wetTop[x] - Self.dryRate * dt, e + 1))
        }
        // 갈매기: 오후 · 노을에 8~18초마다 멀리서(밤엔 없다)
        if time != .night && t > nextGull { sound(.gull); nextGull = t + 8 + R() * 10 }
        let ph = phase
        surf += ((ph < Self.uprush ? 0.35 + 0.65 * Self.run(ph) * (Self.swell(k) > 20 ? 1 : 0.7) : ph < Self.backwash ? 0.3 + 0.3 * (1 - (ph - Self.uprush) / (Self.backwash - Self.uprush)) : 0.22) - surf) * min(1, dt * 3)
        // 자국: 나이 · 물에 잠기면 씻긴다(0.7초에 걸쳐)
        for i in marks.indices {
            marks[i].age += dt
            let m = marks[i]
            if m.x >= 0 && m.x < BeachGeo.W && Double(m.y) <= edge[max(0, min(BeachGeo.W - 1, m.x + m.w / 2))] { marks[i].wash += dt; marks[i].wet = true }
        }
        marks.removeAll { $0.age > 40 || $0.wash > 0.7 }
        if marks.count > 180 { marks.removeFirst(marks.count - 180) }
        for i in parts.indices {
            var p = parts[i]
            p.age += dt
            switch p.kind {
            case .dust: p.vx *= exp(-2.5 * dt); p.vy += (10 - p.vy) * min(1, 2.4 * dt)
            case .spray: p.vy += 300 * dt; p.vx *= exp(-1.2 * dt)
            default: p.vy += 520 * dt; p.vx *= exp(-1.4 * dt)
            }
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.kind != .dust && p.vy > 0 && p.y >= p.gy { p.age = p.life + 1 }   // 바닥에 닿으면 섞인다
            if p.kind == .dust && p.y > p.gy { p.y = p.gy; p.vy = 0 }
            parts[i] = p
        }
        parts.removeAll { $0.age > $0.life }
        if parts.count > 420 { parts.removeFirst(parts.count - 420) }
        for i in rings.indices { rings[i].age += dt }
        rings.removeAll { $0.age > ($0.big ? 1.1 : 0.8) }
    }

    /// 장면 x 의 물 끝 · 그 자리가 물속인가
    func edgeY(_ x: Double) -> Double { edge[max(0, min(BeachGeo.W - 1, Int(x.rounded())))] }
    func inWater(_ x: Double, _ y: Double) -> Bool { y <= edgeY(x) - 0.5 }
    func isWet(_ x: Double, _ y: Double) -> Bool { y <= wetTop[max(0, min(BeachGeo.W - 1, Int(x.rounded())))] }

    // MARK: 튀기기

    /// 마른 모래 한 줌(발 디딤 · 이륙): 덩이 몇 + 가루
    mutating func kick(_ x: Double, _ gy: Double, dir: Double, n: Int, sp: Double = 1) {
        let wet = isWet(x, gy)
        for k in 0..<max(1, n) {
            let chunk = k % 2 == 0
            parts.append(Part(x: x + (R() - 0.5) * 4, y: gy - 1, vx: -dir * (12 + R() * 34) * sp + (R() - 0.5) * 14, vy: -(18 + R() * 40) * sp,
                              age: 0, life: 0.7, kind: wet ? .clod : chunk ? .sand : .dust, gy: gy + (R() - 0.5) * 2, front: R() < 0.5))
        }
    }
    /// 물 튀김(발이 물에 있을 때 · 물이 발에 닿을 때): 물방울 + 물보라 + 동심원
    mutating func splash(_ x: Double, _ gy: Double, power p: Double, dir: Double = 0) {
        let n = Int(4 + 10 * p)
        for _ in 0..<n {
            let a = .pi * (0.2 + R() * 0.6), s = (50 + R() * 110) * (0.6 + 0.5 * p)
            parts.append(Part(x: x + (R() - 0.5) * 6, y: gy - 1, vx: cos(a) * s * (R() < 0.5 ? -1 : 1) + dir * 30, vy: -sin(a) * s, age: 0, life: 1,
                              kind: R() < 0.6 ? .drop : .spray, gy: gy + (R() - 0.5) * 3, front: R() < 0.55))
        }
        rings.append(Ring(x: x, y: gy, age: 0, big: p > 0.8))
        if t - splashSndT > 0.12 || p > 0.8 { splashSndT = t; sound(.splash(big: p > 0.8)) }
    }
    /// 쓰러짐 · 바닥 충격(마른 모래): 덩이 + 낮게 깔리는 가루 구름
    mutating func burst(_ x: Double, _ gy: Double, power p: Double) {
        if inWater(x, gy) { splash(x, gy, power: 1 + p * 0.5); splash(x + (R() - 0.5) * 10, gy, power: 0.6); return }
        let wet = isWet(x, gy)
        for _ in 0..<Int(6 + 7 * p) {
            let a = .pi * (0.12 + R() * 0.76), s = (60 + R() * 110) * (0.7 + 0.4 * p)
            parts.append(Part(x: x + (R() - 0.5) * 12, y: gy - 2, vx: cos(a) * s * (R() < 0.5 ? -1 : 1), vy: -sin(a) * s, age: 0, life: 1,
                              kind: wet ? .clod : .sand, gy: gy + (R() - 0.5) * 4, front: R() < 0.55))
        }
        guard !wet else { return }   // 젖은 모래는 가루가 일지 않는다
        for _ in 0..<Int(8 + 8 * p) {
            parts.append(Part(x: x + (R() - 0.5) * 16, y: gy - 1 - R() * 5, vx: (R() - 0.5) * 110 * (0.6 + 0.4 * p), vy: -(8 + R() * 26), age: 0,
                              life: 0.8 + R() * 0.7, kind: .dust, gy: gy, front: R() < 0.5))
        }
        sound(.sandBurst)
    }
    /// 무거운 타격 · 착지: 바닥을 따라 퍼지는 고리
    mutating func ring(_ x: Double, _ gy: Double, power p: Double) {
        if inWater(x, gy) { splash(x, gy, power: 0.5 + 0.4 * p); return }
        let wet = isWet(x, gy)
        for i in 0..<Int(6 + 8 * p) {
            let side: Double = i % 2 == 0 ? 1 : -1
            parts.append(Part(x: x + side * R() * 4, y: gy - 1, vx: side * (60 + R() * 100) * (0.6 + 0.4 * p), vy: -(6 + R() * 24), age: 0,
                              life: 0.5 + R() * 0.5, kind: wet ? .clod : i % 4 == 0 ? .sand : .dust, gy: gy, front: R() < 0.5))
        }
    }
    /// 미끄러져 서기: 앞으로 뿌리는 호(물속이면 물보라)
    mutating func spray(_ x: Double, _ gy: Double, dir: Double, k: Double) {
        let water = inWater(x, gy), wet = isWet(x, gy)
        for i in 0..<Int(8 * k) + 3 {
            let chunk = i % 3 == 0
            parts.append(Part(x: x + dir * 3, y: gy - 1, vx: dir * (50 + R() * 110), vy: -(40 + R() * 100), age: 0, life: 1,
                              kind: water ? (chunk ? .drop : .spray) : wet ? .clod : chunk ? .sand : .dust, gy: gy + (R() - 0.5) * 3, front: R() < 0.6))
        }
    }

    // MARK: 규칙 이벤트 · 스냅숏 흐름

    mutating func apply(_ events: [SimEvent], _ s: SimSnapshot) {
        guard on else { return }
        for e in events {
            switch e {
            case let .groundImpact(x, y, p):
                ring(x, y, power: min(2, max(0.4, p))); burst(x, y, power: min(1.5, p * 0.6))
                let cw = Int(12 + 8 * min(2, p))
                marks.append(Mark(x: Int(x) - cw / 2, y: Int(y), w: cw, age: 0, wet: isWet(x, y), kind: .crater))
            case let .fx("dust", x, y, _):   // 쓰러짐 · 굴러 닿음: 몸 자국 + 모래(물)
                burst(x, y, power: 0.8)
                marks.append(Mark(x: Int(x) - 8, y: Int(y), w: 16, age: 0, wet: isWet(x, y), kind: .body))
            case let .fx("sxboom", x, y, _): burst(x, y + 8, power: 1.4)
            case .hit(let h):
                guard h.knock || h.reactOpt == "launch" || h.weight == .heavy, let T = s.actors.first(where: { $0.id == h.target }) else { continue }
                ring(T.x, T.y, power: h.weight == .heavy ? 1 : 0.6)
            default: break
            }
        }
    }

    /// 매 프레임: 발 디딤 · 미끄러짐 · 착지 · 물이 발에 닿음
    mutating func track(_ s: SimSnapshot) {
        guard on else { return }
        var seen: [ActorID: Track] = [:]
        for a in s.actors where !a.hidden && !a.isPassenger {
            let f: Double = a.flip ? -1 : 1
            let air = (a.pose.airOv ?? 0) + a.airOv
            var T = tracks[a.id] ?? Track(gph: a.pose.gph, air: air, anim: a.pose.anim, x: a.x, y: a.y)
            let anim = a.pose.anim
            let running = anim == "run" || anim == "nv_go" || (anim == "walk" && (a.pose.runU ?? -1) > s.gameTime)
            let water = inWater(a.x, a.y), wet = isWet(a.x, a.y)
            // 1) 발 디딤(보폭 위상 반 바퀴마다)
            if let g = a.pose.gph, let g0 = T.gph, air < 1, floor(g * 2) != floor(g0 * 2), abs(g - g0) < 0.5 {
                let lead = (g - floor(g)) >= 0.5 ? -1.0 : 1.0
                let fx = a.x + f * (running ? 6 : 3) * lead * 0.6
                if water { splash(fx, a.y, power: running ? 0.45 : 0.2, dir: f) }   // 첨벙 소리는 splash 가 낸다(0.12초 간격)
                else {
                    if a.isHero && t - stepSndT > 0.16 { stepSndT = t; sound(.sandStep(run: running, wet: wet)) }
                    marks.append(Mark(x: Int(fx.rounded()) - 1, y: Int(a.y.rounded()), w: running ? 3 : 2, age: 0, wet: wet, kind: .step))
                    if running { kick(fx, a.y, dir: f, n: 4) } else if R() < 0.3 { kick(fx, a.y, dir: f, n: 1, sp: 0.5) }
                }
            }
            // 2) 미끄러져 서기: 들어서는 순간 호 · 미끄러지는 동안 앞발에서 계속 + 끌린 줄
            if anim == "nv_skid" {
                let dir: Double = a.x >= T.x ? 1 : -1
                if T.anim != "nv_skid" { spray(a.x + dir * 6, a.y, dir: dir, k: 1.4); sound(water ? .splash(big: false) : .sandSkid) }
                else if abs(a.x - T.x) > 0.3 {
                    spray(a.x + dir * 6, a.y, dir: dir, k: 0.15)
                    if !water { marks.append(Mark(x: Int(min(a.x, T.x)) + Int(dir * 4), y: Int(a.y.rounded()), w: max(2, Int(abs(a.x - T.x).rounded()) + 1), age: 0, wet: wet, kind: .drag)) }
                }
            }
            if anim == "nv_skidEnd" && T.anim == "nv_skid" { kick(a.x + f * 7, a.y, dir: -f, n: 6, sp: 0.8) }
            // 3) 착지 · 이륙
            if T.air > 6 && air < 0.5 {
                ring(a.x, a.y, power: min(1, T.air / 30))
                if !water { marks.append(Mark(x: Int(a.x) - 4, y: Int(a.y), w: 8, age: 0, wet: wet, kind: .step)) }
            }
            if T.air < 0.5 && air > 3 && anim != "nv_rise" { if water { splash(a.x, a.y, power: 0.4) } else { kick(a.x, a.y, dir: -f, n: 4, sp: 0.7) } }
            if anim == "nv_rise" && T.anim != "nv_rise" { ring(a.x, a.y, power: 0.7) }
            // 4) 밀려온 물이 발(누운 몸)에 막 닿음: 물보라
            if air < 2 && water && !(T.y <= edgeY(T.x) - 0.5) && phase < Self.uprush { splash(a.x, a.y, power: 0.55, dir: -1) }
            T.gph = a.pose.gph; T.air = air; T.anim = anim; T.x = a.x; T.y = a.y
            seen[a.id] = T
        }
        tracks = seen
    }

    // MARK: 그리기 — 바다

    /// 시간대 값: 바탕(u) · 물결 진폭 · 반짝임 길(폭 · 광택 · 확률) · 반짝임 재질 · 단
    private struct SeaLook { var a: Double, b: Double, c: Double, d: Double, amp: Double, w0: Double, w1: Double, sheen: Double, prob: Double, gMat: Int, gV: Double, crest: Double }
    private var look: SeaLook {
        switch time {
        case .day: return SeaLook(a: 0.36, b: 0.2, c: 0.18, d: 0.07, amp: 0.08, w0: 8, w1: 70, sheen: 0.12, prob: 0.5, gMat: NativePalette.SUN, gV: 0.96, crest: 0.86)
        case .dusk: return SeaLook(a: 0.2, b: 0.32, c: 0.08, d: 0.07, amp: 0.07, w0: 6, w1: 48, sheen: 0.34, prob: 0.6, gMat: NativePalette.SUN, gV: 0.86, crest: 0.62)
        case .night: return SeaLook(a: 0.08, b: 0.14, c: 0.05, d: 0.06, amp: 0.045, w0: 3, w1: 34, sheen: 0.14, prob: 0.4, gMat: NativePalette.FOAM, gV: 0.86, crest: 0.4)
        }
    }

    /// 바다 · 부서지는 파도 · 반짝임 길 · 밤 원더휠 불빛 · 낮 갈매기(보이는 창만 — 매 프레임)
    func seaMesh(camX: Double, visibleWidth vw: Double) -> [Float] {
        let hz = BeachGeo.horizon, sh = BeachGeo.shore
        let x0 = max(0, Int(camX.rounded(.down)) - 2), x1 = min(BeachGeo.W, Int((camX + vw).rounded(.up)) + 2)
        var m = SnowQuads(quads: (x1 - x0) * (sh - hz) / 3 + 256)
        let Lk = look, mat = time.seaMat, FM = NativePalette.FOAM
        let sun = BeachGeo.sun(time), scx = camX + sun.x
        let fr = Int(floor(t * 10))
        // 다가오는 파도 마루(다음 주기 — 물가 뒤 14px 에서 물가로) · 먼 너울 줄
        let ph = phase
        let crestY: Double? = ph > 0.5 ? Double(sh) - 15 + 15 * pow((ph - 0.5) / 0.5, 1.6) : nil
        let swellY = Double(hz) + 30 + 18 * ((t / Self.period * 0.9).truncatingRemainder(dividingBy: 1))
        let shMax = BeachGeo.shoreLine[x0..<x1].max() ?? sh
        for y in hz..<shMax {
            let u = min(1, Double(y - hz) / Double(sh - hz)), p = 0.04 + 0.86 * pow(u, 1.5)
            let sx = 3 + 52 * pow(u, 1.35), band = Double(Int(6 / (u + 0.07)))
            let z = 0.9945 - 0.0003 * u, d = 0.95 - 0.55 * u
            let base = Lk.a + Lk.b * exp(-u / 0.07) - 0.04 * min(1, u * 3) + Lk.c * max(0, (u - 0.62) / 0.38) * max(0, (u - 0.62) / 0.38) + Lk.d * u
            let pw = Lk.w0 + Lk.w1 * u + (time == .dusk ? sun.r : 0)
            var runV = Float.nan, runX = x0, runMat = mat, runEm: Float = 0
            func flush(_ xe: Int) { if xe > runX && !runV.isNaN { m.run(runX, y, xe - runX, mat: runMat, tone: 0, z: z, d: d, emit: Double(runEm), ny: 0.9) } }
            for x in x0..<x1 {
                let shx = BeachGeo.shoreLine[x]
                if y >= shx { flush(x); runV = .nan; continue }   // 이 열은 모래(물가선 아래)
                let lx = Double(x) - (1 - p) * camX
                let w = SnowPaint.n1(lx / sx + t * (0.12 + 0.5 * u) + band * 7.3, 210) * 0.62 + SnowPaint.n1(lx / (sx * 0.4) - t * (0.3 + 0.4 * u) + band * 3.1, 211) * 0.38
                var v = base + Lk.amp * (w - 0.5) * 2
                let dx = (Double(x) - scx) / pw, inPath = exp(-dx * dx)
                v += Lk.sheen * inPath * (0.55 + 0.45 * w)
                var mt = mat, em: Float
                // 반짝임: 마루(w 높음) · 길 안 · 열마다 박자가 다른 깜빡임(10fps)
                let hp = SnowPaint.h(Int(lx.rounded()), y, 212)
                let flick = SnowPaint.h(Int(lx.rounded()), y &+ Int(floor(t * 10 + hp * 10)) &* 131, 213)
                if w > 0.6 && flick < Lk.prob * inPath * (0.35 + 0.65 * u) * (w - 0.6) * 4 { mt = Lk.gMat; v = Lk.gV + (flick < 0.05 ? 0.04 : 0) }
                else if time == .day && w > 0.74 && flick < 0.02 * u { mt = Lk.gMat; v = 0.9 }   // 해가 높아 길 밖에도 드문 반짝임
                // 너울 줄(먼 바다 · 조금 밝은 줄이 천천히 다가온다)
                if abs(Double(y) - swellY) < 0.5 && u < 0.7 && mt == mat { v += 0.05 * (0.5 + w) }
                // 부서지는 파도: 마루 흰 거품(끊기며) · 바로 앞(아래) 짙은 앞면 두 줄 · 뒤에 남는 거품 줄무늬
                if let cy = crestY, mt == mat {
                    let fy = cy + 1.2 * sin(lx / 13 + Double(cycle)), dy = Double(y) - fy
                    let gap = SnowPaint.n1(lx / 7 + Double(cycle) * 2, 214)
                    if abs(dy) < 0.6 && gap > 0.3 { mt = FM; v = Lk.crest + 0.1 * (gap - 0.3) }
                    else if dy > 0.6 && dy < 2.6 { v -= 0.07 }
                    else if dy < -0.6 && dy > -4 && SnowPaint.h(Int(lx), y, 215) < 0.22 * (1 + dy / 4) { mt = FM; v = Lk.crest - 0.2 }
                }
                // 물가 바로 뒤 얕은 물: 밑 모래 빛이 비친다(맨 아래 두 줄 · 성긴 체크)
                if y >= shx - 2 && mt == mat && (x + y) & 1 == 0 { v += 0.05 }
                em = Float((v * 24).rounded() / 24)
                if em != runV || mt != runMat { flush(x); runV = em; runX = x; runMat = mt; runEm = em }
            }
            flush(x1)
        }
        jetty(&m, camX: camX)
        dolphins(&m, camX: camX)
        // 밤: 원더휠 불빛(살 끝 16개 — 색이 돌아간다) · 파라슈트 점프 꼭대기 붉은 등 깜빡임 — 먼 해안 층(시차 0.06) 자리
        if time == .night {
            let ox = 0.94 * camX, wc = (54.0, Double(hz) - 22), cols = [NativePalette.SODIUM, 12, NativePalette.LINE7, NativePalette.TEAL]
            for i in 0..<16 {
                let a = Double(i) * .pi / 8 + t * 0.06
                let x = Int((wc.0 + cos(a) * 15 + ox).rounded()), y = Int((wc.1 + sin(a) * 15).rounded())
                let c = cols[(i + Int(t * 2)) % 4]
                m.run(x, y, 1, mat: c, tone: 0, z: 0.9947, d: 0.95, emit: 0.82)
                if i % 4 == Int(t * 4) % 4 { m.run(Int((wc.0 + cos(a) * 8 + ox).rounded()), Int((wc.1 + sin(a) * 8).rounded()), 1, mat: c, tone: 0, z: 0.9947, d: 0.95, emit: 0.7) }
            }
            if Int(t * 1.2) % 2 == 0 { m.run(Int((18 + ox).rounded()), hz - 52, 1, mat: 12, tone: 0, z: 0.9947, d: 0.95, emit: 0.85) }
            // 등대 등실: 빛줄기가 카메라 쪽을 향할 때 번쩍(나머지는 은은하게) — 회전 빛줄기는 BeachScene 볼류메트릭
            let lh = Self.lighthouseBeam(t), lx = Int((Double(BeachGeo.lighthouse.x) + ox).rounded()), ly = BeachGeo.lighthouse.y
            m.run(lx, ly, 2, mat: NativePalette.SODIUM, tone: 0, z: 0.9947, d: 0.95, emit: 0.6 + 0.38 * lh.flash)
            if lh.flash > 0.5 { m.run(lx - 1, ly, 4, mat: NativePalette.SUN, tone: 0, z: 0.9946, d: 0.95, emit: 0.9); m.run(lx, ly - 1, 2, mat: NativePalette.SUN, tone: 0, z: 0.9946, d: 0.95, emit: 0.8) }
        } else {
            // 낮 · 노을: 갈매기 둘(하늘 층에 붙어 천천히 미끄러진다 · 날갯짓 두 칸)
            for gI in 0..<2 {
                let sp = 5.0 + Double(gI) * 3, gx = (Double(gI) * 90 + t * sp).truncatingRemainder(dividingBy: 260) - 30
                let gy = 40.0 + Double(gI) * 26 + 4 * sin(t * 0.7 + Double(gI))
                let up = Int(t * (2.4 + Double(gI) * 0.5)) % 3 == 0
                let x = Int((camX + gx).rounded()), y = Int(gy.rounded())
                let gm = time == .day ? NativePalette.FOAM : NativePalette.SKYD, gv = time == .day ? 0.8 : 0.12
                m.run(x - 2, y + (up ? -1 : 0), 2, mat: gm, tone: 0, z: 0.9955, d: 0.98, emit: gv)
                m.run(x, y, 1, mat: gm, tone: 0, z: 0.9955, d: 0.98, emit: gv)
                m.run(x + 1, y + (up ? -1 : 0), 2, mat: gm, tone: 0, z: 0.9955, d: 0.98, emit: gv)
            }
        }
        return m.f
    }

    // MARK: 그리기 — 방파제 · 물보라 · 돌고래 · 등대(바다 층 위 · 결정적 — 게임 시간만)

    /// 바다 줄 y → 수평선~물가 비율 u · 시차 p(seaMesh 와 같다)
    static func seaU(_ y: Double) -> (u: Double, p: Double) {
        let u = min(1, max(0, (y - Double(BeachGeo.horizon)) / Double(BeachGeo.shore - BeachGeo.horizon)))
        return (u, 0.04 + 0.86 * pow(u, 1.5))
    }
    /// 방파제 가운데 장면 x(줄 u · 카메라) — 바다 평면 위 물체라 줄마다 시차가 다르다(카메라가 움직이면 멀수록 덜 움직인다)
    static func jettyX(_ u: Double, camX: Double) -> Double {
        let J = BeachGeo.jetty, k = max(0, min(1, (u - J.uTip) / (1 - J.uTip)))
        let p = 0.04 + 0.86 * pow(u, 1.5)
        return J.x1 + (J.x0 - J.x1) * k + (1 - p) * (camX - J.refCam)
    }
    /// 등대 빛줄기(6초 한 바퀴): 화면에 보이는 방향(−1 왼쪽 · +1 오른쪽) · 길이 비율 · 카메라 쪽 번쩍임
    static func lighthouseBeam(_ t: Double) -> (dir: Double, len: Double, flash: Double) {
        let a = t / 6 * 2 * .pi, s = sin(a), c = cos(a)
        return (s >= 0 ? 1 : -1, abs(s), pow(max(0, c), 10))
    }

    /// 방파제: 바다로 뻗은 돌 그로인(물가 → 수평선 쪽 60% 줄까지) — 젖은 바위 덩이(윗면 빛 · 아래 그늘) · 둘레 거품(밀려오는 동안 끓는다) ·
    /// 다가오는 파도 마루가 바위에 부딪히면(주기 위상 0.75) 물보라가 솟구쳤다 흩어진다(다음 파도가 크면 높게)
    func jetty(_ m: inout SnowQuads, camX: Double) {
        let hz = BeachGeo.horizon, J = BeachGeo.jetty
        let y0 = Int((Double(hz) + J.uTip * Double(BeachGeo.shore - hz)).rounded())
        let R = NativePalette.GIRD, FM = NativePalette.FOAM, tm = time
        let rockV: (Double, Double) = tm == .day ? (0.5, 0.86) : tm == .dusk ? (0.28, 0.5) : (0.12, 0.28)
        let ph = phase, surging = ph < Self.uprush + 0.1
        let yEnd = (BeachGeo.shoreLine.max() ?? BeachGeo.shore) + 3
        for y in y0...yEnd {
            let (u, _) = Self.seaU(Double(y)), k = max(0, min(1, (u - J.uTip) / (1 - J.uTip)))
            let cx = Self.jettyX(u, camX: camX), w = 1 + 4 * k
            let xa = Int((cx - w).rounded()), xb = Int((cx + w).rounded())
            guard xb >= xa else { continue }
            let z = 0.9944 - 0.0003 * u - 0.00008, d = 0.95 - 0.55 * u
            for x in xa...xb {
                let lx = x - Int(((1 - (0.04 + 0.86 * pow(u, 1.5))) * (camX - J.refCam)).rounded())   // 바위 무늬는 방파제에 붙는다
                let lump = SnowPaint.n2(Double(lx) / 2.3, Double(y) / 1.6, 241), edgeL = x == xa, edgeR = x == xb
                if (edgeL || edgeR) && lump < 0.35 { continue }   // 울퉁불퉁한 가장자리
                let top = y == y0 || SnowPaint.n2(Double(lx) / 2.3, Double(y - 1) / 1.6, 241) < 0.3
                var v = rockV.0 + (rockV.1 - rockV.0) * lump * 0.6 + (top ? (rockV.1 - rockV.0) * 0.5 : 0)
                v -= edgeR ? 0.08 : 0
                m.run(x, y, 1, mat: tm == .dusk && top && x < Int(cx) ? NativePalette.SUN : R, tone: 0, z: z, d: d, emit: tm == .dusk && top && x < Int(cx) ? 0.42 : v, ny: 0.8)
            }
            // 바위 머리: 물 위로 솟은 덩이(1~3px — 줄마다 몇 개) · 윗면 빛
            for x in stride(from: xa, through: xb, by: 2) {
                let lx = x - Int(((1 - (0.04 + 0.86 * pow(u, 1.5))) * (camX - J.refCam)).rounded())
                let hgt = Int((SnowPaint.h(lx / 2, y, 243) * (1 + 2.2 * k)).rounded())
                guard hgt > 0, y % 2 == 0 else { continue }
                for dy in 1...hgt {
                    let vv = dy == hgt ? rockV.1 : rockV.0 + (rockV.1 - rockV.0) * 0.35
                    m.run(x, y - dy, 2, mat: tm == .dusk && dy == hgt ? NativePalette.SUN : R, tone: 0, z: z - 0.00001, d: d, emit: tm == .dusk && dy == hgt ? 0.4 : vv, ny: 0.8)
                }
            }
            // 둘레 거품: 밀려오는 동안 끓고 · 평소엔 드문드문
            for x in [xa - 1, xb + 1, xa - 2, xb + 2] {
                let h = SnowPaint.h(x, y &+ Int(t * 9) &* 17, 242)
                if h < (surging ? 0.55 : 0.12) * (x == xa - 2 || x == xb + 2 ? 0.5 : 1) {
                    m.run(x, y, 1, mat: FM, tone: 0, z: z - 0.00002, d: d, emit: tm == .night ? 0.4 : 0.8, ny: 0.9)
                }
            }
        }
        // 물보라: 이번 주기 위상 0.75 에 마루가 부딪힌 자리(y 187)에서 — 입자는 해시로(상태 없음)
        let k = Int(floor(t / Self.period)), since = t - (Double(k) + 0.75) * Self.period
        let (bk, bt): (Int, Double) = since >= 0 ? (k, since) : (k - 1, since + Self.period)
        guard bt < 1.6 else { return }
        let big = Self.swell(bk + 1) > 20, yh = 187.0, (uh, _) = Self.seaU(yh), cx = Self.jettyX(uh, camX: camX)
        let n = big ? 96 : 64, g = 160.0
        for i in 0..<n {
            var hs = SplitMix64(seed: UInt64(truncatingIfNeeded: bk &* 977 &+ i &* 131 &+ 7))
            let ang = (hs.next() - 0.5) * 1.3, sp = (big ? 96 : 70) * (0.5 + 0.6 * hs.next()), lag = hs.next() * 0.14
            let tt = bt - lag
            guard tt > 0 else { continue }
            let vx = sin(ang) * sp * 0.7, vy = cos(ang) * sp
            let x = cx + (hs.next() - 0.5) * 6 + vx * tt, y = yh - 2 - vy * tt + 0.5 * g * tt * tt
            guard y < yh + 1 else { continue }
            let life = tt / (2 * vy / g + 0.2)
            if life > 0.6 && (Int(x) + Int(y)) & 1 == 0 { continue }
            let mist = i % 3 == 0
            m.run(Int(x.rounded()), Int(y.rounded()), mist || tt < 0.3 ? 2 : 1, mat: FM, tone: 0, z: 0.99395, d: 0.45, emit: (tm == .night ? 0.45 : mist ? 0.7 : 0.92) * (1 - 0.35 * life), ny: 0.6)
        }
    }

    /// n 번째 28초 창의 돌고래 출발 시각
    static func dolphinStart(_ n: Int) -> Double { var g = SplitMix64(seed: UInt64(truncatingIfNeeded: n &* 7907 &+ 1 &* 31 &+ 3)); return Double(n) * 28 + 5 + g.next() * 12 }
    // 깊이(GL z): 바다 줄은 0.9945 → 0.9942(물가) — 물보라 · 돌고래는 그보다 앞(0.994)이어야 보인다 · 모래 층(0.9855)보다는 뒤
    /// 돌고래: 28초마다 한 번쯤 두세 마리가 바다 가운데 줄에서 연달아 세 번 뛰어오른다(반짝임 길을 가로질러) — 밤엔 없다
    func dolphins(_ m: inout SnowQuads, camX: Double) {
        guard time != .night else { return }
        let W = 28.0, n = Int(floor(t / W))
        func h(_ s: Int) -> Double { var g = SplitMix64(seed: UInt64(truncatingIfNeeded: n &* 7907 &+ s &* 31 &+ 3)); return g.next() }
        let start = Self.dolphinStart(n), local = t - start
        guard local > -0.2 && local < 5.5 else { return }
        let pod = 2 + (h(2) < 0.55 ? 1 : 0), dir: Double = h(3) < 0.5 ? 1 : -1
        let yb = 168 + h(4) * 6, sx0 = dir > 0 ? 24 + h(5) * 60 : 174 - h(5) * 60   // 화면 x(하늘처럼 화면에 붙인다 — 먼 바다라 시차가 작다)
        let body = time == .day ? (NativePalette.GIRD, 0.3, 0.95) : (NativePalette.SKYD, 0.06, 0.2)   // 오후: 짙은 회청 몸 + 밝은 배 · 노을: 역광 실루엣
        let FM = NativePalette.FOAM
        for i in 0..<pod {
            for j in 0..<3 {
                let tau = (local - Double(i) * 0.34 - Double(j) * 1.25) / 1.0
                let bx = camX + sx0 + dir * (Double(j) * 26 + Double(i) * 7), by = yb + Double(i) * 2
                // 들고 날 때 물보라
                if (tau > -0.06 && tau < 0.16) || (tau > 0.88 && tau < 1.12) {
                    let ex = tau < 0.5 ? bx : bx + dir * 20, e = tau < 0.5 ? (tau + 0.06) / 0.22 : (tau - 0.88) / 0.24
                    for q in 0..<5 { let a = Double(q) / 4 * .pi; m.run(Int((ex + cos(a) * (1 + 3 * e)).rounded()), Int((by - sin(a) * 2 * (1 - e)).rounded()), 1, mat: FM, tone: 0, z: 0.99405, d: 0.5, emit: 0.8 * (1 - e * 0.6), ny: 0.6) }
                }
                guard tau > 0, tau < 1 else { continue }
                let x = bx + dir * 20 * tau, y = by - 10 * sin(.pi * tau)
                // 몸: 10×4 — 오를 땐 코가 위 · 꼭대기 수평 · 내려갈 땐 코가 아래(등지느러미 · 꼬리) · 'b' = 밝은 배
                let rows: [String] = tau < 0.33 ? ["       ##", "     ####", "  ######b", "###bbb   "]
                                   : tau < 0.67 ? ["    #     ", "  ########", "#########b", "  bbbbbb  "]
                                   : ["##        ", "####      ", "b#######  ", "   bbb### "]
                let ox = Int(x.rounded()) - 5, oy = Int(y.rounded()) - 3
                for (ry, row) in rows.enumerated() { for (rx, ch) in row.enumerated() where ch != " " {
                    let xx = dir > 0 ? ox + rx : ox + 9 - rx
                    m.run(xx, oy + ry, 1, mat: body.0, tone: 0, z: 0.99406, d: 0.5, emit: ch == "b" ? body.2 : body.1, ny: 0.7)
                } }
            }
        }
    }

    // MARK: 그리기 — 물가 · 젖은 모래 · 자국(배경 층 바로 앞 · 인물 뒤)

    func groundMesh(camX: Double, visibleWidth vw: Double) -> [Float] {
        let sh = BeachGeo.shore, F = BeachFloor.table, tm = time
        let x0 = max(0, Int(camX.rounded(.down)) - 2), x1 = min(BeachGeo.W, Int((camX + vw).rounded(.up)) + 2)
        var m = SnowQuads(quads: (x1 - x0) * 14 + marks.count * 10 + rings.count * 24)
        let z = BeachGeo.zBack - 0.0006, zw = BeachGeo.zBack - 0.0009
        let SW = NativePalette.SANDW, SH = BeachSheet.mat, FM = NativePalette.FOAM, SD = NativePalette.SAND
        let ek = BeachFloor.emitK(tm)
        func wetEmit(_ v: Float) -> Double { Double(max(0, (v + 0.5) / 6 * ek.k - ek.base + 0.06)) }
        let sheetBase: Double = tm == .day ? 0.3 : tm == .dusk ? 0.1 : 0.06
        let ph = phase
        // 젖은 모래 · 물: 열마다(같은 값 가로 줄은 합친다 — 줄 단위로 훑는다)
        let yMax = Int(min(Double(BeachGeo.H - 1), (wetTop[x0..<x1].max() ?? Double(sh)) + 3))
        let yMin = (BeachGeo.shoreLine[x0..<x1].min() ?? sh) - 1
        for y in yMin...yMax {
            var runKey = -1, runX = x0, runE = 0.0, runMat = 0, runNy = 0.0
            func flush(_ xe: Int) { if xe > runX && runKey >= 0 { m.run(runX, y, xe - runX, mat: runMat, tone: runMat == SH ? 0.2 : 0.3, z: runMat == SH || runMat == FM ? zw : z, d: BeachFx.D, emit: runE, ny: runNy) } }
            for x in x0..<x1 {
                let e = edge[x], Y = Double(y), s0 = Double(BeachGeo.shoreLine[x])
                var mt = -1, em = 0.0, ny = 0.8
                if Y < s0 - 1 { if runKey >= 0 { flush(x); runKey = -1 }; continue }   // 바다(seaMesh)
                if Y <= e {   // 밀려온 물: 끝 두 줄은 앞 테 거품 · 얇은 끝은 체크로 모래가 비친다 · 안쪽은 하늘이 비치는 물(반사 재질)
                    let dd = e - Y
                    if dd < 1.2 && e > s0 + 0.5 { mt = FM; em = tm == .night ? 0.4 : 0.82 }
                    else if dd < 3 && (x + y) & 1 == 0, let v = F.step(x, y) { mt = SW; em = wetEmit(v - 0.5) }
                    else { mt = SH; em = sheetBase + 0.04 * min(1, dd / 8); ny = 0.9 }
                    if mt == SH && SnowPaint.h(x, y &+ Int(t * 8) &* 7, 221) < 0.04 * min(1, dd / 4) { mt = FM; em = tm == .night ? 0.3 : 0.62 }   // 물속 거품 낱알
                } else if Y <= wetTop[x] + 1.5 * (SnowPaint.n2(Double(x) / 6, Y / 2.5, 222) - 0.5), let v = F.step(x, y) {   // 젖은 모래(끝은 고르지 않게 마른다)
                    let dryEdge = wetTop[x] - Y < 1.2
                    if dryEdge && (x + y) & 1 == 0 { if runKey >= 0 { flush(x); runKey = -1 }; continue }
                    mt = SW; em = wetEmit(v); ny = 0.85
                    // 이번 주기 가장 멀리 온 자리 — 빠지는 동안 남는 거품 레이스(꺼져 간다)
                    let rr = reach[x]
                    if ph > Self.uprush && ph < Self.backwash + 0.12 && abs(Y - rr) < 0.6 && rr > s0 + 2 {
                        let fade = (ph - Self.uprush) / (Self.backwash + 0.12 - Self.uprush)
                        if SnowPaint.h(x, Int(rr), 223 &+ UInt64(cycle & 7)) > 0.25 + 0.7 * fade { mt = FM; em = tm == .night ? 0.32 : 0.66 }
                    }
                }
                guard mt >= 0 else { if runKey >= 0 { flush(x); runKey = -1 }; continue }
                let key = mt * 100000 + Int((em * 240).rounded()) * 4 + Int(ny * 3)
                if key != runKey { flush(x); runKey = key; runX = x; runE = (em * 240).rounded() / 240; runMat = mt; runNy = ny }
            }
            flush(x1)
        }
        // 자국(마른 · 젖은): 바닥 값에서 단을 더하고 빼 이음매 없이
        for k in marks {
            let wash = Float(max(0, 1 - k.wash / 0.7))
            let fade = Float(max(0, min(1, (k.age - 14) / 20))) // 오래되면 바람에 얕아진다
            let deep = (1 - 0.6 * fade) * wash
            guard deep > 0.15 else { continue }
            let wetNow = k.wet || isWet(Double(k.x), Double(k.y))
            func px(_ x: Int, _ y: Int, _ d: Float, ny: Double = 0.5) {
                guard let v = F.step(x, y) else { return }
                if wetNow { m.run(x, y, 1, mat: SW, tone: 0.3, z: z - 0.0001, d: BeachFx.D, emit: wetEmit(v + d), ny: ny) }
                else { m.run(x, y, 1, mat: SD, tone: Double(BeachFloor.FT), z: z - 0.0001, d: BeachFx.D, emit: Double(BeachFloor.emit(v + d, tm)), ny: ny) }
            }
            switch k.kind {
            case .crater, .body:   // 구덩이 · 몸 자국: 안쪽 짙게 · 뒤 테 그늘 · 앞 입술(밀린 모래) 빛
                let rx = Double(k.w) / 2, ry = max(1.4, rx * (k.kind == .body ? 0.2 : 0.24)), cx = Double(k.x) + rx, cy = Double(k.y)
                for oy in -Int(ceil(ry + 1))...Int(ceil(ry + 1)) { for ox in -Int(ceil(rx + 2))...Int(ceil(rx + 2)) {
                    let X = Int(cx) + ox, Y = Int(cy) + oy, e = pow(Double(ox) / rx, 2) + pow(Double(oy) / ry, 2)
                    if e <= 1 { px(X, Y, (oy < 0 && e > 0.35 ? -2 : -1.5) * deep, ny: oy < 0 ? 0.1 : 0.45) }
                    else if e <= 2 && oy > 0 { px(X, Y, 1 * deep, ny: 0.9) }
                    else if e <= 1.7 && oy <= 0 { px(X, Y, 0.75 * deep, ny: 0.8) }
                } }
                if wetNow && wash > 0.5 { m.run(Int(cx) - 1, Int(cy), 3, mat: SH, tone: 0.25, z: z - 0.0002, d: BeachFx.D, emit: sheetBase + 0.06, ny: 0.9) }   // 고인 물
            case .step, .drag:
                let x = k.x, y = k.y, w = k.w
                for xx in x..<(x + w) { px(xx, y, -1.2 * deep); px(xx, y - 1, -1.6 * deep, ny: 0.2) }   // 눌린 안쪽 · 뒷벽 그늘
                px(x - 1, y, 0.8 * deep, ny: 0.8); px(x + w, y, 0.8 * deep, ny: 0.8)                    // 양옆 밀린 모래
                for xx in x..<(x + w) { px(xx, y + 1, 0.9 * deep, ny: 0.85) }                            // 앞 테 빛
                if wetNow && k.kind == .step && k.age < 6 && wash > 0.8 { m.run(x + w / 2, y, 1, mat: SH, tone: 0.25, z: z - 0.0002, d: BeachFx.D, emit: sheetBase + 0.1, ny: 0.9) }   // 물이 고여 반짝
            }
        }
        // 물 위 동심원(납작한 타원 테 — 체크로 옅어진다)
        for r in rings {
            let u = r.age / (r.big ? 1.1 : 0.8), rx = 2 + (r.big ? 16 : 9) * u, ry = max(0.8, rx * 0.28)
            for i in 0..<Int(10 + rx * 2) {
                let a = Double(i) / Double(Int(10 + rx * 2)) * 2 * .pi
                let x = Int((r.x + cos(a) * rx).rounded()), y = Int((r.y + sin(a) * ry).rounded())
                if u > 0.5 && (x + y) & 1 == 0 { continue }
                m.run(x, y, 1, mat: FM, tone: 0.3, z: zw - 0.0001, d: BeachFx.D, emit: (tm == .night ? 0.3 : 0.7) * (1 - 0.5 * u), ny: 0.9)
            }
        }
        return m.f
    }

    // MARK: 그리기 — 튀는 것(인물과 깊이 검사 — 뒤 절반은 인물 뒤, 앞 절반은 앞)

    func mesh() -> [Float] {
        var m = SnowQuads(quads: parts.count * 6 + 8)
        let tm = time, SD = NativePalette.SAND, SW = NativePalette.SANDW, FM = NativePalette.FOAM, SE = time.seaMat
        let lit: Double = tm == .night ? 0.45 : tm == .dusk ? 0.8 : 1
        for p in parts where p.age >= 0 {
            let u = p.age / p.life
            let z = 0.9 - p.gy / 300 + (p.front ? -0.06 : 0.05)
            let x = Int(p.x.rounded()), y = Int(p.y.rounded())
            switch p.kind {
            case .sand:   // 마른 모래 덩이: 밝은 윗면 + 그늘 아랫줄
                m.run(x, y, 2, mat: SD, tone: 0.5, z: z, d: 0.15, emit: 0.66 * lit, ny: 0.8)
                m.run(x, y + 1, 2, mat: SD, tone: 0.3, z: z, d: 0.15, emit: 0.4 * lit, ny: 0)
            case .clod:   // 젖은 모래 덩이(무겁고 짙다)
                m.run(x, y, 2, mat: SW, tone: 0.5, z: z, d: 0.15, emit: 0.5 * lit, ny: 0.8)
                m.run(x, y + 1, 2, mat: SW, tone: 0.3, z: z, d: 0.15, emit: 0.3 * lit, ny: 0)
            case .dust:   // 가루: 낱 픽셀이 자라며 체크로 옅어진다(반지름 0.6 → 2)
                let rr = 0.6 + 1.4 * min(1, u * 1.6), ri = Int(ceil(rr))
                for oy in -ri...ri { for ox in -ri...ri where Double(ox * ox + oy * oy) <= rr * rr + 0.3 {
                    if (x + ox + y + oy) & 1 != 0 || (u > 0.6 && (x + ox) & 1 == 0) { continue }
                    m.run(x + ox, y + oy, 1, mat: SD, tone: 0.45, z: z, d: 0.15, emit: (0.62 - 0.2 * u) * lit, ny: oy < 0 ? 0.6 : 0)
                } }
            case .drop:   // 물방울: 흰 반짝 1px + 아래 물빛 1px
                m.run(x, y, 1, mat: FM, tone: 0.4, z: z, d: 0.15, emit: (tm == .night ? 0.55 : 0.92) * (1 - 0.3 * u), ny: 0.9)
                if u < 0.6 { m.run(x, y + 1, 1, mat: SE, tone: 0.3, z: z, d: 0.15, emit: tm == .night ? 0.3 : 0.6, ny: 0.2) }
            case .spray:  // 물보라: 성긴 흰 낱 픽셀 둘(옅어지며)
                if u > 0.7 && (x + y) & 1 == 0 { continue }
                m.run(x, y, 1, mat: FM, tone: 0.4, z: z, d: 0.15, emit: (tm == .night ? 0.45 : 0.8) * (1 - 0.4 * u), ny: 0.6)
                if u < 0.4 { m.run(x + 1, y + 1, 1, mat: FM, tone: 0.4, z: z, d: 0.15, emit: tm == .night ? 0.35 : 0.66, ny: 0.6) }
            }
        }
        return m.f
    }
}

/// 밀려온 물(반사 재질 — 젖은 바닥 반사 갈래 0.95: 하늘 · 해가 비친다). 바다 재질과 따로 둬 바다는 비치지 않게 한다
enum BeachSheet {
    static let mat = NativePalette.SHEET
}
