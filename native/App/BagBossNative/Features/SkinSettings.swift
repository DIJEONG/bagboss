import SwiftUI

// 메뉴 › 설정에 붙는 2단계 A 조각(웹 36-meta-menu 설정 탭 '주인공' 섹션 + 기타 바로 가기).
//   스킨 칸: 가진(무료 · 산) 스킨은 눌러 바로 입고, 잠긴 스킨은 누르면 미리보기(가격만 보인다 — 결제 강요 없음).
//   '미리보기 ▶'(웹 data-skinpv) · '구매 복원' · '콤보 연구실 ▶'(웹 jumpTo('dojo')) · Game Center.

struct SkinSettingsGrid: View {
    @Bindable var session: GameSession
    @State private var store = SkinStore.shared
    var body: some View {
        let hub = FeatureHub.shared
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(session.content.skinKeys, id: \.self) { k in
                    if let S = session.content.skins[k] {
                        let on = session.settings.skin == k, open = store.isUnlocked(k)
                        Button {
                            session.audio.play(.click)
                            if open { hub.equip(k) } else { hub.openSkinPreview(k) }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 0) { ForEach(S.sw, id: \.self) { c in Rectangle().fill(Color(px: c)).frame(width: 12, height: 10) } }
                                    .overlay(Rectangle().stroke(PX.dark, lineWidth: 1))
                                HStack(spacing: 4) {
                                    Text(tr(S.n)).font(.galmuri(11, bold: true)).foregroundStyle(on ? PX.brass : PX.lilac)
                                    Spacer(minLength: 0)
                                    Text(tag(k, open: open, on: on)).font(.galmuriSmall(9)).foregroundStyle(open ? (on ? PX.brass : PX.gold) : Color(px: "#ff7a5c"))
                                }
                                Text(tr(S.sub)).font(.galmuriSmall(9)).foregroundStyle(on ? PX.brass : PX.muted).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            .pixelPanel(on ? .btn : .plate)
                            .opacity(open ? 1 : 0.8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(open ? KE("눌러서 입기", "Tap to wear") : KE("눌러서 미리보기", "Tap to preview"))
                    }
                }
            }
            HStack(spacing: 6) {
                Button(tr("미리보기 ▶")) { session.audio.play(.click); hub.openSkinPreview() }.buttonStyle(PixelButtonLook(brass: true))
                Button(store.restoring ? KE("복원 중…", "Restoring…") : KE("구매 복원", "Restore purchases")) { Task { await store.restore() } }
                    .buttonStyle(PixelButtonLook()).disabled(store.restoring)
            }
            if let n = store.notice { MMNote(t: n).onTapGesture { store.notice = nil } }
        }
    }

    private func tag(_ k: String, open: Bool, on: Bool) -> String {
        if on { return tr("착용 중") }
        if store.isFree(k) { return tr("기본") }
        if open { return KE("보유", "Owned") }
        return store.price(k) ?? tr("유료")
    }
}

/// 설정 › 기타 바로 가기
struct FeatureMenuButtons: View {
    @Bindable var session: GameSession
    var body: some View {
        Button(KE("콤보 연구실 ▶", "Combo lab ▶")) { session.audio.play(.click); session.openDojo() }.buttonStyle(PixelButtonLook())
        GameCenterButton()
    }
}

/// Game Center 대시보드(로그인 안 됐으면 로그인 화면 또는 안내)
struct GameCenterButton: View {
    var compact = false
    @State private var gc = GameCenterService.shared
    var body: some View {
        Button {
            gc.openDashboard()
        } label: {
            Label(compact ? KE("순위", "Ranks") : "Game Center", systemImage: "trophy").labelStyle(.titleAndIcon)
        }
        .buttonStyle(PixelButtonLook(minHeight: compact ? 40 : 32))
        .accessibilityLabel(KE("Game Center 순위표", "Game Center leaderboards"))
        .alert("Game Center", isPresented: Binding(get: { gc.notice != nil }, set: { if !$0 { gc.notice = nil } })) {
            Button(KE("확인", "OK"), role: .cancel) { gc.notice = nil }
        } message: { Text(gc.notice ?? "") }
    }
}
