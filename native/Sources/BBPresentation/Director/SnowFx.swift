import Foundation
import BBCore
import BBContent
import BBSim
import BBAnim

// 눈 승강장 움직이는 눈(docs/10) — 표현 몫(규칙 상태 없음 · 씨앗 고정 · 게임 시간으로만 흐른다 → 멈춤 · 배속을 그대로 따른다).
//  1) 내리는 눈 3층(카메라 시차): 먼 1px 흐린 눈(느림 · 많음) · 가운데 1~2px · 가까운 2~3px 밝고 큰 눈(인물 앞을 지난다)
//     바람(옆으로 흐름) + 흔들림 + 가끔 돌풍(1초 남짓 모든 층이 기운다). 따뜻한 등 아래 원뿔 안의 눈은 무대 조명(스폿)이 저절로 데운다
//  2) 바닥 자국: 걷기 · 달리기 발 디딤마다 발자국 · 미끄러지면 끌린 자국 · 쓰러지면 몸 자국 — 몇 초 뒤 새 눈에 묻혀 디더로 사라진다
//  3) 싸움에 튀는 눈: 달리기 발 디딤 작은 눈보라 · 미끄러져 서기 앞으로 뿌리는 호 + 끌린 줄 · 쓰러짐 · 튕김 큰 터짐(덩이 + 낮게 깔리는 가루 구름) ·
//     무거운 타격 · 바닥 충격 바닥 고리 · 점프 착지 고리 · 승천권 상승 기류(발밑 눈이 종이 회오리와 함께 돈다)
//     입자 = 가루(1px · 천천히 가라앉고 바람에 흐른다) + 덩이(2px · 중력으로 빨리 떨어져 바닥에서 사라진다). 모두 정수 픽셀
//  4) 입김: 인물마다 숨 박자(서 있기 3.0~3.6초 · 걷기 2초 · 달리기는 두 발 디딤마다 · 힘쓴 뒤 헐떡임 → 3초에 걸쳐 가라앉음 · 맞는 순간 세게 한 번)
//     입(머리뼈 + 몸 기울기)에서 앞 · 위로 흐르고 바람(내리는 눈과 같은 바람 · 돌풍)에 휜다. 2×1 → 5×3 · 낱 픽셀 디더 · 등 원뿔 안에서만 밝다
//  5) 바닥 반짝이: 결정 낱 픽셀이 천천히 깜빡인다(주로 가로등 웅덩이 안)

/// 무대 픽셀 쿼드 쌓기(PixelMesh 와 같은 정점 10 float — 디버그 빌드에서도 가볍게: 임시 배열 없이 미리 늘린 칸에 바로 쓴다)
struct SnowQuads {
    var f: [Float] = []
    static let blank = [Float](repeating: 0, count: 60)
    init(quads: Int) { f.reserveCapacity(quads * 60) }
    mutating func run(_ x: Int, _ y: Int, _ w: Int, mat: Int, tone: Double, z: Double, d: Double, emit: Double = 0, ny: Double = 0) {
        guard w > 0 else { return }
        let o = f.count
        f.append(contentsOf: Self.blank)
        let x0 = Float(x), x1 = Float(x + w), y0 = Float(y), y1 = Float(y + 1)
        let zz = Float(z), n = Float(ny), t = Float(tone), m = Float(mat), dd = Float(d), e = Float(emit)
        f.withUnsafeMutableBufferPointer { b in
            var i = o
            for k in 0..<6 {
                let px = (k == 1 || k == 2 || k == 4) ? x1 : x0, py = (k == 2 || k == 4 || k == 5) ? y1 : y0
                b[i] = px; b[i + 1] = py; b[i + 2] = zz; b[i + 3] = 0; b[i + 4] = n; b[i + 5] = t; b[i + 6] = m; b[i + 7] = -1; b[i + 8] = dd; b[i + 9] = e
                i += 10
            }
        }
    }
}

/// 눈 효과 상태(StageDirector 가 프레임을 넘어 이어 간다)
struct SnowFx {
    struct Flake { var x: Double, y: Double, vy: Double, ph: Double, layer: Int, size: Int }
    struct Mark { var x: Int, y: Int, w: Int, age: Double, deep: Bool, crater: Bool = false }
    struct Part { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, chunk: Bool, gy: Double, front: Bool, big: Bool }
    struct Track {
        var gph: Double?; var air: Double, anim: String, x: Double
        /// 숨: 위상(0..1 — 1 이 되면 내쉰다) · 헐떡임(1 → 3초에 걸쳐 0) · 내쉬는 중 남은 시간 · 세기 · 다음 김 · 발 디딤 수
        var bph: Double, pant = 0.0, exT = 0.0, exK = 0.0, exNext = 0.0, plants = 0
        /// 큰 몸인가(생김새 열쇠를 처음 한 번만 푼다)
        var heavy: Bool? = nil
    }
    /// 입김 한 줌(낱 픽셀 2~4 — 자라며 옅어진다)
    struct Breath { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, k: Double, seed: UInt32, z: Double, id: ActorID }

