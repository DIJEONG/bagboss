import Foundation

// 직접 조작 패드(네이티브 · docs/09 §패드 — 2026-10-14 감독: 가방 = 빌드, 패드 = 조작감).
// 가방(테트리스)은 어떤 기술을 넣고 어떻게 붙여 콤보 경로를 만들지 고르는 빌드 — 패드는 그 결과를 손으로 내는 자리(고정 배치).
//  · 입력(SimIntent.pad): ◀ ▶ 누르고 있기(걷기) · 기술 버튼(가방 uid) · 기본기(쿨타임 없는 잽 · 크로스 — 누구나) · ▼ 숙이기(기본 장착)
//  · 아무 입력이나 받으면 수동(manualT 2.5초) — 그동안 자동 AI(heroAI)는 쉬고 패드가 조종한다. 손을 떼고 2.5초가 지나면 다시 자동.
//  · 입력 버퍼: 동작 중에 누른 버튼은 0.25초 기억했다가 움직일 수 있게 되는 첫 틱에 낸다.
//  · 캔슬: 지금 동작의 타격(큐)이 이미 나갔으면 남은 회복 칸을 끊고 다음 기술 · 기본기로 잇는다(콤보 손맛 — 자동 AI 의 착지 · 콤보 캔슬과 같은 조건).
//  · 기본기: 앞에 공격을 준비하는 적이 있으면 받아치기(웹 manual 의 저스트 · 카운터 그대로) — 패드가 버튼을 빨갛게 바꿔 알려 준다(PadView.counter).
//  · 숙이기: 쭈그리기 아이템이 없어도 수동으로는 숙일 수 있다(0.6초 간격) — 큰 공격을 피하기만 하고, 완벽 회피 보상 · 자동 숙이기는 아이템이 있을 때만.
// 규칙 난수는 쓰지 않는다.

/// 패드 입력
public enum PadInput: Sendable, Equatable {
    /// ◀(−1) · ▶(+1) 누르기 시작 · 떼기(0)
    case move(Int)
    /// 뛰기(같은 방향 두 번 · 꾹 누르기 — 앱이 고른다): 떼면(move(0)) 미끄러져 선다
    case run(Int)
    /// 기술 버튼(가방 아이템 uid)
    case skill(uid: Int)
    /// 기본기(쿨타임 없음 — 받아치기 겸용)
    case basic
    /// ▼ 숙이기
    case duck
}

/// 패드 상태(규칙)
struct NvPad {
    var dir = 0
    /// 뛰는 중(질주 규칙 — World+NativeMove nvApproach)
    var run = false
    /// 버퍼(입력 · 나이 — 패드 틱에서만 센다: 타격 정지 동안은 늙지 않는다)
    var buf: (input: PadInput, age: Double)?
    var basicN = 0, basicT = -9.0
    var duckReady = 0.0
    /// 패드가 조종 중(수동 시간 안에 패드 입력이 있었다)
    var active = false
}

extension World {
    /// 수동 유지(초) · 입력 버퍼(초) · 기본기 간격(초) · 맨손 숙이기 간격(초) · 기본기 피해(잽 · 크로스)
    static let padManual = 2.5, padBuffer = 0.25, padBasicGap = 0.26, padDuckGap = 0.6, padJab = 4.0, padCross = 6.0
    /// 끌려온 적에게 기본기 = 어퍼컷 피해(띄움)
    static let padUpper = 8.0

    /// 패드 입력 하나(Sim.apply). lag = 터치 뒤 지난 게임 시간(저스트 판정)
    func padInput(_ p: PadInput, lag: Double) {
        guard nv, on, state != "over", state != "shop", let H = hero, !H.dead else { return }
        if tapW != nil { switch p { case .move, .run: break; default: tapFire(true); return } }   // 시작기 '탭!' 창이 열려 있으면 어떤 버튼이든 탭
        manualT = World.padManual; engageT = time + 8; pad.active = true
        switch p {
        case .move(let d): pad.dir = d < 0 ? -1 : d > 0 ? 1 : 0; pad.run = false
        case .run(let d): pad.dir = d < 0 ? -1 : 1; pad.run = true
        case .duck: _ = heroDuck(true)
        case .basic: if !padBasic(lag: lag) { pad.buf = (p, 0) }
        case .skill(let uid): if !padSkill(uid) { pad.buf = (p, 0) }
        }
    }

