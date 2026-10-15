import Foundation
import BBAnim

// 네이티브 잡기 붙이기(SimConfig.nativeMoves — 꺼지면 불리지 않는다 → 웹 30-train-env 의 계단식 자리 그대로). docs/07 §7-T.
// 웹: 잡힌 몸을 주인공 자세마다 정해진 칸으로 순간 이동(잡는 틱 11px 끌려옴 · 들기 20px · 놓는 틱 머리 위 → 30px 앞 바닥 56px),
//     자세도 섞지 않고 바꾼다(prev = pose). 공중 잡기는 높이 40 에서 바로 바닥 높이로.
// 여기서는:
//   · 손에 붙이기 — 주인공이 그린 자세(lastP)의 두 손 가운데에 잡힌 몸의 허리(잡기) · 몸통 가운데(들기)를 맞춘다. 손이 움직이는 만큼만 따라가고(관절 풀이 · 결정적),
//     잡는 순간 · 자세가 바뀌는 순간은 틱마다 0.55 씩 다가가 튀지 않는다. 잡힌 몸 자세는 2칸에 걸쳐 섞는다.
//   · 호 — 메치기(휘두름 칸)는 머리 위에서 앞으로(가로는 먼저 · 세로는 나중에 — 던져 떨어지는 포물선), 수플렉스(젖히기 칸)는 머리 위를 넘어 뒤로,
//     끝점은 놓는 틱의 바닥 자리(규칙이 정하는 x · 누운 자세) — 그래서 놓는 틱에 순간 이동이 없다. 진행은 애니 시계(칸 + acc)라 정지 · 경직 때 멈춘다.
//   · 벽: 잡힌 몸 · 떨어질 자리를 [AW0, AW1] 안으로(웹은 14 ~ sbW−14 — 타워에서는 벽 밖으로 갔다가 다음 틱에 당겨졌다).
//   · 벽꿍(2차): 떨어질 자리가 벽 8px 안 · 밖이면 호가 벽면(높이 22)에서 끝나고 몸이 벽에 붙는다(5틱) → 벽에서 미끄러져 떨어진다(짧은 저글) ·
//     피해 +20% · 벽 자국 · 먼지 · 카메라 · 소리 · 진동. 주인공 발과 겹치지 않게 벽과 40px 안이면 주인공이 뒤로 물러난다.
//   · 무거운 호(2차): 휘두름 · 넘기기 9틱 — 메치기는 천천히 출발해 끝에서 빨라지고(t^1.5), 수플렉스는 꼭대기에서 잠깐 머문다.
//   · 회복(2차): 메치기 · 공중 메치기 · 수플렉스 꽂은 뒤 주인공 경직만 손맛 배율 1.7(1.6) → 1.5(메치기 19 → 17칸) — 맞은 적 누워 있는 시간은 그대로.
//   · 종착역 끌고 가기(2차): 앞손으로 멱살(목 0.95)을 잡아 팔 길이 앞에 · 살짝 들려 발이 끌린다 · 주인공은 뒤로 젖혀 버틴다(nv_spc_haul).
// 규칙 상태는 잡힌 몸의 x · airOv · 자세(보이는 값)만 바꾼다 — 판정 · 피해 · 큐 · 난수는 그대로.

/// 잡힌 몸의 붙이기 상태
struct NvHold {
    var phase = "", p = 0.0   // 단계(grip · lift · arc · drop) · 호 진행(0~1) — drop 이면 떨어지는 속도(px/s)
    var s0 = SIMD2<Double>(0, 0)   // 호 시작 몸통 가운데(장면 좌표)
    /// 벽에 붙어 있는 틱 수(벽꿍 5 · 결재 쌍장은 길게 — 그동안 조금씩 미끄러지고 더 때릴 수 있다)
    var n = 5.0
}

