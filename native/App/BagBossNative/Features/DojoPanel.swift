import SwiftUI
import UIKit
import BBContent
import BBSim
import BBPersistence

// 무도장 · 콤보 실험실 패널(웹 42-dojo.js showDojoPanel — 무대 바로 아래부터 가방 자리를 채운다).
//   도구: 나가기 · 재생/멈춤 · 한 프레임 · 반복 · 초기화 · 스킨 | 속도 · 확대 | 탭: 콤보 · 커스텀 · 기술 · 반응 + 상대 ▾ · 배경 ▾
//   (웹은 제목 줄 · 상대/배경 줄이 따로지만, 무대 아래 자리가 좁아 세 줄을 접었다 — 16단 콤보 편집에 자리를 준다)
//   모든 단추는 SimIntent.dojo(DojoCommand) — 웹 djDo 와 같은 명령(시뮬레이션이 실전 경로 useSkill 로 재생).
//   멈춤은 시뮬레이션 쪽 멈춤(SimIntent.pause) — 화면 프레임은 계속 돌아야 '한 프레임'(DojoCommand.step)이 처리된다.
//   커스텀 콤보는 'dotlab-cc'(BBPersistence CustomCombo — 웹과 같은 키 · 같은 모양, 네이티브 최대 16단 · 웹은 앞 8개만 읽는다)에 저장.
//   패널 설정(웹 OPT.djTab · djZoom · djbg · djDummy)은 dotlab-opt extras 에 웹과 같은 이름으로 남긴다.
// 스킨 미리보기 중이면 같은 자리에 SkinPreviewPanel 을 보인다.

struct DojoPanel: View {
    @Bindable var session: GameSession
    let dojo: DojoView
    @State private var hub = FeatureHub.shared
    /// 시뮬레이션 멈춤 · 속도(패널이 보낸 값)
    @State private var simPaused = false
    @State private var speed = 1.0
    /// 마지막으로 누른 재생 단추(웹 .last)
    @State private var lastKey: String?
    /// 커스텀 콤보(저장본이 기준 — 시뮬레이션에는 실행할 때 넘긴다)
    @State private var cc: [String] = CustomCombo.defaultSteps
    @State private var ranCC: [String]?
    /// 단계 편집(길게 누른 칸) · 누르고 있는 칸(눌림 표시) · 편집 중 끌고 있는 칸과 손가락 자리(편집 격자 좌표) · 편집 격자 크기
    @State private var editK: Int?
    @State private var pressK: Int?
    @State private var dragK: Int?
    @State private var dragAt: CGPoint = .zero
    @State private var gridSize: CGSize = .zero
    @State private var routesTick = 0

    var body: some View {
        if hub.skinPreview && hub.poseEditor {
            PoseEditorPanel(session: session)   // 자세 편집기(개발자 도구)
        } else if hub.skinPreview {
            SkinPreviewPanel(session: session)
        } else {
            panel
        }
    }

