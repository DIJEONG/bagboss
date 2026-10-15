import Foundation

// 직장인 세 기술(SimConfig.nativeMoves — 깃발이 꺼지면 이 동작 · 아이템이 없어 이 파일은 불리지 않는다 → 웹 그대로). docs/07 §7-OF.
// 우리 인물 비율(큰 머리 · 큰 상체 · 짧은 다리)이 작은 화면에서도 읽히게 — 몸 전체 · 머리 · 상대가 크게 움직이는 것으로 보여 준다.
//  · 서류가방 내려찍기(nv_slam · 이음기 *→A): 칸 신호 cs_jump(상대 앞으로 뛰어든다) → 큐 cs_hit(기본 경로 heroSkill — 반응 launch)
//    → 맞은 몸을 바닥으로 내리꽂는다(떠 있으면 빠르게) → 바닥 튕김(기존 gbReady 규칙 — 더 높이 nvSlamBounceV · 충격파 고리) → 다시 공중 콤보.
//    가방이 터지며 서류가 흩날린다(표현 fx 'nv_slam'). 칸 신호 cs_land 착지 먼지.
//  · 결재 쌍장(nv_stamp · 마무리기 *→K): 칸 신호 ss_step(크게 미끄러져 들어감) → 큐 ss_hit(기본 경로 — 반응 rBlast)
//    → 낮고 곧게 길게 날아간다(중력 nvStampG · 가로 감쇠 nvStampKeep) → 벽(객차 끝 · 무도장 벽)에 닿으면 박힌다(기존 벽꿍 — 붙어 있는 시간 nvStampStick 틱 ·
//    천천히 미끄러짐 · 그동안 더 칠 수 있다) → 떨어져 눕는다. 맞은 자리 결재 도장(fx 'nv_stamp') · 벽에 남는 도장(fx 'nv_stampWall').
//  · 멱살 박치기(nv_headbutt · 시작기 G→Z · 잡기 — 가드 무시): 칸 신호 hb_reach(반 걸음) → hb_grab(멱살 — 끌어당겨 묶는다) → hb_hit1(1타 — 아이템 피해 × nvHeadK1)
//    → hb_back2(다시 끌어당김) → 큐 hb_hit2(기본 경로 — 반응 rElbow: 어질어질 · 아이템 stun) → 휘청 물러남 + 머리 위 별(fx 'nv_daze').
// 규칙 난수는 쓰지 않는다(치명 굴림은 기본 경로 heroSkill 그대로).

/// 세 기술 만화 글자(문구는 여기 한 곳 · 영어는 strings-extra)
public enum NvOfficeText {
    /// 내려찍는 순간 · 바닥에 꽂혀 튀는 순간
    public static let slam = "콱!", bounce = "쿠웅!"
    /// 쌍장이 꽂히는 순간(결재 도장)
    public static let stamp = "결재!"
    /// 멱살을 잡는 순간 · 1타 · 2타
    public static let grab = "꽉!", head1 = "쿵!", head2 = "빠악!"
}

extension World {
    /// 내려찍기: 상대 앞 거리(px) · 뛰어드는 최대 거리(px) · 꽂는 속도(떠 있을 때 · 서 있을 때 — px/s) · 튀어 오르는 속도(px/s — 높이 ≈ v²/2G)
    static let nvSlamGap = 14.0, nvSlamLunge = 40.0, nvSlamSpikeV = 520.0, nvSlamSpikeV0 = 300.0, nvSlamBounceV = 240.0
    /// 바닥에 꽂힌 채 멈칫(경직 칸 — 20fps)
    static let nvSlamGroundHs = 3
    /// 쌍장 날림: 가로 속도 · 올라가는 속도 · 중력 배율 · 초당 남는 가로 비율 · 내디딤 최대 거리(px)
    static let nvStampVx = 420.0, nvStampVy = 90.0, nvStampG = 0.35, nvStampKeep = 0.5, nvStampLunge = 30.0
    /// 벽에 박힘: 붙어 있는 틱(60틱 = 1초) · 틱마다 미끄러지는 px · 가장 낮은 높이(px) · 벽 추가 피해(웹 wallCheck 꼴 4 → 6) · 가장 느린 박힘 속도(px/s)
    static let nvStampStick = 27.0, nvStampSlide = 0.35, nvStampSlideMin = 8.0, nvStampWallDmg = 6.0, nvStampMinV = 60.0
    /// 박치기: 1타 피해 배율 · 끌어당기는 거리(상대 몸 가운데까지 px) · 묶는 시간(초) · 2타 뒤 밀림(px/s)
    static let nvHeadK1 = 0.35, nvHeadGap = 15.0, nvHeadHold = 1.0, nvHeadPush = 70.0

