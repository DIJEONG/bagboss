import Foundation
import BBCore
import BBContent
import BBSim

// 무대 위 스프라이트 입자(웹 16-anim pops · sparks · dusts · rings + GS.bits) — render() 의 placeAt 그대로.
//  수명: 웹 stepAnim 이 애니 칸마다 age += 12/animFps(= 게임 시간 1초에 12) — 여기선 게임 시계(gameTime) 차이로 민다.
//  먹이: SimEvent.fx(kind) · hit(맞은 자리 고리/불꽃 · 큰 타격 별 터짐 + 파편) · groundImpact(먼지 둘) · textPop(글리프 숫자)
//  웹 HITFX(벡터 효과: 잔상 · 초승달 · 충격파 고리 · 별 터짐 …)는 여기가 아니라 HUDDirector → 오버레이 패스가 그린다.
//  그리기 층: dusts = 그림자 다음 · 인물 앞(웹: drawChar 루프 전) / front = 3D 인물 뒤(rings → bits → sparks → pops)

public struct FxLayer: Sendable {
    struct Dust: Sendable { var x, y, age: Double; var flip: Bool }
    struct Spark: Sendable { var x, y, age: Double }
    struct Ring: Sendable { var x, y, age: Double; var burst: Bool }
    struct Bit: Sendable { var x, y, vx, vy, t: Double }
    struct Pop: Sendable { var x, y, age: Double; var text: String; var set: String }

    var dusts: [Dust] = [], sparks: [Spark] = [], rings: [Ring] = [], bits: [Bit] = [], pops: [Pop] = []
    private var lastGameTime: Double?
    private var rng: SplitMix64
    /// 웹 POSES[*].impact(타격 자세) — strike() 판정
    public var impactPoses: Set<String> = []
    private var lastPose: [ActorID: String] = [:], lastTime: Double?
    private var dragT0: Double?, dragDustT = 0.0

    public init(seed: UInt64 = 0xF00D) { rng = SplitMix64(seed: seed) }

    /// 지금 살아 있는 입자 수(디버그)
    public var count: Int { dusts.count + sparks.count + rings.count + bits.count + pops.count }

