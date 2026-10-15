import Foundation
import BBSim
import BBContent

// 무도장 깊이 · 조명(docs/10 §10) — 네이티브 전용. 깃발 켜짐(HUDCatalog.native) + 무도장에서만, 세기 하나(StageDirector.dojoDepth: 0 꺼짐 = 웹 그대로 · 1 적정).
//  · 원경 흐림 + 대기 안개 · 명도 · 채도: G-버퍼 깊이(gNorm.b)로 먼 층만 — 반 해상도 블러 후 postFS 24단 베이어 앞에서 섞는다(픽셀 DOF)
//  · 인물 림: 합성 패스에서 인물 픽셀의 광원 쪽 바깥 이웃이 비었으면 램프 한 단 올림(+ 눈 승강장은 보조광 둘을 좌우 림 광원으로 — SnowScene)
//  · 눈 바닥: 램프 한 단 내림 · 젖은 바닥 반사(SNOWF 0.16) · 가로등 · 가판대 반사 줄기
//  · 전경 층(ForegroundArt — 화면 크기 캔버스 하나를 통째로 흐림): 눈 = 행인 이벤트 · 건널목 = 억새 · 단풍잎 · 전차 때 경보기 · 무도장 = 기둥 · 줄 · 노렌 이벤트
//  · 건널목 덧: 역광 금빛 림 · 해 반대쪽 긴 그림자 · 렌즈 반짝 · 역광 먼지 · 땅 반짝 · 경보등 붉은빛 / 무도장 덧: 등롱 떨림 · 달빛 창살 · 빛기둥 먼지 · 2색 림 · 마루 반사 줄기
//  · 시간은 게임 시간(s.gameTime)만 — 벽시계 없음(같은 입력 = 같은 그림). 싸움 x 범위(인물 둘레 26px)는 어떤 전경도 가리지 않는다 · 만화 효과 글자 근처는 옅어진다

/// 렌더러에 넘기는 값(StageFrame.depth — 없으면 웹 그대로)
public struct DepthFX: Sendable, Equatable {
    /// 원경: 섞기(0 끔) · 시작 깊이 · 끝 깊이(이 깊이부터 다 흐림) · 안개
    public var farMix = 0.0, farD0 = 0.0, farD1 = 1.0, haze = 0.0
    public var hazeC: [Double] = [0, 0, 0], value = 0.0, desat = 0.0
    /// 원경 블러 반경(반 해상도 px) · 캐시 열쇠(정지 층 + 같은 카메라면 지난 블러를 다시 쓴다 — nil 은 매 프레임)
    public var farBlur = 0.5, farKey: Int? = nil
    /// 원경 흐림에서 뺄 원(장면 x · y · 반지름 — 0 이면 없음): 건널목 해 원판 · 디더 고리
    public var keep: [Double] = [0, 0, 0]
    /// 인물 1px 림(램프 단) · 광원 쪽(-1 왼쪽 · +1 오른쪽) · 반대쪽 세기 · 2색(광원 쪽 색 곱 rgb · 반대쪽 색 곱 rgb — 비면 색 없음)
    public var rimEdge = 0.0, rimSide = 1.0, rimOpp = 0.5, rimTint: [Double] = []
    /// 눈 바닥(SNOWF · SNOWW) 램프 내림 · 젖은 바닥 반사 · 반사 줄기(세기 · 윗선 y · 폭)
    public var floorStep = 0.0, wetSnow = false
    /// 젖은 바닥 반사 재질(강하게 · 약하게 — 비면 그대로): 해변 = 밀려온 물 · 젖은 모래
    public var wetMats: [Double]? = nil
    public var streak = 0.0, streakY = 0.0, streakW = 4.0
    /// 전경 층(미리 곱한 RGBA · 왼쪽 위 장면 자리 · 크기 · 흐림 반경)
    public var fg: [UInt8]? = nil, fgAt: [Double] = [0, 0], fgSize: [Int] = [0, 0], fgBlur = 0.0
    /// 전경 그림 판 번호(같으면 렌더러가 텍스처를 다시 올리지 않는다)
    public var fgVersion = 0
    /// 큰 눈송이 알파 · 시간 · 카메라 x · 보이는 폭
    public var flakes = 0.0, flakeT = 0.0, camX = 0.0, viewW = 0.0
    /// 배경별 덧(렌더러 PostU.EX 8칸 × 4)
    public var ex: [Double] = Array(repeating: 0, count: 32)
    public init() {}
}

