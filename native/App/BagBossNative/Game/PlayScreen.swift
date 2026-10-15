import SwiftUI
import UIKit
import BBUI
import BBSim

// 게임 화면 새 배치(docs/09 · A안 '무대 우선 + 바텀시트 가방').
//   접힘(전투): 무대가 화면 약 63% · HUD 는 무대 가장자리(왼쪽 위 역 · 노선 / 오른쪽 위 점수 · 남은 시간 · 메뉴 / 왼쪽 아래 초상 · 체력 · 필살 게이지 — 캔버스)
//              아래 시트 = 머리(손잡이) + 엿보기 줄(지금 콤보 경로) + 엄지 줄(속도 · 가방 열기 · 큰 필살)
//   펼침(정리): 무대가 약 34% 로 줄고(장면 폭이 넓어져 싸움이 다 보인다) 가방이 폭을 다 쓴다 · 필살은 같은 자리
//              전투 중이면 가방을 만지는 것과 같은 길(bagTouch → 웹 bagSlowT 0.2배)로 시간이 느려진다(GameSession.frame)
//   시트 손짓은 머리(손잡이) 칸에만 — 타일 끌기와 겹치지 않는다.
// 예전 배치는 GameView(설정 › 개발자 › 레이아웃)에 그대로 남아 있다.

/// 무대 · 시트 높이(화면 비율 + 최소 · 최대 — 874pt 에 박지 않는다). 좌표는 안전 영역 안 기준
struct PlayGeometry {
    let width: CGFloat, height: CGFloat
    /// 위 · 아래 안전 여백
    let top: CGFloat, bottom: CGFloat
    let open: Bool
    /// 무대(장면) 높이 — 위 안전 여백 바로 아래부터
    let stageH: CGFloat
    /// 시트 높이(아래 안전 여백까지 가죽을 깐다)
    var sheetH: CGFloat { height + bottom - stageH }

    static let thumbH: CGFloat = 80, specialW: CGFloat = 150, headH: CGFloat = 44, side: CGFloat = 12
    /// 접힌 시트 최소(머리 44 + 엿보기 64 + 엄지 80 + 여백) · 펼친 시트 최소(머리 + 가방 칸 약 40pt)
    static let minPeek: CGFloat = 214, minOpen: CGFloat = 380
    /// 엿보기 띠: 글 줄(지금 · 다음) + 카드(최대 128pt). 이보다 남으면 무대에 돌려준다(시트 안 빈 자리 없게)
    static let peekTextH: CGFloat = 16, peekCardMax: CGFloat = 128
    /// 접힌 시트 본문 최대 = 머리 50 + 엿보기 띠 + 8 + 엄지 80 + 6
    static let maxPeekBody: CGFloat = (headH + 6) + (peekTextH + 4 + peekCardMax) + 8 + thumbH + 6

    init(width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat, open: Bool) {
        self.width = width; self.height = height; self.top = top; self.bottom = bottom; self.open = open
        let full = height + top + bottom
        // 위 안전 여백 포함 무대 몫: 접힘 63% · 펼침 34%(최소 · 최대)
        let total = open ? min(max(full * 0.34, 200), 340) : min(max(full * 0.63, 340), 620)
        let room = height + bottom - ((open ? Self.minOpen : Self.minPeek) + bottom)
        let base = max(open ? 140 : 200, floor(min(total - top, room)))
        // 시트가 내용보다 크면 남는 높이를 무대로: 접힘 = 엿보기 띠 최대 · 펼침 = 가방(폭을 다 쓰는 칸) + 작은 보관함 띠 + 엄지 줄
        let need = open ? (Self.headH + 6) + BagGridView.sheetPreferredHeight(forWidth: width, thumbRowHeight: Self.thumbH - 8) : Self.maxPeekBody
        stageH = max(base, floor(height - need))
    }
}

struct PlayScreen: View {
    @Bindable var session: GameSession
    let G: PlayGeometry

    var body: some View {
        VStack(spacing: 0) {
            PlayStage(session: session, G: G)
                .frame(width: G.width, height: G.stageH)
                .clipped()
            BagSheet(session: session, G: G)
                .frame(width: G.width, height: G.sheetH)
        }
        .frame(width: G.width, height: G.height, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: session.bagOpen)
        .environment(\.pixelFeedback) { session.buttonFeedback(sound: $0) }
    }
}

// MARK: 무대 + 가장자리 HUD