    var flakes: [Flake] = []
    var marks: [Mark] = []
    var parts: [Part] = []
    var breaths: [Breath] = []
    var tracks: [ActorID: Track] = [:]
    /// 규칙 이벤트에서 온 숨 계기(다음 track 에서 입 위치로 낸다): 맞음(세게 한 번 + 헐떡임) · 힘씀(헐떡임)
    var hurtIDs: Set<ActorID> = [], pantIDs: Set<ActorID> = []
    var lastDt = 1.0 / 60
    /// 연타 수(웹 GS.combo) — 3 이상이던 것이 끊기면 헐떡임
    var lastCombo = 0
    var rng = SplitMix64(seed: 0x5A0F)
    var t = 0.0
    var wind = 14.0, gustT0 = -99.0, gustDir = 1.0, nextGust = 4.0
    var on = false
    /// 이번에 낼 소리(StageDirector.takeSnowCues 가 꺼낸다) · 발소리 간격
    var sounds: [SoundCue] = []
    var stepSndT = -9.0

    mutating func R() -> Double { rng.next() }

    /// 화면 창 폭(내리는 눈은 보이는 창 안에서만 돈다 — 시차로 감아 돌린다)
    static let wrapW = 260.0

    mutating func reset() {
        flakes = []; marks = []; parts = []; breaths = []; tracks = [:]; hurtIDs = []; pantIDs = []; t = 0; nextGust = 4
        rng = SplitMix64(seed: 0x5A0F)
        for i in 0..<230 {   // 먼 150 · 가운데 66 · 가까운 14
            let layer = i < 150 ? 0 : i < 216 ? 1 : 2
            flakes.append(Flake(x: R() * Self.wrapW, y: R() * 290 - 10, vy: [11, 22, 38][layer] * (0.75 + R() * 0.5), ph: R() * 6.28, layer: layer,
                                size: layer == 0 ? 1 : layer == 1 ? (R() < 0.3 ? 2 : 1) : (R() < 0.5 ? 3 : 2)))
        }
        on = true
    }

    /// 돌풍(0..1 — 1초 남짓 부풀었다 가라앉는다)
    var gust: Double { let u = (t - gustT0) / 1.3; return u < 0 || u > 1 ? 0 : sin(u * .pi) * sin(u * .pi) }
    var windNow: Double { wind + gustDir * 70 * gust }

    // MARK: 흐름

    /// dt = 게임 시간
    mutating func advance(_ dt: Double) {
        guard dt > 0 else { return }
        t += dt; lastDt = dt
        if t > nextGust { gustT0 = t; gustDir = R() < 0.7 ? 1 : -1; nextGust = t + 6 + R() * 7 }
        let w = windNow
        for i in flakes.indices {
            var f = flakes[i]
            let k = f.layer == 0 ? 0.45 : f.layer == 1 ? 0.8 : 1.25
            f.y += f.vy * dt * (1 + gust * 0.3)
            f.x += (w * k + sin(t * (0.9 + Double(f.layer) * 0.4) + f.ph) * (f.layer == 0 ? 3.0 : f.layer == 1 ? 6 : 10)) * dt
            if f.y > 268 { f.y -= 280; f.x = R() * Self.wrapW }
            flakes[i] = f
        }
        for i in marks.indices { marks[i].age += dt }
        marks.removeAll { $0.age > 9 }
        if marks.count > 160 { marks.removeFirst(marks.count - 160) }
        for i in parts.indices {
            var p = parts[i]
            p.age += dt
            if p.chunk {
                p.vy += 520 * dt; p.vx *= exp(-1.5 * dt)
            } else {
                p.vx += (w * 0.35 - p.vx) * min(1, 2.6 * dt); p.vy += (14 - p.vy) * min(1, 2.2 * dt)   // 가루: 공기에 붙잡혀 천천히 가라앉고 바람에 흐른다
            }
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.chunk && p.vy > 0 && p.y >= p.gy { p.age = p.life + 1 }   // 덩이는 바닥에 닿으면 사라진다(눈에 섞인다)
            if !p.chunk && p.y > p.gy { p.y = p.gy; p.vy = 0 }
            parts[i] = p
        }
        parts.removeAll { $0.age > $0.life }
        if parts.count > 420 { parts.removeFirst(parts.count - 420) }
        // 입김: 처음엔 내쉰 힘으로 나아가다 공기에 붙잡혀 바람에 휘고 천천히 오른다
        for i in breaths.indices {
            var b = breaths[i]
            b.age += dt
            let g = min(1, 1.6 * dt)
            b.vx += (w * 0.32 - b.vx) * g; b.vy += (-9 - b.vy) * g * 0.7
            b.x += b.vx * dt; b.y += b.vy * dt
            breaths[i] = b
        }
        breaths.removeAll { $0.age > $0.life }
        if breaths.count > 48 { breaths.removeFirst(breaths.count - 48) }
    }

