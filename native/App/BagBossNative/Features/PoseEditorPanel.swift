import SwiftUI
import UIKit
import Observation
import BBContent
import BBAnim
import BBSim

// 개발자 도구 · 자세 편집기(웹 14-pose-editor.js · 50-mobile-dev.js '자세 편집기' → poseEdOpen).
//   무대: 스킨 미리보기 스튜디오(SkinPreviewCommand — 세상은 멈추고 주인공만 가운데) 위에 고른 자세를 고정(.fixed)해 크게 본다.
//   아래(가방 자리 · DojoPanel 이 SkinPreviewPanel 대신 이것을 보인다): 동작 고르기 · 키 자세 칩 · 재생 · 실제 크기 · 보기 회전 ·
//   몸/다리/팔 슬라이더(웹 PE_CTL 범위 · 값 매핑 그대로 — BBAnim PoseEdit) · 골반을 바닥에 맞추기 · 값 복사 · 되돌리기 · 모두 지우기.
//   고친 자세는 BBAnim PoseOverrides(실행 중 덮어쓰기 층)에 넣는다 → 시뮬레이션(공중 · 큐 판정)과 그리기 모두 바로 따른다.
//   저장: UserDefaults 'bbn-pose-edits'(자세 이름 → 수정분 — 웹 'dotlab-poseEdits' 와 같은 모양 · 새 키 · 판 저장(save.json)과 따로).
//   앱을 켤 때 FeatureHub.boot → PoseEditor.boot 가 저장분을 덮어쓰기 층에 다시 얹는다(웹 peApplySaved).
//   웹과 다른 점: 옛 방식(IK) 자세의 다리 · 팔 슬라이더는 0 대신 같은 모양의 각도 값을 보여 준다(엄지를 잡아도 자세가 튀지 않게).

@MainActor @Observable
final class PoseEditor {
    static let shared = PoseEditor()
    /// 저장 키(새 키 — 기존 저장 키는 건드리지 않는다)
    static let key = "bbn-pose-edits"

    /// 고른 동작 · 자세(웹 PE — 처음엔 철산고 타격)
    var anim = "tetsu"
    var pose = "ts_hit"
    /// 실제 크기 · 보기 회전(웹 V.z1 · V.view)
    var z1 = false
    var view = 0.0
    /// 수정이 바뀔 때마다 1씩(화면 다시 그리기)
    var rev = 0
    /// 값 복사 결과(웹 textarea.pe-out)
    var copied: String?

    /// 원본 표(덮어쓰기 전 — SimData.animTables.poses) · 주인공 리그(JW_HERO)
    @ObservationIgnored private(set) var base: [String: Pose] = [:]
    @ObservationIgnored private(set) var rig: RigDims?
    @ObservationIgnored private var data: SimData?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// 점검용(-poseedit … -peset): 이번 실행만 — 저장하지 않는다
    @ObservationIgnored var noSave = false

    /// 앱을 켤 때 한 번: 저장된 수정분을 덮어쓰기 층에 얹는다(웹 peApplySaved)
    func boot(_ d: SimData) {
        guard data == nil else { return }
        data = d; base = d.animTables.poses; rig = d.heroRig
        let S = PoseEdit.decode(UserDefaults.standard.string(forKey: Self.key))
        for (k, df) in S { if let O = base[k] { put(k, PoseEdit.apply(df, to: O)) } }
    }

    // MARK: 읽기

    /// 지금 자세(덮어쓴 것 우선)
    func current(_ k: String) -> Pose? { PoseOverrides.pose(k) ?? base[k] }
    func diff(_ k: String) -> PoseEdit.Diff {
        guard let O = base[k], let P = PoseOverrides.pose(k) else { return [:] }
        return PoseEdit.diff(P, from: O)
    }
    func edited(_ k: String) -> Bool { !diff(k).isEmpty }
    var editedCount: Int { PoseOverrides.all.keys.filter(edited).count }

