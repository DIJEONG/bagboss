import SwiftUI
import BBContent
import BBPersistence

// 타이틀(웹 38-title-news showTitle · CSS .g-title): 로고 · 부제 · '터치해서 출발'(깜빡임) · 이어 하기 · 메뉴 줄 · 기록 줄.
// 바탕을 누르면 새 판(이어 하기 저장이 있으면 버릴지 먼저 묻는다 — 웹은 바로 지운다).

struct TitleView: View {
    @Bindable var session: GameSession

    var body: some View {
        let _ = session.lang
        let M = session.meta, st = session.content.stages
        ZStack {
            RadialGradient(colors: [Color(red: 10 / 255, green: 8 / 255, blue: 20 / 255).opacity(0.6), Color(red: 4 / 255, green: 3 / 255, blue: 10 / 255).opacity(0.92)],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 520)
                .background(PX.dark)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { session.request(RunRequest(kit: session.runKit, stage: session.runStage)) }
                // VoiceOver: 바탕 전체가 '출발' 버튼
                .accessibilityElement()
                .accessibilityLabel(session.hasSave ? KE("새로 출발", "Start over") : KE("출발", "Depart"))
                .accessibilityHint(KE("새 판을 시작해요", "Starts a new run"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { session.request(RunRequest(kit: session.runKit, stage: session.runStage)) }
            VStack(spacing: 12) {
                Spacer()
                logo
                Text(tr("LAST TRAIN · 서류가방 하나로 뉴욕 지하철을 접수한다")).font(.galmuriSmall(11)).foregroundStyle(PX.sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 14)
                TimelineView(.periodic(from: .now, by: 0.5)) { t in
                    HStack(spacing: 6) {
                        Text(KE("▶ 터치해서 \(session.hasSave ? "새로 " : "")출발", "▶ Tap to \(session.hasSave ? "start over" : "depart")"))
                            .font(.galmuri(12)).foregroundStyle(Color(px: "#fff1a0"))
                        Text("PRESS START").font(.galmuriSmall(10)).foregroundStyle(PX.note)
                    }
                    .opacity(Int(t.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)   // 바탕 '출발' 버튼이 같은 말을 한다
                if let S = session.runSave {
                    let short = S.stageIdx < st.count ? st[S.stageIdx].short : "?"
                    Button { session.continueRun() } label: {
                        Text(KE("이어 하기 · \(short)선 \(S.ci + 1)호차 · \(Int(S.score).formatted())점", "Continue · \(short) Line car \(S.ci + 1) · \(Int(S.score).formatted()) pts"))
                            .font(.galmuri(12, bold: true)).foregroundStyle(Color(px: "#1a1206"))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(PX.accent).overlay(Rectangle().stroke(PX.dark, lineWidth: 3))
                            .background(PX.dark.offset(x: 3, y: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(KE("이어 하기, \(short)선 \(S.ci + 1)호차, \(Int(S.score))점", "Continue, \(short) Line car \(S.ci + 1), \(Int(S.score)) points"))
                }
                FlowLayout(spacing: 6) {
                    menuButton(tr("새 판 설정"), .run)
                    menuButton(KE("오늘의 노선", "Daily"), .daily)
                    menuButton(tr("타워"), .tower)
                    menuButton(tr("도감"), .codex)
                    menuButton(tr("설정"), .sound)
                }
                .padding(.horizontal, 16)
                Text("\(st.map(\.short).joined(separator: " · ")) \(tr("노선")) · \(tr("최고")) \(Int(M.best.score))\(tr("점")) · \(M.runs)\(tr("판"))")
                    .font(.galmuriSmall(11)).foregroundStyle(Color(px: "#8a93ad"))
                if let e = session.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
                Spacer()
                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var logo: some View {
        HStack(alignment: .bottom, spacing: 6) {
            CaseIcon().frame(width: 40, height: 40).rotationEffect(.degrees(-6)).shadow(color: PX.dark, radius: 0, x: 3, y: 3)
            Text("BAG BOSS").font(.galmuri(40, bold: true)).foregroundStyle(Color(px: "#ffe27a")).lineLimit(1).fixedSize()
                .background(Text("BAG BOSS").font(.galmuri(40, bold: true)).foregroundStyle(PX.dark).offset(x: 6, y: 6))
                .background(Text("BAG BOSS").font(.galmuri(40, bold: true)).foregroundStyle(Color(px: "#e8322a")).offset(x: 3, y: 3))
            Text(tr("막차")).font(.galmuri(18, bold: true)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color(px: "#e8322a")).overlay(Rectangle().stroke(PX.dark, lineWidth: 3))
                .background(PX.dark.offset(x: 3, y: 3))
                .rotationEffect(.degrees(6))
        }
        .rotationEffect(.degrees(-3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(KE("배그 보스 막차", "Bag Boss: Last Train"))
        .accessibilityAddTraits(.isHeader)
    }

    private func menuButton(_ t: String, _ tab: MenuTab) -> some View {
        Button(t) { session.openMenu(tab) }.buttonStyle(PixelButtonLook(minHeight: 30))
    }
}

/// 타이틀 로고 옆 서류가방(웹 artURL('case') 대신 같은 색의 도트 가방)
struct CaseIcon: View {
    var body: some View {
        Canvas { c, s in
            let u = s.width / 12
            func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: String) { c.fill(Path(CGRect(x: x * u, y: y * u, width: w * u, height: h * u)), with: .color(Color(px: col))) }
            R(4, 1, 4, 1, "#0e0d14"); R(4, 2, 1, 2, "#0e0d14"); R(7, 2, 1, 2, "#0e0d14")
            R(0, 3, 12, 8, "#0e0d14"); R(1, 4, 10, 6, "#6a4226"); R(1, 4, 10, 1, "#9a6a3e"); R(1, 9, 10, 1, "#3a2414")
            R(5, 6, 2, 2, "#c08a24"); R(5, 6, 1, 1, "#ffe7a8"); R(1, 6, 10, 0.5, "#3a2414")
        }
        .drawingGroup()
    }
}
