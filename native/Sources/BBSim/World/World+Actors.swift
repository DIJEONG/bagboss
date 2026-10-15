import Foundation
import BBContent

// 웹 27-actors.js: 칸 들어가기(enterCar) · 승하차(startBoard · boardAt · passengerUpdate) · 적 생성(spawnWave · defFor) ·
// 이동(face · moveTo · runTo · approach) · 판정(inFront · wpnReach · doorOpenAt) · 피해(damage) · 주인공 기술(heroSkill) · 적 타격(foeHit) ·
// 떨어뜨리기 · 줍기(drop · pickup) · 자동 기술 고르기(pickSkill) + 23-game-items.js 판정(condOK · isDown · isFalling · behindOf).

/// 웹 damage(att, tgt, dmg, o) 의 o
struct HitOpts {
    var crit = false, bigCrit = false, knock = false, back = false, low = false, blast = false
    var counter = false, just = false, splash = false, backHit = false
    var react: String?
    /// 네이티브: 막기 · 쳐내기 · 피하기를 꿰뚫는다(코크스크루 블로)
    var pierce = false
}

extension World {
    // MARK: 23-game-items 판정

    /// 웹 behindOf(H, a): 등 뒤(지금 보는 방향의 반대쪽)
    func behindOf(_ H: Actor, _ a: Actor) -> Bool { (a.x - H.x) * H.f < -4 }
    static let downPoses: Set<String> = ["kd3", "kd4", "kd5", "stp0", "slm0", "sp_hit", "sp_bounce", "sp_land", "sp_lie"]
    /// 웹 isDown(a): 누운 자세
    func isDown(_ a: Actor) -> Bool { data.falls.contains(a.anim) && World.downPoses.contains(a.pose) }
    /// 웹 isFalling(a): 넘어지는 동작 전체
    func isFalling(_ a: Actor) -> Bool { data.falls.contains(a.anim) && !a.held }
    /// 웹 condOK(cond, H, T, F)
    func condOK(_ cond: String?, _ H: Actor, _ T: Actor?, _ F: [Actor]) -> Bool {
        guard let cond else { return true }
        let d = T.map { abs($0.x - H.x) } ?? 999
        switch cond {
        case "gap": return T != nil && d >= 30 && d <= 120
        case "down":
            return F.contains { isFalling($0) && abs($0.x - H.x) <= 70 }
                || (bagHasLink("gbounce") && F.contains { a in if let J = a.jug { return !J.gb && J.h < 34 && J.vy < 0 && abs(a.x - H.x) <= 60 }; return false })
        case "multi": return F.filter { !isDown($0) && abs($0.x - H.x) <= 48 }.count >= 2
        case "combo": return combo >= (has("gum") > 0 ? 2 : 3) && time - (lastHit ?? .nan) < comboWin()
        case "finish": guard let T, let e = T.e else { return false }; return e.hp <= e.max * 0.35
        case "counter":
            guard let T else { return false }
            return d <= 30 + pv("ear", 6, 2) && ((T.action != nil && !T.action!.fired) || time - (hurtAt ?? -9) < 0.5 || (nvG && time - H.nvg.blockAt < 0.5))   // 네이티브: 막은 직후도 받아치기
        case "air": guard let T, let J = T.jug else { return false }; return J.h > 4 && d <= 44
        case "grab": guard let T else { return false }; return d <= 28 && T.e?.heavy != true && !T.held && !isDown(T)
        case "back": return F.contains { !isDown($0) && !$0.held && behindOf(H, $0) && abs($0.x - H.x) <= 40 }
        case "nv_aa": return nv && nvAntiAirOK(H, F)   // 네이티브 퇴근 승천권: 대공(World+NativeRise)
        case "nv_ground": return nv && nvGroundOK(H, T)   // 네이티브 파고들어 올려치기: 서 있는 상대(World+NativeVF)
        case "proj": return shots.contains { !$0.dead && !$0.dodged && jsSign(H.x - $0.x) == jsSign($0.vx) && abs($0.x - H.x) < 130 }
        default: return true
        }
    }

    // MARK: 인물 만들기

    /// 웹 mkActor(def, o)
    func mkActor(_ def: ActorDef, x: Double, z: Double = 0, flip: Bool = false, pose: String = "m_idle0", remap: Int = 0, grammar: [String: Int]? = nil, e: Enemy? = nil, pass: Bool = false) -> Actor {
        Actor(id: newActorID(), def: def, x: x, y: data.floorY + z, flip: flip, z: z, pose: pose, remap: remap, grammar: grammar, e: e, pass: pass)
    }
    /// 웹 defFor(T, k): 생김새(look)별 정의
    func defFor(_ T: EnemyDef, _ k: Int, boss: Bool? = nil) -> ActorDef {
        let isBoss = boss ?? (T.boss == true)
        var d = ActorDef(key: isBoss ? "JW_BOSS" : "JW_THUG", name: T.name, jw: true, msT: true, mma: true)
        guard let L = T.look, case .object(let o) = L else { return d }
        var hair = "undefined"
        if case .array(let hs)? = o["hair"], !hs.isEmpty { hair = hs[(k + uid) % hs.count].string ?? "undefined" }
        else if let h = o["hair"]?.string { hair = h }
        func s(_ k: String) -> String { if let v = o[k] { switch v { case .string(let x): return x; case .bool(let b): return b ? "true" : "false"; default: return "" } }; return "" }
        d.look = [hair, s("fat"), s("coat"), isBoss ? "true" : "", s("tie"), s("mandarin")].joined(separator: "|")
        return d
    }
    func lookDef(name: String, hair: String, coat: String) -> ActorDef {
        var d = ActorDef(key: "JW_THUG", name: name, jw: true, msT: true, mma: true)
        d.look = [hair, "", coat, "", "", ""].joined(separator: "|")
        return d
    }

    // MARK: 칸 · 승하차

    func inDoor(_ x: Double) -> Bool { data.doors.contains { x > $0.0 - 8 && x < $0.1 + 8 } }
    func outDoor(_ x: Double) -> Double { for (a, b) in data.doors where x > a - 8 && x < b + 8 { return x < (a + b) / 2 ? a - 10 : b + 10 }; return x }
    /// 웹 FOE_CAP: 한 칸에 동시에 있을 수 있는 적
    func foeCap() -> Int { 7 + min(2, stageIdx) }
    /// 웹 legDur(L)
    func legDur(_ L: CarDef) -> Double {
        if L.end == true { return 64 }
        return (L.bridge != nil ? 48 : 44) + 6 * Double(L.quick?.count ?? 0)
    }