    /// 웹 peMoves: 서기 · 걷기 + 무도장 주인공 기술(지금 깃발 상태의 목록 — 네이티브 기술 포함)의 동작
    func moves(_ hub: FeatureHub) -> [(name: String, anim: String)] {
        var L: [(name: String, anim: String)] = [("서기", "idle"), ("걷기", "walk"), ("질주", Self.runAnim)]
        guard let d = data else { return L }
        for m in hub.dojoCatalog.hero {
            if let an = d.heroMoveAnim(m.id, combo: m.combo), !L.contains(where: { $0.anim == an }) { L.append((m.name, an)) }
        }
        return L
    }
    /// 웹 pePoses
    func poses(_ an: String) -> [String] {
        if an == Self.runAnim { return Self.runPoses.filter { base[$0] != nil } }   // 질주: 시퀀스 없이 보폭 위상으로 고르는 키 6장 + 출발 · 미끄러짐
        return data?.seqPoses(an) ?? []
    }
    /// 질주(뛰기) — 시퀀스가 없는 동작이라 편집기가 키를 직접 늘어놓는다(그리기는 BBAnim Gait 가 덮어쓴 표에서 읽는다)
    static let runAnim = "nv_run"
    static let runPoses = ["nv_go", "nv_run0", "nv_run1", "nv_run2", "nv_run3", "nv_run4", "nv_run5", "nv_skid0", "nv_skid1"]
    /// 웹 peUses
    func uses(_ k: String) -> Int { data?.poseUses(k) ?? 0 }

    // MARK: 고르기

    /// 동작 바꾸기(웹 data-pe="anim": 철산고 타격이 있으면 그것, 아니면 첫 타격 자세, 아니면 첫 자세)
    func pickAnim(_ an: String, _ s: GameSession) {
        anim = an
        let ps = poses(an)
        pose = ps.contains("ts_hit") ? "ts_hit" : (ps.first { base[$0]?.impact == true } ?? ps.first ?? pose)
        show(s)
    }
    func pickPose(_ k: String, _ s: GameSession) { pose = k; show(s) }
    /// 웹 peShow: 스튜디오 자세 고정
    func show(_ s: GameSession) { copied = nil; s.enqueue(.skinPreview(.fixed(pose))) }

    /// 자세 이름으로 열 때 그 자세가 든 동작을 찾는다(점검용 · 처음 열기)
    func focus(pose k: String, _ hub: FeatureHub) {
        guard base[k] != nil else { return }
        pose = k
        if !poses(anim).contains(k), let m = moves(hub).first(where: { poses($0.anim).contains(k) }) { anim = m.anim }
    }

    // MARK: 고치기(웹 data-ctl · floor · revert · clear · copy)

    func set(_ c: PoseEdit.Control, _ v: Double) {
        guard let P = current(pose), let R = rig else { return }
        commit(pose, PoseEdit.edit(P, c, v, rig: R))
    }
    func floor() {
        guard let P = current(pose), let R = rig else { return }
        commit(pose, PoseEdit.floor(P, rig: R))
    }
    func revert() { PoseOverrides.set(pose, nil); rev += 1; scheduleSave() }
    func clearAll() {
        PoseOverrides.removeAll(); rev += 1; saveTask?.cancel()
        if !noSave { UserDefaults.standard.removeObject(forKey: Self.key) }
    }
    /// 값 복사: 웹 줄(자세 전체) · 수정분 줄 · Swift 줄(네이티브 포즈 표용)
    func copy() -> String {
        guard let P = current(pose) else { return "" }
        let t = [PoseEdit.webLine(pose, P), "// " + KE("수정분", "diff") + ": " + PoseEdit.diffLine(pose, diff(pose)), PoseEdit.swiftLine(pose, P)].joined(separator: "\n")
        UIPasteboard.general.string = t
        copied = t
        return t
    }

    private func put(_ k: String, _ P: Pose) {
        guard let O = base[k] else { return }
        PoseOverrides.set(k, PoseEdit.diff(P, from: O).isEmpty ? nil : P)   // 원본과 같으면 덮지 않는다
    }
    private func commit(_ k: String, _ P: Pose) { put(k, P); rev += 1; scheduleSave() }

    /// 웹처럼 0.5초 모아 저장
    private func scheduleSave() {
        guard !noSave else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }
    func saveNow() {
        guard !noSave else { return }
        var o: [String: PoseEdit.Diff] = [:]
        for k in PoseOverrides.all.keys { let d = diff(k); if !d.isEmpty { o[k] = d } }
        if o.isEmpty { UserDefaults.standard.removeObject(forKey: Self.key) }
        else { UserDefaults.standard.set(PoseEdit.encode(o), forKey: Self.key) }
    }
}