extension World {
    /// 손 위치(장면 좌표) — 주인공이 마지막으로 그린 자세(없으면 키 포즈). lead = 앞손(B)만(종착역 멱살) · back = 뒷손(F)만(내선 연결 수화기), 아니면 두 손 가운데
    func nvGrip(_ H: Actor, lead: Bool = false, back: Bool = false) -> SIMD2<Double> {
        let K = data.animTables.poses[live: H.pose]
        let P = (K?.snap == true ? K : nil) ?? H.lastP ?? K ?? Pose()   // 끊어 들어가는(snap) 자세는 그 틱부터 키 포즈 그대로 그려진다(종착역 꽂기 gr_throw — 화면 정지 동안 손이 앞으로)
        let (j, _) = solveJoints(P, rig: data.heroRig, input: JointInput(tilt: H.tilt, airOv: H.airOv, walkResidual: nil, weaponSprite: nil))
        let m = lead ? j.handB : back ? j.handF : (j.handF + j.handB) / 2
        return SIMD2(H.x + H.f * m.x, H.y + m.y)
    }
    /// 잡힌 몸의 기준점(지역 좌표 · airOv 0): k = 골반 → 목 비율(0.3 허리 · 0.5 몸통 가운데)
    func nvBodyPt(_ a: Actor, pose: String? = nil, k: Double) -> SIMD2<Double> {
        let P = pose.flatMap { data.animTables.poses[live: $0] } ?? drawnPose(a) ?? data.animTables.poses[live: a.pose] ?? Pose()
        let (j, _) = solveJoints(P, rig: data.heroRig, input: JointInput(tilt: a.tilt, airOv: 0, walkResidual: nil, weaponSprite: nil))
        return j.hips + (j.neck - j.hips) * k
    }
    /// 메치기 · 수플렉스가 떨어뜨리는 x(규칙과 호가 같은 값을 쓴다)
    func nvThrowLandX(_ H: Actor, back: Bool, d: Double) -> Double { clamp(H.x + (back ? -1 : 1) * H.f * d, AW0(), AW1()) }
    /// 벽꿍: 떨어질 자리가 벽 8px 안이거나 벽 밖이면 (벽 x, 벽 쪽 방향)
    func nvWallFor(_ H: Actor, back: Bool, d: Double) -> (w: Double, dir: Double)? {
        guard nvGrabTune, nvGrabWall else { return nil }
        let dir = (back ? -1 : 1) * H.f, raw = H.x + dir * d, W = dir > 0 ? AW1() : AW0()
        return (raw - W) * dir > -8 ? (W, dir) : nil
    }
    /// 벽에 붙는 자세(벽을 보고 넘어오면 얼굴로)
    func nvSplatPose(_ a: Actor, dir: Double) -> String { a.f == dir ? "nv_wsplatF" : "nv_wsplat" }
    /// 벽에 붙는 몸통 가운데 자리(장면 좌표)
    func nvWallContact(_ a: Actor, _ wl: (w: Double, dir: Double)) -> SIMD2<Double> { SIMD2(wl.w - wl.dir * 5, a.y - 22) }

    /// 잡힌 몸 자세 바꾸기 — blend 칸에 걸쳐 섞는다(웹은 prev = pose 로 끊어 바꿈)
    func nvHeldPose(_ a: Actor, _ pose: String, blend: Int = 2) {
        guard a.pose != pose else { return }
        a.prev = a.pose; a.pose = pose; a.k = 0; a.phaseN = blend
    }

    /// 호 진행 t → 몸이 간 비율 e. 메치기 = 천천히 출발해 끝에서 빨라짐(t^1.5 — 내리꽂는 가속) ·
    /// 수플렉스 = 머리 위까지 부드럽게 올라(0.33에 0.42) 꼭대기에서 잠깐 머물고(0.33~0.45에 0.42~0.48) 뒤로 빨라짐
    static func nvArcEase(_ t: Double, suplex: Bool) -> Double {
        if !suplex { return pow(t, 1.5) }
        if t < 0.33 { let u = t / 0.33; return 0.42 * (1 - (1 - u) * (1 - u)) }
        if t < 0.45 { return 0.42 + 0.06 * (t - 0.33) / 0.12 }
        let u = (t - 0.45) / 0.55; return 0.48 + 0.52 * pow(u, 1.25)
    }