    /// 기본 경로가 이번에 상대를 맞혔나(피해가 들어갔나 — 막힘 · 빗나감 · 피함이면 false)
    private func nvLanded(_ T: Actor, _ hp0: Double?) -> Bool { (T.e?.hp ?? 0) < (hp0 ?? 0) }

    // MARK: 서류가방 내려찍기

    func nvSlamOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let f = H.f
        opts.cues = [
            // 도약: 바닥을 박차고 상대 앞(14px)으로 뛰어든다
            "cs_jump": { [unowned self] c in
                visCue("cs_jump")(c); self.fx("dust", H.x - f * 3, H.y, -f); self.fx("dust", H.x + f * 3, H.y, f)
                let dd = min(World.nvSlamLunge, max(0, abs(T.x - H.x) - World.nvSlamGap))
                if dd > 0 && !T.dead { H.dash = f * dd / 0.2; H.dashT = 0.2 }
            },
            // 착지: 가방이 바닥 앞을 친다(먼지 · 작은 바닥 충격)
            "cs_land": { [unowned self] c in
                visCue("cs_land")(c); H.dash = 0; H.dashT = 0
                self.fx("dust", H.x + f * 16, H.y, f); self.fx("dust", H.x - f * 2, H.y, -f); self.groundImpact(H.x + f * 16, H.y, 0.5)
            },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let hp0 = T.e?.hp
            hit?(c)
            guard self.nvLanded(T, hp0), let J = T.jug, !J.roofOut else { return }
            // 바닥으로 내리꽂는다(바닥에 닿으면 jugStep 의 바닥 튕김 → nvSlamBounce)
            J.vy = -(J.h > 20 ? World.nvSlamSpikeV : World.nvSlamSpikeV0); J.vx = f * 12; T.kb = J.vx
            J.gb = false; J.gbReady = true; J.gbSrc = b.uid; J.nvSlam = true; J.trip = false; J.nvKeep = nil; J.nvRollT = nil; J.nvWall = false
            J.up = "air_up"; J.fall = "air_back"; J.hitT = self.time + 0.3   // 꽂히는 동안은 맞은 자세(air_hit)
            T.hs = min(T.hs, 2); T.hs0 = max(1, T.hs)
            self.fx("nv_slam", T.x - f * 4, T.y - 40 - J.h, f)   // 가방이 터지며 서류가 흩날린다
            self.comicSFX(T.x + f * 4, T.y - 84 - J.h, NvOfficeText.slam, force: true)
            var k = CameraKick(); k.shake = 2.4; k.zoom = 0.05; k.zoomMode = .add(cap: 0.08); k.focus = SIMD2(T.x, T.y - 30 - J.h); self.emit(.camera(k))
            self.emit(.haptic(.heavy))
        }
    }

    /// 바닥 튕김(jugStep): 더 높이 튀고 바닥 충격파 고리 · 흔들림
    func nvSlamBounce(_ a: Actor, _ J: Jug) {
        J.vy = World.nvSlamBounceV * (a.e?.heavy == true ? 0.8 : 1)
        J.vx = jsSign(J.vx) * 10; a.kb = J.vx   // 제자리에서 솟는다(다시 띄워 잇기 좋게)
        a.hs = max(a.hs, World.nvSlamGroundHs); a.hs0 = a.hs; a.flash = 0   // 바닥에 꽂힌 채 잠깐 멈칫(꽂힌 게 읽히게 — 흰 번쩍임 없이 몸 모양 그대로)
        fx("tsring", a.x, a.y); shake(3.2); slowT = max(slowT, 0.06)
        comicSFX(a.x, a.y - 70, NvOfficeText.bounce, force: true); sfx("thud"); emit(.haptic(.heavy))
    }

    // MARK: 결재 쌍장

    func nvStampOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let f = H.f
        opts.cues = [
            // 내디딤: 앞발을 크게 미끄러뜨려 상대 앞(16px)까지
            "ss_step": { [unowned self] c in
                visCue("ss_step")(c); self.fx("dust", H.x, H.y, -f)
                let dd = min(World.nvStampLunge, max(0, abs(T.x - H.x) - 16))
                if dd > 0 && !T.dead { H.dash = f * dd / 0.1; H.dashT = 0.1 }
            },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            H.dash = 0; H.dashT = 0
            let hp0 = T.e?.hp
            hit?(c)
            guard self.nvLanded(T, hp0) else { return }
            let h = T.jug?.h ?? 0
            self.fx("nv_stamp", T.x - f * 7, T.y - 38 - h, f)   // 손바닥 자리에 결재 도장
            self.comicSFX(T.x - f * 2, T.y - 88 - h, NvOfficeText.stamp, force: true)
            var k = CameraKick(); k.shake = 3.0; k.zoom = 0.06; k.zoomMode = .add(cap: 0.1); k.focus = SIMD2(T.x, T.y - 36 - h); self.emit(.camera(k))
            self.emit(.haptic(.heavy)); self.slowT = max(self.slowT, 0.06)
            guard let J = T.jug, !J.roofOut else { return }
            // 낮고 곧게 길게: 가로는 천천히 잃고(nvKeep — nvKneeFlyStep 이 J.vx 를 kb 에 맞춘다) 중력은 약하게
            let hv = T.e?.heavy == true ? 0.6 : 1
            J.vx = f * World.nvStampVx * hv; J.vy = World.nvStampVy; J.gk = World.nvStampG; J.nvKeep = World.nvStampKeep; J.nvRollT = nil
            J.nvWall = true; J.nvSlam = false; J.forceB = true; J.bounced = false; J.trip = false
            J.up = "air_back"; J.fall = "air_back"; J.rollT = J.roll; J.rollR = 0
            T.kb = J.vx; T.hs = min(T.hs, 3); T.hs0 = max(1, T.hs)
        }
    }

    /// 날아가는 몸이 벽에 닿았나(wallCheck 앞 — 무도장에서도). 느려지면 보통 규칙으로
    func nvStampWallCheck(_ a: Actor, _ J: Jug) {
        let v = abs(a.kb) >= abs(J.vx) ? a.kb : J.vx, dir = jsSign(v)
        if dir == 0 || abs(v) < World.nvStampMinV { if J.bounced { J.nvWall = false }; return }
        let W = dir > 0 ? AW1() : AW0()
        guard (a.x - W) * dir >= -2, !a.held, !a.kane, !a.carDummy, !a.carOwner else { return }
        nvStampSplat(a, (W, dir))
    }

    /// 벽에 박힌다: 기존 벽꿍(nvWallPlace · nvWallHit)에 붙어 있는 시간만 길게 + 벽 피해 · 벽에 남는 결재 도장
    func nvStampSplat(_ a: Actor, _ wl: (w: Double, dir: Double)) {
        let h = max(0, a.jug?.h ?? 0)
        a.jug = nil; a.airOv = h; a.kb = 0
        if a.dead { setAnim(a, "rBlastD") } else { setAnim(a, "fall"); a.after = "getup" }
        nvWallPlace(a, wl)
        if let e = a.e, !a.dead {   // 벽 피해(웹 wallCheck 꼴)
            let dm = max(1, jsRound(World.nvStampWallDmg * (1 + 0.12 * Double(ci))))
            if e.hp > dm || demo { e.hp -= dm; stats.dealt += dm; score += 60; emit(.damagePop(target: a.id, value: Int(jsRound(dm * data.dmgK)), style: "hit", label: nil)) }
        }
        nvWallHit(a, wl)
        if !a.dead { a.nvHold?.n = World.nvStampStick }
        fx("nv_stampWall", wl.w - wl.dir * 1, a.y - 26 - a.airOv * 0.5, wl.dir)
        slowT = max(slowT, 0.1); shake(3.6)
    }

    // MARK: 멱살 박치기

    func nvHeadbuttOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ i: Int, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let st = sStats(i), f = H.f
        var held = false
        /// 상대를 주인공 앞(nvHeadGap)으로 끌어당긴다(0.1초)
        let pull: () -> Void = { [unowned self] in
            guard held, !T.dead else { return }
            let tx = H.x + f * World.nvHeadGap
            T.kb = 0; T.dash = (tx - T.x) / 0.1; T.dashT = 0.1
            if let e = T.e { e.stun = max(e.stun, World.nvHeadHold) }
            self.face(T, H.x)
        }
        opts.cues = [
            // 뻗기: 반 걸음 들어간다
            "hb_reach": { [unowned self] c in
                visCue("hb_reach")(c)
                let dd = max(0, abs(T.x - H.x) - (World.nvHeadGap + 3))
                if dd > 0 && !T.dead { H.dash = f * min(dd, 16) / 0.1; H.dashT = 0.1; self.fx("dust", H.x, H.y, -f) }
            },
            // 멱살: 잡을 수 있으면(서 있는 · 떠 있지 않은 · 잡히지 않은 상대 · 34px 안) 끌어당겨 묶는다
            "hb_grab": { [unowned self] c in
                visCue("hb_grab")(c); H.dash = 0; H.dashT = 0
                guard !T.dead, !T.held, T.jug == nil, !self.isDown(T), T.e != nil, abs(T.x - H.x) <= 34 else { return }
                held = true
                T.action = nil; T.queue = []; self.setAnim(T, "pulled"); pull()
                self.comicSFX(T.x, T.y - 80, NvOfficeText.grab); self.sfx("clack"); self.emit(.haptic(.light))
            },
            // 1타: 짧게 박는다(작게 · 묶음 유지)
            "hb_hit1": { [unowned self] c in
                visCue("hb_hit1")(c)
                guard held, !T.dead else { return }
                self.curSrc = b.uid; var o = HitOpts(); o.react = "head"; o.pierce = true   // 잡고 박는다 — 방패 · 쳐내기 · 피하기 없이
                self.damage(H, T, max(1, jsRound(st.dmg * World.nvHeadK1 * self.comboMul(b))), o); self.curSrc = nil
                guard !T.dead else { return }
                T.kb = f * 4; T.flash = 0   // 1타는 작게: 흰 번쩍임 없이(2타가 크게 터진다)
                if let e = T.e { e.stun = max(e.stun, World.nvHeadHold) }; T.action = nil; T.queue = []
                T.hs = min(T.hs, 2); T.hs0 = max(1, T.hs); H.hs = min(H.hs, 1); H.hs0 = max(1, H.hs)
                self.fx("nv_head", (H.x + T.x) / 2, H.y - 50, f)
                self.comicSFX(T.x, T.y - 84, NvOfficeText.head1, force: true); self.emit(.haptic(.medium))
                if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
            },
            // 크게 젖히며 다시 끌어당긴다
            "hb_back2": { c in visCue("hb_back2")(c); pull() },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let hp0 = T.e?.hp
            hit?(c)   // 2타: 기본 경로(아이템 피해 · 치명 · stun · 반응 rElbow — 어질어질)
            guard self.nvLanded(T, hp0) else { return }
            self.fx("nv_head", (H.x + T.x) / 2, H.y - 50, f * 2)   // 큰 별 터짐(dir 크기 2 = 크게)
            self.comicSFX(T.x + f * 4, T.y - 90, NvOfficeText.head2, force: true)
            var k = CameraKick(); k.shake = 2.6; k.zoom = 0.07; k.zoomMode = .add(cap: 0.1); k.focus = SIMD2((H.x + T.x) / 2, H.y - 50); self.emit(.camera(k))
            self.emit(.haptic(.heavy)); self.slowT = max(self.slowT, 0.08)
            if !T.dead && T.jug == nil {
                T.kb = f * World.nvHeadPush   // 휘청 물러난다
                self.fx("nv_daze", T.x, T.y - 64, Double(T.id))   // 머리 위 별(표현이 그 인물 머리를 따라간다)
            }
        }
    }
}
