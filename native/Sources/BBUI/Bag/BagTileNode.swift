#if canImport(UIKit)
import UIKit
import BBSim
import BBContent

// 가방 타일 하나(웹 itemHTML · tileLabel): 모양대로 칸 조각 · 바깥 변 테두리 · 이름표(역할 배지 · ★ · 이름 · 피해 · 쿨다운) · 쿨다운 막대 · 쿨다운 그늘.
// CALayer 묶음 — 내용이 바뀔 때(서명 비교)만 다시 짓고, 쿨다운은 setCooldown 으로 막대 · 그늘 높이만 바꾼다.

func bbColor(_ hex: String, _ a: CGFloat = 1) -> UIColor {
    let v = UInt32(hex.hasPrefix("#") ? String(hex.dropFirst()) : hex, radix: 16) ?? 0
    return UIColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: a)
}
/// CSS color-mix(in srgb, a k%, b)
func bbMix(_ a: String, _ k: CGFloat, _ b: String) -> UIColor {
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, al: CGFloat = 0
    bbColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &al); bbColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &al)
    return UIColor(red: r1 * k + r2 * (1 - k), green: g1 * k + g2 * (1 - k), blue: b1 * k + b2 * (1 - k), alpha: 1)
}

/// 타일 그리기에 필요한 값 전부(서명 = 다시 지을지 판단)
struct TileSpec: Equatable {
    var id: String, uid: Int, tier: Int, rot: Int
    var shape: [Cell]
    /// 모양 상자(칸) — 보류함 접힘이면 실제 모양 상자, 그리는 칸은 frame 크기로 늘린다
    var boxW: Int, boxH: Int
    var label: LabelRect
    var fcol: String
    var badge: String, badgeColor: String
    var name: String, tight: Bool
    var stats: TileStats
    var optColor: String?
    var setColor: String?
    var selected: Bool, inStash: Bool, folded: Bool, isNew: Bool
}

extension TileSpec {
    /// 대각선으로 뒤집은 모양(가로 보관함 그리기 — BagGridView sheet). 자리 · 이름표 상자도 같이 뒤집는다
    var transposed: TileSpec {
        var t = self
        t.shape = shape.map { Cell($0.y, $0.x) }
        t.boxW = boxH; t.boxH = boxW
        var L = label; L.x = label.y; L.y = label.x; L.w = label.h; L.h = label.w
        t.label = L
        return t
    }
}

@MainActor
final class BagTileNode {
    let root = CALayer()
    private let body = CAShapeLayer(), edge = CAShapeLayer(), setLine = CAShapeLayer()
    private let shade = CALayer(), shadeMask = CAShapeLayer()
    private let labelBox = CALayer()
    private let barBG = CALayer(), bar = CALayer()
    private let newTag = CATextLayer()
    private(set) var spec: TileSpec?
    private var lang = ""   // 지어 둔 글자의 언어(Loc.lang)
    private var ready = false
    private var hasCdBar = false

    init() {
        root.masksToBounds = false
        for l in [body, setLine, shade, labelBox, edge] { root.addSublayer(l) }
        shade.backgroundColor = UIColor(red: 8 / 255, green: 6 / 255, blue: 16 / 255, alpha: 0.42).cgColor
        shade.mask = shadeMask
        edge.fillColor = nil; edge.lineWidth = 2; edge.lineCap = .square
        setLine.fillColor = nil; setLine.lineWidth = 1
        barBG.backgroundColor = bbColor("#0e0d14").cgColor; bar.backgroundColor = bbColor("#c98a2c").cgColor
        barBG.addSublayer(bar); root.addSublayer(barBG)
        bar.anchorPoint = .zero
        newTag.backgroundColor = bbColor("#7dffa0").cgColor; newTag.alignmentMode = .center; newTag.isHidden = true
        root.addSublayer(newTag)
    }

    /// 칸 좌표 → 타일 안 사각형
    private func cellRect(_ c: Cell, _ size: CGSize, _ s: TileSpec) -> CGRect {
        let cw = size.width / CGFloat(s.boxW), ch = size.height / CGFloat(s.boxH)
        return CGRect(x: CGFloat(c.x) * cw, y: CGFloat(c.y) * ch, width: cw, height: ch)
    }