    // MARK: 튀기기

    mutating func puff(_ x: Double, _ gy: Double, dir: Double, n: Int, sp: Double = 1) {
        for k in 0..<max(1, n * 2 / 3) {
            let chunk = k == 0 && R() < 0.6
            parts.append(Part(x: x + (R() - 0.5) * 4, y: gy - 1, vx: -dir * (14 + R() * 30) * sp + (R() - 0.5) * 16, vy: -(16 + R() * 34) * sp,
                              age: 0, life: chunk ? 0.6 : 0.45 + R() * 0.5, chunk: chunk, gy: gy, front: R() < 0.5, big: false))
        }
    }
    /// 미끄러져 서기: 앞으로 뿌리는 호
    mutating func spray(_ x: Double, _ gy: Double, dir: Double, k: Double) {
        for i in 0..<Int(8 * k) + 4 {
            let chunk = i % 3 == 0
            parts.append(Part(x: x + dir * 3, y: gy - 1, vx: dir * (50 + R() * 120), vy: -(50 + R() * 110), age: 0, life: chunk ? 0.9 : 0.6 + R() * 0.7,
                              chunk: chunk, gy: gy + (R() - 0.5) * 3, front: R() < 0.6, big: chunk && R() < 0.4))
        }
    }
    /// 쓰러짐 · 튕김: 덩이 + 낮게 깔리는 가루 구름
    mutating func burst(_ x: Double, _ gy: Double, power p: Double) {
        let n = Int(6 + 7 * p)
        for _ in 0..<n {
            let a = .pi * (0.12 + R() * 0.76), s = (60 + R() * 120) * (0.7 + 0.4 * p)
            parts.append(Part(x: x + (R() - 0.5) * 12, y: gy - 2, vx: cos(a) * s * (R() < 0.5 ? -1 : 1), vy: -sin(a) * s, age: 0, life: 1.0,
                              chunk: true, gy: gy + (R() - 0.5) * 4, front: R() < 0.55, big: R() < 0.45))
        }
        for _ in 0..<Int(9 + 8 * p) {   // 가루 구름: 옆으로 퍼지고 1초 남짓 낮게 머문다
            parts.append(Part(x: x + (R() - 0.5) * 16, y: gy - 1 - R() * 6, vx: (R() - 0.5) * 120 * (0.6 + 0.4 * p), vy: -(8 + R() * 30), age: 0,
                              life: 0.9 + R() * 0.7, chunk: false, gy: gy, front: R() < 0.5, big: false))
        }
    }
    /// 무거운 타격 · 바닥 충격 · 착지: 바닥을 따라 퍼지는 고리
    mutating func ring(_ x: Double, _ gy: Double, power p: Double) {
        let n = Int(6 + 8 * p)
        for i in 0..<n {
            let side: Double = i % 2 == 0 ? 1 : -1
            parts.append(Part(x: x + side * R() * 4, y: gy - 1, vx: side * (70 + R() * 110) * (0.6 + 0.4 * p), vy: -(6 + R() * 26), age: 0,
                              life: 0.5 + R() * 0.5, chunk: i % 5 == 0, gy: gy, front: R() < 0.5, big: false))
        }
    }

    // MARK: 규칙 이벤트 · 스냅숏 흐름

    mutating func apply(_ events: [SimEvent], _ s: SimSnapshot) {
        guard on else { return }
        func actor(_ id: ActorID) -> SimSnapshot.ActorView? { s.actors.first { $0.id == id } }
        for e in events {
            switch e {
            case let .groundImpact(x, y, p):
                ring(x, y, power: min(2, max(0.4, p))); burst(x, y, power: min(1.5, p * 0.6))
                // 눈은 갈라지지 않는다 → 눌린 구덩이(납작한 타원: 뒷테 그늘 · 앞 입술 빛) — 발자국처럼 새 눈에 묻힌다
                let cw = Int(12 + 8 * min(2, p))
                marks.append(Mark(x: Int(x) - cw / 2, y: Int(y), w: cw, age: 0, deep: true, crater: p >= 0.9))
            case let .fx("dust", x, y, _):
                burst(x, y, power: 0.8); if sounds.count < 4 { sounds.append(.snowBurst) }
                marks.append(Mark(x: Int(x) - 8, y: Int(y), w: 16, age: 0, deep: true))
            case let .fx("sxboom", x, y, _): burst(x, y + 8, power: 1.4)
            case .hit(let h):
                if !h.dead && !h.splash { hurtIDs.insert(h.target) }   // 맞는 순간 세게 한 번 + 헐떡임
                guard h.knock || h.reactOpt == "launch" || h.weight == .heavy, let T = actor(h.target) else { continue }
                ring(T.x, T.y, power: h.weight == .heavy ? 1 : 0.6)
            case let .comboEnded(count, _) where count >= 2:   // 콤보 경로를 끝낸 주인공이 헐떡인다
                if let H = s.actors.first(where: { $0.isHero }) { pantIDs.insert(H.id) }
            default: break
            }
        }
    }

