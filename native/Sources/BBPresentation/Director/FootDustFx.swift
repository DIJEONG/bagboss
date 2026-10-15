import Foundation
import BBCore
import BBContent
import BBSim

// 발놀림 먼지(docs/11 §3) — 눈 승강장 발 디딤 눈보라(SnowFx)를 모든 바닥으로. 깃발 켜짐(HUDCatalog.native)에서만 · 눈 바닥은 SnowFx 그대로.
//  · 계기: 질주 발 디딤(보폭 위상 gph 반 바퀴) · 걷기 디딤(드물게) · 방향 바꿈(제자리 돌기) · 미끄러져 서기(nv_skid 들어설 때 · 미끄러지는 동안 · nv_skidEnd)
//          · 출발 박차기(nv_go) · 착지(떠 있던 높이 > 6 → 0) · 쓰러져 미끄러짐(누운 몸이 바닥을 쓸며 밀려남 — 몸 뒤로 먼지 줄)
//  · 바닥 재질 색(ImpactFx 와 같은 무대 픽셀 길): 객차 = 회청색(아주 옅게) · 승강장 · 거리 = 콘크리트 · 무도장 = 따뜻한 나무 가루 · 타워 = 회색
//  · 1px 씨앗 → 나이에 따라 작은 구름(최대 2~3px)으로 부풀고 체크 디더로 옅어진다. 실내는 일부러 성기게(입자 수 · 남기는 칸 비율)
// 표현 몫 — 씨앗 고정 · 게임 시간으로만 흐른다(정지 · 슬로를 따른다).

struct FootDustFx {
    enum Floor { case car, platform, wood, tower }
    struct Puff { var x: Double, y: Double, vx: Double, vy: Double, age: Double, life: Double, r: Double, gy: Double }
    struct Track { var gph: Double?; var air: Double; var anim: String; var x: Double; var flip: Bool; var slideT: Double; var pose = "" }

    var puffs: [Puff] = []
    var tracks: [ActorID: Track] = [:]
    var ground: Floor = .car
    var rng = SplitMix64(seed: 0xF007D)
    mutating func R() -> Double { rng.next() }
    var isEmpty: Bool { puffs.isEmpty }
    static let maxPuffs = 96

    /// 재질 · 톤 · 발광 · 남기는 칸 비율(실내는 옅게)
    static func look(_ f: Floor) -> (mat: Int, tone: Double, emit: Double, keep: Double, k: Double) {
        switch f {
        case .car: return (NativePalette.HAZE, 1.0, 0.24, 0.55, 0.7)       // 객차 바닥: 회청색 먼지 — 옅게 · 적게
        case .platform: return (17, 1.0, 0.22, 0.65, 1.1)                 // CONC 콘크리트
        case .wood: return (11, 1.0, 0.3, 0.65, 1.0)                      // WOOD 따뜻한 나무 가루(바닥보다 밝게 — 같은 재질이라 묻히지 않게)
        case .tower: return (38, 1.0, 0.2, 0.6, 0.9)                      // STONEL 회색
        }
    }

    static let downAnims: Set<String> = ["down", "fall", "kd3", "kd4", "kd5", "ko", "crumple", "crumpleD", "death"]

    mutating func puff(_ x: Double, _ y: Double, dir: Double, n: Int, sp: Double = 1, up: Double = 1) {
        let k = Self.look(ground).k
        let m = max(1, Int((Double(n) * k).rounded()))
        for _ in 0..<m {
            puffs.append(Puff(x: x + (R() - 0.5) * 3, y: y - R(), vx: dir * (6 + R() * 18) * sp + (R() - 0.5) * 6, vy: -(8 + R() * 12) * up,
                              age: -R() * 0.03, life: 0.36 + R() * 0.24, r: 1.2 + R() * 1.0, gy: y))
        }
        if puffs.count > Self.maxPuffs { puffs.removeFirst(puffs.count - Self.maxPuffs) }
    }