    /// 웹 enterCar(i, carry)
    func enterCar(_ i: Int, carry: Bool = false) {
        let L = line[i], C = data.cars[L.car], keep = carry ? foes() : []
        ci = i; wave = 0; waveT = 1.2; nextWaveAt = 1.2; legT = 0; clearT = nil; arriving = false; setState("fight"); fade = 1; items = []; shots = []; cans = []
        let H = hero!, hx = H.x
        for a in ents where a !== H && !keep.contains(where: { $0 === a }) { retire(a) }
        H.x = (on && hx > 0) ? clamp(hx, 30, data.sbW - 30) : (carry ? 120 : 40); H.z = 3; H.kb = 0; H.rest = nil; ents = [H]; filler = 0
        for (k, a) in keep.enumerated() {   // 못 잡은 적이 통로로 따라 들어온다
            a.x = clamp(a.x != 0 ? a.x : 16 + Double(k) * 14, 16, data.sbW - 16); a.kb = 0; a.action = nil; a.queue = []; setAnim(a, "idle"); ents.append(a)
        }
        if !stash.isEmpty && !bag.isEmpty { let n = autoPack(); if n > 0 { say("", "보류함의 \(n)개를 서류가방 빈자리에 넣었어요", 1.6) } }
        for (k, p) in (data.passengers[C.key] ?? []).enumerated() {
            let x = inDoor(p.x) ? outDoor(p.x) : p.x
            let pose = p.pose == "sleep" ? "death2" : p.pose == "sit" ? "sb_sit" : "sb_strap"
            let a = mkActor(.passenger(model: k % 3), x: x, z: p.pose == "strap" ? 1 : -2, flip: k % 2 == 1, pose: pose, remap: [0, 6, 7, 5][k % 4], pass: true)
            a.passPose = pose; if p.pose == "sleep" { a.z = -16 }
            a.idleAct = p.pose == "sit" ? ["paper", "phone", "doze", nil][(k + ci) % 4] : p.pose == "strap" ? (k % 2 == 1 ? "phone" : nil) : nil
            setAnim(a, "pass"); ents.append(a)
        }
        if C.key == "night" { for k in 0..<3 { cans.append(Can(x: 120 + Double(k) * 110)) } }
        propsInit(C); pt = nil; legEvent()
        if oneBit == nil { oneBit = false }
        let want = C.oneBit == true
        if let T = trans, T.to != want { trans = nil; lightK = 1; emitK = 1 }   // 진행 중이던 다른 전환은 취소
        if oneBit != want && !(trans != nil && trans!.to == want) { trans = LightTrans(to: want); fade = 0; emit(.lightsTransition(toDark: want)) }
        say("\(stage.short) · \(i + 1)호차 · \(C.name)", i == 0 ? stage.intro : (C.desc ?? ""), 3.2)
        if nvSnow != nil || nvSnowOn { nvSnowEnter() }   // 네이티브 눈 승강장(깃발 꺼짐이면 건너뛴다)
    }

    /// 웹 startBoard: 다음 칸으로 넘어가며 문이 열린 채 타는 적
    func startBoard() {
        contrib = [:]; schedule(after: 0.3) { $0.emit(.runCheckpoint) }
        let L = line[ci], carry = foes().count
        sfx("door")
        enterCar(ci + 1, carry: true); fade = 0; leg = ci; legStart = tr.ex; qi = 0
        let reinf = stage.reinf
        let extra: [String] = carry > 0 ? (0..<(1 + carry / 4)).map { _ in reinf[rndInt(reinf.count)] } : []
        let base = carry > 0 ? Array((L.fight ?? []).prefix(1)) : (L.fight ?? [])
        let room = max(0, foeCap() - foes().count), list = Array((base + extra).prefix(room))
        if !list.isEmpty { spawnWave(list, fromDoors: true); say(carry > 0 ? "지원군이 탔다!" : "적이 탔다!", list.compactMap { data.enemy($0)?.name }.joined(separator: " · "), 1.8) }
        setState("board"); boardT = 2.2; doorWant = true; nextStop = ci < line.count ? line[ci].stop : nil
    }

    /// 웹 arr.sort(()=>Math.random()-.5) — V8 TimSort 를 짧은 배열(64 미만) 그대로: 첫 런 세기(CountAndMakeRun) → 이진 삽입 정렬.
    /// 비교 함수 호출 순서 · 횟수가 같아야 규칙 난수 소비가 웹과 같다
    func randomSort<T>(_ a: [T]) -> [T] {
        var arr = a
        let n = arr.count
        guard n > 1 else { return arr }
        var runLen = 2
        let desc = rnd() - 0.5 < 0          // Compare(a[1], a[0])
        var idx = 2
        while idx < n { let order = rnd() - 0.5; if desc ? order >= 0 : order < 0 { break }; runLen += 1; idx += 1 }
        if desc { arr[0..<runLen].reverse() }
        var start = runLen
        while start < n {
            let pivot = arr[start]
            var left = 0, right = start
            while left < right { let mid = left + ((right - left) >> 1); if rnd() - 0.5 < 0 { right = mid } else { left = mid + 1 } }
            var p = start
            while p > left { arr[p] = arr[p - 1]; p -= 1 }
            arr[left] = pivot
            start += 1
        }
        return arr
    }

    /// 웹 boardAt(enemies): 짧은 정차 · 도착 때 승객이 내리고 타며 적이 탄다
    func boardAt(_ enemies: [String]) {
        let pass = ents.filter { $0.pass && !$0.hidden && $0.goal == nil }
        func door(_ x: Double) -> Double { data.doors.reduce(9999.0) { b, d in abs((d.0 + d.1) / 2 - x) < abs(b - x) ? (d.0 + d.1) / 2 : b } }
        let shuffled = randomSort(pass)
        for a in shuffled.prefix(rndInt(3)) { a.goal = door(a.x); a.exiting = true; a.z = 0; setAnim(a, "walk") }   // 내리는 사람
        let n = 1 + rndInt(3)
        func taken(_ x: Double) -> Bool { ents.contains { $0.pass && !$0.exiting && abs(($0.goal ?? $0.x) - x) < 16 } }
        for k in 0..<n {   // 타는 사람
            let free = data.spots.filter { !taken($0.x) }
            if free.isEmpty { break }
            let (gx, pose) = free[rndInt(free.count)], dx = data.doors[k % 2]
            let mx = (dx.0 + dx.1) / 2
            let a = mkActor(.passenger(model: (k + uid) % 3), x: mx, z: 0, flip: gx < mx, pose: "b_walk0", remap: [0, 6, 7, 5][(k + ci) % 4], pass: true)
            a.passPose = pose == "sit" ? "sb_sit" : "sb_strap"; a.goal = gx; a.goalZ = pose == "sit" ? -2 : 1; setAnim(a, "walk"); ents.append(a)
        }
        if !enemies.isEmpty { spawnWave(enemies, fromDoors: true); say("적이 탔다!", enemies.compactMap { data.enemy($0)?.name }.joined(separator: " · "), 1.8) }
    }