/// 무도장 깊이 연출 상태(전경 이벤트) — 시간은 게임 시간
struct DojoDepth {
    /// 이번 행인 이벤트(눈 승강장)
    private struct Pass {
        var t0: Double, kind: PasserKind, dir: Double, startSX: Double, camX0: Double, endDist: Double
        var alpha = 0.0
    }
    private var pass: Pass?, pending: Double?, passN = 0
    private var art: [UInt8]? = nil, artKey: [Double] = []
    private var lastSeq: String?, lastBg: String?, lastPass = -99.0, lastT: Double?
    // 건널목 경보기 · 무도장 기둥 · 노렌
    private var sigT0: Double?, sigOff: Double?, sigSide = 1.0, sigInset = 10.0
    private var pillarW = 0.0, norenT0: Double?, lastNoren = -99.0
    private var canvasKey: [Double] = [], canvas: [UInt8]? = nil, fgVersion = 0
    /// 걷기 속도(장면 px/초 — 카메라 바로 앞이라 화면에선 빠르다) · 처음 붙는 시간 · 한 걸음 바퀴(두 걸음) 길이 · 흐림
    static let speed = 30.0, ease = 0.45, cycle = 52.0, blurR = 2.2, flakeDur = 4.6
    /// 땅 높이(인물 발) · 화면 높이
    static let ground = 222.0, H = 270

    /// 배경별 주 광원 x(인물 림 쪽): 눈 = 가까운 가로등 · 건널목 = 지는 해 · 무도장 = 가까운 붉은 등롱
    static func keyLightX(_ bg: String, cx: Double) -> Double {
        switch bg {
        case "snow": return SnowGeo.lamps.min { abs($0 - cx) < abs($1 - cx) }! + 7
        case "cross": return XC.SUN.0
        case "beach", "beach_dusk", "beach_night": return cx + 50   // 해(달)는 화면 오른쪽 위에 붙어 있다
        default: return [150.0, 330].min { abs($0 - cx) < abs($1 - cx) }!
        }
    }
    static func fighters(_ s: SimSnapshot) -> [SimSnapshot.ActorView] { s.actors.filter { !$0.hidden && ($0.isHero || $0.isEnemy) } }
    static func center(_ s: SimSnapshot, _ view: StageView) -> Double {
        let F = fighters(s); return F.isEmpty ? view.cameraX + view.visibleWidth / 2 : F.reduce(0) { $0 + $1.x } / Double(F.count)
    }
    /// 싸움 x 범위(장면 x — 인물 몸 반폭 14 + 26px 비움) · 인물 정수리 y
    static func fightRange(_ s: SimSnapshot, _ view: StageView) -> (lo: Double, hi: Double, top: Double) {
        let F = fighters(s); guard !F.isEmpty else { let c = view.cameraX + view.visibleWidth / 2; return (c, c, 999) }
        return (F.map(\.x).min()! - 40, F.map(\.x).max()! + 40, F.map(\.y).min()! - 78)
    }
    /// 만화 효과 글자 · 큰 숫자가 떠 있는 장면 자리
    static func comics(_ hud: HUDState) -> [SIMD2<Double>] {
        hud.words.filter { $0.age < $0.life }.map { SIMD2($0.x, $0.y) } + hud.pops.filter { $0.age < $0.life && $0.scale >= 3 }.map { $0.anchor }
    }
    static func comicXs(_ hud: HUDState) -> [Double] { comics(hud).map(\.x) }
    /// 전경 요소가 만화 글자 가까이면 옅게(장면 x · y 범위)
    static func comicFade(_ hud: HUDState, x: Double, y0: Double, y1: Double) -> Double {
        comics(hud).contains { abs($0.x - x) < 52 && $0.y > y0 - 30 && $0.y < y1 + 30 } ? 0.3 : 1
    }

