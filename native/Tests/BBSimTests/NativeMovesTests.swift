import Testing
import Foundation
@testable import BBSim
import BBContent
import BBAnim

/// 네이티브 동작 개편(SimConfig.nativeMoves) 검사 — 깃발이 꺼진 쪽은 기존 락스텝 · 분포 테스트가 지킨다.
///  ① 결정성 ② 이동 판단(깜빡임 없음 · 미끄러져 서기 · 스텝 인) ③ 막차 러시(박자 · 실어 나르기 · 마무리) ④ 새 기술 발동 · 콤보 경로
///  ⑤ 밸런스: 같은 씨앗으로 깃발 끔/켬 판을 돌려 생존 · 처치 · 피해 분포를 비교(BB_NV_STATS=1 이면 표본을 늘리고 tools/js/out/moves/balance.md 에 표)
@Suite struct NativeMovesTests {
    static let data = SimRunTests.data
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func cfg(_ on: Bool, stage: Int = 0, kit: String = "basic", bag: [BagItem]? = nil) -> SimConfig {
        var c = SimRunTests.harnessConfig(stage: stage, kit: kit); c.nativeMoves = on; c.customBag = bag; c.trackDrawnPose = true
        return c
    }

    struct Res { var t = 0.0, alive = true, kills = 0.0, dealt = 0.0, taken = 0.0, score = 0.0, ci = 0.0, maxCombo = 0.0, spc = 0.0 }
    static func run(_ on: Bool, seed: UInt32, seconds: Double, stage: Int = 0, kit: String = "basic", autoSpecial: Bool = true, bag: [BagItem]? = nil) -> Res {
        var c = cfg(on, stage: stage, kit: kit, bag: bag); c.autoSpecial = autoSpecial
        let sim = Sim(data: data, seed: seed, config: c)
        var r = Res(), n = 0.0
        for _ in 0..<Int(seconds * 60) {
            for e in sim.step() { if case .specialUsed = e { n += 1 } }
            r.t += 1.0 / 60
            if sim.state == "over" || sim.state == "end" { break }
        }
        let s = sim.snapshot
        r.alive = s.hp > 0; r.kills = Double(s.kills); r.dealt = s.stats.dealt; r.taken = s.stats.taken; r.score = Double(s.score); r.ci = Double(s.car)
        r.maxCombo = Double(s.stats.maxCombo); r.spc = n
        return r
    }

    @Test func deterministic() {
        func run() -> [String] {
            let sim = Sim(data: Self.data, seed: 909, config: Self.cfg(true))
            var out: [String] = []
            for _ in 0..<(45 * 60) { for e in sim.step() { out.append(String(describing: e)) } }
            out.append("\(sim.snapshot.score)|\(sim.snapshot.kills)|\(sim.snapshot.hp)")
            return out
        }
        #expect(run() == run())
    }

    @Test func flagOffUsesBaseContent() {
        let off = Sim(data: Self.data, seed: 1, config: Self.cfg(false)), on = Sim(data: Self.data, seed: 1, config: Self.cfg(true))
        #expect(off.w.data === Self.data && !off.w.data.nativeMoves)
        #expect(on.w.data.nativeMoves && on.w.data.game.items["nv_cork"] != nil && off.w.data.game.items["nv_cork"] == nil)
        #expect(Self.data.variant(nativeMoves: true) === on.w.data)   // 한 번만 만든다
    }

    // MARK: 이동 판단

    /// 깃발을 켠 판에서 이동 상태 전환을 센다: 질주↔걷기 깜빡임 없음 · 미끄러져 서기 · 스텝 인 · 출발 칸이 실제로 나온다
    @Test func movementDecisionsNoFlicker() {
        var go = 0, skid = 0, step = 0, sprintTicks = 0, walkTicks = 0, flicker = 0, heroSwitches = 0
        for seed in [21, 22, 23, 24] as [UInt32] {
            let sim = Sim(data: Self.data, seed: seed, config: Self.cfg(true))
            var lastMode = 0, lastChange = -9.0, prevAnim = ""
            for _ in 0..<(90 * 60) {
                sim.step()
                let w = sim.w, H = w.hero!, m = H.nvm
                if H.anim != prevAnim { if H.anim == "nv_go" { go += 1 }; if H.anim == "nv_skid" { skid += 1 }; if H.anim == "nv_step" { step += 1 } }
                prevAnim = H.anim
                if m.mode == 2 { sprintTicks += 1 } else if m.mode == 1 { walkTicks += 1 }
                if m.mode != lastMode {
                    // 질주 ↔ 걷기가 0.2초 안에 되돌아가면 깜빡임
                    if (m.mode == 1 && lastMode == 2) || (m.mode == 2 && lastMode == 1) { if w.gameTime - lastChange < 0.2 { flicker += 1 } }
                    lastMode = m.mode; lastChange = w.gameTime
                }
                if w.state == "over" { break }
            }
            heroSwitches += sim.w.hero.nvm.switches
        }
        print("[move] 출발 \(go) · 미끄러짐 \(skid) · 스텝 인 \(step) · 질주 틱 \(sprintTicks) · 걷기 틱 \(walkTicks) · 깜빡임 \(flicker) · 전환 \(heroSwitches)")
        #expect(go > 0 && skid > 0 && step > 0)
        #expect(walkTicks > 0 && sprintTicks > 0)
        #expect(flicker == 0)
    }

