import Testing
import Foundation
@testable import BBSim

/// K 흐름 검사(바깥 계약): 대화 멈춤(skipTalks=false → talk 이벤트 → 판이 멈춤 → talkNext/talkPick → 이어서) · 콤보 쇼 '탭!'(SimIntent.tapWindow) ·
/// 프롤로그 한 바퀴(앱 설정) · 거리 연출 넘기기 · 무도장 명령 · 스킨 미리보기 · 프롤로그 중 이어 하기 · 오늘의 노선 기록.
@Suite struct StoryFlowTests {
    static func appConfig() -> SimConfig { var c = SimConfig(); c.prologue = true; c.skipTalks = false; c.autoAdvance = true; return c }

    @Test func talkPausesSimAndResumes() {
        let sim = Sim(data: SimRunTests.data, seed: 11, config: Self.appConfig())
        sim.w.endPrologueForTest()
        // 케인 장면 → 첫 소개 대화(intro)가 뜰 때까지
        var opened = false, t = 0
        while t < 60 * 40 && !opened { for e in sim.step() { if case .talk(let k) = e, k == "intro" { opened = true } }; t += 1 }
        #expect(opened, "케인 장면 뒤 첫 소개 대화가 떠야 한다")
        guard opened else { return }
        let s0 = sim.snapshot
        #expect(s0.talk?.key == "intro" && s0.talk?.who == "cond" && s0.talk?.name == "노 차장" && s0.talkActive)
        // 대화 중엔 판이 멈춘다(웹 gameUpdate: if(GS.talk) return)
        let time0 = sim.w.time, legT0 = sim.w.legT
        for _ in 0..<120 { sim.step() }
        #expect(sim.w.time == time0 && sim.w.legT == legT0)
        sim.apply(.talkNext); #expect(sim.snapshot.talk?.who == "minnie")
        sim.apply(.talkNext); #expect(sim.snapshot.talk?.choices == ["…짧게.", "그래서?"])
        sim.apply(.talkNext); #expect(sim.snapshot.talk?.choices != nil, "고를 것이 떠 있으면 탭은 무시")
        sim.apply(.talkPick(1)); #expect(sim.snapshot.talk?.who == "saboo" && sim.snapshot.talk?.text.contains("주워 오는 게") == true)
        var ended = false
        for _ in 0..<5 { sim.apply(.talkNext) }
        for e in sim.step() { if case .talkEnded(let k, _) = e, k == "intro" { ended = true } }
        #expect(sim.snapshot.talk == nil && !sim.snapshot.talkActive)
        #expect(sim.w.meta.talks.contains("intro"))
        // 대화가 끝나면 go(): 출발 예약(departT 1.4)
        for _ in 0..<200 { sim.step() }
        #expect(sim.w.tr.phase != "stop" || sim.w.tr.v > 0 || sim.w.departT < 1.4)
        _ = ended
    }

