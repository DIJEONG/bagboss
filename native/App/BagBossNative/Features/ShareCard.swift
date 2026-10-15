import SwiftUI
import UIKit
import BBSim

// 결과 공유(docs/01 2단계 ⑤): 결과 신문 1면(보도 사진 NewsPhoto + 머리기사 + 점수) · 타워 결과 카드를 그림(UIImage)으로 그려
// 시스템 공유 시트(UIActivityViewController)로 넘긴다. 그림은 SwiftUI ImageRenderer — 화면의 결과 화면과 같은 문구 함수(newsCopy)를 쓴다.
// 단추는 누를 때 그린다(보도 사진이 '현상 중'에서 늦게 도착해도 최신으로).

@MainActor
enum ResultShare {
    static let width: CGFloat = 360

    static func newsImage(_ info: NewsInfo, session: GameSession) -> UIImage? {
        let N = newsCopy(info, session.content, dmgK: session.data.dmgK)
        return render(NewsShareCard(info: info, copy: N, photo: session.newsPhoto, best: Int(session.meta.best.score)))
    }

    static func towerImage(_ r: TowerResult, session: GameSession) -> UIImage? {
        render(TowerShareCard(r: r, content: session.content))
    }

    static func render<V: View>(_ v: V) -> UIImage? {
        let r = ImageRenderer(content: v.frame(width: width).environment(\.colorScheme, .dark))
        r.scale = 3
        r.isOpaque = true
        return r.uiImage
    }

    static func newsText(_ info: NewsInfo) -> String {
        KE("BAG BOSS · 막차 — \(info.score.formatted())점\(info.daily ? " (오늘의 노선)" : "")", "BAG BOSS — \(info.score.formatted()) pts\(info.daily ? " (Daily Route)" : "")")
    }
    static func towerText(_ r: TowerResult) -> String {
        KE("BAG BOSS · 막차 엘리베이터 타워 — \(r.floor)층 · \(mmss(r.seconds))\(r.daily != nil ? " (오늘의 타워)" : "")",
           "BAG BOSS Elevator Tower — \(r.floor)F · \(mmss(r.seconds))\(r.daily != nil ? " (Daily Tower)" : "")")
    }

    /// 시스템 공유 시트
    static func present(image: UIImage?, text: String) {
        var items: [Any] = [text]
        if let image { items.insert(image, at: 0) }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let top = GameCenterService.topViewController() else { return }
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }
}

/// 결과 화면 단추 줄에 붙이는 공유 단추
struct ShareResultButton: View {
    var paper = false
    let make: @MainActor () -> (UIImage?, String)
    var body: some View {
        let b = Button {
            let (img, txt) = make()
            ResultShare.present(image: img, text: txt)
        } label: { Label(KE("공유", "Share"), systemImage: "square.and.arrow.up").labelStyle(.titleAndIcon) }
        .accessibilityLabel(KE("결과 공유", "Share result"))
        if paper { b.buttonStyle(PaperButton()) } else { b.buttonStyle(PixelButtonLook(minHeight: 40)) }
    }
}

/// 공유용 신문 1면(화면 결과 신문을 한 장에 맞게 줄인 것)
struct NewsShareCard: View {
    let info: NewsInfo
    let copy: NewsCopy
    let photo: UIImage?
    let best: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 2) {
                Text("THE DAILY TRANSIT").font(.galmuri(20, bold: true)).tracking(1.6).foregroundStyle(PX.paperInk)
                Text(info.daily ? KE("오늘의 노선 특별판 · 25¢", "Daily Route Special · 25¢") : KE("데일리 트랜짓 · 뉴욕 지하철판 · 25¢", "New York Subway Edition · 25¢"))
                    .font(.galmuriSmall(10)).foregroundStyle(PX.paperSub)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            .overlay(VStack(spacing: 2) { Rectangle().frame(height: 1); Rectangle().frame(height: 1) }.foregroundStyle(PX.paperInk), alignment: .bottom)
            Text(copy.head).font(.galmuri(18, bold: true)).foregroundStyle(PX.paperInk).fixedSize(horizontal: false, vertical: true)
            Text(copy.deck).font(.galmuriSmall(10)).foregroundStyle(Color(px: "#4a3e28")).fixedSize(horizontal: false, vertical: true)
            ZStack {
                Color(px: "#2a2620")
                if let p = photo { Image(uiImage: p).resizable().interpolation(.none) }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(Rectangle().stroke(PX.paperInk, lineWidth: 2))
            Text(copy.p1).font(.galmuriSmall(10)).foregroundStyle(PX.paperInk).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .lastTextBaseline) {
                Text("\(info.score.formatted())").font(.galmuri(26, bold: true)).foregroundStyle(PX.paperInk)
                Text(tr("점")).font(.galmuri(13)).foregroundStyle(PX.paperInk)
                if info.newBest { Text(KE("최고 기록 경신", "New best!")).font(.galmuri(11, bold: true)).foregroundStyle(Color(px: "#a8241c")) }
                Spacer()
                Text("\(tr("최고")) \(best.formatted())").font(.galmuriSmall(10)).foregroundStyle(PX.paperSub)
            }
            Text("BAG BOSS · 막차").font(.galmuri(10, bold: true)).foregroundStyle(PX.paperSub).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(PX.paper)
    }
}

/// 공유용 타워 결과 카드
struct TowerShareCard: View {
    let r: TowerResult
    let content: FlowContent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(r.daily.map { "\(KE("오늘의 타워", "Daily Tower")) · \($0)" } ?? "\(tr("엘리베이터 타워")) · \(content.otName(r.ot))")
                .font(.galmuriSmall(11)).foregroundStyle(PX.sub)
            Text(r.win ? KE("\(content.towerTop)층 돌파!", "Cleared \(content.towerTop)F!") : KE("\(r.floor)층에서 멈췄다", "Stopped at \(r.floor)F"))
                .font(.galmuri(17, bold: true)).foregroundStyle(PX.ink)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(r.floor)F").font(.galmuri(44, bold: true)).foregroundStyle(PX.accent)
                Text(content.floorName(r.floor)).font(.galmuri(13)).foregroundStyle(PX.ink)
            }
            .frame(maxWidth: .infinity)
            HStack {
                stat(KE("걸린 시간", "Time"), mmss(r.seconds)); stat(KE("쓰러뜨린 적", "Defeated"), "\(r.kills)"); stat(KE("문밖으로", "Thrown out"), "\(r.outs)")
            }
            if r.newRecord { Text(KE("새 기록", "New record")).font(.galmuri(12, bold: true)).foregroundStyle(PX.accent).frame(maxWidth: .infinity) }
            Text("BAG BOSS · 막차").font(.galmuri(10, bold: true)).foregroundStyle(PX.note).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Palette.bg)
        .pixelPanel(.frame)
    }
    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.galmuri(15, bold: true)).foregroundStyle(PX.accent)
            Text(k).font(.galmuriSmall(9)).foregroundStyle(PX.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6).pixelPanel(.plate)
    }
}