    /// 웹 passengerUpdate(a, dt)
    func passengerUpdate(_ a: Actor, _ dt: Double) {
        if a.goal == nil && !a.dancer && (a.passPose == "sb_sit" || a.passPose == "sb_sitc") {
            let near = ents.contains { !$0.pass && !$0.dead && abs($0.x - a.x) < 40 && !["idle", "walk"].contains($0.anim) }
            let want = near ? "sb_sitc" : "sb_sit"
            if a.passPose != want { a.passPose = want; setAnim(a, "pass") }
        }
        if a.idleAct == "doze" && a.goal == nil { a.tilt += sin(time * 1.1 + a.x) > 0.55 ? 0.16 : 0 }
        if a.goal == nil && !a.exiting && tr.door > 0.05 && inDoor(a.x) { a.goal = outDoor(a.x); a.goalZ = a.z; setAnim(a, "walk"); return }   // 문이 열리면 비켜선다
        if a.goal == nil && a.passPose == "sb_strap" && a.anim == "pass", let hdx = a.handDX, a.strapX == nil {
            let hx = a.x + hdx, sx = data.strapX.reduce(data.strapX[0]) { abs($1 - hx) < abs($0 - hx) ? $1 : $0 }
            a.strapX = sx; a.x += sx - hx
        }
        guard let g = a.goal else { return }
        face(a, g)
        if moveTo(a, g, 30, dt) {
            if a.exiting { a.hidden = true; return }
            a.goal = nil; a.z = a.goalZ ?? 0; a.flip = rnd() < 0.5; a.handDX = nil; a.strapX = nil; setAnim(a, "pass")
        }
    }

    /// 웹 spawnWave(list, fromDoors)
    func spawnWave(_ list: [String], fromDoors: Bool) {
        let sg = Double(stageIdx), m = (1 + 0.12 * Double(ci)) * (1 + 0.25 * sg), hx = hero?.x ?? 40
        let W = data.sbW, dL = hx - 22, dR = W - 22 - hx, nearL = dL < dR ? dL >= 70 : dR < 70
        for (k, t) in list.enumerated() {
            guard let T = data.enemy(t) else { continue }
            let left = fromDoors ? false : (k % 2 == 0 ? nearL : (nearL ? (dR >= 70 ? false : true) : (dL >= 70 ? true : false)))
            let x = fromDoors ? data.doors[k % 2].0 + 17 : (left ? 22 + (k > 2 ? 14 : 0) : W - 22 - (k > 1 ? 18 * Double(k - 1) : 0))
            let e = Enemy(t: t, def: T, hp: jsRound(T.hp * m), dmg: jsRound(T.dmg * 0.8 * (1 + 0.08 * Double(ci)) * (1 + 0.15 * sg)), cd: T.cd * 1.2, cdT: -0.8 - Double(k) * 0.6)
            metaFoe(t)
            let a = mkActor(defFor(T, k), x: x, z: 1 + Double((k * 3) % 5), flip: !left, pose: "st0", remap: T.remap, grammar: T.grammar, e: e)
            ents.append(a)
            if T.boss == true { bossIntro(a) } else if k == 0 && rnd() < 0.7 { let bk = data.barks.isEmpty ? "" : data.barks[rndInt(data.barks.count)]; emit(.bark(actor: a.id, key: bk)) }
        }
        emit(.waveSpawned(types: list, fromDoors: fromDoors))
        nvKOArmed = true   // 네이티브 KO 마무리: 새 웨이브마다 한 번
    }
    func metaFoe(_ t: String, _ ko: Bool = false) { var r = meta.foes[t] ?? [0, 0]; if ko { r[1] += 1 } else { r[0] += 1 }; meta.foes[t] = r; emit(.metaChanged) }

    // MARK: 이동

    /// 웹 canAct
    func canAct(_ c: Actor) -> Bool { c.anim == "idle" || c.anim == "walk" || (nv && (c.anim == "nv_gdH" || c.anim == "nv_gdL")) }   // 네이티브: 가드 자세도 '쉬는 중'
    /// 웹 holding(c): 잡아 던지는 중
    func holding(_ c: Actor?) -> Bool { guard let c else { return false }; return c.anim == "throw" && ents.contains { $0.heldBy === c } }
    /// 웹 face(c, tx)
    func face(_ c: Actor, _ tx: Double) { if holding(c) { return }; c.flip = tx < c.x }
    /// 웹 moveTo(c, tx, spd, dt)
    @discardableResult
    func moveTo(_ c: Actor, _ tx: Double, _ spd: Double, _ dt: Double) -> Bool {
        let dx = tx - c.x
        if abs(dx) < 1.5 { if c.anim == "walk" { setAnim(c, "idle") }; return true }
        let mx = jsSign(dx) * min(abs(dx), spd * dt); c.x += mx
        c.gph += abs(mx) / (4 * 0.3 * 24) * ((mx * c.f) < -0.01 ? -1 : 1)
        if c.anim == "idle" || (nv && World.nvGuardStill.contains(c.anim)) { setAnim(c, "walk") }
        return false
    }
    /// 웹 runTo: 대시 접근
    @discardableResult
    func runTo(_ c: Actor, _ tx: Double, _ spd: Double, _ dt: Double) -> Bool {
        let dx = tx - c.x
        if abs(dx) < 1.5 { if c.anim == "walk" { setAnim(c, "idle") }; return true }
        let mx = jsSign(dx) * min(abs(dx), spd * dt); c.x += mx
        c.gph += abs(mx) / max(40, min(66, spd * 0.42))
        if c.anim == "idle" || (nv && World.nvGuardStill.contains(c.anim)) { setAnim(c, "walk") }
        let was = c.runU > gameTime - 0.05; c.runU = gameTime + 0.09
        if !was && mx != 0 { fx("dust", c.x - jsSign(mx) * 5, c.y, c.f); if c === hero { sfx("whoosh") } }   // 웹 dashFx 출발 먼지
        return false
    }
    /// 웹 approach(c, tx, spd, dt, rs, chase): 멀면 달린다(주인공 34px · 적 56px)
    @discardableResult
    func approach(_ c: Actor, _ tx: Double, _ spd: Double, _ dt: Double, _ rs: Double, _ chase: Bool = false) -> Bool {
        if nv { return nvApproach(c, tx, spd, dt, rs, chase) }   // 네이티브: 걷기 · 스텝 인 · 질주 · 미끄러져 서기(World+NativeMove)
        let far = abs(tx - c.x)
        if rs > spd && (far > (c === hero ? 34 : 56) || (chase && far > 1) || (c.runU > gameTime - 0.05 && far > 2)) { return runTo(c, tx, rs, dt) }
        return moveTo(c, tx, spd, dt)
    }
    /// 웹 inFront(att, t, reach)
    func inFront(_ att: Actor, _ t: Actor, _ reach: Double) -> Bool { let dx = (t.x - att.x) * att.f; return dx > -4 && dx <= reach + 4 }
    /// 웹 wpnReach(mv, wpn)
    func wpnReach(_ mv: String?, _ wpn: String?) -> Double {
        if mv == "bat" { return wpn == "w_wrench" ? 36 : wpn == "w_case" ? 32 : 30 }
        if mv == "jab" && wpn == "w_umb" { return 40 }
        if mv == "jab" && wpn == "w_paper" { return 28 }
        return mv.flatMap { data.moveReach[$0] } ?? 24
    }
    /// 웹 doorOpenAt(x)
    func doorOpenAt(_ x: Double) -> Bool {
        if nvSnow?.held == true { return false }   // 네이티브 눈 승강장: 바깥이라 문이 없다
        if let T = tw { return T.door > 0.75 && x > TWR.G0 + 8 && x < TWR.G1 - 8 }   // 타워: 엘리베이터 문
        return tr.door > 0.6 && data.doors.contains { x > $0.0 - 4 && x < $0.1 + 4 }
    }

