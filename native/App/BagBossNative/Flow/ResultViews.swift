import SwiftUI
import BBSim
import BBPersistence

// 판 끝 화면:
//   지하철 — 타블로이드 신문 1면(웹 34-shop showResult + 38-title-news newsCopy · newsPhoto, CSS .g-card.paper)
//   타워   — 결과 카드(웹 24-tower towerResult, CSS .tw-res)
//   보너스 — 결산판(웹 43-fx-smoke drawBonusResult, CSS .bonus-res — 무대 위, 줄마다 0.45초 간격으로 숫자가 오른다)

// MARK: 신문

struct NewsCopy { var head: String, deck: String, p1: String, p2: String }

/// 웹 newsCopy(win)
func newsCopy(_ n: NewsInfo, _ C: FlowContent, dmgK: Double) -> NewsCopy {
    let st = C.stages, S = st[min(n.stageIdx, st.count - 1)], line = S.line
    let ci = min(n.ci, line.count - 1)
    let to = C.stationName(line[ci].stop), from = C.stationName(ci == 0 ? S.start : line[ci - 1].stop)
    let s = n.stats
    let head = n.win ? KE("정장 사나이, \(st.count)개 노선 평정!", "Suited man conquers all \(st.count) lines!")
        : (n.kills >= 30 ? KE("\(n.ci + 1)호차의 혈투 — 정장 사나이 끝내 하차", "Bloodbath in car \(n.ci + 1) — suited man finally gets off")
           : KE("\(from) 구간서 쓰러진 정장 사나이", "Suited man falls near \(from)"))
    let deck = n.win ? tr("애틀랜틱 애비뉴에서 지도에 없는 역까지 — 배신자 케인, 종점에서 쓰러지다")
        : KE("\(S.name) \(n.ci + 1)호차, \(from)→\(to) 구간 — 목격담 잇따라", "\(tr(S.name)), car \(n.ci + 1), \(from) → \(to) — witnesses keep coming forward")
    let dk: (Double) -> String = { Int((($0) * dmgK).rounded()).formatted() }
    if L10n.isEN {
        let F = [s.maxCombo > 1 ? "a \(s.maxCombo)-hit chain" : nil, s.crits > 0 ? "\(s.crits) crits" : nil, s.combos > 0 ? "\(s.combos) combos" : nil,
                 s.counters > 0 ? "\(s.counters) counters" : nil, s.justs > 0 ? "\(s.justs) just counters" : nil].compactMap { $0 }
        let p1 = "He took down \(n.kills) enemies that day\(s.outs > 0 ? ", throwing \(s.outs) of them out an open door" : "").\(F.isEmpty ? "" : " Witnesses counted \(F.joined(separator: ", ")).")"
        let p2 = "\(s.onTime > 0 || s.late > 0 ? "The train ran on time \(s.onTime) times\(s.late > 0 ? " and late \(s.late)" : ""). " : "")One rider said, \"His tie never moved.\" Damage dealt \(dk(s.dealt)) · taken \(dk(s.taken))."
        return NewsCopy(head: head, deck: deck, p1: p1, p2: p2)
    }
    let F = [s.maxCombo > 1 ? "최대 \(s.maxCombo)연타" : nil, s.crits > 0 ? "치명타 \(s.crits)번" : nil, s.combos > 0 ? "콤보 \(s.combos)번" : nil,
             s.counters > 0 ? "받아치기 \(s.counters)번" : nil, s.justs > 0 ? "저스트 \(s.justs)번" : nil].compactMap { $0 }
    // 받침 있으면 '이', 없으면 '가'(웹 jo)
    func jo(_ w: String) -> String {
        guard let c = w.unicodeScalars.last?.value, (0xAC00...0xD7A3).contains(c) else { return "가" }
        return (c - 0xAC00) % 28 != 0 ? "이" : "가"
    }
    let p1 = "이날 그는 적 \(n.kills)명을 쓰러뜨렸다.\(s.outs > 0 ? " 그중 \(s.outs)명은 열린 문밖으로 내던졌다." : "")\(F.isEmpty ? "" : " \(F.joined(separator: ", "))\(jo(F.last!)) 목격됐다.")"
    let p2 = "\(s.onTime > 0 || s.late > 0 ? "열차는 정시 도착 \(s.onTime)회\(s.late > 0 ? ", 지각 \(s.late)회" : "")를 기록했다. " : "")한 승객은 \"넥타이 한 번 안 흐트러지더라\"고 전했다. 준 피해 \(dk(s.dealt)), 받은 피해 \(dk(s.taken))."
    return NewsCopy(head: head, deck: deck, p1: p1, p2: p2)
}