    /// 매 프레임: 발 디딤 · 미끄러짐 · 착지 · 입김을 스냅숏 흐름에서 알아본다
    mutating func track(_ s: SimSnapshot, mouths: [ActorID: (p: SIMD2<Double>, fwd: SIMD2<Double>)]) {
        guard on else { return }
        var seen: [ActorID: Track] = [:]
        if s.combo < lastCombo && lastCombo >= 3, let H = s.actors.first(where: { $0.isHero }) { pantIDs.insert(H.id) }
        lastCombo = s.combo
        for a in s.actors where !a.hidden && !a.isPassenger {
            let f: Double = a.flip ? -1 : 1
            let air = (a.pose.airOv ?? 0) + a.airOv
            var T = tracks[a.id] ?? Track(gph: a.pose.gph, air: air, anim: a.pose.anim, x: a.x, bph: Self.unit(a.id, 1))   // 인물마다 숨 위상이 다르다
            let anim = a.pose.anim
            let running = anim == "run" || anim == "nv_go" || (anim == "walk" && (a.pose.runU ?? -1) > s.gameTime)   // 질주(웹 runPose: walk + runU > 지금)
            // 1) 발 디딤(보폭 위상이 0 · 0.5 를 지날 때) — 달리면 작은 눈보라, 걸으면 자국만
            if let g = a.pose.gph, let g0 = T.gph, air < 1 {
                let crossed = floor(g * 2) != floor(g0 * 2) && abs(g - g0) < 0.5   // gph 는 누적 위상(한 바퀴 = 1) — 반 바퀴마다 한 발
                if crossed {
                    let lead = (g - floor(g)) >= 0.5 ? -1.0 : 1.0
                    let fx = a.x + f * (running ? 6 : 3) * lead * 0.6
                    marks.append(Mark(x: Int(fx.rounded()) - 1, y: Int(a.y.rounded()), w: running ? 3 : 2, age: 0, deep: false))
                    if running { puff(fx, a.y, dir: f, n: 4) } else if R() < 0.35 { puff(fx, a.y, dir: f, n: 1, sp: 0.5) }
                    T.plants += 1
                    if running && T.plants % 2 == 0 && T.pant < 0.5 { T.exT = 0.1; T.exK = 0.95; T.exNext = 0; T.bph = 0 }   // 달리기: 두 발 디딤마다 짧게 훅
                    if a.isHero && t - stepSndT > 0.16 { stepSndT = t; sounds.append(.snowStep(run: running)) }
                }
            }
            // 2) 미끄러져 서기: 들어서는 순간 호 · 미끄러지는 동안 앞발에서 계속 + 끌린 자국
            if anim == "nv_skid" {
                let dir: Double = a.x >= T.x ? 1 : -1
                if T.anim != "nv_skid" { spray(a.x + dir * 6, a.y, dir: dir, k: 1.4); if sounds.count < 4 { sounds.append(.snowSkid) } }
                else if abs(a.x - T.x) > 0.3 { spray(a.x + dir * 6, a.y, dir: dir, k: 0.15); marks.append(Mark(x: Int(min(a.x, T.x)) + Int(dir * 4), y: Int(a.y.rounded()), w: max(2, Int(abs(a.x - T.x).rounded()) + 1), age: 0, deep: true)) }
            }
            if anim == "nv_skidEnd" && T.anim == "nv_skid" { puff(a.x + f * 7, a.y, dir: -f, n: 6, sp: 0.8) }
            // 3) 점프 착지(떠 있다가 내려앉음) · 이륙
            if T.air > 6 && air < 0.5 && !a.isPassenger { ring(a.x, a.y, power: min(1, T.air / 30)); marks.append(Mark(x: Int(a.x) - 4, y: Int(a.y), w: 8, age: 0, deep: false)) }
            if T.air < 0.5 && air > 3 && anim != "nv_rise" { puff(a.x, a.y, dir: -f, n: 4, sp: 0.7) }
            // 4) 승천권 이륙: 발밑 눈이 솟는다(회오리는 그리기에서 나이로)
            if anim == "nv_rise" && T.anim != "nv_rise" { ring(a.x, a.y, power: 0.7) }
            // 5) 입김(숨 박자): 서 있기 · 막기 3.0~3.6초 · 걷기 2초 · 달리기는 발 디딤(위) · 힘쓴 뒤 헐떡임 · 맞는 순간 세게 · 쓰러져 있으면 없음
            breathe(a, &T, anim: anim, running: running, mouth: mouths[a.id])
            T.gph = a.pose.gph; T.air = air; T.anim = anim; T.x = a.x
            seen[a.id] = T
        }
        tracks = seen
        hurtIDs = []; pantIDs = []
    }