    // MARK: 피해

    /// 웹 damage(att, tgt, dmg, o)
    func damage(_ att: Actor, _ tgt: Actor, _ dmg0: Double, _ o0: HitOpts = HitOpts()) {
        var dmg = dmg0, o = o0
        let H = hero!
        var nvCrash = false
        if nvG {   // 네이티브 공방: 가드 · 높이 · 가드 크래시(World+NativeGuard)
            switch nvGuardCheck(att, tgt, dmg, o) {
            case .blocked: nvc.blockedNow = true; return
            case .crash: nvCrash = true; if att === H { dmg = jsRound(dmg * 1.5) }   // 가드를 부수는 한 방은 ×1.5
            case .none:
                if att === H, tgt.e != nil, tgt.nvg.inited {
                    if time < tgt.nvg.crashUntil { dmg = jsRound(dmg * 1.3); o.crit = true }   // 무방비: 치명 · ×1.3
                    if time - tgt.nvg.blockAt < 3 && tgt.nvg.blockN > 0 { nvCountExchange(tgt) }   // 막힘 → 뚫음
                }
            }
        }
        if tgt === H { hurtAt = time }
        if att === H, let bb = bossBreak, tgt === bb.a { dmg = jsRound(dmg * (croute != nil ? 1.6 : 1.3)) }   // 무너진 두목: 콤보 ×1.6 · 그 밖 ×1.3
        if att === H, let J = tgt.jug { dmg = max(1, jsRound(dmg * max(data.jugScaleMin, pow(data.jugScaleK, Double(J.n + 1))))) }   // 공중 타격 피해 감소
        if demo, att === H, tgt.dojo, let S = dj?.seq, let k = S.cur { S.hits[k, default: 0] += 1; if tgt.jug != nil { S.airs.insert(k) } }   // 무도장: 단계별 적중 기록
        if att === H && tgt.anim == "spinout" && (tgt.pose == "so1" || tgt.pose == "so2") { o.crit = true; o.backHit = true; dmg = jsRound(dmg * 1.5) }   // 돌아선 등: 반드시 치명타
        if tgt.e == nil && (spc != nil || cut != nil) { return }   // 필살기 · 컷인 중엔 주인공 무적
        if att === H && prologue { dmg = jsRound(dmg * 1.5); lampKick(tgt.x, (o.knock || o.crit) ? 1.6 : 0.7) }   // 장도리 · 충격에 전등이 흔들린다
        if att === H && tgt.e != nil, let cs = curSrc { contribAdd(cs, dmg) }
        let f = att.f * (o.back ? -1 : 1)
        if let e = tgt.e, let ev = e.evade, ev != 0, att === H, canAct(tgt), !o.crit, !o.splash, !o.pierce, rnd() < ev {   // 얍삽한 놈: 쓱 빠진다
            setAnim(tgt, "evade"); tgt.kb = f * 120; e.cdT = max(e.cdT, e.cd - 0.5); flashText("MISS", 0.5); emit(.evaded(target: tgt.id)); return
        }
        if let e = tgt.e, e.shield, !o.counter, !o.pierce, time > e.shieldT, inFront(tgt, att, 40) {   // 우산으로 막음 · 권법가는 팔로 쳐낸다
            e.shieldT = time + (e.parry ? 2.2 : 3); setAnim(tgt, e.parry ? "parry" : "hitB"); fx("spark", tgt.x + tgt.f * 6, tgt.y - 38); freeze = 2
            let kind: BlockKind = e.parry ? .parry : e.lamp ? .lamp : e.pan ? .pan : .shield
            if e.parry { flashText("BLOCK", 0.4) } else if e.lamp { flashText("BLIND", 0.4) } else if e.pan { flashText("CLANG", 0.4) }
            emit(.blocked(target: tgt.id, kind: kind)); return
        }
        var chit = false
        if att === H, tgt.e != nil, !o.counter, !o.splash, !demo, !tgt.dead, tgt.jug == nil, let A = tgt.action, !A.fired, let wu = tgt.windup, time - wu < 1,
           let lm = tgt.lastMove, data.foeW[lm] != nil, !data.reacts.contains(tgt.anim) { chit = true }
        if chit { dmg = jsRound(dmg * 1.25) }   // 받아치기: 준비하는 순간에 맞히면 ×1.25
        if let e = tgt.e { e.hp -= dmg; stats.dealt += dmg; score += jsRoundI(dmg * 10 * crowdK()) } else { hp -= dmg; stats.taken += dmg }
        if demo && (tgt.dojo || tgt === H) {   // 무도장 화면: 마지막 타격(웹 DJ.hit)
            dj?.hit = DojoView.Hit(me: tgt === H, n: tgt === H ? att.anim : djMoveName(), dmg: dmg, crit: o.crit, air: tgt.jug != nil, r: o.react ?? (o.knock ? "knock" : o.blast ? "blast" : ""))
        }
        if att === H && tgt.e != nil { spcGain(o.crit ? 3 : 2) }
        if tgt.e == nil { spcGain(1) }
        if let e = tgt.e, e.boss, data.bossInfo[e.t] != nil, !e.raged, e.hp > 0, e.hp < e.max * 0.5, spc == nil { bossRage(tgt) }   // 두목 분노
        if let e = tgt.e, e.boss, e.hp > 0, spc == nil, bossBreak == nil, !demo {
            let k = e.hp / e.max, n = e.brk
            if (n == 0 && k < 0.75) || (n == 1 && k < 0.3) { bossBreakStart(tgt) }   // 두목 무너지는 순간
        }
        if att === H && tgt.e != nil {
            combo = time - (lastHit ?? -9) < comboWin() ? combo + 1 : 1
            if combo % 5 == 0 { spcGain(5) }
            lastHit = time; stats.maxCombo = max(stats.maxCombo, combo)
            emit(.comboStep(count: combo))
        }
        let dead = tgt.e.map { $0.hp <= 0 } ?? (hp <= 0), kres = tgt.e?.heavy == true ? 0.35 : 1.0
        let isBoss = tgt.e?.boss == true
        var rk = tgt.def.jw ? reactKey(att, o) : (o.knock ? "fall" : o.react == "launch" ? "launch" : o.react == "body" ? "hitB" : "hit")
        if rk == "rKnee" && att === H && tgt.e != nil && !isBoss && srcLinked("crumple") { rk = "crumple" }   // 무너뜨리기 연계
        if rk == "rHook" && att === H && att.anim == "hook" && tgt.e != nil && !isBoss && tgt.jug == nil && srcLinked("spinout") { rk = "spinout" }   // 돌려 세우기
        if att === H && att.anim == "uthrust" && tgt.e != nil && !isBoss && tgt.jug == nil && abs(tgt.x - att.x) > 22 && srcLinked("pull") { rk = "pulled" }   // 우산 걸어 당기기
        if !dead && rk == "rStomp" { fx("ring", tgt.x, tgt.y - 8); groundImpact(tgt.x, tgt.y, 0.6) }
        if att === H && att.anim == "scoop" && data.falls.contains(tgt.anim) && tgt.jug == nil { tgt.anim = "idle" }   // 바닥에서 들어 올리기
        if o.blast && att === H && tgt.e != nil && !isBoss && tgt.def.jw && ["rKick", "hitB", "rSpin", "rHook", "fall"].contains(rk) { rk = "rBlast" }   // 콤보 마무리: 일직선
        if chit && !dead && !isBoss && tgt.def.jw && ["hitB", "rKnee", "rElbow"].contains(rk) { rk = "crumple" }
        if nv && att === H && tgt.e != nil && tgt.def.jw && tgt.jug == nil {   // 네이티브 복싱 기술의 반응
            if att.anim == "nv_liver" && !isBoss { rk = "crumple" }              // 리버 블로: 숨이 막혀 무릎부터
            if att.anim == "nv_cork" && !isBoss && o.knock { rk = "rBlast" }      // 코크스크루: 일직선으로 날아간다
            if att.anim == "nv_stamp" && isBoss { rk = "hitB" }                   // 결재 쌍장: 두목은 날아가지 않고 버틴다
        }
        if o.just && !dead && tgt.e != nil && !isBoss && tgt.def.jw && tgt.jug == nil { rk = "crumple" }   // 저스트: 무릎부터 무너진다
        let spike = att === H && (att.anim == "axe" || att.anim == "axe_air" || att.anim == "hm_down") && tgt.e != nil && tgt.def.jw && !tgt.held && !bonus
        if spike {   // 도끼 차기: 얼굴부터 바닥에 꽂는다
            rk = "rSpike"; let h0 = tgt.jug.map { max(0, $0.h) } ?? max(0, tgt.airOv)
            tgt.jug = nil; tgt.spike = (h0, 0, h0 > 2 ? 0.07 : 0.02); tgt.airOv = h0; tgt.action = nil; tgt.queue = []
        }
        let airy = !spike && tgt.e != nil && tgt.def.jw && !tgt.held && !bonus && (tgt.jug != nil || (data.launch[rk] != nil && (dead || !isBoss)))
        if att === H && tgt.e != nil {   // 개발용: 실전 반응 분포
            let key = (spike ? "rSpike" : airy ? (tgt.jug != nil ? "공중:" : "뜸:") + rk : rk) + (dead ? "†" : "")
            stats.rk[key, default: 0] += 1
        }
        if dead {
            tgt.dead = true
            if tgt.e == nil { hp = 0; tgt.keepBody = true }
            if airy { jugHit(tgt, rk, f, att, o, kres); tgt.jug?.die = true }
            else {
                let crumD = (o.crit || chit) && att === H && ["hit", "hitB", "rCross", "rHook", "rKnee", "rElbow"].contains(rk)
                setAnim(tgt, tgt.def.jw ? (crumD ? "crumpleD" : deathOf(rk)) : "death"); tgt.kb = f * (data.reactKB[rk] ?? 80) * kres
            }
            if let e = tgt.e {
                kills += 1; score += 100 * (e.boss ? 10 : 1); drop(tgt); metaFoe(e.t, true)
                emit(.foeDowned(target: tgt.id, cause: e.boss ? .boss : (foes().isEmpty ? .last : .ko), at: SIMD2(tgt.x, tgt.y)))
            }
        }
        else if isBoss && (tgt.anim == "bat" || tgt.anim == "round") && !data.falls.contains(rk) { }   // 두목은 큰 휘두르기 중엔 버틴다
        else if airy { jugHit(tgt, rk, f, att, o, kres) }
        else if spike { setAnim(tgt, "rSpike"); tgt.after = "getupP"; tgt.kb = 0 }   // 엎어진 채 손 짚고 일어난다
        else if tgt.anim == "crumple" && rk != "crumple" && !o.knock { tgt.kb = f * 8 }
        else {
            setAnim(tgt, rk); if data.falls.contains(rk) { tgt.after = "getup" }; tgt.kb = f * (data.reactKB[rk] ?? 40) * kres
            if rk == "rKnee", let e = tgt.e { e.stun = max(e.stun, 0.45) }
            if nv && att === H && att.anim == "nv_liver", let e = tgt.e { e.stun = max(e.stun, isBoss ? 0.5 : 0.9) }
            if let e = tgt.e, !e.boss, !data.falls.contains(rk) {
                if chit { e.stun = max(e.stun, 0.8) }   // 받아치기: 맞고 나서 휘청
                else if !e.stagD && e.hp < e.max * 0.3 { e.stagD = true; e.stun = max(e.stun, 0.7) }   // 빈사: 한 번 휘청
            }
        }
        // 히트스톱 · 흔들림
        let big = o.crit || o.knock || o.react == "launch"
        let hs = max(1, jsRoundI(Double(BF(Gstop)) * (o.bigCrit ? 1.9 : o.crit ? 1.5 : o.knock ? 1.3 : 0.8)))
        let hsT = tgt.jug != nil ? min(hs, BF(big ? 2.6 : 1.8)) : hs
        tgt.flash = big ? 2 : 1; tgt.hs = spike ? 1 : hsT; tgt.hs0 = tgt.hs; tgt.shkA = big ? 2 : 1
        if att.def.jw { att.hs = max(att.hs, hsT); if !o.back { att.x += f * 2 } }
        shoveX += f * (o.bigCrit ? 6 : big ? 4 : 2.2)
        let nvKO = dead && att === H && tgt.e != nil && (foes().isEmpty || isBoss) && nvKOTry(tgt, f)   // 네이티브 KO 마무리(깃발 켜짐 — 슬로 → 정지 순서로 대신한다)
        if dead && att === H && tgt.e != nil && (foes().isEmpty || isBoss) && !nvKO { freeze = BF(Gstop) }   // 마지막 한 방만 화면 전체를 멈춘다
        var chitFlash = false
        if chit { stats.chits += 1; if time - (chT ?? -9) >= 1.2 { chT = time; slowT = max(slowT, 0.1); chitFlash = true; comicSFX(tgt.x, tgt.y - 96, "받아치기!", force: true) } }
        var info = HitInfo(attacker: att.id, target: tgt.id, damage: Int(dmg), reaction: rk)
        info.crit = o.crit; info.bigCrit = o.bigCrit; info.counter = o.counter || chit; info.just = o.just; info.back = o.back || o.backHit
        info.dead = dead; info.airborne = tgt.jug != nil; info.heroWasHit = tgt === H; info.at = SIMD2(tgt.x, tgt.y)
        info.weight = big ? .heavy : .light
        if att === H && tgt.e != nil {
            let hk = hitKind(att.anim, big || rk == "rSlam")
            if hk == "hammer" { info.soundKind = "hammer" } else {
                let tr3 = hitTier(att.anim, o, rk); stats.snd[tr3] += 1
                info.soundTier = tr3; info.soundKind = hk
            }
            if let F = data.atkFeel[att.anim] { info.weight = HitWeight(rawValue: F.w) ?? info.weight }
        }
        let shown = Int(jsRound(dmg * data.dmgK))
        if tgt.uid == nil { uid += 1; tgt.uid = uid }   // 웹 tgt.uid=tgt.uid||++GS.uid — GS.uid 는 아이템과 같이 센다(defFor 머리 · boardAt 승객 모델이 읽는다)
        if att === H && tgt.e != nil { comboDmg = (combo > 1 ? comboDmg : 0) + shown }
        emit(.damagePop(target: tgt.id, value: shown, style: tgt.e != nil ? (o.crit ? "crit" : "hit") : "hurt",
                        label: o.just ? "JUST!" : (o.counter || chit) ? "COUNTER" : (o.back || o.backHit) ? (o.crit ? "BACK CRITICAL" : "BACK ATTACK") : o.crit ? (o.bigCrit ? "CRITICAL!!" : "CRITICAL") : nil))
        let heavy = o.knock || o.react == "launch" || (o.crit && dead)
        if tgt.e == nil { emit(.heroHurt(weight: HitWeight(rawValue: att.lastMove.flatMap { data.foeW[$0] } ?? "L") ?? .light)) }
        if att === H, let e = tgt.e {
            let word: String? = dead && (foes().isEmpty || e.boss) ? "KA-BOOM!" : o.counter ? "BLAM!" : rk == "rSlam" ? "SLAM!" : o.bigCrit ? "KRAK!" : (o.back && (o.crit || data.falls.contains(rk))) ? "THWAK!" : data.falls.contains(rk) ? "WHAM!" : nil
            if let word, !chit, !o.just, !(nv && att.anim == "nv_punt" && word == "WHAM!") { comicSFX(tgt.x, tgt.y - 86, word) }   // 구두 슛은 '뻥!' 하나만(World+NativePunt)
        }
        // 카메라(웹 27-actors damage 그대로): 흔들림은 big?2:1 로 덮어쓴 뒤 자리마다 덮어쓰기/최댓값, 줌은 자리마다 더하기/최댓값 + 상한.
        // 흔들림 최종값은 맨 끝에 한 번(shakeSet) — 줌은 순서대로 모드를 달아 낸다(CameraDirector 가 웹 식으로 합친다)
        var amp = big ? 2.0 : 1.0
        let focus = SIMD2(tgt.x, tgt.y - 40)
        if att === H && tgt.e != nil && o.crit && !heavy {
            amp = o.bigCrit ? 2 : 1
            var k = CameraKick(); k.zoom = o.bigCrit ? 0.035 : 0.022; k.zoomMode = .add(cap: 0.06); k.focus = focus; emit(.camera(k))
        }
        if att === H && tgt.e != nil && heavy {
            amp = 3
            var k = CameraKick(); k.zoom = 0.055; k.zoomMode = .add(cap: 0.09); k.focus = focus; k.invertFrames = 2; emit(.camera(k))
            if dead && (foes().isEmpty || isBoss) { if !nvKO { slowT = 0.9 }; var z = CameraKick(); z.zoom = 0.12; z.zoomMode = .set; z.slowmo = 0.9; emit(.camera(z)) }
            if dead && tgt.e?.t == "kaneB" { schedule(after: 0.7) { $0.say("빅터 케인", "…보스가 왜 너를 골랐는지 알겠군.", 2.8) } }
        } else if tgt.e == nil && heavy {   // 주인공이 넘어뜨리는 공격에 맞음(웹 !tgt.e && heavy)
            var k = CameraKick(); k.zoom = 0.03; k.zoomMode = .add(cap: 0.05); k.focus = focus; emit(.camera(k))
        }
        if tgt === H, att.e != nil, let w = data.foeW[att.anim] {
            let K: (hs: Double, sh: Double) = w == "L" ? (0.8, 1) : w == "M" ? (1, 1.6) : (1.35, 2.6)
            tgt.hs = max(1, jsRoundI(Double(tgt.hs != 0 ? tgt.hs : 1) * K.hs)); att.hs = max(att.hs, tgt.hs); amp = max(amp, K.sh)
            if w == "H" { var k = CameraKick(); k.zoom = 0.05; k.zoomMode = .max(cap: 0.1); k.focus = focus; emit(.camera(k)) }   // 웹: 무거운 적 공격 줌
        }
        if att === H, let F = data.atkFeel[att.anim] {
            tgt.hs = max(1, jsRoundI(Double(tgt.hs != 0 ? tgt.hs : 1) * F.hs)); att.hs = max(att.hs, tgt.hs); amp = max(amp, F.shake)
            if F.zoom > 0 { var k = CameraKick(); k.zoom = F.zoom; k.zoomMode = .max(cap: 0.12); k.focus = focus; emit(.camera(k)) }
            if F.dust != nil { fx("dust", att.x - att.f * 5, att.y, att.f) }
        }
        do { var k = CameraKick(); k.shake = amp; k.shakeSet = true; emit(.camera(k)) }
        info.freezeFrames = tgt.hs
        info.low = o.low; info.splash = o.splash; info.big = big; info.chit = chit; info.chitFlash = chitFlash
        info.attackerAnim = att.anim; info.targetAnim = tgt.anim; info.attackerIsHero = att === H; info.dir = f
        info.targetJugH = tgt.jug?.h ?? 0; info.targetAirOv = tgt.airOv
        info.knock = o.knock; info.reactOpt = o.react
        emit(.hit(info))
        if nvCrash { nvGuardCrash(att, tgt, dead: dead) }
    }

