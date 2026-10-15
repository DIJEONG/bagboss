import SwiftUI
import UIKit
import BBSim

// 직접 조작 패드(접힌 시트 본문 — 전투 중 · 설정 '직접 조작 패드' 켬). 규칙은 BBSim World+NativePad.
// 배치(오른손 기준 — 왼손이면 좌우를 뒤집는다):
//   위 띠: 수동 · 자동 칩 · 콤보 순서 칩(1 무릎 › 2 내려찍기 › 3 쌍장) · 속도
//   왼쪽: ◀ ▶(누르고 있으면 걷기) · ▼ 숙이기(기본 장착) · 필살
//   오른쪽: 기울인 두 줄 — 아래 줄 = 콤보 경로 ①②③(왼→오) + 오른쪽 끝 엄지 자리 큰 기본기(앞에서 적이 공격을 준비하면 빨간 '받아치기') ·
//           위 줄 = 나머지 기술(작게). 버튼은 누르는 순간(손가락이 닿을 때) 낸다 — 뗄 때가 아니다.
// 쿨타임 = 시계 방향 그늘 + 남은 초 · 콤보 다음 차례 = 노란 테두리 맥박.

struct PadBody: View {
    @Bindable var session: GameSession
    /// 방향키 뛰기 판단(같은 방향 두 번 0.3초 안 · 꾹 0.35초)
    @State private var arrows = ArrowTracker()
    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height, P = session.pad
            let L = session.settings.padLefty
            let lay = PadLayout(W: W, H: H, pad: P, lefty: L)
            ZStack(alignment: .topLeading) {
                PadStrip(session: session, pad: P).frame(width: W, height: PadLayout.stripH)
                ForEach(lay.dpad) { b in
                    PadKey(label: b.label, aria: b.aria, w: b.w, h: b.h, heavy: b.kind == .duck && P.heavy,
                           down: { press(b.kind, true) }, up: { press(b.kind, false) })
                        .position(x: b.x, y: b.y)
                }
                SpecialMini(session: session, w: lay.special.width, h: lay.special.height)
                    .position(x: lay.special.midX, y: lay.special.midY)
                ForEach(lay.buttons) { s in
                    PadSkillButton(spec: s, counter: s.basic && P.counter) {
                        if s.basic { session.padInput(.basic) } else { session.padInput(.skill(uid: s.uid)) }
                    }
                    .position(x: s.x, y: s.y)
                }
            }
        }
    }
    private func press(_ k: PadLayout.Key.Kind, _ on: Bool) {
        switch k {
        case .left, .right:
            let d = k == .left ? -1 : 1
            guard on else { arrows.release(); session.padInput(.move(0), feedback: false); return }
            if arrows.pressDoubles(d) { session.padInput(.run(d)); return }   // 두 번 누름 → 바로 뛰기
            session.padInput(.move(d))
            let token = arrows.token
            DispatchQueue.main.asyncAfter(deadline: .now() + ArrowTracker.holdRun) { [session] in   // 꾹 누름 → 뛰기
                if arrows.held == d && arrows.token == token && !arrows.running { arrows.running = true; session.padInput(.run(d), feedback: false) }
            }
        case .duck: if on { session.padInput(.duck) }
        }
    }
}

/// 방향키 뛰기 판단: 같은 방향을 doubleGap 안에 다시 누르면 바로 · holdRun 동안 누르고 있으면 뛴다
final class ArrowTracker {
    static let doubleGap = 0.3, holdRun = 0.35
    var lastDir = 0, lastTap = -9.0, held = 0, token = 0, running = false
    /// 누름 기록 — 두 번 누름이면 true
    func pressDoubles(_ d: Int) -> Bool {
        let now = CACurrentMediaTime(), dbl = d == lastDir && now - lastTap < Self.doubleGap
        lastDir = d; lastTap = now; held = d; token += 1; running = dbl
        return dbl
    }
    func release() { held = 0; running = false; token += 1 }
}

/// 자리 계산(뷰 크기 · 패드 보기 · 왼손)
struct PadLayout {
    static let stripH: CGFloat = 26
    struct Key: Identifiable { enum Kind { case left, right, duck }; let kind: Kind; var id: Int { kind.hashValue }; let label: String, aria: String; let x, y, w, h: CGFloat }
    struct Btn: Identifiable {
        let id: Int, uid: Int, basic: Bool
        let x, y, d: CGFloat
        let label: String, aria: String, color: Color
        let cd: Double, wait: Double, order: Int?, next: Bool
    }
    var dpad: [Key] = [], buttons: [Btn] = []
    var special = CGRect.zero

