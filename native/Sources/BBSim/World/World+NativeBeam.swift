import Foundation

// 야근 광선(nv_beam — SimConfig.nativeMoves · docs/07 §7-BM). 두 손가락을 안경테에 대고 안경알에서 광선을 내뿜는다(마무리기 · 지속 다단 · 각도).
//  · 칸 신호 bm_set(손가락을 안경에 — 모음 시작: 안경이 차오른다) → 큐 bm_fire(발사: 기본 경로 heroSkill 첫 타 + 광선 시작)
//    → 유지(nvBeamTick: nvBeamTickT 마다 광선에 걸린 적 모두 작게 · 뒤로 민다 · 떠 있으면 받쳐 든다) → 칸 신호 bm_end(끊기 전 마지막 한 방: 큰 피해 · 일직선 날림 rBlast) → 사라짐.
//  · 각도: 큐 순간 대상이 떠 있으면 그 몸통을 향해 위로(최대 nvBeamUp) · 서 있으면 가슴 높이로 거의 수평. 발사 뒤엔 각도를 고정하고 출발점(눈)만 주인공을 따라간다.
//  · 꿰뚫는다: 광선 위의 적 모두 · 무도장 소품도 깬다. 주인공은 반동으로 조금씩 밀린다.
//  · 표현: 스냅숏 beam(SimSnapshot.BeamView) — 무대가 도트 광선 · 광원을 그린다(BBPresentation NativeBeamArt). 소리 · 진동은 칸 신호(actionCue bm_charge · bm_fire).
// 규칙 난수는 쓰지 않는다(첫 타 치명 굴림은 기본 경로 heroSkill 그대로).

/// 광선 상태(규칙)
struct NvBeam {
    enum Phase { case charge, fire, fade }
    var phase: Phase
    /// 단계 안 시간(초)
    var t = 0.0
    /// 방향(주인공이 보는 쪽 ±1) · 각도(라디안 — 0 수평, + 위)
    var f: Double, ang = 0.0
    /// 다단 시계 · 친 횟수 · 아이템 uid · 피해 기준(아이템 피해)
    var tickT = 0.0, ticks = 0
    let uid: Int, dmg: Double
    /// 최근 맞은 자리(표현 — 불꽃)
    var hits: [SIMD2<Double>] = []
}

/// 만화 글자(문구는 여기 한 곳 · 영어는 strings-extra 'native-moves')
public enum NvBeamText {
    /// 발사
    public static let fire = "지이잉!"
    /// 끊기 전 마지막 한 방
    public static let end = "콰지직!"
}

extension World {
    /// 광선 길이(px) · 판정 반폭(px — 몸 가운데까지 거리) · 눈 높이(바닥에서 px)
    static let nvBeamLen = 230.0, nvBeamHW = 18.0, nvBeamEyeY = 46.0
    /// 다단 간격(초) · 다단 피해 배율(아이템 피해 ×) · 마지막 한 방 배율 · 다단 밀어내기(px/s)
    static let nvBeamTickT = 0.07, nvBeamTickK = 0.12, nvBeamEndK = 0.8, nvBeamPush = 110.0
    /// 위로 꺾는 최대 각도(라디안 ≈ 35°) · 아래로(≈ 8°) · 사라지는 시간(초)
    static let nvBeamUp = 0.6, nvBeamDown = 0.14, nvBeamFade = 0.18

    /// 광선 출발점(주인공 눈 — 장면 좌표)
    func nvBeamEye(_ H: Actor) -> SIMD2<Double> { SIMD2(H.x + H.f * 4, H.y - World.nvBeamEyeY - H.airOv) }