    /// 웹 heroSkill(i, manual): 기술의 큐 자세에서 실제 피해
    func heroSkill(_ i: Int, _ manual: Bool) {
        guard bag.indices.contains(i), let H = hero else { return }
        let b = bag[i]; guard let it = item(b.id) else { return }
        let st = sStats(i)
        let reach = it.combo == true ? (data.moveReach[["jab", "cross", "hook", "upper"][b.combo ?? 0]] ?? 24) : (it.reach ?? 0) + (it.cond == "counter" ? pv("ear", 6, 2) : 0)
        func inBack(_ t: Actor, _ r: Double) -> Bool { let dx = (t.x - H.x) * H.f; return dx < 4 && dx >= -(r + 4) }
        var T = foes().filter { t in
            (it.back == true ? inBack(t, reach) : inFront(H, t, reach + (t.jug != nil ? 8 : 0))) && !t.held && !(t.jug != nil && t.jug!.h > 66) && (it.cond != "air" || t.jug != nil)
                && (it.cond == "down" ? (isFalling(t) || (t.jug != nil && !t.jug!.gb && t.jug!.h < 36 && bagHasLink("gbounce")))
                                      : (!isDown(t) || (H.anim == "scoop" && time - ((t.tripLandT ?? 0) != 0 ? t.tripLandT! : -9) < 0.6)))
        }
        T = stableSortD(T) { abs($0.x - H.x) - abs($1.x - H.x) }
        if it.area != true { T = Array(T.prefix(1)) }
        let cm = b.combo ?? 0, dm = it.combo == true ? [1, 1.6, 2, 2.4][cm] : 1.0
        let react: String? = it.cond == "down" ? "down" : it.combo == true ? ["head", "head", "head", "launch"][cm] : it.react
        let emp = (b.emp || dodgeEmp > time) ? 1.5 : 1.0
        if !T.isEmpty { b.emp = false; dodgeEmp = 0 }   // 피하고 반격: 다음 한 방 +50%
        let sigB = sigCheck(b), finB = croute?.uids.contains(b.uid) ?? false
        for t in T { t.finKill = finB || sigB != nil; t.sigKill = sigB != nil }
        var anyCrit = false; curSrc = b.uid
        var nvAllBlocked = nvG && !T.isEmpty
        for t in T {
            let critOff = nv && demo && dj?.crit == false   // 네이티브 무도장 '치명 끄기': '항상 치명' 아이템까지 치명 없음(난수도 굴리지 않는다)
            let crit = !critOff && (it.crit == true || rnd() < st.crit + (manual && !(nv && demo) ? 0.1 : 0))   // 네이티브 무도장: 시연은 직접 누름 보너스(+10%) 없이(감독 피드백 2026-10-14 — 치명타가 너무 잦다)
            if crit { stats.crits += 1; anyCrit = true }
            var o = HitOpts(); o.crit = crit; o.bigCrit = crit && st.critD >= 2.2; o.knock = it.knock == true; o.react = react; o.back = it.back == true
            o.pierce = nv && (it.anim == "nv_cork" || it.anim == "nv_headbutt")   // 코크스크루 · 멱살 박치기(잡기): 방패 · 쳐내기 · 피하기를 뚫는다
            o.low = it.low == true || ["kick", "sweep", "stomp", "bkick"].contains(H.anim)
            o.blast = rules.role(b.id) == "F" && ((finB && croute != nil && croute!.fin)
                || (demo && dj?.seq != nil && !dj!.seq!.single && dj!.seq!.steps.count > 1 && dj!.seq!.cur == dj!.seq!.steps.count - 1))   // 무도장 시연의 마지막 단계도 콤보 마무리
            if nvG { nvc.blockedNow = false }
            damage(H, t, max(1, jsRound(st.dmg * dm * emp * comboMul(b) * (b.opener ? 0.4 : 1) * (crit ? st.critD : 1))), o)
            if nvG && nvc.blockedNow { continue }   // 막혔다: 경직 · 연계 없음
            nvAllBlocked = false
            if let s = it.stun, s != 0, let e = t.e, !t.dead { e.stun = s; t.action = nil; t.queue = [] }
        }
        for t in T where !t.dead { t.finKill = false; t.sigKill = false }
        if let sb = sigB, !T.isEmpty { croute?.sig = true; sigFire(sb, T[0]) }
        if let bb = bossBreak, croute != nil, T.contains(where: { $0 === bb.a }) { slowT = max(slowT, 0.1) }   // 무너진 두목에게 콤보: 짧은 슬로
        curSrc = nil; emit(.bagPulse(uid: b.uid, kind: T.isEmpty ? "fire" : anyCrit ? "crit" : "fire")); if !T.isEmpty { contribTrig(b.uid) }
        cmdSkill(b, anyCrit, cm); if !T.isEmpty { watchFlow(b) }
        if !T.isEmpty && !nvAllBlocked, let bi = bag.firstIndex(where: { $0 === b }) {
            linkFire(bi, "hit"); if it.knock == true || react == "sweep" { linkFire(bi, "knock") }; if react == "launch" { linkFire(bi, "launch") }; if b.id == "sweep" { linkFire(bi, "trip") }
            if b.id == "punch" && T.contains(where: { $0.anim == "spinout" }) { linkFire(bi, "spin") }
            if b.id == "umb" && T.contains(where: { $0.anim == "pulled" }) { linkFire(bi, "pull") }
            comboOpen(bi, stableSortD(T) { abs($0.x - H.x) - abs($1.x - H.x) }[0])   // 콤보 대상: 가장 가까운 적
            if let C = croute, C.uids.contains(b.uid) { C.hits += 1 }
        }
    }

