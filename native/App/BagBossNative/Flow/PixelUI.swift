import SwiftUI
import UIKit
import BBUI

// 흐름 화면 공통 도트 스킨(웹 #gOverlay .g-card · .btn · .mm-tabs — CSS border-image 9-슬라이스).
// 그림은 가방 UI 와 같은 BBUI BagPixelSkin(웹 33-bag-ui2 buildInvSkin 1:1 — 가죽 틀 · 짙은 판 · 놋쇠 버튼)을 최근접 2배로 키워
// SwiftUI 9-슬라이스(resizable capInsets · 타일)로 깐다. 글꼴은 갈무리(Font.galmuri · galmuriSmall — GameHUDView).

extension Color {
    /// '#rrggbb'
    init(px hex: String, _ a: Double = 1) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255, opacity: a)
    }
}

/// 웹 오버레이 색(CSS 그대로)
enum PX {
    static let ink = Color(px: "#f1e6d0")       // 카드 본문
    static let sub = Color(px: "#cfc39a")       // 머리 줄 · 부제
    static let gold = Color(px: "#ffcf7a")      // .mm-sub
    static let accent = Color(px: "#ffd34a")
    static let dark = Color(px: "#0e0d14")
    static let note = Color(px: "#a99c80")      // .mm-note
    static let lilac = Color(px: "#e9e4f7")     // 판 버튼 글
    static let muted = Color(px: "#cfc6e6")
    static let small = Color(px: "#a99cc0")     // 목록 small
    static let unknown = Color(px: "#6a6290")   // 모르는 항목
    static let brass = Color(px: "#2a1a10")     // 놋쇠 버튼 위 글
    static let paper = Color(px: "#efe6cf"), paperInk = Color(px: "#1a1610"), paperSub = Color(px: "#5a4e38")

    /// 9-슬라이스 원본(2배) · 모서리(점)
    enum Skin { case frame, plate, btn }
    nonisolated(unsafe) static let images: [Skin: UIImage] = {
        let s = BagPixelSkin.shared
        return [.frame: UIImage(cgImage: bbUpscale(s.frame, 2)), .plate: UIImage(cgImage: bbUpscale(s.plate, 2)), .btn: UIImage(cgImage: bbUpscale(s.btn, 2))]
    }()
    static func cap(_ k: Skin) -> CGFloat { k == .frame ? 16 : 8 }
}

extension View {
    /// 도트 9-슬라이스 바탕(웹 border-image … fill)
    func pixelPanel(_ k: PX.Skin) -> some View {
        background {
            let c = PX.cap(k)
            Image(uiImage: PX.images[k]!)
                .resizable(capInsets: EdgeInsets(top: c, leading: c, bottom: c, trailing: c), resizingMode: .tile)
                .interpolation(.none)
        }
    }
    /// 웹 #gOverlay .g-card(가죽 틀) — 안쪽 여백 포함
    func gCard() -> some View {
        padding(.horizontal, 18).padding(.vertical, 16).pixelPanel(.frame)
    }
}

/// 판(plate) / 놋쇠(btn) 버튼 — 웹 .btn · .btn.primary · 탭 버튼(on)
struct PixelButtonLook: ButtonStyle {
    var brass = false
    var minHeight: CGFloat = 32
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.galmuri(12, bold: brass))
            .foregroundStyle(brass ? PX.brass : PX.lilac)
            .padding(.horizontal, 10)
            .frame(minHeight: minHeight)
            .pixelPanel(brass ? .btn : .plate)
            .brightness(configuration.isPressed ? 0.25 : 0)
            .opacity(enabled ? 1 : 0.5)
    }
}

/// 탭 줄(웹 .mm-tabs · .mm-ctabs)
struct PixelTabs<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    var scroll = false
    var onPick: (() -> Void)? = nil
    var body: some View {
        let row = HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                Button { selection = it.0; onPick?() } label: { Text(it.1).lineLimit(1) }
                    .buttonStyle(PixelButtonLook(brass: it.0 == selection, minHeight: 28))
            }
        }
        if scroll { ScrollView(.horizontal, showsIndicators: false) { row } } else { row }
    }
}

/// 진행 막대(웹 .mm-prog)
struct PixelProgress: View {
    var value: Double
    var color = Color(px: "#ffb547")
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(PX.dark)
                Rectangle().fill(color).frame(width: g.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 4)
    }
}