    /// 0..1 고정 난수(인물 번호 · 갈래 — 숨 위상 · 박자 차이)
    static func unit(_ id: ActorID, _ k: UInt64) -> Double { var g = SplitMix64(seed: UInt64(truncatingIfNeeded: id) &* 0x9E37 &+ k &* 0x51ED); return g.next() }
    static let downAnims: Set<String> = ["down", "fall", "kd3", "kd4", "kd5", "ko", "getup", "getupP"]
    static let hurtAnims: Set<String> = ["hit", "hitB", "hitK", "hurt", "hitrun"]

    /// 숨 한 박자 흐름 · 내쉬기(입 위치에서 김을 낸다 — 내쉬는 동안 머리를 따라간다)
    mutating func breathe(_ a: SimSnapshot.ActorView, _ T: inout Track, anim: String, running: Bool, mouth: (p: SIMD2<Double>, fwd: SIMD2<Double>)?) {
        let dt = lastDt
        if T.heavy == nil { T.heavy = a.isBoss || a.look.flatMap { LookSpec(key: $0) }.map { $0.fat || $0.boss || $0.hair == "nv_lineback" } == true || a.enemyType == "brute" }
        let heavy = T.heavy ?? false
        let down = Self.downAnims.contains(anim) || CharacterStage.downPoses.contains(a.pose.pose) || (a.isEnemy && a.hp <= 0)
        // 힘쓴 뒤: 일어남(getup 끝) · 승천권 끝 · 연타 끝 · 맞음 → 헐떡임 1
        if (T.anim == "getup" || T.anim == "getupP" || T.anim == "nv_rise") && anim != T.anim && !down { T.pant = 1; T.bph = 1 }
        if pantIDs.contains(a.id) { T.pant = 1; T.bph = max(T.bph, 0.85) }
        if hurtIDs.contains(a.id) && !down { T.exT = 0.08; T.exK = 1.5; T.exNext = 0; T.bph = 0; T.pant = max(T.pant, 0.8) }
        T.pant = max(0, T.pant - dt / 3)
        guard !down, let M = mouth else { T.exT = 0; return }
        // 박자: 인물마다 ±7% · 큰 몸은 느리게
        var P = anim == "walk" && !running ? 2.0 : 3.0 + 0.6 * Self.unit(a.id, 2)
        P *= (0.93 + 0.14 * Self.unit(a.id, 3)) * (heavy ? 1.15 : 1)
        if running && T.pant < 0.5 { P = 9 }   // 달리기는 발 디딤이 박자를 정한다(위상 멈춤)
        let pp = (1 - T.pant) * (1 - T.pant)
        P = 0.5 * (heavy ? 1.15 : 1) + (P - 0.5) * pp   // 헐떡임: 0.5초 간격 → 3초에 걸쳐 평소로
        T.bph += dt / P
        if T.bph >= 1 && T.exT <= 0 {
            T.bph -= floor(T.bph)
            T.exT = T.pant > 0.3 ? 0.1 : anim == "walk" ? 0.16 : 0.22; T.exK = 0.8 + 0.35 * T.pant; T.exNext = 0
        }
        // 내쉬는 동안: 0.07초마다 입에서 한 줌(머리를 따라간다)
        guard T.exT > 0 else { return }
        T.exT -= dt; T.exNext -= dt
        guard T.exNext <= 0 else { return }
        T.exNext = 0.07
        let k = T.exK * (heavy ? 1.25 : 1), f: Double = a.flip ? -1 : 1
        let sp = (k > 1.3 ? 34 : 14 + 6 * k) * (0.85 + 0.3 * R())
        let fw = M.fwd.x == 0 && M.fwd.y == 0 ? SIMD2(f, 0) : M.fwd
        breaths.append(Breath(x: M.p.x + fw.x, y: M.p.y + fw.y, vx: fw.x * sp + windNow * 0.15, vy: fw.y * sp - 3 - 3 * R(), age: 0,
                              life: (k > 1.3 ? 0.6 : 0.7 + 0.3 * R()) * (heavy ? 1.1 : 1), k: k, seed: UInt32(truncatingIfNeeded: Int(R() * 65535)),
                              z: 0.9 - a.y / 300 - 0.08, id: a.id))
    }

    // MARK: 그리기

    /// 바닥 반짝이 자리(결정 낱 픽셀 — 70% 는 가로등 웅덩이 안) · 위상 · 빠르기
    static let glints: [(x: Int, y: Int, ph: Double, sp: Double, lit: Bool)] = {
        var g = SplitMix64(seed: 0x6117), out: [(Int, Int, Double, Double, Bool)] = []
        let F = SnowFloor.table
        while out.count < 64 {
            let pool = g.next() < 0.7
            let x = pool ? Int(SnowGeo.lamps[Int(g.next() * 3) % 3] + 6 + (g.next() - 0.5) * 70) : Int(g.next() * Double(SnowGeo.W))
            let y = pool ? 200 + Int(g.next() * 18) : 203 + Int(g.next() * 44)
            guard x >= 0, x < SnowGeo.W, y > F.edge[x] + 1, F.step(x, y) != nil else { continue }
            out.append((x, y, g.next() * 6.28, 0.5 + g.next() * 0.9, pool))
        }
        return out
    }()