    private var C: DojoCatalog { hub.dojoCatalog }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 5) {
            tools
            HStack(spacing: 8) {
                seg(tr("속도"), [(0.1, ".1"), (0.25, ".25"), (0.5, ".5"), (1, "1×")], speed) { setSpeed($0) }
                seg(tr("확대"), [(1, "1×"), (1.5, "1.5×"), (2, "2×")], dojo.zoom) { z in session.dojo(.zoom(z)); hub.saveOption("djZoom", .number(z)) }
                seg(KE("치명", "Crit"), [(true, KE("켬", "On")), (false, KE("끔", "Off"))], dojo.crit) { on in session.dojo(.crit(on)); hub.saveOption("djCrit", .bool(on)) }   // 새 저장 키
            }
            // 탭 + 상대 · 배경(두 줄이던 것을 펼침 메뉴 둘로 — 아래 콤보 편집에 자리를 준다)
            HStack(spacing: 5) {
                PixelTabs(items: [("combo", tr("콤보")), ("custom", tr("커스텀")), ("move", tr("기술")), ("react", tr("반응")), ("props", KE("소품", "Props"))],
                          selection: Binding(get: { hub.dojoTab }, set: { hub.setDojoTab($0); editK = nil }), scroll: true, onPick: { session.audio.play(.click) })
                pickMenu(tr("상대"), C.dummies.map { ($0.key, tr($0.name)) }, dojo.dummyType) { d in session.dojo(.dummy(d)); hub.saveOption("djDummy", .string(d)) }
                pickMenu(tr("배경"), [("dojo", tr("무도장")), ("cross", tr("건널목")), ("snow", tr("눈 승강장")), ("beach", tr("해변 · 오후")), ("beach_dusk", tr("해변 · 노을")), ("beach_night", tr("해변 · 밤"))], dojo.bg) { b in session.dojo(.background(b)); hub.saveOption("djbg", .string(b)) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if hub.dojoTab != "custom" {   // 마지막 결과(예전 제목 줄 자리 — 커스텀 탭은 콤보 머리에)
                        Text(dojo.result.map(tr) ?? tr("동작을 골라 바로 연습해요")).font(.galmuriSmall(10))
                            .foregroundStyle(dojo.result == nil ? PX.note : PX.ink).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    switch hub.dojoTab {
                    case "custom": customPane
                    case "move": movePane
                    case "react": reactPane
                    case "props": propsPane
                    default: comboPane
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 8).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
        .overlay {   // 길게 누른 단계 편집(패널 자리만 덮는다 — 무대는 그대로 보인다)
            if hub.dojoTab == "custom", let k = editK, cc.indices.contains(k) {
                stepEditor(k).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: editK == nil)
        .onAppear(perform: restore)
        .onChange(of: dojo.objs.map { "\($0.kind)@\(Int($0.x))" }) { _ in saveObjs(dojo.objs) }
    }

    // MARK: 도구(머리 줄 — 제목 줄을 없애고 나가기 · 스킨을 도구 줄 양 끝에)

    private var tools: some View {
        ViewThatFits(in: .horizontal) { toolRow(0); toolRow(1); toolRow(2) }
    }

    /// level: 0 = 글자 모두 · 1 = 한 프레임만 기호(402pt) · 2 = 반복 · 초기화도 기호(SE 375pt)
    private func toolRow(_ level: Int) -> some View {
        let short = level >= 2
        return HStack(spacing: 5) {
            Button(tr("나가기")) { hub.exitDojo() }.buttonStyle(PixelButtonLook(brass: true, minHeight: 30))
                .accessibilityHint(KE("들어오기 전의 판으로 돌아가요", "Return to the run you left"))
            Button(simPaused ? "▶ " + tr("재생") : "❚❚ " + tr("멈춤")) { setPaused(!simPaused) }
                .buttonStyle(PixelButtonLook(brass: simPaused, minHeight: 30))
            Button(level >= 1 ? "⇥" : "⇥ " + tr("한 프레임")) { session.dojo(.step) }.buttonStyle(PixelButtonLook(minHeight: 30)).disabled(!simPaused)
                .accessibilityLabel(tr("한 프레임")).accessibilityHint(tr("멈춘 상태에서 한 프레임(1/12초)씩"))
            Button(short ? "⟲" : "⟲ " + tr("반복")) { session.dojo(.loop(!dojo.rep)) }.buttonStyle(PixelButtonLook(brass: dojo.rep, minHeight: 30))
                .accessibilityLabel(tr("반복")).accessibilityAddTraits(dojo.rep ? .isSelected : [])
            Button(short ? "↺" : "↺ " + tr("초기화")) { session.dojo(.reset) }.buttonStyle(PixelButtonLook(minHeight: 30))
                .accessibilityLabel(tr("초기화"))
            Spacer(minLength: 0)
            if session.settings.devUnlocked {   // 개발자 칸이 열렸을 때만 — 자세 편집기
                Button(short ? KE("자세", "Pose") : tr("자세 편집기")) { hub.openPoseEditor() }.buttonStyle(PixelButtonLook(minHeight: 30))
                    .accessibilityLabel(tr("자세 편집기"))
            }
            Button(tr("스킨")) { hub.openSkinPreview() }.buttonStyle(PixelButtonLook(minHeight: 30))
        }
        .lineLimit(1)
    }

    private func seg<V: Equatable>(_ label: String, _ items: [(V, String)], _ cur: V, _ pick: @escaping (V) -> Void) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.galmuriSmall(9)).foregroundStyle(PX.note)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        Button(it.1) { pick(it.0) }
                            .font(.galmuriSmall(10))
                            .buttonStyle(PixelButtonLook(brass: it.0 == cur, minHeight: 24))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 상대 · 배경 펼침 메뉴(작은 이름표 + 지금 값 ▾)
    ///   패널은 DojoView(행인 · 시연 시각)가 바뀔 때마다 매 프레임 다시 그려진다 — 메뉴를 같이 다시 만들면
    ///   열린 메뉴 항목이 계속 바뀌어 시뮬레이터(마우스 클릭)에서 선택이 안 먹었다 → 이름표 · 항목 · 지금 값이 같으면 다시 그리지 않는다
    private func pickMenu(_ label: String, _ items: [(String, String)], _ cur: String, _ pick: @escaping (String) -> Void) -> some View {
        let audio = session.audio
        return PickMenu(label: label, keys: items.map(\.0), names: items.map(\.1), cur: cur) { k in
            if k != cur { pick(k) }; audio.play(.click)
        }.equatable()
    }

    private func setSpeed(_ v: Double) {
        speed = v; simPaused = false
        session.director.playSpeed = v
        session.enqueue(.setSpeed(v)); session.audio.play(.click)
    }
    private func setPaused(_ p: Bool) {
        simPaused = p
        session.enqueue(.pause(p)); session.audio.play(.click)
    }

    /// 재생 명령(웹 DJ_PLAY — 마지막 것은 반복용)
    private func play(_ key: String, _ c: DojoCommand) {
        lastKey = key
        if simPaused { simPaused = false; session.enqueue(.pause(false)) }
        session.dojo(c)
    }

    // MARK: 콤보

    @ViewBuilder private var comboPane: some View {
        MMSub(t: tr("콤보 시연"))
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(Array(C.combos.enumerated()), id: \.offset) { k, n in
                let p = split(n)
                card(p.0, p.1, key: "cmb\(k)") { play("cmb\(k)", .combo(k)) }
            }
        }
        MMSub(t: tr("지금 가방의 콤보 경로"))
        let _ = routesTick
        let bag = session.snapshot.bag
        let R = session.data.catalog.routes(bag)
        if R.isEmpty {
            MMNote(t: tr("가방에 시작기 ▶와 이어지는 기술이 있으면 여기에 경로가 생겨요"))
        } else {
            ForEach(Array(R.enumerated()), id: \.offset) { k, r in
                let names = r.route.uids.compactMap { u in bag.first { $0.uid == u } }.map { "\(glyph($0.id)) \(session.content.itemName($0.id))" }
                card(tr(r.route.name), names.joined(separator: " → "), key: "br\(k)", color: Color(px: BagCatalog.routeColors[r.color])) { play("br\(k)", .bagRoute(k)) }
            }
        }
        FlowLayout(spacing: 5) {
            ForEach(Array(C.demoBags.enumerated()), id: \.offset) { k, n in
                Button("\(tr(n)) \(tr("넣기"))") {
                    session.dojo(.demoBag(k))
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(120)); routesTick += 1 }
                }
                .font(.galmuriSmall(10)).buttonStyle(PixelButtonLook(minHeight: 26))
            }
        }
    }

    private func split(_ n: String) -> (String, String?) {
        guard let r = n.range(of: " · ") else { return (tr(n), nil) }
        return (tr(String(n[..<r.lowerBound])), tr(String(n[r.upperBound...])))
    }

    private func card(_ title: String, _ sub: String?, key: String, color: Color? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.galmuri(11, bold: true)).foregroundStyle(color ?? PX.lilac).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if let sub, !sub.isEmpty { Text(sub).font(.galmuriSmall(9)).foregroundStyle(PX.muted).lineLimit(3).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading).padding(7)
            .pixelPanel(lastKey == key ? .btn : .plate)
            .overlay(alignment: .leading) { if let color { Rectangle().fill(color).frame(width: 3) } }
        }
        .buttonStyle(.plain)
    }

    private func glyph(_ id: String) -> String { BagCatalog.roleGlyph[session.data.catalog.rules.role(id)] ?? "" }

    // MARK: 기술 · 반응

    @ViewBuilder private var movePane: some View {
        HStack(alignment: .firstTextBaseline) {
            MMSub(t: tr("주인공 공격"))
            Text("▶ \(tr("시작기"))  ● \(tr("이음기"))  ■ \(tr("마무리기"))").font(.galmuriSmall(9)).foregroundStyle(PX.note)
        }
        moveGrid(C.hero, "hero") { m in .hero(m.id, combo: m.combo) }
        MMSub(t: tr("기타 동작"))
        moveGrid(C.misc, "misc") { .misc($0.id) }
        MMSub(t: tr("필살기"))
        moveGrid(C.spc, "spc") { .special($0.id) }
    }

    // MARK: 부서지는 소품(네이티브 — World+NativeObj · DojoObjArt): 마음대로 놓고 옮기고 치운다. 놓인 목록은 dotlab-opt extras 'djObj'([{kind, x}])

    private static let objKinds: [(id: String, name: String)] = [("glass", KE("유리 부스", "Glass booth")), ("crate", KE("나무 상자", "Wooden crate")), ("shoji", KE("장지문", "Paper screen"))]

    @ViewBuilder private var propsPane: some View {
        HStack(alignment: .firstTextBaseline) {
            MMSub(t: KE("부서지는 소품", "Breakable props"))
            Text(KE("날아간 상대가 부딪히면 부서져요 · 최대 \(DojoObjKind.maxCount)개", "Flying foes smash them · up to \(DojoObjKind.maxCount)"))
                .font(.galmuriSmall(9)).foregroundStyle(PX.note).lineLimit(1).minimumScaleFactor(0.7)
        }
        FlowLayout(spacing: 5) {
            ForEach(Self.objKinds, id: \.id) { k in
                Button("+ " + k.name) { session.dojo(.objAdd(k.id, nil)) }
                    .buttonStyle(PixelButtonLook(minHeight: 30)).disabled(dojo.objs.count >= DojoObjKind.maxCount)
            }
        }
        if dojo.objs.isEmpty {
            Text(KE("소품을 놓으면 허수아비 뒤에 서요. 막대로 자리를 옮겨요", "New props stand behind the dummy. Drag the bar to move them"))
                .font(.galmuriSmall(10)).foregroundStyle(PX.note)
        }
        ForEach(dojo.objs, id: \.id) { o in
            HStack(spacing: 6) {
                Text((Self.objKinds.first { $0.id == o.kind }?.name ?? o.kind) + (o.broken ? " ✕" : ""))
                    .font(.galmuriSmall(10)).foregroundStyle(o.broken ? PX.note : PX.ink).frame(width: 74, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                Slider(value: Binding(get: { o.x }, set: { session.enqueue(.dojo(.objMove(o.id, $0.rounded()))) }), in: DojoObjKind.minX...DojoObjKind.maxX, step: 1)
                    .tint(PX.accent).accessibilityLabel(KE("소품 자리", "Prop position"))
                Text("\(Int(o.x))").font(.galmuri(10, bold: true)).foregroundStyle(PX.ink).frame(width: 30, alignment: .trailing)
                Button("✕") { session.dojo(.objRemove(o.id)) }.buttonStyle(PixelButtonLook(minHeight: 28)).accessibilityLabel(KE("치우기", "Remove"))
            }
            .frame(minHeight: 30)
        }
        FlowLayout(spacing: 5) {
            Button(KE("코크스크루로 시험", "Test with Corkscrew")) { session.dojo(.hero("nv_cork", combo: nil)) }   // 일직선으로 빠르게 날아가 소품을 깬다(회오리 옆차기는 지웠다)
                .buttonStyle(PixelButtonLook(brass: true, minHeight: 30)).disabled(!C.hero.contains { $0.id == "nv_cork" })
            Button(KE("모두 복구", "Repair all")) { session.dojo(.objRepair) }.buttonStyle(PixelButtonLook(minHeight: 30)).disabled(!dojo.objs.contains(where: \.broken))
            Button(KE("모두 치우기", "Clear all")) { session.dojo(.objClear) }.buttonStyle(PixelButtonLook(minHeight: 30)).disabled(dojo.objs.isEmpty)
        }
    }

    /// 놓인 소품 목록 저장(종류 · 자리만 — 깨짐은 남기지 않는다)
    private func saveObjs(_ L: [DojoView.Obj]) {
        hub.saveOption("djObj", .array(L.map { .object(["kind": .string($0.kind), "x": .number($0.x)]) }))
    }

    @ViewBuilder private var reactPane: some View {
        MMSub(t: tr("허수아비 반응"))
        moveGrid(C.react, "react") { .react($0.id) }
        HStack(alignment: .firstTextBaseline) {
            MMSub(t: tr("적 공격"))
            Text(tr("허수아비가 주인공을 공격")).font(.galmuriSmall(9)).foregroundStyle(PX.note)
        }
        moveGrid(C.foe, "foe") { .foe($0.id) }
    }

    private func moveGrid(_ L: [DojoCatalog.Move], _ kind: String, _ cmd: @escaping (DojoCatalog.Move) -> DojoCommand) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 4)], spacing: 4) {
            ForEach(Array(L.enumerated()), id: \.offset) { _, m in
                let key = "\(kind):\(m.id):\(m.combo.map(String.init) ?? "")"
                Button { play(key, cmd(m)) } label: {
                    HStack(spacing: 3) {
                        if kind == "hero" { Text(glyph(m.id)).font(.galmuriSmall(9)).foregroundStyle(PX.gold) }
                        Text(tr(m.name)).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
                .font(.galmuriSmall(10))
                .buttonStyle(PixelButtonLook(brass: lastKey == key, minHeight: 28))
            }
        }
    }

    // MARK: 커스텀 콤보(웹 ccRender · ccBind — 누르면 붙이기 · 순서 칩 누르면 빼기 · 팔레트에서 끌어 그 자리에 넣기)
    // 네이티브 더하기: 최대 16단(2줄 × 8칸) · 순서 칩을 0.4초 길게 누르면 단계 편집(바꾸기 · 앞/뒤에 넣기 · 옮기기 · 빼기).
    //   웹은 길게 누르기가 없다 — 웹의 '끌어 자리 바꾸기 · 밖으로 끌어내면 빼기'는 편집 중에 칩을 끌어서 한다(스크롤과 다투지 않게).

    /// 한 줄 칸 수(16단 = 2줄)
    private static let ccCols = 8
    private static let cellH: CGFloat = PXSpace.hit
    private static let editSpace = "ccEdit"

    /// 실행 결과 색(실행한 순서와 지금 순서가 같을 때만)
    private var ccResNow: [String] { (ranCC == cc && dojo.cc == cc) ? (dojo.ccRes ?? []) : [] }

    @ViewBuilder private var customPane: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(tr("커스텀 콤보")).font(PXType.font(12, bold: true)).foregroundStyle(PX.gold)
                    Text("\(cc.count)/\(C.ccMax)\(tr("단"))").font(.galmuriSmall(9)).foregroundStyle(PX.note)
                }
                if let r = dojo.result, ranCC == cc {
                    Text(tr(r)).font(.galmuriSmall(9)).foregroundStyle(PX.ink).lineLimit(2).minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength: 0)
            Button("▶ " + tr("실행")) { ranCC = cc; session.enqueue(.dojo(.setCustom(cc))); play("ccrun", .customRun) }
                .font(PXType.font(PXType.s, bold: true)).buttonStyle(PixelButton(kind: .brass, sound: false)).disabled(cc.isEmpty)
            Button(tr("지우기")) { cc = []; editK = nil; commit() }
                .font(PXType.font(PXType.s)).buttonStyle(PixelButton(sound: false)).disabled(cc.isEmpty)
        }
        slotGrid(editing: false)
        MMNote(t: KE("동작을 누르면 뒤에 붙어요. 순서 칩을 누르면 빠지고, 길게 누르면 바꾸거나 옮겨요.",
                     "Tap a move to add it. Tap a step to remove it; press and hold to change or move it."))
        FlowLayout(spacing: 4) {
            ForEach(Array(C.moves.enumerated()), id: \.offset) { _, m in
                moveChip(tr(m.name), on: false)
                    .onTapGesture { if cc.count < C.ccMax { cc.append(m.value); commit() } }
                    .draggable("m:\(m.value)") { moveChip(tr(m.name), on: false) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(KE("콤보 끝에 붙여요", "Adds to the end of the combo"))
            }
        }
    }

    /// 순서 칸 격자(2줄 × 8칸 — 빈 칸도 보여 남은 자리를 안다). editing = 편집기 안(누르면 고르기 · 끌면 옮기기)
    private func slotGrid(editing: Bool) -> some View {
        let res = ccResNow
        let n = max(C.ccMax, cc.count)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: Self.ccCols), spacing: 4) {
            ForEach(0..<n, id: \.self) { k in slot(k, editing: editing, res: res) }
        }
        .padding(4)
        .background(Color.black.opacity(0.35))
        .overlay(Rectangle().stroke(PX.gold.opacity(0.4), lineWidth: 1))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { if editing { gridSize = $0 } }
        .coordinateSpace(name: editing ? Self.editSpace : "ccGrid")
        .overlay(alignment: .topLeading) { if editing { dragGhost } }
        .dropDestination(for: String.self) { items, _ in editing ? false : drop(items.first, at: cc.count) }
    }

    @ViewBuilder private func slot(_ k: Int, editing: Bool, res: [String]) -> some View {
        if k < cc.count {
            let name = C.label(cc[k])
            let face = slotFace(k, name, state: k < res.count ? res[k] : nil, sel: editing && editK == k,
                                pressed: pressK == k, dragging: dragK == k, target: editing && dragK != nil && dropTarget == k && dragK != k)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(KE("\(k + 1)단 \(name)", "Step \(k + 1) \(name)"))
                .accessibilityAddTraits(.isButton)
            if editing {
                face
                    .onTapGesture { pickEdit(k) }
                    .gesture(editDrag(k))
                    .accessibilityAddTraits(editK == k ? .isSelected : [])
                    .accessibilityHint(KE("두 번 누르면 이 단계를 고쳐요", "Double-tap to edit this step"))
            } else {
                face
                    .onTapGesture { removeStep(k) }   // 웹: 순서 칩 누르면 빼기
                    .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 12) { beginEdit(k) } onPressingChanged: { p in
                        if p { pressK = k } else if pressK == k { pressK = nil }
                    }
                    .dropDestination(for: String.self) { items, _ in drop(items.first, at: k) }
                    .accessibilityHint(KE("두 번 누르면 빠져요", "Double-tap to remove"))
                    .accessibilityAction(named: KE("단계 바꾸기", "Change step")) { beginEdit(k) }
                    .accessibilityAction(named: KE("빼기", "Remove")) { removeStep(k) }
            }
        } else {
            emptySlot(k)
                .dropDestination(for: String.self) { items, _ in editing ? false : drop(items.first, at: cc.count) }
                .accessibilityHidden(true)
        }
    }

    /// 순서 칸 한 칸: 단 번호(왼쪽 위) + 동작 이름(두 줄까지). 눌림 = 0.4초 동안 줄어들며 밝아진다(길게 누르기 진행)
    private func slotFace(_ k: Int, _ t: String, state: String?, sel: Bool, pressed: Bool, dragging: Bool, target: Bool) -> some View {
        let col: Color = switch state { case "air": Color(px: "#5fc8ff"); case "hit": Color(px: "#8dff7a"); case "miss": Color(px: "#ff7a5c"); default: PX.gold }
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(k + 1)").font(.galmuriSmall(8)).foregroundStyle(sel ? PX.brass : PX.note)
            Text(t).font(.galmuriSmall(10)).foregroundStyle(sel ? PX.brass : PX.lilac)
                .lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 2).padding(.vertical, 2)
        .frame(maxWidth: .infinity, minHeight: Self.cellH, maxHeight: Self.cellH)
        .background(sel ? PX.gold : Color(px: target ? "#3d3360" : "#2a2342"))
        .overlay(Rectangle().stroke(target ? PX.accent : sel ? Color.white : col.opacity(state == nil ? 0.55 : 1), lineWidth: state == nil && !sel && !target ? 1 : 2))
        .contentShape(Rectangle())
        .scaleEffect(pressed ? 0.88 : 1).brightness(pressed ? 0.18 : 0)
        .animation(pressed ? .easeIn(duration: 0.4) : .easeOut(duration: 0.12), value: pressed)
        .opacity(dragging ? 0.35 : 1)
    }

    private func emptySlot(_ k: Int) -> some View {
        Text("\(k + 1)").font(.galmuriSmall(8)).foregroundStyle(PX.unknown)
            .frame(maxWidth: .infinity, minHeight: Self.cellH, maxHeight: Self.cellH, alignment: .topLeading)
            .padding(.leading, 3).padding(.top, 2)
            .overlay(Rectangle().strokeBorder(PX.unknown.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
    }

    /// 팔레트 동작 칩(높이 40 + 간격 4 = 44pt 누름 자리)
    private func moveChip(_ t: String, on: Bool) -> some View {
        Text(t).font(.galmuriSmall(10)).foregroundStyle(on ? PX.brass : PX.lilac).lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minHeight: 40)
            .background(on ? PX.gold : Color(px: "#1d1930"))
            .overlay(Rectangle().stroke(on ? Color.white : Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
    }

    // MARK: 단계 편집기(길게 누르기 — 패널을 덮는다)

    private func stepEditor(_ k: Int) -> some View {
        let full = cc.count >= C.ccMax
        let name = C.label(cc[k])
        return VStack(alignment: .leading, spacing: 5) {
            slotGrid(editing: true)
            HStack(spacing: 4) {
                edButton("◀", KE("앞으로", "Move earlier"), off: k == 0) { shift(k, -1) }
                edButton("▶", KE("뒤로", "Move later"), off: k >= cc.count - 1) { shift(k, 1) }
                edButton("＋" + KE("앞", "Before"), KE("앞에 칸 넣기", "Insert step before"), off: full) { insertCopy(k, after: false) }
                edButton("＋" + KE("뒤", "After"), KE("뒤에 칸 넣기", "Insert step after"), off: full) { insertCopy(k, after: true) }
                edButton(KE("빼기", "Remove"), KE("이 단계 빼기", "Remove this step"), off: false) { removeStep(k) }
                Spacer(minLength: 0)
                Button(KE("완료", "Done")) { endEdit() }
                    .font(PXType.font(PXType.s, bold: true)).buttonStyle(PixelButton(kind: .brass, sound: false))
            }
            .lineLimit(1)
            HStack(spacing: 4) {
                Text(KE("\(k + 1)단", "Step \(k + 1)")).font(PXType.font(PXType.s, bold: true)).foregroundStyle(PX.gold)
                Text(name).font(PXType.font(PXType.s)).foregroundStyle(PX.ink).lineLimit(1)
                Text(KE("· 아래 동작을 누르면 바뀌어요 · 칸을 끌면 옮기고 밖으로 끌면 빠져요", "· tap a move to swap · drag a step to move, out to remove"))
                    .font(.galmuriSmall(9)).foregroundStyle(PX.note).lineLimit(2).minimumScaleFactor(0.8)
            }
            ScrollView {
                FlowLayout(spacing: 4) {
                    ForEach(Array(C.moves.enumerated()), id: \.offset) { _, m in
                        let on = cc.indices.contains(k) && cc[k] == m.value
                        moveChip(tr(m.name), on: on)
                            .onTapGesture { replace(k, m.value) }
                            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint(KE("\(k + 1)단을 이 동작으로 바꿔요", "Puts this move in step \(k + 1)"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 8).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
        .overlay(alignment: .top) { Rectangle().fill(PX.gold.opacity(0.5)).frame(height: 1) }
        .accessibilityAction(.escape) { endEdit() }
    }

    private func edButton(_ t: String, _ a11y: String, off: Bool, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action)
            .font(PXType.font(PXType.s)).buttonStyle(PixelButton(sound: false)).disabled(off)
            .accessibilityLabel(a11y)
    }

    /// 편집 중 끌고 있는 칸(손가락을 따라간다 · 밖이면 '빼기')
    @ViewBuilder private var dragGhost: some View {
        if let d = dragK, cc.indices.contains(d) {
            let out = dragOutside(dragAt)
            let w = max(36, (gridSize.width - 8 - 3 * CGFloat(Self.ccCols - 1)) / CGFloat(Self.ccCols))
            Text(out ? KE("빼기", "Remove") : C.label(cc[d]))
                .font(.galmuriSmall(10)).foregroundStyle(out ? PX.hotInk : PX.brass).lineLimit(2).minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .frame(width: w + 6, height: Self.cellH + 4)
                .background(out ? PX.hot : PX.gold)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 0, x: 2, y: 3)
                .position(x: dragAt.x, y: dragAt.y - 10)
                .allowsHitTesting(false)
        }
    }

    private func editDrag(_ k: Int) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.editSpace))
            .onChanged { g in
                if dragK == nil { dragK = k; editK = k; buzz(.light) }
                dragAt = g.location
            }
            .onEnded { g in
                defer { dragK = nil }
                guard dragK == k else { return }
                dropEdited(k, at: g.location)
            }
    }

    /// 격자 안 위치 → 칸 번호(웹 dropIndex 와 같은 뜻: 손가락이 놓인 칸 자리로)
    private func slotIndex(_ p: CGPoint) -> Int {
        let n = max(C.ccMax, cc.count), rows = (n + Self.ccCols - 1) / Self.ccCols
        let pitchX = max(1, (gridSize.width - 8 + 3) / CGFloat(Self.ccCols)), pitchY = Self.cellH + 4
        let c = min(Self.ccCols - 1, max(0, Int((p.x - 4) / pitchX))), r = min(rows - 1, max(0, Int((p.y - 4) / pitchY)))
        return r * Self.ccCols + c
    }
    /// 격자 밖(16pt 넘게)으로 끌어냈나(웹: 칸 상자 밖에서 놓으면 빼기)
    private func dragOutside(_ p: CGPoint) -> Bool {
        p.x < -16 || p.y < -16 || p.x > gridSize.width + 16 || p.y > gridSize.height + 16
    }
    private var dropTarget: Int? { dragK == nil || dragOutside(dragAt) ? nil : min(slotIndex(dragAt), cc.count - 1) }

    private func dropEdited(_ k: Int, at p: CGPoint) {
        guard cc.indices.contains(k) else { return }
        if dragOutside(p) { removeStep(k); return }
        let t = min(slotIndex(p), cc.count - 1)
        guard t != k else { return }
        let v = cc.remove(at: k); cc.insert(v, at: t); editK = t; commit()
    }

    // MARK: 편집 동작

    private func beginEdit(_ k: Int) {
        guard cc.indices.contains(k) else { return }
        pressK = nil; buzz(.medium); session.audio.play(.click)
        editK = k
    }
    private func pickEdit(_ k: Int) { guard cc.indices.contains(k), editK != k else { return }; editK = k; session.audio.play(.click) }
    private func endEdit() { editK = nil; dragK = nil; session.audio.play(.click) }
    private func removeStep(_ k: Int) {
        guard cc.indices.contains(k) else { return }
        cc.remove(at: k)
        if let e = editK { editK = cc.isEmpty ? nil : min(e > k ? e - 1 : e, cc.count - 1) }
        commit()
    }
    private func replace(_ k: Int, _ v: String) { guard cc.indices.contains(k), cc[k] != v else { return }; cc[k] = v; commit() }
    private func shift(_ k: Int, _ d: Int) {
        let t = k + d; guard cc.indices.contains(k), cc.indices.contains(t) else { return }
        cc.swapAt(k, t); editK = t; commit()
    }
    /// 앞/뒤에 같은 동작으로 한 칸 넣고 그 칸을 고른다(바로 아래 팔레트로 바꾼다 — 웹 '끌어 그 자리에 넣기'와 같은 결과)
    private func insertCopy(_ k: Int, after: Bool) {
        guard cc.indices.contains(k), cc.count < C.ccMax else { return }
        let i = after ? k + 1 : k
        cc.insert(cc[k], at: i); editK = i; commit()
    }

    /// 길게 누르기 · 끌기 진동(앱 단추 피드백과 같은 길 — 설정에서 진동을 끄면 없다)
    private func buzz(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if session.settings.vibration { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }

    private func drop(_ s: String?, at i: Int) -> Bool {
        guard let s else { return false }
        if s.hasPrefix("m:"), cc.count < C.ccMax {
            cc.insert(String(s.dropFirst(2)), at: min(i, cc.count))
        } else { return false }
        commit(); return true
    }

    private func commit() {
        ranCC = nil
        session.save?.setCustomCombo(CustomCombo(steps: cc))
        session.audio.play(.click)
    }

    /// 들어올 때: 저장된 패널 설정 · 커스텀 콤보(웹 showDojoPanel · ccLoad — 네이티브는 앞 16개)
    private func restore() {
        cc = Array((session.save?.customCombo(limit: CustomCombo.nativeMaxSteps).steps ?? CustomCombo.defaultSteps).prefix(C.ccMax))
        editK = nil
        #if DEBUG
        if let d = hub.debugCC { cc = Array(d.prefix(C.ccMax)); ranCC = cc }
        if let e = hub.debugEdit, cc.indices.contains(e) { editK = e; pressK = nil }
        #endif
        speed = 1; simPaused = false
        guard let o = session.save?.options() else { return }
        if let d = o.extras["djDummy"]?.stringValue, d != dojo.dummyType, C.dummies.contains(where: { $0.key == d }) { session.enqueue(.dojo(.dummy(d))) }
        if let z = o.extras["djZoom"]?.doubleValue, z != dojo.zoom { session.enqueue(.dojo(.zoom(z))) }
        if let c = o.extras["djCrit"]?.boolValue, c != dojo.crit { session.enqueue(.dojo(.crit(c))) }   // 치명 켜기 · 끄기(네이티브)
        if dojo.objs.isEmpty, let L = o.extras["djObj"]?.arrayValue {   // 부서지는 소품(네이티브)
            let specs = L.compactMap { v -> DojoObjSpec? in
                guard let m = v.objectValue, let k = m["kind"]?.stringValue, let x = m["x"]?.doubleValue else { return nil }
                return DojoObjSpec(kind: k, x: x)
            }
            if !specs.isEmpty { session.enqueue(.dojo(.objSet(specs))) }
        }
        if let b = o.extras["djbg"]?.stringValue, b != dojo.bg, ["dojo", "cross", "snow", "beach", "beach_dusk", "beach_night"].contains(b) { session.enqueue(.dojo(.background(b))) }   // 예전에 고른 허드슨 강(삭제됨) 같은 모르는 배경은 무시
    }
}

/// 무도장 펼침 메뉴 한 개 — 값이 같으면 다시 그리지 않는다(Equatable · 동작 클로저는 비교에서 뺀다)
private struct PickMenu: View, Equatable {
    let label: String, keys: [String], names: [String], cur: String
    let pick: (String) -> Void

    nonisolated static func == (a: PickMenu, b: PickMenu) -> Bool { a.label == b.label && a.keys == b.keys && a.names == b.names && a.cur == b.cur }

    var body: some View {
        let name = keys.firstIndex(of: cur).map { names[$0] } ?? cur
        Menu {
            ForEach(keys.indices, id: \.self) { i in
                Button { pick(keys[i]) } label: {
                    if keys[i] == cur { Label(names[i], systemImage: "checkmark") } else { Text(names[i]) }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.galmuriSmall(8)).foregroundStyle(PX.note)
                HStack(spacing: 2) {
                    Text(name).font(.galmuriSmall(10)).foregroundStyle(PX.lilac).lineLimit(1).minimumScaleFactor(0.7)
                    Text("▾").font(.galmuriSmall(9)).foregroundStyle(PX.gold)
                }
            }
            .padding(.horizontal, 6)
            .frame(minWidth: 52, maxWidth: 92, minHeight: 30, alignment: .leading)
            .pixelPanel(.plate)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(label): \(name)")
    }
}
