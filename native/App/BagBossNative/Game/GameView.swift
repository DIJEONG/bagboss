import SwiftUI
import UIKit
import BBSim
import BBContent
import BBUI

// 게임 화면(세로) — 배치 둘(설정 › 개발자 › 레이아웃, 'bbn-layout'):
//   새 배치(기본): PlayScreen.swift — 무대 우선 + 바텀시트 가방(docs/09)
//   예전 배치: 위 무대(4:3 · Metal) + HUD → 행동 줄(진행 · 필살 · 속도 · 메뉴) → 가방(UIKit 격자)
// 흐름 화면(타이틀 · 매점 · 정리 · 환승 · 결과 · 일시정지)은 SwiftUI 덮개.

struct GameRootView: View {
    @State private var session: GameSession?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    /// 점검 탭(-render · -lab · -bag · -data)으로 실행했으면 탭 막대를 보인다
    private static let devLaunch = ["-render", "-lab", "-bag", "-data"].contains { ProcessInfo.processInfo.arguments.contains($0) }
    private var showTabs: Bool {
        guard let session else { return Self.devLaunch }
        return session.screen != .playing && (session.settings.devTabs || Self.devLaunch)
    }

    var body: some View {
        Group {
            if let session { GameView(session: session) }
            else if let error { Text(error).font(.footnote).foregroundStyle(.red).padding() }
            else { ProgressView(tr("불러오는 중…")).tint(.white).foregroundStyle(.white) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .toolbar(showTabs ? .visible : .hidden, for: .tabBar)   // 점검 탭 막대: 개발자 설정 · 점검 실행 인자일 때만, 판 중에는 늘 숨김(무대 · 가방 자리)
        .task {
            // 무거운 준비는 앱 init 에서 시작한 GameAssets 가 뒤 스레드에서 한다 — 타이틀은 core(데이터)만 기다린다
            guard session == nil else { return }
            BootTrace.mark("게임 탭 task")
            do {
                let core = try await GameAssets.shared.core()
                let s = BootTrace.measure("GameSession.init") { GameSession(core: core) }
                session = s
                #if DEBUG
                DebugLaunch.run(s)
                #endif
                do { s.attach(render: try await GameAssets.shared.render()) }
                catch { s.lastError = "렌더러 준비 실패: \(error)" }   // 타이틀은 그대로(출발만 안 된다)
            } catch { self.error = "게임 준비 실패: \(error)" }
        }
        .onChange(of: scenePhase) { _, p in
            guard let session else { return }
            if p == .background { session.didEnterBackground() }
            if p == .inactive { session.willResignActive() }
            if p == .active { session.willEnterForeground() }
        }
    }
}

enum Palette {
    static let bg = Color(red: 0.07, green: 0.06, blue: 0.12)
    static let panel = Color(red: 0.11, green: 0.1, blue: 0.17)
    static let line = Color(red: 0.35, green: 0.32, blue: 0.48)
    static let gold = Color(red: 1, green: 0.83, blue: 0.42)
    static let ink = Color(red: 0.055, green: 0.05, blue: 0.08)
}

struct GameView: View {
    @Bindable var session: GameSession

    var body: some View {
        GeometryReader { geo in
            if session.settings.layoutNew {
                let G = PlayGeometry(width: geo.size.width, height: geo.size.height, top: geo.safeAreaInsets.top, bottom: geo.safeAreaInsets.bottom, open: session.bagOpen)
                PlayScreen(session: session, G: G)
                    .overlay { overlays(geo, stageH: G.stageH, sheetTop: G.stageH) }
            } else {
                classic(geo)
            }
        }
        .background(Palette.bg)
        .statusBarHidden(true)
    }

    /// 예전 배치(비교용)
    @ViewBuilder private func classic(_ geo: GeometryProxy) -> some View {
            let w = geo.size.width, stageH = (w * 3 / 4).rounded()
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    GameStageView(session: session)
                    if session.screen == .playing { GameHUDView(hud: session.hud, view: session.view) }
                    if session.settings.devPerf { PerfOverlay(perf: session.perf).padding(.top, stageH - 16) }   // 개발자 설정에서만(기본 끔)
                }
                .frame(width: w, height: stageH)
                .clipped()
                ActionLine(session: session).frame(height: 54)
                BagHost(controller: session.bag)
                    .frame(width: w)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .overlay { overlays(geo, stageH: stageH, sheetTop: stageH + 54) }
    }

    /// stageH = 무대 아래 끝 · sheetTop = 가방(시트) 위 끝(안전 영역 안 좌표)
    @ViewBuilder private func overlays(_ geo: GeometryProxy, stageH: CGFloat, sheetTop: CGFloat) -> some View {
        ZStack {
            if session.screen == .title {
                TitleView(session: session)
            } else if case .news(let n)? = session.result {
                NewsResultView(info: n, session: session)
            } else if case .tower(let t)? = session.result {
                TowerResultView(r: t, session: session)
            } else if session.phase == "shop" && session.menuTab == nil {
                if session.settings.layoutNew { ShopPanel(session: session, stageH: stageH) }   // 새 배치: 무대 자리 안(시트 머리 · 섬 · 홈 막대와 안 겹침)
                else { ShopScreen(session: session) }
            } else if session.phase == "transfer" {
                TransferCard(session: session).allowsHitTesting(false)
            }
            // 보너스 결산판 · 도움말 · 대화(무대 위)
            if let b = session.bonusBoard {
                BonusBoardView(board: b).frame(width: min(300, geo.size.width * 0.66)).frame(width: geo.size.width, height: stageH).frame(maxHeight: .infinity, alignment: .top)
            }
            if let h = session.hintCard, session.menuTab == nil, session.result == nil {
                HintCardView(card: h).padding(.top, stageH - 92).frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity).allowsHitTesting(false)
            }
            if let t = session.talk, session.menuTab == nil {
                DialogView(talk: t, typer: session.typer, onTap: { session.talkTap() }, onPick: { session.talkPick($0) }, onSkip: { session.talkSkip() })
                    .padding(.horizontal, 8)
                    .frame(width: geo.size.width)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, max(30, stageH - 150))
            }
            if let d = session.dojoView, session.menuTab == nil, session.screen == .playing {
                DojoBar(session: session, dojo: d).frame(maxHeight: .infinity, alignment: .top).padding(.top, sheetTop)
            }
            if let tab = session.menuTab { MenuView(session: session, tab: tab) }
            if let c = session.confirm { ConfirmView(kind: c, session: session) }
        }
        .animation(.easeOut(duration: 0.15), value: session.hintCard)
    }
}

