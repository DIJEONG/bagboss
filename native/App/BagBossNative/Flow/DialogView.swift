import SwiftUI
import Observation
import BBAudio
import BBContent
import BBSim

// 대화 상자(웹 44-story: tkShow · tkNext · tkPick · tkSkip · drawPortrait · blip)와 도움말 카드(웹 41 hint → say('도움말 · 제목', 본문, 4.2)).
// 대화 규칙(줄 · 고르기 · 끼워 넣는 대답 · 대기열 · 고른 값)은 시뮬레이션 몫이다(BBSim World+Story — SimSnapshot.talk: TalkView).
// 여기는 그리기와 글자 찍기(타자기 · 목소리)만: 무대 탭 → 치는 중이면 다 보이기, 아니면 SimIntent.talkNext ·
// 고르기 → .talkPick(k) · 건너뛰기 → .talkDone. 대화 중엔 판이 멈춘다(시뮬레이션). 도움말은 SimSnapshot.hint(HintView).

/// 웹 VOX(말소리 blip) — 글자 간격 ms · 음색
struct Vox { let f: Double, wave: Waveform, ms: Double, span: Double, vol: Double, slide: Double }
let VOX: [String: Vox] = [
    "cond": Vox(f: 150, wave: .triangle, ms: 48, span: 5, vol: 0.05, slide: 1),
    "saboo": Vox(f: 240, wave: .square, ms: 36, span: 8, vol: 0.022, slide: 0.94),
    "minnie": Vox(f: 430, wave: .triangle, ms: 39, span: 7, vol: 0.045, slide: 1.06),
    "me": Vox(f: 118, wave: .sine, ms: 46, span: 3, vol: 0.05, slide: 0.98),
]
private let VOWEL: [Double] = [2, 3, 1, 2, 1, 2, 0, 1, -2, -1, -1, -1, -2, -3, -2, -2, -3, -3, -4, -3, 4]

/// 웹 blip(who, ch): 한글이면 모음으로 음높이, 아니면 글자 코드로
func blipCue(_ who: String, _ ch: Character) -> SfxCue {
    let V = VOX[who] ?? VOX["cond"]!
    let code = Int(ch.unicodeScalars.first?.value ?? 0)
    var st = (0xAC00...0xD7A3).contains(code) ? VOWEL[((code - 0xAC00) % 588) / 28] * V.span / 4 : Double((code * 7) % Int(V.span * 2)) - V.span
    st += (Double.random(in: 0..<1) - 0.5) * 1.2
    let f = V.f * pow(2, st / 12), d = V.ms / 1000 * 0.85
    return .tone(dur: d, f: f, to: f * V.slide, wave: V.wave, g: V.vol, att: 0.006)
}

// MARK: 글자 찍기(웹 tkShow 의 step — 줄마다 처음부터)

@MainActor @Observable
final class TalkTyper {
    private(set) var shown = 0
    private(set) var typing = false
    @ObservationIgnored private(set) var lineKey = ""
    @ObservationIgnored var onBlip: ((SfxCue) -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?

    /// 새 줄이면(대화 열쇠 · 줄 번호) 처음부터 찍는다
    func sync(_ v: TalkView?) {
        guard let v else { task?.cancel(); lineKey = ""; typing = false; return }
        let k = "\(v.key)#\(v.i)#\(v.count)"
        guard k != lineKey else { return }
        lineKey = k
        task?.cancel()
        if v.choices != nil { typing = false; shown = 0; return }
        let p = Array(TalkText.plain(tr(v.text))), w = v.who, ms = (VOX[w] ?? VOX["cond"]!).ms
        shown = 0; typing = true
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            var k = 0
            while k < p.count {
                guard let self, !Task.isCancelled, self.typing else { return }
                let ch = p[k]; k += 1; self.shown = k
                if !" .,!?…·—:()".contains(ch) { self.onBlip?(blipCue(w, ch)) }
                let mul = ".!?…".contains(ch) ? 5.0 : ",·—:".contains(ch) ? 2.5 : 1.0
                try? await Task.sleep(for: .milliseconds(Int(ms * mul)))
            }
            self?.finish()
        }
    }
    /// 웹 tkFinish: 줄 전체 보이기
    func finish() { task?.cancel(); typing = false; shown = .max }
}