    /// 매 틱(heroAI 앞): 패드가 조종 중이면 true(자동 AI 를 쉰다) — 버퍼 · 걷기
    func padTick(_ H: Actor, _ dt: Double) -> Bool {
        guard nv, pad.active else { return false }
        if manualT <= 0 || H.dead { pad = NvPad(basicN: pad.basicN, basicT: pad.basicT, duckReady: pad.duckReady); if H.anim == "walk" { setAnim(H, "idle") }; return false }
        if var b = pad.buf {
            b.age += dt; pad.buf = b
            if b.age > World.padBuffer { pad.buf = nil }
            else {
                let ok: Bool
                switch b.input { case .basic: ok = padBasic(lag: 0); case .skill(let uid): ok = padSkill(uid); default: ok = true }
                if ok { pad.buf = nil }
            }
        }
        if pad.dir != 0 {
            manualT = World.padManual   // 누르고 있는 동안은 수동 유지
            if pad.run {   // 뛰기: 자동 전투와 같은 질주(출발 칸 · 가속 · 떼면 미끄러져 서기 — nvMoveTick)
                if canAct(H) || H.anim == "walk" || H.anim == "nv_go" {
                    face(H, H.x + Double(pad.dir))
                    _ = approach(H, max(AW0(), min(AW1(), H.x + Double(pad.dir) * 120)), heroSpd(), dt, heroSpd() * 3.4, true)
                }
            } else if canAct(H) || H.anim == "walk" {
                face(H, H.x + Double(pad.dir))
                moveTo(H, max(AW0(), min(AW1(), H.x + Double(pad.dir) * 40)), heroSpd(), dt)
            }
        } else if H.anim == "walk" && H.nvm.mode != 2 { setAnim(H, "idle") }
        return true
    }

    /// 새 동작을 시작할 수 있나 — 타격이 이미 나간 동작의 회복 칸은 끊는다(캔슬)
    func padCanStart(_ H: Actor) -> Bool {
        if canAct(H) || H.anim == "walk" { return true }
        if let A = H.action, A.fired, !heroAirborne(H), !data.falls.contains(H.anim), !data.reacts.contains(H.anim),
           H.anim != "duck", H.anim != "getup", !holding(H), !(H.anim == "nv_rise") {
            H.action = nil; H.queue = []; setAnim(H, "idle"); return true
        }
        return false
    }

    /// 패드 대상: 보는 쪽 앞(120px 안)에서 가장 가까운 적 → 없으면 가장 가까운 적(돌아선다). 뒤 공격 기술은 등 뒤
    func padTarget(_ H: Actor, back: Bool = false) -> Actor? {
        let F = foes().filter { !$0.dead && !$0.held && $0.anim != "death" }
        func d(_ a: Actor) -> Double { abs(a.x - H.x) }
        if back { return stableSortD(F.filter { behindOf(H, $0) }) { d($0) - d($1) }.first }
        return stableSortD(F.filter { !behindOf(H, $0) && d($0) < 120 }) { d($0) - d($1) }.first ?? stableSortD(F) { d($0) - d($1) }.first
    }

    /// 기술 버튼: 쿨타임 중이면 버린다(true) · 움직일 수 없으면 버퍼(false)
    @discardableResult
    func padSkill(_ uid: Int) -> Bool {
        guard let H = hero, let i = bag.firstIndex(where: { $0.uid == uid }), let it = item(bag[i].id), it.kind == "skill" else { return true }
        if bag[i].t < cdOf(i) { flashText("WAIT", 0.3); return true }
        guard padCanStart(H) else { return false }
        guard let T = padTarget(H, back: it.back == true) else { return true }
        if H.anim == "walk" { setAnim(H, "idle") }
        useSkill(i, T, true)
        return true
    }

    /// 앞에 공격을 준비하는 적(받아치기 대상) — 웹 manual 의 카운터 조건
    func padCounterFoe(_ H: Actor) -> Actor? {
        let win = 0.42 * (1 + pv("ear", 0.6, 0.15))
        return stableSortD(foes().filter { a in
            guard !a.dead, abs(a.x - H.x) < 46, !behindOf(H, a), let A = a.action, !A.fired, let w = data.foeW[a.anim], w != "H" else { return false }
            return time - (a.windup ?? 0) < win + 0.35
        }) { abs($0.x - H.x) - abs($1.x - H.x) }.first
    }
    /// 앞에서 큰 공격(숙여 피할 것)이 오는 중
    func padHeavyIncoming(_ H: Actor) -> Bool {
        foes().contains { a in !a.dead && abs(a.x - H.x) < 60 && (a.action.map { !$0.fired } ?? false) && data.foeW[a.anim] == "H" }
    }