    init(W: CGFloat, H: CGFloat, pad P: SimSnapshot.PadView, lefty: Bool) {
        func mx(_ x: CGFloat) -> CGFloat { lefty ? W - x : x }
        let top = Self.stripH + 6, A = H - top
        // 왼쪽 기둥: ◀ ▶ · ▼ · 필살
        let lw = min(138, W * 0.34), kb = min(56, (lw - 10) / 2, A * 0.3)
        let ky = top + kb / 2
        dpad = [Key(kind: .left, label: "◀", aria: KE("왼쪽으로", "Move left"), x: mx(4 + kb / 2), y: ky, w: kb, h: kb),
                Key(kind: .right, label: "▶", aria: KE("오른쪽으로", "Move right"), x: mx(4 + kb + 8 + kb / 2), y: ky, w: kb, h: kb)]
        let dh = min(42, A * 0.2), dy = top + kb + 8 + dh / 2
        dpad.append(Key(kind: .duck, label: KE("▼ 숙이기", "▼ Duck"), aria: KE("숙이기", "Duck"), x: mx(4 + (kb * 2 + 8) / 2), y: dy, w: kb * 2 + 8, h: dh))
        let sy = top + kb + 8 + dh + 8, sh = max(40, A - (kb + 8 + dh + 8) - 4)
        special = CGRect(x: lefty ? W - 4 - (kb * 2 + 8) : 4, y: sy, width: kb * 2 + 8, height: min(sh, 64))
        // 오른쪽: 기울인 두 줄
        let rx0 = lw + 8, rw = W - rx0 - 6
        let route = P.skills.filter { $0.order != nil }.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
        var low = Array(route.prefix(3)), high = Array(route.dropFirst(3)) + P.skills.filter { $0.order == nil }
        if low.isEmpty { low = Array(high.prefix(3)); high = Array(high.dropFirst(low.count)) }
        high = Array(high.prefix(3))
        let slant: CGFloat = 10, gap: CGFloat = 8
        let n = CGFloat(max(1, low.count))
        var dB = min(64, (rw - gap * n) / (n + 1.25), A * 0.36), dJ = dB * 1.22
        dB = max(44, dB); dJ = max(52, dJ)
        let dT = max(42, dB * 0.84)
        // 두 줄 묶음을 영역 가운데쯤에(위 줄이 없으면 아래 줄만 가운데) — 맨 아래에 몰리지 않게
        let blockH = (high.isEmpty ? 0 : dT + 10) + dJ + n * slant
        let jx = rx0 + rw - dJ / 2, jy = min(top + A - dJ / 2 - 4 - n * slant, top + (A - blockH) / 2 + (high.isEmpty ? 0 : dT + 10) + dJ / 2)
        func col(_ s: SimSnapshot.PadView.Btn) -> Color {
            switch s.fam { case "fist": return Color(px: "#a8443a"); case "grap": return Color(px: "#2e8656"); case "foot": return Color(px: "#3a6ab0"); default: return Color(px: "#6d5e8f") }
        }
        var out: [Btn] = []
        out.append(Btn(id: -1, uid: -1, basic: true, x: mx(jx), y: jy, d: dJ, label: KE("기본기", "Basic"), aria: KE("기본기 — 앞에서 공격을 준비하는 적이 있으면 받아치기", "Basic attack — counters a foe winding up"),
                       color: Color(px: "#3d4a63"), cd: 0, wait: 0, order: nil, next: false))
        for (k, s) in low.enumerated() {
            let back = CGFloat(low.count - k)
            let x = jx - dJ / 2 - gap - dB / 2 - (back - 1) * (dB + gap), y = jy + back * slant
            out.append(Btn(id: s.uid, uid: s.uid, basic: false, x: mx(x), y: min(y, top + A - dB / 2 - 2), d: dB, label: PadNames.short(s.id, s.name), aria: tr(s.name),
                           color: col(s), cd: s.cd, wait: s.wait, order: s.order, next: s.next))
        }
        let lowY = jy + slant
        for (k, s) in high.enumerated() {
            let x = jx - dJ / 2 - gap - dB / 2 - CGFloat(max(0, low.count - 1 - k)) * (dB + gap) + dB * 0.45
            let y = lowY - dB / 2 - dT / 2 - 10 - CGFloat(k) * slant + CGFloat(max(0, low.count - 1)) * slant * 0.3
            out.append(Btn(id: s.uid, uid: s.uid, basic: false, x: mx(x), y: max(top + dT / 2, y), d: dT, label: PadNames.short(s.id, s.name), aria: tr(s.name),
                           color: col(s), cd: s.cd, wait: s.wait, order: s.order, next: s.next))
        }
        buttons = out
    }
}

