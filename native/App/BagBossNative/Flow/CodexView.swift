import SwiftUI
import BBContent
import BBPersistence

// 도감(웹 36-meta-menu codexHTML): 적 · 역 · 아이템 · 연계 · 콤보(도감 · 두목 명장면 · 자유 콤보) · 필살기 · 기록.
// 모르는 항목은 '???'(웹 .unk). 무도장 시연 · 콤보 연구실 버튼은 무도장(42-dojo)이 이식되면 붙인다.

struct CodexView: View {
    @Bindable var session: GameSession

    var body: some View {
        let C = session.content, M = session.meta, ct = session.codexTab
        PixelTabs(items: [(CodexTab.foe, tr("적")), (.stn, tr("역")), (.item, tr("아이템")), (.link, tr("연계")), (.cmb, tr("콤보")), (.spc, tr("필살기")), (.rec, tr("기록"))],
                  selection: $session.codexTab, scroll: true, onPick: { session.audio.play(.click) })
        switch ct {
        case .foe: MMNote(t: "\(M.foes.count) / \(C.game.enemies.count)")
        case .item: MMNote(t: "\(M.items.keys.filter { C.realItems.contains($0) }.count) / \(C.realItems.count)")
        default: EmptyView()
        }
        let rows = entries(ct, C, M)
        LazyVGrid(columns: ct == .cmb ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(rows) { r in
                CodexRow(row: r, content: C) {
                    if r.lab { session.openDojo() } else if let d = r.demo { session.openDojo(route: d) }
                }
            }
        }
    }

    struct Row: Identifiable {
        let id: String
        var title: String
        var lines: [String]
        var known = true
        var head = false, ok = false, seen = false, stamp = false
        var itemId: String? = nil
        var accent: String? = nil
        /// 무도장 시연 경로(콤보 도감) · 연구실 열기(머리 줄)
        var demo: [String]? = nil
        var lab = false
    }

