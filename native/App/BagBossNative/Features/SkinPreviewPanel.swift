import SwiftUI
import BBSim

// 스킨 미리보기(웹 13-rig-grammar skinPvOpen · skinPvRender + 14-pose-editor 보기 조절).
//   무대: 무도장 판 위에서 주인공만 남기고 가운데로(SkinPreviewCommand.open — 서기 → 걷기 → 몸짓 gx_<스킨> → 한 바퀴 → 돌려차기 9.2초 주기)
//   아래(가방 자리): 스킨 목록(견본 3색 · 이름 · 부제 · 착용 중/기본/가격) · 특징(전용 옷 · 몸짓 · 마무리 연출) · 입기/사기 · 보기 조절.
//   잠긴 유료 스킨도 미리보기는 언제나 된다(결제 강요 없음). 사기는 StoreKit 2(SkinStore).

/// 웹 SKINS 전체 값(FlowContent.Skin 에 없는 몸짓 · 마무리 연출 · 강조색까지)
struct SkinInfo: Decodable { let n: String; let sub: String; let sw: [String]; let free: Bool?; let gx: String?; let fl: String?; let acc: String? }

struct SkinPreviewPanel: View {
    @Bindable var session: GameSession
    @State private var hub = FeatureHub.shared
    @State private var store = SkinStore.shared
    @State private var view = 0.0
    @State private var close = false
    @State private var mode = "auto"

    @MainActor private static var infoCache: [String: SkinInfo]?
    private var infos: [String: SkinInfo] {
        if let c = Self.infoCache { return c }
        let v: [String: SkinInfo] = (try? session.store.decode("SKINS")) ?? [:]
        Self.infoCache = v; return v
    }

