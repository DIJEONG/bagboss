import SwiftUI
import UIKit
import BBContent
import BBSim
import BBUI

// 가방 실험실(N4 점검): 시작 가방(KITS) + 보류함 장난감 몇 개로 BagGridView 를 만져 본다.
// 조립: BagGridView 가 낸 BagIntent → BagEditor.apply → render. 쿨다운은 가짜로 흘려 updateCooldowns 를 확인한다.

@MainActor
final class BagLabModel {
    var editor: BagEditor
    weak var view: BagGridView?
    private var timer: Timer?

    init() {
        let store = try! ContentStore.bundled()
        let content = try! GameContent(store)
        let cat = try! BagCatalog(content, store: store)
        let kit = content.kits.first { $0.id == "basic" } ?? content.kits[0]
        var uid = 0
        let bag = kit.bag.map { s -> BagItem in uid += 1; return BagItem(id: s.id, uid: uid, x: s.x, y: s.y, rot: s.rot, opt: s.opt) }
        var e = BagEditor(catalog: cat, state: BagState(bag: bag, tokens: 6, imprints: ["4,1": "holster", "5,3": "pocket", "0,3": "worn"], uid: uid))
        // 보류함 장난감: 합성용 주먹 · 부적 · 밟기(새 장비) · 넥타이핀
        e.addToStash("punch", markNew: false)
        e.addToStash("charm", markNew: false)
        e.addToStash("stomp", markNew: true)
        e.addToStash("pin", markNew: false)
        editor = e
    }

    func attach(_ v: BagGridView) {
        view = v
        v.onIntent = { [weak self] intent in self?.handle(intent) }
        v.render(editor)
        #if DEBUG
        // 점검용 실행 인자: -bagshot drag(끌기 미리보기) · merge(합성 창) — 시뮬레이터 스크린숏 자동화
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-bagshot"), i + 1 < args.count {
            let mode = args[i + 1], stomp = editor.state.stash.first { $0.id == "stomp" }?.uid
            let pStash = editor.state.stash.first { $0.id == "punch" }?.uid, pBag = editor.state.bag.first { $0.id == "punch" }?.uid
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak v] in
                if mode == "drag", let u = stomp { v?.debugDrag(uid: u, toGridCell: 1.5, 2.5, release: false) }
                if mode == "merge", let a = pStash, let b = pBag { v?.debugAskMerge(src: a, dst: b) }
            }
        }
        #endif
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick(1 / 30) }
        }
    }

    func handle(_ intent: BagIntent) {
        let r = editor.apply(intent)
        view?.render(editor)
        if r.title != nil || r.message != nil { view?.showMessage(r.title, r.message) }
    }

    /// 가짜 쿨다운: 가방 기술의 t 를 흘린다(가득 차면 0 으로) — 상태를 바꾸는 행동이 아니라 화면 점검용
    private func tick(_ dt: Double) {
        var s = editor.state
        for i in s.bag.indices { s.bag[i].t += dt; if s.bag[i].t > 4.5 { s.bag[i].t = 0 } }
        editor.replaceState(s)
        view?.updateCooldowns(s)
    }
}

struct BagGridRepresentable: UIViewRepresentable {
    let model: BagLabModel
    func makeUIView(context: Context) -> BagGridView { let v = BagGridView(); model.attach(v); return v }
    func updateUIView(_ v: BagGridView, context: Context) {}
}

struct BagLab: View {
    @State private var model = BagLabModel()
    var body: some View {
        GeometryReader { geo in
            VStack {
                BagGridRepresentable(model: model)
                    .frame(width: geo.size.width, height: BagGridView().preferredHeight(forWidth: geo.size.width))
                Spacer(minLength: 0)
            }
        }
        .background(Color(red: 0.07, green: 0.06, blue: 0.12))
        .navigationTitle("가방")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