    /// 이벤트 반영. actors = 이번 틱 뒤 스냅숏(맞은 인물 · 때린 인물 위치)
    public mutating func apply(_ events: [SimEvent], actors: [SimSnapshot.ActorView], glyphs: Set<String>) {
        func actor(_ id: ActorID) -> SimSnapshot.ActorView? { actors.first { $0.id == id } }
        var rkMirrored = false
        for e in events {
            switch e {
            case .fx(let kind, let x, let y, let dir):
                switch kind {
                case "dust":
                    dusts.append(Dust(x: x, y: y, age: 0, flip: dir < 0))
                    // 웹 연환퇴 rk_land 는 먼지 둘(flip · !flip) — 규칙은 하나만 낸다
                    //  (다음 동작이 바로 이어지면 같은 틱에 자세가 land_q 로 넘어가 있다 — 지난 틱 자세가 연환퇴(rk_*)인지로 본다. rk_k1 먼지는 뒤쪽 방향이라 빠진다)
                    //  land_q 먼지(방향 0 · 1)와 겹칠 수 있어 한 번에 하나만
                    if !rkMirrored, dir != 0, let H = actors.first(where: { $0.isHero }), (H.pose.pose == "rk_land" || lastPose[H.id]?.hasPrefix("rk_") == true),
                       (dir < 0) == H.flip, abs(H.x - x) < 4, abs(H.y - y) < 1 { rkMirrored = true; dusts.append(Dust(x: x, y: y, age: 0, flip: dir >= 0)) }
                case "spark": sparks.append(Spark(x: x, y: y, age: 0))
                case "ring": rings.append(Ring(x: x, y: y, age: 0, burst: false))
                case "wave": rings.append(Ring(x: x, y: y - 8, age: 0, burst: true))   // 웹 종착역 마무리: rings burst(+ HITFX wave 는 HUD)
                case "sxboom": dusts.append(Dust(x: x, y: y + 8, age: 0, flip: false)); dusts.append(Dust(x: x, y: y + 8, age: 0, flip: true))   // 웹 sx_slam: 먼지 둘(fx 는 y-8 자리)
                default: break   // axring · tsring · swirl · sig_* · twfall … = 웹 HITFX 벡터 효과 → HUD 오버레이 패스(HUDDirector)
                }
            case .hit(let h):
                guard let T = actor(h.target) else { continue }
                let A = actor(h.attacker)
                let f = h.dir == 0 ? 1 : h.dir   // 웹 f(때린 쪽 방향 × 등 뒤면 −1)
                // 웹 damage(): 3D(jw) 인물이 때리면 고리(낮은 타격 −22 · 아니면 −44), 아니면 불꽃(−18 · −25)
                if A?.isPassenger == false || A == nil { rings.append(Ring(x: T.x - f * 5, y: T.y + (h.low ? -22 : -44), age: 0, burst: false)) }
                else { sparks.append(Spark(x: T.x - f * 2, y: T.y + (h.low ? -18 : -25), age: 0)) }
                // 웹: if(o.knock || o.react==='launch') 맞은 자리 먼지
                let launch = h.reactOpt == "launch"
                if h.knock || launch { dusts.append(Dust(x: T.x, y: T.y, age: 0, flip: T.flip)) }
                // 웹: heavy = o.knock || o.react==='launch' || (o.crit && dead) — 주인공이 적을 때렸을 때만 별 터짐 고리 + 파편 8
                let heavy = h.knock || launch || (h.crit && h.dead)
                if h.attackerAnim == "nv_rise" { continue }   // 네이티브 승천권: 별 터짐 고리 · 파편 없이(섬광 줄임 — 종이 회오리가 보이게)
                if heavy && h.attackerIsHero && T.isEnemy {
                    rings.append(Ring(x: T.x - f * 4, y: T.y - 42, age: 0, burst: true))
                    for _ in 0..<8 {
                        bits.append(Bit(x: T.x - f * 3, y: T.y - 42, vx: f * (40 + rng.next() * 130) + (rng.next() - 0.5) * 60, vy: -(50 + rng.next() * 140), t: 0))
                    }
                }
            case .actionCue(let a, _, let cue):
                // 웹 29 useSkill opts.cues 의 먼지(규칙은 큐 이름만 알린다): 섬머솔트 이륙 · 착지 둘 · 돌려차기 마무리 · 도끼 차기 들어 올림
                guard let A = actor(a) else { continue }
                switch cue {
                case "sk_jump", "sk_land": dusts.append(Dust(x: A.x, y: A.y, age: 0, flip: false)); dusts.append(Dust(x: A.x, y: A.y, age: 0, flip: true))
                case "r_hit_rt", "ax_up": dusts.append(Dust(x: A.x, y: A.y, age: 0, flip: A.flip))
                default: break
                }
            case .blocked(let t, _):
                if let T = actor(t) { sparks.append(Spark(x: T.x + (T.flip ? -6 : 6), y: T.y - 38, age: 2)) }
            case .guardBlock(let g) where !g.whiff:   // 네이티브 공방: 막은 자리 불꽃(무대 광원 포함)
                sparks.append(Spark(x: g.at.x, y: g.at.y, age: g.heavy || g.just ? 0 : 1))
            case .guardCrash(let g):                  // 가드 크래시: 불꽃 + 별 터짐 고리
                sparks.append(Spark(x: g.at.x, y: g.at.y, age: 0)); rings.append(Ring(x: g.at.x, y: g.at.y, age: 0, burst: true))
            case .groundImpact(let x, let y, _):
                dusts.append(Dust(x: x, y: y, age: 0, flip: false)); dusts.append(Dust(x: x, y: y, age: 0, flip: true))
                // 웹 30 도끼 차기 꽂힘 끝(spike): groundImpact 에 더해 먼지 둘 — 꽂힌 인물(rSpike) 발밑 자리로 알아본다
                if actors.contains(where: { $0.pose.anim.hasPrefix("rSpike") && $0.x == x && $0.y == y }) {
                    dusts.append(Dust(x: x, y: y, age: 0, flip: false)); dusts.append(Dust(x: x, y: y, age: 0, flip: true))
                }
            case .foeDowned(_, let cause, let at) where cause == .doorOut:
                dusts.append(Dust(x: at.x, y: at.y, age: 0, flip: false))
            case .textPop(let x, let y, let text):
                // 숫자 · 기호만(글리프 스프라이트) — 한글은 HUD 가 맡는다
                let set = "C"
                if text.allSatisfy({ glyphs.contains("g" + set + String($0)) }) { pops.append(Pop(x: x, y: y, age: 0, text: text, set: set)) }
            default: break
            }
        }
    }

