import SwiftUI
import BBContent
import BBSim
import BBPersistence

// 메뉴 5탭(웹 36-meta-menu openMenu): 새 판(시작 가방 · 시작 노선) · 오늘의 노선 · 타워(야근 단계 · 기록 · 오늘의 타워) · 도감 · 설정.
// 타이틀에서 열면 메뉴, 판 중에 열면 일시정지 메뉴(계속하기 · 타이틀로 · 포기하기가 더 붙는다).

struct MenuView: View {
    @Bindable var session: GameSession
    var tab: MenuTab

    private var inGame: Bool { session.screen == .playing && session.sim != nil && session.phase != "over" }

    var body: some View {
        let _ = session.lang
        let M = session.meta, st = session.content.stages
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(inGame ? tr("일시정지") : tr("메뉴")).font(.galmuri(17, bold: true)).foregroundStyle(PX.ink).inkShadow()
                        .accessibilityAddTraits(.isHeader)
                    Text("\(tr("최고")) \(Int(M.best.score))\(tr("점")) · \(st[min(M.best.stage, st.count - 1)].short)\(tr("선까지")) · \(M.runs)\(tr("판"))")
                        .font(.galmuriSmall(11)).foregroundStyle(PX.sub).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Button { session.closeMenu() } label: { Text("✕").font(.galmuri(18)).foregroundStyle(PX.ink).frame(width: 40, height: 40) }
                        .buttonStyle(.plain).accessibilityLabel(inGame ? KE("닫고 계속하기", "Close and resume") : tr("닫기"))
                }
                PixelTabs(items: [(MenuTab.run, tr("새 판")), (.daily, KE("오늘의 노선", "Daily")), (.tower, tr("타워")), (.codex, tr("도감")), (.sound, tr("설정"))],
                          selection: Binding(get: { tab }, set: { session.menuTab = $0 }), scroll: true, onPick: { session.audio.play(.click) })
                    .padding(.vertical, 6)
                if inGame { pauseStrip }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        switch tab {
                        case .run: RunTab(session: session)
                        case .daily: DailyTab(session: session)
                        case .tower: TowerTab(session: session)
                        case .codex: CodexView(session: session)
                        case .sound: SettingsTab(session: session)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                actions
            }
            .gCard()
            .frame(maxWidth: 560)
            .padding(.horizontal, 10).padding(.vertical, 24)
        }
    }

    /// 판 중: 계속하기 · 타이틀로(이어 하기 저장) · 포기하기(확인)
    private var pauseStrip: some View {
        HStack(spacing: 6) {
            Button(tr("계속하기")) { session.closeMenu() }.buttonStyle(PixelButtonLook(brass: true))
            Button(tr("타이틀로")) { session.toTitle() }.buttonStyle(PixelButtonLook())
            Button(tr("포기하기")) { session.confirm = .abandon }.buttonStyle(PixelButtonLook())
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder private var actions: some View {
        let row = HStack(spacing: 8) {
            switch tab {
            case .run:
                Button(tr("출발 ▶")) { session.request(RunRequest(kit: session.runKit, stage: session.runStage)) }.buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                    .accessibilityLabel(KE("새 판 출발", "Start new run"))
                if inGame { Button(tr("계속하기")) { session.closeMenu() }.buttonStyle(PixelButtonLook(minHeight: 40)) }
            case .daily:
                Button(tr("도전 ▶")) { session.request(RunRequest(kit: session.runKit, stage: 0, daily: true)) }.buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                    .accessibilityLabel(KE("오늘의 노선 도전", "Play daily route"))
            case .tower:
                Button(KE("오르기 ▶", "Climb ▶")) { session.request(RunRequest(mode: .tower, ot: session.towerOT)) }.buttonStyle(PixelButtonLook(brass: true, minHeight: 40))
                    .accessibilityLabel(KE("타워 오르기", "Climb tower"))
                Button(KE("오늘의 타워 ▶", "Daily Tower ▶")) { session.request(RunRequest(mode: .tower, daily: true)) }.buttonStyle(PixelButtonLook(minHeight: 40))
                    .accessibilityLabel(KE("오늘의 타워 도전", "Play daily tower"))
                GameCenterButton(compact: true)
            case .codex, .sound:
                if inGame { Button(tr("계속하기")) { session.closeMenu() }.buttonStyle(PixelButtonLook(brass: true, minHeight: 40)) }
                else { Button(tr("닫기")) { session.closeMenu() }.buttonStyle(PixelButtonLook(minHeight: 40)) }
            }
        }
        row.frame(maxWidth: .infinity).padding(.top, 8)
    }
}

/// 섹션 제목(웹 .mm-sub)
struct MMSub: View {
    let t: String
    var body: some View { Text(t).font(.galmuri(12, bold: true)).foregroundStyle(PX.gold).inkShadow().padding(.top, 6) }
}
/// 본문 문단(웹 .g-card p)
struct MMText: View {
    let t: String
    var body: some View { Text(t).font(.galmuriSmall(11)).foregroundStyle(PX.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
}
struct MMNote: View {
    let t: String
    var body: some View { Text(t).font(.galmuriSmall(10)).foregroundStyle(PX.note).fixedSize(horizontal: false, vertical: true) }
}

// MARK: 새 판

struct RunTab: View {
    @Bindable var session: GameSession
    var body: some View {
        let C = session.content, M = session.meta
        MMSub(t: tr("시작 가방"))
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(C.kits, id: \.id) { k in
                let cond = k.cond.map { MetaState.KitCondition(id: k.id, key: $0.k, n: $0.n) }
                let open = cond == nil || M.kits[k.id] != nil
                let prog = cond.map { M.kitProgress($0) }
                Button { session.runKit = k.id; session.audio.play(.click) } label: {
                    KitCard(content: C, kit: k, selected: session.runKit == k.id, locked: !open,
                            lockText: k.cond.map { "🔒 \(tr($0.t)) (\(prog?.value ?? 0)/\($0.n))" }, progress: prog?.ratio)
                }
                .buttonStyle(.plain).disabled(!open)
            }
        }
        MMSub(t: tr("시작 노선"))
        FlowLayout(spacing: 6) {
            ForEach(Array(C.stages.enumerated()), id: \.offset) { k, S in
                let open = M.lines[String(k)] != nil || session.devLines
                Button { session.runStage = k; session.audio.play(.click) } label: {
                    HStack(spacing: 6) {
                        Text(S.short).font(.galmuri(11, bold: true)).foregroundStyle(.white).frame(width: 18, height: 18).background(Circle().fill(Color(px: S.color)))
                        Text(open ? (M.lines[String(k)] != nil ? tr(S.name) : tr(S.name) + " · " + KE("개발", "dev")) : KE("🔒 이 노선까지 가 보면 열려요", "🔒 Reach this line to unlock")).font(.galmuriSmall(11))
                    }
                }
                .buttonStyle(PixelButtonLook(brass: session.runStage == k, minHeight: 30)).disabled(!open)
            }
        }
        if session.runStage > 0 { MMNote(t: tr("중간 노선에서 시작하면 아이템 하나와 토큰 6개를 더 받아요.")) }
    }
}

/// 시작 가방 카드(웹 .mm-kit — 이름 · 미니 가방 · 설명/잠금 · 진행 막대)
struct KitCard: View {
    let content: FlowContent
    let kit: KitDef
    var selected: Bool
    var locked = false
    var lockText: String? = nil
    var progress: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tr(kit.name)).font(.galmuri(12, bold: true)).foregroundStyle(PX.lilac)
            MiniBag(content: content, slots: kit.bag.map { ($0.id, $0.x, $0.y, $0.rot) })
            Text(locked ? (lockText ?? "") : tr(kit.desc)).font(.galmuriSmall(10)).foregroundStyle(PX.muted).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            if locked, let p = progress { PixelProgress(value: p) }
        }
        .padding(selected ? 14 : 8)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .pixelPanel(selected ? .frame : .plate)
        .opacity(locked ? 0.6 : 1)
    }
}

