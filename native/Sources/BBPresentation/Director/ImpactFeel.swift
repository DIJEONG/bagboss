import Foundation
import BBCore
import BBContent
import BBSim

// 타격감 묶음(docs/11 — New Virtua Fighter 공개 영상 분석에서 감독이 고른 네 가지). 깃발 켜짐(HUDCatalog.native)에서만 · 표현 몫.
//  1) KO 마무리 카메라: 규칙 koFinisher(0.4초 0.25배 슬로 → 정지 2칸) 위에 — 슬로 동안 몸 쪽으로 밀고 들어가 → 정지 →
//     쓰러진 몸 가운데로 빼며(줌 아웃) 0.6초 한 박자 머묾(환경음 낮춤 · 타격음 끊김) → 제자리. 흔들림 줄이기면 카메라는 안 움직인다(최소판)
//  2) 받아치기 · 치명 펀치인: 줌 +8% · 0.25초 감쇠 + 더치 틸트 2.5°(부호는 사건마다 결정적) · 맞은 몸 찌그러짐(2칸 0.85×1.1 → 3칸 튕겨 돌아옴). 0.6초 쿨
//  3) 발놀림 먼지: FootDustFx
//  4) 열기: 무거운 타격 자리 몸이 주황-빨강으로 잠깐 달아오름(0.22초) + 불티 3~6. 온몸 흰 번쩍임은 없다 · 번쩍임 줄이기면 작고 짧게
// 시계: 카메라 · 찌그러짐 = 화면 시간(실제 dt — 슬로 · 정지와 무관하게 같은 길이) · 불티 · 먼지 = 게임 시간.

struct ImpactFeel {
    // MARK: 상태
    struct KO { var t: Double; var target: ActorID; var x: Double; var y: Double; var calm: Bool }
    struct Punch { var t: Double; var x: Double; var y: Double; var sign: Double }
    struct Squash { var t: Double; var dir: Double }
    struct Heat { var t: Double; var life: Double; var dir: Double; var hy: Double; var k: Double }
    struct Ember { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, z: Double }

    /// 화면 시계(초)
    var t = 0.0
    var ko: KO?
    var punch: Punch?
    var lastPunch = -99.0
    var squash: [ActorID: Squash] = [:]
    var heat: [ActorID: Heat] = [:]
    var embers: [Ember] = []
    var dust = FootDustFx()
    /// 조용한 한 박자(타격음 끊김) · 환경음 낮추기 예약(화면 시계)
    var quiet: ClosedRange<Double>?
    var hushAt: Double?
    var rng = SplitMix64(seed: 0x1F7AC7)
    mutating func R() -> Double { rng.next() }

    // 시간표(초)
    static let koSlow = 0.4, koFreeze = 0.08, koPull = 0.3, koHold = 0.6, koBack = 0.4
    static var koEnd: Double { koSlow + koFreeze + koPull + koHold + koBack }
    static let punchLife = 0.25, punchCD = 0.6, punchZoom = 0.08, punchRoll = 2.5 * Double.pi / 180
    static let heatLife = 0.22

    var busy: Bool { ko != nil || punch != nil || !squash.isEmpty || !heat.isEmpty || !embers.isEmpty || !dust.isEmpty }

    // MARK: 계기