    /// 판단 단위: 같은 거리라도 '이유'가 없으면 걷고, 있으면 달린다 · 히스테리시스(들어가기 70 · 나오기 26)
    @Test func sprintNeedsReasonAndHysteresis() {
        let sim = Sim(data: Self.data, seed: 3, config: Self.cfg(true))
        let w = sim.w, H = w.hero!
        w.croute = nil; w.bossBreak = nil
        H.x = 100; H.anim = "idle"; H.nvm = NvMove()
        // 이유 없음(웨이브 초반 · 시간 넉넉) → 걷기
        let reason0 = w.nvSprintReason(H, 200, false)
        w.nvApproach(H, 200, w.heroSpd(), 1.0 / 60, w.heroSpd() * 3.4, false)
        if !reason0 { #expect(H.nvm.mode == 1, "이유가 없으면 걷는다") }
        // 쫓기 이유 → 질주(출발 칸)
        H.nvm = NvMove(); H.anim = "idle"
        w.nvApproach(H, 200, w.heroSpd(), 1.0 / 60, w.heroSpd() * 3.4, true)
        #expect(H.nvm.mode == 2 && H.anim == "nv_go")
        // 질주 중엔 들어가기 문턱(70)보다 가까워도(40) 유지
        H.anim = "walk"; H.nvm.v = 60; H.x = 160
        w.nvApproach(H, 200, w.heroSpd(), 1.0 / 60, w.heroSpd() * 3.4, false)
        #expect(H.nvm.mode == 2, "히스테리시스: 40px 에선 아직 질주")
        // 최고 속도로 제동 거리 안에 들어오면 미끄러져 선다
        H.anim = "walk"; H.nvm.v = 156; H.x = 192
        w.nvApproach(H, 200, w.heroSpd(), 1.0 / 60, w.heroSpd() * 3.4, false)
        #expect(H.nvm.mode == 3 && H.anim == "nv_skid")
        for _ in 0..<30 { w.nvMoveTick(1.0 / 60) }
        #expect(H.nvm.mode == 0 && H.anim != "nv_skid" && abs(H.x - 200) < 12, "미끄러져 \(H.x) 에 섰다")
        // 작은 틈 → 스텝 인
        H.nvm = NvMove(); H.anim = "idle"; H.x = 180
        w.nvApproach(H, 200, w.heroSpd(), 1.0 / 60, w.heroSpd() * 3.4, false)
        #expect(H.anim == "nv_step" && H.dash > 0)
    }

    // MARK: 새 기술

    @Test func newSkillsFireAndRoute() {
        // 플리커 → 주먹 콤보 → 코크스크루: '피카부 러시' 도감 경로
        let bagA = [BagItem(id: "nv_flick", uid: 1, x: 0, y: 0), BagItem(id: "punch", uid: 2, x: 2, y: 0), BagItem(id: "nv_cork", uid: 3, x: 3, y: 0),
                    BagItem(id: "nv_roll", uid: 4, x: 0, y: 2), BagItem(id: "duck", uid: 5, x: 5, y: 3)]
        let bagB = [BagItem(id: "nv_liver", uid: 1, x: 0, y: 0), BagItem(id: "punch", uid: 2, x: 2, y: 0), BagItem(id: "upper", uid: 3, x: 3, y: 0),
                    BagItem(id: "duck", uid: 4, x: 5, y: 3)]
        let native = Self.data.variant(nativeMoves: true)
        #expect(native.catalog.rules.routes(bagA).contains { $0.name == "피카부 러시" }, "\(native.catalog.rules.routes(bagA).map(\.name))")
        #expect(native.catalog.rules.routes(bagB).contains { $0.name == "간 찌르고 퍼 올리기" }, "\(native.catalog.rules.routes(bagB).map(\.name))")
        var used: [String: Int] = [:], hitsBy: [String: Int] = [:], routes: Set<String> = [], crumple = 0, blast = 0, slips = 0
        for (seed, bag) in [(41, bagA), (42, bagB), (43, bagA), (44, bagB)] as [(UInt32, [BagItem])] {
            let sim = Sim(data: Self.data, seed: seed, config: Self.cfg(true, bag: bag))
            for _ in 0..<(150 * 60) {
                for e in sim.step() {
                    switch e {
                    case .skillUsed(_, let a, _): used[a, default: 0] += 1
                    case .hit(let h) where h.attackerIsHero: hitsBy[h.attackerAnim, default: 0] += 1; if h.reaction == "crumple" && h.attackerAnim == "nv_liver" { crumple += 1 }; if h.reaction == "rBlast" { blast += 1 }
                    case .comboRoute(let n, _, _): routes.insert(n)
                    case .perfectDodge: slips += 1
                    default: break
                    }
                }
                if sim.state == "over" { break }
            }
        }
        print("[skills] 사용 \(used) · 적중 \(hitsBy.filter { $0.key.hasPrefix("nv_") }) · 경로 \(routes) · 리버 무너짐 \(crumple) · 일직선 \(blast) · 흘림 \(slips)")
        for a in ["nv_flick", "nv_liver", "nv_cork", "nv_roll"] { #expect((hitsBy[a] ?? 0) > 0, "\(a) 적중") }
        #expect(crumple > 0 && blast > 0)
        #expect(routes.isSuperset(of: ["피카부 러시", "간 찌르고 퍼 올리기"]), "\(routes)")
        // 깃발이 꺼지면 상점 · 드롭 후보에 없다
        let off = Sim(data: Self.data, seed: 1, config: Self.cfg(false)), on = Sim(data: Self.data, seed: 1, config: Self.cfg(true))
        #expect(!off.w.realItems().contains("nv_cork") && on.w.realItems().contains("nv_cork"))
    }

    // MARK: 막차 러시

    /// 적이 셋 이상 서 있을 때 게이지를 채워 러시를 쓴다 → (러시 동안 이벤트, 실제 틱 수, 게임 시간)
    static func rushRun(_ on: Bool, seed: UInt32) -> (events: [SimEvent], ticks: Int, game: Double, sim: Sim) {
        var c = cfg(on); c.nativeGuard = false   // 러시만 웹과 견준다(공방 층의 군중 자리가 끼면 맞는 적 수가 달라진다 — docs/08)
        let sim = Sim(data: data, seed: seed, config: c)
        var ev: [SimEvent] = [], ticks = 0, g0 = 0.0, started = false
        for _ in 0..<(60 * 60) {
            let w = sim.w
            if !started && w.state == "fight" && w.time > 3 + Double(seed % 9) && w.foes().filter({ !w.isDown($0) }).count >= 2 && w.spc == nil && w.cut == nil { w.sp = 100; started = sim.w.trySpecial() }
            let e = sim.step()
            if started { ev += e; ticks += 1; if g0 == 0 && w.spc != nil { g0 = w.gameTime } }
            if started && w.spc == nil && w.cut == nil && ticks > 30 { return (ev, ticks, w.gameTime - g0, sim) }
        }
        return (ev, ticks, 0, sim)
    }

    @Test func rushHitsCarriesAndLaunches() {
        var webHits: [Int] = [], nvHits: [Int] = [], nvLaunch = 0, webLaunch = 0
        var allAnims: Set<String> = [], allWords: [String] = [], finishes = 0
        for seed in [11, 12, 13, 14, 15, 16] as [UInt32] {
            for on in [false, true] {
                let r = Self.rushRun(on, seed: seed)
                let hits = r.events.compactMap { e -> HitInfo? in if case .hit(let h) = e, h.attackerIsHero { return h }; return nil }
                let launches = hits.filter { $0.reaction == "launch" }.count
                if on { nvHits.append(hits.count); nvLaunch += launches } else { webHits.append(hits.count); webLaunch += launches }
                if on {
                    allAnims.formUnion(hits.map(\.attackerAnim))
                    let words = r.events.compactMap { e -> String? in if case .comicWord(let w, _, _) = e { return w }; return nil }
                    allWords += words
                    if r.events.contains(where: { if case .fxDetail(let d) = $0 { return d.kind == "nv_finish" }; return false }) { finishes += 1 }
                    print("[rush] seed \(seed): 타격 \(hits.count) · 띄움 \(launches) · 실제 \(String(format: "%.2f", Double(r.ticks) / 60))초 · 게임 \(String(format: "%.2f", r.game))초 · 글자 \(words)")
                } else {
                    print("[rush/web] seed \(seed): 타격 \(hits.count) · 띄움 \(launches) · 실제 \(String(format: "%.2f", Double(r.ticks) / 60))초 · 게임 \(String(format: "%.2f", r.game))초")
                }
            }
        }
        #expect(allAnims.isSuperset(of: ["nv_drHLq", "nv_drHRq", "nv_drFinUp"]), "좌우 훅 · 마무리 올려치기: \(allAnims)")
        #expect(finishes == 6 && allWords.filter { $0 == "KA-POW!" }.count == 6)
        #expect(allWords.contains("파바박!") && allWords.contains("우다다다다!"), "박자마다 커지는 만화 글자")
        // 피해 규칙이 같으니 타격 수가 비슷해야 한다(웹 대비 ±50%)
        let a = Double(webHits.reduce(0, +)), b = Double(nvHits.reduce(0, +))
        #expect(b >= a * 0.5 && b <= a * 1.5, "러시 타격 수 웹 \(webHits) · 네이티브 \(nvHits)")
        #expect(nvLaunch > 0 && Double(nvLaunch) >= Double(webLaunch) * 0.6)
    }

    /// 무도장: 깃발이 켜지면 새 기술 · 도감 콤보 · 예시 가방이 목록 뒤에 붙고 시연이 실제로 맞는다 · 꺼지면 웹 목록 그대로
    @Test func dojoListsAndDemos() {
        var c = Self.cfg(true); c.mode = .dojo
        let sim = Sim(data: Self.data, seed: 5, config: c), w = sim.w
        var c0 = Self.cfg(false); c0.mode = .dojo
        let off = Sim(data: Self.data, seed: 5, config: c0).w
        #expect(w.sd.dojoCombo.count == off.sd.dojoCombo.count + 7 && w.sd.demoBags.count == off.sd.demoBags.count + 2)
        #expect(w.sd.dojoHero.contains { $0.id == "nv_cork" } && !off.sd.dojoHero.contains { $0.id == "nv_cork" })
        var anims: Set<String> = []
        func play(_ cmd: DojoCommand, _ sec: Double) { sim.step([.dojo(cmd)]); for _ in 0..<Int(sec * 60) { for e in sim.step() { if case .hit(let h) = e, h.attackerIsHero { anims.insert(h.attackerAnim) } } } }
        for k in 0..<3 { play(.combo(off.sd.dojoCombo.count + k), 5) }
        for (_, id) in NativeContent.dojoHero { play(.hero(id, combo: nil), 2.5) }
        play(.special("fist"), 6)
        play(.demoBag(off.sd.demoBags.count), 0.2)
        let R = w.rules.routes(w.bagStructs())
        print("[dojo] 맞힌 동작 \(anims.filter { $0.hasPrefix("nv_") }.sorted()) · 예시 가방 경로 \(R.map(\.name))")
        #expect(anims.isSuperset(of: ["nv_flick", "nv_liver", "nv_cork", "upper", "nv_drHLq", "nv_drFinUp"]))
        #expect(R.contains { $0.name == "피카부 러시" })
    }

    /// 위빙이 화면에서 읽히는가: 러시 동안 머리(관절) · 골반이 주인공 기준으로 몇 px 오가는가(감독 기준 4~6px 이상)
    @Test func rushWeaveAmplitude() {
        let sim = Sim(data: Self.data, seed: 12, config: Self.cfg(true))
        var started = false, hx: [Double] = [], hy: [Double] = [], bx: [Double] = []
        for _ in 0..<(60 * 60) {
            let w = sim.w
            if !started && w.state == "fight" && w.time > 6 && w.foes().count >= 2 && w.spc == nil && w.cut == nil { w.sp = 100; started = w.trySpecial() }
            sim.step()
            if let S = w.spc, !S.fin, S.nvBeat >= 0, let P = w.hero.lastP {
                let (j, _) = solveJoints(P, rig: w.data.heroRig, input: JointInput(tilt: w.hero.tilt, airOv: w.hero.airOv, walkResidual: nil, weaponSprite: nil))
                hx.append(j.head.x); hy.append(j.head.y); bx.append(j.hips.x)
            }
            if started && w.spc == nil && w.cut == nil && !hx.isEmpty { break }
        }
        let rx = (hx.max() ?? 0) - (hx.min() ?? 0), ry = (hy.max() ?? 0) - (hy.min() ?? 0), rb = (bx.max() ?? 0) - (bx.min() ?? 0)
        print("[weave] 머리 좌우 \(String(format: "%.1f", rx))px · 위아래 \(String(format: "%.1f", ry))px · 골반 좌우 \(String(format: "%.1f", rb))px (\(hx.count)틱)")
        #expect(rx >= 8 && ry >= 4 && rb >= 4)
    }

    // MARK: 밸런스(분포)

    static func ms(_ v: [Double]) -> (m: Double, s: Double) {
        let m = v.reduce(0, +) / Double(max(1, v.count))
        return (m, (v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(1, v.count))).squareRoot())
    }
    /// 묶음 하나: 같은 씨앗 n판씩 끔/켬 → 지표별 (평균 끔, 평균 켬, z)
    static func compare(_ name: String, n: Int, seconds: Double, stage: Int = 0, kit: String = "basic") -> [(String, Double, Double, Double, Double, Double)] {
        var A: [Res] = [], B: [Res] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: n * 2) { k in
            let r = run(k % 2 == 1, seed: UInt32(5000 + k / 2), seconds: seconds, stage: stage, kit: kit)
            lock.lock(); if k % 2 == 1 { B.append(r) } else { A.append(r) }; lock.unlock()
        }
        let rows: [(String, (Res) -> Double)] = [("생존율", { $0.alive ? 1 : 0 }), ("처치", \.kills), ("준 피해", \.dealt), ("받은 피해", \.taken), ("점수", \.score),
                                                 ("도달 칸", \.ci), ("최대 연타", \.maxCombo), ("필살기 횟수", \.spc), ("끝 시각", \.t)]
        return rows.map { (k, f) in
            let a = ms(A.map(f)), b = ms(B.map(f))
            let se = ((a.s * a.s + b.s * b.s) / Double(n)).squareRoot()
            return (k, a.m, a.s, b.m, b.s, se > 0 ? (b.m - a.m) / se : 0)
        }
    }