    @Test func prologueRunsThroughWithAppConfig() {
        var c = SimConfig(); c.prologue = true; c.autoAdvance = true   // skipTalks 기본(true)
        let sim = Sim(data: SimRunTests.data, seed: 21, config: c)
        #expect(sim.state == "corridor" && sim.snapshot.prologue != nil && sim.snapshot.bag.map(\.id) == ["hmup", "hmswing", "hmback", "hmdown"])
        var beats: [String] = [], taps = 0
        for _ in 0..<(60 * 200) {
            var it: [SimIntent] = []
            if let W = sim.snapshot.tapWindow, W.t > 0.3 { it.append(.tapWindow(at: sim.clock)); taps += 1 }
            for e in sim.step(it) { if case .storyBeat(let b) = e { beats.append(b) } }
            if sim.state == "over" { break }
            if beats.contains("kaneEnd") && sim.w.kn == nil && sim.w.pBag == false && sim.state == "fight" && sim.w.departT <= 0 { break }
        }
        for b in ["prologue", "vault", "exit", "cine", "stairs", "cineEnd", "kane", "bagScatter", "kaneEnd"] { #expect(beats.contains(b), "장면 고비 \(b)") }
        #expect(taps > 0, "콤보 쇼 '탭!' 창이 열려야 한다")
        let s = sim.snapshot
        #expect(s.prologue == nil && s.cine == nil && s.kane == nil && !s.pBag && s.scene == "subway")
        #expect(s.bag.map(\.id) == SimRunTests.data.game.kits.first { $0.id == "basic" }!.bag.map(\.id), "시작 가방을 돌려받는다")
        #expect(sim.w.meta.cseen.count > 0, "프롤로그 콤보는 도감에 목격만")
        #expect(sim.w.meta.cbook.isEmpty && sim.w.meta.combos.isEmpty)
    }

    @Test func cineSkipAndResumeDuringPrologue() {
        let sim = Sim(data: SimRunTests.data, seed: 31, config: Self.appConfig())
        sim.w.pr!.x = sim.w.sd.corrLen; sim.w.pr!.wi = 99; sim.w.ents = [sim.w.hero]; sim.w.hero.x = 400   // 웹 jumpTo('cine')
        var t = 0
        while sim.snapshot.cine == nil && t < 600 { sim.step(); t += 1 }
        #expect(sim.snapshot.scene == "brawl" && sim.snapshot.cine != nil)
        for _ in 0..<50 { sim.step() }
        sim.apply(.tap(side: 1, at: sim.clock))   // 0.6초 뒤 무대 탭 → 넘기기
        #expect(sim.snapshot.cine == nil && sim.snapshot.scene == "subway" && sim.state == "fight")
        // 보스의 가방 없이 나왔으면 시작 가방으로(restoreKit)
        #expect(!sim.snapshot.bag.contains { $0.id.hasPrefix("hm") })
        // 프롤로그 중 이어 하기: 프롤로그를 걷고 저장된 판으로
        let sim2 = Sim(data: SimRunTests.data, seed: 32, config: Self.appConfig())
        #expect(sim2.state == "corridor")
        var r = SimResume(); r.ci = 2; r.tokens = 5; r.bag = sim2.snapshot.pKit ?? []
        sim2.resume(r)
        #expect(sim2.snapshot.prologue == nil && sim2.state != "corridor" && sim2.snapshot.tokens == 5)
    }

    @Test func dojoCommandsAndSkinPreview() {
        var c = SimConfig(); c.mode = .dojo
        let sim = Sim(data: SimRunTests.data, seed: 41, config: c)
        #expect(sim.snapshot.demo && sim.snapshot.dojo?.dummy != nil && sim.snapshot.dojo?.dummyType == "punk")
        sim.apply(.dojo(.combo(2)))   // 낙뢰
        var res: [String] = []
        for _ in 0..<(60 * 8) { for e in sim.step() { if case .dojoResult(let t) = e { res.append(t) } } }
        #expect(res.count == 1 && res[0].hasPrefix("3타 중"))
        #expect(sim.snapshot.dojo?.result == res.first)
        sim.apply(.dojo(.setCustom(["punch:3", "punch:0", "upper:scoop", "kick"])))
        sim.apply(.dojo(.customRun))
        #expect(sim.snapshot.dojo?.seq?.steps == ["punch:3", "punch:0", "upper:scoop", "kick"] && sim.snapshot.dojo?.seq?.custom == true)
        for _ in 0..<(60 * 8) { sim.step() }
        #expect(sim.snapshot.dojo?.ccRes?.count == 4)
        sim.apply(.dojo(.dummy("heavy"))); #expect(sim.snapshot.dojo?.dummyType == "heavy")
        sim.apply(.dojo(.loop(true))); sim.apply(.dojo(.react("launch")))
        var reacts = 0
        for _ in 0..<(60 * 10) { sim.step(); if sim.w.dojoDummy()?.anim == "launch" { reacts += 1 } }
        #expect(sim.snapshot.dojo?.rep == true && reacts > 0)
        // 멈춘 채 한 프레임씩
        sim.apply(.dojo(.loop(false))); sim.apply(.pause(true)); let g0 = sim.w.time
        sim.apply(.dojo(.step)); sim.step()
        #expect(sim.w.time > g0); let g1 = sim.w.time; sim.step(); #expect(sim.w.time == g1)
        sim.apply(.pause(false))
        // 스킨 미리보기: 다른 인물은 숨고 주인공만
        sim.apply(.skinPreview(.open)); sim.step()
        #expect(sim.snapshot.skinPv != nil && sim.snapshot.actors.filter { !$0.isHero }.allSatisfy(\.hidden))
        sim.apply(.skinPreview(.fixed("kd5"))); sim.step(); #expect(sim.w.hero.pose == "kd5")
        sim.apply(.skinPreview(.close)); #expect(sim.snapshot.skinPv == nil)
        sim.apply(.dojo(.stop)); #expect(!sim.snapshot.demo && sim.state == "fight")
    }

    @Test func dailyRecordsBest() {
        var c = SimRunTests.harnessConfig(); c.daily = true; c.dateKey = "2026-10-09"
        let sim = Sim(data: SimRunTests.data, seed: 51, config: c)
        let kits = SimRunTests.data.game.kits
        #expect(sim.snapshot.bag.map(\.id) == kits[Int(World.hashStr("2026-10-09") % UInt32(kits.count))].bag.map(\.id))
        sim.w.score = 1234; sim.w.showResult(false)
        #expect(sim.meta.daily["2026-10-09"] == 1234)
    }
}

extension World {
    /// 시험용: 복도 · 거리를 건너뛰고 보스의 가방을 든 채 첫 칸으로(케인 장면부터)
    func endPrologueForTest() {
        guard pr != nil else { return }
        pr!.bag = true; pBag = true; bag = scBag("signoff"); ents = [hero]
        endPrologue()
    }
}