struct NewsResultView: View {
    let info: NewsInfo
    @Bindable var session: GameSession

    var body: some View {
        let C = session.content, M = session.meta, N = newsCopy(info, C, dmgK: session.data.dmgK)
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(spacing: 2) {
                        Text("THE DAILY TRANSIT").font(.galmuri(20, bold: true)).tracking(1.6).foregroundStyle(PX.paperInk)
                        HStack {
                            Text(KE("데일리 트랜짓 · 뉴욕 지하철판", "New York Subway Edition"))
                            Spacer()
                            Text("\(dateText(info.date)) · \(info.daily ? KE("오늘의 노선 특별판", "Daily Route Special") : KE("최종판", "Final")) · 25¢")
                        }
                        .font(.galmuriSmall(10)).foregroundStyle(PX.paperSub)
                    }
                    .padding(.bottom, 4)
                    .overlay(VStack(spacing: 2) { Rectangle().frame(height: 1); Rectangle().frame(height: 1) }.foregroundStyle(PX.paperInk), alignment: .bottom)
                    Text(N.head).font(.galmuri(19, bold: true)).foregroundStyle(PX.paperInk).fixedSize(horizontal: false, vertical: true)
                    Text(N.deck).font(.galmuriSmall(11)).foregroundStyle(Color(px: "#4a3e28")).fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4).overlay(Rectangle().frame(height: 1).foregroundStyle(PX.paperInk), alignment: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        ZStack {
                            Color(px: "#2a2620")
                            if let p = session.newsPhoto { Image(uiImage: p).resizable().interpolation(.none) }
                            else { Text(KE("현상 중…", "Developing…")).font(.galmuriSmall(10)).foregroundStyle(PX.paper.opacity(0.6)) }
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay(Rectangle().stroke(PX.paperInk, lineWidth: 2))
                        .accessibilityLabel(tr("보도 사진"))
                        Text(KE("사진: 승객 제공 · 점수 \(info.score.formatted())점\(info.newBest ? " · 최고 기록 경신" : "")",
                                "Photo: courtesy of a passenger · Score \(info.score.formatted())\(info.newBest ? " · New best!" : "")"))
                            .font(.galmuriSmall(10)).foregroundStyle(PX.paperSub)
                    }
                    Text(N.p1).font(.galmuriSmall(11)).foregroundStyle(PX.paperInk).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    Text(N.p2).font(.galmuriSmall(11)).foregroundStyle(PX.paperInk).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: 8) {
                        Text(tr("기록실")).font(.galmuri(11, bold: true))
                        Text("\(tr("최고")) \(Int(M.best.score).formatted())\(tr("점"))")
                        Text("\(M.runs)\(tr("판째"))")
                        if info.daily { Text("\(tr("오늘의 노선 최고")) \(Int(M.daily[DailyKey.today(info.date)] ?? 0))\(tr("점"))") }
                        Text("\(tr("도감 적")) \(M.foes.count)/\(C.game.enemies.count)")
                        Text("\(tr("역")) \(M.stns.count)")
                        Text("\(tr("아이템")) \(M.items.count)/\(C.realItems.count)")
                        if !info.unlocks.isEmpty { Text("\(tr("새로 열림")): \(info.unlocks.map(tr).joined(separator: " · "))").foregroundStyle(Color(px: "#a8241c")) }
                    }
                    .font(.galmuriSmall(11)).foregroundStyle(PX.paperInk)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(px: "#e6dcc0")).overlay(Rectangle().stroke(PX.paperInk, lineWidth: 2))
                    HStack(spacing: 8) {
                        Button(tr("다시 하기")) { session.again() }.buttonStyle(PaperButton(primary: true))
                        Button(tr("메뉴")) { session.toTitle(openMenu: .run) }.buttonStyle(PaperButton()).accessibilityLabel(KE("메뉴로", "To menu"))
                        ShareResultButton(paper: true) { (ResultShare.newsImage(info, session: session), ResultShare.newsText(info)) }   // Features/ShareCard
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(PX.paper)
                .background(PX.dark.offset(x: 5, y: 5))
                .frame(maxWidth: 560)
                .padding(.horizontal, 12).padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func dateText(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        if L10n.isEN { let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM d, yyyy"; return f.string(from: d) }
        return "\(c.year ?? 0)년 \(c.month ?? 0)월 \(c.day ?? 0)일"
    }
}

/// 신문 위 버튼(웹 .g-card.paper .btn)
struct PaperButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.galmuri(13, bold: primary))
            .foregroundStyle(PX.paperInk)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(primary ? PX.accent : Color(px: "#e6dcc0"))
            .overlay(Rectangle().stroke(PX.paperInk, lineWidth: 2))
            .brightness(configuration.isPressed ? 0.1 : 0)
    }
}

