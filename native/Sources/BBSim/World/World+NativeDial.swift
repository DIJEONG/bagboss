import Foundation
import BBAnim

// 내선 연결(nv_dial — SimConfig.nativeMoves · docs/07 §7-PH). 유선 전화 수화기를 던져 멀리 있는 적 · 날아가는 적 · 벽에 박힌 적을 끌어온다(MK 스콜피온 창 참고).
//  · 칸 신호 ph_set(수화기를 귀 뒤로 — 선 상태 시작) → ph_throw(던짐: 수화기가 손을 떠나 대상 몸통으로 날아간다 · 꼬인 선이 펴진다)
//    → 큐 ph_catch(닿는 순간: 기본 경로 heroSkill — 작은 피해 · 반응 hit) → 맞았으면 끌어온다(nvDialPull초 · 주인공 앞 nvDialGap px):
//      서 있는 적 = 살짝 떠서 끌려온다(발끝이 끌리는 먼지) · 떠 있는 적 = 저글을 풀고 그 높이에서 일직선으로 끌어 내린다 · 벽에 박힌 적 = 벽에서 떼어 낸다
//      → 도착하면 끌림(pulled — 콤보 상태 P) + 경직 nvDialStun → 어퍼컷 등으로 잇는다.
//    두목은 끌려오지 않고 주인공이 끌려간다(거리 좁히기). 빗나가거나 막히면 선이 튕겨 돌아온다(헛손질 — 동작은 그대로 끝까지).
//  · 표현: 스냅숏 cord(SimSnapshot.CordView) — 무대가 꼬인 전화선 · 수화기를 그린다(BBPresentation NativeCordArt). 끌어온 만큼 발밑에 선이 감겨 쌓인다.
// 규칙 난수는 쓰지 않는다(치명 굴림은 기본 경로 heroSkill 그대로).

/// 전화선 상태(규칙)
struct NvCord {
    enum Phase { case hold, fly, pull, reel, stow }
    var phase: Phase = .hold
    /// 단계 안 시간(초)
    var t = 0.0
    /// 대상 · 끌기 시작 x · 시작 높이(airOv) · 끌기 시간(초) · 두목이면 주인공이 끌려간다
    weak var T: Actor?
    var x0 = 0.0, h0 = 0.0, dur = 0.2, rev = false
    /// 수화기 자리(장면 좌표 — 날아가는 동안 · 돌아오는 동안) · 끌어온 거리(px — 발밑에 감기는 양)
    var tip = SIMD2<Double>(0, 0), reelFrom = SIMD2<Double>(0, 0), hauled = 0.0
    /// 겨눈 점(장면 좌표 — 매 틱 실제 몸 닿는 점을 부드럽게 따라간다 · 대상이 없으면 던진 순간 값 그대로)
    var aim = SIMD2<Double>(0, 0)
    /// 걸린 뒤 수화기 자리 = 몸 가운데 + 이 어긋남(px — 몸 이동은 그대로 따르고, 자세가 바뀌어 닿는 점이 옮겨 갈 때만 부드럽게 따라간다)
    var off = SIMD2<Double>(0, 0)
}

/// 대상 몸(그려진 관절에서 — 발끝 ~ 머리 상자): 장면 좌표 가운데 · 반폭 · 반높이 · 바라보는 방향
struct NvBody {
    var c: SIMD2<Double>, a: Double, b: Double, f: Double
    /// 장면 좌표 → 몸 상자 기준 비율
    func rel(_ p: SIMD2<Double>) -> SIMD2<Double> { SIMD2((p.x - c.x) * f / a, (p.y - c.y) / b) }
}

/// 만화 글자(문구는 여기 한 곳 · 영어는 strings-extra 'native-moves')
public enum NvDialText {
    /// 수화기가 머리에 닿는 순간 · 끌어오는 순간
    public static let ring = "따르릉!", come = "이리 와!"
}