    /// 무도장 장면 값 손보기(장면 구성 뒤 — 깃발 켜짐 · 무도장만): 무도장 = 등롱 떨림 · 빛무리 · 달빛 기둥 / 무도장 블룸
    static func editScene(_ f: inout SceneFrame, bg: String, k: Double, t: Double) {
        guard bg == "dojo" else { return }
        f.post.bloom *= 1 + 0.15 * k
        for j in f.lighting.lights.indices {
            let L = f.lighting.lights[j]
            let fl = 0.6 * sin(t * 7.3 + L.x) + 0.4 * sin(t * 13.1 + L.x * 1.7)   // 결정적 떨림(게임 시간)
            if L.em == true { f.lighting.lights[j].i *= 1 + 0.08 * k * fl }        // 붉은 등롱
            else if L.z == 46 { f.lighting.lights[j].i *= 1 + 0.03 * k * fl }      // 종이 등(안돈)
        }
        for j in f.post.vols.indices {
            let v = f.post.vols[j], fl = 0.6 * sin(t * 7.3 + v.x) + 0.4 * sin(t * 13.1 + v.x * 1.7)
            if v.cone == 2 { f.post.vols[j].halo *= 1 + 0.7 * k; f.post.vols[j].i *= (1 + 0.4 * k) * (1 + 0.08 * k * fl) }   // 등롱 빛무리
            else if v.dx > 0.3 { f.post.vols[j].i *= 1 + 1.0 * k; f.post.vols[j].len *= 1 + 0.25 * k }                      // 장지 달빛 기둥
        }
    }

    /// 이번 프레임 값. k = 세기(0 < k) · t = 게임 시간
    mutating func params(_ s: SimSnapshot, bg: String, k: Double, view: StageView, shake: Double, hud: HUDState, cross: SceneInput.Cross?) -> DepthFX {
        var D = DepthFX()
        let t = s.gameTime, dt = lastT.map { min(0.1, max(0, t - $0)) } ?? 0; lastT = t
        let cx = Self.center(s, view)
        D.rimSide = Self.keyLightX(bg, cx: cx) < cx ? -1 : 1
        let cw = Int(view.visibleWidth.rounded(.up)) + 2, cx0 = view.cameraX.rounded(.down) - 1
        var ops: [(inout FgCanvas) -> Void] = []   // 전경 그리기는 미뤄 둔다(열쇠가 바뀔 때만 실제로 그린다)
        var ckey: [Double] = [cx0, Double(cw)]
        D.fgBlur = Self.blurR
        switch bg {
        case "snow":   // 먼 층 d: 하늘 .99 · 맨해튼 .95~.96 · 퀸즈 .88 · 아파트 .72 · 나무 .6 (먼 내리는 눈 .5 · 승강장 ≤.38 은 또렷)
            D.farMix = k; D.farD0 = 0.55; D.farD1 = 0.9; D.haze = 0.55 * k; D.hazeC = [0.09, 0.12, 0.24]; D.value = 0.1 * k; D.desat = 0.35
            D.farBlur = 0.55
            var h = Hasher()
            for p in [0.0, 0.1, 0.28, 0.55, 0.72] { h.combine(Int(((1 - p) * view.cameraX).rounded())) }
            h.combine(Int((shake * 4).rounded())); D.farKey = h.finalize()
            D.rimEdge = k; D.floorStep = k / 6; D.wetSnow = true; D.streak = 0.22 * k; D.streakY = Double(SnowGeo.groundTop) + 2
            passer(s, k: k, view: view, t: t, dt: dt, hud: hud, ops: &ops, x0: cx0, key: &ckey, into: &D)
        case "cross":
            crossing(s, k: k, view: view, t: t, hud: hud, X: cross, ops: &ops, x0: cx0, key: &ckey, into: &D)
        case "beach", "beach_dusk", "beach_night":
            beach(s, time: BeachTime.of(bg) ?? .day, k: k, view: view, t: t, hud: hud, ops: &ops, x0: cx0, key: &ckey, into: &D)
        default:
            wood(s, k: k, view: view, t: t, dt: dt, hud: hud, ops: &ops, x0: cx0, key: &ckey, into: &D)
        }
        lastBg = bg
        // 전경 캔버스: 같은 열쇠면 지난 것(그림이 바뀔 때만 다시 만든다)
        if ckey.count > 2 {
            if ckey != canvasKey {
                canvasKey = ckey; fgVersion &+= 1
                var C = FgCanvas(w: cw, h: Self.H); for op in ops { op(&C) }
                canvas = C.isEmpty ? nil : C.bytes
            }
            if let c = canvas { D.fg = c; D.fgAt = [cx0, 0]; D.fgSize = [cw, Self.H]; D.fgVersion = fgVersion }
        } else { canvasKey = []; canvas = nil }
        return D
    }

    // MARK: 눈 승강장 — 행인