/// 시작 가방 미리보기(웹 miniBag — 6×4 배치를 작은 타일로)
struct MiniBag: View {
    let content: FlowContent
    let slots: [(String, Int, Int, Int)]
    var cs: CGFloat = 9
    var body: some View {
        let W = content.inv.W, H = content.inv.H, rules = content.catalog.rules
        Canvas { c, _ in
            c.fill(Path(CGRect(x: 0, y: 0, width: CGFloat(W) * cs, height: CGFloat(H) * cs)), with: .color(Color(px: "#1f1a38")))
            for y in 0..<H { for x in 0..<W { c.stroke(Path(CGRect(x: CGFloat(x) * cs + 0.5, y: CGFloat(y) * cs + 0.5, width: cs - 1, height: cs - 1)), with: .color(Color(px: "#2c2650")), lineWidth: 1) } }
            for (id, x, y, rot) in slots where content.game.items[id] != nil {
                let col = Color(px: content.itemColor(id))
                for cell in rules.shape(id, rot: rot) {
                    let r = CGRect(x: CGFloat(x + cell.x) * cs, y: CGFloat(y + cell.y) * cs, width: cs, height: cs)
                    c.fill(Path(r), with: .color(col)); c.stroke(Path(r.insetBy(dx: 0.5, dy: 0.5)), with: .color(PX.dark), lineWidth: 1)
                }
            }
        }
        .frame(width: CGFloat(W) * cs, height: CGFloat(H) * cs)
    }
}