    func configure(_ s: TileSpec, size: CGSize, scale: CGFloat) {
        let sizeChanged = root.bounds.size != size
        root.bounds = CGRect(origin: .zero, size: size)
        if spec == s && !sizeChanged && lang == Loc.lang { return }
        lang = Loc.lang   // 언어가 바뀌면 이름 글자를 다시 짓는다
        spec = s
        let has = Set(s.shape)
        // 조각 · 바깥 변
        let bp = CGMutablePath(), ep = CGMutablePath(), sp = CGMutablePath()
        for c in s.shape {
            let r = cellRect(c, size, s)
            bp.addRect(r)
            let i: CGFloat = 1   // 선 두께 2 의 절반 — 안쪽으로
            if !has.contains(Cell(c.x, c.y - 1)) { ep.move(to: CGPoint(x: r.minX, y: r.minY + i)); ep.addLine(to: CGPoint(x: r.maxX, y: r.minY + i)) }
            if !has.contains(Cell(c.x, c.y + 1)) { ep.move(to: CGPoint(x: r.minX, y: r.maxY - i)); ep.addLine(to: CGPoint(x: r.maxX, y: r.maxY - i)) }
            if !has.contains(Cell(c.x - 1, c.y)) { ep.move(to: CGPoint(x: r.minX + i, y: r.minY)); ep.addLine(to: CGPoint(x: r.minX + i, y: r.maxY)) }
            if !has.contains(Cell(c.x + 1, c.y)) { ep.move(to: CGPoint(x: r.maxX - i, y: r.minY)); ep.addLine(to: CGPoint(x: r.maxX - i, y: r.maxY)) }
            sp.addRect(r.insetBy(dx: 3.5, dy: 3.5))
        }
        body.path = bp; body.fillColor = bbMix(s.fcol, 0.2, "#16111f").cgColor
        shadeMask.path = bp; shade.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: 0))
        shadeMask.frame = CGRect(origin: .zero, size: size)
        edge.path = ep
        setLine.path = s.setColor == nil ? nil : sp; setLine.strokeColor = s.setColor.map { bbColor($0).cgColor }
        updateEdgeColor()
        root.opacity = s.inStash && !s.isNew && !s.selected ? 0.82 : 1
        buildLabel(s, size: size, scale: scale)
    }

    private func updateEdgeColor() {
        guard let s = spec else { return }
        edge.strokeColor = (s.selected ? UIColor.white : ready ? bbColor("#ffd66e") : bbColor(s.fcol)).cgColor
    }

    private func text(_ str: NSAttributedString, scale: CGFloat) -> CATextLayer {
        let t = CATextLayer(); t.string = bagTrA(str)   // 타일 글자는 모두 여기로 — 번역 자리 하나
        t.contentsScale = scale; t.isWrapped = true; t.truncationMode = .end; t.alignmentMode = .left   // (예전엔 위 주석에 묻혀 안 불렸다 — 글자가 1배 · 줄바꿈 없음)
        return t
    }

    private func buildLabel(_ s: TileSpec, size: CGSize, scale: CGFloat) {
        labelBox.sublayers?.forEach { $0.removeFromSuperlayer() }
        let cw = size.width / CGFloat(s.boxW), ch = size.height / CGFloat(s.boxH)
        let L = s.label
        let lr = CGRect(x: CGFloat(L.x) * cw, y: CGFloat(L.y) * ch, width: CGFloat(L.w) * cw, height: CGFloat(L.h) * ch)
        labelBox.frame = lr; labelBox.masksToBounds = true
        let lay = L.w >= 2 && L.h == 1 ? "row" : L.w == 1 && L.h == 1 ? "s1" : "col"
        let shadow = NSShadow(); shadow.shadowColor = bbColor("#0e0d14"); shadow.shadowOffset = CGSize(width: 1, height: 1); shadow.shadowBlurRadius = 0
        let f9 = UIFont.systemFont(ofSize: 9, weight: .bold), f8 = UIFont.systemFont(ofSize: 8, weight: .bold)
        // 머리줄: 배지 · ★ · 옵션 점
        let bstr = NSAttributedString(string: s.badge, attributes: [.font: f9, .foregroundColor: bbColor("#140e1c")])
        let bw = ceil(bstr.size().width) + 4, bh: CGFloat = 11
        let badge = CALayer(); badge.backgroundColor = bbColor(s.badgeColor).cgColor; badge.frame = CGRect(x: 3, y: 3, width: bw, height: bh)
        let bt = text(bstr, scale: scale); bt.frame = CGRect(x: 2, y: -0.5, width: bw, height: bh); badge.addSublayer(bt)
        labelBox.addSublayer(badge)
        var hx = 3 + bw + 2
        if s.tier > 1 {
            let tr = text(NSAttributedString(string: "★\(s.tier)", attributes: [.font: f8, .foregroundColor: bbColor(BagCatalog.tierColors[min(5, s.tier)]), .shadow: shadow]), scale: scale)
            let w = ceil((tr.string as! NSAttributedString).size().width) + 1
            tr.frame = CGRect(x: hx, y: 3, width: w, height: 11); labelBox.addSublayer(tr); hx += w + 1
        }
        if let oc = s.optColor {
            let od = CALayer(); od.backgroundColor = bbColor(oc).cgColor; od.frame = CGRect(x: hx, y: 6, width: 5, height: 5)
            od.shadowColor = bbColor("#0e0d14").cgColor; od.shadowOffset = CGSize(width: 1, height: 1); od.shadowOpacity = 1; od.shadowRadius = 0
            labelBox.addSublayer(od); hx += 7
        }
        // 이름
        let nf = s.tight ? f8 : f9
        let nm = NSAttributedString(string: s.name, attributes: [.font: nf, .foregroundColor: bbColor("#f1e6d0"), .shadow: shadow])
        let nt = text(nm, scale: scale)
        if lay == "row" { nt.isWrapped = false; nt.frame = CGRect(x: hx + 1, y: 2.5, width: max(0, lr.width - hx - 3), height: 12) }
        else { nt.frame = CGRect(x: 3, y: 15, width: lr.width - 5, height: max(0, min(24, lr.height - 26))) }
        labelBox.addSublayer(nt)
        // 피해 · 값 · 쿨다운
        let st = s.stats, sk = st.hasCd && st.val == nil
        let sv = NSMutableAttributedString()
        if let d = st.dmg { sv.append(NSAttributedString(string: "⚔︎" + d, attributes: [.font: f8, .foregroundColor: bbColor("#ffd9a8"), .shadow: shadow])) }
        if let v = st.val { sv.append(NSAttributedString(string: (sv.length > 0 ? " " : "") + v, attributes: [.font: f8, .foregroundColor: bbColor(st.valColor ?? "#f1e6d0"), .shadow: shadow])) }
        if let c = st.cd, sk { sv.append(NSAttributedString(string: (sv.length > 0 ? " " : "") + "◷" + c, attributes: [.font: f8, .foregroundColor: bbColor("#f1e6d0", 0.8), .shadow: shadow])) }
        let showSv = sv.length > 0 && !(lay == "s1" && st.hasCd) && !s.folded
        if showSv {
            let svt = text(sv, scale: scale); svt.isWrapped = lay != "row"
            let h: CGFloat = lay == "row" ? 11 : 22
            svt.frame = CGRect(x: 3, y: lr.height - h - 6, width: lr.width - 5, height: h)
            if lay == "s1" { svt.frame.origin.y = lr.height - 17 }
            labelBox.addSublayer(svt)
        }
        newTag.isHidden = !s.isNew
        if s.isNew {
            newTag.string = NSAttributedString(string: bagTr("NEW · 탭: 장착"), attributes: [.font: UIFont.systemFont(ofSize: 7, weight: .heavy), .foregroundColor: bbColor("#1a1206")])
            newTag.contentsScale = scale
            newTag.frame = CGRect(x: 1, y: size.height - 12, width: size.width - 2, height: 11)
        }
        // 쿨다운 막대(가방 안 기술 · 반창고만)
        hasCdBar = st.hasCd && !s.inStash
        barBG.isHidden = !hasCdBar
        barBG.frame = CGRect(x: lr.minX + 4, y: lr.maxY - 5, width: max(0, lr.width - 7), height: 3)
        bar.frame = CGRect(x: 0, y: 0, width: 0, height: 3)
    }

    /// 쿨다운 진행(0…1) — 막대 폭 · 위에서부터 그늘(웹 .cdo) · 준비 테두리
    func setCooldown(_ p: Double, active: Bool) {
        guard spec != nil else { return }
        let k = active ? 1 - min(1, max(0, p)) : 0
        shade.frame = CGRect(x: 0, y: 0, width: root.bounds.width, height: root.bounds.height * k)
        if hasCdBar { bar.frame = CGRect(x: 0, y: 0, width: barBG.bounds.width * (active ? min(1, p) : 0), height: 3) }
        let r = active && p >= 1
        if r != ready {
            ready = r
            bar.backgroundColor = bbColor(r ? "#ffe27a" : "#c98a2c").cgColor
            updateEdgeColor()
        }
    }
}
#endif