    /// 스냅숏 하나(그리기 프레임마다) — 인물 발놀림을 본다
    mutating func track(_ s: SimSnapshot, dt: Double) {
        var seen: [ActorID: Track] = [:]
        for a in s.actors where !a.hidden && !a.isPassenger {
            let f: Double = a.flip ? -1 : 1
            let air = (a.pose.airOv ?? 0) + a.airOv
            let anim = a.pose.anim
            var T = tracks[a.id] ?? Track(gph: a.pose.gph, air: air, anim: anim, x: a.x, flip: a.flip, slideT: 0)
            let running = anim == "run" || anim == "nv_go" || (anim == "walk" && (a.pose.runU ?? -1) > s.gameTime)
            let down = Self.downAnims.contains(anim) || CharacterStage.downPoses.contains(a.pose.pose)
            // 1) 발 디딤(보폭 위상 반 바퀴마다) — 질주는 작은 한 줌, 걷기는 가끔 1점
            if let g = a.pose.gph, let g0 = T.gph, air < 1, !down {
                if floor(g * 2) != floor(g0 * 2) && abs(g - g0) < 0.5 {
                    let lead = (g - floor(g)) >= 0.5 ? -1.0 : 1.0
                    let fx = a.x + f * (running ? 6 : 3) * lead * 0.6
                    if running { puff(fx - f * 2, a.y, dir: -f, n: 3, sp: 0.8) } else if R() < 0.18 { puff(fx, a.y, dir: -f, n: 1, sp: 0.4, up: 0.6) }
                }
            }
            // 2) 미끄러져 서기: 들어설 때 앞으로 한 줌 · 미끄러지는 동안 앞발에서 조금씩 · 멈출 때 한 줌
            if anim == "nv_skid" {
                let dir: Double = a.x >= T.x ? 1 : -1
                if T.anim != "nv_skid" { puff(a.x + dir * 6, a.y, dir: dir, n: 4, sp: 1.2) }
                else if abs(a.x - T.x) > 0.3 && R() < 0.35 { puff(a.x + dir * 6, a.y, dir: dir, n: 1, sp: 0.6) }
            }
            if anim == "nv_skidEnd" && T.anim == "nv_skid" { puff(a.x + f * 6, a.y, dir: f, n: 3, sp: 0.5) }
            // 3) 출발 박차기 · 돌진(뒤로 차는 한 줌)
            if (anim == "nv_go" && T.anim != "nv_go") || (anim.hasPrefix("dash") && !T.anim.hasPrefix("dash")) { puff(a.x - f * 5, a.y, dir: -f, n: 3, sp: 1.1) }
            // 4) 방향 바꿈(땅 위 · 서 있거나 걷다가 돌아섬)
            if a.flip != T.flip && air < 1 && !down && !anim.hasPrefix("hit") { puff(a.x, a.y, dir: -f, n: 2, sp: 0.6, up: 0.7) }
            // 5) 착지
            if T.air > 6 && air < 0.5 && !down { puff(a.x - 4, a.y, dir: -1, n: 2, sp: 0.9, up: 0.6); puff(a.x + 4, a.y, dir: 1, n: 2, sp: 0.9, up: 0.6) }
            // 6) 쓰러져 미끄러짐: 누운 몸이 바닥을 쓸면(0.06초마다) 몸 뒤로 먼지 줄
            // 7) 버추어 파이터 두 기술(World+NativeVF): 파고드는 내디딤(앞발 앞으로 한 줌) · 웅크림에서 튀어 오름(위로 솟는 먼지) · 무릎 내디딤
            let pz = a.pose.pose
            if pz != T.pose && air < 1 {
                if pz == "du_step" { puff(a.x + f * 7, a.y, dir: f, n: 4, sp: 1.2); puff(a.x - f * 6, a.y, dir: -f, n: 2, sp: 0.8) }
                if pz == "du_rise" { puff(a.x - 4, a.y, dir: -1, n: 3, sp: 0.6, up: 2.4); puff(a.x + 4, a.y, dir: 1, n: 3, sp: 0.6, up: 2.4) }
                if pz == "kl_plant" { puff(a.x + f * 6, a.y, dir: f, n: 3, sp: 0.8, up: 0.7) }
            }
            T.pose = pz
            T.slideT = max(0, T.slideT - dt)
            if down && air < 1 && abs(a.x - T.x) > 0.35 && T.slideT <= 0 {
                let dir: Double = a.x >= T.x ? 1 : -1
                puff(a.x - dir * 4, a.y, dir: -dir, n: 1, sp: 0.3, up: 0.5); T.slideT = 0.06
            }
            T.gph = a.pose.gph; T.air = air; T.anim = anim; T.x = a.x; T.flip = a.flip
            seen[a.id] = T
        }
        tracks = seen
    }

    mutating func advance(_ dt: Double) {
        guard dt > 0, !puffs.isEmpty else { return }
        for i in puffs.indices {
            var p = puffs[i]
            p.age += dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= exp(-4 * dt); p.vy *= exp(-3 * dt)
            puffs[i] = p
        }
        puffs.removeAll { $0.age > $0.life }
    }

    /// 무대 픽셀(인물과 깊이 검사 — 발밑 앞뒤)
    func mesh() -> [Float] {
        guard !puffs.isEmpty else { return [] }
        let L = Self.look(ground)
        var m = SnowQuads(quads: puffs.count * 6)
        for p in puffs where p.age >= 0 {
            let u = p.age / p.life, r = p.r + 2.4 * min(1, u * 1.6), ri = Int(ceil(r))
            let x = Int(p.x.rounded()), y = Int(p.y.rounded()), z = 0.9 - p.gy / 300 - 0.02
            let keep = L.keep * (1 - u * 0.7)
            for oy in -ri...0 { for ox in -ri...ri where Double(ox * ox + oy * oy * 2) <= r * r {
                let X = x + ox, Y = y + oy
                guard u < 0.25 || (X + Y) & 1 == 0 else { continue }   // 갓 핀 먼지는 꽉 차게 → 체크 디더로 옅어진다
                let h = Double(UInt32(truncatingIfNeeded: (X &* 73856093) ^ (Y &* 19349663) ^ Int(p.life * 1000)) % 1000) / 1000
                guard h < keep else { continue }
                m.run(X, Y, 1, mat: L.mat, tone: L.tone, z: z, d: 0.15, emit: L.emit * (1 - u), ny: 0.4)
            } }
        }
        return m.f
    }
}