    /// 스냅숏 흐름에서 알아보는 웹 먼지(규칙이 이벤트로 안 내는 것). 한 틱(또는 한 프레임) 이벤트 반영 뒤 부른다.
    ///  · 웹 16 strike(): 동작 요청 없이 타격 자세(impact)에 들어서면 그 인물 앞 먼지 — 도끼 차기에 꽂히는 적(sp_hit) · 필살기 연타(주인공).
    ///    웹은 실험실 인물(CHARS[0] 기사 88,101) 자리에 불꽃도 하나 찍는데 게임 인물과 무관한 자리라(웹 버그) 옮기지 않는다
    ///  · 웹 47 종착역 끌고 가기: S.t > .42 부터 .07초마다 잡힌 적 앞 먼지
    public mutating func track(_ s: SimSnapshot) {
        var seen: [ActorID: String] = [:]
        for a in s.actors where !a.hidden {
            let pose = a.pose.pose
            seen[a.id] = pose
            guard let prev = lastPose[a.id], prev != pose else { continue }
            let strike = (a.isEnemy && pose == "sp_hit") || (a.isHero && s.specialActive && impactPoses.contains(pose))
            if strike { let fa: Double = a.flip ? -1 : 1; dusts.append(Dust(x: a.x + fa * 4, y: a.y, age: 0, flip: a.flip)) }
        }
        lastPose = seen
        let dt = max(0, s.time - (lastTime ?? s.time)); lastTime = s.time
        if s.specialActive, let H = s.actors.first(where: { $0.isHero }), H.pose.anim == "spcHold", let T = s.actors.first(where: { $0.isEnemy && $0.pose.anim == "held" }), T.pose.pose != "nv_hl_drag" {   // 네이티브 끌기 자세면 규칙이 발 먼지를 낸다(World+Special)
            if dragT0 == nil { dragT0 = s.time; dragDustT = 0 } else {
                if s.time - dragT0! > 0.12 - 1e-9 {   // 웹 spcHold 는 S.t ≥ .3 에 시작 · 먼지는 S.t > .42 부터
                    dragDustT -= dt
                    if dragDustT <= 0 { dragDustT = 0.07; let f: Double = H.flip ? -1 : 1; dusts.append(Dust(x: T.x + f * 4, y: T.y, age: 0, flip: f < 0)) }
                }
            }
        } else { dragT0 = nil }
    }

    /// 게임 시계로 수명 진행(웹 stepAnim: 12/animFps 씩 · bits 는 rdt 로 물리)
    public mutating func advance(gameTime: Double, floorY: Double = 222) {
        let dg = max(0, min(0.1, gameTime - (lastGameTime ?? gameTime))); lastGameTime = gameTime
        guard dg > 0 else { return }
        let k = dg * 12
        for i in pops.indices { pops[i].age += k }; for i in sparks.indices { sparks[i].age += k }
        for i in dusts.indices { dusts[i].age += k }; for i in rings.indices { rings[i].age += k }
        rings.removeAll { $0.age > 4 }; pops.removeAll { $0.age > 16 }; sparks.removeAll { $0.age > 4 }; dusts.removeAll { $0.age > 5 }
        for i in bits.indices { bits[i].t += dg; bits[i].x += bits[i].vx * dg; bits[i].y += bits[i].vy * dg; bits[i].vy += 420 * dg }
        bits.removeAll { $0.t >= 0.8 }
    }

    /// 판이 바뀔 때(웹 enterCar · resetScene: pops · sparks · dusts 비우기)
    public mutating func clear() { dusts = []; sparks = []; rings = []; bits = []; pops = [] }

    /// 그리기 목록: 인물 앞 먼지
    public func dustDraws(_ spr: [String: AtlasMeta.Sprite]) -> [SpriteDraw] {
        var P = Painter(spr)
        for p in dusts { P.placeAt(p.age < 3 ? "dust0" : "dust1", jsRound(p.x), jsRound(p.y), p.flip, 0) }
        return P.out
    }
    /// 그리기 목록: 인물 뒤 앞 효과 + 동적 광원(불꽃)
    public func frontDraws(_ spr: [String: AtlasMeta.Sprite], floorY: Double = 222) -> (draws: [SpriteDraw], lights: [SceneLight]) {
        var P = Painter(spr), L: [SceneLight] = []
        for r in rings { P.placeAt(r.burst ? "fx_burst" + jsStr(min(1, jsFloor(r.age / 1.5))) : "fx_ring" + jsStr(min(2, jsFloor(r.age))), jsRound(r.x), jsRound(r.y), false, 0) }
        for b in bits where b.y < floorY { P.placeAt("fx_bit", jsRound(b.x), jsRound(b.y), false, 0) }
        for p in sparks {
            P.placeAt(p.age < 2 ? "spark0" : "spark1", jsRound(p.x), jsRound(p.y), false, 0)
            if p.age < 2 { L.append(SceneLight(x: p.x + 0.5, y: p.y + 0.5, z: 10, r: 48, c: [1, 0.95, 0.85], i: 1.6)) }
        }
        for p in pops {
            var x = jsRound(p.x) - jsFloor(Double(p.text.count) * 2)
            let y = jsRound(p.y) - min(jsRound(p.age), 6)
            if p.age > 12 && Int(jsFloor(p.age)) % 2 == 1 { continue }
            for ch in p.text { P.quad("g" + p.set + String(ch), x, y); x += ch == "." ? 2 : 4 }
        }
        return (P.out, L)
    }
}