struct PoseEditorPanel: View {
    @Bindable var session: GameSession
    @State private var hub = FeatureHub.shared
    @State private var ed = PoseEditor.shared
    /// 값 직접 입력: 지금 고치는 조절값 이름 · 입력 중인 글
    @State private var typing: String?
    @State private var draft = ""
    @FocusState private var typeFocus: Bool

    var body: some View {
        let _ = ed.rev
        let moves = ed.moves(hub), P = ed.current(ed.pose), uses = ed.uses(ed.pose), edited = ed.edited(ed.pose)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(tr("자세 편집기")).font(.galmuri(14, bold: true)).foregroundStyle(PX.gold).inkShadow()
                Text(KE("개발자 도구", "Developer tool")).font(.galmuriSmall(9)).foregroundStyle(PX.note)
                Spacer()
                Button(tr("닫기")) { hub.closePoseEditor() }.buttonStyle(PixelButtonLook(brass: true, minHeight: 28))
            }
            HStack(spacing: 5) {
                Menu {
                    ForEach(moves, id: \.anim) { m in
                        Button { ed.pickAnim(m.anim, session); session.audio.play(.click) } label: {
                            let t = "\(tr(m.name)) · \(m.anim)"
                            if m.anim == ed.anim { Label(t, systemImage: "checkmark") } else { Text(t) }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(tr(moves.first { $0.anim == ed.anim }?.name ?? ed.anim)) · \(ed.anim)").font(.galmuriSmall(10)).foregroundStyle(PX.lilac)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("▾").font(.galmuriSmall(9)).foregroundStyle(PX.gold)
                    }
                    .padding(.horizontal, 6).frame(maxWidth: 170, minHeight: 28, alignment: .leading).pixelPanel(.plate).contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .accessibilityLabel(KE("동작", "Move") + ": " + ed.anim)
                Button("▶ " + tr("동작 재생")) { session.enqueue(.skinPreview(.play(ed.anim))) }
                    .font(.galmuriSmall(10)).buttonStyle(PixelButtonLook(minHeight: 28))
                Spacer(minLength: 0)
                Toggle(tr("실제 크기"), isOn: Binding(get: { ed.z1 }, set: { ed.z1 = $0; session.enqueue(.skinPreview(.z1($0))) }))
                    .toggleStyle(.button).font(.galmuriSmall(10)).tint(PX.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {   // 키 자세 칩(* = 고친 자세)
                HStack(spacing: 3) {
                    ForEach(ed.poses(ed.anim), id: \.self) { k in
                        Button(k + (ed.edited(k) ? " *" : "")) { ed.pickPose(k, session); session.audio.play(.click) }
                            .font(.galmuriSmall(10)).buttonStyle(PixelButtonLook(brass: k == ed.pose, minHeight: 26))
                    }
                }
            }
            noteLine(uses: uses, edited: edited)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    row(tr("보기 회전(확인용)"), value: Binding(get: { ed.view }, set: { ed.view = $0.rounded(); session.enqueue(.skinPreview(.view(ed.view))) }),
                        range: -180...180, text: "\(Int(ed.view))°", key: "_view", raw: Int(ed.view)) { v in
                        ed.view = min(180, max(-180, v.rounded())); session.enqueue(.skinPreview(.view(ed.view))) }
                    if let P { controls(P) }
                    FlowLayout(spacing: 5) {
                        Button(tr("골반을 바닥에 맞추기")) { ed.floor(); session.audio.play(.click) }.buttonStyle(PixelButtonLook(minHeight: 28))
                        Button(tr("값 복사")) { _ = ed.copy(); session.audio.play(.click) }.buttonStyle(PixelButtonLook(brass: true, minHeight: 28))
                        Button(tr("이 자세 되돌리기")) { ed.revert(); session.audio.play(.click) }.buttonStyle(PixelButtonLook(minHeight: 28)).disabled(!edited)
                        Button(tr("모든 수정 지우기")) { ed.clearAll(); session.audio.play(.click) }.buttonStyle(PixelButtonLook(minHeight: 28)).disabled(ed.editedCount == 0)
                    }
                    .font(.galmuriSmall(10)).padding(.top, 4)
                    if let c = ed.copied {
                        Text(tr("값을 복사했어요")).font(.galmuriSmall(10)).foregroundStyle(PX.gold)
                        Text(c).font(.system(size: 9, design: .monospaced)).foregroundStyle(PX.ink).textSelection(.enabled)
                            .padding(5).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.35))
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 8).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
    }

    /// 웹 .pe-note: 자세 이름 · 공용 자세 N개 동작 · 수정됨
    private func noteLine(uses: Int, edited: Bool) -> some View {
        HStack(spacing: 0) {
            Text(ed.pose).foregroundStyle(PX.ink)
            if uses > 1 { Text(" · \(tr("공용 자세")) \(uses)\(tr("개 동작"))").italic().foregroundStyle(PX.note) }
            if edited { Text(" · " + tr("수정됨 · 이 기기에 저장")).bold().foregroundStyle(PX.gold) }
        }
        .font(.galmuriSmall(10)).lineLimit(1).minimumScaleFactor(0.7)
    }

    /// 몸 · 다리 · 팔 슬라이더(웹 PE_CTL). 옛 방식 자세는 같은 모양의 각도 값으로 보여 준다 — 처음 움직일 때 그 값으로 바뀐다
    @ViewBuilder private func controls(_ P: Pose) -> some View {
        let F = ed.rig.map { PoseEdit.toFK(P, rig: $0) } ?? P
        ForEach(PoseEdit.groups, id: \.self) { g in
            Text(tr(g)).font(.galmuri(11, bold: true)).foregroundStyle(PX.gold).padding(.top, 4)
            ForEach(Array(PoseEdit.controls.enumerated()).filter { $0.element.group == g }, id: \.offset) { _, c in
                let show = PoseEdit.shown(c, F), auto = c.name == "골반 높이" && P.legH == nil
                row(label(c.name), value: Binding(get: { Double(show) }, set: { ed.set(c, $0.rounded()) }),
                    range: c.min...c.max, text: auto ? tr("자동") : "\(show)\(c.unit)", key: c.name, raw: show) { v in ed.set(c, min(c.max, max(c.min, v))) }
            }
        }
    }

    /// 네이티브에서 더한 조절값 이름(웹 사전에 없다)
    private func label(_ n: String) -> String {
        switch n {
        case "몸 전체 기울기": KE("몸 전체 기울기", "Whole-body lean")
        case "고개 숙임": KE("고개 숙임", "Head nod")
        case "고개 돌림": KE("고개 돌림", "Head turn")
        default: tr(n)
        }
    }

    /// 슬라이더 한 줄 — 오른쪽 값을 누르면 숫자를 직접 넣는다(범위 밖은 끝값으로 · 엔터 또는 다른 곳을 누르면 적용)
    private func row(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, text: String, key: String, raw: Int, commit: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.galmuriSmall(10)).foregroundStyle(PX.ink).frame(width: 78, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            Slider(value: value, in: range, step: 1).tint(PX.accent).accessibilityLabel(name)
            if typing == key {
                TextField("", text: $draft)
                    .keyboardType(.numbersAndPunctuation).submitLabel(.done).focused($typeFocus)
                    .font(.galmuri(10, bold: true)).foregroundStyle(PX.ink).multilineTextAlignment(.trailing)
                    .frame(width: 48).padding(.horizontal, 2).background(PX.accent.opacity(0.18))
                    .onSubmit { apply(commit) }
                    .onChange(of: typeFocus) { f in if !f { apply(commit) } }
            } else {
                Text(text).font(.galmuri(10, bold: true)).foregroundStyle(PX.ink).frame(width: 48, alignment: .trailing)
                    .underline(true, color: PX.ink.opacity(0.35)).contentShape(Rectangle())
                    .onTapGesture { if let t = typing, t != key { typing = nil }; draft = "\(raw)"; typing = key; typeFocus = true }
                    .accessibilityHint(KE("눌러서 값 직접 입력", "Tap to type a value"))
            }
        }
        .frame(minHeight: 28)
    }

    /// 입력한 글 → 값(쉼표 소수점 · 전각 마이너스도 받는다) · 숫자가 아니면 그대로 둔다
    private func apply(_ commit: (Double) -> Void) {
        guard typing != nil else { return }
        let t = draft.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "°", with: "")
        if let v = Double(t), v.isFinite { commit(v) }
        typing = nil
    }
}