    /// 시연 시작 · 배경을 눈으로 바꿈 → 싸움에서 먼 가장자리 안쪽에서 바깥으로 걸어 나가는 행인 + 큰 눈송이. 10초에 한 번까지.
    /// 싸움 x 범위는 들어가지 않고, 만화 효과 글자가 그 가장자리에 떠 있으면 다른 쪽 · 둘 다면 2초까지 미룬다. 지나는 중 글자가 가까이 뜨면 옅어진다
    private mutating func passer(_ s: SimSnapshot, k: Double, view: StageView, t now: Double, dt: Double, hud: HUDState,
                                 ops: inout [(inout FgCanvas) -> Void], x0 cx0: Double, key: inout [Double], into D: inout DepthFX) {
        let seq = s.dojo?.seq.map { "\($0.name)|\($0.steps.joined(separator: ","))" }
        let start = (seq != nil && seq != lastSeq) || lastBg != "snow"
        lastSeq = seq
        let x0 = view.cameraX, x1 = view.cameraX + view.visibleWidth
        if start && pass == nil && now - lastPass > 10 { pending = now }
        if let p0 = pending, pass == nil {
            let F = Self.fighters(s)
            let lo = F.map(\.x).min() ?? (x0 + x1) / 2, hi = F.map(\.x).max() ?? (x0 + x1) / 2
            let comics = Self.comicXs(hud)
            func room(_ side: Double) -> Double { side > 0 ? x1 - (hi + 26) : lo - 26 - x0 }
            func clear(_ side: Double) -> Bool { let ex = side > 0 ? x1 : x0; return !comics.contains { abs($0 - (ex - side * 30)) < 60 } }
            let kind = PasserKind(rawValue: passN % PasserKind.allCases.count)!   // 이벤트마다 차례로(결정적)
            let backExt = PasserArt.backExtent(kind)
            let order: [Double] = room(1) >= room(-1) ? [1, -1] : [-1, 1]
            if let side = order.first(where: { room($0) - backExt >= -8 && clear($0) }) {
                let inset = min(36, room(side) - backExt)
                passN += 1
                pass = Pass(t0: now, kind: kind, dir: side, startSX: (side > 0 ? view.visibleWidth : 0) - side * inset, camX0: view.cameraX, endDist: inset + 70)
                lastPass = now; pending = nil
            } else if now - p0 > 2 { pending = nil }
        }
        guard var P = pass else { return }
        let t = now - P.t0
        let dist = Self.speed * (t - Self.ease * (1 - exp(-t / Self.ease)))     // 처음 ease 초 동안 붙는 속도
        let sx = P.startSX + P.dir * dist - 0.6 * (view.cameraX - P.camX0)    // 시차 1.6 — 화면에서 카메라 움직임의 0.6 배 더 밀린다
        let x = view.cameraX + sx
        if dist < P.endDist {
            let near = Self.comicXs(hud).contains { abs($0 - x) < 52 }
            let target = (near ? 0.3 : 0.95) * min(1, k)
            P.alpha += (target - P.alpha) * min(1, dt * (P.alpha < target ? 5 : 9))
            if t < 0.05 { P.alpha = 0 }
            let keyX = SnowGeo.lamps.min { abs($0 - x) < abs($1 - x) }! + 7
            let light = keyX > x ? 1.0 : -1.0, warm = 0.55 + 0.45 * exp(-pow((x - keyX) / 90, 2))
            // 그림은 걸음 한 바퀴 24장 · 펄럭임 1/12초로 끊는다(도트 애니메이션 박자 ≈ 14fps)
            let akey = [Double(P.kind.rawValue), (dist / Self.cycle * 24).rounded(.down), (t * 12).rounded(.down), P.dir, light, (warm * 8).rounded()]
            if akey != artKey {
                artKey = akey
                art = PasserArt.render(P.kind, phase: akey[1] / 24 * 2 * .pi, t: akey[2] / 12, facing: P.dir, light: light, warmK: akey[5] / 8)
            }
            if let a = art {
                let ox = Int(x.rounded()) - PasserArt.footX - Int(cx0), oy = 290 - PasserArt.footY
                let al = P.alpha; ops.append { c in c.blit(a, sw: PasserArt.W, sh: PasserArt.H, ox: ox, oy: oy, alpha: al) }
                key += akey + [Double(ox), (P.alpha * 32).rounded()]
            }
            D.fgBlur = Self.blurR + 1.6 * max(0, 1 - t / 0.5)   // 들어설 때 더 흐렸다가 자리를 잡는다
        }
        let fa = t < 0.4 ? t / 0.4 : t > Self.flakeDur - 1 ? (Self.flakeDur - t) : 1
        D.flakes = max(0, fa) * min(1, k); D.flakeT = now; D.camX = x0; D.viewW = x1 - x0
        pass = t > Self.flakeDur && dist >= P.endDist ? nil : P
    }

