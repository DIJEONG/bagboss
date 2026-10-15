#if canImport(UIKit)
import UIKit
import BBSim
import BBContent

// 가방 화면(웹 33-bag-ui2 renderBag · 끌어 놓기 · 미리보기 · 합성 창 · 휴지통). docs/06 §2.7: UIKit 커스텀 뷰 + CALayer 픽셀 스킨.
// 이 뷰는 상태를 고치지 않는다 — 손짓을 BagIntent 로 바꿔 onIntent 로 내보내고, 호스트가 BagEditor 에 넣은 뒤 render(_:) 로 다시 준다.
// 그리기는 서명 비교로 바뀐 타일만 다시 짓고, 쿨다운은 updateCooldowns(_:) 가 막대 · 그늘만 바꾼다.
// 배치는 둘(docs/09): classic = 웹 그대로(가죽 틀 · 머리줄 · 세로 보관함 · 아래 정보 칸) ·
//   sheet = 네이티브 바텀시트(머리줄은 호스트 SwiftUI · 폭을 다 쓰는 큰 칸 · 가로 보관함 · 엄지 줄 · 고른 칸 말풍선).
//   sheet 의 가로 보관함은 그리기만 전치한다(보관함 칸 (x, y) ↔ 화면 (y, x)) — 보관함 2×4 규칙 · 저장 좌표는 그대로.

/// 가방 화면 배치
public enum BagLayoutStyle: Sendable { case classic, sheet }

@MainActor
public final class BagGridView: UIView {
    /// 손짓 → 편집 행동
    public var onIntent: ((BagIntent) -> Void)?
    /// 합성 굴림값 공급(웹 Math.random 한 번) — 호스트가 판 난수로 바꿔 끼운다
    public var randomRoll: () -> Double = { Double.random(in: 0..<1) }

    public private(set) var editor: BagEditor?
    /// 배치(classic = 웹 그대로 · sheet = 바텀시트)
    public var layoutStyle: BagLayoutStyle = .classic { didSet { if oldValue != layoutStyle { applyStyle(); setNeedsLayout() } } }
    /// sheet: 엄지 줄 오른쪽에 비워 둘 폭(호스트가 큰 필살 단추를 얹는다) · 엄지 줄 높이
    public var thumbReserve: CGFloat = 0 { didSet { if oldValue != thumbReserve { setNeedsLayout() } } }
    public var thumbRowHeight: CGFloat = 72 { didSet { if oldValue != thumbRowHeight { setNeedsLayout() } } }
    /// 단추를 눌렀을 때(호스트가 딸깍 소리 · 가벼운 진동을 설정에 맞춰 낸다)
    public var onButtonFeedback: (() -> Void)?
    private var sheet: Bool { layoutStyle == .sheet }
    private var cat: BagCatalog? { editor?.catalog }
    private var state: BagState? { editor?.state }

    // MARK: 배치 상수
    private let border: CGFloat = 12, pad: CGFloat = 4, headH: CGFloat = 24, gap: CGFloat = 10, pocketPad: CGFloat = 6, pocketTop: CGFloat = 10
    private let footH: CGFloat = 64, infoH: CGFloat = 92
    private var cs: CGFloat = 40
    /// 보관함 칸 크기 — classic 은 가방 칸과 같고, sheet 는 작은 가로 띠(가방 칸이 먼저)
    private var ps: CGFloat = 40
    private var gridRect = CGRect.zero, pocketRect = CGRect.zero, pocketSkinRect = CGRect.zero

    // MARK: 층
    private let frameLayer = CALayer()
    private let gridBG = CALayer()
    private var cells: [CALayer] = [], cellHi: [CALayer] = [], impMarks: [CALayer] = []
    private let pocketSkin = CALayer()
    private var pocketCells: [CALayer] = [], pocketHi: [CALayer] = []
    private let tilesLayer = CALayer(), pocketTilesLayer = CALayer(), overlayLayer = CALayer()
    private var tiles: [Int: BagTileNode] = [:]
    private var overlaySig = ""
    /// 쿨다운 전체 길이(uid → 초) — render 때 구해 둔다
    private var cdFull: [Int: Double] = [:]

    // MARK: 머리 · 발 · 정보
    private let titleLabel = UILabel(), hintLabel = UILabel(), tokenLabel = UILabel(), setsLabel = UILabel()
    private let rotButton = UIButton(type: .custom), undoButton = UIButton(type: .custom), autoButton = UIButton(type: .custom)
    private let combosLabel = UILabel(), infoLabel = UILabel()
    private let trashView = UIView(), trashIcon = CALayer(), trashLabel = UILabel()
    private let tokenIcon = CALayer()
    private let prevLabel = PaddedLabel(), toastLabel = PaddedLabel()
    private let rotFab = UIButton(type: .custom)
    private var mergeSheet: UIView?
    /// sheet: 보관함 이름 · 고른 칸 설명 카드(설명 상자 대신 — 보관함 띠 자리에 덮는다)
    private let stashLabel = UILabel()
    private let tipLabel = PaddedLabel()
    /// 빈 곳을 눌러 말풍선을 닫았다(다른 칸을 고르면 다시 보인다)
    private var tipDismissedFor: Int?

    // MARK: 끌기
    private struct Drag {
        var uid: Int, touch: UITouch?, start: CGPoint, gx: Int, gy: Int, rot: Int
        var moved = false
        var ghost: BagTileNode?
        var p = CGPoint.zero
        var tx = 0, ty = 0, inGrid = false
        var inPocket = false, ptx = 0, pty = 0
        var mergeT: Int?
        var onTrash = false
        var pk = ""
    }
    private var drag: Drag?
    private var lastTap: (uid: Int, t: TimeInterval)?
    private var scale: CGFloat { traitCollection.displayScale > 0 ? traitCollection.displayScale : 2 }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    /// 9-슬라이스: 모서리 edge 픽셀이 border pt 가 되게 정수배로 미리 키워 contentsCenter 로 늘린다(웹 border-image)
    private func nineSlice(_ l: CALayer, _ img: CGImage, edge: Int, size: Int, border: CGFloat) {
        let k = max(1, Int((border * scale / CGFloat(edge)).rounded()))
        l.contents = bbUpscale(img, k); nearest(l)
        l.contentsScale = scale
        let e = CGFloat(edge) / CGFloat(size)
        l.contentsCenter = CGRect(x: e, y: e, width: 1 - 2 * e, height: 1 - 2 * e)
    }

    private func nearest(_ l: CALayer) { l.magnificationFilter = .nearest; l.minificationFilter = .nearest }

    private func setup() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        let skin = BagPixelSkin.shared
        nineSlice(frameLayer, skin.frame, edge: 8, size: 24, border: border)   // 8 이미지 픽셀 → 12pt 테두리
        layer.addSublayer(frameLayer)
        gridBG.backgroundColor = bbColor("#120f22").cgColor
        gridBG.borderColor = bbColor("#0e0d14").cgColor; gridBG.borderWidth = 2
        layer.addSublayer(gridBG)
        for _ in 0..<(BagSpec.width * BagSpec.height) {
            let c = CALayer(); c.contents = skin.cell; nearest(c); layer.addSublayer(c); cells.append(c)
            let h = CALayer(); layer.addSublayer(h); cellHi.append(h)
        }
        nineSlice(pocketSkin, skin.pocket, edge: 6, size: 18, border: 9)
        layer.addSublayer(pocketSkin)
        for _ in 0..<(BagSpec.stashWidth * BagSpec.stashHeight) {
            let c = CALayer(); c.contents = skin.slot; nearest(c); layer.addSublayer(c); pocketCells.append(c)
            let h = CALayer(); layer.addSublayer(h); pocketHi.append(h)
        }
        for l in [tilesLayer, pocketTilesLayer, overlayLayer] { layer.addSublayer(l) }

