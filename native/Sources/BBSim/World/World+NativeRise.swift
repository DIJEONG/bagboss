import Foundation
import BBContent

// 퇴근 승천권(nv_rise — SimConfig.nativeMoves. 깃발이 꺼지면 이 동작 · 아이템이 없어 이 파일은 불리지 않는다 → 웹 그대로). docs/07 §7-R · docs/08 §8.
// 역할: 막는 중 되받아치기(가드 리버설) · 대공. 솟구치며 2타(작게, 띄우며 끌어올림) → 꼭대기 1타(크게 띄움 — 아이템 피해 · 큐 rs_apex) → 돌며 내려와 깊게 착지.
//  · 무적: 웅크림 · 솟구침 칸(rs_crouch · rs_launch — 0.1초) 동안 적 공격 · 던진 병은 빗나간다
//  · 높이 층: 오름 · 꼭대기 칸(rs_rise · rs_apex)은 몸이 상단 공격 선 위로 솟아 상단(잽 · 훅 · 돌려차기 · 몽둥이 · 날아차기 · 병)이 빗나간다. 중단 · 하단은 맞는다
//  · 내 기술 높이 = 중단(아래에서 올려 친다): 서서 막기에 막히고(되받아치기를 읽힌 셈 — 착지 빈틈이 그대로 벌), 앉아 막기는 뚫는다
//  · 착지(rs_land · rs_rec · c_over 0.38초)는 가드 · 받아치기 · 공중 콤보로 끊을 수 없다(빈틈)
//  · 인공지능: 막는 순간(블록 경직) 압박(앞뒤 46px 안 둘 이상 · 무거운 H 공격 예고)이면 55%(직접 조작 중 35%) — 막기 한 번에 한 번만 굴린다.
//    날아차기로 뛰어드는 적(타격까지 ≤ 0.45초 · 70px 안)에겐 가드 대신 75% · 조건 'nv_aa'(대공 — 뛰어드는 적 · 떨어지는 낮은 공중 적)
//  · 지붕 뚫기: 꼭대기 한 방이 적을 쓰러뜨리면(두목은 마지막 쓰러짐일 때만 — 쓰러지면 늘 마지막) 8초에 한 번 — 천장을 뚫고 화면 위로 날려 보낸다(roofBlast 이벤트)
// 규칙 난수는 깃발 켜짐 경로에서만 쓴다.

/// 퇴근 승천권 외침(만화 글자 — 문구는 여기 한 곳 · 영어는 tools/js/extract/strings-extra.json 'native-moves')
public enum NvRiseText {
    /// 솟구칠 때(표현이 머리 옆에)
    public static let launch = "칼퇴!"
    /// 지붕 뚫기(꼭대기 처치) — 구멍 옆 큰 글자
    public static let roof = "퇴근해라!!"
}

extension World {
    /// 무적 칸(웅크림 · 솟구침)
    static let nvRiseInvulnPoses: Set<String> = ["rs_crouch", "rs_launch"]
    /// 상단이 빗나가는 칸(오름 · 꼭대기)
    static let nvRiseHighPoses: Set<String> = ["rs_rise", "rs_apex"]
    /// 끊을 수 없는 착지 빈틈 칸
    static let nvRiseRecovPoses: Set<String> = ["rs_land", "rs_rec", "c_over"]
    /// 지붕 뚫기 간격(초)
    static let nvRoofGap = 8.0

    /// 지금 이 공격(높이)을 승천권이 흘리는가 — 무적 칸은 전부, 오름 · 꼭대기 칸은 상단만
    func nvRiseDodges(_ H: Actor, _ h: NvHeight) -> Bool {
        guard H.anim == "nv_rise" else { return false }
        if World.nvRiseInvulnPoses.contains(H.pose) { return true }
        return h == .high && World.nvRiseHighPoses.contains(H.pose)
    }
    /// 승천권 착지 빈틈 중인가(가드 · 받아치기 · 공중 콤보 캔슬을 막는다)
    func nvRiseRecovering(_ H: Actor) -> Bool { H.anim == "nv_rise" && (World.nvRiseRecovPoses.contains(H.pose) || H.action?.fired == true) }

