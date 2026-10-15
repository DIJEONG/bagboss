import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 인물 가독성(배경에 맞춘 테 · 발밑 접지 그림자) 눈으로 보기(BB_DUMP=1) → tools/js/out/stage/readability{_태그}.png
///   칸: 눈 승강장 · 밤 해변 · 무도장 · 노을 해변 · 오후 해변 · 건널목 — 시연 중 같은 순간(인물 둘레 120×100 · 3배)
///   BB_TAG=before 처럼 태그를 주면 이름 뒤에 붙인다(전 · 후 비교)
@Suite(.serialized) struct ReadabilityStripTests {
    typealias Strip = NativeMoveStripTests

    static func shot(_ bg: String) throws -> Strip.Shot {
        let R = try Strip.Rig(native: true); R.d.camera.visibleWidth = 198
        var c = SimConfig(); c.nativeMoves = true; c.nativeSnow = true; c.skipTalks = true; c.playSpeed = 1; c.mode = .dojo
        let sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 5, config: c)
        if bg != "dojo" { sim.apply(.dojo(.background(bg))) }
        sim.apply(.dojo(.combo(1)))
        var last: (SimSnapshot, StageFrame)?
        for k in 0..<(60 * 4 + 40) { let ev = sim.step(); _ = R.d.apply(ev, snapshot: sim.snapshot, now: Double(k) / 60); last = (sim.snapshot, R.d.frame(sim.snapshot, dt: 1.0 / 60, now: Double(k) / 60)) }
        let (s, f) = last!
        let px = try SnowStripTests.render(R, s, f)
        let F = s.actors.filter { !$0.hidden && ($0.isHero || $0.isEnemy) }
        let cx = F.map(\.x).reduce(0, +) / Double(max(1, F.count)), gy = F.map(\.y).max() ?? 222
        var sh = SnowStripTests.crop(px, x0: Int(cx) - 60, y0: Int(gy) - 86, w: 120, h: 100)
        sh.band = bg.hasPrefix("beach") ? (90, 170, 255) : bg == "snow" ? (220, 230, 255) : (190, 130, 70)
        return sh
    }

    @Test(.enabled(if: Strip.dump)) func readability() throws {
        let tag = ProcessInfo.processInfo.environment["BB_TAG"].map { "_" + $0 } ?? ""
        let shots = try ["snow", "beach_night", "dojo", "beach_dusk", "beach", "cross"].map(Self.shot)
        try NativeGuardStripTests.sheet(shots, cw: 120, ch: 100, cols: 3, name: "../stage/readability" + tag, scale: 3)
    }
}
