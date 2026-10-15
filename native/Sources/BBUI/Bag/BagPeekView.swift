#if canImport(UIKit)
import UIKit
import BBSim
import BBContent

// 바텀시트 엿보기 줄(docs/09): 지금 콤보 경로를 같은 크기 가로 카드로 한 줄에 늘어놓는다(가방 모양 그대로면 키 큰 타일 아래가 빈다).
//   카드 = 순서 배지(경로 색) · 이름 · 피해 · 쿨다운 · 쿨다운 막대. 지금 친 칸은 흰 테두리 · 다음 칸은 주황 테두리 · 이미 친 칸은 흐리게.
//   폭에 맞춰 줄이고, 최소 폭(84pt)보다 좁아지면 가로로 밀린다(지금 · 다음 칸이 보이게 옮겨 둔다). 카드 높이 = 뷰 높이.
// 상태는 고치지 않는다 — 호스트가 render(_:route:step:) 로 편집기 상태와 경로(uid 들 · 진행 칸)를, updateCooldowns(_:) 로 쿨다운을 준다. 누르면 onTap(시트 펼치기).

@MainActor
public final class BagPeekView: UIView {
    /// 눌렀을 때(호스트: 가방 펼치기)
    public var onTap: (() -> Void)?
    private let scroller = UIScrollView(), line = CAShapeLayer()
    private var cards: [PeekCard] = []
    private let empty = UILabel()
    private var input: (e: BagEditor, route: [Int], step: Int)?
    private var sig = ""
    /// 카드 순서대로 uid · 쿨다운 전체 길이
    private var cdFull: [(uid: Int, full: Double)] = []
    /// 마지막으로 받은 쿨다운 값(편집기 상태의 t 는 배치가 바뀔 때만 새로 온다)
    private var lastT: [Int: Double] = [:]
    static let minCardW: CGFloat = 84, maxCardW: CGFloat = 150, gap: CGFloat = 6

    public override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = .clear
        scroller.showsHorizontalScrollIndicator = false; scroller.alwaysBounceHorizontal = false; scroller.clipsToBounds = true
        addSubview(scroller)
        line.fillColor = nil; line.strokeColor = bbColor("#ffb547").cgColor; line.lineWidth = 2; line.lineDashPattern = [5, 4]
        scroller.layer.addSublayer(line)
        empty.numberOfLines = 2; empty.textColor = bbColor("#a99f88"); empty.textAlignment = .center
        empty.font = UIFont(name: GameFonts.ui, size: 11) ?? .systemFont(ofSize: 11)
        empty.adjustsFontSizeToFitWidth = true; empty.minimumScaleFactor = 0.8
        addSubview(empty)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    @objc private func tapped() { onTap?() }

    /// 편집기 상태 + 보여 줄 경로(uid 순서) · 지금까지 친 칸 수
    public func render(_ e: BagEditor, route: [Int], step: Int) {
        input = (e, route, step)
        let s = e.state
        let k = route.map { u in s.bag.first { $0.uid == u }.map { "\($0.uid):\($0.id)\($0.tier)r\($0.rot)@\($0.x),\($0.y)" } ?? "-" }.joined(separator: ",")
        let newSig = "\(k)|\(step)|\(Int(bounds.width))x\(Int(bounds.height))|\(Loc.lang)"
        if newSig == sig { return }
        sig = newSig
        rebuild()
    }

    /// 쿨다운 막대만(몇 프레임마다 — 가방 격자와 같은 값)
    public func updateCooldowns(_ s: BagState) {
        for (i, c) in cdFull.enumerated() where i < cards.count {
            let t = s.bag.first { $0.uid == c.uid }?.t ?? 0
            lastT[c.uid] = t
            cards[i].setCooldown(c.full > 0 ? t / c.full : 0, active: c.full > 0)
        }
    }

    public override func layoutSubviews() { super.layoutSubviews(); sig = ""; if let i = input { render(i.e, route: i.route, step: i.step) } }