    private func entries(_ ct: CodexTab, _ C: FlowContent, _ M: MetaState) -> [Row] {
        switch ct {
        case .foe:
            return C.game.enemies.ordered.map { k, e in
                let r = M.foes[k]
                return Row(id: k, title: r != nil ? tr(e.name) : "???", lines: [r.map { "\(tr("만남")) \($0.seen) · \(tr("쓰러뜨림")) \($0.ko)" } ?? tr("아직 못 만났어요")], known: r != nil)
            }
        case .stn:
            return C.stationOrder.map { id in
                let S = C.stations[id]!, v = M.stns[id] != nil
                return Row(id: id, title: v ? tr(S.ko) : "???", lines: [v ? S.n : tr("아직 안 들렀어요")], known: v, stamp: v)
            }
        case .item:
            return C.realItems.map { id in
                let t = M.items[id]
                return Row(id: id, title: t != nil ? C.itemName(id) : "???", lines: [t.map { "\(tr("최고")) \(String(repeating: "★", count: $0))" } ?? tr("아직 못 얻었어요")],
                           known: t != nil, itemId: id)
            }
        case .link:
            return C.linkGroups.map { g in
                let v = g.ids.contains { M.links[$0] != nil }
                return Row(id: g.name, title: v ? tr(g.name) : "???", lines: [v ? tr(g.desc) : tr("어떤 조합일까요?")], known: v)
            }
        case .cmb:
            let CB = M.cbook ?? [:], seenB = M.cseen ?? [:]
            let nm: (String) -> String = { id in "\(C.roleGlyph(id)) \(C.itemName(id))" }
            var out: [Row] = []
            let got = CB.keys.filter { k in C.game.comboBook.contains { $0.id == k } }.count
            out.append(Row(id: "h-book", title: "\(tr("콤보 도감")) \(got) / \(C.game.comboBook.count)", lines: [tr("실전에서 그 순서로 성공해야 채워져요")], head: true, lab: true))
            for B in C.game.comboBook {
                let e = CB[B.id], seen = seenB[B.id] != nil
                var lines = [B.route.map(nm).joined(separator: " → "),
                             tr(B.desc) + (e.map { " · \($0.n)\(tr("번")) · \(tr("최고")) \($0.best) HIT" } ?? " · \(tr("실전에서 성공하면 채워져요"))")]
                if let s = C.sig[B.id] { lines.append("\(tr("고유 마무리")) · \(s.w) \(tr(s.d))") }
                out.append(Row(id: "b-" + B.id, title: (e != nil ? "✓ " : "") + tr(B.name), lines: lines, known: e != nil, ok: e != nil, seen: e == nil && seen, demo: B.route))
            }
            out.append(Row(id: "h-boss", title: tr("두목 명장면"), lines: [tr("무너진 두목을 콤보로 쓰러뜨리면 기록돼요")], head: true))
            for k in C.bossKeys {
                guard let b = C.boss[k] else { continue }
                let n = (M.bossScenes ?? [:])[k]
                out.append(Row(id: "s-" + k, title: (n != nil ? "✓ " : "") + tr(b.n), lines: [n.map { "\($0)\(tr("번"))" } ?? tr("아직 없어요")], known: n != nil, ok: n != nil))
            }
            let free = (M.combos ?? [:]).filter { _, e in !C.game.comboBook.contains { $0.route == e.ids } }.sorted { $0.value.n > $1.value.n }
            out.append(Row(id: "h-free", title: tr("자유 콤보"), lines: [free.isEmpty ? tr("도감에 없는 순서로 콤보를 완성하면 여기에 기록돼요") : tr("도감 밖에서 찾은 콤보")], head: true))
            for (k, e) in free {
                let title = e.name.isEmpty ? e.ids.map(C.itemName).joined(separator: "·") : tr(e.name)
                out.append(Row(id: "f-" + k, title: title, lines: ["\(e.ids.map(nm).joined(separator: " → ")) · \(e.n)\(tr("번")) · \(tr("최고")) \(e.best) HIT"]))
            }
            return out
        case .spc:
            return C.specialKeys.compactMap { k in
                guard let s = C.specials[k] else { return nil }
                let n = (M.spc ?? [:])[k]
                return Row(id: k, title: n != nil ? tr(s.n) : "???",
                           lines: [n.map { "\(s.en) · \($0)\(tr("번 사용"))" } ?? "\(tr(C.families[k]?.n ?? k)) \(tr("위주로 가방을 짜면 나와요"))"], known: n != nil)
            }
        case .rec:
            let T = M.tot, st = C.stages
            let recs: [(String, String)] = [("판 수", "\(M.runs)"), ("최고 점수", "\(Int(M.best.score))"), ("가장 멀리 간 노선", tr(st[min(M.best.stage, st.count - 1)].name)),
                                            ("쓰러뜨린 적", "\(T.kills)"), ("치명타", "\(T.crits)"), ("병 피하기", "\(T.dodges)"), ("연계 발동", "\(T.links)"), ("메치기", "\(T.throws)"),
                                            ("문밖으로 날린 적", "\(T.outs)"), ("정시 클리어", "\(T.onTime)"), ("합성 성공", "\(T.merges)")]
            var out = recs.map { Row(id: $0.0, title: tr($0.0), lines: [$0.1]) }
            if let tw = M.tower { out.append(Row(id: "tw", title: KE("타워 최고 층", "Tower best"), lines: ["\(tw.best)F · \(tw.runs)\(tr("판"))"])) }
            if let b = M.bonusBest { out.append(Row(id: "bn", title: KE("보너스 최고", "Bonus best"), lines: ["\(Int(b))"])) }
            return out
        }
    }
}

/// 도감 한 칸(웹 .mm-list li — 판 · 들른 역은 가죽 틀)
struct CodexRow: View {
    let row: CodexView.Row
    let content: FlowContent
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if let id = row.itemId {
                MiniBag(content: content, slots: [(id, 0, 0, 0)], cs: 6)
                    .frame(width: 24, height: 24, alignment: .topLeading).clipped()
                    .saturation(row.known ? 1 : 0).brightness(row.known ? 0 : -0.6).opacity(row.known ? 1 : 0.45)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(row.title).font(.galmuri(12, bold: row.head || row.ok)).foregroundStyle(row.ok ? Color(px: "#ffd36a") : row.known ? PX.ink : PX.unknown)
                    if row.seen {
                        Text(tr("목격함")).font(.galmuri(9, bold: true)).foregroundStyle(Color(px: "#6ec6ff")).padding(.horizontal, 4).overlay(Rectangle().stroke(Color(px: "#6ec6ff"), lineWidth: 1))
                    }
                }
                ForEach(Array(row.lines.enumerated()), id: \.offset) { _, l in
                    Text(l).font(.galmuriSmall(10)).foregroundStyle(l.hasPrefix(tr("고유 마무리")) ? Color(px: "#ffcf6a") : PX.small).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if row.lab || row.demo != nil, let action {
                Button(row.lab ? tr("콤보 연구실 열기") : tr("무도장 시연")) { action() }
                    .font(.galmuri(10, bold: true)).foregroundStyle(row.lab ? Color(px: "#ffd36a") : Color(px: "#f6ecd6"))
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color(px: "#2a2440")).overlay(Rectangle().stroke(Color(px: row.lab ? "#ffd36a" : "#8a7a52"), lineWidth: 2))
                    .buttonStyle(.plain)
            }
        }
        .padding(row.stamp ? 10 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(row.stamp ? .frame : .plate)
    }
}
