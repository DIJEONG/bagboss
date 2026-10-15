import UIKit
import BBSim
import BBContent
import BBUI

// 게임 안 가방(BBUI BagGridView)과 시뮬레이션 잇기.
//  시뮬레이션 → 가방: bagChanged 이벤트(또는 처음)마다 스냅숏의 가방 · 보류함 · 토큰 · 각인으로 BagEditor 상태를 새로 만들고 render
//                    · 쿨다운은 몇 프레임마다 updateCooldowns(막대만)
//  가방 → 시뮬레이션: BagGridView 손짓(BagIntent) → BagEditor.apply(미리 보기 · 합성 굴림 · 되돌리기) → 결과 배치를 SimIntent.bagLayout(+ bagTokens)로
//  만지는 동안(전투 중) bagTouch → 시뮬레이션이 0.2배 슬로(웹 bagSlowT)
//  새 배치(docs/09): 엿보기 줄(BagPeekView)에 지금 콤보 경로를 · SwiftUI 에 PeekInfo 를 준다

@MainActor
final class BagController: NSObject, UIGestureRecognizerDelegate {
    weak var session: GameSession?
    weak var view: BagGridView?
    weak var peekView: BagPeekView?
    /// 가방 첫 콤보 경로(배치가 바뀔 때만 다시 구한다)
    private var routeSig = "", firstRoute: (uids: [Int], name: String) = ([], ""), routeCount = 0
    private(set) var editor: BagEditor
    private var frameNo = 0
    private var lastTouchSent = 0.0
    private var lastState = ""

    init(catalog: BagCatalog) { editor = BagEditor(catalog: catalog, state: BagState()) }

    func attach(_ v: BagGridView) {
        view = v
        v.onIntent = { [weak self] i in self?.handle(i) }
        // 만지는 동안 알림(가방 뷰의 손짓은 그대로 두고 같이 받는다)
        let g = UILongPressGestureRecognizer(target: self, action: #selector(touching(_:)))
        g.minimumPressDuration = 0; g.cancelsTouchesInView = false; g.delaysTouchesBegan = false; g.delaysTouchesEnded = false
        g.delegate = self
        v.addGestureRecognizer(g)
        v.onButtonFeedback = { [weak self] in self?.session?.buttonFeedback(sound: true) }
        v.render(editor, force: true)
    }

    func attachPeek(_ v: BagPeekView) {
        peekView = v
        v.onTap = { [weak self] in self?.session?.buttonFeedback(sound: true); self?.session?.setBagOpen(true) }
        if let s = session?.snapshot { updatePeek(s) }
    }

    /// 엿보기 줄: 판에서 도는 경로(있으면) — 없으면 가방의 첫 경로를 미리 보여 준다
    private func updatePeek(_ s: SimSnapshot) {
        let bag = editor.state.bag
        let sig = bag.map { "\($0.uid):\($0.id)@\($0.x),\($0.y)r\($0.rot)t\($0.tier)" }.joined(separator: ";")
        if sig != routeSig {
            routeSig = sig
            let R = editor.catalog.routes(bag)
            firstRoute = R.first.map { ($0.route.uids, $0.route.name) } ?? ([], "")
            routeCount = R.count
        }
        let live = !s.comboRoute.isEmpty
        let uids = live ? s.comboRoute : firstRoute.uids, step = live ? s.comboStep : 0
        peekView?.render(editor, route: uids, step: step)
        let next = step < uids.count ? (bag.first { $0.uid == uids[step] }.flatMap { editor.catalog.item($0.id)?.name } ?? "") : ""
        let P = PeekInfo(name: live ? (s.comboName ?? firstRoute.name) : firstRoute.name, step: step, count: uids.count, next: next, routes: routeCount, live: live)
        if session?.peek != P { session?.peek = P }
    }

    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

    @objc private func touching(_ g: UIGestureRecognizer) {
        guard g.state == .began || g.state == .changed else { return }
        let now = CACurrentMediaTime()
        if now - lastTouchSent > 0.25 { lastTouchSent = now; session?.enqueue(.bagTouch) }
    }

    /// 스냅숏 → 편집기 상태
    func sync(_ s: SimSnapshot, force: Bool = false) {
        let maxUid = (s.bag + s.stash).map(\.uid).max() ?? 0
        var st = BagState(bag: s.bag, stash: s.stash, tokens: s.tokens, imprints: s.imprints, uid: maxUid, selUid: editor.state.selUid, newUids: editor.state.newUids)
        if let sel = st.selUid, st.item(sel) == nil { st.selUid = nil }
        editor.replaceState(st)
        editor.inCombat = s.actors.contains { $0.isEnemy && !$0.hidden && $0.hp > 0 } && !["shop", "arrange", "transfer", "over"].contains(s.state)
        editor.canEdit = s.state != "over" && s.state != "transfer"
        view?.render(editor, force: force)
        updatePeek(s)
    }

    /// 화면 프레임마다
    func frame(_ s: SimSnapshot, events: [SimEvent]) {
        frameNo += 1
        let changed = events.contains { if case .bagChanged = $0 { return true }; return false } || s.state != lastState
        lastState = s.state
        if changed { sync(s) }
        if changed || frameNo % 6 == 0 { updatePeek(s) }
        if !changed && frameNo % 3 == 0 {
            var st = editor.state
            for i in st.bag.indices { if let b = s.bag.first(where: { $0.uid == st.bag[i].uid }) { st.bag[i].t = b.t } }
            view?.updateCooldowns(st); peekView?.updateCooldowns(st)
        }
    }

    #if DEBUG
    /// 점검용: 가방(또는 보관함) 첫 타일 고르기(설명 카드 스크린숏)
    func debugSelectFirst(stash: Bool = false) { if let u = (stash ? editor.state.stash.first : editor.state.bag.first)?.uid { handle(.select(u)) } }
    #endif

    private func handle(_ i: BagIntent) {
        guard let session else { return }
        let before = editor.state
        if case .quickEquip(let u) = i { session.enqueue(.quickEquip(uid: u)); return }
        let r = editor.apply(i)
        view?.render(editor)
        updatePeek(session.snapshot)
        if r.title != nil || r.message != nil { view?.showMessage(r.title, r.message) }
        if let ok = r.merged { session.audio.play(.merge(ok: ok)); session.noteMerge(ok: ok) }   // 웹 GS.stats.merges(메타 누계)
        guard r.changed else { return }
        let s = editor.state
        if s.bag != before.bag || s.stash != before.stash { session.enqueue(.bagLayout(bag: s.bag, stash: s.stash)) }
        if s.tokens != before.tokens { session.enqueue(.bagTokens(s.tokens)) }
        session.enqueue(.bagTouch)
    }
}