    /// 웹 foeHit(a): 적의 큐 자세에서 주인공 피해
    func foeHit(_ a: Actor) {
        guard let H = hero, !H.dead, let e = a.e, !(e.stun > 0) else { return }
        if e.hitrun { e.retreatT = 1.1 }
        if !inFront(a, H, wpnReach(a.lastMove, e.wpn)) { return }
        if nv && nvSlipPose(H) {   // 네이티브 숄더 롤: 앞어깨로 흘려 보낸다(흘리는 순간 바람 + 잔상)
            e.stun = max(e.stun, 0.6); e.cdT = min(e.cdT, -0.3); stats.dodges += 1; sfx("dodge"); score += 80
            fxD(FxDetail(kind: "nv_speed", x: H.x, y: H.y - 34, dir: H.f))
            flashText("SLIP", 0.6); comicSFX(a.x, a.y - 86, "흘렸다!"); emit(.perfectDodge(by: H.id)); return
        }
        if nv && nvRiseDodges(H, NativeContent.foeHeight(a.lastMove ?? a.anim)) {   // 네이티브 퇴근 승천권: 솟는 무적 칸 · 오름 칸의 상단은 빗나간다
            stats.nvg.riseInvuln += 1; sfx("dodge"); fxD(FxDetail(kind: "nv_speed", x: H.x, y: H.y - 34, dir: H.f))
            return
        }
        if nv, let lm = a.lastMove, data.foeW[lm] == "H" && isDucking(H) && duckSlot() < 0 {   // 네이티브 맨손 숙이기: 피하기만(보상은 쭈그리기 아이템이 있을 때)
            stats.dodges += 1; sfx("dodge"); flashText("DODGE", 0.5); return
        }
        if let lm = a.lastMove, data.foeW[lm] == "H" && isDucking(H) {   // 완벽 회피
            e.stun = 1.0; e.cdT = -0.4; dodgeEmp = time + 3; slowT = max(slowT, 0.25); sfx("dodge"); score += 120
            stats.dodges += 1; stats.perfectDodges += 1; flashText("DODGE!", 0.8); comicSFX(a.x, a.y - 86, "빈틈!"); emit(.perfectDodge(by: H.id))
            let di = duckSlot(); if di >= 0 { linkFire(di, "dodge") }
            cmdPush("완벽 회피"); return
        }
        if e.hitrun { let st = min(score, 150); score -= st; if st > 0 { emit(.textPop(x: H.x - 8, y: H.y - 78, text: "-\(st)")) } }
        let km: [String: Double] = ["jab": 1, "hook": 1.3, "hbutt": 1.2, "kick": 1.3, "bat": 1.5, "round": 1.6, "upper": 1.5, "charge": 1.4, "fkick": 1.6]
        let k = a.lastMove.flatMap { km[$0] ?? (nv ? NativeContent.foeKM[$0] : nil) } ?? 1
        let guardK = sets["grap"] != nil ? 1 - (data.catalog.families["grap"]?.guard_ ?? 0.15) : 1
        var o = HitOpts()
        o.knock = (["bat", "round"].contains(a.lastMove ?? "") && e.heavy) || a.lastMove == "charge" || a.lastMove == "fkick"
        o.react = a.lastMove == "upper" ? "launch" : "head"
        damage(a, H, jsRound(e.dmg * k * (e.flankHit ? 0.8 : 1) * max(0.5, 1 - pv("armor", 0.1, 0.03)) * guardK), o)
    }