    /// 매 틱: 잡힌 몸 a 를 주인공 Hh 의 손 · 호에 붙인다. dt = 게임 시간(호 진행) · arcP = 호 진행을 따로 재는 곳(필살기 종착역)이 넘긴다
    func nvHeldPlace(_ a: Actor, _ Hh: Actor, dt: Double = 0, arcP: Double? = nil) {
        let f = Hh.f, fv = -f, sx = Hh.anim == "suplex", drag = Hh.anim == "spcHold" && nvGrabTune
        let p = Hh.pose
        let phase = ["gr_lift", "sx_lift"].contains(p) ? "lift" : (p == "nv_gr_swing" || p == "nv_sx_arch" || p == "sx_arch" || arcP != nil) ? "arc" : "grip"
        var S = a.nvHold ?? NvHold()
        if a.nvHold == nil { a.k = 0; a.phaseN = 2 }   // 잡는 순간: 직전 자세(서기 · 공중)에서 hl0 로 2칸 섞기(enterStep 이 남긴 phaseN 은 1999칸)
        a.flip = !Hh.flip; a.z = Hh.z + 1; a.kb = 0
        if Hh.isHero && Hh.airOv > 0 { Hh.airOv = Hh.airOv < 0.5 ? 0 : Hh.airOv * 0.82 }   // 공중 잡기 깡충(웹 airOv 9 고정) → 잡으며 내려선다
        // 손에 붙일 점: 잡기 = 메치기는 어깨 밑(골반→목 0.9) · 수플렉스는 허리(0.4), 손이 몸 뒤를 감는다 / 들기 = 몸통 가운데가 손바닥 위(머리 위로 떠 주인공 머리와 겹치지 않게 5px)
        // 종착역 끌고 가기 = 앞손에 멱살(0.95) — 팔 길이 앞(손 6px 바깥에 몸통 — 멱살을 쥔 주먹이 가슴 앞) · 2px 들림
        func handTarget(_ ph: String) -> (t: SIMD2<Double>, k: Double) {
            if ph == "grip" && drag { return (nvGrip(Hh, lead: true) + SIMD2(f * 6, -2), 0.95) }
            let g = nvGrip(Hh)
            return ph == "grip" ? (g + SIMD2(-f * 1.5, 0), sx ? 0.4 : 0.9) : (g + SIMD2(0, -5), 0.5)
        }
        if phase == "arc" {
            if S.phase != "arc" { S.p = 0; S.s0 = SIMD2(a.x, a.y - a.airOv) + SIMD2(fv, 1) * nvBodyPt(a, k: 0.5) }
            // 진행: 그 칸이 끝나는 틱(놓는 큐 바로 앞)에 1 — 게임 시간으로 재 정지 · 느린 화면을 따른다
            let dur = Double(max(1, Hh.phaseN)) / animFps
            let t = max(S.p, min(1, arcP ?? (S.p + dt / dur))); S.p = t
            let e = nvGrabTune && arcP == nil ? Self.nvArcEase(t, suplex: sx) : t
            let wall = arcP == nil ? nvWallFor(Hh, back: sx, d: sx ? 24 : 30) : nil
            nvHeldPose(a, e < (sx ? 0.62 : 0.45) ? (sx ? "nv_hl_ov" : "nv_hl_sw") : wall.map { nvSplatPose(a, dir: $0.dir) } ?? "nv_kd3")
            // 끝점: 놓는 틱의 자리(누운 자세의 몸통 가운데) · 벽꿍이면 벽면(높이 22)
            let E: SIMD2<Double>
            if let wall { E = nvWallContact(a, wall) } else {
                let lx = sx ? nvThrowLandX(Hh, back: true, d: 24) : arcP != nil ? clamp(Hh.x + f * 24, AW0(), AW1()) : nvThrowLandX(Hh, back: false, d: 30)
                let kd = nvBodyPt(a, pose: "nv_kd3", k: 0.5); E = SIMD2(lx + fv * kd.x, a.y + kd.y)
            }
            let s0 = S.s0
            var c: SIMD2<Double>
            if sx {   // 수플렉스: 머리 위를 넘어 뒤로 — 가로 고르게(smoothstep) · 세로 볼록
                let u = e * e * (3 - 2 * e)
                c = SIMD2(s0.x + (E.x - s0.x) * u, s0.y + (E.y - s0.y) * pow(e, 1.6) - 16 * sin(.pi * e))
            } else {  // 메치기: 앞으로 먼저 나가고(1−(1−e)²) 나중에 떨어진다(e^1.6) — 던진 포물선
                let ux = 1 - (1 - e) * (1 - e)
                c = SIMD2(s0.x + (E.x - s0.x) * ux, s0.y + (E.y - s0.y) * pow(e, 1.6))
            }
            // 앞부분은 손을 따라간다(손이 놓을 때까지) → 뒤로 갈수록 호
            let w0 = sx ? 0.65 : 0.5, w = min(1, max(0, e / w0)), ww = w * w * (3 - 2 * w)
            let hold = handTarget("lift").t
            c = hold + (c - hold) * ww
            let b = nvBodyPt(a, k: 0.5)
            a.x = clamp(c.x - fv * b.x, AW0() - 2, AW1() + 2); a.airOv = max(0, a.y + b.y - c.y)
        } else {
            if phase == "grip" { nvHeldPose(a, drag ? "nv_hl_drag" : "hl0") }
            else { nvHeldPose(a, sx ? "hl1" : Int((time * 10).rounded(.down)) % 2 == 1 ? "hl1" : "hl1b") }   // 메치기 들기: 버둥거림(웹과 같은 0.1초 번갈아)
            let (tgt, kk) = handTarget(phase)
            let b = nvBodyPt(a, k: kk)
            let wx = clamp(tgt.x - fv * b.x, AW0() - 2, AW1() + 2), wa = max(0, a.y + b.y - tgt.y)
            let k = S.phase == "" ? (a.airOv > 6 ? 0.25 : 0.35) : phase == "lift" ? 0.4 : 0.55   // 잡는 첫 틱(공중이면 더) · 들어 올리기는 조금 천천히(무게)
            let off = a.x - Hh.x; a.x = Hh.x + off + (wx - Hh.x - off) * k; a.airOv += (wa - a.airOv) * k   // 주인공 기준으로 다가간다(끌고 가는 종착역에서 뒤처지지 않게)
        }
        S.phase = phase; a.nvHold = S
    }