    private func rebuild() {
        guard let (e, route, step) = input, bounds.width > 0 else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        let c = e.catalog, s = e.state, R = c.rules
        let items = route.compactMap { u in s.bag.first { $0.uid == u } }
        empty.isHidden = !items.isEmpty
        empty.text = bagTr("시작기 ▶ 옆에 ●·■를 붙이면 콤보가 생겨요")
        empty.frame = bounds.insetBy(dx: 8, dy: 0)
        accessibilityLabel = items.isEmpty ? bagTr("콤보 없음 — 눌러서 가방 열기")
            : bagTr("콤보 경로") + " " + items.compactMap { c.item($0.id)?.name }.map(bagTr).joined(separator: ", ") + " — " + bagTr("눌러서 가방 열기")
        scroller.frame = bounds
        // 카드 폭: 폭에 맞춰 나누되 84 ~ 150pt — 넘치면 밀기
        let n = CGFloat(items.count), g = Self.gap
        let fit = (bounds.width - g * max(0, n - 1)) / max(1, n)
        let cw = floor(min(Self.maxCardW, max(Self.minCardW, fit))), ch = bounds.height
        while cards.count < items.count { let v = PeekCard(); scroller.addSubview(v); cards.append(v) }
        while cards.count > items.count { cards.removeLast().removeFromSuperview() }
        let sets = R.sets(s.bag), badges = c.routeBadges(s.bag)
        let now = step - 1   // 방금 나간 칸(아직 안 쳤으면 -1)
        cdFull = []
        var x: CGFloat = 0, pts: [CGPoint] = []
        for (i, b) in items.enumerated() {
            let spec = makeTileSpec(c, s, b, inStash: false, sets: sets, badges: badges)
            let it = c.item(b.id)
            var full = 0.0
            if let k = s.bag.firstIndex(where: { $0.uid == b.uid }), it?.kind == "skill" || it?.kind == "dodge" { full = R.stats(k, bag: s.bag, sets: sets, imprints: s.imprints).cd ?? 0 }
            else if it?.kind == "heal" { full = (it?.cd ?? 0) - Double(b.tier - 1) }
            cdFull.append((b.uid, full))
            let st: PeekCard.State = i == now ? .now : i == step ? .next : i < now ? .done : .later
            cards[i].frame = CGRect(x: x, y: 0, width: cw, height: ch)
            cards[i].configure(spec, name: bagTr(it?.name ?? spec.name), state: st)
            let t = lastT[b.uid] ?? b.t
            cards[i].setCooldown(full > 0 ? t / full : 0, active: full > 0)
            pts.append(CGPoint(x: x + cw / 2, y: PeekCard.badgeMidY))
            x += cw + g
        }
        let contentW = max(0, x - g)
        scroller.contentSize = CGSize(width: contentW, height: ch)
        scroller.isScrollEnabled = contentW > bounds.width + 0.5
        // 밀리는 줄이면 지금 · 다음 칸이 보이게
        if scroller.isScrollEnabled, !items.isEmpty {
            let k = max(0, min(items.count - 1, max(now, 0))), fx = CGFloat(k) * (cw + g)
            let maxX = contentW - bounds.width
            scroller.contentOffset.x = max(0, min(maxX, fx - (cw + g) * 0.5))
        } else { scroller.contentOffset = .zero }
        line.frame = CGRect(x: 0, y: 0, width: contentW, height: ch)
        let p = CGMutablePath(); if pts.count >= 2 { p.addLines(between: pts) }
        line.path = p
        scroller.layer.insertSublayer(line, at: 0)   // 카드 뒤 — 사이 틈에만 보인다
    }
}