    /// 웹 drop(a): 쓰러진 적이 떨어뜨리는 것(서류 · 고기 · 동전)
    func drop(_ a: Actor) {
        guard let e = a.e else { return }
        if e.boss, let bb = bossBreak, bb.a === a, a.finKill || a.sigKill { bossScene(a) }   // 무너진 동안 콤보로 쓰러뜨리면 명장면
        let r = rnd(), gp = prologue ? 0 : e.boss ? 1 : a.sigKill ? 0.55 : a.finKill ? 0.3 : 0.14
        if a.finKill || a.sigKill { stats.comboKills += 1 }
        if e.meat { items.append(FloorItem(kind: "meat", x: a.x + 6, z: a.z)) }
        if r < gp {
            items.append(FloorItem(kind: "gear", id: pickGear(), x: a.x, z: a.z))
            if a.finKill || a.sigKill { stats.finPages += 1; emit(.textPop(x: a.x - 12, y: a.y - 74, text: "서류!")) }
        } else if r < gp + 0.31 { items.append(FloorItem(kind: "meat", x: a.x, z: a.z)) }
        else if r < gp + 0.56 { items.append(FloorItem(kind: "coin", x: a.x, z: a.z)) }
        if let last = items.last, r < gp + 0.56 || e.meat { emit(.itemDropped(kind: last.kind, x: last.x)) }
    }
    /// 웹 REAL_ITEMS · pickGear
    func realItems() -> [String] { data.game.items.keys.filter { data.game.items[$0]?.pro != true } }
    func pickGear() -> String { let ks = realItems(); return ks[rndInt(ks.count)] }