    /// 가방에서 쓸 수 있는 승천권 칸
    func nvRiseSlot() -> Int? {
        bag.indices.first { k in bag[k].id == "nv_rise" && bag[k].t >= cdOf(k) && !soloSkip(bag[k]) }
    }

    /// 조건 'nv_aa'(대공): 날아차기로 뛰어드는 적 · 낮게 떨어지는 공중 적
    func nvAntiAirOK(_ H: Actor, _ F: [Actor]) -> Bool {
        F.contains { a in
            guard !a.dead, !a.held else { return false }
            let d = abs(a.x - H.x)
            if a.anim == "fkick", let A = a.action, !A.fired, d <= 70, let tt = timeToCue(a), tt <= 0.45 { return true }
            if let J = a.jug, !J.roofOut, J.h >= 8, J.h <= 46, J.vy < 60, d <= 30 { return true }
            return false
        }
    }

    /// 막는 순간(블록 경직): 압박이면 승천권으로 되받아친다. true = 썼다
    func nvRiseReversal(_ H: Actor, _ live: [Actor]) -> Bool {
        guard let i = nvRiseSlot(), H.nvg.blockAt != nvRiseRollAt, time - H.nvg.blockAt < 0.3 else { return false }
        let close = live.filter { !isDown($0) && !$0.held && abs($0.x - H.x) < 46 }
        let heavy = live.contains { a in
            guard let A = a.action, !A.fired, data.foeW[a.anim] == "H", let e = a.e, let tt = timeToCue(a) else { return false }
            return tt <= 0.5 && abs(a.x - H.x) <= wpnReach(a.lastMove, e.wpn) + 10
        }
        guard close.count >= 2 || heavy else { return false }
        nvRiseRollAt = H.nvg.blockAt
        if rnd() >= (manualT > 0 ? 0.35 : 0.55) { return false }
        let byID = H.nvg.blockBy
        let T = live.first { $0.id == byID && !isDown($0) } ?? stableSortD(close) { abs($0.x - H.x) - abs($1.x - H.x) }.first
        guard let T else { return false }
        stats.nvg.riseReversals += 1
        nvRiseGo(H, i, T)
        flashText("REVERSAL!", 0.6)
        return true
    }

    /// 뛰어드는 적(날아차기)에게 가드 대신 대공. true = 썼다
    func nvRiseAntiAirGuard(_ H: Actor, _ a: Actor) -> Bool {
        guard a.anim == "fkick", let i = nvRiseSlot(), abs(a.x - H.x) <= 70 else { return false }
        if rnd() >= 0.75 { return false }
        stats.nvg.riseAntiAir += 1
        nvRiseGo(H, i, a)
        return true
    }

    /// 지금 동작을 끊고 승천권(가드 · 막기 경직에서도)
    func nvRiseGo(_ H: Actor, _ i: Int, _ T: Actor) {
        H.action = nil; H.queue = []; H.after = nil; H.hs = 0; H.dash = 0; H.dashT = 0; H.nvg.stance = 0
        setAnim(H, "idle"); face(H, T.x)
        useSkill(i, T, false)
        bag[i].opener = false   // 되받아치기 · 대공은 제 몫(조건 없이 콤보를 여는 시작기 감쇠 ×0.4 를 받지 않는다)
    }

