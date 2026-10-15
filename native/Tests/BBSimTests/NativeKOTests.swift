import Testing
import Foundation
@testable import BBSim
import BBContent

/// KO 마무리(docs/11 §1 — World+NativeKO): 웨이브마다 한 번 · 마지막 적이나 두목만 · 0.25배 슬로 → 정지 · 결정적 · 깃발 꺼짐이면 없다
@Suite struct NativeKOTests {
    struct Fire { var tick: Int; var K: KOFinisher; var foesLeft: Int; var segment: Int }

    /// 지하철 판을 돌리며 KO 마무리를 모은다(20틱마다 좌우 탭 — 다른 네이티브 테스트와 같은 입력)
    static func run(_ data: SimData, _ cfg: SimConfig, seed: UInt32, ticks: Int, low: Bool = true) -> (fires: [Fire], sim: Sim, gameTimes: [Double], freezes: [Int]) {
        let sim = Sim(data: data, seed: seed, config: cfg)
        var fires: [Fire] = [], seg = 0, gts: [Double] = [], frz: [Int] = []
        for k in 0..<ticks {
            if low && k % 90 == 0 { sim.debugLowFoes(8) }   // 웨이브를 빨리 끝낸다(규칙 경로 그대로)
            let ev = sim.step(k % 20 == 0 ? [SimIntent.tap(side: k % 60 < 30 ? 1 : -1, at: sim.clock)] : [])
            var fresh = Set<ActorID>()   // 같은 틱에 마무리 뒤 들어온 새 웨이브(그 적은 셈에서 뺀다)
            for e in ev {
                if case .waveSpawned = e { seg += 1; if !fires.isEmpty && fires.last!.tick == k { fresh = Set(sim.w.foes().map(\.id)) } }
                if case .koFinisher(let K) = e { fires.append(Fire(tick: k, K: K, foesLeft: 0, segment: seg)) }
            }
            if let f = fires.last, f.tick == k { fires[fires.count - 1].foesLeft = sim.w.foes().filter { !fresh.contains($0.id) }.count }
            gts.append(sim.w.gameTime); frz.append(sim.w.freeze)
        }
        return (fires, sim, gts, frz)
    }

    @Test func oncePerWaveOnlyLast() {
        let r = Self.run(NativeGuardTests.on, NativeGuardTests.config(stage: 0), seed: 31, ticks: 60 * 150)
        #expect(r.fires.count >= 3, "KO 마무리 \(r.fires.count)번")
        for f in r.fires { #expect(f.foesLeft == 0 || f.K.boss, "남은 적 \(f.foesLeft) · 두목 \(f.K.boss)") }
        let per = Dictionary(grouping: r.fires, by: \.segment)
        for (s, l) in per { #expect(l.count == 1, "웨이브 구간 \(s): \(l.count)번") }
        print("[ko] \(r.fires.count)번 · 틱 \(r.fires.map(\.tick))")
    }

    @Test func slowThenFreeze() {
        let cfg = NativeGuardTests.config(stage: 0)
        let r = Self.run(NativeGuardTests.on, cfg, seed: 31, ticks: 60 * 60)
        guard let f = r.fires.first else { Issue.record("KO 마무리 없음"); return }
        // 슬로 0.4초(24틱): 틱당 게임 시간 = 1/60 × 배속 × 0.25(필살기 · 가방 슬로 없음)
        let ps = cfg.playSpeed
        let d = (f.tick + 1..<f.tick + 23).map { r.gameTimes[$0] - r.gameTimes[$0 - 1] }
        for x in d { #expect(abs(x - ps * 0.25 / 60) < 1e-6, "슬로 틱 \(x)") }
        // 그 뒤 정지 칸(애니 2칸) — 슬로가 끝나는 틱 둘레에서 freeze > 0
        let after = r.freezes[(f.tick + 23)...(f.tick + 28)]
        #expect(after.contains { $0 > 0 }, "정지 \(Array(after))")
        // 늘어난 게임 시간 ≤ 1.2초(실제로는 약 0.4초)
        let slowLoss = 0.4 * (1 - 0.25)
        #expect(slowLoss + Double(World.nvKOFreeze) / 20 / ps <= 1.2)
    }

    @Test func deterministic() {
        let a = Self.run(NativeGuardTests.on, NativeGuardTests.config(stage: 1), seed: 9, ticks: 60 * 80)
        let b = Self.run(NativeGuardTests.on, NativeGuardTests.config(stage: 1), seed: 9, ticks: 60 * 80)
        #expect(a.fires.map(\.tick) == b.fires.map(\.tick))
        #expect(a.fires.map(\.K) == b.fires.map(\.K))
        #expect(a.gameTimes == b.gameTimes)
        #expect(a.sim.w.kills == b.sim.w.kills && a.sim.w.score == b.sim.w.score && a.sim.w.hp == b.sim.w.hp)
    }

    @Test func flagOffNever() {
        let r = Self.run(SimRunTests.data, SimRunTests.harnessConfig(stage: 0), seed: 31, ticks: 60 * 60, low: false)
        #expect(r.fires.isEmpty)
    }

    @Test func dojoOnlyInDemo() {
        var c = SimConfig(); c.mode = .dojo; c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1
        let sim = Sim(data: NativeGuardTests.on, seed: 5, config: c)
        var n = 0
        for i in 0..<(60 * 30) {
            if i % 120 == 10 { sim.apply(.dojo(.hero("kick", combo: nil))); for a in sim.w.foes() { a.e?.hp = 1 } }
            for e in sim.step() { if case .koFinisher = e { n += 1 } }
        }
        #expect(n == 0, "무도장 시연 \(n)")
    }
}