/// 엿보기 카드 하나(같은 크기 가로 카드) — 높이에 따라 글자 크기를 고른다(낮으면 이름 한 줄)
@MainActor
final class PeekCard: UIView {
    enum State { case done, now, next, later }
    static let badgeMidY: CGFloat = 13
    private let badge = UILabel(), mark = UILabel(), name = UILabel(), stats = UILabel()
    private let barBG = CALayer(), bar = CALayer()
    private var ready = false, state: State = .later, fcol = "#c9a24a"

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.borderWidth = 2
        for l in [badge, mark, name, stats] { addSubview(l) }
        badge.textAlignment = .center; badge.textColor = bbColor("#140e1c")
        mark.textAlignment = .right
        name.textColor = bbColor("#f1e6d0"); name.lineBreakMode = .byTruncatingTail
        name.adjustsFontSizeToFitWidth = true; name.minimumScaleFactor = 0.6
        stats.adjustsFontSizeToFitWidth = true; stats.minimumScaleFactor = 0.7
        barBG.backgroundColor = bbColor("#0e0d14").cgColor; bar.backgroundColor = bbColor("#c98a2c").cgColor; bar.anchorPoint = .zero
        barBG.addSublayer(bar); layer.addSublayer(barBG)
    }
    required init?(coder: NSCoder) { fatalError() }

    private static func font(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? GameFonts.uiBold : GameFonts.ui, size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    func configure(_ s: TileSpec, name nm: String, state st: State) {
        state = st; fcol = s.fcol
        let W = bounds.width, H = bounds.height, tall = H >= 96, p: CGFloat = 6
        let big: CGFloat = tall ? 14.67 : 11   // PXType m · s
        backgroundColor = st == .now ? bbMix(s.fcol, 0.42, "#16111f") : bbMix(s.fcol, 0.2, "#16111f")
        alpha = st == .done ? 0.5 : 1
        // 순서 배지(경로 색) · ★
        badge.font = Self.font(11, bold: true)
        badge.text = s.badge + (s.tier > 1 ? " ★\(s.tier)" : "")
        badge.backgroundColor = bbColor(s.badgeColor)
        let bw = ceil((badge.text! as NSString).size(withAttributes: [.font: badge.font!]).width) + 8
        badge.frame = CGRect(x: p, y: Self.badgeMidY - 8, width: min(bw, W - p * 2), height: 16)
        // 지금 · 다음 꼬리표
        mark.font = Self.font(11, bold: true)
        mark.text = st == .now ? KE("지금", "NOW") : st == .next ? KE("다음", "NEXT") : ""
        mark.textColor = st == .now ? .white : bbColor("#ffb547")
        mark.frame = CGRect(x: badge.frame.maxX + 2, y: badge.frame.minY, width: max(0, W - p - badge.frame.maxX - 2), height: 16)
        mark.isHidden = mark.frame.width < 22
        // 이름(높으면 두 줄 · 크게)
        name.font = Self.font(big, bold: true); name.numberOfLines = tall ? 2 : 1
        name.text = nm
        // 피해 · 값 · 쿨다운
        let sv = NSMutableAttributedString(), sf = Self.font(tall ? 14.67 : 11)
        if let d = s.stats.dmg { sv.append(NSAttributedString(string: "⚔︎" + d, attributes: [.font: sf, .foregroundColor: bbColor("#ffd9a8")])) }
        if let v = s.stats.val { sv.append(NSAttributedString(string: (sv.length > 0 ? " " : "") + v, attributes: [.font: sf, .foregroundColor: bbColor(s.stats.valColor ?? "#f1e6d0")])) }
        if let c = s.stats.cd, s.stats.hasCd { sv.append(NSAttributedString(string: (sv.length > 0 ? " " : "") + "◷" + c, attributes: [.font: sf, .foregroundColor: bbColor("#f1e6d0", 0.8)])) }
        stats.attributedText = sv
        let barH: CGFloat = 5, sh = ceil(sf.lineHeight)
        barBG.frame = CGRect(x: p, y: H - p - barH, width: W - p * 2, height: barH)
        stats.frame = CGRect(x: p, y: barBG.frame.minY - 3 - sh, width: W - p * 2, height: sh)
        let ny = badge.frame.maxY + 3
        name.frame = CGRect(x: p, y: ny, width: W - p * 2, height: max(0, min(ceil(name.font.lineHeight) * CGFloat(name.numberOfLines), stats.frame.minY - ny - 1)))
        updateEdge()
    }

    /// 쿨다운 진행(0…1) — 막대 폭 · 다 차면 노란 막대
    func setCooldown(_ k: Double, active: Bool) {
        barBG.isHidden = !active
        let f = active ? min(1, max(0, k)) : 0
        bar.frame = CGRect(x: 0, y: 0, width: barBG.bounds.width * f, height: barBG.bounds.height)
        let r = active && k >= 1
        if r != ready { ready = r; bar.backgroundColor = bbColor(r ? "#ffe27a" : "#c98a2c").cgColor; updateEdge() }
    }

    private func updateEdge() {
        layer.borderColor = (state == .now ? UIColor.white : state == .next ? bbColor("#ffb547") : ready ? bbColor("#ffd66e") : bbColor(fcol)).cgColor
        layer.borderWidth = state == .now || state == .next ? 3 : 2
    }
}