    // MARK: 건널목 — 역광 · 억새 · 단풍잎 · 경보기

    private mutating func crossing(_ s: SimSnapshot, k: Double, view: StageView, t: Double, hud: HUDState, X: SceneInput.Cross?,
                                ops: inout [(inout FgCanvas) -> Void], x0 cx0: Double, key: inout [Double], into D: inout DepthFX) {
        // 공기: 하늘 .95 · 구름 .93 · 언덕 .9 만 흐리고 따뜻한 안개(선로 · 전차 · 기둥은 또렷). 해 원판 · 고리는 뺀다
        D.farMix = 0.8 * k; D.farD0 = 0.87; D.farD1 = 0.95; D.haze = 0.4 * k; D.hazeC = [0.5, 0.3, 0.24]; D.desat = 0.12
        D.farBlur = 0.5; D.keep = [XC.SUN.0, XC.SUN.1, 23]
        // 역광: 해 쪽 금빛 림(테가 아니라 한 단 반) · 반대쪽 없음
        let sunVis = CrossGeom.sunK(X?.tr)   // 전차가 해를 가리면 .35
        D.rimEdge = 1.35 * k; D.rimOpp = 0; D.rimTint = [1.18, 1.0, 0.72, 1, 1, 1]
        let R = Self.fightRange(s, view), vx0 = view.cameraX, vw = view.visibleWidth
        // 긴 그림자(땅 y 222 · 높이 1px → 0.45px 아래 · 해 반대쪽 0.35 기울기 · 세기) · 해 · 렌즈 반짝 · 역광 먼지 · 화면 가운데 · 땅 반짝
        let sunIn = max(0, 1 - max(0, max(vx0 - XC.SUN.0, XC.SUN.0 - (vx0 + vw))) / 40)
        D.ex[0] = Self.ground; D.ex[1] = 0.45; D.ex[2] = 0.35; D.ex[3] = 0.55 * k * (0.5 + 0.5 * sunVis)
        D.ex[4] = XC.SUN.0; D.ex[5] = XC.SUN.1; D.ex[6] = 0.9 * k * sunIn * sunVis; D.ex[7] = 0.55 * k
        D.ex[8] = vx0 + vw / 2; D.ex[9] = 135; D.ex[10] = 0.55 * k
        let sun: Double = 1   // 해는 오른쪽(332) — 화면 어디서든 오른쪽 위 뒤
        let qt = (t * 12).rounded(.down) / 12   // 전경 그림 박자 12fps(도트 애니메이션)
        key += [qt, (view.cameraX * 1.4).rounded()]
        // 억새 덤불(시차 1.4 · 화면 아래 가장자리): 덤불마다 키 40~76 · 싸움 x 범위 둘레에선 끝이 발보다 아래(28px)로 낮춘다
        let par = 1.4, sp = 34.0, wx0 = vx0 * par
        for j in Int(floor((wx0 - 40) / sp))...Int(ceil((wx0 + vw + 40) / sp)) {
            let hj = ForegroundArt.h(j, 91)
            guard hj > 0.18 else { continue }                       // 군데군데 빈 자리
            let sxs = Double(j) * sp + (ForegroundArt.h(j, 92) - 0.5) * 16 - wx0   // 화면 x
            let sxScene = vx0 + sxs
            var Hh = 40 + 36 * ForegroundArt.h(j, 93)
            let dist = max(0, max(R.lo - (sxScene + 12), (sxScene - 12) - R.hi))
            if sxScene + 12 > R.lo - 30 && sxScene - 12 < R.hi + 30 { Hh = min(Hh, 28 + (Hh - 28) * min(1, dist / 30)) }
            let fade = Self.comicFade(hud, x: sxScene, y0: 272 - Hh, y1: 272)
            ops.append { c in ForegroundArt.silverGrass(&c, x: sxs - (cx0 - vx0), y: 273, height: Hh, t: qt, seed: j, sun: sun, alpha: 0.97 * min(1, k) * fade) }
        }
        // 가끔 큰 단풍잎(7.5초마다 70% · 4.5초에 걸쳐 화면 위쪽을 가로지른다 — 인물 머리 위로는 지나지 않게 겹치면 사라진다)
        let n = Int(floor(t / 7.5)), u = (t - Double(n) * 7.5) / 4.5
        if u < 1, ForegroundArt.h(n, 95) < 0.7 {
            let dir: Double = n % 2 == 0 ? 1 : -1, hy = ForegroundArt.h(n, 96)
            let lx = dir > 0 ? -20 + (vw + 40) * u : vw + 20 - (vw + 40) * u
            let ly = 34 + hy * 64 + sin(u * 7 + hy * 6) * 9, r = 7 + ForegroundArt.h(n, 97) * 3
            let over = vx0 + lx + r > R.lo && vx0 + lx - r < R.hi && ly + r > R.top - 10
            let a = (over ? 0 : 0.95) * min(1, k) * min(1, u * 8, (1 - u) * 8) * Self.comicFade(hud, x: vx0 + lx, y0: ly - r, y1: ly + r)
            ops.append { c in ForegroundArt.mapleLeaf(&c, cx: lx - (cx0 - vx0), cy: ly, r: r, angle: qt * 2.4 * dir + hy * 6, hue: hy, alpha: a) }
            key += [Double(n), (a * 16).rounded()]
        }
        // 전차가 지날 때(경보 울림 동안): 카메라 앞 건널목 경보기가 한쪽 가장자리로 들어온다 · 붉은 등 둘이 배경 경보등과 같은 박자(2.4Hz)로 번갈아
        let bell = X?.bell == true
        if bell && sigT0 == nil {
            let roomL = R.lo - vx0, roomR = vx0 + vw - R.hi
            sigSide = roomR >= roomL ? 1 : -1
            sigInset = min(16, max(roomL, roomR) - 24)   // 등 팔 반폭 24 가 싸움 범위에 닿지 않게
            sigT0 = t; sigOff = nil
        }
        if !bell, sigT0 != nil, sigOff == nil { sigOff = t }
        if let t0 = sigT0 {
            let inT = min(1, (t - t0) / 0.6), outT = sigOff.map { min(1, (t - $0) / 0.6) } ?? 0
            let e = (1 - pow(1 - inT, 3)) * (1 - outT * outT)
            if sigInset < -14 || outT >= 1 { if outT >= 1 || !bell { sigT0 = nil; sigOff = nil } }
            else {
                let ins = -44 + (sigInset + 44) * e
                let sx = sigSide > 0 ? vw - ins : ins
                let lit = Int(jsMod(jsFloor(t * 2.4), 2))   // 0 왼쪽 · 1 오른쪽(배경 경보등 i=0 과 같은 박자)
                let fade = Self.comicFade(hud, x: vx0 + sx, y0: 30, y1: 270)
                ops.append { c in ForegroundArt.crossingSignal(&c, x: sx - (cx0 - vx0), lit: lit, sun: sun, alpha: min(1, k) * fade) }
                key += [sx.rounded(), Double(lit), (fade * 4).rounded()]
                // 붉은빛: 켜진 등 자리 · 세기 · 반경(인물 등 쪽 면 · 땅)
                D.ex[12] = vx0 + sx + (lit == 0 ? -14 : 14); D.ex[13] = 102; D.ex[14] = 0.9 * k * e; D.ex[15] = 170
            }
        }
    }