        let mono = UIFont.systemFont(ofSize: 12, weight: .bold)
        titleLabel.text = bagTr(" 서류가방 "); titleLabel.font = mono; titleLabel.textColor = bbColor("#3a2414"); titleLabel.backgroundColor = bbColor("#e8d6a8")
        hintLabel.font = .systemFont(ofSize: 10); hintLabel.textColor = bbColor("#cfc39a"); hintLabel.adjustsFontSizeToFitWidth = true; hintLabel.minimumScaleFactor = 0.7
        tokenLabel.font = mono; tokenLabel.textColor = bbColor("#ffcf7a")
        tokenIcon.contents = skin.token; nearest(tokenIcon)
        layer.addSublayer(tokenIcon)
        setsLabel.font = .systemFont(ofSize: 10, weight: .bold); setsLabel.numberOfLines = 1; setsLabel.adjustsFontSizeToFitWidth = true
        for (b, t, a) in [(rotButton, "↻ 돌리기", #selector(tapRotate)), (undoButton, "↶ 되돌리기", #selector(tapUndo))] {
            styleButton(b, t, plate: true); b.addTarget(self, action: a, for: .touchUpInside)
        }
        styleButton(autoButton, "빈자리에 넣기", plate: false); autoButton.addTarget(self, action: #selector(tapAuto), for: .touchUpInside)
        combosLabel.numberOfLines = 0; combosLabel.font = .systemFont(ofSize: 10)
        infoLabel.numberOfLines = 0; infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        trashIcon.contents = skin.trash; nearest(trashIcon); trashView.layer.addSublayer(trashIcon)
        trashLabel.font = .systemFont(ofSize: 9, weight: .bold); trashLabel.textColor = bbColor("#e8d6a8"); trashLabel.textAlignment = .center; trashLabel.text = bagTr("버리기")
        trashView.addSubview(trashLabel)
        for v in [titleLabel, hintLabel, tokenLabel, setsLabel, rotButton, undoButton, combosLabel, trashView, autoButton, infoLabel] as [UIView] { addSubview(v) }
        prevLabel.numberOfLines = 0; prevLabel.backgroundColor = UIColor(red: 10 / 255, green: 8 / 255, blue: 18 / 255, alpha: 0.94)
        prevLabel.layer.borderColor = bbColor("#0e0d14").cgColor; prevLabel.layer.borderWidth = 2; prevLabel.isHidden = true; prevLabel.isUserInteractionEnabled = false
        toastLabel.numberOfLines = 0; toastLabel.backgroundColor = UIColor(red: 10 / 255, green: 8 / 255, blue: 18 / 255, alpha: 0.92)
        toastLabel.layer.borderColor = bbColor("#e8d6a8").cgColor; toastLabel.layer.borderWidth = 2; toastLabel.alpha = 0; toastLabel.isUserInteractionEnabled = false
        rotFab.setTitle("↻", for: .normal); rotFab.titleLabel?.font = .systemFont(ofSize: 26, weight: .bold); rotFab.setTitleColor(bbColor("#1a1206"), for: .normal)
        rotFab.backgroundColor = bbColor("#ffd34a"); rotFab.layer.borderColor = bbColor("#0e0d14").cgColor; rotFab.layer.borderWidth = 3; rotFab.layer.cornerRadius = 27
        rotFab.isHidden = true; rotFab.isMultipleTouchEnabled = true
        rotFab.addTarget(self, action: #selector(fabRotate), for: .touchDown)
        rotFab.accessibilityLabel = bagTr("회전")
        for v in [prevLabel, toastLabel, rotFab] as [UIView] { addSubview(v) }
        stashLabel.text = bagTr("보관함"); stashLabel.textColor = bbColor("#e8d6a8"); stashLabel.isHidden = true
        tipLabel.numberOfLines = 0; tipLabel.isHidden = true; tipLabel.isUserInteractionEnabled = true   // 카드 아래 단추(빈자리에 넣기)로 새지 않게 — 누름은 touchesBegan 이 받아 닫는다
        tipLabel.backgroundColor = bbColor("#f1e6d0"); tipLabel.layer.borderColor = bbColor("#3a2414").cgColor; tipLabel.layer.borderWidth = 2
        addSubview(stashLabel); addSubview(tipLabel)
        for b in [rotButton, undoButton, autoButton] { pixelPress(b) }
        rotButton.accessibilityLabel = bagTr("돌리기"); undoButton.accessibilityLabel = bagTr("되돌리기"); autoButton.accessibilityLabel = bagTr("빈자리에 넣기")
        trashView.isAccessibilityElement = true; trashView.accessibilityLabel = bagTr("버리기 — 타일을 여기로 끌어 놓기")
        applyStyle()
    }

    /// 눌림(1.5pt 아래로 · 어둡게) + 호스트 딸깍
    private func pixelPress(_ b: UIButton) {
        b.addAction(UIAction { [weak b] _ in b?.transform = CGAffineTransform(translationX: 0, y: 1.5); b?.alpha = 0.78 }, for: [.touchDown, .touchDragEnter])
        b.addAction(UIAction { [weak b] _ in b?.transform = .identity; b?.alpha = 1 }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        b.addAction(UIAction { [weak self] _ in self?.onButtonFeedback?() }, for: .touchUpInside)
    }

    /// 갈무리(없으면 시스템) — 도트 글꼴은 정수 크기로
    private static func pixelFont(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? GameFonts.uiBold : GameFonts.ui, size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// 배치에 따라 보이는 것 · 글꼴
    private func applyStyle() {
        let sh = sheet
        frameLayer.isHidden = sh
        for v in [titleLabel, hintLabel, tokenLabel, combosLabel, infoLabel] as [UIView] { v.isHidden = sh }
        tokenIcon.isHidden = sh
        stashLabel.isHidden = !sh
        if !sh { tipLabel.isHidden = true }
        let f: UIFont = sh ? Self.pixelFont(12, bold: true) : .systemFont(ofSize: 11, weight: .bold)
        for b in [rotButton, undoButton, autoButton] { b.titleLabel?.font = f; b.titleLabel?.adjustsFontSizeToFitWidth = sh; b.titleLabel?.minimumScaleFactor = 0.75 }
        rotButton.setTitle(sh ? "↻\n" + bagTr("돌리기") : bagTr("↻ 돌리기"), for: .normal)
        undoButton.setTitle(sh ? "↶\n" + bagTr("되돌리기") : bagTr("↶ 되돌리기"), for: .normal)
        for b in [rotButton, undoButton] { b.titleLabel?.numberOfLines = sh ? 2 : 1; b.titleLabel?.textAlignment = .center }
        trashLabel.font = sh ? Self.pixelFont(11, bold: true) : .systemFont(ofSize: 9, weight: .bold)
        stashLabel.font = Self.pixelFont(11, bold: true)
        setsLabel.numberOfLines = sh ? 3 : 1
    }

    private func styleButton(_ b: UIButton, _ t: String, plate: Bool) {
        b.setTitle(bagTr(t), for: .normal); b.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        b.setTitleColor(plate ? bbColor("#e9e4f7") : bbColor("#2a1a10"), for: .normal)
        b.setTitleColor(UIColor(white: 0.5, alpha: 0.5), for: .disabled)
        nineSlice(b.layer, plate ? BagPixelSkin.shared.plate : BagPixelSkin.shared.btn, edge: 4, size: 12, border: 6)
    }

    // MARK: 배치

    /// 폭에 맞는 높이
    public func preferredHeight(forWidth w: CGFloat) -> CGFloat {
        let c = cellSize(forWidth: w)
        return border * 2 + pad + headH + 16 + c * 4 + 8 + footH + infoH
    }
    private func cellSize(forWidth w: CGFloat) -> CGFloat {
        floor(min(56, (w - border * 2 - pad * 2 - gap - pocketPad * 2) / 8))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        if sheet { layoutSheet(); return }
        let W = bounds.width
        cs = cellSize(forWidth: W); ps = cs
        frameLayer.frame = bounds
        let x0 = border + pad, y0 = border + pad
        titleLabel.sizeToFit(); titleLabel.frame.origin = CGPoint(x: x0, y: y0 + 3)
        if let s = state { tokenLabel.text = "\(s.tokens)" }
        tokenLabel.sizeToFit()
        let tokX = W - border - pad - tokenLabel.bounds.width
        tokenLabel.frame.origin = CGPoint(x: tokX, y: y0 + 3); tokenIcon.frame = CGRect(x: tokX - 15, y: y0 + 5, width: 12, height: 12)
        undoButton.sizeToFit(); rotButton.sizeToFit()
        for b in [undoButton, rotButton] { b.frame.size = CGSize(width: b.bounds.width + 14, height: 22) }
        undoButton.frame.origin = CGPoint(x: tokX - 20 - undoButton.bounds.width, y: y0)
        rotButton.frame.origin = CGPoint(x: undoButton.frame.minX - 4 - rotButton.bounds.width, y: y0)
        hintLabel.frame = CGRect(x: titleLabel.frame.maxX + 6, y: y0 + 4, width: max(0, rotButton.frame.minX - titleLabel.frame.maxX - 10), height: 14)
        setsLabel.frame = CGRect(x: x0, y: y0 + headH, width: W - 2 * x0, height: 14)
        let gy = y0 + headH + 16
        gridRect = CGRect(x: x0, y: gy, width: cs * CGFloat(BagSpec.width), height: cs * CGFloat(BagSpec.height))
        gridBG.frame = gridRect.insetBy(dx: -2, dy: -2)
        for y in 0..<BagSpec.height { for x in 0..<BagSpec.width {
            let r = cellFrame(x, y); cells[y * BagSpec.width + x].frame = r; cellHi[y * BagSpec.width + x].frame = r
        } }
        pocketSkinRect = CGRect(x: gridRect.maxX + gap, y: gy - pocketTop, width: cs * 2 + pocketPad * 2, height: cs * 4 + pocketTop + pocketPad)
        pocketSkin.frame = pocketSkinRect
        pocketRect = CGRect(x: pocketSkinRect.minX + pocketPad, y: gy, width: cs * 2, height: cs * 4)
        for y in 0..<BagSpec.stashHeight { for x in 0..<BagSpec.stashWidth {
            let r = pocketFrame(x, y); pocketCells[y * BagSpec.stashWidth + x].frame = r; pocketHi[y * BagSpec.stashWidth + x].frame = r
        } }
        tilesLayer.frame = gridRect; overlayLayer.frame = gridRect; pocketTilesLayer.frame = pocketRect
        let fy = pocketSkinRect.maxY + 6
        trashView.frame = CGRect(x: W - border - pad - 104, y: fy, width: 44, height: footH - 6)
        trashIcon.frame = CGRect(x: 8, y: 0, width: 28, height: 34); trashLabel.frame = CGRect(x: -10, y: 36, width: 64, height: 14)
        autoButton.sizeToFit(); autoButton.frame = CGRect(x: W - border - pad - 56, y: fy + 8, width: 56, height: 36)
        autoButton.titleLabel?.numberOfLines = 2; autoButton.titleLabel?.textAlignment = .center
        combosLabel.frame = CGRect(x: x0, y: fy, width: trashView.frame.minX - x0 - 6, height: footH - 4)
        infoLabel.frame = CGRect(x: x0, y: fy + footH, width: W - 2 * x0, height: max(0, bounds.height - (fy + footH) - border))
        rotFab.frame = CGRect(x: x0 + 4, y: fy + footH - 60, width: 54, height: 54)
        toastLabel.frame.size.width = min(W - 40, 300)
        if let e = editor { render(e, force: true) }
    }
    /// sheet 치수(호스트가 시트 높이를 맞출 때도 쓴다): 위 여백 · 띠 사이 · 바깥 여백 · 보관함 판 안 여백
    nonisolated private static let sheetTop: CGFloat = 4, sheetGap: CGFloat = 8, sheetSide: CGFloat = 12, sheetPocketPad: CGFloat = 6
    /// sheet 보관함 칸: 가방 칸(폭 기준)의 0.6배 · 28 ~ 40pt — 가로 4×2 띠가 낮게 깔린다
    nonisolated private static func sheetPocketCell(forWidth W: CGFloat) -> CGFloat {
        max(28, min(40, floor((W - sheetSide * 2) / CGFloat(BagSpec.width) * 0.6)))
    }
    /// sheet 가 폭을 다 쓰는 큰 칸(최대 64pt)으로 그릴 때 필요한 높이 — 남는 높이는 호스트가 무대에 돌려준다
    nonisolated public static func sheetPreferredHeight(forWidth W: CGFloat, thumbRowHeight row: CGFloat) -> CGFloat {
        let c = floor(min(64, (W - sheetSide * 2) / CGFloat(BagSpec.width)))
        return sheetTop + c * CGFloat(BagSpec.height) + sheetGap + (sheetPocketCell(forWidth: W) * CGFloat(BagSpec.stashWidth) + sheetPocketPad * 2) + sheetGap + row + 6
    }

    /// sheet 배치: 위 여백 → 가방 6×4(폭을 다 쓰는 큰 칸 · 높이가 모자라면 가방이 먼저) → 가로 보관함 띠(전치 4×2 · 작은 칸) + 오른쪽 기둥(보관함 이름 · 빈자리에 넣기 · 세트)
    ///   → 엄지 줄(돌리기 · 되돌리기 · 버리기 | 호스트 필살 자리). 고른 칸 설명 카드는 보관함 띠 자리에 덮는다(가방 칸은 가리지 않음)
    private func layoutSheet() {
        let W = bounds.width, H = bounds.height, side = Self.sheetSide, g = Self.sheetGap, row = thumbRowHeight
        ps = Self.sheetPocketCell(forWidth: W)
        let band = ps * CGFloat(BagSpec.stashWidth) + pocketPad * 2
        let byW = (W - side * 2) / CGFloat(BagSpec.width)
        let byH = (H - Self.sheetTop - g - band - g - row - 6) / CGFloat(BagSpec.height)
        cs = max(20, floor(min(64, byW, byH)))
        let gx = floor((W - cs * CGFloat(BagSpec.width)) / 2)
        gridRect = CGRect(x: gx, y: Self.sheetTop, width: cs * CGFloat(BagSpec.width), height: cs * CGFloat(BagSpec.height))
        gridBG.frame = gridRect.insetBy(dx: -2, dy: -2)
        for y in 0..<BagSpec.height { for x in 0..<BagSpec.width {
            let r = cellFrame(x, y); cells[y * BagSpec.width + x].frame = r; cellHi[y * BagSpec.width + x].frame = r
        } }
        // 보관함(전치): 화면 폭 = 보관함 높이 칸 수 · 엄지 줄 바로 위에 붙인다(남는 높이는 가방과 띠 사이)
        let pw = ps * CGFloat(BagSpec.stashHeight), ph = ps * CGFloat(BagSpec.stashWidth)
        let ry = H - row - 6
        pocketRect = CGRect(x: gridRect.minX + pocketPad, y: max(gridRect.maxY + g + pocketPad, ry - g - pocketPad - ph), width: pw, height: ph)
        pocketSkinRect = pocketRect.insetBy(dx: -pocketPad, dy: -pocketPad)
        pocketSkin.frame = pocketSkinRect
        for y in 0..<BagSpec.stashHeight { for x in 0..<BagSpec.stashWidth {
            let r = pocketFrame(x, y); pocketCells[y * BagSpec.stashWidth + x].frame = r; pocketHi[y * BagSpec.stashWidth + x].frame = r
        } }
        tilesLayer.frame = gridRect; overlayLayer.frame = gridRect; pocketTilesLayer.frame = pocketRect
        // 오른쪽 기둥
        let cx = pocketSkinRect.maxX + g, cw = max(0, gridRect.maxX - cx)
        stashLabel.frame = CGRect(x: cx, y: pocketSkinRect.minY, width: cw, height: 16)
        autoButton.frame = CGRect(x: cx, y: stashLabel.frame.maxY + 2, width: cw, height: 44)
        autoButton.titleLabel?.numberOfLines = 1; autoButton.titleLabel?.textAlignment = .center
        let sh = max(0, pocketSkinRect.maxY - autoButton.frame.maxY - 2)
        setsLabel.frame = CGRect(x: cx, y: autoButton.frame.maxY + 2, width: cw, height: sh)
        setsLabel.numberOfLines = max(1, Int(sh / 13))
        // 엄지 줄
        let avail = W - side * 2 - thumbReserve - (thumbReserve > 0 ? g : 0)
        let bw = floor((avail - g * 2) / 3)
        rotButton.frame = CGRect(x: side, y: ry, width: bw, height: row)
        undoButton.frame = CGRect(x: side + bw + g, y: ry, width: bw, height: row)
        trashView.frame = CGRect(x: side + (bw + g) * 2, y: ry, width: bw, height: row)
        trashView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.22)
        let iw: CGFloat = 28, ih: CGFloat = 34
        trashIcon.frame = CGRect(x: (bw - iw) / 2, y: max(2, (row - ih - 16) / 2), width: iw, height: ih)
        trashLabel.frame = CGRect(x: 0, y: trashIcon.frame.maxY + 2, width: bw, height: 14)
        rotFab.frame = CGRect(x: side, y: ry - 60, width: 54, height: 54)
        toastLabel.frame.size.width = min(W - 40, 300)
        if let e = editor { render(e, force: true) }
    }

    private func cellFrame(_ x: Int, _ y: Int) -> CGRect { CGRect(x: gridRect.minX + CGFloat(x) * cs, y: gridRect.minY + CGFloat(y) * cs, width: cs, height: cs) }
    /// 보관함 칸(x, y) 의 화면 사각형 — sheet 는 전치(가로 보관함)
    private func pocketFrame(_ x: Int, _ y: Int) -> CGRect {
        sheet ? CGRect(x: pocketRect.minX + CGFloat(y) * ps, y: pocketRect.minY + CGFloat(x) * ps, width: ps, height: ps)
              : CGRect(x: pocketRect.minX + CGFloat(x) * ps, y: pocketRect.minY + CGFloat(y) * ps, width: ps, height: ps)
    }

    // MARK: 그리기

    /// 편집기 상태를 그린다 — 바뀐 타일만 다시 짓는다
    public func render(_ e: BagEditor, force: Bool = false) {
        editor = e
        guard cs > 0, gridRect.width > 0 else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        let c = e.catalog, s = e.state, R = c.rules
        let sets = R.sets(s.bag), badges = c.routeBadges(s.bag)
        // 머리줄
        if tokenLabel.text != "\(s.tokens)" { tokenLabel.text = "\(s.tokens)"; if !force { setNeedsLayout() } }
        hintLabel.text = bagTr(!e.canEdit ? BagEditor.lockNote : e.inCombat ? "전투 중 정리 · 시간이 느려지고 옮긴 기술은 쿨다운이 처음부터" : "끌어 놓으면 화력 변화가 미리 보여요")
        titleLabel.text = bagTr(" 서류가방 ")   // 언어를 바꾸면 다음 그리기에서 따라온다
        rotButton.isEnabled = e.canEdit && s.selUid != nil
        undoButton.isEnabled = e.canUndo
        let st = NSMutableAttributedString()
        for f in R.families where sets[f] != nil {
            let F = c.families[f]
            st.append(NSAttributedString(string: " \(F?.n ?? f) 세트 · 피해 +20% · 쿨다운 −10%\(F?.guard_ != nil ? " · 받는 피해 −15%" : "") ", attributes: [.backgroundColor: bbColor(F?.c ?? "#ffffff"), .foregroundColor: bbColor("#120f22")]))
            st.append(NSAttributedString(string: " "))
        }
        setsLabel.attributedText = bagTrA(st)
        // 각인 칸 표시
        impMarks.forEach { $0.removeFromSuperlayer() }; impMarks = []
        for (k, t) in s.imprints {
            let p = k.split(separator: ",").compactMap { Int($0) }; guard p.count == 2 else { continue }
            let m = CATextLayer(); m.contentsScale = scale; m.alignmentMode = .center
            let col = t == "holster" ? "#ffb347" : t == "pocket" ? "#7dffa0" : "#ff8a7a"
            m.string = NSAttributedString(string: bagTr(t == "holster" ? "총" : t == "pocket" ? "주" : "해"), attributes: [.font: UIFont.systemFont(ofSize: 7, weight: .heavy), .foregroundColor: bbColor("#0e0d14")])
            m.backgroundColor = bbColor(col).cgColor
            let r = cellFrame(p[0], p[1]); m.frame = CGRect(x: r.maxX - 10, y: r.minY + 1, width: 9, height: 9)
            layer.insertSublayer(m, above: cells.last); impMarks.append(m)
        }
        // 타일
        var alive = Set<Int>()
        cdFull = [:]
        for (i, b) in s.bag.enumerated() {
            alive.insert(b.uid)
            let spec = tileSpec(b, inStash: false, sets: sets, badges: badges)
            let node = tiles[b.uid] ?? makeNode(b.uid)
            if node.root.superlayer !== tilesLayer { tilesLayer.addSublayer(node.root) }
            let (w, h) = R.box(b)
            node.root.frame = CGRect(x: CGFloat(b.x) * cs, y: CGFloat(b.y) * cs, width: CGFloat(w) * cs, height: CGFloat(h) * cs)
            node.configure(spec, size: node.root.bounds.size, scale: scale)
            let it = c.item(b.id)
            if it?.kind == "skill" || it?.kind == "dodge" { cdFull[b.uid] = R.stats(i, bag: s.bag, sets: sets, imprints: s.imprints).cd ?? 0 }
            else if it?.kind == "heal" { cdFull[b.uid] = (it?.cd ?? 0) - Double(b.tier - 1) }
        }
        for b in s.stash {
            alive.insert(b.uid)
            let spec = tileSpec(b, inStash: true, sets: sets, badges: badges)
            let node = tiles[b.uid] ?? makeNode(b.uid)
            if node.root.superlayer !== pocketTilesLayer { pocketTilesLayer.addSublayer(node.root) }
            let f = R.stashFoot(b, rot: b.rot)
            if sheet {   // 가로 보관함: 자리 · 모양 · 이름표를 전치해 그린다
                node.root.frame = CGRect(x: CGFloat(b.sy ?? 0) * ps, y: CGFloat(b.sx ?? 0) * ps, width: CGFloat(f.h) * ps, height: CGFloat(f.w) * ps)
                node.configure(spec.transposed, size: node.root.bounds.size, scale: scale)
            } else {
                node.root.frame = CGRect(x: CGFloat(b.sx ?? 0) * ps, y: CGFloat(b.sy ?? 0) * ps, width: CGFloat(f.w) * ps, height: CGFloat(f.h) * ps)
                node.configure(spec, size: node.root.bounds.size, scale: scale)
            }
            node.setCooldown(0, active: false)
        }
        for (u, n) in tiles where !alive.contains(u) { n.root.removeFromSuperlayer(); tiles[u] = nil }
        updateCooldowns(s)
        // 경로 · 연결 표시
        let sig = s.bag.map { "\($0.uid):\($0.id)@\($0.x),\($0.y)r\($0.rot)p\($0.pin ?? -1)" }.joined(separator: ";") + "|\(Int(cs))"
        if sig != overlaySig || force { overlaySig = sig; drawOverlay(s.bag) }
        // 콤보 목록 · 정보
        combosLabel.attributedText = bagTrA(comboList(s.bag))
        infoLabel.attributedText = bagTrA(infoText(s))
        stashLabel.text = bagTr("보관함")
        if sheet { updateTip(s) }
    }

    /// sheet: 고른 칸 설명 카드 — 보관함 띠 자리에 덮는다(가방 칸은 가리지 않는다).
    ///   가방 칸을 고르면 띠 전체(보관함을 잠시 가린다 — 끌기 시작하면 숨어서 보관함이 다시 보인다) ·
    ///   보관함 칸을 고르면 오른쪽 기둥만(고른 칸이 보이게). 넘치면 안내 줄을 빼고, 그래도 넘치면 글자를 줄인다
    private func updateTip(_ s: BagState) {
        guard drag == nil, mergeSheet == nil, let u = s.selUid, tipDismissedFor != u, let node = tiles[u], node.root.superlayer != nil else {
            tipLabel.isHidden = true; return
        }
        let inStash = !s.inBag(u)
        let x0 = inStash ? pocketSkinRect.maxX + Self.sheetGap : gridRect.minX
        let box = CGRect(x: x0, y: pocketSkinRect.minY, width: max(0, gridRect.maxX - x0), height: pocketSkinRect.height)
        var fit: NSAttributedString = tipText(s, hint: true, size: 11)
        for (hint, size) in [(true, 11.0), (false, 11.0), (false, 10.0), (false, 9.0)] as [(Bool, CGFloat)] {
            fit = tipText(s, hint: hint, size: size)
            tipLabel.attributedText = bagTrA(fit)
            if tipLabel.sizeThatFits(CGSize(width: box.width, height: .greatestFiniteMagnitude)).height <= box.height { break }
        }
        tipLabel.frame = box
        tipLabel.isHidden = false
        bringSubviewToFront(tipLabel); tipLabel.layer.zPosition = 41
    }

    /// 설명 카드 글(밝은 종이 바탕 — 짙은 글). hint = 아래 안내 줄 · size = 본문 글자 크기
    private func tipText(_ s: BagState, hint: Bool, size: CGFloat) -> NSAttributedString {
        let out = NSMutableAttributedString()
        guard let c = cat, let u = s.selUid, let b = s.item(u), let it = c.item(b.id) else { return out }
        let f11 = Self.pixelFont(size), f12b = Self.pixelFont(size + 1, bold: true), ink = bbColor("#1a1610"), sub = bbColor("#5a4e38")
        let badge = c.routeBadges(s.bag)[u].map { "\($0.n) · " } ?? ""
        out.append(NSAttributedString(string: badge + it.name + " ", attributes: [.font: f12b, .foregroundColor: ink]))
        out.append(NSAttributedString(string: String(repeating: "★", count: b.tier), attributes: [.font: f11, .foregroundColor: bbColor("#b5651d")]))
        var meta: [String] = []
        if let i = s.bag.firstIndex(where: { $0.uid == u }), it.kind == "skill" || it.kind == "dodge" {
            let st = c.rules.stats(i, bag: s.bag, sets: c.rules.sets(s.bag), imprints: s.imprints)
            if (it.dmg ?? 0) != 0 { meta.append("피해 \(BagCatalog.formatDamage(st.dmg))\(it.combo == true ? "+" : "")") }
            meta.append("쿨 \(JSFormat.fixed(st.cd ?? 0, 1))초")
        } else if let v = c.tileStats(b, in: s).val { meta.append(v) }
        if !s.inBag(u) { meta.append("보관 중") }
        if !meta.isEmpty { out.append(NSAttributedString(string: "  " + meta.joined(separator: " · "), attributes: [.font: f11, .foregroundColor: bbColor("#8a3a12")])) }
        if let o = b.opt { out.append(NSAttributedString(string: "  " + c.optionText(o), attributes: [.font: f11, .foregroundColor: bbColor("#2c5aa0")])) }
        out.append(NSAttributedString(string: "\n" + it.desc, attributes: [.font: f11, .foregroundColor: ink]))
        if hint { out.append(NSAttributedString(string: "\n" + "두 번 누르면 돌리기 · 같은 ★끼리 겹치면 합성 · 버리면 토큰 \(c.rules.tokenValue(b))", attributes: [.font: f11, .foregroundColor: sub])) }
        return out
    }

    private func makeNode(_ uid: Int) -> BagTileNode { let n = BagTileNode(); tiles[uid] = n; return n }

    /// 웹 itemHTML · tileLabel 에 들어가는 값
    private func tileSpec(_ b: BagItem, inStash: Bool, sets: [String: [Int]], badges: [Int: RouteBadge], rot: Int? = nil) -> TileSpec {
        makeTileSpec(cat!, state!, b, inStash: inStash, sets: sets, badges: badges, rot: rot)
    }

    /// 쿨다운만 갱신(매 프레임 불러도 가볍다) — 웹 updateBagCD 의 막대 · 그늘 · 준비 표시
    public func updateCooldowns(_ s: BagState) {
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        for b in s.bag {
            guard let n = tiles[b.uid] else { continue }
            let full = cdFull[b.uid] ?? 0
            n.setCooldown(full > 0 ? b.t / full : 0, active: full > 0)
        }
    }

    // MARK: 경로선 · 연결 막대(웹 routeLayer · linkMarks)

    private func drawOverlay(_ bag: [BagItem]) {
        overlayLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let c = cat else { return }
        for m in c.linkMarks(bag) {
            let l = CALayer()
            let col = m.type == "nm" ? ("#ffcf4a", "#8a5a14") : m.type == "ch" ? ("#c9d2e6", "#4d4943") : ("#62a8ee", "#2c5aa0")
            l.backgroundColor = bbColor(col.0).cgColor; l.borderColor = bbColor(col.1).cgColor; l.borderWidth = 1
            let cx = CGFloat(m.x) * cs, cy = CGFloat(m.y) * cs
            l.frame = m.vertical ? CGRect(x: cx - 3, y: cy - cs * 0.25, width: 6, height: cs * 0.5) : CGRect(x: cx - cs * 0.25, y: cy - 3, width: cs * 0.5, height: 6)
            overlayLayer.addSublayer(l)
        }
        let R = c.routes(bag)
        // 시트: 이름 줄이 칸 위쪽이라 웹 높이(0.26)면 선이 이름을 긋는다 — 이름 두 줄 아래(+0.4 — 칸의 약 2/3)로 내린다. classic 은 웹 그대로
        let dy = sheet ? 0.4 : 0
        for (k, (r, col)) in R.enumerated() {
            let off = (Double(k) - Double(R.count - 1) / 2) * 0.1
            let pts = r.uids.compactMap { u in bag.first { $0.uid == u } }.map { c.routeAnchor($0) }.map { CGPoint(x: ($0.x + off) * cs, y: ($0.y + off + dy) * cs) }
            guard pts.count >= 2 else { continue }
            let p = CGMutablePath(); p.addLines(between: pts)
            let under = CAShapeLayer(); under.path = p; under.fillColor = nil; under.strokeColor = bbColor("#0e0d14", 0.5).cgColor; under.lineWidth = 4.5; under.lineCap = .round; under.lineJoin = .round
            let line = CAShapeLayer(); line.path = p; line.fillColor = nil; line.strokeColor = bbColor(BagCatalog.routeColors[col]).cgColor; line.lineWidth = 2
            line.lineDashPattern = [5, 4]; line.lineCap = .round; line.lineJoin = .round
            overlayLayer.addSublayer(under); overlayLayer.addSublayer(line)
        }
    }

    private func comboList(_ bag: [BagItem]) -> NSAttributedString {
        guard let c = cat else { return NSAttributedString() }
        let R = c.routes(bag), out = NSMutableAttributedString()
        if R.isEmpty { return NSAttributedString(string: "시작기 ▶ 옆에 ●·■를 붙이면 콤보", attributes: [.foregroundColor: bbColor("#a99f88"), .font: UIFont.systemFont(ofSize: 10)]) }
        for (k, (r, col)) in R.enumerated() {
            if k > 0 { out.append(NSAttributedString(string: "\n")) }
            out.append(NSAttributedString(string: "▌", attributes: [.foregroundColor: bbColor(BagCatalog.routeColors[col]), .font: UIFont.systemFont(ofSize: 11, weight: .heavy)]))
            out.append(NSAttributedString(string: "\(k + 1) \(r.name) ", attributes: [.foregroundColor: bbColor("#f6ecd6"), .font: UIFont.systemFont(ofSize: 11, weight: .bold)]))
            out.append(NSAttributedString(string: "\(r.uids.count)단", attributes: [.foregroundColor: bbColor("#cfc3a6"), .font: UIFont.systemFont(ofSize: 10)]))
        }
        return out
    }

    /// 아래 정보 칸(웹 showInfo 의 짧은 꼴)
    private func infoText(_ s: BagState) -> NSAttributedString {
        let out = NSMutableAttributedString(), base: [NSAttributedString.Key: Any] = [.foregroundColor: bbColor("#e4def2"), .font: UIFont.systemFont(ofSize: 11)]
        guard let c = cat, let u = s.selUid, let b = s.item(u), let it = c.item(b.id) else {
            return NSAttributedString(string: " 타일을 누르면 자세한 정보가 여기 떠요 · 두 번 누르면 돌리기 · 같은 아이템 · 같은 ★끼리 겹치면 합성", attributes: [.foregroundColor: bbColor("#a99fc4"), .font: UIFont.systemFont(ofSize: 11)])
        }
        let tc = BagCatalog.tierColors[min(5, b.tier)]
        out.append(NSAttributedString(string: " \(it.name) ", attributes: [.foregroundColor: bbColor(tc), .font: UIFont.systemFont(ofSize: 12, weight: .bold)]))
        out.append(NSAttributedString(string: String(repeating: "★", count: b.tier), attributes: [.foregroundColor: bbColor(tc), .font: UIFont.systemFont(ofSize: 11)]))
        var meta = ["\(c.rules.size(b.id))칸"]
        if let f = it.fam, let F = c.families[f] { meta.append(F.n) }
        if !s.inBag(u) { meta.append("보류 중") }
        out.append(NSAttributedString(string: "  " + meta.joined(separator: " · "), attributes: [.foregroundColor: bbColor("#cfc39a"), .font: UIFont.systemFont(ofSize: 10)]))
        if let i = s.bag.firstIndex(where: { $0.uid == u }), it.kind == "skill" || it.kind == "dodge" {
            let st = c.rules.stats(i, bag: s.bag, sets: c.rules.sets(s.bag), imprints: s.imprints)
            var line = "\n "
            if (it.dmg ?? 0) != 0 { line += "피해 \(BagCatalog.formatDamage(st.dmg))\(it.combo == true ? "+" : "") · " }
            line += "쿨 \(JSFormat.fixed(st.cd ?? 0, 1))초"
            if (it.dmg ?? 0) != 0 { line += " · 치명 \(JSFormat.round(st.crit * 100))% ×\(JSFormat.fixed(st.critD, 1))" }
            out.append(NSAttributedString(string: line, attributes: [.foregroundColor: bbColor("#ffd9a8"), .font: UIFont.systemFont(ofSize: 11, weight: .semibold)]))
        } else {
            let T = c.tileStats(b, in: s)
            if let v = T.val { out.append(NSAttributedString(string: "\n " + v, attributes: [.foregroundColor: bbColor(T.valColor ?? "#ffffff"), .font: UIFont.systemFont(ofSize: 11, weight: .semibold)])) }
        }
        if let o = b.opt { out.append(NSAttributedString(string: "  " + c.optionText(o), attributes: [.foregroundColor: bbColor(c.options[o.k]?.c ?? "#ffffff"), .font: UIFont.systemFont(ofSize: 11)])) }
        out.append(NSAttributedString(string: "\n " + it.desc, attributes: base))
        out.append(NSAttributedString(string: "  · 버리면 토큰 \(c.rules.tokenValue(b))", attributes: [.foregroundColor: bbColor("#ffcf7a"), .font: UIFont.systemFont(ofSize: 10)]))
        return out
    }

    // MARK: 알림

    /// 웹 say(): 잠깐 뜨는 상자
    public func showMessage(_ title: String?, _ body: String?, duration: TimeInterval = 1.6) {
        guard title != nil || body != nil else { return }
        let a = NSMutableAttributedString()
        if let t = title { a.append(NSAttributedString(string: t + (body != nil ? "\n" : ""), attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .heavy), .foregroundColor: bbColor("#ffe27a")])) }
        if let b = body { a.append(NSAttributedString(string: b, attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: bbColor("#f1e6d0")])) }
        toastLabel.attributedText = bagTrA(a)
        let w = min(bounds.width - 40, 300), sz = toastLabel.sizeThatFits(CGSize(width: w, height: 200))
        toastLabel.frame = CGRect(x: (bounds.width - sz.width) / 2, y: gridRect.midY - sz.height / 2, width: sz.width, height: sz.height)
        toastLabel.layer.removeAllAnimations(); toastLabel.alpha = 1
        UIView.animate(withDuration: 0.25, delay: duration, options: [.beginFromCurrentState]) { self.toastLabel.alpha = 0 }
    }