    /// 이벤트(규칙 한 묶음). calm = 흔들림 줄이기 · noFlash = 번쩍임 줄이기
    mutating func apply(_ events: [SimEvent], _ s: SimSnapshot, calm: Bool, noFlash: Bool) {
        var koNow = false
        let roof = events.contains { if case .roofBlast = $0 { return true }; return false }
        for e in events {
            guard case .koFinisher(let K) = e else { continue }
            koNow = true
            if !roof { ko = KO(t: t, target: K.target, x: K.x, y: K.y, calm: calm) }   // 지붕 뚫기면 그쪽 카메라가 맡는다
            quiet = (t + Self.koSlow)...(t + Self.koSlow + Self.koFreeze + Self.koPull + Self.koHold)
            hushAt = t + Self.koSlow
            punch = nil
        }
        for e in events {
            switch e {
            case .hit(let h):
                guard h.attackerIsHero, !h.heroWasHit, let T = s.actors.first(where: { $0.id == h.target }), T.isEnemy else { continue }
                let f = h.dir == 0 ? 1.0 : h.dir
                // 2) 받아치기(적이 치려고 준비 · 내지르는 중에 맞힘 — 규칙 chit/counter) · 치명
                if (h.counter || h.crit) && t - lastPunch >= Self.punchCD {
                    lastPunch = t
                    squash[T.id] = Squash(t: t, dir: f)
                    if !koNow && ko == nil {
                        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: h.target) &* 0x9E3779B9 &+ UInt64(max(0, s.gameTime * 600).rounded()) &+ UInt64(h.damage))
                        let air = (T.pose.airOv ?? 0) + T.airOv
                        punch = Punch(t: t, x: T.x, y: T.y - air - 36, sign: g.next() < 0.5 ? -1 : 1)
                    }
                }
                // 4) 열기: 넘어뜨림 · 띄움 · 큰 치명 · 메치기 꽂음 · 승천권 꼭대기 · 무거운 기술(손맛 H, 치명 아님) · 치명 처치
                let riseApex = h.attackerAnim == "nv_rise" && h.damage >= 12
                let heavy = h.knock || h.reactOpt == "launch" || h.reaction == "rSlam" || h.bigCrit || riseApex || (h.crit && h.dead)
                    || (h.weight == .heavy && !h.crit && h.attackerAnim != "nv_rise")
                if heavy { ignite(T, dir: f, low: h.low, s, noFlash: noFlash) }
            case .fx(let k, let x, let y, let d) where k == "wallImpact":   // 벽꿍: 벽에 붙은 몸
                if let T = s.actors.filter({ $0.isEnemy && !$0.hidden && abs($0.x - x) < 30 }).min(by: { abs($0.x - x) < abs($1.x - x) }) {
                    _ = y; ignite(T, dir: d >= 0 ? 1 : -1, low: false, s, noFlash: noFlash)
                }
            default: break
            }
        }
    }

    /// 열기 걸기 + 불티
    mutating func ignite(_ T: SimSnapshot.ActorView, dir f: Double, low: Bool, _ s: SimSnapshot, noFlash: Bool) {
        let life = Self.heatLife * (noFlash ? 0.65 : 1)
        heat[T.id] = Heat(t: t, life: life, dir: f, hy: low ? 0.32 : 0.7, k: noFlash ? 0.5 : 1)
        let air = (T.pose.airOv ?? 0) + T.airOv
        let px = T.x - f * 3, py = T.y - air - (low ? 18 : 38)
        let n = noFlash ? 3 : 3 + Int(R() * 4)
        for _ in 0..<n {
            embers.append(Ember(x: px + (R() - 0.5) * 6, y: py + (R() - 0.5) * 6, vx: f * (6 + R() * 16) + (R() - 0.5) * 14, vy: -(18 + R() * 30),
                                age: -R() * 0.04, life: (0.35 + R() * 0.3) * (noFlash ? 0.7 : 1), z: 0.9 - T.y / 300 - 0.07))
        }
        if embers.count > 48 { embers.removeFirst(embers.count - 48) }
    }

    // MARK: 흐름

    /// 화면 프레임: dt = 화면 시간 · gdt = 게임 시간
    mutating func advance(dt: Double, gdt: Double) {
        t += dt
        if let K = ko, t - K.t > Self.koEnd { ko = nil }
        if let P = punch, t - P.t > Self.punchLife { punch = nil }
        squash = squash.filter { t - $0.value.t < 0.12 }
        heat = heat.filter { t - $0.value.t < $0.value.life }
        if let q = quiet, t > q.upperBound { quiet = nil }
        if gdt > 0 && !embers.isEmpty {
            for i in embers.indices {
                var e = embers[i]
                e.age += gdt; e.x += e.vx * gdt; e.y += e.vy * gdt; e.vx *= exp(-2.5 * gdt); e.vy = e.vy * exp(-1.2 * gdt) - 4 * gdt
                e.x += sin(e.age * 17 + e.z * 999) * 6 * gdt   // 하늘거림
                embers[i] = e
            }
            embers.removeAll { $0.age > $0.life }
        }
        dust.advance(gdt)
    }

    /// 지금 환경음을 낮출 때인가(한 번) — 앱이 AudioEngine.duck 으로 옮긴다
    mutating func takeHush() -> Bool {
        guard let h = hushAt, t >= h else { return false }
        hushAt = nil; return true
    }
    /// 조용한 한 박자 동안 끊는 소리(타격 · 피격 · 휘두름 · 쿵)
    func muted(_ c: SoundCue) -> Bool {
        guard let q = quiet, q.contains(t) else { return false }
        switch c {
        case .hit3, .hitK, .hurt, .swing, .whoosh, .thud, .floor, .block, .snowStep, .snowSkid, .sandStep, .sandSkid, .splash: return true
        default: return false
        }
    }

    // MARK: 카메라

    static func ease(_ u: Double) -> Double { let x = max(0, min(1, u)); return x * x * (3 - 2 * x) }
    static func easeOut(_ u: Double) -> Double { let x = max(0, min(1, u)); return 1 - (1 - x) * (1 - x) }

    /// 카메라 프레임 다듬기(KO 마무리 · 펀치인). motion = 흔들림 배율(1 = 보통 · 줄이기 0.3)
    func shape(_ v: inout StageView, _ s: SimSnapshot, motion: Double) {
        guard s.camZoom <= 1 else { return }   // 필살기 줌 중엔 손대지 않는다
        if let K = ko, !K.calm, motion >= 1 {
            let u = t - K.t
            // 지금 몸 자리(날아가는 중이면 따라간다)
            var bx = K.x, by = K.y - 30
            if let A = s.actors.first(where: { $0.id == K.target }), !A.hidden { bx = A.x; by = A.y - ((A.pose.airOv ?? 0) + A.airOv) - (CharacterStage.isDown(A) ? 12 : 30) }
            let t1 = Self.koSlow, t2 = t1 + Self.koFreeze, t3 = t2 + Self.koPull, t4 = t3 + Self.koHold
            let z: Double, w: Double
            if u < t1 { z = 0.10 * Self.easeOut(u / 0.15); w = 0.35 * Self.ease(u / t1) }
            else if u < t2 { z = 0.10; w = 0.35 }
            else if u < t3 { let k = Self.ease((u - t2) / Self.koPull); z = 0.10 + (0.03 - 0.10) * k; w = 0.35 + 0.65 * k }
            else if u < t4 { z = 0.03; w = 1 }
            else { let k = Self.ease((u - t4) / Self.koBack); z = 0.03 * (1 - k); w = 1 - k }
            // 가로: 쓰러진 몸을 가운데로(주인공이 화면 밖으로 나가지 않게)
            let VW = v.visibleWidth, W = v.sceneWidth
            var cx = bx - VW / 2
            if let H = s.actors.first(where: { $0.isHero }) { let m = min(40, VW * 0.15); cx = max(H.x - VW + m, min(H.x - m, cx)) }
            cx = max(0, min(W - VW, cx))
            v.cameraX = v.cameraX + (cx - v.cameraX) * w
            v.zoom = 1 + z
            v.zoomCenter = [bx / W, max(0.2, min(0.85, by / v.sceneHeight))]
            return
        }
        if let P = punch {
            let u = (t - P.t) / Self.punchLife
            let e = u < 0.16 ? Self.easeOut(u / 0.16) : pow(1 - (u - 0.16) / 0.84, 2)   // 빠르게 들어가 감속하며 돌아온다
            let zp = Self.punchZoom * e * motion
            if v.zoom <= 1.0005 { v.zoomCenter = [P.x / v.sceneWidth, max(0.2, min(0.85, P.y / v.sceneHeight))] }
            v.zoom += zp
            if motion >= 1 { v.roll = P.sign * Self.punchRoll * e }   // 흔들림 줄이기면 틸트 없음
        }
    }

    // MARK: 인물 정점(찌그러짐 · 달아오름)

    /// 찌그러짐 세기(화면 프레임 60Hz 기준 칸 표 — 2칸 눌림 → 3칸에 튕겨 돌아옴)
    static func squashAmt(_ age: Double) -> Double {
        let tab: [Double] = [1, 1, 0.45, -0.15, -0.05, 0]
        let f = age * 60
        if f >= Double(tab.count - 1) { return 0 }
        let i = Int(f), k = f - Double(i)
        return tab[i] + (tab[i + 1] - tab[i]) * k
    }

    /// 인물 정점 고치기(ranges = CharacterLayer.ranges). 고친 게 없으면 그대로
    func deform(_ mesh: inout [Float], ranges: [ActorID: Range<Int>], _ s: SimSnapshot) {
        guard !squash.isEmpty || !heat.isEmpty else { return }
        mesh.withUnsafeMutableBufferPointer { m in
            for (id, r) in ranges where r.count >= 30 {
                let sq = squash[id], ht = heat[id]
                guard sq != nil || ht != nil else { continue }
                var x0 = Float.greatestFiniteMagnitude, x1 = -x0, y0 = x0, y1 = -x0
                for i in stride(from: r.lowerBound, to: r.upperBound, by: 10) { x0 = min(x0, m[i]); x1 = max(x1, m[i]); y0 = min(y0, m[i + 1]); y1 = max(y1, m[i + 1]) }
                let A = s.actors.first { $0.id == id }
                let air = A.map { ($0.pose.airOv ?? 0) + $0.airOv } ?? 0
                if let q = sq {
                    let a = Float(Self.squashAmt(t - q.t))
                    if a != 0 {
                        let px = (x0 + x1) / 2, py = air > 3 ? (y0 + y1) / 2 : y1, d = Float(q.dir)
                        let sx = 1 - 0.15 * a, sy = 1 + 0.10 * a, sh = 0.08 * a * d
                        for i in stride(from: r.lowerBound, to: r.upperBound, by: 10) {
                            let dy = m[i + 1] - py
                            m[i] = px + (m[i] - px) * sx - sh * dy
                            m[i + 1] = py + dy * sy
                        }
                    }
                }
                if let h = ht {
                    let u = (t - h.t) / h.life
                    let k = Float(h.k * (u < 0.15 ? 1 : pow(1 - (u - 0.15) / 0.85, 1.5)))
                    let cx = (x0 + x1) / 2 - Float(h.dir) * 3, cy = y1 - (y1 - y0) * Float(h.hy)
                    let rad: Float = 9 * (h.k < 1 ? 0.7 : 1)
                    var i = r.lowerBound
                    while i + 30 <= r.upperBound {   // 삼각형 단위(flat 값은 마지막 정점)
                        let mx = (m[i] + m[i + 10] + m[i + 20]) / 3 - cx, my = (m[i + 1] + m[i + 11] + m[i + 21]) / 3 - cy
                        let d = (mx * mx + my * my).squareRoot()
                        if d < rad {
                            let w = k * (1 - d / rad)
                            for j in [i, i + 10, i + 20] {
                                m[j + 9] = max(m[j + 9], w * 0.55)             // 발광
                                if w > 0.25 { m[j + 6] = Float(NativePalette.HEAT); m[j + 5] = 0.45 + 0.4 * w }   // 가운데는 달아오른 쇠 빛(주황-빨강)
                            }
                        }
                        i += 30
                    }
                }
            }
        }
    }

    // MARK: 무대 픽셀(열기 낱 픽셀 · 불티 · 발 먼지)

    func mesh(_ s: SimSnapshot, ranges: [ActorID: Range<Int>], bodyMesh: [Float]) -> [Float] {
        var m = SnowQuads(quads: embers.count + heat.count * 24)
        // 열기 낱 픽셀: 맞은 자리 둘레 다이아몬드 · 체크 디더로 식는다
        for (id, h) in heat {
            guard let A = s.actors.first(where: { $0.id == id }), let r = ranges[id], r.count >= 30 else { continue }
            var y0 = Float.greatestFiniteMagnitude, y1 = -y0, x0 = y0, x1 = -y0
            for i in stride(from: r.lowerBound, to: r.upperBound, by: 10) { x0 = min(x0, bodyMesh[i]); x1 = max(x1, bodyMesh[i]); y0 = min(y0, bodyMesh[i + 1]); y1 = max(y1, bodyMesh[i + 1]) }
            let u = (t - h.t) / h.life
            let cx = Int((Double(x0 + x1) / 2 - h.dir * 3).rounded()), cy = Int((Double(y1) - Double(y1 - y0) * h.hy).rounded())
            let rr = (h.k < 1 ? 1.6 : 2.4) * (1 - 0.4 * u), ri = Int(ceil(rr))
            let z = 0.9 - A.y / 300 - 0.06
            for oy in -ri...ri { for ox in -ri...ri {
                let d = Double(abs(ox) + abs(oy))
                guard d <= rr else { continue }
                if u > 0.45 && (cx + ox + cy + oy) & 1 == 1 { continue }
                let core = d < rr * 0.45
                m.run(cx + ox, cy + oy, 1, mat: NativePalette.HEAT, tone: core ? 0.85 : 0.6, z: z, d: 0.15, emit: h.k * (core ? 0.6 : 0.35) * (1 - u), ny: 0.3)
            } }
        }
        for e in embers where e.age >= 0 {
            let u = e.age / e.life
            if u > 0.6 && Int(e.age * 30) % 2 == 1 { continue }   // 꺼져 가며 깜빡
            m.run(Int(e.x.rounded()), Int(e.y.rounded()), 1, mat: NativePalette.HEAT, tone: 0.8 - 0.4 * u, z: e.z, d: 0.15, emit: 0.55 - 0.4 * u, ny: 0.3)
        }
        return m.f + dust.mesh()
    }
}