/// 버튼에 쓰는 짧은 이름(네이티브 · 웹 기술) — 모르면 이름의 첫 낱말
enum PadNames {
    static var table: [String: String] { [
        "nv_slam": KE("내려찍기", "Slam"),
        "nv_stamp": KE("쌍장", "Palms"),
        "nv_headbutt": KE("박치기", "Headbutt"),
        "nv_dial": KE("수화기", "Phone"),
        "nv_punt": KE("슛", "Punt"),
        "nv_kneelift": KE("무릎", "Knee"),
        "nv_duckup": KE("파고들기", "Duck-in"),
        "nv_rise": KE("승천권", "Rise"),
        "nv_beam": KE("광선", "Beam"),
        "nv_cork": KE("코크", "Cork"),
        "nv_liver": KE("리버", "Liver"),
        "nv_flick": KE("플리커", "Flicker"),
        "nv_roll": KE("숄더롤", "Roll"),
        "punch": KE("주먹", "Punch"),
        "upper": KE("어퍼컷", "Upper"),
        "kick": KE("앞차기", "Kick"),
        "knee": KE("니킥", "Knee"),
        "elbow": KE("팔꿈치", "Elbow"),
        "round": KE("돌려차기", "Round"),
        "sweep": KE("다리걸기", "Sweep"),
        "charge": KE("돌진", "Charge"),
        "throw": KE("메치기", "Throw"),
        "stomp": KE("밟기", "Stomp"),
        "bkick": KE("뒤차기", "Back"),
        "bfist": KE("백피스트", "Backfist"),
        "fkick": KE("날아차기", "Fly kick"),
        "cycle": KE("자전거", "Bicycle"),
        "axe": KE("도끼차기", "Axe"),
        "suplex": KE("수플렉스", "Suplex"),
        "renkan": KE("연환퇴", "Renkan"),
        "tetsu": KE("철산고", "Tetsu"),
        "skick": KE("섬머솔트", "Flip"),
        "umb": KE("우산", "Umbrella"),
        "paper": KE("신문", "Paper"),
        "case": KE("가방", "Case"),
        "hmup": KE("장도리", "Hammer"),
        "hmswing": KE("장도리", "Hammer"),
        "hmback": KE("장도리", "Hammer"),
        "hmdown": KE("장도리", "Hammer"),
    ] }
    static func short(_ id: String, _ name: String) -> String {
        if let s = table[id] { return s }
        let full = tr(name)
        return String(full.split(separator: " ").first ?? Substring(full))
    }
}

/// 위 띠: 수동 · 자동 · 콤보 순서 · 속도
struct PadStrip: View {
    @Bindable var session: GameSession
    let pad: SimSnapshot.PadView
    var body: some View {
        HStack(spacing: 6) {
            let manual = pad.manual > 0
            Text(manual ? KE("수동 \(String(format: "%.1f", pad.manual))", "Manual \(String(format: "%.1f", pad.manual))") : KE("자동", "Auto"))
                .font(PXType.font(PXType.s, bold: true)).monospacedDigit()
                .foregroundStyle(manual ? Color(px: "#1a120c") : PX.sub)
                .padding(.horizontal, 8).frame(minWidth: 64, minHeight: 22)
                .background(manual ? Color(px: "#e8b24a") : Color(px: "#3a2c24"))
                .overlay(Rectangle().strokeBorder(PX.dark, lineWidth: 1))
                .accessibilityLabel(manual ? KE("직접 조작 중", "Manual control") : KE("자동 전투", "Auto battle"))
            let route = pad.skills.filter { $0.order != nil }.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
            HStack(spacing: 3) {
                ForEach(route, id: \.uid) { s in
                    Text("\(s.order ?? 0) \(PadNames.short(s.id, s.name))")
                        .font(PXType.font(PXType.s, bold: true)).lineLimit(1)
                        .foregroundStyle(s.next ? Color(px: "#1a120c") : PX.sub)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(s.next ? Color(px: "#ffd45a") : Color(px: "#3a2c24"))
                }
            }
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button { session.cycleSpeed() } label: {
                Text(String(format: session.speed == session.speed.rounded() ? "%.0f×" : "%g×", session.speed)).font(PXType.font(PXType.s, bold: true))
            }
            .buttonStyle(PixelButton(minWidth: 44, minHeight: 24, sound: false))
            .accessibilityLabel(KE("게임 속도", "Game speed"))
        }
    }
}

