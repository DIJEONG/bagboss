import Testing
import Foundation
import BBCore
import BBContent
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 해변 도장(docs/12) 눈으로 보기(BB_DUMP=1 일 때만) → tools/js/out/stage/
///   beach_still_{day,dusk,night}.png : 게임 화면 틀(보이는 폭 198) 3배 — 시연 중 한 장
///   beach_pano_{…}.png              : 무대 전체 480×270 2배(층 · 시차)
///   beach_waves.png                 : 같은 자리 0.6초 간격 12칸(파도가 밀려와 빠지고 젖은 모래가 마른다 — 큰 파도 주기 포함)
///   beach_fight.png                 : 시연 띠(오후 · 노을 · 밤 각 6칸 — 발 디딤 모래 · 물보라 · 쓰러짐)
@Suite(.serialized) struct BeachStripTests {
    typealias Strip = NativeMoveStripTests
    static let vw = 198

    final class Run {
        let R: Strip.Rig, sim: Sim
        var k = 0
        init(_ bg: String) throws {
            R = try Strip.Rig(native: true); R.d.camera.visibleWidth = Double(BeachStripTests.vw)
            var c = SimConfig(); c.nativeMoves = true; c.skipTalks = true; c.playSpeed = 1; c.mode = .dojo
            sim = Sim(data: Strip.base.variant(nativeMoves: true), seed: 5, config: c)
            sim.apply(.dojo(.background(bg)))
            for _ in 0..<30 { tick() }
        }
        @discardableResult func tick(_ intents: [SimIntent] = []) -> (SimSnapshot, StageFrame) {
            let ev = sim.step(intents), s = sim.snapshot
            _ = R.d.apply(ev, snapshot: s, now: Double(k) / 60)
            let f = R.d.frame(s, dt: 1.0 / 60, now: Double(k) / 60); k += 1
            return (s, f)
        }
    }

    static func names(_ bg: String) -> String { bg == "beach" ? "day" : bg == "beach_dusk" ? "dusk" : "night" }

    @Test(.enabled(if: Strip.dump)) func stills() throws {
        for bg in ["beach", "beach_dusk", "beach_night"] {
            let r = try Run(bg)
            r.sim.apply(.dojo(.combo(0)))
            var last: (SimSnapshot, StageFrame)?
            for i in 0..<(60 * 6) { last = r.tick(); if i == 60 * 5 + 30 { break } }
            let (s, f) = try #require(last)
            let px = try SnowStripTests.render(r.R, s, f)
            let cx = Int(f.view.cameraX.rounded()), n = Self.names(bg)
            try NativeGuardStripTests.sheet([SnowStripTests.crop(px, x0: cx, y0: 0, w: Self.vw, h: 270)], cw: Self.vw, ch: 270, cols: 1, name: "../stage/beach_still_" + n, scale: 3)
            try NativeGuardStripTests.sheet([SnowStripTests.crop(px, x0: 0, y0: 0, w: 480, h: 270)], cw: 480, ch: 270, cols: 1, name: "../stage/beach_pano_" + n, scale: 2)
            print("[beach \(n)] 사각형 \(BeachArt.shared.rectCount(BeachTime.of(bg)!)) · 배경 정점 \(f.backMesh.count / 10) · 앞 정점 \(f.mesh.count / 10) · camX \(cx)")
        }
    }

    @Test(.enabled(if: Strip.dump)) func waves() throws {
        let r = try Run("beach_dusk")
        var shots: [Strip.Shot] = []
        for i in 0..<(60 * 22) {
            let (s, f) = r.tick()
            guard i >= 60 * 6, (i - 60 * 6) % 36 == 0, shots.count < 24 else { continue }
            let px = try SnowStripTests.render(r.R, s, f)
            var sh = SnowStripTests.crop(px, x0: Int(f.view.cameraX.rounded()), y0: 150, w: Self.vw, h: 100)
            sh.band = r.R.d.beach.phase < BeachFx.uprush ? (90, 170, 255) : (200, 200, 200)
            shots.append(sh)
        }
        try NativeGuardStripTests.sheet(shots, cw: Self.vw, ch: 100, cols: 4, name: "../stage/beach_waves", scale: 2)
    }