    // MARK: 벽꿍

    /// 꽂는 틱(규칙 큐 안 — damage 전): 잡힌 몸을 벽면에 붙인다
    func nvWallPlace(_ T: Actor, _ wl: (w: Double, dir: Double)) {
        let pose = nvSplatPose(T, dir: wl.dir), b = nvBodyPt(T, pose: pose, k: 0.5), C = nvWallContact(T, wl)
        T.x = max(AW0() - 2, min(AW1() + 2, C.x - T.f * b.x)); T.airOv = max(0, T.y + b.y - C.y)
    }
    /// 꽂는 틱(damage 뒤): 벽꿍 연출 · 벽에 붙은 상태(5틱 뒤 미끄러져 떨어진다)
    func nvWallHit(_ T: Actor, _ wl: (w: Double, dir: Double)) {
        let pose = nvSplatPose(T, dir: wl.dir), y = T.y - 22
        T.kb = 0; T.dash = 0; T.dashT = 0
        if !T.dead { T.hs = 0; T.pose = pose; T.prev = pose; T.nvHold = NvHold(phase: "wall", p: 0, s0: SIMD2(wl.w, wl.dir)) }
        else { T.nvHold = NvHold(phase: "drop") }   // 쓰러졌으면 벽 밑으로 떨어지기만
        fx("wallImpact", wl.w, y, wl.dir); fx("spark", wl.w - wl.dir * 2, y - 4); fx("dust", wl.w - wl.dir * 6, T.y, -wl.dir)
        var k = CameraKick(); k.shake = 3.4; k.zoom = 0.05; k.zoomMode = .add(cap: 0.09); emit(.camera(k))
        sfx("thud"); sfx("hitK", 3); emit(.haptic(.heavy))
        comicSFX(wl.w - wl.dir * 22, T.y - 96, "벽꿍!", force: true)
        stats.walls += 1
    }
    /// 벽에 붙은 몸(매 틱 — 잡힘이 풀린 뒤 World+Train): 5틱 붙어 있다가 벽에서 튕겨 미끄러진다(짧은 저글 — 웹 jugHit 'fall' 그대로, 속도만 낮게)
    func nvWallTick(_ a: Actor) {
        guard var S = a.nvHold, S.phase == "wall" else { return }
        if a.jug != nil { a.nvHold = nil; return }   // 붙어 있는 동안 띄우는 기술에 맞으면 벽에서 떨어져 보통 공중 규칙
        let W = S.s0.x, dir = S.s0.y
        S.p += 1; a.kb = 0; a.hs = 0
        let pose = nvSplatPose(a, dir: dir); a.pose = pose; a.prev = pose
        guard S.p >= S.n else {
            if S.n > 5 { a.airOv = max(World.nvStampSlideMin, a.airOv - World.nvStampSlide) }   // 결재 쌍장: 벽을 타고 천천히 미끄러진다
            a.nvHold = S; return
        }
        a.nvHold = nil
        guard let H = hero, !a.dead else { a.nvHold = NvHold(phase: "drop"); return }
        jugHit(a, "fall", -dir, H, HitOpts(), 1)   // 높이 = 지금 airOv(벽면 22)
        if let J = a.jug { J.vx = -dir * 10; J.vy = 150; a.kb = J.vx; a.airOv = 0 }   // 저글의 옆 이동은 kb(웹 jugHit)   // 벽 밑으로(약 6px만 벽에서 떨어져 눕는다)
        fx("dust", W - dir * 4, a.y - 18, -dir)   // 벽에서 떨어지는 먼지(눈 승강장 = 눈가루)
        // 주인공 발과 겹치지 않게: 벽에서 40px 안이면 0.2초에 걸쳐 뒤로 물러난다(벽 밑 16px 에 누운 몸 ±13 + 앞발 8 — 3px 틈)
        let gap = (W - H.x) * dir
        if gap < 40 { H.dash = -dir * (40 - gap) / 0.2; H.dashT = 0.2 }
    }

