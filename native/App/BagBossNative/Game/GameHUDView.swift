import SwiftUI
import BBContent
import BBPresentation

// HUD 의 SwiftUI 부분(웹 DOM 이던 안내 상자) + 앱 공용 글꼴 · 글자 도우미. 캔버스 HUD 는 오버레이 패스(GameStageView · BBRender OverlayRenderer).

extension Font {
    static func galmuri(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? GameFonts.uiBold : GameFonts.ui, size: size) }
    static func galmuriSmall(_ size: CGFloat) -> Font { .custom(GameFonts.small, size: size) }
    static func comic(_ size: CGFloat) -> Font { .custom(GameFonts.comic, size: size) }
}

/// 4방향 1pt 테두리 글자(웹 outlined)
struct Outlined: View {
    let text: String, font: Font, color: Color
    var outline: Color = Color(red: 0.055, green: 0.05, blue: 0.08)
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { k in
                Text(text).font(font).foregroundStyle(outline)
                    .offset(x: [-1.5, 1.5, 0, 0][k], y: [0, 0, -1.5, 1.5][k])
            }
            Text(text).font(font).foregroundStyle(color)
        }
        .fixedSize()
    }
}

/// SwiftUI 로 남는 HUD = 웹에서 DOM 이던 것만: 안내 상자(sayEl). 나머지(피해 숫자 · HITFX · 만화 · 말풍선 · 컷인 · 노선도 · 체력 칸 ·
/// 필살 게이지 · 연타 · 기술 줄 · 두목 막대 · 상태 글자 · 문 전환)는 웹 #ui 캔버스였으므로 Metal 오버레이 패스(GameStageView)가 그린다.
struct GameHUDView: View {
    let hud: HUDState
    let view: StageView
    /// 아래 비울 높이(새 배치: 왼쪽 아래 초상 · 체력 묶음 위로)
    var bottomPad: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let n = hud.notice {
                    NoticeView(notice: n)
                        .frame(maxWidth: geo.size.width - 24)
                        .position(x: geo.size.width / 2, y: geo.size.height - 30 - bottomPad)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct HPBar: View {
    let hp: Double, lag: Double, max: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.7))
                Rectangle().fill(Color(red: 0.95, green: 0.85, blue: 0.85)).frame(width: g.size.width * CGFloat(Swift.max(0, Swift.min(1, lag / max))))
                Rectangle().fill(hp / max < 0.3 ? Color(red: 0.95, green: 0.25, blue: 0.3) : Color(red: 0.4, green: 0.85, blue: 0.45))
                    .frame(width: g.size.width * CGFloat(Swift.max(0, Swift.min(1, hp / max))))
            }
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
    }
}



struct Star: Shape {
    let points: Int, inner: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), n = points * 2
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi, f = i % 2 == 1 ? inner : 1
            let q = CGPoint(x: c.x + cos(a) * r.width / 2 * f, y: c.y + sin(a) * r.height / 2 * f)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}


struct NoticeView: View {
    let notice: HUDState.Notice
    var body: some View {
        // 번역은 자르기 전에(통째 문장으로 사전을 찾는다) — 찍힌 글자 수는 원문 비율로 옮긴다
        let T = tr(notice.title), B = tr(notice.body)
        let all0 = notice.title.count + notice.body.count, all = T.count + B.count
        let n = all0 == 0 ? all : min(all, Int((Double(min(all0, notice.shownChars)) / Double(all0) * Double(all)).rounded(.up)))
        let t = String(T.prefix(n)), b = String(B.prefix(max(0, n - T.count)))
        VStack(alignment: .leading, spacing: 2) {
            if !notice.title.isEmpty { Text(t).font(.galmuri(11, bold: true)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.45)) }
            if !notice.body.isEmpty { Text(b).font(.galmuriSmall(10)).foregroundStyle(.white) }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.06, green: 0.05, blue: 0.1).opacity(0.85))
        .overlay(Rectangle().stroke(Color(red: 0.4, green: 0.36, blue: 0.5), lineWidth: 1))
        .opacity(notice.alpha)
    }
}

/// 성능 줄(설정 › 개발자 › 성능 표시 — 출시판 기본 끔)
struct PerfOverlay: View {
    let perf: PerfStats
    var body: some View {
        Text(String(format: "%.0ffps · 틱 %.2fms · 프레임 %.2fms · GPU %.2fms · 인물 %d · 입자 %d", perf.fps, perf.simMs, perf.frameMs, perf.gpuMs, perf.actors, perf.particles))
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.green)
            .padding(3).background(Color.black.opacity(0.6))
            .allowsHitTesting(false)
    }
}