struct PlayStage: View {
    @Bindable var session: GameSession
    let G: PlayGeometry
    var body: some View {
        ZStack(alignment: .topLeading) {
            GameStageView(session: session)
            if session.screen == .playing {
                GameHUDView(hud: session.hud, view: session.view, bottomPad: 70)
                if session.slowed {   // 정리 중: 옅은 청록 막 + 칩(캔버스 테두리 · 글자는 웹 그대로)
                    Rectangle().fill(PX.calm.opacity(0.07)).allowsHitTesting(false)
                }
                PlayHUD(session: session)
            }
            if session.settings.devPerf { PerfOverlay(perf: session.perf).frame(maxHeight: .infinity, alignment: .bottom) }   // 개발자 설정에서만
        }
    }
}

/// 무대 위 SwiftUI HUD: 왼쪽 위 역 이름(정리 중이면 느림 칩) · 오른쪽 위 점수 · 남은 시간 · 적 수 · 메뉴
struct PlayHUD: View {
    @Bindable var session: GameSession
    var body: some View {
        let hud = session.hud
        HStack(alignment: .top, spacing: PXSpace.s) {
            VStack(alignment: .leading, spacing: 2) {
                if session.slowed && session.hudPlain {
                    SlowChip()
                } else if session.hudPlain {
                    Text(tr(hud.line)).font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.ink).inkShadow()
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
            if session.hudPlain {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%06d", session.score)).font(PXType.font(PXType.m, bold: true)).foregroundStyle(PX.ink).inkShadow()
                        .monospacedDigit()
                    if session.phase != "arrange" {   // 정리 남은 초는 '출발 ▶' 단추 한 곳에만
                        Text(Self.short(tr(hud.sub)))
                            .font(PXType.font(PXType.s)).foregroundStyle(PX.sub).inkShadow().lineLimit(1)
                    }
                }
                .padding(.top, 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(KE("점수 \(session.score)", "Score \(session.score)"))
            }
            Button { session.openMenu(.run) } label: {
                Image(systemName: "pause.fill").font(.system(size: 15, weight: .black))
            }
            .buttonStyle(PixelButton())
            .accessibilityLabel(KE("일시정지 메뉴", "Pause menu"))
        }
        .padding(.horizontal, PXSpace.s).padding(.top, PXSpace.xs)
        .overlay(alignment: .top) {   // 모드 HUD(복도 · 타워 …) 중엔 왼쪽 위가 캔버스 몫 — 칩을 가운데로
            if session.slowed && !session.hudPlain { SlowChip().padding(.top, PXSpace.xs + 2) }
        }
    }
    /// '48초 · 적 2 · 그랜드 스트리트까지' → '48초 · 적 2'(목적지는 노선도가 보여 준다). 번역은 통문장으로 먼저(조각은 사전에 없다)
    static func short(_ s: String) -> String { s.components(separatedBy: " · ").prefix(2).joined(separator: " · ") }
}

/// 정리 중 칩(시뮬레이션 bagSlowT 0.2배 — 웹 bagTouch 와 같은 값)
struct SlowChip: View {
    var body: some View {
        Text(KE("정리 중 · 0.2×", "Arranging · 0.2×"))
            .font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.calmInk)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(PX.calm).overlay(Rectangle().strokeBorder(PX.dark, lineWidth: 1))
            .accessibilityLabel(KE("정리 중, 시간이 느려졌어요", "Arranging, time slowed"))
    }
}

// MARK: 가방 시트

struct BagSheet: View {
    @Bindable var session: GameSession
    let G: PlayGeometry
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(session: session, open: G.open)
            if G.open {
                ZStack(alignment: .bottomTrailing) {
                    BagHost(controller: session.bag, style: .sheet, reserve: PlayGeometry.specialW, rowH: PlayGeometry.thumbH - 8)
                    SpecialButton(session: session)
                        .padding(.trailing, PlayGeometry.side).padding(.bottom, 6)
                }
                .padding(.bottom, G.bottom)
                .transition(.opacity)
            } else if session.padActive && session.phase != "arrange" {   // 직접 조작 패드(PadView)
                PadBody(session: session)
                    .padding(.horizontal, PlayGeometry.side)
                    .padding(.bottom, G.bottom + 4)
                    .transition(.opacity)
            } else {
                PeekBody(session: session)
                    .padding(.horizontal, PlayGeometry.side + 4)
                    .padding(.bottom, G.bottom + 6)
                    .transition(.opacity)
            }
        }
        .background(SheetSkin())
    }
}

/// 시트 바탕: 가죽 9-슬라이스(가방 틀과 같은 그림) — 위 테두리가 무대와의 경계
struct SheetSkin: View {
    var body: some View {
        Color.clear.pixelPanel(.frame)
            .padding(.bottom, -16)   // 아래 모서리는 화면 밖으로(시트가 바닥에 붙어 보이게)
    }
}

