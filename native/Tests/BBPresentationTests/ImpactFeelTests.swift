import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation

/// 타격감 묶음(docs/11) 표현 규칙: 펀치인 쿨 0.6초 · 받아치기/치명만 · 기울기 부호 결정적 · KO 카메라 시간표 · 흔들림 줄이기 최소판
@Suite struct ImpactFeelTests {
    static let data = NativeMoveStripTests.base.variant(nativeMoves: true)

    /// 적이 있는 지하철 스냅숏
    static func snap() -> SimSnapshot {
        var c = SimConfig(); c.skipTalks = true; c.autoAdvance = true; c.nativeMoves = true; c.playSpeed = 1
        let sim = Sim(data: data, seed: 7, config: c)
        for _ in 0..<(60 * 6) { sim.step(); if sim.snapshot.actors.contains(where: { $0.isEnemy && $0.hp > 0 }) { break } }
        for _ in 0..<30 { sim.step() }
        return sim.snapshot
    }
    static func hit(_ s: SimSnapshot, crit: Bool = false, counter: Bool = false, dmg: Int = 10) -> SimEvent {
        let H = s.actors.first { $0.isHero }!, T = s.actors.first { $0.isEnemy && $0.hp > 0 }!
        var h = HitInfo(attacker: H.id, target: T.id, damage: dmg, reaction: "hit")
        h.crit = crit; h.counter = counter; h.attackerIsHero = true; h.dir = 1; h.attackerAnim = "jab"
        return .hit(h)
    }

    @Test func punchCooldownAndOnlyCounters() {
        let s = Self.snap()
        var F = ImpactFeel(), punches = 0
        func step(_ ev: [SimEvent]) { let had = F.punch?.t; F.apply(ev, s, calm: false, noFlash: false); if F.punch != nil && F.punch?.t != had { punches += 1 }; F.advance(dt: 1.0 / 60, gdt: 1.0 / 60) }
        for k in 0..<120 {   // 2초 — 5칸(0.083초)마다 받아치기 타격
            step(k % 5 == 0 ? [Self.hit(s, counter: true)] : [])
        }
        #expect(punches == 3, "2초 동안 0.6초 쿨이면 3번(0 · 0.67 · 1.33) — \(punches)")
        var G = ImpactFeel()
        for k in 0..<120 { G.apply(k % 6 == 0 ? [Self.hit(s)] : [], s, calm: false, noFlash: false); #expect(G.punch == nil && G.squash.isEmpty); G.advance(dt: 1.0 / 60, gdt: 1.0 / 60) }
    }

    @Test func rollDeterministicAndEases() {
        let s = Self.snap()
        func roll(_ seedHit: SimEvent) -> [Double] {
            var F = ImpactFeel(); F.apply([seedHit], s, calm: false, noFlash: false)
            var out: [Double] = []
            for _ in 0..<20 { var v = StageView(visibleWidth: 222, cameraX: 100); F.shape(&v, s, motion: 1); out.append(v.roll); F.advance(dt: 1.0 / 60, gdt: 1.0 / 60) }
            return out
        }
        let a = roll(Self.hit(s, crit: true)), b = roll(Self.hit(s, crit: true))
        #expect(a == b)
        let peak = a.map(abs).max() ?? 0
        #expect(peak > 2 * .pi / 180 && peak <= 3 * .pi / 180, "기울기 최대 \(peak * 180 / .pi)°")
        #expect(abs(a.last!) < 0.002, "끝에 돌아옴")
        // 흔들림 줄이기: 기울기 없음 · 줌은 0.3배
        var F = ImpactFeel(); F.apply([Self.hit(s, crit: true)], s, calm: true, noFlash: false); F.advance(dt: 0.03, gdt: 0.03)
        var v = StageView(visibleWidth: 222, cameraX: 100); F.shape(&v, s, motion: 0.3)
        #expect(v.roll == 0 && v.zoom > 1 && v.zoom < 1.03)
    }

    @Test func koCameraTimeline() {
        let s = Self.snap()
        let T = s.actors.first { $0.isEnemy && $0.hp > 0 }!
        let K = KOFinisher(target: T.id, x: T.x, y: T.y, dir: 1, boss: false, slow: 0.4, freezeFrames: 2)
        var F = ImpactFeel(); F.apply([.koFinisher(K)], s, calm: false, noFlash: false)
        var zs: [Double] = [], hush = -1.0
        for k in 0..<Int(ImpactFeel.koEnd * 60 + 10) {
            var v = StageView(visibleWidth: 222, cameraX: 100); F.shape(&v, s, motion: 1); zs.append(v.zoom)
            if F.takeHush() { hush = Double(k) / 60 }
            F.advance(dt: 1.0 / 60, gdt: 1.0 / 60)
        }
        #expect(abs(zs[Int(0.3 * 60)] - 1.10) < 0.01, "슬로 동안 밀고 들어감 \(zs[18])")
        #expect(abs(zs[Int(1.0 * 60)] - 1.03) < 0.005, "빼서 머묾 \(zs[60])")
        #expect(abs(zs.last! - 1) < 1e-9 && F.ko == nil, "제자리")
        #expect(abs(hush - 0.4) < 0.03, "환경음 낮춤 \(hush)")
        #expect(ImpactFeel.koEnd <= 1.9)
        // 조용한 한 박자 동안 타격음은 끊긴다
        var G = ImpactFeel(); G.apply([.koFinisher(K)], s, calm: false, noFlash: false); G.advance(dt: 0.6, gdt: 0.6)
        #expect(G.muted(.hitK(kind: "big", crit: false, combo: 0)) && !G.muted(.clear))
        // 흔들림 줄이기: 카메라는 안 움직인다(최소판 — 슬로 · 정지 · 소리 낮춤만)
        var C = ImpactFeel(); C.apply([.koFinisher(K)], s, calm: true, noFlash: false); C.advance(dt: 0.3, gdt: 0.3)
        var v = StageView(visibleWidth: 222, cameraX: 100); C.shape(&v, s, motion: 0.3)
        #expect(v.zoom == 1 && v.cameraX == 100)
    }

    @Test func squashSpringsBack() {
        #expect(ImpactFeel.squashAmt(0) == 1)
        #expect(ImpactFeel.squashAmt(1.0 / 60) == 1)
        #expect(ImpactFeel.squashAmt(3.0 / 60) < 0)          // 튕겨 넘어감
        #expect(ImpactFeel.squashAmt(5.0 / 60) == 0)
    }
}
