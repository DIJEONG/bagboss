import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation

/// 해변 도장(docs/12) 움직이는 층 규칙 점검 — 파도 · 젖은 모래 · 튀김 · 연출기 연결(그림 없이)
@Suite struct BeachFxTests {
    @Test func timeFromBackground() {
        #expect(BeachTime.of("beach") == .day && BeachTime.of("beach_dusk") == .dusk && BeachTime.of("beach_night") == .night)
        #expect(BeachTime.of("snow") == nil && BeachTime.of(nil) == nil)
    }

    /// 파도: 같은 시간 = 같은 물 끝(결정적) · 잔물결은 물가 뒤 · 큰 파도는 싸움 줄(발 214~230)까지 온다 · 잠잠할 땐 물가
    @Test func wavesReachFightLineSometimes() {
        var maxNormal = 0.0, maxAll = 0.0, bigCycles = 0
        for k in 0..<12 {
            let big = BeachFx.swell(k) > 20
            if big { bigCycles += 1 }
            for i in 0..<72 {
                let t = (Double(k) + Double(i) / 72) * BeachFx.period
                for x in stride(from: 0, to: BeachGeo.W, by: 7) {
                    let e = BeachFx.edgeAt(x, t: t)
                    #expect(e == BeachFx.edgeAt(x, t: t))
                    maxAll = max(maxAll, e)
                    if !big && BeachFx.swell(k - 1) <= 20 { maxNormal = max(maxNormal, e) }
                }
            }
        }
        print("[파도] 큰 파도 주기 \(bigCycles)/12 · 잔파도 최대 y \(Int(maxNormal)) · 전체 최대 y \(Int(maxAll))")
        #expect(bigCycles >= 3 && bigCycles <= 7)
        #expect(maxNormal < 218 && maxAll >= 222)
        #expect(BeachFx.run(0.9) == 0 && BeachFx.run(BeachFx.uprush) > 0.99)
    }

    /// 젖은 모래: 물이 지나간 자리까지 젖었다가 마르며 물가로 물러난다 · 자국은 물이 덮으면 씻긴다
    @Test func wetSandDriesAndMarksWash() {
        var B = BeachFx(); B.reset(.day)
        let k = (0..<20).first { BeachFx.swell($0) > 20 }!
        B.marks.append(.init(x: 240, y: 214, w: 3, age: 0, wet: false, kind: .step))
        let t0 = Double(k) * BeachFx.period
        while B.t < t0 + BeachFx.period * BeachFx.uprush + 0.1 { B.advance(1.0 / 30) }
        let wet0 = B.wetTop[240]
        #expect(wet0 > Double(BeachGeo.shore) + 12)
        #expect(B.marks.isEmpty)   // 큰 파도가 덮어 씻겼다
        while B.t < t0 + BeachFx.period * 0.95 { B.advance(1.0 / 30) }
        #expect(B.wetTop[240] < wet0 - 1)
    }

    /// 튀김: 물속 = 물방울 · 물보라 · 동심원 / 마른 모래 = 모래 덩이 · 가루
    @Test func splashInWaterSandOnDry() {
        var B = BeachFx(); B.reset(.dusk)
        B.burst(240, 230, power: 1)
        #expect(B.parts.contains { $0.kind == .sand } && B.parts.contains { $0.kind == .dust } && B.rings.isEmpty)
        B = BeachFx(); B.reset(.dusk)
        for x in 0..<BeachGeo.W { B.edge[x] = 226 }
        B.burst(240, 220, power: 1)
        #expect(B.parts.contains { $0.kind == .drop } && !B.rings.isEmpty && !B.parts.contains { $0.kind == .sand })
    }

    /// 연출기: 무도장 배경 해변이면 켜지고(정지 그림 + 바다 + 물가 정점 · 파도 소리) · 다른 배경으로 바꾸면 꺼진다 · 시간대 바뀌면 다시 만든다
    @Test func directorWiring() throws {
        let R = try NativeMoveStripTests.Rig(native: true); R.d.camera.visibleWidth = 198
        var c = SimConfig(); c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1; c.mode = .dojo
        let sim = Sim(data: NativeMoveStripTests.base.variant(nativeMoves: true), seed: 5, config: c)
        sim.apply(.dojo(.background("beach_night")))
        var f: StageFrame?, surfMax = 0.0
        var spent = 0.0
        for k in 0..<(60 * 9) {
            let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60)
            let c0 = CFAbsoluteTimeGetCurrent(); f = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60); spent += CFAbsoluteTimeGetCurrent() - c0
            surfMax = max(surfMax, R.d.surf)
        }
        print(String(format: "[해변 연출] frame %.2f ms/프레임(이 빌드 설정)", spent / 540 * 1000))
        #expect(R.d.beach.on && R.d.beach.time == .night)
        #expect((f?.backMesh.count ?? 0) > 1000 && f?.depth?.wetMats?.count == 2)
        #expect(surfMax > 0.5 && surfMax <= 1)
        sim.apply(.dojo(.background("beach")))
        for k in 0..<5 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: 10 + Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: 10 + Double(k) / 60) }
        #expect(R.d.beach.time == .day)
        sim.apply(.dojo(.background("dojo")))
        for k in 0..<5 { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: 11 + Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: 11 + Double(k) / 60) }
        #expect(!R.d.beach.on && R.d.surf == 0)
    }

    /// 소리: 오후 해변 시연 20초 — 갈매기 · 모래 발소리(또는 첨벙)가 나고, 밤엔 갈매기가 없다
    @Test func beachSounds() throws {
        func run(_ bg: String) throws -> [SoundCue] {
            let R = try NativeMoveStripTests.Rig(native: true); R.d.camera.visibleWidth = 198
            var c = SimConfig(); c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1; c.mode = .dojo
            let sim = Sim(data: NativeMoveStripTests.base.variant(nativeMoves: true), seed: 5, config: c)
            sim.apply(.dojo(.background(bg))); sim.apply(.dojo(.combo(1)))
            var cues: [SoundCue] = []
            for k in 0..<(60 * 20) { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); _ = R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60); cues += R.d.takeSnowCues() }
            return cues
        }
        let day = try run("beach"), night = try run("beach_night")
        func n(_ a: [SoundCue], _ f: (SoundCue) -> Bool) -> Int { a.filter(f).count }
        let gull: (SoundCue) -> Bool = { if case .gull = $0 { return true }; return false }
        let feet: (SoundCue) -> Bool = { switch $0 { case .sandStep, .splash, .sandSkid, .sandBurst: return true; default: return false } }
        print("[해변 소리] 오후 갈매기 \(n(day, gull)) · 발 · 물 \(n(day, feet)) / 밤 갈매기 \(n(night, gull)) · 발 · 물 \(n(night, feet))")
        #expect(n(day, gull) >= 1 && n(night, gull) == 0)
        #expect(n(day, feet) > 0 && n(night, feet) > 0)
    }
}
