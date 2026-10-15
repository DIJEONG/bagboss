import Testing
import Foundation
import BBCore
import BBContent
import BBAnim
@testable import BBSim
@testable import BBPresentation

/// 피격 반응 다양화(docs/11 §9): 결정적 고르기 · 연달아 같은 변형 없음 · 깃발 꺼짐 = 웹 그대로 · 몸무게 배율 · 세기별 길이
@Suite(.serialized) struct HitReactTests {
    static let store = try! ContentStore.bundled()
    static let content = try! SceneContent.bundled()

    static func director(native: Bool, hitReact: Bool = true) throws -> (StageDirector, SimData) {
        let data = NativeMoveStripTests.base.variant(nativeMoves: native)
        let d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK)
        d.hitReact = hitReact
        return (d, data)
    }
    static func config(_ native: Bool) -> SimConfig {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = native; c.playSpeed = 1
        return c
    }

    /// 실제 판(자동 전투)을 연출 감독으로 돌리며 반응 변형을 모은다
    struct Run { var picks: [(ActorID, HitReactVariant)] = []; var meshes: [[Float]] = []; var hits = 0; var states: [String] = [] }
    static func run(native: Bool, hitReact: Bool, seed: UInt32 = 31, frames: Int = 60 * 40, keepMesh: Bool = false) throws -> Run {
        let (d, data) = try director(native: native, hitReact: hitReact)
        let sim = Sim(data: data, seed: seed, config: config(native))
        var R = Run(), lastCount: [ActorID: Int] = [:]
        for k in 0..<frames {
            let ev = sim.step(), s = sim.snapshot
            _ = d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = d.frame(s, dt: 1.0 / 60, now: Double(k) / 60)
            for case let .hit(h) in ev where !h.dead { R.hits += 1; _ = h }
            for a in s.actors { if let st = d.characters.reactState(a.id), st.count != lastCount[a.id] ?? 0, let v = st.last { R.picks.append((a.id, v)); lastCount[a.id] = st.count } }
            if keepMesh && k % 7 == 0 { R.meshes.append(f.mesh) }
            if k % 60 == 0 { R.states.append("\(s.hp)|\(s.score)|\(s.actors.map { "\($0.id):\($0.pose.anim):\($0.x)" }.joined(separator: ","))") }
        }
        return R
    }

    @Test func chooseIsDeterministic() {
        for z in HitZone.allCases { for dr in HitDir.allCases { for t in HitTier.allCases {
            for sd in 0..<40 {
                let s = HitReact.seed(actor: 7, tick: sd * 13, count: sd)
                let a = HitReact.choose(zone: z, dir: dr, tier: t, mass: .normal, last: nil, seed: s), b = HitReact.choose(zone: z, dir: dr, tier: t, mass: .normal, last: nil, seed: s)
                #expect(a.0 == b.0 && a.mirror == b.mirror)
            }
        } } }
        // 같은 판 두 번 → 같은 변형 열
        let a = try! Self.run(native: true, hitReact: true, frames: 60 * 45), b = try! Self.run(native: true, hitReact: true, frames: 60 * 45)
        #expect(a.picks.count >= 5, "실전에서 변형이 걸려야 한다 — \(a.picks.count)")
        #expect(a.picks.map { "\($0.0)\($0.1)" } == b.picks.map { "\($0.0)\($0.1)" })
    }

    @Test func noBackToBackRepeat() {
        // 같은 타격(같은 자리 · 방향 · 세기) 300번 — 같은 인물에게 연달아 같은 변형이 없다 · 후보가 고루 나온다
        for z in HitZone.allCases { for dr in HitDir.allCases { for t in HitTier.allCases {
            for m in [HitMass.normal, HitReact.mass["nv_lineback"]!] {
                var st = HitReactState(), prev: HitReactVariant?, seen = Set<HitReactVariant>()
                for k in 0..<300 {
                    let v = st.trigger(actor: 3, zone: z, dir: dr, tier: t, mass: m, time: Double(k) * 0.35, hold: 0.05)
                    #expect(v != prev, "\(z) \(dr) \(t): \(v) 연달아")
                    prev = v; seen.insert(v)
                }
                #expect(seen.count >= 2)
                if !m.spin { #expect(!seen.contains(.spinAround), "무거운 몸은 빙글 돌지 않는다") }
            }
        } } }
        // 실전: 인물마다 연달아 같은 것 없음
        let r = try! Self.run(native: true, hitReact: true, frames: 60 * 30)
        var last: [ActorID: HitReactVariant] = [:]
        for (id, v) in r.picks { #expect(last[id] != v, "인물 \(id) \(v) 연달아"); last[id] = v }
    }

    @Test func flagOffIsWeb() throws {
        // 깃발 꺼짐(웹 규칙): 반응 변형 스위치를 켜든 끄든 그림이 똑같다(변형이 한 번도 안 걸린다)
        let on = try Self.run(native: false, hitReact: true, frames: 60 * 20, keepMesh: true), off = try Self.run(native: false, hitReact: false, frames: 60 * 20, keepMesh: true)
        #expect(on.hits > 5)
        #expect(on.picks.isEmpty)
        #expect(on.meshes == off.meshes)
        // 깃발 켜짐: 그림만 다르고 규칙(체력 · 점수 · 인물 자리 · 동작)은 같다
        let a = try Self.run(native: true, hitReact: true, frames: 60 * 20, keepMesh: true), b = try Self.run(native: true, hitReact: false, frames: 60 * 20, keepMesh: true)
        #expect(a.states == b.states)
        #expect(!a.picks.isEmpty && b.picks.isEmpty)
        #expect(a.meshes != b.meshes)
    }

    /// 변형 최대 크기(골반 · 몸통 · 회전 합)
    static func peak(_ st: HitReactState, from t0: Double) -> (amp: Double, len: Double) {
        var mx = 0.0, end = t0
        for k in 0..<120 {
            let t = t0 + Double(k) / 60, d = st.delta(time: t)
            let m = abs(d.r) + abs(d.by) + abs(d.t) * 3 + abs(d.spin) * 20 + abs(d.ty) * 2
            mx = max(mx, m); if m > 0.05 { end = t }
        }
        return (mx, end - t0)
    }

    @Test func massScalesAndHeavyIsLonger() {
        let types: [(String, Bool)] = [("nv_newsboy", false), ("punk", false), ("nv_lineback", false)]
        var amps: [Double] = [], lens: [Double] = []
        for (t, boss) in types {
            let m = HitReact.mass(type: t, hero: false, boss: boss)
            var st = HitReactState(); st.trigger(actor: 1, zone: .head, dir: .front, tier: .medium, mass: m, time: 10, hold: 0)
            // 같은 변형끼리 비교(첫 고르기가 같도록 같은 씨앗 — 인물 번호 · 시각 · 수가 같다)
            let p = Self.peak(st, from: 10); amps.append(p.amp); lens.append(p.len)
        }
        #expect(amps[0] > amps[1] && amps[1] > amps[2], "신문팔이 > 보통 > 라인배커 — \(amps)")
        #expect(lens[0] > lens[1] && lens[1] > lens[2], "가벼울수록 길다 — \(lens)")
        #expect(HitReact.mass["nv_newsboy"]!.amp >= 1.3 && HitReact.mass["nv_lineback"]!.amp <= 0.6)
        // 두목은 표에 없어도 무겁다
        #expect(HitReact.mass(type: "unknownBoss", hero: false, boss: true) == HitReact.mass["boss*"]!)
        // 세기: 무거운 타격이 더 길다(같은 자리 · 방향)
        var L = HitReactState(), H = HitReactState()
        L.trigger(actor: 2, zone: .body, dir: .front, tier: .light, mass: .normal, time: 5, hold: 0)
        H.trigger(actor: 2, zone: .body, dir: .front, tier: .heavy, mass: .normal, time: 5, hold: 0)
        #expect(Self.peak(H, from: 5).len > Self.peak(L, from: 5).len + 0.2)
        #expect(H.current?.spec.big == true)
    }

    @Test func readsZoneAndDirection() {
        let T = SimSnapshot.ActorView(id: 9, def: "JW_THUG", pose: ActorPose(anim: "hit", pose: "hh0"), x: 100, y: 220, flip: true, remap: 0, flash: 0, weaponSprite: nil,
                                      hidden: false, isHero: false, isEnemy: true, isPassenger: false, shake: 0)
        func h(_ att: String, _ rk: String, dir: Double = -1) -> HitInfo { var i = HitInfo(attacker: 1, target: 9, damage: 5, reaction: rk); i.attackerAnim = att; i.targetAnim = rk; i.dir = dir; return i }
        // 맞는 쪽이 왼쪽(−1)을 본다 → 밀리는 방향 +1 이면 앞에서 맞음
        let r0 = HitReactMap.read(h("jab", "hit", dir: 1), target: T)
        #expect(r0?.zone == .head && r0?.dir == .front)
        #expect(HitReactMap.read(h("nv_liver", "hitB", dir: 1), target: T)?.zone == .body)
        #expect(HitReactMap.read(h("sweep", "hit", dir: 1), target: T)?.zone == .legs)
        #expect(HitReactMap.read(h("jab", "hit", dir: -1), target: T)?.dir == .back)
        #expect(HitReactMap.read(h("upper", "hit", dir: 1), target: T)?.dir == .below)
        #expect(HitReactMap.read(h("hm_down", "hit", dir: 1), target: T)?.dir == .above)
        #expect(HitReactMap.read(h("jab", "fall", dir: 1), target: T) == nil, "쓰러짐은 웹 그대로")
        var dead = h("jab", "hit", dir: 1); dead.dead = true
        #expect(HitReactMap.read(dead, target: T) == nil)
    }
}