// MARK: 행동 줄(웹 #actionbar: 노선 · 남은 초 · 진행 막대 · 필살 · 속도 · 메뉴)

struct ActionLine: View {
    @Bindable var session: GameSession
    var body: some View {
        let hud = session.hud
        HStack(spacing: 8) {
            Button { session.openMenu(.run) } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 16, weight: .bold)).frame(width: 34, height: 34)
            }
            .buttonStyle(PixelButtonStyle())
            .accessibilityLabel(KE("일시정지 메뉴", "Pause menu"))
            VStack(alignment: .leading, spacing: 3) {
                Text(tr(hud.line)).font(.galmuriSmall(10)).foregroundStyle(.white).lineLimit(1)
                Text(tr(session.phase == "arrange" ? "정리 시간 \(session.arrangeLeft)초 — 가방을 손보고 출발" : hud.sub)).font(.galmuriSmall(9)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.black.opacity(0.6))
                        Rectangle().fill(Palette.gold).frame(width: g.size.width * CGFloat(hud.progress))
                    }
                }
                .frame(height: 3)
            }
            if session.phase == "arrange" {
                Button(tr("출발 ▶")) { session.enqueue(.advance) }.font(.galmuri(12, bold: true)).buttonStyle(PixelButtonStyle(accent: true))
                    .accessibilityLabel(KE("출발", "Depart"))
            }
            Button { session.special() } label: {
                ZStack(alignment: .bottom) {
                    Rectangle().fill(Color.black.opacity(0.6))
                    Rectangle().fill(hud.specialReady ? Color(red: 1, green: 0.5, blue: 0.2) : Color(red: 0.55, green: 0.4, blue: 0.9))
                        .frame(height: 38 * CGFloat(hud.special / 100))
                    Text(hud.specialReady ? tr("필살") : "\(Int(hud.special))%").font(.galmuriSmall(9)).foregroundStyle(.white).padding(.bottom, 12)
                }
                .frame(width: 44, height: 38)
                .overlay(Rectangle().stroke(hud.specialReady ? Palette.gold : Palette.line, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(KE("필살기", "Special"))
            .accessibilityValue(hud.specialReady ? KE("준비됨", "Ready") : "\(Int(hud.special))%")
            Button { session.cycleSpeed() } label: {
                Text(String(format: session.speed == session.speed.rounded() ? "%.0f×" : "%g×", session.speed)).font(.galmuri(11, bold: true)).frame(width: 40, height: 34)
            }
            .buttonStyle(PixelButtonStyle())
            .accessibilityLabel(KE("게임 속도", "Game speed"))
            .accessibilityValue(String(format: "%g", session.speed))
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(Palette.panel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Palette.line), alignment: .top)
    }
}