extension World {
    /// 날아가는 시간(던짐 칸 50ms + 뻗은 칸 150ms — 큐 순간에 닿는다) · 끌기 시간(초 — 무거운 적은 nvDialPullHeavy) · 주인공 앞 도착 거리(px)
    static let nvDialFly = 0.2, nvDialPull = 0.17, nvDialPullHeavy = 0.24, nvDialGap = 18.0
    /// 끌기 2박자(감독 자세표 Yanking → Pulling hard): 버티는 동안(초) 대상은 이만큼(거리 비율)만 움찔 끌려오고 → 끌어당김 칸에서 확 끌려온다
    static let nvDialTense = 0.15, nvDialTenseK = 0.08
    /// 걸린 순간 경직 상한(칸 — 20fps · 0.1초): 길면 끌어당김 자세(ph_haul)보다 끌려오는 몸이 늦는다
    static let nvDialHs = 2
    /// 수화기가 붙는 자리: 날아오는 직선이 몸 상자(타원)에 들어가는 점에서 가운데 쪽으로 이만큼 파고든다(비율) · 겨눈 점이 실제 몸을 따라가는 빠르기(1/초)
    static let nvDialSink = 0.35, nvDialTrack = 30.0
    /// 도착 뒤 경직(초) · 서 있는 적이 끌려오며 뜨는 높이(px) · 두목에게 끌려갈 때 남기는 거리(px) · 선이 돌아오는 시간(초)
    static let nvDialStun = 0.6, nvDialLift = 7.0, nvDialBossGap = 22.0, nvDialReel = 0.25

    /// 방금 끌려와 비틀거리는 적인가(끌림 동작 중 · 도착 뒤 경직 창 안)
    func nvJustPulled(_ T: Actor) -> Bool {
        T.anim == "pulled" || (nvDialLast.map { $0.id == T.id && time - $0.t < World.nvDialStun + 0.2 } ?? false)
    }
    /// 수화기를 쥔 손(뒷손 F — 화면 쪽) 자리
    func nvDialHand(_ H: Actor) -> SIMD2<Double> { nvGrip(H, back: true) }
    /// 대상 몸(docs/07 §7-PH 겨눔 — 2026-10-14 감독 제안): 지금 그려진 자세의 관절(머리 끝 · 목 · 골반 · 무릎 · 발)을 풀어 상자를 잡는다.
    /// 서 있음 · 누움 · 넘어지는 중 · 떠서 구름(roll — 그리기와 같은 축으로 돌린다) · 벽에 박힘 어느 자세든 상태별 높이 값 없이 맞는다.
    func nvDialBody(_ T: Actor) -> NvBody {
        let keep = T.drawState   // 그리기 보간 상태는 건드리지 않는다(규칙에서 한 번 더 풀 뿐)
        let P = drawnPose(T) ?? data.animTables.poses[live: T.pose] ?? Pose()
        T.drawState = keep
        let (j, _) = solveJoints(P, rig: data.heroRig, input: JointInput(tilt: T.tilt, airOv: T.airOv, walkResidual: nil, weaponSprite: nil))
        var pts = [j.head + V2(0, -5), j.neck, j.hips, j.kneeF, j.kneeB, j.footF, j.footB]
        if let r = P.roll, r != 0 {   // 몸 전체 구름(RigMesh BodyRoll 과 같은 축 · 같은 방향)
            let A = r * 2 * .pi, c = cos(A), sn = sin(A), px = (j.hips.x + j.neck.x) / 2, py = (j.hips.y + j.neck.y) / 2
            pts = pts.map { let dx = $0.x - px, dy = $0.y - py; return V2(px + dx * c - dy * sn, py + dx * sn + dy * c) }
        }
        let x0 = pts.map(\.x).min()!, x1 = pts.map(\.x).max()!, y0 = pts.map(\.y).min()!, y1 = pts.map(\.y).max()!
        return NvBody(c: SIMD2(T.x + T.f * (x0 + x1) / 2, T.y + (y0 + y1) / 2), a: max(4, (x1 - x0) / 2), b: max(4, (y1 - y0) / 2), f: T.f)
    }
    /// 몸 가운데(장면 좌표 — 만화 글자 · 카메라 기준)
    func nvDialAim(_ T: Actor) -> SIMD2<Double> { nvDialBody(T).c }
    /// 수화기가 닿는 점: from → 몸 가운데 직선이 몸 상자(타원)에 들어가는 점에서 조금 파고든 자리(주인공 쪽 가장자리 — 등 뒤로 감기지 않는다)
    func nvDialContact(_ B: NvBody, from: SIMD2<Double>) -> SIMD2<Double> {
        let v = B.c - from, L = (v.x * v.x + v.y * v.y).squareRoot()
        guard L > 1 else { return B.c }
        let u = v / L, t = 1 / ((u.x / B.a) * (u.x / B.a) + (u.y / B.b) * (u.y / B.b)).squareRoot()
        return B.c - u * min(L, t) * (1 - World.nvDialSink)
    }