/// ◀ ▶ ▼ — 누르는 동안 · 떼면(손가락이 닿고 뗄 때 각각)
struct PadKey: View {
    let label: String, aria: String
    let w: CGFloat, h: CGFloat
    var heavy = false
    let down: () -> Void, up: () -> Void
    @State private var held = false
    var body: some View {
        Text(label).font(PXType.font(label.count > 2 ? PXType.s : PXType.l, bold: true)).foregroundStyle(PX.ink)
            .frame(width: w, height: h)
            .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color(px: "#4a4a55") : heavy ? Color(px: "#7a3a1e") : Color(px: "#2a2a31")))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(heavy ? Color(px: "#ff7a2a") : PX.dark, lineWidth: heavy ? 3 : 2))
            .offset(y: held ? 2 : 0)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !held { held = true; down() } }
                .onEnded { _ in held = false; up() })
            .accessibilityElement().accessibilityLabel(aria).accessibilityAddTraits(.isButton)
            .accessibilityAction { down(); up() }
    }
}

/// 둥근 기술 버튼: 색(계열) · 이름 · 쿨타임 그늘 · 남은 초 · 순서 배지 · 다음 차례 테두리
struct PadSkillButton: View {
    let spec: PadLayout.Btn
    var counter = false
    let fire: () -> Void
    @State private var held = false
    @State private var pulse = false
    var body: some View {
        let d = spec.d
        ZStack {
            Circle().fill(counter ? Color(px: "#c0392b") : spec.color)
            Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
            if spec.cd > 0 { PadPie(fraction: spec.cd).fill(Color.black.opacity(0.62)) }
            VStack(spacing: 0) {
                Text(counter ? KE("받아치기", "Counter") : spec.label)
                    .font(PXType.font(d > 60 ? PXType.m : PXType.s, bold: true)).foregroundStyle(PX.ink)
                    .lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 4)
                if spec.wait > 0.05 && spec.cd > 0 {
                    Text(String(format: "%.1f", spec.wait)).font(PXType.font(PXType.s)).monospacedDigit().foregroundStyle(PX.gold)
                }
            }
            Circle().strokeBorder(PX.dark, lineWidth: 2)
            if spec.next || counter {
                Circle().strokeBorder(counter ? Color(px: "#ff5a3c") : Color(px: "#ffd45a"), lineWidth: 3)
                    .padding(-6).opacity(pulse ? 1 : 0.4)
            }
            if let o = spec.order {
                Text("\(o)").font(PXType.font(PXType.s, bold: true)).foregroundStyle(Color(px: "#1a120c"))
                    .frame(width: 20, height: 20).background(Circle().fill(Color(px: "#ffd45a"))).overlay(Circle().strokeBorder(PX.dark, lineWidth: 1.5))
                    .position(x: 6, y: 6)
            }
        }
        .frame(width: d, height: d)
        .scaleEffect(held ? 0.93 : 1).offset(y: held ? 2 : 0)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !held { held = true; fire() } }
            .onEnded { _ in held = false })
        .onAppear { withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityElement().accessibilityLabel(counter ? KE("받아치기", "Counter") : spec.aria)
        .accessibilityValue(spec.cd > 0 ? KE("\(String(format: "%.1f", spec.wait))초 남음", "\(String(format: "%.1f", spec.wait))s left") : KE("준비됨", "Ready"))
        .accessibilityAddTraits(.isButton).accessibilityAction { fire() }
    }
}

/// 쿨타임 그늘(12시부터 시계 방향으로 남은 몫)
struct PadPie: Shape {
    var fraction: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        p.move(to: c)
        p.addArc(center: c, radius: r.width / 2, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// 작은 필살 단추(패드 왼쪽 아래) — 모으는 게이지 · 준비되면 뜨겁게
struct SpecialMini: View {
    @Bindable var session: GameSession
    let w: CGFloat, h: CGFloat
    var body: some View {
        let hud = session.hud, ready = hud.specialReady, k = max(0, min(1, hud.special / 100))
        Button { session.special() } label: {
            ZStack(alignment: .bottom) {
                if !ready { Rectangle().fill(Color(px: "#7a5ad8").opacity(0.55)).frame(height: (h - 10) * k) }
                VStack(spacing: 0) {
                    Text(tr("필살")).font(PXType.font(PXType.m, bold: true))
                    Text(ready ? KE("탭!", "Tap!") : "\(Int(hud.special))%").font(PXType.font(PXType.s, bold: true))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: w - 8, height: h - 10)
        }
        .buttonStyle(PixelButton(kind: ready ? .hot : .plate, minWidth: w, minHeight: h))
        .accessibilityLabel(KE("필살기", "Special"))
        .accessibilityValue(ready ? KE("준비됨", "Ready") : "\(Int(hud.special))%")
    }
}
