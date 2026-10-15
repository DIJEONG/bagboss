import Foundation

// 네이티브 눈 승강장(docs/10 · SimConfig.nativeMoves && nativeSnow — 꺼지면 이 파일은 불리지 않는다 → 웹과 같다).
// 7호선 2호차 구간(46번가–블리스 → 61번가–우드사이드): 폭설로 열차가 46번가 고가 승강장에 붙잡히고, 그 구간 웨이브를 바깥 승강장에서 싸운다.
// 다 쓰러뜨리면 열차에 다시 올라 남은 구간을 달린다(그 뒤는 보통 칸 그대로).
//  · 붙잡힌 동안: 열차는 선다(phase stop · v 0 · 출발 대기 0). 구간 시계(legT)는 흐르고 웨이브는 그대로 온다 — 짧은 정차 · 도착 판단은 달리는 동안만이라 멈춘다
//  · 바깥이라 문 밖으로 날리기 · 손잡이 매달려 차기 · 손잡이 공중전이 없다. 승객 · 바닥 사물(웅덩이 · 상자 · 캔)도 없다(열차 안에 남았다)
//  · 승천권 지붕 뚫기는 'open'(구멍 없이 하늘로 — World+NativeRise.nvRoofSpot)
//  · 그림 · 눈 효과 · 소리는 표현 몫(BBPresentation SnowScene · SnowFx) — 규칙은 스냅숏 snowStage 만 낸다

/// 눈 승강장 구간 하나
final class SnowLeg {
    /// 붙잡힌 역 id
    let station: String
    /// 아직 승강장(열차가 서 있다)
    var held = true
    init(station: String) { self.station = station }
}

extension NativeContent {
    /// 눈 승강장 구간(노선 열쇠 · 호차 번호 — 그 호차 구간의 출발역 승강장에서 싸운다)
    public static let snowLegs: [(stage: String, car: Int)] = [("7", 1)]
}

extension World {
    var nvSnowOn: Bool { config.nativeMoves && config.nativeSnow }

    /// enterCar 끝: 눈 구간 호차면 승강장으로(승객 · 바닥 사물은 열차 안에 남는다), 아니면 끈다
    func nvSnowEnter() {
        guard nvSnowOn, NativeContent.snowLegs.contains(where: { $0.stage == stage.key && $0.car == ci }) else { nvSnow = nil; return }
        let st = ci > 0 ? (line[ci - 1].stop ?? startStop) : startStop
        nvSnow = SnowLeg(station: st)
        for a in ents where a.pass { retire(a) }
        ents.removeAll { $0.pass }
        props = []; cans = []
        say("폭설 · \(data.stations[st] ?? st)", "눈 때문에 열차가 멈췄다 — 고가 승강장에서 싸운다", 3.0)
        emit(.storyBeat("snow"))
    }

    /// 매 틱(trainUpdate 전): 붙잡힌 동안 열차를 세워 두고, 구간 웨이브를 다 쓰러뜨리면 다시 탄다
    func nvSnowTick() {
        guard let S = nvSnow, S.held else { return }
        if state == "fight" { tr.phase = "stop"; tr.v = 0; tr.a = 0; departT = 0; doorWant = false }
        guard state == "fight", ci < line.count, let H = hero, !H.dead else { return }
        let L = line[ci]
        let cleared = wave >= L.waves.count && foes().isEmpty && clearT.map { legT - $0 > 1.2 } == true
        if cleared || legT > legDur(L) + 20 {   // 다 쓰러뜨렸다(또는 안전장치: 구간 시간을 한참 넘겼다)
            S.held = false; tr.phase = "accel"; fade = 1
            say("열차 출발", "다시 열차에 올랐다 — 남은 구간을 달린다", 2.0)
            emit(.storyBeat("snowEnd"))
        }
    }
}

// MARK: 개발용(앱 DebugLaunch '-stage snow' — 점검 · 영상)

extension Sim {
    /// 7호선 눈 승강장 구간으로 바로 간다(노선 기록은 건드리지 않는다). 깃발이 꺼져 있거나 노선이 없으면 false
    @discardableResult
    public func debugSnowJump() -> Bool {
        guard w.nvSnowOn, let leg = NativeContent.snowLegs.first, let k = w.data.game.stages.firstIndex(where: { $0.key == leg.stage }), w.hero != nil else { return false }
        let keep = w.devRun; w.devRun = true
        if w.pr != nil { w.pr = nil; w.props = []; w.cans = []; w.ev = nil; w.pt = nil }
        if w.stageIdx != k { w.loadStage(k) }
        w.devRun = keep
        w.departT = 0; w.tr.phase = "stop"; w.tr.v = 0; w.tr.door = 1
        w.ents = w.ents.filter { $0.e == nil && !$0.pass }
        w.ci = leg.car - 1; w.atStop = w.line[leg.car - 1].stop ?? w.startStop
        w.startBoard()
        return w.nvSnow != nil
    }

    /// 바닥 충격 시연(앱 '-impactdemo' — 철산고 진각과 같은 groundImpact 1.6 + tsring 을 주인공 앞에 낸다 · 규칙 상태는 그대로)
    @discardableResult
    public func debugGroundImpact() -> Bool {
        guard let H = w.hero, !H.dead else { return false }
        let x = H.x + H.f * 14
        w.groundImpact(x, H.y, 1.6); w.fx("tsring", x, H.y)
        return true
    }
}