    // MARK: 회복

    /// 꽂은 뒤 주인공 경직 배율(손맛 1.7 · 1.6 대신)
    static let nvThrowRecK = 1.5
    /// 꽂은 뒤 주인공 경직: 손맛 배율(메치기 1.7 · 수플렉스 1.6) → 1.5(감독안 1.2 는 생존 +12~15pp — 밸런스 측정으로 낮춤) — 맞은 적 경직 · 누운 시간은 그대로
    func nvThrowRecover(_ H: Actor, wall: Bool) {   // wall: 벽꿍(지금은 같은 배율 — 자리만 남김)
        guard nvGrabTune, nvGrabRec, H.hs > 0, let F = data.atkFeel[H.anim], F.hs > 1.2 else { return }
        H.hs = max(1, jsRoundI(Double(H.hs) * Self.nvThrowRecK / F.hs)); H.hs0 = H.hs   // 벽꿍도 같은 배율(벽 8칸으로 줄였을 때 생존 +8pp — 밸런스로 되돌림)
    }
}

extension Sim {
    /// 개발용(앱 -dojomove wall:throw · wall:suplex): 무도장 오른쪽 벽 앞에서 메치기(벽 쪽) · 수플렉스(등 뒤 벽)로 벽꿍 시연
    public func debugDojoWallThrow(_ id: String) {
        guard w.demo, w.nv else { return }
        w.dojoReset(18)
        guard let H = w.hero, let D = w.dojoDummy() else { return }
        let back = id == "suplex", W = w.AW1()
        H.flip = back; H.x = W - 22; D.x = back ? H.x - 18 : H.x + 18; D.flip = !back
        w.bag = [w.dojoItem(id, 9900, t: 99, tier: 2)]
        w.useSkill(0, D, true)
    }
}