    /// 바닥 자국 · 반짝이(배경 층 바로 앞 · 같은 그리기) — 장면 x 그대로. 바닥 값(SnowFloor)에서 단 단위로 더하고 빼 이음매가 없다
    ///   발자국: 안쪽 한 단 짙게 · 빛 쪽(뒤 · 가까운 가로등 쪽) 가장자리 1px 그늘 · 반대쪽 1px 빛 — 3.5초 뒤부터 5.5초에 걸쳐 새 눈에 묻힌다
    func markMesh() -> [Float] {
        var m = SnowQuads(quads: marks.count * 8 + 24)
        let z = SnowGeo.zBack - 0.001, F = SnowFloor.table, FT = Double(SnowFloor.FT)
        func px(_ x: Int, _ y: Int, _ w: Int, _ d: Float, ny: Double = 0.45) {
            guard let v = F.step(x, y) else { return }
            m.run(x, y, w, mat: Int(F.mat(x, y)), tone: FT, z: z, d: 0.12, emit: Double(SnowFloor.emit(v + d)), ny: ny)
        }
        for k in marks where k.crater {   // 구덩이: 안쪽 한~두 단 짙게 · 뒤 테 그늘 · 앞 입술(들린 눈) 빛 · 양옆 밀린 눈
            let fade = max(0, min(1, (k.age - 3.5) / 5.5))
            if fade > 0.85 { continue }
            let rx = Double(k.w) / 2 * (1 - 0.3 * fade), ry = max(1.2, rx * 0.22), cx = Double(k.x) + Double(k.w) / 2, cy = Double(k.y)
            let deep: Float = fade < 0.45 ? 1 : 0.5, thin = fade > 0.6
            for oy in -Int(ceil(ry + 1))...Int(ceil(ry + 1)) { for ox in -Int(ceil(rx + 2))...Int(ceil(rx + 2)) {
                let X = Int(cx) + ox, Y = Int(cy) + oy
                if thin && (X + Y) & 1 == 0 { continue }
                let e = pow(Double(ox) / rx, 2) + pow(Double(oy) / ry, 2)
                if e <= 1 {
                    let back = oy < 0 && e > 0.35
                    px(X, Y, 1, back ? -2 * deep - 1 : e < 0.3 ? -2 * deep : -1.5 * deep, ny: back ? 0.1 : 0.45)
                } else if e <= 2.0 && oy > 0 { px(X, Y, 1, deep + 1, ny: 0.9) }                   // 앞 입술: 들린 눈
                else if e <= 1.8 && oy <= 0 { px(X, Y, 1, deep, ny: 0.8) }                        // 뒤 · 옆 테: 밀려 쌓인 눈
            } }
        }
        for k in marks where !k.crater {
            let fade = max(0, min(1, (k.age - 3.5) / 5.5))
            let w = max(1, Int((Double(k.w) * (1 - 0.5 * fade)).rounded())), x = k.x + (k.w - w) / 2, y = k.y
            if fade > 0.85 { continue }
            let deep: Float = fade < 0.45 ? 1 : 0.5   // 묻히며 얕아진다(한 단 → 반 단)
            // 빛 쪽: 가장 가까운 가로등이 왼쪽이면 왼쪽 끝이 그늘 · 오른쪽 끝이 빛
            let lampL = (SnowGeo.lamps.min { abs($0 - Double(x)) < abs($1 - Double(x)) } ?? 0) < Double(x)
            let thin = fade > 0.6   // 마지막엔 체크 디더로 흩어진다
            for xx in x..<(x + w) where !thin || (xx + y) & 1 == 0 { px(xx, y, 1, -deep) }                  // 다져진 안쪽
            for xx in x..<(x + w) where !thin || (xx + y) & 1 == 1 { px(xx, y - 1, 1, -deep - (fade < 0.3 ? 1 : 0), ny: 0.2) }   // 뒷벽 그늘
            if k.deep && w > 2 { px(x + 1, y + 1, w - 2, -deep * 0.5) }
            if fade < 0.5 {
                px(lampL ? x - 1 : x + w, y, 1, -1)   // 빛 쪽 가장자리 그늘
                px(lampL ? x + w : x - 1, y, 1, 1, ny: 0.8)   // 반대쪽 빛(밀린 눈)
                px(x, y + 1, w, k.deep ? 0.5 : 1, ny: 0.8)   // 앞 벽에 걸린 빛
            }
        }
        // 반짝이: 천천히 깜빡이는 결정(웅덩이 안은 톤이 높아 가로등 빛을 받아 크림색으로 튄다)
        for g in Self.glints {
            let tw = sin(t * g.sp + g.ph)
            guard tw > 0.82, let v = F.step(g.x, g.y) else { continue }
            let up: Float = tw > 0.95 ? 2 : 1
            m.run(g.x, g.y, 1, mat: Int(F.mat(g.x, g.y)), tone: g.lit ? 1.3 : 0.9, z: z - 0.0002, d: 0.12, emit: Double(SnowFloor.emit(v + up)), ny: 0.9)
        }
        return m.f
    }