    // MARK: 해변 — 공기 원근 · 해 쪽 림 · 젖은 바닥 반사 · 긴 그림자 · 모래 반짝 · 바닷풀

    private mutating func beach(_ s: SimSnapshot, time tm: BeachTime, k: Double, view: StageView, t: Double, hud: HUDState,
                                ops: inout [(inout FgCanvas) -> Void], x0 cx0: Double, key: inout [Double], into D: inout DepthFX) {
        let sun = BeachGeo.sun(tm), sx = view.cameraX + sun.x
        // 공기: 하늘 .99 · 먼 해안 .96 · 바다(수평선 .95 → 물가 .4)만 흐리고 시간대 안개 — 해 · 달 원판은 뺀다(또렷하게)
        D.farMix = 0.8 * k; D.farD0 = 0.62; D.farD1 = 0.97; D.farBlur = 0.5; D.keep = [sx, sun.y, sun.r + 3]
        switch tm {
        case .day:
            D.haze = 0.1 * k; D.hazeC = [0.66, 0.78, 0.92]; D.desat = 0.04; D.farMix = 0.55 * k
            D.rimEdge = 0.8 * k; D.rimOpp = 0.3; D.rimTint = [1.1, 1.03, 0.9, 0.9, 0.96, 1.12]
        case .dusk:
            D.haze = 0.32 * k; D.hazeC = [0.66, 0.38, 0.36]; D.desat = 0.05
            D.rimEdge = 1.4 * k; D.rimOpp = 0; D.rimTint = [1.2, 1.0, 0.7, 1, 1, 1]   // 역광 금빛 테
        case .night:
            D.haze = 0.42 * k; D.hazeC = [0.06, 0.09, 0.18]; D.desat = 0.3; D.value = 0.05 * k
            D.rimEdge = 0.9 * k; D.rimOpp = 0.5; D.rimTint = [0.86, 0.94, 1.2, 1.15, 0.95, 0.8]   // 달 쪽 차갑게 · 감시탑 등 쪽 따뜻하게
        }
        D.rimSide = sx < Self.center(s, view) ? -1 : 1
        D.wetMats = [Double(NativePalette.SHEET), Double(NativePalette.SANDW)]
        // 긴 그림자(해 반대쪽 — 오후는 짧게 · 노을은 길게 · 밤은 달 그림자 옅게) · 해 x · 렌즈 반짝(노을만) · 모래 반짝(오후 · 노을)
        let shadow: (Double, Double, Double) = tm == .day ? (0.22, 0.12, 0.38) : tm == .dusk ? (0.5, 0.62, 0.55) : (0.3, 0.2, 0.18)
        D.ex[0] = Self.ground; D.ex[1] = shadow.0; D.ex[2] = shadow.1; D.ex[3] = shadow.2 * k
        D.ex[4] = sx; D.ex[5] = sun.y; D.ex[6] = tm == .dusk ? 0.42 * k : 0; D.ex[7] = 0
        D.ex[8] = view.cameraX + view.visibleWidth / 2; D.ex[9] = 135; D.ex[10] = (tm == .day ? 0.55 : tm == .dusk ? 0.4 : 0) * k
        // 전경: 카메라 앞 모래 둔덕의 바닷풀(아래 가장자리 · 싸움 x 범위 둘레는 낮춘다 · 시간대 색)
        let R = Self.fightRange(s, view), vx0 = view.cameraX, vw = view.visibleWidth
        let qt = (t * 12).rounded(.down) / 12
        key += [qt, (view.cameraX * 1.35).rounded(), Double(tm.rawValue)]
        let par = 1.35, sp = 30.0, wx0 = vx0 * par
        for j in Int(floor((wx0 - 40) / sp))...Int(ceil((wx0 + vw + 40) / sp)) {
            guard ForegroundArt.h(j, 191) > 0.3 else { continue }
            let sxs = Double(j) * sp + (ForegroundArt.h(j, 192) - 0.5) * 14 - wx0, sxScene = vx0 + sxs
            var Hh = 22 + 26 * ForegroundArt.h(j, 193)
            let dist = max(0, max(R.lo - (sxScene + 10), (sxScene - 10) - R.hi))
            if sxScene + 10 > R.lo - 30 && sxScene - 10 < R.hi + 30 { Hh = min(Hh, 14 + (Hh - 14) * min(1, dist / 30)) }
            let fade = Self.comicFade(hud, x: sxScene, y0: 272 - Hh, y1: 272)
            ops.append { c in ForegroundArt.duneGrass(&c, x: sxs - (cx0 - vx0), y: 274, height: Hh, t: qt, seed: j, time: tm.rawValue, alpha: 0.97 * min(1, k) * fade) }
        }
    }