/// 웹 text-shadow:1px 1px 0 #0e0d14
extension Text {
    func inkShadow() -> some View { shadow(color: PX.dark, radius: 0, x: 1, y: 1) }
}

// MARK: 도트 디자인 토큰(docs/09 — 게임 화면부터 쓰고, 다른 화면은 차차 옮긴다)

/// 글자 사다리(갈무리11): 3배 화면에서 글자 1px = 기기 3 · 4 · 6px(정수배라 번지지 않는다)
enum PXType {
    /// 본문 · 보조(11pt)
    static let s: CGFloat = 11
    /// 단추 · 이름(14.67pt)
    static let m: CGFloat = 44.0 / 3
    /// 큰 단추 · 점수(22pt)
    static let l: CGFloat = 22
    static func font(_ size: CGFloat, bold: Bool = false) -> Font { .galmuri(size, bold: bold) }
}

/// 간격 · 손가락 자리
enum PXSpace {
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16
    /// 최소 누름 자리(HIG 44pt)
    static let hit: CGFloat = 44
}

/// 게임 화면 색(가죽 시트 · 필살 · 정리 중)
extension PX {
    static let leather = Color(px: "#5a3a1e"), leatherDark = Color(px: "#3a2414"), leatherHi = Color(px: "#c98a3c")
    static let hot = Color(px: "#ff7a2a"), hotDeep = Color(px: "#b8461a"), hotInk = Color(px: "#fff1d0")
    static let calm = Color(px: "#6ee8dc"), calmInk = Color(px: "#0b2a2a")
    static let plateFill = Color(px: "#2c2648"), plateLine = Color(px: "#8a7fc0")
    static let label = Color(px: "#e8d6a8")
}

/// 단추 피드백(딸깍 · 가벼운 진동) — 게임 화면이 설정(소리 · 진동)에 맞춰 넣어 준다
/// 인자 = 딸깍 소리도 낼지(false 면 진동만)
private struct PixelFeedbackKey: EnvironmentKey { static let defaultValue: (@MainActor @Sendable (Bool) -> Void)? = nil }
extension EnvironmentValues {
    var pixelFeedback: (@MainActor @Sendable (Bool) -> Void)? {
        get { self[PixelFeedbackKey.self] }
        set { self[PixelFeedbackKey.self] = newValue }
    }
}

/// 도트 단추 하나(평소 · 눌림 · 끔): 눌리면 1.5pt 내려가고 어두워진다(아래 턱이 사라짐) · 끄면 흐리고 회색.
/// 최소 44×44pt. 눌리는 순간 pixelFeedback(딸깍 · 진동)
struct PixelButton: ButtonStyle {
    enum Kind { case plate, brass, hot }
    var kind: Kind = .plate
    var minWidth: CGFloat = PXSpace.hit, minHeight: CGFloat = PXSpace.hit
    /// 동작이 이미 소리를 내면 false(두 번 울리지 않게)
    var sound = true
    @Environment(\.isEnabled) private var enabled
    @Environment(\.pixelFeedback) private var feedback

    func makeBody(configuration: Configuration) -> some View {
        let p = configuration.isPressed
        return configuration.label
            .foregroundStyle(kind == .hot ? PX.hotInk : kind == .brass ? PX.brass : PX.lilac)
            .multilineTextAlignment(.center)
            .padding(.horizontal, PXSpace.s)
            .frame(minWidth: minWidth, minHeight: minHeight)
            .background { face }
            .background(Rectangle().fill(PX.dark).offset(y: p ? 0 : 2))   // 아래 턱
            .brightness(p ? -0.16 : 0)
            .offset(y: p ? 1.5 : 0)
            .saturation(enabled ? 1 : 0.15).opacity(enabled ? 1 : 0.55)
            .contentShape(Rectangle())
            .onChange(of: p) { _, now in if now && enabled { feedback?(sound) } }
    }

    @ViewBuilder private var face: some View {
        switch kind {
        case .plate: Rectangle().fill(PX.plateFill).overlay(Rectangle().strokeBorder(PX.dark, lineWidth: 2)).overlay(Rectangle().strokeBorder(PX.plateLine.opacity(0.6), lineWidth: 1).padding(2))
        case .brass: Color.clear.pixelPanel(.btn)
        case .hot:
            Rectangle().fill(PX.hot)
                .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.22)).frame(height: 3).padding(3) }
                .overlay(Rectangle().strokeBorder(PX.gold, lineWidth: 3)).overlay(Rectangle().strokeBorder(PX.dark, lineWidth: 1))
        }
    }
}