/// 시트 머리(손잡이): 끌어 올리면 펼침 · 끌어 내리면 접힘 · 누르면 바꿈. 가방 격자 위 손짓과 겹치지 않게 이 칸에서만
struct SheetHeader: View {
    @Bindable var session: GameSession
    let open: Bool
    var body: some View {
        VStack(spacing: 4) {
            Rectangle().fill(PX.leatherHi).frame(width: 40, height: 4).overlay(Rectangle().strokeBorder(PX.dark.opacity(0.5), lineWidth: 1))
            HStack(spacing: PXSpace.s) {
                Text(tr("서류가방")).font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.leatherDark)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(PX.label)
                    .fixedSize()
                Text(hint).font(PXType.font(PXType.s)).foregroundStyle(PX.sub)
                    .lineLimit(2).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 3) {
                    Image(uiImage: PX.tokenImage).interpolation(.none).resizable().frame(width: 14, height: 14)
                    Text("\(session.tokens)").font(PXType.font(PXType.m, bold: true)).foregroundStyle(PX.gold)
                }
                .fixedSize()
                .accessibilityElement(children: .combine).accessibilityLabel(KE("토큰 \(session.tokens)개", "\(session.tokens) tokens"))
            }
        }
        .padding(.horizontal, PlayGeometry.side + 4).padding(.top, 8)
        .frame(height: PlayGeometry.headH + 6, alignment: .top)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 8).onEnded { v in
            if v.translation.height < -20 { session.setBagOpen(true) } else if v.translation.height > 20 { session.setBagOpen(false) }
        })
        .onTapGesture { session.buttonFeedback(sound: true); session.setBagOpen(!open) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(open ? KE("가방 닫기", "Close bag") : KE("가방 열기", "Open bag"))
        .accessibilityAction { session.setBagOpen(!open) }
    }
    private var hint: String {
        if session.phase == "arrange" { return KE("끌어 옮기고 돌려 가방 손보기", "Drag & rotate to fix up the bag") }   // 남은 초는 '출발 ▶' 단추에만
        if !open { return KE("▲ 밀어 올려 정리 · 시간 느려짐", "▲ Swipe up to arrange · time slows") }
        return session.bag.editor.inCombat
            ? KE("▼ 내려서 닫기 · 옮긴 기술은 쿨다운이 처음부터", "▼ Swipe down · moved skills restart cooldown")
            : KE("▼ 내려서 닫기 · 끌어 놓으면 화력 미리 보기", "▼ Swipe down · drag to preview damage")
    }
}