    @Test(.enabled(if: Strip.dump)) func fight() throws {
        var shots: [Strip.Shot] = []
        for bg in ["beach", "beach_dusk", "beach_night"] {
            let r = try Run(bg)
            r.sim.apply(.dojo(.combo(1)))
            for i in 0..<(60 * 9) {
                let (s, f) = r.tick()
                guard i >= 60 * 3, i % 50 == 0, shots.count % 6 != 0 || i > 60 * 3 || true else { continue }
                if shots.count >= 6 * (["beach", "beach_dusk", "beach_night"].firstIndex(of: bg)! + 1) { break }
                guard let H = s.actors.first(where: { $0.isHero }) else { continue }
                let px = try SnowStripTests.render(r.R, s, f)
                let x0 = max(Int(f.view.cameraX), min(Int(f.view.cameraX + f.view.visibleWidth) - 120, Int(H.x) - 60))
                shots.append(SnowStripTests.crop(px, x0: x0, y0: Int(H.y) - 96, w: 120, h: 112))
            }
        }
        try NativeGuardStripTests.sheet(shots, cw: 120, ch: 112, cols: 6, name: "../stage/beach_fight", scale: 3)
    }

    /// 바다 볼거리(바다 영역 2배): 위 줄 = 방파제 물보라(오후 · 0.1초 간격) · 가운데 = 돌고래(오후) · 아래 = 밤 등대 빛줄기(0.5초 간격)
    @Test(.enabled(if: Strip.dump)) func seaLife() throws {
        var shots: [Strip.Shot] = []
        func grab(_ r: Run, _ f: StageFrame, _ s: SimSnapshot, band: (UInt8, UInt8, UInt8)) throws {
            let px = try SnowStripTests.render(r.R, s, f)
            var sh = SnowStripTests.crop(px, x0: Int(f.view.cameraX.rounded()), y0: 100, w: Self.vw, h: 110); sh.band = band; shots.append(sh)
        }
        let r = try Run("beach")
        let k0 = Int(ceil(r.R.d.beach.t / BeachFx.period)) + 1, tSpray = (Double(k0) + 0.75) * BeachFx.period - 0.1
        let tDol = BeachFx.dolphinStart(Int(floor((r.R.d.beach.t + 2) / 28)) + 1) + 0.3
        var sprayN = 0, dolN = 0
        while dolN < 6 {
            let (s, f) = r.tick(); let t = r.R.d.beach.t
            if sprayN < 6 && t >= tSpray + Double(sprayN) * 0.12 { sprayN += 1; try grab(r, f, s, band: (255, 255, 255)) }
            if sprayN >= 6 && t >= tDol + Double(dolN) * 0.3 { dolN += 1; try grab(r, f, s, band: (90, 170, 255)) }
            if t > tDol + 10 { break }
        }
        let rn = try Run("beach_night")
        for i in 0..<(60 * 4) { let (s, f) = rn.tick(); if i % 30 == 0 && i > 0 { try grab(rn, f, s, band: (255, 200, 90)) } }
        // 가까이(4배): 물보라 · 돌고래 자리만
        let rz = try Run("beach")
        let k1 = Int(ceil(rz.R.d.beach.t / BeachFx.period)) + 1, ts = (Double(k1) + 0.75) * BeachFx.period
        let td = BeachFx.dolphinStart(Int(floor((rz.R.d.beach.t + 2) / 28)) + 1)
        var zs: [Strip.Shot] = [], zi = 0, zd = 0
        while zd < 6 {
            let (s, f) = rz.tick(); let t = rz.R.d.beach.t
            if zi < 6 && t >= ts + Double(zi) * 0.15 { zi += 1; let px = try SnowStripTests.render(rz.R, s, f); let cx = Int(BeachFx.jettyX(0.83, camX: f.view.cameraX)); zs.append(SnowStripTests.crop(px, x0: cx - 30, y0: 150, w: 60, h: 45)) }
            if zi >= 6 && t >= td + 0.2 + Double(zd) * 0.35 { zd += 1; let px = try SnowStripTests.render(rz.R, s, f); zs.append(SnowStripTests.crop(px, x0: Int(f.view.cameraX), y0: 150, w: 198, h: 40)) }
            if t > td + 10 { break }
        }
        try NativeGuardStripTests.sheet(Array(zs.prefix(6)), cw: 60, ch: 45, cols: 6, name: "../stage/beach_spray_zoom", scale: 4)
        try NativeGuardStripTests.sheet(Array(zs.dropFirst(6)), cw: 198, ch: 40, cols: 2, name: "../stage/beach_dolphin_zoom", scale: 3)
        print("[바다 볼거리] 물보라 \(sprayN) · 돌고래 \(dolN) · 칸 \(shots.count)")
        try NativeGuardStripTests.sheet(shots, cw: Self.vw, ch: 110, cols: 6, name: "../stage/beach_sealife", scale: 2)
    }
}