struct PixelButtonStyle: ButtonStyle {
    var accent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(accent ? Palette.ink : .white)
            .padding(.horizontal, accent ? 10 : 0).padding(.vertical, accent ? 7 : 0)
            .background(accent ? Palette.gold : Color(red: 0.2, green: 0.18, blue: 0.3))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

// MARK: 가방

struct BagHost: UIViewRepresentable {
    let controller: BagController
    /// classic = 웹 그대로 · sheet = 새 배치 시트(엄지 줄 오른쪽 reserve 폭은 SwiftUI 필살 자리)
    var style: BagLayoutStyle = .classic
    var reserve: CGFloat = 0
    var rowH: CGFloat = 72
    func makeUIView(context: Context) -> BagGridView {
        BootTrace.measure("가방 뷰") { let v = BagGridView(); v.layoutStyle = style; v.thumbReserve = reserve; v.thumbRowHeight = rowH; controller.attach(v); return v }
    }
    func updateUIView(_ v: BagGridView, context: Context) { v.layoutStyle = style; v.thumbReserve = reserve; v.thumbRowHeight = rowH }
}

// MARK: 흐름 화면

/// 매점(예전 배치 그대로) — 새 배치는 PlayScreen.swift ShopPanel
struct ShopScreen: View {
    @Bindable var session: GameSession
    var body: some View {
        let cat = session.data.catalog
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(tr("역 매점")).font(.galmuri(18, bold: true)).foregroundStyle(Palette.gold)
                Text(tr("하나를 고르면 보류함에 들어가요 · 토큰 \(session.tokens)")).font(.galmuriSmall(10)).foregroundStyle(.white.opacity(0.8))
                ForEach(Array(session.shopCards.enumerated()), id: \.offset) { k, c in
                    Button { session.enqueue(.shopPick(k)) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(tr(cat.item(c.id)?.name ?? c.id)).font(.galmuri(13, bold: true))
                                Text(String(repeating: "★", count: c.tier)).font(.galmuriSmall(10)).foregroundStyle(Palette.gold)
                                Spacer()
                                if let o = c.opt { Text("\(tr(cat.options[o.k]?.n ?? o.k)) +\(o.v < 1 ? String(format: "%.0f%%", o.v * 100) : String(format: "%g", o.v))").font(.galmuriSmall(9)).foregroundStyle(Color(red: 0.5, green: 0.85, blue: 1)) }
                            }
                            Text(tr(cat.item(c.id)?.desc ?? "")).font(.galmuriSmall(9)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.leading)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.panel).overlay(Rectangle().stroke(Palette.line, lineWidth: 2))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                }
                HStack(spacing: 10) {
                    Button(tr("새로고침 (2)")) { session.enqueue(.shopReroll) }.disabled(session.tokens < 2)
                    Button(tr("각인 (4)")) { session.enqueue(.shopCarve) }.disabled(session.tokens < 4)
                    Button(tr("지나가기")) { session.enqueue(.advance) }
                }
                .font(.galmuri(12)).buttonStyle(PixelButtonStyle())
            }
            .padding(16)
            .frame(maxWidth: 380)
        }
    }
}

struct TransferCard: View {
    @Bindable var session: GameSession
    var body: some View {
        let st = session.data.game.stages, k = session.transferTo
        VStack(spacing: 8) {
            Text(tr("환승")).font(.galmuriSmall(12)).foregroundStyle(.white.opacity(0.8))
            Text(tr(k < st.count ? st[k].name : "다음 노선")).font(.galmuri(22, bold: true)).foregroundStyle(Palette.gold)
            if k < st.count { Text(tr(st[k].intro)).font(.galmuriSmall(10)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center) }
        }
        .padding(20).frame(maxWidth: 340)
        .background(Palette.panel.opacity(0.95)).overlay(Rectangle().stroke(Palette.gold, lineWidth: 2))
        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 60)
    }
}