// MARK: 오늘의 노선

struct DailyTab: View {
    @Bindable var session: GameSession
    var body: some View {
        let C = session.content, dk = DailyKey.today()
        let k = C.kits[DailyKey.kitIndex(dk, count: C.kits.count)]
        MMSub(t: "\(dk) \(KE("오늘의 노선", "Daily Route"))")
        MMText(t: tr("오늘은 매점 · 적 · 확률이 누구에게나 같아요. 시작 가방도 하루 하나로 정해져요(잠긴 가방이어도 오늘은 써 볼 수 있어요)."))
        KitCard(content: C, kit: k, selected: true).frame(maxWidth: 260)
        HStack(spacing: 6) {
            MMText(t: tr("오늘 최고 기록"))
            Text("\(Int(session.meta.daily[dk] ?? 0))").font(.galmuri(16, bold: true)).foregroundStyle(PX.gold)
        }
    }
}

// MARK: 타워

struct TowerTab: View {
    @Bindable var session: GameSession
    var body: some View {
        let C = session.content, T = session.meta.tower
        let otU = T?.ot ?? 0, otS = max(0, min(otU, session.towerOT)), LV = T?.lv?[String(otS)]
        MMSub(t: KE("엘리베이터 타워 · 1~\(C.towerTop)층", "Elevator Tower · 1–\(C.towerTop)F"))
        MMText(t: KE("화물 엘리베이터를 타고 1층 주차장에서 20층 총주방장실까지 올라가요. 층마다 적이 타고, 정원을 넘기면 문이 안 닫혀요. 문이 열린 동안 밖으로 날려 보내고, 띄우기 기술은 천장에 튕겨요.",
                     "Ride a freight elevator from the 1F garage to the 20F head chef. Enemies board on every floor; over capacity, the doors stay open. Throw them out while the doors are open — launchers bounce off the ceiling."))
        FlowLayout(spacing: 4) {
            ForEach(0...otU, id: \.self) { l in
                Button(l > 0 ? KE("야근 \(l)", "OT \(l)") : KE("정시", "Regular")) { session.setTowerOT(l); session.audio.play(.click) }
                    .buttonStyle(PixelButtonLook(brass: l == otS, minHeight: 28))
            }
            if otU < C.towerOTMax {
                Text("🔒 " + KE("\(C.towerTop)층을 돌파하면 야근 \(otU + 1)단계", "Clear \(C.towerTop)F for OT \(otU + 1)")).font(.galmuriSmall(10)).foregroundStyle(PX.note)
                    .frame(minHeight: 28)
            }
        }
        if otS > 0 { ModBadges(names: (1...otS).compactMap { C.otRule($0) }.map { KE($0.name, $0.en) }) }
        HStack(spacing: 6) {
            RecBox(big: LV.map { "\($0.f)F" } ?? "—", small: "\(C.otName(otS)) \(KE("최고 층", "best floor"))")
            RecBox(big: LV.flatMap { $0.f >= C.towerTop ? mmss($0.t) : nil } ?? "—", small: KE("\(C.towerTop)층 최단 시간", "Best \(C.towerTop)F time"))
            RecBox(big: "\(T?.runs ?? 0)", small: KE("도전", "Runs"))
        }
        MMNote(t: KE("시작 가방은 '새 판'에서 고른 가방이에요 · 본편 이어 하기 저장은 그대로 남아요", "Uses the starting case picked in New run · your main-run save stays untouched"))
        // 오늘의 타워
        let dk = DailyKey.today(), db = T?.daily?[dk], dkit = C.kits[DailyKey.kitIndex(dk, count: C.kits.count)]
        MMSub(t: "\(KE("오늘의 타워", "Daily Tower")) · \(dk)").padding(.top, 10)
        MMText(t: KE("오늘은 누구에게나 같은 조건 · 같은 탑승 순서 · 같은 시작 가방이에요.", "Same conditions, boarding order and starting case for everyone today."))
        ModBadges(names: session.dailyTowerModIDs().compactMap { C.mod($0) }.map { KE($0.name, $0.en) }, kit: "\(KE("가방", "Case")) · \(tr(dkit.name))")
        HStack(spacing: 6) {
            MMText(t: KE("오늘 최고", "Today best"))
            Text(db.map { "\($0.f)F · \(mmss($0.t))" } ?? "—").font(.galmuri(16, bold: true)).foregroundStyle(PX.gold)
        }
    }
}