    /// useSkill 갈래: 솟구치는 두 타 · 꼭대기 큰 타(띄움 · 지붕 뚫기) · 착지 먼지
    func nvRiseOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ i: Int, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let st = sStats(i), f = H.f
        stats.nvg.rises += 1
        /// 솟구치며 끌어올리는 작은 타격(피해 = 아이템 × k) — 주인공 경직은 1칸으로(오름이 끊기지 않게)
        let rise: (Double, Double) -> Void = { [unowned self] k, vy in
            guard !T.dead, !T.held else { return }
            let dx = (T.x - H.x) * f
            if dx < -8 || dx > (self.item(b.id)?.reach ?? 24) + 8 || (T.jug.map { $0.h > 60 } ?? false) { return }
            // 가벼운 타격(띄우기 반응 · 큰 연출 없이) — 서 있던 적은 직접 띄워 주인공과 함께 솟게 한다
            self.curSrc = b.uid; var o = HitOpts(); o.react = "head"
            let blocked0 = self.nvc.blockedNow; self.nvc.blockedNow = false
            self.damage(H, T, max(1, jsRound(st.dmg * k * self.comboMul(b))), o); self.curSrc = nil
            let blocked = self.nvG && self.nvc.blockedNow; self.nvc.blockedNow = blocked0
            if !T.dead && !blocked && T.jug == nil && T.e?.boss != true && !self.data.falls.contains(T.anim) { self.jugHit(T, "launch", f, H, HitOpts(), T.e?.heavy == true ? 0.35 : 1) }
            if let J = T.jug, !T.dead, !J.roofOut { J.vy = max(J.vy, vy); J.vx = f * 12 }   // 주인공과 함께 솟는다
            H.hs = min(H.hs, 1); H.hs0 = max(1, H.hs); T.hs = min(T.hs, 2)
            if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
        }
        opts.cues = [
            "rs_crouch": { [unowned self] _ in self.fx("dust", H.x, H.y, -H.f) },
            "rs_launch": { [unowned self] c in visCue("rs_launch")(c); self.fx("dust", H.x, H.y, H.f); rise(0.2, 170) },
            "rs_rise": { c in visCue("rs_rise")(c); rise(0.2, 200) },
            "rs_land": { [unowned self] c in visCue("rs_land")(c); self.fx("dust", H.x, H.y, H.f); self.fx("dust", H.x, H.y, -H.f); self.groundImpact(H.x, H.y, 0.7) },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            visCue("rs_apex")(c)
            let before = Set(self.foes().map(\.id))
            hit?(c)
            H.hs = min(H.hs, 3); H.hs0 = max(1, H.hs)   // 꼭대기 멈칫은 매달림 칸이 맡는다(경직은 짧게 — 0.15초)
            // 꼭대기 큰 타: 거의 수직으로 높이 띄운다(공중 콤보 이어 가기)
            for a in self.ents where a.e != nil && a.jug != nil && (before.contains(a.id) || a === T) && !(a.jug!.roofOut) && abs(a.x - H.x) < 40 {
                let J = a.jug!; J.vy = max(J.vy, a.dead ? 260 : 320); J.vx = f * 24; J.up = "air_up"; J.fall = "air_back"
            }
            // 지붕 뚫기: 이번 한 방에 쓰러진 적(떠서 죽는 중) 하나
            if let v = self.ents.first(where: { a in a.e != nil && a.dead && before.contains(a.id) && a.jug?.die == true && abs(a.x - H.x) < 40 }), self.nvRoofOK(v) { self.nvRoofBlast(v, f) }
        }
    }

    // MARK: 지붕 뚫기

    func nvRoofOK(_ a: Actor) -> Bool {
        guard nv, !bonus, spc == nil, cut == nil, !a.kane, !a.carDummy, !a.carOwner, a.jug != nil else { return false }
        return time - nvRoofAt >= World.nvRoofGap || time < nvRoofAt   // 새 판(time 이 0 부터)이면 다시
    }

    /// 무대 종류 · 천장 선 y
    func nvRoofSpot() -> (kind: String, y: Double) {
        if demo { return (dj?.bg == "snow" || dj?.bg.hasPrefix("beach") == true ? "open" : "none", 30) }   // 무도장: 천장이 화면 밖 — 빛줄기만(눈 승강장 · 해변 배경은 하늘)
        if nvSnow?.held == true { return ("open", 20) }   // 눈 승강장: 지붕이 없다 — 구멍 없이 눈 내리는 하늘로
        if tower { return ("hatch", TWR.CEIL + 2) }     // 엘리베이터 비상 해치
        if prologue { return ("tile", 44) }             // 프롤로그 복도 천장 타일
        if scene == "subway" { return ("car", 141 + tr.dy) }   // 객차 지붕 선(SB.CAR_Y 140 — 그 위는 터널 · 바깥)
        return ("none", 30)
    }

    func nvRoofBlast(_ a: Actor, _ f: Double) {
        guard let J = a.jug else { return }
        nvRoofAt = time; stats.nvg.roofBlasts += 1
        J.roofOut = true; J.die = true; J.vy = max(J.vy, 520); J.vx = f * 10; J.up = "air_up"; J.fall = "air_up"; J.hitT = 0; J.rollT = 0
        a.kb = 0; a.hs = 0
        let (kind, y) = nvRoofSpot()
        let R = RoofBlast(target: a.id, x: a.x, y: y, kind: kind, dir: f)
        emit(.roofBlast(R))
        comicSFX(a.x + f * 40, y + 30, NvRiseText.roof, force: true)   // 구멍 옆(피해 숫자는 반대쪽 — HUD)
        var k = CameraKick(); k.zoom = 0.1; k.zoomMode = .add(cap: 0.12); k.focus = SIMD2(a.x, y + 20); k.shake = 3.6; k.invertFrames = 2; emit(.camera(k))
        slowT = max(slowT, 0.2)   // 화면 정지는 더하지 않는다(날아가는 몸이 바로 보이게 — 마지막 적이면 웹 마지막 일격 정지가 따로 있다)
        schedule(after: 1.9) { $0.emit(.roofThud(R)) }
    }

    /// jugStep 갈래: 천장을 뚫고 빨라지며 돌아 화면 위로 — 다 나가면 사라진다(쓰러짐 기록은 damage 에서 이미)
    func nvRoofStep(_ a: Actor, _ J: Jug, _ dt: Double) {
        J.t += dt; J.vy += 900 * dt; J.h += J.vy * dt; J.roll += 2.6 * dt
        a.x += J.vx * dt; a.kb = 0
        if a.pose != "air_up" { a.prev = "air_up"; a.pose = "air_up"; a.k = 0 }
        a.hold = 99999; a.phaseN = 99999; a.airOv = J.h
        if J.h > 320 { a.jug = nil; a.airOv = 0; a.hidden = true }
    }
}

