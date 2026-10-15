#if DEBUG
import Foundation
import BBSim
import BBPersistence

// 점검용 실행 인자(시뮬레이터 스크린숏 · UI 테스트) — 흐름 화면을 바로 연다.
//   -autostart            새 판(씨앗 2026)        -autotower   엘리베이터 타워
//   -screen <이름>        title · menu-run · menu-daily · menu-tower · menu-codex[-foe|stn|item|link|cmb|spc|rec] · menu-sound ·
//                         pause · news · tower-result · bonus · talk · hint · confirm · abandon
//   -samplemeta           메모리에만 예시 메타(도감 · 기록 · 타워 · 해금)를 깐다(저장하지 않음 — 화면 점검용)
//   -skiptalks            대화 상자를 띄우지 않는다(자동 점검 환경과 같게)
//   -dojo [적 종류]       무도장 바로 열기(+ 상대 — 예: -dojo nv_spar · 새 적 화면 점검)
//   -autospc              필살기 자동(설정 저장은 그대로 — 동작 개편 영상 · 점검용)
//   -devhud               성능 줄 · AUTO 배지를 이번 실행만 켠다(개발자 설정 저장은 그대로)
//   -lang en|ko           이번 실행만 화면 언어를 바꾼다('dotlab-lang' 저장은 그대로 — 시뮬레이터 공용 저장을 건드리지 않게)
//   -bagopen [초]         새 배치: 판이 시작되고 몇 초(기본 7) 뒤 가방 시트를 펼친다(펼친 화면 스크린숏 — 손가락 자동화 없이)
//   -layout old|new       이번 실행만 게임 화면 배치('bbn-layout' 저장은 그대로)
//   -noprologue           이번 실행만 프롤로그 없이(첫 노선 열차부터 — 노선도 HUD 점검)
//   -bagsel [stash]       가방 시트를 펼칠 때 첫 타일(stash 면 보관함 첫 타일)을 고른다(설명 카드 점검)
//   -arrange              첫 매점이 열리면 첫 카드를 골라 정리 단계로(시트 자동 펼침 · '출발 ▶' 점검) — 속도 2배 · 필살 자동 ·
//                         정리 단계에 들면 가방을 만진 것처럼(bagTouch → 정리 타이머 멈춤 — 손으로 '출발 ▶'을 누를 때까지 남는다)
//   -shop                 첫 매점까지 가서 멈춘다(속도 2배 · 필살 자동 — 매점은 시간 제한이 없어 고를 때까지 남는다 · 매점 화면 점검)
//   -dojomove <아이템 id> [초]  무도장을 열고 그 기술 단독 시연을 반복(예: -dojomove nv_rise 5 — 퇴근 승천권 영상, 간격 기본 2.6초 · 쉼표로 여럿이면 번갈아: nv_rise,combo0 · spc:grap = 필살기 · wall:throw / wall:suplex = 벽 앞 벽꿍)
//   -roofdemo [tower]     새 판(프롤로그 없이)에서 승천권 지붕 뚫기 시연을 3.5초마다(앞 40px 적을 꼭대기 한 방 체력으로 — Sim.debugRiseDemo)
//                         tower = 엘리베이터 타워에서(비상 해치 갈래)
//   -arrangelive          -arrange 와 같지만 bagTouch 를 넣지 않는다(정리 타이머가 흐르는 '출발 ▶ n초' 점검)
//   -stage snow           새 판(프롤로그 없이)을 열고 7호선 눈 승강장 구간으로 바로 간다(Sim.debugSnowJump — docs/10 · 노선 기록은 그대로)
//                         -stage snowdojo = 무도장을 눈 승강장 배경으로(+ -dojozoom 2 = 무도장 확대 — 입김 영상) · crossdojo = 건널목 · wooddojo = 무도장
//                         beachdojo · beachdusk · beachnight = 무도장을 해변(오후 · 노을 · 밤) 배경으로(docs/12)
//   -impactdemo [초]      주인공 앞 바닥 충격(철산고 진각과 같은 groundImpact + tsring)을 n초(기본 2.5)마다 — 바닥 충격 연출 점검(Sim.debugGroundImpact)
//   -kodemo [체력] [초]   새 판(프롤로그 없이)에서 n초(기본 3)마다 남은 적 체력을 그 값(기본 6) 이하로 — 웨이브가 빨리 끝나 KO 마무리가 자주 보인다(docs/11 · Sim.debugLowFoes)
enum DebugLaunch {
    @MainActor static func run(_ s: GameSession) {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-lang"), i + 1 < a.count { s.lang = a[i + 1]; L10n.lang = a[i + 1] }
        if a.contains("-samplemeta") { s.meta = sampleMeta(s); s.debugNoSave = true }
        if a.contains("-autospc") { s.settings.autoSpc = true }
        if a.contains("-devhud") { s.settings.devPerf = true; s.settings.devBadge = true; s.director.hud.modeBadge = true }   // 이번 실행만(저장 안 함)
        if let i = a.firstIndex(of: "-layout"), i + 1 < a.count { s.settings.layoutNew = a[i + 1] != "old" }
        if a.contains("-noprologue") { s.settings.prologue = false }
        if let i = a.firstIndex(of: "-bagopen") {
            let t = i + 1 < a.count ? Double(a[i + 1]) ?? 7 : 7
            let sel = a.contains("-bagsel"), selStash = a.firstIndex(of: "-bagsel").map { $0 + 1 < a.count && a[$0 + 1] == "stash" } ?? false
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(t)); s.setBagOpen(true)
                if sel { try? await Task.sleep(for: .seconds(0.6)); s.bag.debugSelectFirst(stash: selStash) }
            }
        }
        let arrange = a.contains("-arrange") || a.contains("-arrangelive")
        if arrange || a.contains("-shop") {   // 매점 → 첫 카드 → 정리 단계(규칙 경로 그대로 — 손가락 대신 의도만 넣는다)
            s.settings.autoSpc = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                while s.speed != 2 { s.cycleSpeed() }
                for _ in 0..<600 {
                    try? await Task.sleep(for: .seconds(0.5))
                    if s.snapshot.state == "shop" {
                        guard arrange else { return }   // -shop: 매점에서 멈춘다
                        try? await Task.sleep(for: .seconds(1.2)); s.enqueue(.shopPick(0)); break
                    }
                }
                guard !a.contains("-arrangelive") else { return }
                // 정리 단계에서 가방을 한 번 만진 것처럼(웹 arrTouched — 정리 타이머가 멈춰 스크린숏 동안 남는다)
                for _ in 0..<40 {
                    try? await Task.sleep(for: .seconds(0.25))
                    if s.snapshot.state == "arrange" { s.enqueue(.bagTouch); break }
                }
            }
        }
        if a.contains("-autostart") { s.newRun(seed: 2026) }
        if let i = a.firstIndex(of: "-dojomove"), i + 1 < a.count {   // 무도장 기술 단독 시연 반복
            let id = a[i + 1], gap = i + 2 < a.count ? Double(a[i + 2]) ?? 2.6 : 2.6
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5)); s.openDojo()
                try? await Task.sleep(for: .seconds(4))   // 패널이 저장된 상대 · 설정을 되살린 뒤
                let ids = id.split(separator: ",").map(String.init)
                for n in 0..<200 {
                    let k = ids[n % ids.count]
                    if k.hasPrefix("combo"), let c = Int(k.dropFirst(5)) { s.enqueue(.dojo(.combo(c))) }   // combo<n> = 콤보 시연
                    else if k.hasPrefix("spc:") { s.enqueue(.dojo(.special(String(k.dropFirst(4))))) }   // spc:grap = 필살기 시연(종착역)
                    else if k.hasPrefix("wall:") { s.sim?.debugDojoWallThrow(String(k.dropFirst(5))) }   // wall:throw · wall:suplex = 벽 앞 벽꿍 시연(네이티브)
                    else { s.enqueue(.dojo(.hero(k, combo: nil))) }
                    try? await Task.sleep(for: .seconds(gap))
                }   // gap 초마다 다시(반복 단추와 같은 효과 · 패널 상태와 무관)
            }
        }
        if let ri = a.firstIndex(of: "-roofdemo") {   // 지붕 뚫기 시연(지하철 판 · tower 면 엘리베이터 타워)
            s.settings.prologue = false; s.settings.autoSpc = false
            if ri + 1 < a.count && a[ri + 1] == "tower" { s.newTower(daily: false) } else { s.newRun(seed: 2026) }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                for _ in 0..<400 {
                    if s.sim?.debugRiseDemo() == true { try? await Task.sleep(for: .seconds(3.5)) } else { try? await Task.sleep(for: .seconds(0.2)) }
                }
            }
        }
        if let i = a.firstIndex(of: "-kodemo") {   // KO 마무리 시연(타격감 묶음 영상)
            let hp = i + 1 < a.count ? Double(a[i + 1]) ?? 6 : 6, gap = i + 2 < a.count ? Double(a[i + 2]) ?? 3 : 3
            s.settings.prologue = false
            if !a.contains("-autostart") { s.newRun(seed: 2026) }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                for _ in 0..<600 { _ = s.sim?.debugLowFoes(hp); try? await Task.sleep(for: .seconds(gap)) }
            }
        }
        if let i = a.firstIndex(of: "-impactdemo") {   // 바닥 충격 시연(지금 판 그대로 — -autostart · -stage snow 와 함께)
            let gap = i + 1 < a.count ? Double(a[i + 1]) ?? 2.5 : 2.5
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                for _ in 0..<400 { _ = s.sim?.debugGroundImpact(); try? await Task.sleep(for: .seconds(gap)) }
            }
        }
        if let i = a.firstIndex(of: "-stage"), i + 1 < a.count {   // 눈 승강장 바로 가기
            if a[i + 1] == "snow" {
                s.settings.prologue = false
                if !a.contains("-autostart") { s.newRun(seed: 2026) }
                Task { @MainActor in
                    for _ in 0..<40 { try? await Task.sleep(for: .seconds(0.25)); if s.sim?.debugSnowJump() == true { break } }
                }
            } else if ["snowdojo", "crossdojo", "wooddojo", "beachdojo", "beachdusk", "beachnight"].contains(a[i + 1]) {   // 무도장 배경 바로 가기(눈 승강장 · 건널목 · 무도장 · 해변 셋)
                let bg = ["snowdojo": "snow", "crossdojo": "cross", "wooddojo": "dojo", "beachdojo": "beach", "beachdusk": "beach_dusk", "beachnight": "beach_night"][a[i + 1]]!
                let zoom = a.firstIndex(of: "-dojozoom").flatMap { $0 + 1 < a.count ? Double(a[$0 + 1]) : nil }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5)); s.openDojo(); try? await Task.sleep(for: .seconds(3)); s.enqueue(.dojo(.background(bg)))
                    if let z = zoom { s.enqueue(.dojo(.zoom(z))) }
                }
            }
        }
        if a.contains("-autotower") { s.newTower(daily: false) }
        if let i = a.firstIndex(of: "-dojo") {   // 무도장 바로 열기(+ 상대 종류: -dojo nv_spar) — 새 적 화면 점검용
            let d = i + 1 < a.count && !a[i + 1].hasPrefix("-") ? a[i + 1] : nil
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5)); s.openDojo()
                if let d { try? await Task.sleep(for: .seconds(3)); s.enqueue(.dojo(.dummy(d))) }   // 패널이 저장된 상대(djDummy)를 되살린 뒤에
            }
        }
        guard let i = a.firstIndex(of: "-screen"), i + 1 < a.count else { return }
        let name = a[i + 1]
        if name.hasPrefix("menu-codex") {
            if let t = CodexTab(rawValue: String(name.dropFirst("menu-codex-".count))) { s.codexTab = t }
            s.menuTab = .codex; return
        }
        switch name {
        case "title": break
        case "menu-run": s.menuTab = .run
        case "menu-daily": s.menuTab = .daily
        case "menu-tower": s.menuTab = .tower
        case "menu-sound": s.menuTab = .sound
        case "confirm": s.request(RunRequest(kit: "basic"))   // 저장이 있으면 확인 창
        default:
            // 판 안 화면: 새 판을 열고 조금 뒤에
            s.begin(RunRequest(), seed: 2026)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(name == "talk" || name == "hint" ? 2 : 6))
                switch name {
                case "pause": s.openMenu(.run)
                case "abandon": s.openMenu(.run); s.confirm = .abandon
                case "news": s.debugShowNews(win: false)
                case "tower-result": s.debugShowTower()
                case "bonus": s.debugShowBonus()
                case "talk": s.debugTalk("intro")
                case "hint": s.debugHint("just")
                default: break
                }
            }
        }
    }

    /// 화면 점검용 예시 메타(웹에서 몇 판 돈 모양)
    @MainActor static func sampleMeta(_ s: GameSession) -> MetaState {
        var m = s.meta
        let C = s.content
        m.runs = max(m.runs, 7); m.best.score = max(m.best.score, 48210); m.best.stage = max(m.best.stage, 1)
        m.tot.kills += 212; m.tot.crits += 64; m.tot.dodges += 9; m.tot.links += 27; m.tot.throws += 11; m.tot.outs += 33; m.tot.onTime += 6; m.tot.merges += 4; m.tot.footSet += 1
        m.kits["crit"] = 1; m.kits["foot"] = 1; m.lines["1"] = 1
        for (k, e) in C.game.enemies.ordered.prefix(14) { _ = e; m.foes[k] = .init(seen: 12, ko: 9) }
        for id in C.stationOrder.prefix(9) { m.stns[id] = 1 }
        for id in C.realItems.prefix(18) { m.items[id] = 2 }
        for L in C.game.links.prefix(6) { m.links[L.id] = 1 }
        if let b = C.game.comboBook.first { m.cbook = [b.id: .init(n: 4, best: 7)] }
        if C.game.comboBook.count > 1 { m.cseen = [C.game.comboBook[1].id: 1] }
        m.combos = ["kick>punch": .init(name: "", ids: ["kick", "punch"], n: 3, best: 4)]
        m.spc = ["fist": 2]; m.bossScenes = ["boss": 1]
        var T = MetaState.TowerRecord(); T.best = 18; T.bestT = 0; T.runs = 4; T.ot = 2
        T.lv = ["0": .init(f: 20, t: 244), "1": .init(f: 18, t: 260), "2": .init(f: 14, t: 251)]; T.daily = [DailyKey.today(): .init(f: 9, t: 120)]
        m.tower = T; m.bonusBest = 23340
        m.daily[DailyKey.today()] = 12900
        return m
    }
}

enum DebugJump { case bonusBoard, news, tower, talk, openLines }

extension GameSession {
    func debugJump(_ j: DebugJump) {
        switch j {
        case .openLines: devLines.toggle()
        default:
            if sim == nil { begin(RunRequest(), seed: 2026) }
            menuTab = nil
            switch j {
            case .bonusBoard: debugShowBonus(); setPaused(false)
            case .news: debugShowNews(win: false)
            case .tower: debugShowTower()
            case .talk: setPaused(false); debugTalk("intro")
            case .openLines: break
            }
        }
    }
}
#endif