/// 접힌 시트 본문: 엿보기 띠(글 줄 '지금 k/n · 경로 / 다음 ▶ 기술' + 같은 크기 콤보 카드 한 줄) + 엄지 줄
struct PeekBody: View {
    @Bindable var session: GameSession
    var body: some View {
        VStack(spacing: PXSpace.s) {
            VStack(alignment: .leading, spacing: 4) {
                PeekText(peek: session.peek)
                    .frame(height: PlayGeometry.peekTextH)
                PeekHost(controller: session.bag)
                    .frame(maxWidth: .infinity, maxHeight: PlayGeometry.peekCardMax)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            HStack(alignment: .bottom, spacing: PXSpace.s) {
                Button { session.cycleSpeed() } label: {
                    VStack(spacing: 1) {
                        Text(String(format: session.speed == session.speed.rounded() ? "%.0f×" : "%g×", session.speed)).font(PXType.font(PXType.m, bold: true))
                        Text(tr("속도")).font(PXType.font(PXType.s)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(PixelButton(minWidth: 64, minHeight: PlayGeometry.thumbH, sound: false))   // cycleSpeed 가 딸깍을 낸다
                .accessibilityLabel(KE("게임 속도", "Game speed")).accessibilityValue(String(format: "%g", session.speed))
                Button { session.setBagOpen(true) } label: {
                    VStack(spacing: 2) {
                        Text(KE("가방 열기", "Open bag")).font(PXType.font(PXType.m, bold: true)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(KE("위로 밀어도 돼요", "or swipe up")).font(PXType.font(PXType.s)).foregroundStyle(PX.muted).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelButton(minHeight: PlayGeometry.thumbH))   // 엄지 줄은 모두 필살과 같은 높이(위 빈 틈 없게)
                .accessibilityLabel(KE("가방 열기", "Open bag"))
                SpecialButton(session: session)
            }
        }
    }
}

/// 엿보기 글 줄: 왼쪽 '지금 k/n · 경로 이름(· 콤보 n개)' · 오른쪽 '다음 ▶ 기술'. 좁으면 콤보 수를 빼고 그래도 넘치면 줄인다(자르지 않음)
struct PeekText: View {
    let peek: PeekInfo
    var body: some View {
        Group {
            if peek.count > 0 {
                ViewThatFits(in: .horizontal) {
                    line(routes: true, scale: 1)
                    line(routes: false, scale: 1)
                    line(routes: false, scale: 0.75)
                }
            } else {
                Text(KE("콤보 없음", "No combo"))
                    .font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.note).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .accessibilityElement(children: .combine)
    }
    private func line(routes: Bool, scale: CGFloat) -> some View {
        HStack(spacing: PXSpace.s) {
            (now + (routes && peek.routes > 1 ? Text(KE(" · 콤보 \(peek.routes)개", " · \(peek.routes) combos")).foregroundColor(PX.note) : Text("")))
                .font(PXType.font(PXType.s * scale, bold: true)).foregroundStyle(PX.ink)
            Spacer(minLength: PXSpace.s)
            if !peek.next.isEmpty {
                Text(KE("다음 ▶ ", "Next ▶ ") + tr(peek.next)).font(PXType.font(PXType.s * scale)).foregroundStyle(PX.gold)
            }
        }
        .lineLimit(1).minimumScaleFactor(scale < 1 ? 0.7 : 1).fixedSize(horizontal: scale == 1, vertical: false)
    }
    private var now: Text {
        peek.live ? Text(KE("지금 \(min(peek.step, peek.count))/\(peek.count) · ", "Now \(min(peek.step, peek.count))/\(peek.count) · ")) + Text(tr(peek.name)) : Text(tr(peek.name))
    }
}

/// 큰 필살 단추(150×80 · 접힘 · 펼침 모두 오른쪽 아래 같은 자리). 정리 단계에선 '출발'
struct SpecialButton: View {
    @Bindable var session: GameSession
    var body: some View {
        let hud = session.hud, arrange = session.phase == "arrange", ready = hud.specialReady
        let k = max(0, min(1, hud.special / 100))
        Button { arrange ? session.enqueue(.advance) : session.special() } label: {
            ZStack(alignment: .bottom) {
                if !arrange && !ready {   // 모으는 중: 아래부터 차오르는 게이지
                    Rectangle().fill(Color(px: "#7a5ad8").opacity(0.55)).frame(height: (PlayGeometry.thumbH - 10) * k)
                }
                VStack(spacing: 2) {
                    Text(arrange ? tr("출발 ▶") : tr("필살")).font(PXType.font(PXType.l, bold: true))
                    Text(arrange ? departNote : ready ? KE("탭! 지금 쓸 수 있어요", "Ready — tap!") : KE("모으는 중 \(Int(hud.special))%", "Charging \(Int(hud.special))%"))
                        .font(PXType.font(PXType.s, bold: true)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: PlayGeometry.specialW - 16, height: PlayGeometry.thumbH - 10)
        }
        .buttonStyle(PixelButton(kind: arrange || ready ? .hot : .plate, minWidth: PlayGeometry.specialW, minHeight: PlayGeometry.thumbH))
        .accessibilityLabel(arrange ? KE("출발", "Depart") : KE("필살기", "Special"))
        .accessibilityValue(arrange ? departNote : ready ? KE("준비됨", "Ready") : "\(Int(hud.special))%")
    }
}

extension SpecialButton {
    /// 정리 남은 초 — 화면에서 이 한 곳만(웹 arrTouched: 가방을 만지면 자동 출발이 멈춘다)
    var departNote: String {
        session.arrangeHeld ? KE("준비되면 눌러요", "Tap when ready") : KE("\(session.arrangeLeft)초 뒤 자동", "Auto in \(session.arrangeLeft)s")
    }
}

// MARK: 매점(새 배치)

/// 새 배치 매점 판: 무대 자리(위 안전 여백 아래 ~ 시트 머리 위)에만 띄운다 — 시트 머리 · 섬 · 홈 막대와 겹치지 않는다.
/// 막(어둡게)은 화면 전체(시트도 못 누름 — 예전 매점 덮개와 같게). 카드가 넘치면 카드만 굴린다. 단추는 PixelButton(44pt 이상)
struct ShopPanel: View {
    @Bindable var session: GameSession
    /// 무대 아래 끝(안전 영역 안 좌표) — 판은 이 위에만
    let stageH: CGFloat
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: PXSpace.s) {
                HStack(alignment: .firstTextBaseline, spacing: PXSpace.s) {
                    Text(tr("역 매점")).font(PXType.font(PXType.l, bold: true)).foregroundStyle(PX.gold).inkShadow()
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Image(uiImage: PX.tokenImage).interpolation(.none).resizable().frame(width: 14, height: 14)
                        Text("\(session.tokens)").font(PXType.font(PXType.m, bold: true)).foregroundStyle(PX.gold)
                    }
                    .fixedSize()
                    .accessibilityElement(children: .combine).accessibilityLabel(KE("토큰 \(session.tokens)개", "\(session.tokens) tokens"))
                }
                Text(KE("하나를 고르면 보류함에 들어가요", "Pick one — it goes to Holding"))
                    .font(PXType.font(PXType.s)).foregroundStyle(PX.sub)
                    .lineLimit(2).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
                ViewThatFits(in: .vertical) {
                    cards
                    ScrollView(.vertical, showsIndicators: true) { cards.padding(.bottom, 2) }
                }
                HStack(spacing: PXSpace.s) {
                    Button { session.enqueue(.shopReroll) } label: { cost(tr("새로고침"), BagSpec.rerollCost) }
                        .buttonStyle(PixelButton())
                        .disabled(session.tokens < BagSpec.rerollCost)
                        .accessibilityLabel(KE("새로고침, 토큰 \(BagSpec.rerollCost)개", "Reroll, \(BagSpec.rerollCost) tokens"))
                    Button { session.enqueue(.shopCarve) } label: { cost(KE("각인", "Carve"), 4) }
                        .buttonStyle(PixelButton())
                        .disabled(session.tokens < 4)
                        .accessibilityLabel(KE("각인 새기기, 토큰 4개", "Carve imprint, 4 tokens"))
                    Button { session.enqueue(.advance) } label: {
                        Text(tr("지나가기")).font(PXType.font(PXType.m, bold: true)).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButton(kind: .brass))
                    .accessibilityLabel(KE("고르지 않고 지나가기", "Skip"))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, PXSpace.m + 4).padding(.vertical, PXSpace.m + 2)
            .pixelPanel(.frame)
            .padding(.horizontal, PXSpace.s).padding(.top, PXSpace.s)
            .frame(maxHeight: max(160, stageH - PXSpace.s), alignment: .top)
        }
    }
    /// '새로고침 ⓣ2' — 이름 + 동전 + 값
    private func cost(_ name: String, _ n: Int) -> some View {
        HStack(spacing: 3) {
            Text(name).font(PXType.font(PXType.m, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
            Image(uiImage: PX.tokenImage).interpolation(.none).resizable().frame(width: 14, height: 14)
            Text("\(n)").font(PXType.font(PXType.m, bold: true)).foregroundStyle(PX.gold).fixedSize()
        }
        .frame(maxWidth: .infinity)
    }
    private var cards: some View {
        let cat = session.data.catalog
        return VStack(spacing: PXSpace.s) {
            ForEach(Array(session.shopCards.enumerated()), id: \.offset) { k, c in
                Button { session.enqueue(.shopPick(k)) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: PXSpace.xs) {
                            Text(tr(cat.item(c.id)?.name ?? c.id)).font(PXType.font(PXType.m, bold: true)).foregroundStyle(PX.ink)
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Text(String(repeating: "★", count: c.tier)).font(PXType.font(PXType.s)).foregroundStyle(PX.gold).fixedSize()
                            Spacer(minLength: PXSpace.xs)
                            if let o = c.opt {
                                Text("\(tr(cat.options[o.k]?.n ?? o.k)) +\(o.v < 1 ? String(format: "%.0f%%", o.v * 100) : String(format: "%g", o.v))")
                                    .font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.calm).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        Text(tr(cat.item(c.id)?.desc ?? "")).font(PXType.font(PXType.s)).foregroundStyle(PX.muted)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, PXSpace.s).padding(.horizontal, PXSpace.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PixelButton())
            }
        }
    }
}

// MARK: UIKit 잇기

struct PeekHost: UIViewRepresentable {
    let controller: BagController
    func makeUIView(context: Context) -> BagPeekView { let v = BagPeekView(); controller.attachPeek(v); return v }
    func updateUIView(_ v: BagPeekView, context: Context) {}
}

extension PX {
    /// 토큰 동전(가방 머리줄과 같은 그림)
    nonisolated(unsafe) static let tokenImage: UIImage = UIImage(cgImage: bbUpscale(BagPixelSkin.shared.token, 2))
}