    /// 기본기: 받아치기(저스트 · 카운터) → 아니면 잽 · 크로스 번갈아(쿨타임 없음 — 0.26초 간격). 움직일 수 없으면 false(버퍼)
    func padBasic(lag: Double) -> Bool {
        guard let H = hero else { return true }
        if let si = shots.firstIndex(where: { jsSign($0.x - H.x) == H.f && abs($0.x - H.x) < 40 }) {   // 날아오는 병은 쳐낸다
            shots[si].dead = true; fx("spark", shots[si].x, shots[si].y); score += 50; if canAct(H) { setAnim(H, "jab") }; return true
        }
        if nvG && nvJustGuard(H.f, lag: lag) { return true }
        if let A = padCounterFoe(H), !data.falls.contains(H.anim), !data.reacts.contains(H.anim) {
            if let tt = timeToCue(A).map({ $0 + lag }), tt <= justW(), A.e?.boss != true { justCounter(A); return true }   // 저스트
            A.action = nil; A.queue = []; A.e?.stun = 1.2; A.e?.cdT = -0.6; stats.counters += 1; face(H, A.x); H.queue = []; H.action = nil; setAnim(H, "idle")
            requestAction(H, "cross", ActionReq(cue: cueFor(H, "cross", "m_cross")) { [unowned self] _ in
                if A.dead || !self.inFront(H, A, self.data.moveReach["cross"] ?? 28) { return }
                var o = HitOpts(); o.crit = true; o.counter = true; o.react = "body"
                self.damage(H, A, jsRound(14 * (1 + 0.12 * Double(self.ci))), o)
            })
            flashText("COUNTER", 0.8); emit(.counter(target: A.id)); return true
        }
        guard mcd <= 0, padCanStart(H) else { return false }
        if time - pad.basicT > 0.7 { pad.basicN = 0 }
        let T = padTarget(H)
        if let T, nvJustPulled(T), !T.dead, !isDown(T), T.jug == nil, abs(T.x - H.x) < 40 {   // 끌려온 적(내선 연결 · 우산): 기본기가 어퍼컷으로 — 띄워서 잇는다(MK 창 → 어퍼컷)
            pad.basicN = 0; pad.basicT = time; mcd = World.padBasicGap
            face(H, T.x); if H.anim == "walk" { setAnim(H, "idle") }
            H.action = nil
            requestAction(H, "upper", ActionReq(cue: cueFor(H, "upper", "up")) { [unowned self] _ in
                guard !T.dead, self.inFront(H, T, (self.data.moveReach["upper"] ?? 24) + 6) else { return }
                var o = HitOpts(); o.react = "launch"
                self.damage(H, T, jsRound(World.padUpper * (1 + 0.12 * Double(self.ci))), o)
            })
            return true
        }
        let cross = pad.basicN % 2 == 1, anim = cross ? "cross" : "jab"
        pad.basicN += 1; pad.basicT = time; mcd = World.padBasicGap
        if let T { face(H, T.x) }
        if H.anim == "walk" { setAnim(H, "idle") }
        if let T, abs(T.x - H.x) > (data.moveReach[anim] ?? 24) && abs(T.x - H.x) < 56 { H.dash = H.f * 140; H.dashT = 0.08 }   // 조금 멀면 반 걸음 들어간다
        H.action = nil
        requestAction(H, anim, ActionReq(cue: cueFor(H, anim, cross ? "m_cross" : "m_jab")) { [unowned self] _ in
            guard let T, !T.dead, self.inFront(H, T, (self.data.moveReach[anim] ?? 24) + 4) else { return }
            var o = HitOpts(); o.react = "head"
            self.damage(H, T, jsRound((cross ? World.padCross : World.padJab) * (1 + 0.12 * Double(self.ci))), o)
        })
        return true
    }

    /// 쭈그리기 아이템 없이 숙이기(수동 · 패드) — heroDuck 이 부른다
    func padDuckBare(_ H: Actor) -> Bool {
        guard time >= pad.duckReady else { return false }
        pad.duckReady = time + World.padDuckGap; manualT = World.padManual
        H.queue = []; H.action = nil; setAnim(H, "idle"); requestAction(H, "duck", ActionReq(cue: "dk1") { _ in })
        return true
    }

    /// 패드 보기(스냅숏): 가방 기술 버튼(경로 기술은 순서 번호 — 최대 6) · 받아치기 · 큰 공격 · 수동 남은 초
    func padView() -> SimSnapshot.PadView {
        var P = SimSnapshot.PadView()
        P.manual = pad.active ? manualT : 0
        guard let H = hero else { return P }
        P.counter = padCounterFoe(H) != nil
        P.heavy = padHeavyIncoming(H)
        let route: [Int], step: Int
        if let C = croute { route = C.uids; step = C.k } else { route = rules.routes(bagStructs()).first?.uids ?? []; step = 0 }
        var list: [SimSnapshot.PadView.Btn] = []
        func btn(_ i: Int) -> SimSnapshot.PadView.Btn? {
            let b = bag[i]
            guard let it = item(b.id), it.kind == "skill", b.id != "duck" else { return nil }
            let cd = cdOf(i), left = max(0, cd - b.t)
            let ri = route.firstIndex(of: b.uid)
            return .init(uid: b.uid, id: b.id, name: it.name, fam: it.fam ?? "none", cd: cd > 0 ? min(1, left / cd) : 0, wait: left,
                         order: ri.map { $0 + 1 }, next: ri == step && left <= 0)
        }
        for u in route { if let i = bag.firstIndex(where: { $0.uid == u }), let b = btn(i) { list.append(b) } }
        for i in bag.indices where !route.contains(bag[i].uid) { if let b = btn(i) { list.append(b) } }
        P.skills = Array(list.prefix(6))
        return P
    }
}