// MARK: 타워 결과

struct TowerResultView: View {
    let r: TowerResult
    @Bindable var session: GameSession

    var body: some View {
        let C = session.content
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Text(r.daily.map { "\(KE("오늘의 타워", "Daily Tower")) · \($0)" } ?? "\(tr("엘리베이터 타워")) · \(C.otName(r.ot))")
                    .font(.galmuriSmall(11)).foregroundStyle(PX.sub)
                if r.ot > 0 && r.daily == nil { ModBadges(names: (1...r.ot).compactMap { C.otRule($0) }.map { KE($0.name, $0.en) }) }
                if r.daily != nil { ModBadges(names: r.mods.compactMap { C.mod($0) }.map { KE($0.name, $0.en) }) }
                Text(r.win ? KE("\(C.towerTop)층 \(C.floorName(C.towerTop)) 돌파!", "Cleared \(C.towerTop)F!") : KE("\(r.floor)층에서 멈췄다", "Stopped at \(r.floor)F"))
                    .font(.galmuri(17, bold: true)).foregroundStyle(PX.ink).inkShadow()
                if r.newRecord { Text(KE("새 기록", "New record")).font(.galmuri(12, bold: true)).foregroundStyle(PX.accent) }
                if r.unlocked > 0, let o = C.otRule(r.unlocked) {
                    Text("\(KE("야근 \(r.unlocked)단계가 열렸어요", "Overtime \(r.unlocked) unlocked")) — \(KE(o.name, o.en))").font(.galmuri(12, bold: true)).foregroundStyle(Color(px: "#ff7a5c"))
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(r.floor)F").font(.galmuri(40, bold: true)).foregroundStyle(PX.accent).inkShadow()
                    Text(C.floorName(r.floor)).font(.galmuri(13)).foregroundStyle(PX.ink)
                }
                .frame(maxWidth: .infinity)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                    row(KE("걸린 시간", "Time"), mmss(r.seconds))
                    row(KE("쓰러뜨린 적", "Defeated"), "\(r.kills)")
                    row(KE("문밖으로 날림", "Thrown out"), "\(r.outs)")
                    row(KE("천장 튕기기", "Ceiling bounces"), "\(r.ceils)")
                    row(KE("부순 층", "Floors wrecked"), "\(r.wrecks)")
                    if let d = r.dailyBest { row(KE("오늘 최고", "Today best"), "\(d.f)F · \(mmss(d.t))") }
                    if let l = r.levelBest { row("\(C.otName(r.ot)) \(KE("최고", "best"))", "\(l.f)F · \(mmss(l.t))") }
                    row(KE("최고 층", "Best floor"), "\(r.best)F")
                }
                if r.win { MMNote(t: KE("21층부터는 아직 공사 중이에요", "Floors 21+ are still under construction")) }
                HStack(spacing: 8) {
                    Button(KE("다시 오르기 ▶", "Climb again ▶")) { session.begin(RunRequest(mode: .tower, daily: r.daily != nil, ot: r.ot)) }
                        .buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                        .accessibilityLabel(KE("다시 오르기", "Climb again"))
                    Button(KE("메뉴", "Menu")) { session.toTitle(openMenu: .tower) }.buttonStyle(PixelButtonLook(minHeight: 40))
                    ShareResultButton { (ResultShare.towerImage(r, session: session), ResultShare.towerText(r)) }   // Features/ShareCard
                }
                .frame(maxWidth: .infinity).padding(.top, 6)
            }
            .gCard()
            .frame(maxWidth: 420)
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).font(.galmuriSmall(11)).foregroundStyle(PX.sub)
            Text(v).font(.galmuri(12, bold: true)).foregroundStyle(PX.ink)
        }
    }
}