    // MARK: 단추

    @objc private func tapRotate() { if let u = state?.selUid { onIntent?(.rotate(uid: u)) } }
    @objc private func tapUndo() { onIntent?(.undo) }
    @objc private func tapAuto() { onIntent?(.autoPack) }
    @objc private func fabRotate() { rotDrag() }

    // MARK: 끌어 놓기 — 손가락 한 칸 위로 띄운 고스트 · 칸 맞춤 · 두 번째 손가락 회전

    private func gridCellAt(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - gridRect.minX) / cs, y: (p.y - gridRect.minY) / cs) }
    /// 점 → 보관함 칸 좌표(sheet 는 전치를 되돌린다)
    private func pocketCellAt(_ p: CGPoint) -> CGPoint {
        let a = (p.x - pocketRect.minX) / ps, b = (p.y - pocketRect.minY) / ps
        return sheet ? CGPoint(x: b, y: a) : CGPoint(x: a, y: b)
    }

    /// 점 아래 아이템 uid(가방 · 보류함 칸 기준)
    private func itemAt(_ p: CGPoint) -> Int? {
        guard let c = cat, let s = state else { return nil }
        if gridRect.contains(p) {
            let g = gridCellAt(p), cell = Cell(Int(g.x), Int(g.y))
            return s.bag.first { c.rules.cells($0).contains(cell) }?.uid
        }
        if pocketRect.contains(p) {
            let g = pocketCellAt(p), cell = Cell(Int(g.x), Int(g.y))
            return s.stash.first { c.rules.stashCells($0, x: $0.sx ?? 0, y: $0.sy ?? 0, rot: $0.rot).contains(cell) }?.uid
        }
        return nil
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let d = drag {   // 끄는 중 두 번째 손가락 = 회전
            if d.moved, touches.contains(where: { $0 !== d.touch }) { rotDrag() }
            return
        }
        guard let t = touches.first else { return }
        pointerDown(t.location(in: self), touch: t)
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let d = drag, let t = d.touch, touches.contains(where: { $0 === t }) else { return }
        pointerMove(t.location(in: self))
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let d = drag, let t = d.touch, touches.contains(where: { $0 === t }) else { return }
        pointerUp(t.location(in: self))
    }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let d = drag, let t = d.touch, touches.contains(where: { $0 === t }) else { return }
        endDragVisuals(); drag = nil
        if let e = editor { render(e) }
    }

    /// 웹 pointerdown: 잡은 칸 기억 · 고르기
    private func pointerDown(_ p: CGPoint, touch: UITouch?) {
        guard let s = state, let c = cat, mergeSheet == nil else { return }
        // 설명 카드를 누르면 닫기만(아래 가려진 보관함 칸을 잡지 않는다)
        if sheet, !tipLabel.isHidden, tipLabel.frame.contains(p), let u = s.selUid { tipDismissedFor = u; tipLabel.isHidden = true; return }
        guard let uid = itemAt(p), let b = s.item(uid), let node = tiles[uid] else {
            if sheet, let u = s.selUid { tipDismissedFor = u; tipLabel.isHidden = true }   // 빈 곳: 설명 카드 닫기
            return
        }
        if tipDismissedFor == uid { tipDismissedFor = nil; if let e = editor { render(e) } }
        let r = node.root.convert(node.root.bounds, to: layer)
        let (w, h) = c.rules.box(b)
        let gx = max(0, min(w - 1, Int((p.x - r.minX) / (r.width / CGFloat(w))))), gy = max(0, min(h - 1, Int((p.y - r.minY) / (r.height / CGFloat(h)))))
        drag = Drag(uid: uid, touch: touch, start: p, gx: gx, gy: gy, rot: b.rot)
        if s.selUid != uid { onIntent?(.select(uid)) }
    }

    /// 웹 pointermove: 6pt 넘게 움직이면 고스트를 띄운다
    private func pointerMove(_ p: CGPoint) {
        guard var d = drag, let e = editor else { return }
        if !d.moved && hypot(p.x - d.start.x, p.y - d.start.y) > 6 {
            if !e.canEdit { drag = nil; showMessage(nil, BagEditor.lockNote); return }
            d.moved = true; drag = d; makeGhost(); d = drag!
        }
        guard d.moved else { return }
        moveGhost(p)
    }

    /// 웹 pointerup: 탭(새 장비 장착 · 두 번 탭 회전) · 휴지통 · 합성 · 보류함 · 가방 칸
    private func pointerUp(_ p: CGPoint) {
        guard let d = drag, let s = state else { return }
        endDragVisuals()
        drag = nil
        if !d.moved {
            if s.newUids.contains(d.uid), !s.inBag(d.uid), editor?.canEdit == true { onIntent?(.quickEquip(uid: d.uid)); return }   // 새 장비: 한 번 탭으로 빈자리에
            let now = Date.timeIntervalSinceReferenceDate
            if let lt = lastTap, lt.uid == d.uid, now - lt.t < 0.35 { onIntent?(.rotate(uid: d.uid)); lastTap = nil } else { lastTap = (d.uid, now) }
            return
        }
        var dd = d; aim(&dd, p)
        if dd.onTrash { onIntent?(.move(uid: d.uid, to: .trash)); return }
        if let m = dd.mergeT { askMerge(src: d.uid, dst: m); return }
        if dd.inPocket { onIntent?(.move(uid: d.uid, to: .stash(x: dd.ptx, y: dd.pty, rot: dd.rot))); return }
        if dd.inGrid { onIntent?(.move(uid: d.uid, to: .bag(x: dd.tx, y: dd.ty, rot: dd.rot))) }
        if let e = editor { render(e) }
    }

    #if DEBUG
    /// 점검용(시뮬레이터 자동 스크린숏): 손가락 없이 끌기를 흉내 낸다 — 놓지 않으면 고스트 · 미리보기가 남는다
    public func debugDrag(uid: Int, toGridCell x: Double, _ y: Double, release: Bool) {
        guard let n = tiles[uid] else { return }
        let r = n.root.convert(n.root.bounds, to: layer)
        let p0 = CGPoint(x: r.minX + cs / 2, y: r.minY + cs / 2)
        pointerDown(p0, touch: nil)
        let p1 = CGPoint(x: gridRect.minX + CGFloat(x) * cs, y: gridRect.minY + CGFloat(y) * cs + lift)
        pointerMove(CGPoint(x: p0.x + 10, y: p0.y + 10)); pointerMove(p1)
        if release { pointerUp(p1) }
    }
    /// 점검용: 합성 창 띄우기
    public func debugAskMerge(src: Int, dst: Int) { askMerge(src: src, dst: dst) }
    #endif

    private var lift: CGFloat { cs }

    private func makeGhost() {
        guard var d = drag, let s = state, let b = s.item(d.uid) else { return }
        let g = BagTileNode(); g.root.opacity = 0.85; g.root.zPosition = 50
        layer.addSublayer(g.root); d.ghost = g; drag = d
        sizeGhost(b)
        trashView.layer.borderColor = bbColor("#e8524a").cgColor; trashView.layer.borderWidth = 0
        rotFab.isHidden = false; bringSubviewToFront(rotFab)
        tipLabel.isHidden = true
        tiles[d.uid]?.root.opacity = 0.35
    }

    private func sizeGhost(_ b: BagItem) {
        guard let d = drag, let g = d.ghost, let c = cat, let s = state else { return }
        let (w, h) = c.rules.box(b, rot: d.rot)
        var spec = tileSpec(b, inStash: false, sets: c.rules.sets(s.bag), badges: c.routeBadges(s.bag), rot: d.rot)
        spec.selected = true
        g.root.bounds = CGRect(x: 0, y: 0, width: CGFloat(w) * cs, height: CGFloat(h) * cs)
        g.configure(spec, size: g.root.bounds.size, scale: scale)
        g.setCooldown(0, active: false)
    }

    /// 웹 rotDrag: 끄는 중 회전(잡은 칸은 상자 안으로)
    private func rotDrag() {
        guard var d = drag, d.moved, let s = state, let b = s.item(d.uid), let c = cat else { return }
        d.rot = (d.rot + 1) % 4
        let (w, h) = c.rules.box(b, rot: d.rot)
        d.gx = min(d.gx, w - 1); d.gy = min(d.gy, h - 1); d.pk = ""
        drag = d
        sizeGhost(b); moveGhost(d.p)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 손가락 위치 → 놓을 곳 판정(웹 moveGhost · pocketAim)
    private func aim(_ d: inout Drag, _ p: CGPoint) {
        guard let c = cat, let s = state, let b = s.item(d.uid) else { return }
        d.p = p
        let q = CGPoint(x: p.x, y: p.y - lift)
        let g = gridCellAt(q)
        d.tx = Int((g.x - CGFloat(d.gx) - 0.5).rounded()); d.ty = Int((g.y - CGFloat(d.gy) - 0.5).rounded())
        d.inGrid = g.x >= 0 && g.y >= 0 && g.x < CGFloat(BagSpec.width) && g.y < CGFloat(BagSpec.height)
        // 합성 대상: 손가락(띄운 자리) 아래 같은 아이템 · 같은 ★
        if let u = itemAt(q), u != d.uid, let e = editor, e.canMerge(src: d.uid, dst: u) { d.mergeT = u } else { d.mergeT = nil }
        // 보류함
        let pc = pocketCellAt(q)
        d.inPocket = false
        if pc.x >= -0.25 && pc.y >= -0.25 && pc.x <= CGFloat(BagSpec.stashWidth) + 0.25 && pc.y <= CGFloat(BagSpec.stashHeight) + 0.25 {
            let f = c.rules.stashFoot(b, rot: d.rot), gx = min(d.gx, f.w - 1), gy = min(d.gy, f.h - 1)
            d.inPocket = true
            d.ptx = max(0, min(BagSpec.stashWidth - f.w, Int((pc.x - CGFloat(gx) - 0.5).rounded())))
            d.pty = max(0, min(BagSpec.stashHeight - f.h, Int((pc.y - CGFloat(gy) - 0.5).rounded())))
        }
        d.onTrash = trashView.frame.insetBy(dx: -6, dy: -6).contains(q)
    }

    private func moveGhost(_ p: CGPoint) {
        guard var d = drag, let g = d.ghost, let c = cat, let s = state, let b = s.item(d.uid) else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        aim(&d, p)
        g.root.frame.origin = CGPoint(x: p.x - (CGFloat(d.gx) + 0.5) * cs, y: p.y - lift - (CGFloat(d.gy) + 0.5) * cs)
        // 휴지통
        trashLabel.text = bagTr(d.onTrash ? "+\(c.rules.tokenValue(b)) 토큰" : "버리기")
        trashView.layer.borderWidth = d.onTrash ? 2 : 0
        g.root.opacity = d.onTrash ? 0.5 : 0.85
        // 칸 강조
        for h in cellHi + pocketHi { h.backgroundColor = nil; h.borderWidth = 0 }
        if d.inPocket && d.mergeT == nil {
            let ok = c.rules.canStash(b, x: d.ptx, y: d.pty, rot: d.rot, in: s.stash)
            for cc in c.rules.stashCells(b, x: d.ptx, y: d.pty, rot: d.rot) where cc.x >= 0 && cc.y >= 0 && cc.x < BagSpec.stashWidth && cc.y < BagSpec.stashHeight {
                pocketHi[cc.y * BagSpec.stashWidth + cc.x].backgroundColor = ok ? UIColor(red: 95 / 255, green: 208 / 255, blue: 138 / 255, alpha: 0.42).cgColor : UIColor(red: 232 / 255, green: 82 / 255, blue: 74 / 255, alpha: 0.45).cgColor
            }
        } else {
            // 콤보 추천 칸(웹 rtSuggest)
            let sug = c.routeSuggest(s, uid: d.uid, rot: d.rot)
            for hit in sug.hits { for cc in c.rules.cells(b, x: hit.x, y: hit.y, rot: d.rot) {
                let h = cellHi[cc.y * BagSpec.width + cc.x]
                if hit.v == sug.best { h.backgroundColor = UIColor(red: 1, green: 205 / 255, blue: 90 / 255, alpha: 0.32).cgColor; h.borderColor = bbColor("#ffd36a").cgColor; h.borderWidth = 2 }
                else if h.borderWidth == 0 { h.backgroundColor = UIColor(red: 1, green: 170 / 255, blue: 60 / 255, alpha: 0.16).cgColor }
            } }
            if d.inGrid {
                let ok = c.rules.canPlace(b, x: d.tx, y: d.ty, rot: d.rot, in: s.bag)
                for cc in c.rules.cells(b, x: d.tx, y: d.ty, rot: d.rot) where cc.x >= 0 && cc.y >= 0 && cc.x < BagSpec.width && cc.y < BagSpec.height {
                    let h = cellHi[cc.y * BagSpec.width + cc.x]
                    h.borderWidth = 0
                    h.backgroundColor = ok ? UIColor(red: 95 / 255, green: 208 / 255, blue: 138 / 255, alpha: 0.42).cgColor : UIColor(red: 232 / 255, green: 82 / 255, blue: 74 / 255, alpha: 0.45).cgColor
                }
            }
        }
        drag = d
        showPreview()
    }

    /// 웹 showPreview: 화력 변화 · 피해/쿨 · 새 연계 · 세트 · 각인 · 콤보 경로 변화(경로선도 가설 배치로)
    private func showPreview() {
        guard var d = drag, let g = d.ghost, let c = cat, let s = state, let b = s.item(d.uid) else { prevLabel.isHidden = true; return }
        if d.onTrash { prevLabel.isHidden = true; return }
        let key = "\(d.tx),\(d.ty),\(d.rot),\(d.mergeT ?? -1),\(d.inPocket ? "P\(d.ptx),\(d.pty)" : "")"
        if key == d.pk { return }
        d.pk = key; drag = d
        var lines: [PreviewLine]
        var hyp: [BagItem]? = nil
        if let m = d.mergeT, let t = s.item(m) { lines = c.mergeLines(tier: t.tier) }
        else if d.inPocket {
            let P = c.previewStash(s, uid: d.uid, x: d.ptx, y: d.pty, rot: d.rot)!
            lines = c.stashLines(P)
            if P.ok && s.inBag(d.uid) { hyp = s.bag.filter { $0.uid != d.uid } }
        } else if !d.inGrid { prevLabel.isHidden = true; drawOverlay(s.bag); return }
        else if !c.rules.canPlace(b, x: d.tx, y: d.ty, rot: d.rot, in: s.bag) { lines = [PreviewLine("여기엔 자리가 모자라요", .bad)] }
        else {
            let P = c.previewPlace(s, uid: d.uid, x: d.tx, y: d.ty, rot: d.rot)!
            lines = c.previewLines(P)
            var m = b; m.x = d.tx; m.y = d.ty; m.rot = d.rot
            hyp = s.bag.filter { $0.uid != d.uid } + [m]
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        drawOverlay(hyp ?? s.bag)
        CATransaction.commit()
        let a = NSMutableAttributedString()
        for (i, l) in lines.enumerated() {
            let col: String = switch l.style {
            case .up: "#7dffa0"; case .down, .bad: "#ff8a7a"; case .even: "#cfc6e6"; case .link: "#ffe27a"; case .merge: "#ffd34a"
            case .imprint: "#c59bff"; case .combo: BagCatalog.routeColors[l.color ?? 0]; case .info: "#e9e4f7" }
            let bold = i == 0
            a.append(NSAttributedString(string: (i > 0 ? "\n" : "") + l.text, attributes: [.foregroundColor: bbColor(col), .font: UIFont.systemFont(ofSize: bold ? 12 : 11, weight: bold ? .bold : .regular)]))
        }
        prevLabel.attributedText = bagTrA(a)
        let sz = prevLabel.sizeThatFits(CGSize(width: bounds.width - 16, height: 300))
        let gr = g.root.frame
        prevLabel.frame = CGRect(x: max(4, min(bounds.width - 4 - sz.width, gr.minX)), y: max(4, gr.minY - 6 - sz.height), width: sz.width, height: sz.height)
        prevLabel.isHidden = false; bringSubviewToFront(prevLabel)
    }

    private func endDragVisuals() {
        if let d = drag { d.ghost?.root.removeFromSuperlayer(); tiles[d.uid]?.root.opacity = 1 }
        prevLabel.isHidden = true; rotFab.isHidden = true
        trashView.layer.borderWidth = 0; trashLabel.text = bagTr("버리기")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for h in cellHi + pocketHi { h.backgroundColor = nil; h.borderWidth = 0 }
        CATransaction.commit()
        overlaySig = ""
    }

    // MARK: 합성 창(웹 askMerge)

    private func askMerge(src: Int, dst: Int) {
        guard let e = editor, let s = state, let d = s.item(dst), let it = e.catalog.item(d.id) else { return }
        let c = e.catalog, t = d.tier
        mergeSheet?.removeFromSuperview()
        let box = UIView(); box.backgroundColor = bbColor("#211a3d"); box.layer.borderColor = bbColor("#5a4b9a").cgColor; box.layer.borderWidth = 3
        let w = min(bounds.width * 0.88, 340)
        let txt = NSMutableAttributedString()
        func add(_ s: String, _ col: String, _ size: CGFloat = 12, _ wt: UIFont.Weight = .regular) { txt.append(NSAttributedString(string: s, attributes: [.foregroundColor: bbColor(col), .font: UIFont.systemFont(ofSize: size, weight: wt)])) }
        add("\(it.name)\n", "#f1e6d0", 14, .heavy)
        add("★\(t)", BagCatalog.tierColors[min(5, t)], 12, .bold); add(" → ", "#cfc6e6"); add("★\(t + 1)", BagCatalog.tierColors[min(5, t + 1)], 12, .bold); add(" 합성\n", "#cfc6e6")
        // ★가 오르면 바뀌는 값(지금 배치 그대로)
        if it.kind == "skill" || it.kind == "dodge" {
            var a0: (Double, Double), a1: (Double, Double)
            if let i = s.bag.firstIndex(where: { $0.uid == dst }) {
                let st0 = c.rules.stats(i, bag: s.bag, sets: c.rules.sets(s.bag), imprints: s.imprints)
                var bag1 = s.bag; bag1[i].tier = t + 1
                let st1 = c.rules.stats(i, bag: bag1, sets: c.rules.sets(bag1), imprints: s.imprints)
                a0 = (st0.dmg, st0.cd ?? 0); a1 = (st1.dmg, st1.cd ?? 0)
            } else {
                a0 = ((it.dmg ?? 0) * BagSpec.tierDamage(t), (it.cd ?? 0) * BagSpec.tierCooldown(t))
                a1 = ((it.dmg ?? 0) * BagSpec.tierDamage(t + 1), (it.cd ?? 0) * BagSpec.tierCooldown(t + 1))
            }
            let dg = JSFormat.fixed(a0.1, 1) == JSFormat.fixed(a1.1, 1) ? 2 : 1
            if (it.dmg ?? 0) != 0 { add("피해 \(BagCatalog.formatDamage(a0.0)) → \(BagCatalog.formatDamage(a1.0))   ", "#ffd9a8", 12, .semibold) }
            add("쿨 \(JSFormat.fixed(a0.1, dg)) → \(JSFormat.fixed(a1.1, dg))초\n", "#cfe0ff", 12, .semibold)
        } else {
            var d1 = d; d1.tier = t + 1
            let S0 = c.tileStats(d, in: s), S1 = c.tileStats(d1, in: s)
            if let v0 = S0.val, let v1 = S1.val { add("\(v0) → \(v1)\n", S0.valColor ?? "#ffffff", 12, .semibold) } else { add("등급마다 효과가 커져요\n", "#cfc6e6") }
        }
        if let so = s.item(src)?.opt {   // 옵션 상속
            if let dop = d.opt {
                if dop.k == so.k {
                    let cap = c.options[dop.k]?.cap ?? 1, nv = min(cap, Double(JSFormat.round((dop.v + so.v * 0.5) * 100)) / 100)
                    add("같은 옵션이라 절반이 더해져요 · \(c.optionText(dop)) → \(c.optionText(ItemOption(k: dop.k, v: nv)))\n", c.options[so.k]?.c ?? "#ffffff", 11)
                } else { add("재료 옵션(\(c.optionText(so)))은 사라져요 — 지금 옵션 유지\n", "#cfc6e6", 11) }
            } else { add("\(c.optionText(so)) 옵션이 넘어와요\n", c.options[so.k]?.c ?? "#ffffff", 11) }
        }
        add("실패하면 재료 하나를 잃고 토큰 1개를 돌려받아요 · ★는 그대로", "#cfc6e6", 10)
        let info = UILabel(); info.numberOfLines = 0; info.attributedText = bagTrA(txt)
        let pLabel = UILabel(); pLabel.font = .systemFont(ofSize: 13, weight: .heavy); pLabel.textColor = bbColor("#ffcf7a")
        let barBG = UIView(); barBG.backgroundColor = bbColor("#0e0d14"); let bar = UIView(); bar.backgroundColor = bbColor("#7dffa0"); barBG.addSubview(bar)
        let sw = UISwitch(); sw.isEnabled = e.canBoost
        let swLabel = UILabel(); swLabel.numberOfLines = 2; swLabel.font = .systemFont(ofSize: 11); swLabel.textColor = e.canBoost ? bbColor("#f1e6d0") : UIColor.gray
        swLabel.text = bagTr("토큰 \(BagSpec.boostCost)개로 성공 +\(JSFormat.round(BagSpec.mergeBoost * 100))%  보유 \(s.tokens)")
        let no = UIButton(type: .custom), go = UIButton(type: .custom)
        styleButton(no, "그만두기", plate: false); styleButton(go, "합성하기", plate: false)
        let upd: () -> Void = { [weak self, weak pLabel, weak bar, weak barBG, weak go] in
            guard let self, let e = self.editor else { return }
            let q = e.mergeChance(dst: dst, boost: sw.isOn)
            pLabel?.text = bagTr("성공 \(JSFormat.round(q * 100))%")
            go?.setTitle(bagTr("합성하기 \(JSFormat.round(q * 100))%"), for: .normal)
            if let bg = barBG { bar?.frame = CGRect(x: 0, y: 0, width: bg.bounds.width * q, height: bg.bounds.height) }
        }
        sw.addAction(UIAction { _ in upd() }, for: .valueChanged)
        no.addAction(UIAction { [weak self] _ in self?.closeMerge() }, for: .touchUpInside)
        go.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let boost = sw.isOn, roll = self.randomRoll()
            self.closeMerge()
            self.onIntent?(.merge(src: src, dst: dst, boost: boost, roll: roll))
        }, for: .touchUpInside)
        for v in [info, pLabel, barBG, sw, swLabel, no, go] as [UIView] { box.addSubview(v) }
        let iw = w - 24, isz = info.sizeThatFits(CGSize(width: iw, height: 400))
        info.frame = CGRect(x: 12, y: 12, width: iw, height: isz.height)
        var y = info.frame.maxY + 8
        pLabel.frame = CGRect(x: 12, y: y, width: 100, height: 18); barBG.frame = CGRect(x: 112, y: y + 5, width: iw - 100, height: 8); y += 26
        sw.frame.origin = CGPoint(x: 12, y: y); swLabel.frame = CGRect(x: 12 + sw.bounds.width + 8, y: y, width: iw - sw.bounds.width - 8, height: 31); y += 40
        no.frame = CGRect(x: 12, y: y, width: (iw - 8) / 2, height: 34); go.frame = CGRect(x: 12 + (iw + 8) / 2, y: y, width: (iw - 8) / 2, height: 34); y += 46
        box.frame = CGRect(x: (bounds.width - w) / 2, y: max(8, gridRect.minY - 10), width: w, height: y)
        addSubview(box); mergeSheet = box
        upd()
    }
    private func closeMerge() { mergeSheet?.removeFromSuperview(); mergeSheet = nil }
}

/// 안쪽 여백 있는 글상자(미리보기 · 알림)
final class PaddedLabel: UILabel {
    var inset = UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = super.sizeThatFits(CGSize(width: size.width - inset.left - inset.right, height: size.height))
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
}
#endif