    @Test func balanceHolds() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let sets: [(String, Int, Double, Int, String)] = big
            ? [("1노선 기본 가방 90초", 60, 90, 0, "basic"), ("1노선 기본 가방 300초", 40, 300, 0, "basic"), ("2노선 기본 가방 180초", 30, 180, 1, "basic"),
               ("1노선 잡기 가방 180초", 30, 180, 0, "grap"), ("1노선 발 가방 180초", 30, 180, 0, "foot")]
            : [("1노선 기본 가방 90초", 24, 90, 0, "basic")]   // 12판은 아이템 표가 바뀔 때마다(난수 흐름) 흔들려 24판으로(2026-10-13 회오리 옆차기 추가 때 — 큰 표본 60판 기준은 통과)
        var md = "| 묶음 | 지표 | 끔(웹 규칙) | 켬(네이티브) | z |\n|---|---|---:|---:|---:|\n"
        for (name, n, sec, st, kit) in sets {
            let R = Self.compare(name, n: n, seconds: sec, stage: st, kit: kit)
            for (k, am, asd, bm, bsd, z) in R {
                md += "| \(name) (\(n)판) | \(k) | \(String(format: "%.2f ± %.2f", am, asd)) | \(String(format: "%.2f ± %.2f", bm, bsd)) | \(String(format: "%+.2f", z)) |\n"
                if k == "처치" || k == "받은 피해" || k == "생존율" {
                    // 크게 깨지지 않았는지: 평균이 끔 대비 ±35% 안(생존율은 ±0.3)
                    if k == "생존율" { #expect(abs(bm - am) <= 0.3, Comment(rawValue: "\(name) \(k) \(am) → \(bm)")) }
                    else { #expect(abs(bm - am) <= max(4, am * 0.35), Comment(rawValue: "\(name) \(k) \(am) → \(bm)")) }
                }
            }
        }
        print(md)
        if big {
            let url = Self.root.appending(path: "tools/js/out/moves/balance.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try md.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