    /// 웹 pickup(): 주인공 발밑 10px 안
    func pickup() {
        guard let H = hero else { return }
        var i = items.count - 1
        while i >= 0 {
            defer { i -= 1 }
            guard i < items.count else { continue }
            let it = items[i]
            if abs(it.x - H.x) > 10 { continue }
            if it.kind == "meat" {
                let v = min(25, maxHP - hp); if v <= 0 { continue }
                hp += v; emit(.damagePop(target: H.id, value: Int(jsRound(v * data.dmgK)), style: "heal", label: nil))
            } else if it.kind == "coin" {
                score += 300; tokens += 1; sfx("coin"); emit(.textPop(x: H.x - 6, y: H.y - 70, text: "+1")); renderBag()
            } else if let id = it.id { gainGear(id, it.tier ?? 1, rollOpt(id, 0.35)) }
            emit(.pickedUp(kind: it.kind, item: it.id))
            if i < items.count { items.remove(at: i) }
        }
    }

    /// 웹 pickSkill(H, T, F): 쿨다운 · 조건이 맞는 기술 중 피해 가중 추첨(조건 기술 2.2배)
    func pickSkill(_ H: Actor, _ T: Actor?, _ F: [Actor]) -> Int {
        var c: [(Int, Double)] = []
        for (i, b) in bag.enumerated() {
            guard let it = item(b.id) else { continue }
            if it.kind != "skill" || b.t < cdOf(i) || !condOK(it.cond, H, T, F) || soloSkip(b) { continue }
            var w = sStats(i).dmg * (it.cond != nil ? 2.2 : 1)
            if nvG { w *= nvHeightWeight(i, T) }   // 네이티브: 상대 가드를 이기는 높이
            c.append((i, w))
        }
        if c.isEmpty { return -1 }
        var w = c.reduce(0) { $0 + $1.1 } * rnd()
        for (i, d) in c { w -= d; if w <= 0 { return i } }
        return c[0].0
    }

    /// 목록에서 빠지는 인물: 동작 요청 클로저(인물을 붙잡는다)를 놓아 순환 참조를 끊는다
    func retire(_ a: Actor) { a.action = nil; a.queue = []; a.heldBy = nil }

    func setState(_ s: String) { if state != s { state = s; emit(.stateChanged(s)) } }
}