    var body: some View {
        let keys = session.content.skinKeys, k = hub.previewSkin, S = infos[k]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("스킨")).font(.galmuri(14, bold: true)).foregroundStyle(PX.gold).inkShadow()
                Text(KE("미리보기는 언제나 무료예요", "Previews are always free")).font(.galmuriSmall(10)).foregroundStyle(PX.note)
                Spacer()
                Button(hub.previewFromDojo ? KE("무도장으로", "Back to lab") : tr("닫기")) { if hub.previewFromDojo { hub.closeSkinPreview() } else { hub.exitDojo() } }.buttonStyle(PixelButtonLook(brass: true, minHeight: 28))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(keys, id: \.self) { kk in
                        if let Q = infos[kk] { skinCard(kk, Q, on: kk == k) }
                    }
                }
            }
            if let S {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tr(S.n)).font(.galmuri(13, bold: true)).foregroundStyle(S.acc.map { Color(px: $0) } ?? PX.ink)
                        Text(store.isFree(k) ? tr("기본 스킨") : (store.isUnlocked(k) ? KE("구매함", "Owned") : tr("유료 스킨"))).font(.galmuriSmall(10)).foregroundStyle(PX.note)
                    }
                    Text("· " + tr("전용 옷 · 컷인 초상화")).font(.galmuriSmall(10)).foregroundStyle(PX.ink)
                    if let g = S.gx { Text("· \(tr("제스처")) · \(tr(g))").font(.galmuriSmall(10)).foregroundStyle(PX.ink) }
                    if let f = S.fl { Text("· \(tr("마무리 연출")) · \(tr(f))").font(.galmuriSmall(10)).foregroundStyle(PX.ink) }
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading).pixelPanel(.plate)
            }
            actionRow(k)
            if let n = store.notice {
                Text(n).font(.galmuriSmall(10)).foregroundStyle(Color(px: "#ff9a7a")).fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { store.notice = nil }
            }
            // 보기 조절(웹 자세 편집기 V.play · V.view · V.z1 — 주인공만 보는 확인용)
            HStack(spacing: 4) {
                Button(KE("자동", "Auto")) { mode = "auto"; session.enqueue(.skinPreview(.fixed(nil))) }.buttonStyle(PixelButtonLook(brass: mode == "auto", minHeight: 26))
                ForEach([("gx", tr("제스처")), ("round", tr("돌려차기")), ("walk", KE("걷기", "Walk"))], id: \.0) { a in
                    Button(a.1) {
                        mode = a.0
                        session.enqueue(.skinPreview(.fixed(nil)))
                        session.enqueue(.skinPreview(.play(a.0 == "gx" ? "gx_" + k : a.0)))
                    }
                    .buttonStyle(PixelButtonLook(brass: mode == a.0, minHeight: 26))
                }
                Spacer(minLength: 0)
                Toggle(KE("멀리", "Wide"), isOn: $close).toggleStyle(.button).font(.galmuriSmall(10)).tint(PX.accent)
                    .onChange(of: close) { _, z in session.enqueue(.skinPreview(.z1(z))) }
            }
            .font(.galmuriSmall(10))
            HStack(spacing: 6) {
                Text(KE("돌려 보기", "Turn")).font(.galmuriSmall(10)).foregroundStyle(PX.note)
                Slider(value: $view, in: -180...180, step: 15).tint(PX.accent)
                    .onChange(of: view) { _, v in session.enqueue(.skinPreview(.view(v))) }
                Text("\(Int(view))°").font(.galmuri(10, bold: true)).foregroundStyle(PX.ink).frame(width: 40)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
    }

    private func skinCard(_ k: String, _ Q: SkinInfo, on: Bool) -> some View {
        Button { mode = "auto"; view = 0; hub.previewSkinChange(k) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) { ForEach(Q.sw, id: \.self) { c in Rectangle().fill(Color(px: c)).frame(width: 12, height: 10) } }
                    .overlay(Rectangle().stroke(PX.dark, lineWidth: 1))
                Text(tr(Q.n)).font(.galmuri(11, bold: true)).foregroundStyle(on ? PX.brass : PX.lilac).lineLimit(1)
                Text(tr(Q.sub)).font(.galmuriSmall(9)).foregroundStyle(on ? PX.brass : PX.muted).lineLimit(2).frame(width: 112, alignment: .leading)
                Text(badge(k)).font(.galmuriSmall(9)).foregroundStyle(store.isUnlocked(k) ? (on ? PX.brass : PX.gold) : Color(px: "#ff9a7a"))
            }
            .padding(7).frame(width: 128, alignment: .leading)
            .pixelPanel(on ? .btn : .plate)
        }
        .buttonStyle(.plain)
    }

    /// 착용 중 · 기본 · 가진 것 · 가격(웹 skinPvRender em)
    private func badge(_ k: String) -> String {
        if session.settings.skin == k { return tr("착용 중") }
        if store.isFree(k) { return tr("기본") }
        if store.isUnlocked(k) { return KE("보유", "Owned") }
        return store.price(k) ?? (store.productsLoaded ? KE("판매 준비 중", "Unavailable") : tr("유료"))
    }

    @ViewBuilder private func actionRow(_ k: String) -> some View {
        if hub.previewFromDojo {
            // 무도장: 어떤 스킨이든 골라 싸워 보기(착용 · 구매와 별개)
            HStack(spacing: 6) {
                Button(KE("무도장에서 쓰기", "Use in lab")) { hub.useInDojo(k) }
                    .buttonStyle(PixelButtonLook(brass: true, minHeight: 36))
                    .accessibilityHint(KE("무도장에서만 이 스킨으로 싸워요. 착용 스킨은 바뀌지 않아요", "Fight with this skin in the lab only"))
                Text(KE("무도장 전용 · 착용은 그대로", "Lab only · equipped skin unchanged")).font(.galmuriSmall(9)).foregroundStyle(PX.note).lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        HStack(spacing: 6) {
            if session.settings.skin == k {
                Text(tr("착용 중")).font(.galmuri(12, bold: true)).foregroundStyle(PX.gold).frame(minHeight: 36)
            } else if store.isUnlocked(k) {
                Button(KE("입기", "Wear")) { hub.equip(k) }.buttonStyle(PixelButtonLook(brass: true, minHeight: 36))
            } else {
                Button {
                    Task { if await store.purchase(k) { hub.equip(k) } }
                } label: {
                    Text(store.purchasing == k ? KE("결제 중…", "Purchasing…") : "\(KE("사기", "Buy")) · \(store.price(k) ?? "—")")
                }
                .buttonStyle(PixelButtonLook(brass: true, minHeight: 36))
                .disabled(store.purchasing != nil || store.price(k) == nil)
            }
            Button(store.restoring ? KE("복원 중…", "Restoring…") : KE("구매 복원", "Restore")) { Task { await store.restore() } }
                .buttonStyle(PixelButtonLook(minHeight: 36)).disabled(store.restoring)
            Spacer(minLength: 0)
        }
    }
}