// MARK: 개발용 시연(앱 DebugLaunch '-roofdemo' — 시뮬레이터 영상 · 점검용, 규칙 경로 그대로)

extension Sim {
    /// 지하철 판에서 승천권 시연: 가방에 없으면 넣고, 앞 40px 안의 서 있는 적 하나를 꼭대기 한 방에 쓰러질 체력으로 낮춰 바로 쓴다.
    /// roof = true 면 지붕 뚫기 간격(8초)을 무시한다. 썼으면 true
    @discardableResult
    public func debugRiseDemo(roof: Bool = true) -> Bool {
        guard w.config.nativeMoves, w.state == "fight", let H = w.hero, !H.dead, w.canAct(H) else { return false }
        if !w.bag.contains(where: { $0.id == "nv_rise" }) {
            let it = w.newItem("nv_rise")
            if let p = w.findSpot(it) { it.x = p.x; it.y = p.y; it.rot = p.rot } else { it.x = 0; it.y = 0 }
            w.bag.append(it); w.renderBag()
        }
        guard let i = w.bag.firstIndex(where: { $0.id == "nv_rise" }) else { return false }
        let T = stableSortD(w.foes().filter { !w.isDown($0) && !$0.held && $0.jug == nil && abs($0.x - H.x) < 40 && $0.e?.boss != true }) { abs($0.x - H.x) - abs($1.x - H.x) }.first
        guard let T, let e = T.e else { return false }
        e.hp = min(e.hp, 10); w.bag[i].t = 99
        if roof { w.nvRoofAt = -99 }
        w.nvRiseGo(H, i, T)
        return true
    }
}