    /// useSkill 갈래: 내선 연결
    func nvDialOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let f = H.f
        opts.cues = [
            // 장전: 수화기를 귀 뒤로(선 상태 시작 — 수화기는 손에)
            "ph_set": { [unowned self] c in
                visCue("ph_set")(c)
                self.nvCord = NvCord(T: T, tip: self.nvDialHand(H))
            },
            // 던짐: 수화기가 손을 떠난다 · 앞발 먼지
            "ph_throw": { [unowned self] c in
                visCue("ph_throw")(c); self.fx("dust", H.x + f * 6, H.y, f)
                if self.nvCord == nil { self.nvCord = NvCord(T: T, tip: self.nvDialHand(H)) }
                self.nvCord!.phase = .fly; self.nvCord!.t = 0
                let from = self.nvDialHand(H)
                if T.dead { self.nvCord!.T = nil; self.nvCord!.aim = from + SIMD2(f * 120, 0) }
                else { self.nvCord!.T = T; self.nvCord!.aim = self.nvDialContact(self.nvDialBody(T), from: from) }
                self.sfx("swing")
            },
            // 끌어당김(Pulling hard): 끌려오는 동안 발밑 먼지
            "ph_haul": { [unowned self] c in
                visCue("ph_haul")(c)
                if let C = self.nvCord, C.phase == .pull, !C.rev { self.fx("dust", H.x - f * 4, H.y, -f) }
            },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let hp0 = T.e?.hp
            hit?(c)   // 기본 경로(아이템 피해 · 치명 · 연계 · 콤보 집계 — 사거리 안 가장 가까운 적)
            let landed = (T.e?.hp ?? 0) < (hp0 ?? 0)
            guard landed, !T.dead else { self.nvDialMiss(H); return }
            self.nvDialCatch(H, T)
        }
    }

    /// 걸렸다: 끌기 시작(두목이면 주인공이 끌려간다)
    func nvDialCatch(_ H: Actor, _ T: Actor) {
        let f = H.f, isBoss = T.e?.boss == true
        var C = nvCord ?? NvCord()
        C.phase = .pull; C.t = 0; C.T = T; C.hauled = 0
        if isBoss {
            C.rev = true; C.x0 = H.x; C.dur = World.nvDialPull
            let dd = max(0, abs(T.x - H.x) - World.nvDialBossGap)
            if dd > 0 { H.dash = f * dd / C.dur; H.dashT = C.dur }
        } else {
            // 붙잡힌 모든 상태를 풀고 서 있는 끌림으로(떠 있으면 그 높이 · 벽에 박혀 있으면 벽 높이에서)
            let h = max(T.airOv, T.jug?.h ?? 0)
            if T.jug != nil { T.jug = nil }
            T.nvHold = nil; T.spike = nil
            T.airOv = h; T.kb = 0; T.dash = 0; T.dashT = 0
            T.action = nil; T.queue = []; setAnim(T, "pulled"); face(T, H.x)
            C.rev = false; C.x0 = T.x; C.h0 = h
            C.dur = T.e?.heavy == true ? World.nvDialPullHeavy : World.nvDialPull
            if let e = T.e { e.stun = max(e.stun, C.dur + World.nvDialStun) }
        }
        // 건다: 끌림 자세로 바뀐 몸(같은 틱에 그려지는 몸)의 주인공 쪽 가장자리 — 이후 몸 가운데와의 어긋남으로 붙여 둔다(nvDialTick)
        let B = nvDialBody(T)
        C.aim = nvDialContact(B, from: nvDialHand(H)); C.off = C.aim - B.c; C.tip = C.aim
        nvCord = C
        H.hs = min(H.hs, World.nvDialHs); H.hs0 = max(1, H.hs); T.hs = min(T.hs, World.nvDialHs); T.hs0 = max(1, T.hs)
        T.flash = 0   // 몸 전체 흰 번쩍임 대신 수화기 자리 흰 살(NativeCordArt)
        let a = nvDialAim(T)
        comicSFX(a.x, a.y - 44, NvDialText.ring, force: true)
        comicSFX(H.x + f * 10, H.y - 92, NvDialText.come, force: true)
        var k = CameraKick(); k.shake = 1.6; k.zoom = 0.03; k.zoomMode = .add(cap: 0.06); k.focus = SIMD2((H.x + T.x) / 2, H.y - 40); emit(.camera(k))
        sfx("clack"); emit(.haptic(.medium))
    }

    /// 빗나감 · 막힘: 선이 튕겨 돌아온다
    func nvDialMiss(_ H: Actor) {
        guard var C = nvCord else { return }
        C.phase = .reel; C.t = 0; C.reelFrom = C.tip
        nvCord = C
    }

    /// 매 틱(FIGHTING · 무도장): 날아감 → 끌기 → 감기 → 손에 → 동작이 끝나면 사라진다
    func nvDialTick(_ dt: Double) {
        guard var C = nvCord, let H = hero else { return }
        if H.dead || H.anim != "nv_dial" { nvDialRelease(); return }
        let hand = nvDialHand(H)
        if H.hs > 0 && C.phase != .reel {   // 경직(히트스톱) 동안 멈춘다 — 걸려 있으면 몸에 붙은 채(몸이 바뀌면 함께)
            if C.phase == .hold || C.phase == .stow { C.tip = hand }
            if C.phase == .pull, let T = C.T, !T.dead { C.tip = nvDialBody(T).c + C.off }
            nvCord = C; return
        }   // 경직(히트스톱) 동안 멈춘다
        C.t += dt
        switch C.phase {
        case .hold, .stow:
            C.tip = hand
        case .fly:
            // 매 틱 다시 긋는 직선: 수화기는 늘 '지금 손 → 지금 몸 닿는 점' 선분 위 진행률 k 자리 → 선은 언제나 곧고(휘지 않는다)
            // k 는 같은 빠르기로 큐 순간에 1 → 판정 순간 정확히 몸에 닿는다(예측 · 순간이동 없음). 겨눈 점은 실제 몸을 부드럽게 따라가 선이 떨리지 않는다.
            let k = min(1, C.t / World.nvDialFly)
            if let T = C.T, !T.dead {
                let want = nvDialContact(nvDialBody(T), from: hand)
                C.aim += (want - C.aim) * (k >= 1 ? 1 : 1 - exp(-World.nvDialTrack * dt))
            }
            C.tip = hand + (C.aim - hand) * k
        case .pull:
            guard let T = C.T, !T.dead else { C.phase = .reel; C.t = 0; C.reelFrom = C.tip; break }
            // 2박자: 버팀(움찔 — 조금만) → 끌어당김(빠르게 출발해 감속하며 도착)
            let tt = World.nvDialTense, total = tt + C.dur
            let k = min(1, C.t / total)
            let e = C.t < tt ? World.nvDialTenseK * sin(.pi / 2 * C.t / tt)
                             : World.nvDialTenseK + (1 - World.nvDialTenseK) * (1 - pow(1 - min(1, (C.t - tt) / C.dur), 2.2))
            if C.rev {
                C.hauled = abs(H.x - C.x0)
            } else {
                let tx = H.x + H.f * World.nvDialGap
                let x = C.x0 + (tx - C.x0) * e
                C.hauled = abs(x - C.x0)
                T.x = x; T.kb = 0; T.dash = 0; T.dashT = 0
                // 높이: 시작 높이 → 바닥으로 내려오며 · 서 있던 적은 살짝 떴다 내려앉는다(발끝이 끌린다)
                T.airOv = C.h0 * (1 - e) + World.nvDialLift * sin(.pi * max(0, (C.t - tt) / C.dur)) * (C.h0 > 12 ? 0 : 1)   // 떠 있던 적은 일직선으로(뜨지 않는다)
                if Int(C.t * 30) != Int((C.t - dt) * 30) && T.airOv < 4 { fx("dust", T.x, T.y, -H.f) }
                if T.anim != "pulled" && !isDown(T) { setAnim(T, "pulled") }
            }
            // 몸에 붙어 따라온다: 몸 가운데는 그대로 따르고(끌려오는 빠르기에 뒤처지지 않는다) · 닿는 점(주인공 쪽 가장자리)이 자세 따라 옮겨 가면 어긋남만 부드럽게
            let B = nvDialBody(T)
            C.off += (nvDialContact(B, from: hand) - B.c - C.off) * (1 - exp(-World.nvDialTrack * dt))
            C.tip = B.c + C.off
            if k >= 1 {
                if !C.rev {
                    T.airOv = 0; T.x = H.x + H.f * World.nvDialGap
                    if let e = T.e { e.stun = max(e.stun, World.nvDialStun) }
                    fx("dust", T.x, T.y, H.f); nvDialLast = (T.id, time)
                }
                C.phase = .stow; C.t = 0
            }
        case .reel:
            // 튕겨 돌아온다(처지며)
            let k = min(1, C.t / World.nvDialReel), e = k * k
            C.tip = C.reelFrom + (hand - C.reelFrom) * e + SIMD2(0, 10 * sin(.pi * k))
            if k >= 1 { C.phase = .stow; C.t = 0 }
        }
        nvCord = C
    }

    /// 동작이 끊기거나 끝났다: 끌던 몸은 그 자리에 내려놓는다
    func nvDialRelease() {
        if let C = nvCord, C.phase == .pull, !C.rev, let T = C.T, !T.dead { T.airOv = 0 }
        nvCord = nil
    }
}