// MARK: 보너스 결산판

struct BonusBoardView: View {
    let board: BonusBoard

    var body: some View {
        let T = board.result, t = board.pt - 1.6
        let rows: [(String, Int)] = [("타격 점수", T.hit), ("부품 보너스", T.part), ("파괴 보너스", T.destroy), ("시간 보너스", T.time), ("최대 연타 보너스", T.combo)]
        let n = min(rows.count, max(0, Int((t / 0.45).rounded(.down)) + 1))
        let u: (Int) -> Double = { k in max(0, min(1, (t - Double(k) * 0.45) / 0.4)) }
        let tot = Int(rows.enumerated().reduce(0.0) { $0 + Double($1.element.1) * u($1.offset) }.rounded())
        VStack(spacing: 0) {
            Text("BONUS · \(tr("차 부수기"))").font(.galmuri(12, bold: true)).foregroundStyle(PX.accent).padding(.bottom, 4)
            ForEach(0..<n, id: \.self) { k in
                HStack {
                    Text(tr(rows[k].0)); Spacer(minLength: 16)
                    Text(Int((Double(rows[k].1) * u(k)).rounded()).formatted()).foregroundStyle(Color(px: "#fff1a0"))
                }
            }
            if t > Double(rows.count) * 0.45 {
                Rectangle().fill(Color(px: "#6a5a30")).frame(height: 1).padding(.top, 4)
                HStack { Text(tr("합계")); Spacer(); Text(tot.formatted()).foregroundStyle(PX.accent) }.font(.galmuri(12, bold: true)).padding(.top, 4)
                HStack(spacing: 4) {
                    Text("\(T.grade)\(tr("등급"))\(T.tokens > 0 ? " · \(tr("토큰")) +\(T.tokens)" : "")").foregroundStyle(PX.accent)
                    if T.best { Text("· NEW RECORD").foregroundStyle(Color(px: "#ff6a4a")) }
                }
                .frame(maxWidth: .infinity)
                if board.skippable { Text(KE("탭해서 넘기기", "Tap to continue")).font(.galmuriSmall(9)).foregroundStyle(PX.note).padding(.top, 2) }
            }
        }
        .font(.galmuri(12))
        .foregroundStyle(Color(px: "#f1ece0"))
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(minWidth: 190)
        .background(Color(red: 10 / 255, green: 8 / 255, blue: 18 / 255).opacity(0.9))
        .overlay(Rectangle().stroke(PX.accent, lineWidth: 3))
        .background(PX.dark.offset(x: 4, y: 4))
        .allowsHitTesting(false)
    }
}

// MARK: 확인 창

struct ConfirmView: View {
    let kind: ConfirmKind
    @Bindable var session: GameSession
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { session.confirm = nil }
            VStack(alignment: .leading, spacing: 8) {
                switch kind {
                case .replace(let r):
                    Text(tr("새로 시작할까요?")).font(.galmuri(15, bold: true)).foregroundStyle(PX.ink).inkShadow()
                    MMText(t: r.mode == .tower ? KE("진행 중인 판은 이어 하기로 저장돼요.", "The current run is saved for Continue.")
                           : KE("이어 하기 기록이 지워져요. 진행 중인 판은 기록 없이 끝나요.", "Your Continue save will be erased. The current run ends without a record."))
                    HStack(spacing: 8) {
                        Button(tr("새로 시작")) {
                            if r.mode == .tower, let s = session.sim, s.config.mode == .subway { session.toTitle() }
                            session.begin(r)
                        }
                        .buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                        Button(tr("취소")) { session.confirm = nil }.buttonStyle(PixelButtonLook(minHeight: 40))
                    }
                case .abandon:
                    Text(tr("이 판을 포기할까요?")).font(.galmuri(15, bold: true)).foregroundStyle(PX.ink).inkShadow()
                    MMText(t: KE("이어 하기 기록 없이 타이틀로 돌아가요. 쌓은 도감 · 누계는 남아요.", "Return to title without a Continue save. Codex and totals are kept."))
                    HStack(spacing: 8) {
                        Button(tr("포기하기")) { session.abandonRun() }.buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                        Button(tr("취소")) { session.confirm = nil }.buttonStyle(PixelButtonLook(minHeight: 40))
                    }
                }
            }
            .gCard()
            .frame(maxWidth: 340)
            .padding(.horizontal, 20)
        }
    }
}