    // MARK: 무도장 — 등롱 · 달빛 · 기둥 · 줄 · 노렌

    private mutating func wood(_ s: SimSnapshot, k: Double, view: StageView, t: Double, dt: Double, hud: HUDState,
                               ops: inout [(inout FgCanvas) -> Void], x0 cx0: Double, key: inout [Double], into D: inout DepthFX) {
        // 실내라 흐림은 얕게: 창 밖 거리(.9) · 창 밖 행인(.6)만
        D.farMix = 0.6 * k; D.farD0 = 0.5; D.farD1 = 0.62; D.haze = 0.2 * k; D.hazeC = [0.1, 0.12, 0.2]; D.value = 0.05 * k; D.desat = 0.2
        D.farBlur = 0.5
        // 2색 림: 등롱 쪽 따뜻하게 · 창(달빛) 쪽 차갑게
        D.rimEdge = 1.0 * k; D.rimOpp = 0.6; D.rimTint = [1.12, 0.96, 0.8, 0.82, 0.92, 1.22]
        // 마루 반사 줄기(등롱 · 안돈 빛이 니스 칠한 마루에 길게 — 깊이 띠 .25~.35 · 마루 윗선 223)
        D.streak = 0.16 * k; D.streakY = Self.ground + 1; D.streakW = 3; D.ex[20] = 1; D.ex[21] = 0.25; D.ex[22] = 0.35
        // 달빛: 바닥 창살 자리 · 빛기둥 먼지 · 바닥 y · 창살 칸 / 창 x 범위 / 창 y · 빛 방향
        D.ex[16] = 0.11 * k; D.ex[17] = 0.4 * k; D.ex[18] = Self.ground; D.ex[19] = 10
        D.ex[24] = DJ_WIN[0].0; D.ex[25] = DJ_WIN[0].1; D.ex[26] = DJ_WIN[1].0; D.ex[27] = DJ_WIN[1].1
        D.ex[28] = 150; D.ex[29] = 197; D.ex[30] = 0.36; D.ex[31] = 0.93
        let R = Self.fightRange(s, view), vx0 = view.cameraX, vw = view.visibleWidth
        let qt = (t * 12).rounded(.down) / 12
        // 기둥(왼쪽 가장자리 · 보이는 폭 14 — 싸움이 가까이 오면 가늘어진다 · 게임 시간으로 부드럽게)
        let roomL = R.lo - vx0
        let wTarget = max(0, min(14, roomL))
        pillarW += (wTarget - pillarW) * min(1, dt * 4)
        let pw = Int(pillarW.rounded())
        let warmSide: Double = Self.keyLightX("dojo", cx: vx0 + 7) < vx0 + 7 ? -1 : 1
        ops.append { c in ForegroundArt.pillar(&c, side: -1, width: pw > 0 ? pw + Int(vx0 - cx0) : 0, warmSide: warmSide, alpha: min(1, k)) }
        // 매달린 줄(기둥 안쪽 · 위에서 104px · 아주 느린 흔들림): 싸움이 높이 떠서 닿으면 옅게
        let ropeX = Double(pw) + 12, swing = 0.035 * sin(qt * 0.6)
        let ropeOver = vx0 + ropeX + 4 > R.lo && R.top < 125
        let ra = (ropeOver ? 0.15 : 0.95) * min(1, k) * Self.comicFade(hud, x: vx0 + ropeX, y0: 0, y1: 114)
        ops.append { c in ForegroundArt.rope(&c, x: ropeX + (vx0 - cx0), length: 104, swing: swing, alpha: ra) }
        key += [Double(pw), (ra * 8).rounded(), (sin(swing) * 104 * 2).rounded()]   // 줄은 끝이 반 픽셀 움직일 때만 다시
        // 노렌(이벤트: 시연 시작 — 8초에 한 번 · 위 가장자리 가운데): 누가 지나간 듯 아래로 흔들려 들어왔다가 잦아든다
        let seq = s.dojo?.seq.map { "\($0.name)|\($0.steps.joined(separator: ","))" }
        if seq != nil && seq != lastSeq && t - lastNoren > 8 { norenT0 = t; lastNoren = t }
        if lastBg != "dojo" && t - lastNoren > 8 { norenT0 = t; lastNoren = t }
        lastSeq = seq
        if let t0 = norenT0 {
            let u = t - t0
            if u > 4.2 { norenT0 = nil }
            else {
                let drop = 34 * (1 - exp(-u / 0.22)) * (u < 2.4 ? 1 : exp(-(u - 2.4) / 0.5))
                let sw = 8 * exp(-u / 1.4)
                let nx = vw * 0.5 - 22   // 위 가운데(오른쪽 위는 일시정지 · 연타 수 HUD 자리)
                let over = vx0 + nx < R.hi && vx0 + nx + 64 > R.lo && R.top < drop + 10
                let a = (over ? 0.2 : 0.97) * min(1, k) * Self.comicFade(hud, x: vx0 + nx + 32, y0: 0, y1: drop)
                ops.append { c in ForegroundArt.noren(&c, x: nx + (vx0 - cx0), drop: drop, sway: sw, t: qt, alpha: a) }
                key += [qt, drop.rounded(), (sw * 2).rounded(), (a * 8).rounded()]
            }
        }
    }
}