    /// useSkill 갈래: 야근 광선
    func nvBeamOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ i: Int, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let st = sStats(i), f = H.f
        opts.cues = [
            // 손가락을 안경테에: 안경이 차오른다(모음)
            "bm_charge": { [unowned self] c in
                visCue("bm_charge")(c)
                self.nvBeam = NvBeam(phase: .charge, f: f, uid: b.uid, dmg: st.dmg)
            },
            // 끊기 전 마지막 한 방(광선 위 모두 · 큰 피해 · 일직선 날림)
            "bm_end": { [unowned self] c in visCue("bm_end")(c); self.nvBeamHits(final: true) },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            // 각도: 떠 있는 대상이면 몸통을 향해 위로 · 서 있으면 가슴 높이로
            let e = self.nvBeamEye(H)
            var ang = 0.0
            if !T.dead, abs(T.x - H.x) > 6 {
                let ty = T.y - 26 - (T.jug?.h ?? 0) - (T.jug == nil ? 14 : 0)   // 서 있으면 어깨 높이(거의 수평)
                ang = atan2(e.y - ty, abs(T.x - H.x))
            }
            var B = self.nvBeam ?? NvBeam(phase: .charge, f: f, uid: b.uid, dmg: st.dmg)
            B.phase = .fire; B.t = 0; B.f = f; B.ang = min(World.nvBeamUp, max(-World.nvBeamDown, ang)); B.tickT = 0
            self.nvBeam = B
            hit?(c)   // 첫 타: 기본 경로(아이템 피해 · 치명 · 연계 · 콤보 집계)
            H.kb = -f * 40   // 반동
            self.comicSFX(e.x + f * 26, e.y - 16, NvBeamText.fire, force: true)
            var k = CameraKick(); k.shake = 2.0; k.zoom = 0.03; k.zoomMode = .add(cap: 0.06); k.focus = e; self.emit(.camera(k))
            self.emit(.haptic(.heavy))
        }
    }

    /// 매 틱(FIGHTING): 모음 → 발사(다단 · 반동) → 사라짐. 주인공이 다른 동작으로 끊기면 바로 사라진다
    func nvBeamTick(_ dt: Double) {
        guard var B = nvBeam else { return }
        B.t += dt
        let H = hero!
        if B.phase != .fade && (H.dead || H.anim != "nv_beam") { B.phase = .fade; B.t = 0 }
        switch B.phase {
        case .charge: break
        case .fire:
            B.tickT += dt
            nvBeam = B
            if B.tickT >= World.nvBeamTickT { nvBeam!.tickT -= World.nvBeamTickT; nvBeamHits(final: false) }
            if H.kb * B.f > -12 { H.kb = -B.f * 12 }   // 버티며 조금씩 밀린다
            return
        case .fade: if B.t >= World.nvBeamFade { nvBeam = nil; return }
        }
        nvBeam = B
    }

    /// 광선 위 적 · 소품을 친다. final = 끊기 전 마지막 한 방
    func nvBeamHits(final: Bool) {
        guard var B = nvBeam, B.phase == .fire, let H = hero else { return }
        let e = nvBeamEye(H), d = SIMD2(B.f * cos(B.ang), -sin(B.ang))
        func onBeam(_ p: SIMD2<Double>, _ hw: Double) -> SIMD2<Double>? {
            let v = p - e, s = v.x * d.x + v.y * d.y
            guard s > 4 && s < World.nvBeamLen else { return nil }
            let n = abs(v.x * d.y - v.y * d.x)
            return n <= hw ? e + d * s : nil
        }
        var hitAny = false
        let hx0 = H.x   // 맞힐 때마다 공격자를 앞으로 미는 기본 규칙(damage — att.x += 2)을 되돌린다: 광선은 반동으로 뒤로만 밀린다
        let L = foes().filter { !$0.dead && !$0.held && !isDown($0) }
        for t in L {
            guard let at = onBeam(SIMD2(t.x, t.y - 30 - (t.jug?.h ?? 0)), World.nvBeamHW) else { continue }
            curSrc = B.uid; var o = HitOpts()
            if final { o.knock = true; o.blast = true } else { o.react = "body" }
            damage(H, t, max(1, jsRound(B.dmg * (final ? World.nvBeamEndK : World.nvBeamTickK))), o); curSrc = nil
            if !final {   // 다단: 경직은 짧게 · 뒤로 민다(떠 있으면 받쳐 든다 — 기본 공중 규칙)
                t.hs = min(t.hs, 1); t.hs0 = max(1, t.hs); t.flash = B.ticks % 3 == 0 ? 1 : 0   // 번쩍임은 세 번에 한 번만(광선 빛에 몸이 하얗게 묻히지 않게)
                if t.jug == nil { t.kb = B.f * World.nvBeamPush }
            }
            B.hits.append(at); hitAny = true
        }
        H.x = hx0
        H.hs = final ? min(H.hs, 2) : 0; H.hs0 = max(1, H.hs)   // 주인공은 버티는 자세를 멈추지 않는다
        if let S = dj {   // 무도장 소품: 광선이 지나가면 깬다
            let gy = H.y
            for (k, o) in S.objs.enumerated() where !o.broken {
                guard let K = DojoObjKind.of(o.kind), let at = onBeam(SIMD2(o.x, gy - K.top / 2), K.top / 2 + 4) else { continue }
                nvObjBreak(k, B.f, comicY: at.y - 24)
            }
        }
        if B.hits.count > 6 { B.hits.removeFirst(B.hits.count - 6) }
        B.ticks += 1
        if final {
            if hitAny {
                comicSFX(e.x + B.f * 60, e.y - 20, NvBeamText.end, force: true)
                slowT = max(slowT, 0.08); shake(3.0); emit(.haptic(.heavy))
                if let C = croute, C.uids.contains(B.uid) { C.hits += 1 }
            }
            B.phase = .fade; B.t = 0
        } else if hitAny { emit(.haptic(.light)) }
        nvBeam = B
    }
}