func mmss(_ s: Double) -> String { mmss(Int(s.rounded())) }
func mmss(_ s: Int) -> String { "\(s / 60):\(String(format: "%02d", s % 60))" }

/// 조건 배지(웹 .tw-mods b)
struct ModBadges: View {
    let names: [String]
    var kit: String? = nil
    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(names, id: \.self) { n in
                Text(n).font(.galmuriSmall(10)).foregroundStyle(Color(px: "#ff9a7a")).padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Rectangle().stroke(Color(px: "#ff7a5c"), lineWidth: 1))
            }
            if let kit {
                Text(kit).font(.galmuriSmall(10)).foregroundStyle(PX.accent).padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Rectangle().stroke(PX.accent, lineWidth: 1))
            }
        }
    }
}

/// 기록 칸(웹 .tw-rec div)
struct RecBox: View {
    let big: String, small: String
    var body: some View {
        VStack(spacing: 2) {
            Text(big).font(.galmuri(16, bold: true)).foregroundStyle(PX.accent)
            Text(small).font(.galmuriSmall(9)).foregroundStyle(PX.sub).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8).pixelPanel(.plate)
    }
}

// MARK: 설정

struct SettingsTab: View {
    @Bindable var session: GameSession
    @State private var hintsReset = false
    /// 버전 줄을 누른 횟수(7번이면 개발자 칸 — 안드로이드 빌드 번호 관례)
    @State private var versionTaps = 0
    private static let version: String = {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }()
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            section(tr("소리"), note: KE("기기에서 바로 합성", "synthesized on device")) {
                vol(tr("전체"), $session.settings.master)
                vol(tr("음악"), $session.settings.music)
                vol(tr("효과음"), $session.settings.sfx)
                toggle(tr("음소거"), nil, $session.settings.muted)
            }
            section(tr("게임")) {
                toggle(tr("필살기 자동 발동"), tr("적 3명 이상이거나 두목일 때"), $session.settings.autoSpc)
                toggle(tr("컷인 짧게"), tr("두 번째부터 짧게 보여요"), $session.settings.shortCut)
                toggle(KE("프롤로그", "Prologue"), KE("첫 노선을 새로 시작할 때 지하 복도부터", "New runs from the first line start in the corridor"), $session.settings.prologue)
                toggle(tr("번쩍임 줄이기"), tr("흑백 반전 · 하얀 섬광 끔 · 충격파 약하게"), $session.settings.noFlash)
                toggle(KE("화면 흔들림 줄이기", "Reduce screen shake"), KE("흔들림 · 확대 펀치 약하게 + 번쩍임 끔", "Weaker shake · zoom punches, no flashes"), $session.settings.calm)
                toggle(KE("직접 조작 패드", "Control pad"), KE("◀ ▶ · 숙이기 · 기술 버튼으로 직접 싸워요 — 손을 떼면 2.5초 뒤 자동", "Fight with ◀ ▶ · duck · skill buttons — auto again 2.5s after you let go"), $session.settings.padOn)
                if session.settings.padOn {
                    toggle(KE("왼손 배치", "Left-handed pad"), KE("기술 버튼을 왼쪽에", "Skill buttons on the left"), $session.settings.padLefty)
                }
                toggle(tr("진동"), KE("큰 타격 · 필살기 · 두목 등장", "Big hits · specials · boss entrances"), $session.settings.vibration)
                if session.settings.vibration {
                    HStack(spacing: 8) {
                        Text(KE("피격 진동", "Hurt buzz")).font(.galmuriSmall(11)).foregroundStyle(PX.ink).frame(width: 64, alignment: .leading)
                        Slider(value: $session.settings.hurtScale, in: 0...1, step: 0.1).tint(PX.accent)
                            .accessibilityLabel(KE("피격 진동 세기", "Hurt buzz strength"))
                        Text("\(Int(session.settings.hurtScale * 100))").font(.galmuri(11, bold: true)).foregroundStyle(PX.ink).frame(width: 28)
                    }
                }
                toggle(KE("동작 강화", "Motion detail"), KE("코트 · 머리 · 호흡(네이티브)", "coat · hair · breathing (native)"), $session.settings.motionEnhance)
                toggle(KE("실제 타격음", "Recorded hits"), KE("녹음 펀치 소리를 겹쳐요(네이티브)", "Layer recorded punch sounds (native)"), $session.settings.sampleHits)
                if session.inRunForSettings {
                    MMNote(t: KE("필살기 자동 · 컷인 짧게는 다음 판부터 적용돼요", "Auto special · short cut-ins apply from the next run"))
                }
            }
            section(tr("주인공"), note: KE("유료 스킨 · 미리보기는 무료", "Paid skins · previews are free")) {
                SkinSettingsGrid(session: session)   // Features/SkinSettings.swift — 가격 · 보유 · 미리보기 · 구매 복원
            }
            section(tr("언어 · Language")) {
                HStack(spacing: 6) {
                    Button("한국어") { session.setLanguage("ko") }.buttonStyle(PixelButtonLook(brass: session.lang == "ko"))
                    Button("English") { session.setLanguage("en") }.buttonStyle(PixelButtonLook(brass: session.lang == "en"))
                }
            }
            section(tr("기타")) {
                FlowLayout(spacing: 6) {
                    Button(hintsReset ? tr("도움말을 다시 보여 드려요") : tr("도움말 다시 보기")) { session.resetHints(); hintsReset = true; session.audio.play(.click) }
                        .buttonStyle(PixelButtonLook())
                    FeatureMenuButtons(session: session)   // Features/: 콤보 연구실 · Game Center
                }
            }
            if session.settings.devUnlocked {
                section(KE("개발자", "Developer"), note: KE("출시판에서는 숨은 칸", "hidden in release")) {
                    toggle(KE("성능 표시", "Performance line"), KE("fps · 틱 · 프레임 · 인물 · 입자", "fps · tick · frame · actors · particles"), $session.settings.devPerf)
                    toggle(KE("AUTO · MANUAL 배지", "AUTO · MANUAL badge"), KE("무대 오른쪽 위 조작 상태", "control state, stage top-right"), $session.settings.devBadge)
                    toggle(KE("점검 탭", "Inspection tabs"), KE("데이터 · 렌더 · 캐릭터 · 가방", "data · render · character · bag"), $session.settings.devTabs)
                    HStack(spacing: 6) {   // 게임 화면 배치(docs/09) — 예전 배치와 비교용
                        Text(KE("레이아웃", "Layout")).font(.galmuriSmall(11)).foregroundStyle(PX.ink)
                        Spacer(minLength: 4)
                        Button(KE("새 배치", "New")) { session.settings.layoutNew = true }.buttonStyle(PixelButtonLook(brass: session.settings.layoutNew))
                        Button(KE("예전 배치", "Classic")) { session.settings.layoutNew = false }.buttonStyle(PixelButtonLook(brass: !session.settings.layoutNew))
                    }
                    .frame(minHeight: 30)
                    .accessibilityElement(children: .contain).accessibilityLabel(KE("레이아웃", "Layout"))
                    FlowLayout(spacing: 6) {
                        Button(tr("자세 편집기")) { FeatureHub.shared.openPoseEditor() }.buttonStyle(PixelButtonLook(brass: true))
                            .accessibilityHint(KE("무도장 스튜디오에서 동작의 키 자세를 각도로 고쳐요", "Edit key poses by angle in the dojo studio"))
                        #if DEBUG
                        Button(KE("개발: 보너스 결산", "Dev: bonus board")) { session.debugJump(.bonusBoard) }.buttonStyle(PixelButtonLook())
                        Button(KE("개발: 결과 신문", "Dev: newspaper")) { session.debugJump(.news) }.buttonStyle(PixelButtonLook())
                        Button(KE("개발: 타워 결과", "Dev: tower card")) { session.debugJump(.tower) }.buttonStyle(PixelButtonLook())
                        Button(KE("개발: 대화", "Dev: talk")) { session.debugJump(.talk) }.buttonStyle(PixelButtonLook())
                        Button(KE("개발: 모든 노선 열기", "Dev: open lines")) { session.debugJump(.openLines) }.buttonStyle(PixelButtonLook())
                        #endif
                        Button(KE("개발자 칸 닫기", "Hide developer")) {
                            session.settings.devUnlocked = false; session.settings.devPerf = false; session.settings.devBadge = false; session.settings.devTabs = false
                            session.settings.layoutNew = true   // 닫으면 출시 기본(새 배치)
                            versionTaps = 0
                        }
                        .buttonStyle(PixelButtonLook())
                    }
                }
            }
            // 버전 줄 — 7번 누르면 개발자 칸(숨은 문)
            Text("BAG BOSS · \(KE("버전", "Version")) \(Self.version)")
                .font(.galmuriSmall(10)).foregroundStyle(PX.note)
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !session.settings.devUnlocked else { return }
                    versionTaps += 1
                    if versionTaps >= 7 { session.settings.devUnlocked = true; session.audio.play(.unlock) }
                }
                .accessibilityLabel(KE("버전 \(Self.version)", "Version \(Self.version)"))
        }
        .onChange(of: session.settings) { _, _ in session.applySettings() }
    }

    private func section<C: View>(_ t: String, note: String? = nil, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(t).font(.galmuri(12, bold: true)).foregroundStyle(PX.gold)
                if let note { Text(note).font(.galmuriSmall(9)).foregroundStyle(PX.note) }
            }
            c()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22))
        .overlay(Rectangle().stroke(Color(px: "#c9a24a", 0.28), lineWidth: 1))
    }
    private func vol(_ t: String, _ v: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(t).font(.galmuriSmall(11)).foregroundStyle(PX.ink).frame(width: 44, alignment: .leading)
            Slider(value: v, in: 0...1).tint(PX.accent)
                .accessibilityLabel(KE("\(t) 볼륨", "\(t) volume"))
            Text("\(Int((v.wrappedValue * 100).rounded()))").font(.galmuri(11, bold: true)).foregroundStyle(PX.ink).frame(width: 28)
        }
        .frame(minHeight: 28)
    }
    private func toggle(_ t: String, _ d: String?, _ v: Binding<Bool>) -> some View {
        Toggle(isOn: v) {
            VStack(alignment: .leading, spacing: 1) {
                Text(t).font(.galmuriSmall(11)).foregroundStyle(PX.ink)
                if let d { Text(d).font(.galmuriSmall(9)).foregroundStyle(PX.note) }
            }
        }
        .tint(PX.accent).frame(minHeight: 30)
    }
}

extension GameSession {
    var inRunForSettings: Bool { screen == .playing && sim != nil }
}