/// 웹 KE(ko, en) — 영어가 바로 옆(번역 범위 점검이 건너뛴다)
private func KE(_ ko: String, _ en: String) -> String { Loc.ke(ko, en) }

private let bagShortNames = ["hmback": "되치기", "charm": "부적", "pin": "타이핀", "ring": "반지", "metro": "메트로", "cuff": "커프스", "paper": "신문", "earph": "이어폰", "bandage": "반창고", "duck": "쭈그리기"]

/// 웹 itemHTML · tileLabel 에 들어가는 값(가방 격자 · 엿보기 줄 공용)
@MainActor
func makeTileSpec(_ c: BagCatalog, _ s: BagState, _ b: BagItem, inStash: Bool, sets: [String: [Int]], badges: [Int: RouteBadge], rot: Int? = nil) -> TileSpec {
    let R = c.rules, it = c.item(b.id)
    let r = rot ?? b.rot, L = c.labelRect(b.id, rot: r), role = R.role(b.id), k = it?.kind ?? ""
    let sk = k == "skill" || k == "dodge"
    let shape = R.shape(b.id, rot: r), (w, h) = R.box(b, rot: r)
    let rb = badges[b.uid]
    let badge = rb != nil ? "\(rb!.n)\(BagCatalog.roleGlyph[role] ?? "")" : sk ? (BagCatalog.roleGlyph[role] ?? "◇") : "◆"
    let badgeColor = rb.map { BagCatalog.routeColors[$0.color] } ?? (sk ? "#8a82a6" : "#c9a24a")
    let nm = (L.w == 1 ? bagShortNames[b.id] : nil) ?? it?.sn ?? it?.name ?? b.id
    let tight = L.w == 1 && (nm.split(separator: " ").map(\.count).max() ?? 0) >= 4
    let fcol = it?.fcol ?? it?.fam.flatMap { c.families[$0]?.c } ?? (sk ? "#d8cfae" : "#c9a24a")
    let inSet = !inStash && (it?.fam.map { sets[$0]?.contains(b.uid) ?? false } ?? false)
    return TileSpec(id: b.id, uid: b.uid, tier: b.tier, rot: r, shape: shape, boxW: w, boxH: h, label: L, fcol: fcol, badge: badge, badgeColor: badgeColor,
                    name: nm, tight: tight, stats: c.tileStats(b, in: s), optColor: b.opt.flatMap { c.options[$0.k]?.c },
                    setColor: inSet ? it?.fam.flatMap { c.families[$0]?.c } : nil, selected: s.selUid == b.uid, inStash: inStash,
                    folded: inStash && R.stashFoot(b, rot: r).fold, isNew: inStash && s.newUids.contains(b.uid))
}
#endif