enum TalkText {
    static func plain(_ s: String) -> String { s.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "") }
    /// <b> 강조(웹 .tk-text b: #ffd36a 굵게) — 앞에서 n 글자만
    static func attributed(_ s: String, upTo n: Int) -> AttributedString {
        var out = AttributedString(), left = n, bold = false, rest = Substring(s)
        while !rest.isEmpty && left > 0 {
            if rest.hasPrefix("<b>") { bold = true; rest = rest.dropFirst(3); continue }
            if rest.hasPrefix("</b>") { bold = false; rest = rest.dropFirst(4); continue }
            var run = AttributedString(String(rest.first!))
            if bold { run.swiftUI.foregroundColor = Color(px: "#ffd36a"); run.swiftUI.font = Font.galmuri(12, bold: true) }
            out += run; rest = rest.dropFirst(); left -= 1
        }
        return out
    }
}

// MARK: 대화 상자(웹 .talk)

struct DialogView: View {
    let talk: TalkView
    @Bindable var typer: TalkTyper
    var onTap: () -> Void
    var onPick: (Int) -> Void
    var onSkip: () -> Void

    var body: some View {
        let tc = Color(px: talk.color)
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 8) {
                Portrait(who: talk.who, color: tc)
                    .frame(width: 58, height: 58)
                    .overlay(Rectangle().stroke(tc, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr(talk.name)).font(.galmuri(11, bold: true)).foregroundStyle(PX.dark)
                        .padding(.horizontal, 6).background(tc)
                    Text(TalkText.attributed(tr(talk.text), upTo: typer.typing ? typer.shown : .max))
                        .font(.galmuri(12)).foregroundStyle(Color(px: "#f6ecd6")).lineSpacing(4)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let ch = talk.choices {
                        FlowLayout(spacing: 6) {
                            ForEach(Array(ch.enumerated()), id: \.offset) { k, o in
                                Button { onPick(k) } label: {
                                    Text(tr(o)).font(.galmuri(11, bold: true)).foregroundStyle(Color(px: "#f6ecd6"))
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color(px: "#2a2440")).overlay(Rectangle().stroke(Color(px: "#ffd36a"), lineWidth: 2))
                                        .background(PX.dark.offset(x: 2, y: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 10))
            .background(Color(red: 14 / 255, green: 13 / 255, blue: 20 / 255).opacity(0.94))
            .overlay(Rectangle().stroke(Color(px: "#f1e6cf"), lineWidth: 2))
            .background(PX.dark.offset(x: 3, y: 3))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            // ▼ 더 보기(깜빡임)
            if !typer.typing && talk.choices == nil {
                TimelineView(.periodic(from: .now, by: 0.4)) { t in
                    Text("▼").font(.galmuriSmall(10)).foregroundStyle(Color(px: "#ffd36a"))
                        .opacity(Int(t.date.timeIntervalSinceReferenceDate / 0.4) % 2 == 0 ? 1 : 0)
                }
                .frame(maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 9).padding(.bottom, 5)
                .allowsHitTesting(false)
            }
            Button { onSkip() } label: {
                Text(tr("건너뛰기")).font(.galmuriSmall(10)).foregroundStyle(Color(px: "#cfc3a6"))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(PX.dark).overlay(Rectangle().stroke(Color(px: "#5a5266"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .offset(x: -6, y: -24)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 웹 drawPortrait: 잉크 실루엣 + 소품 하나(64×64 캔버스를 그대로 비율로)
struct Portrait: View {
    let who: String
    let color: Color
    var body: some View {
        Canvas { c, size in
            let W = size.width, H = size.height, ink = Color(px: "#14121c")
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(colors: [color, Color(px: "#0e0d14")]),
                   center: CGPoint(x: W * 0.5, y: H * 0.4), startRadius: 2, endRadius: W * 0.8))
            var body = Path()
            body.move(to: CGPoint(x: W * 0.1, y: H)); body.addQuadCurve(to: CGPoint(x: W * 0.5, y: H * 0.64), control: CGPoint(x: W * 0.16, y: H * 0.66))
            body.addQuadCurve(to: CGPoint(x: W * 0.9, y: H), control: CGPoint(x: W * 0.84, y: H * 0.66)); body.closeSubpath()
            c.fill(body, with: .color(ink))
            c.fill(Path(CGRect(x: W * 0.43, y: H * 0.5, width: W * 0.14, height: H * 0.16)), with: .color(ink))
            c.fill(Path(ellipseIn: CGRect(x: W * 0.34, y: H * 0.23, width: W * 0.32, height: H * 0.38)), with: .color(ink))
            func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: String) { c.fill(Path(CGRect(x: W * x, y: H * y, width: W * w, height: H * h)), with: .color(Color(px: col))) }
            func E(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ rot: Double, _ col: Color) {
                var p = Path(ellipseIn: CGRect(x: -W * rx, y: -H * ry, width: W * rx * 2, height: H * ry * 2))
                p = p.applying(CGAffineTransform(rotationAngle: rot)).applying(CGAffineTransform(translationX: W * cx, y: H * cy))
                c.fill(p, with: .color(col))
            }
            switch who {
            case "cond":   // 차장 모자 · 배지 · 회중시계 줄
                R(0.3, 0.16, 0.4, 0.12, "#14121c"); R(0.25, 0.27, 0.5, 0.04, "#14121c"); R(0.47, 0.19, 0.06, 0.05, "#ffcf5a"); R(0.6, 0.76, 0.03, 0.14, "#ffcf5a")
            case "saboo":  // 넘긴 머리 · 선글라스 · 금니 · 넓은 깃
                E(0.47, 0.27, 0.19, 0.08, -0.2, ink); R(0.35, 0.38, 0.3, 0.05, "#9fe6ff"); R(0.53, 0.5, 0.05, 0.04, "#ffcf5a")
                var v = Path(); v.move(to: CGPoint(x: W * 0.38, y: H * 0.68)); v.addLine(to: CGPoint(x: W * 0.5, y: H * 0.86)); v.addLine(to: CGPoint(x: W * 0.62, y: H * 0.68))
                c.stroke(v, with: .color(Color(px: "#cfc3a6")), lineWidth: W * 0.02)
            case "minnie": // 헌팅캡 · 신문 묶음
                E(0.5, 0.26, 0.22, 0.1, 0, ink); R(0.5, 0.3, 0.26, 0.04, "#14121c"); R(0.14, 0.72, 0.34, 0.24, "#f1e6cf")
                for k in 0..<4 { R(0.18, 0.76 + Double(k) * 0.045, 0.26, 0.015, "#14121c") }
            default:       // 나: 넘긴 머리 · 흰 셔츠 · 붉은 넥타이
                E(0.48, 0.27, 0.17, 0.07, -0.15, ink)
                var v = Path(); v.move(to: CGPoint(x: W * 0.42, y: H * 0.66)); v.addLine(to: CGPoint(x: W * 0.5, y: H * 0.8)); v.addLine(to: CGPoint(x: W * 0.58, y: H * 0.66)); v.closeSubpath()
                c.fill(v, with: .color(Color(px: "#f1e6cf"))); R(0.48, 0.69, 0.04, 0.16, "#d6453a")
            }
        }
        .background(PX.dark)
    }
}

// MARK: 도움말 카드(웹 hint → say('도움말 · 제목', 본문, 4.2))

struct HintCard: Equatable, Identifiable {
    let id: String
    let title: String, body: String
}

struct HintCardView: View {
    let card: HintCard
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tr("도움말") + " · " + tr(card.title)).font(.galmuri(12, bold: true)).foregroundStyle(PX.gold)
            Text(tr(card.body)).font(.galmuriSmall(11)).foregroundStyle(PX.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: 340, alignment: .leading)
        .pixelPanel(.plate)
        .shadow(color: .black.opacity(0.6), radius: 0, x: 3, y: 3)
    }
}

/// 줄바꿈 가로 배치(선택지 · 조건 배지)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += z.width + spacing; rowH = max(rowH, z.height); w = max(w, x - spacing)
        }
        return CGSize(width: min(w, maxW), height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > b.minX && x + z.width > b.maxX { x = b.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; rowH = max(rowH, z.height)
        }
    }
}

#if DEBUG
#Preview("대화 상자") {
    var v = TalkView(); v.key = "intro"; v.who = "minnie"; v.name = "미니"; v.color = "#ff8a5a"; v.text = "호외요, 호외! <b>보스의 가방</b>이 막차에서 터졌대요!"
    let t = TalkTyper()
    return ZStack(alignment: .bottom) {
        Color.black
        DialogView(talk: v, typer: t, onTap: { t.finish() }, onPick: { _ in }, onSkip: {}).padding(8)
    }
    .onAppear { GameFonts.register(); t.sync(v) }
}
#endif

// MARK: 콤보 연구실(무도장) — 전체 패널은 Features/DojoPanel.swift(에이전트 O). GameView 가 부르는 이름을 그대로 둔다.

struct DojoBar: View {
    @Bindable var session: GameSession
    let dojo: DojoView
    var body: some View { DojoPanel(session: session, dojo: dojo) }
}