    /// 내리는 눈 · 튀는 눈 · 입김 · 승천권 회오리(인물과 깊이 검사 — 뒤 층은 인물 뒤, 가까운 층은 앞)
    func mesh(camX: Double, visibleWidth vw: Double, risePapers: [RisePaper]) -> [Float] {
        var m = SnowQuads(quads: flakes.count + parts.count * 8 + breaths.count * 4 + 64)
        let SN = NativePalette.SNOW
        let W = Self.wrapW, span = min(W, vw + 24)
        for f in flakes {
            let p = f.layer == 0 ? 0.45 : f.layer == 1 ? 0.85 : 1.2
            // 층 x(0..W) → 화면 창 안 장면 x(카메라 시차로 감아 돈다)
            var sx = (f.x - camX * p).truncatingRemainder(dividingBy: W); if sx < 0 { sx += W }
            guard sx < span else { continue }
            let x = Int(camX - 12 + sx), y = Int(f.y)
            switch f.layer {
            case 0: m.run(x, y, 1, mat: SN, tone: 0.25, z: 0.984, d: 0.5, emit: 0.36)
            case 1:
                m.run(x, y, f.size, mat: SN, tone: 0.4, z: 0.3, d: 0.3, emit: 0.5)
                if f.size == 2 { m.run(x, y + 1, 2, mat: SN, tone: 0.4, z: 0.3, d: 0.3, emit: 0.42) }
            default:   // 가까운 큰 눈: 가운데 밝고 모서리 어두운 부드러운 덩이(인물 앞)
                let s = f.size
                if s == 3 {   // 십자 + 흐린 모서리 하나
                    m.run(x + 1, y, 1, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.7); m.run(x, y + 1, 3, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.8)
                    m.run(x + 1, y + 2, 1, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.7); m.run(x + 2, y + 2, 1, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.45)
                } else { m.run(x, y, 2, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.78); m.run(x, y + 1, 2, mat: SN, tone: 0.5, z: 0.02, d: 0.2, emit: 0.62) }
            }
        }
        for p in parts where p.age >= 0 {
            let u = p.age / p.life
            if u > 0.7 && (Int(p.x) + Int(p.y)) & 1 == 0 && !p.chunk { continue }   // 사라질 땐 체크 디더
            let z = 0.9 - p.gy / 300 + (p.front ? -0.06 : 0.05)
            let x = Int(p.x.rounded()), y = Int(p.y.rounded())
            if p.chunk {   // 덩이: 밝은 윗면 + 푸른 그늘 아랫줄(눈 바닥 위에서도 읽히게)
                m.run(x, y, 2, mat: SN, tone: 0.5, z: z, d: 0.15, emit: 0.92)
                m.run(x, y + 1, 2, mat: SN, tone: 0.3, z: z, d: 0.15, emit: p.big ? 0.5 : 0.3)
                if p.big { m.run(x, y + 2, 2, mat: SN, tone: 0.3, z: z, d: 0.15, emit: 0.3) }
            } else {   // 가루: 작은 구름 덩이 — 나이에 따라 부풀고(반지름 0.7 → 2.4) 가장자리부터 체크 디더로 옅어진다
                let rr = (p.big ? 1.1 : 0.7) + 1.7 * min(1, u * 1.6), ri = Int(ceil(rr))
                for oy in -ri...ri {
                    let hw2 = rr * rr + 0.3 - Double(oy * oy)
                    guard hw2 >= 0 else { continue }
                    let hw = Int(sqrt(hw2)), inner2 = (rr - 1) * (rr - 1) - Double(oy * oy), iw = inner2 >= 0 ? Int(sqrt(inner2)) : -1
                    let ny = oy < 0 ? 0.6 : 0, eE = 0.62 - 0.22 * u, eI = 0.88 - 0.22 * u
                    if u > 0.55 {   // 옅어질 때: 체크 디더 낱 픽셀
                        for ox in -hw...hw where (x + ox + y + oy) & 1 == 0 && !(u > 0.8 && ((x + ox) & 1 == 0 || (y + oy) & 1 == 0)) {
                            m.run(x + ox, y + oy, 1, mat: SN, tone: 0.45, z: z, d: 0.15, emit: abs(ox) > iw ? eE : eI, ny: ny)
                        }
                        continue
                    }
                    if iw >= 0 { m.run(x - iw, y + oy, iw * 2 + 1, mat: SN, tone: 0.45, z: z, d: 0.15, emit: eI, ny: ny) }   // 속 = 한 줄
                    for ox in stride(from: -hw, to: -max(iw, -1) - (iw >= 0 ? 0 : 0), by: 1) where ox < -iw && (x + ox + y + oy) & 1 == 0 { m.run(x + ox, y + oy, 1, mat: SN, tone: 0.45, z: z, d: 0.15, emit: eE, ny: ny) }
                    for ox in stride(from: iw + 1, through: hw, by: 1) where (x + ox + y + oy) & 1 == 0 { m.run(x + ox, y + oy, 1, mat: SN, tone: 0.45, z: z, d: 0.15, emit: eE, ny: ny) }
                }
            }
        }
        // 입김: 2×1 → 5×3 타원 안의 낱 픽셀 2~4개(성긴 디더 — 반투명하게 읽힌다). 톤이 높고 발광이 거의 없어 등 원뿔 안에서만 밝다
        for b in breaths {
            let u = b.age / b.life, q = min(1, u * 1.6)
            let hw = (1 + 1.5 * q) * (0.85 + 0.15 * b.k), hh = (0.5 + 1.0 * q) * (0.85 + 0.15 * b.k)
            let cx = b.x.rounded(), cy = b.y.rounded()
            let maxN = u < 0.15 ? 2 : u < 0.7 ? 4 : u < 0.88 ? 3 : 2
            let ri = Int(ceil(hw)), rj = Int(ceil(hh))
            // 가로등 원뿔 안이면 빛을 받아 밝다(등은 고정 — 원뿔 cos 0.82 · 아래로 갈수록 옅다) · 어둠에선 거의 안 보인다
            var cone = 0.0
            for lx in SnowGeo.lamps {
                let dx = b.x - (lx + 7), dy = b.y - SnowGeo.lampY
                guard dy > 0 else { continue }
                cone = max(cone, max(0, 1 - abs(dx) / (dy * 0.62 + 2)) * (1 - min(1, dy / 190)))
            }
            cone = min(1, cone * 2.2)
            let em = (0.03 + 0.32 * cone) * (1 - u * 0.6) * min(1.3, b.k), tone = (0.55 + 0.6 * cone) * (1 - 0.3 * u)
            // 타원 안 칸 → 가운데부터(타원 거리 + 씨앗 흔들림) maxN 개: 처음엔 가로로 뭉친 김, 옅어질 땐 체크 디더로 흩어진다
            var cand: [(Double, Int, Int)] = []; cand.reserveCapacity(24)
            for oy in -rj...rj { for ox in -ri...ri {
                let ex = Double(ox) / max(0.6, hw), ey = Double(oy) / max(0.6, hh), d2 = ex * ex + ey * ey
                guard d2 <= 1.05 else { continue }
                if u > 0.55 && (ox + oy + Int(b.seed & 1)) & 1 != 0 { continue }
                let j = Double((UInt32(truncatingIfNeeded: (ox + 7) * 31 + (oy + 7) * 7) &* 2654435761 ^ b.seed) & 255) / 255 * 0.45
                cand.append((d2 + j, ox, oy))
            } }
            cand.sort { $0.0 < $1.0 }
            for (_, ox, oy) in cand.prefix(maxN) {
                m.run(Int(cx) + ox, Int(cy) + oy, 1, mat: SN, tone: tone, z: b.z, d: 0.15, emit: em, ny: 0.3)
            }
        }
        // 승천권 상승 기류: 발밑 눈이 몸을 감고 돌며 오른다(종이 회오리와 같은 회전) → 0.9초 뒤 풀려 흩날리며 떨어진다
        for P in risePapers where P.age < 2.4 {
            var g = SplitMix64(seed: P.seed ^ 0x5A0)
            let dir: Double = P.f >= 0 ? 1 : -1
            for i in 0..<26 {
                let th0 = g.next() * 6.28, H = 18 + g.next() * 70, lag = 0.6 + g.next() * 0.4, r0 = 4 + g.next() * 8, drift = (g.next() - 0.5) * 30
                let t = P.age - Double(i % 5) * 0.02
                guard t > 0 else { continue }
                let tr = min(t, 0.9)
                var th = th0, a = 0.0, dtt = 1.0 / 60
                while a < tr { th += dir * NativeRiseArt.spinRate(a) * lag * dtt; a += dtt }
                let hh = H * (1 - pow(1 - min(1, tr / 0.5), 2)), r = r0 + 5 + hh * 0.32
                var x = P.x + r * cos(th), y = P.y - hh - 0.28 * r * sin(th)
                let front = sin(th) > 0
                if t > 0.9 { let u = t - 0.9; x += drift * u + windNow * 0.3 * u; y += 22 * u + 6 * u * u }
                if y > P.y { continue }
                if t > 1.8 && (i + Int(t * 20)) & 1 == 0 { continue }
                let z = 0.9 - P.y / 300 + (front ? -0.1 : 0.1)
                m.run(Int(x), Int(y), i % 6 == 0 ? 2 : 1, mat: SN, tone: 0.5, z: z, d: 0.15, emit: front ? 0.7 : 0.45)
            }
        }
        return m.f
    }
}
