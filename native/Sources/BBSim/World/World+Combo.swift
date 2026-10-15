import Foundation
import BBContent

// 웹 32-block-art.js 규칙 부분: 콤보 경로 실행(liveSt · routeSets · soloSkip · comboMul · comboOpen · comboOnUse · comboPick · comboTick · comboEnd) ·
// 고유 콤보 마무리(sigCheck · sigFire) · 두목 무너짐(bossBreak · bossScene) · 몸 간격(bodySep) · 벽꽝(wallCheck) · 볼링(bowlCheck).
// 경로 계산 자체는 Bag/ComboRoutes.swift(웹 대조 완료).

extension World {
    /// 웹 liveSt(T): 지금 목표의 상태 글자
    func liveSt(_ T: Actor?) -> String {
        guard let T else { return "G" }
        if let J = T.jug { return J.trip ? "T" : "A" }
        if T.anim == "crumple" || T.anim == "crumpleD" { return "C" }
        if T.anim == "spinout" { return "B" }
        if T.anim == "pulled" { return "P" }
        if data.falls.contains(T.anim) || isDown(T) { return "D" }
        if let e = T.e, e.stun > 0 { return "Z" }
        return "G"
    }
    /// 웹 routeSets(): 시작기 uid(S) · 경로 안 나머지(M) — 같은 시각엔 다시 계산하지 않는다
    func routeSets() -> (S: Set<Int>, M: Set<Int>) {
        if let c = routeSetsCache, c.time == time { return (c.S, c.M) }
        var S = Set<Int>(), M = Set<Int>()
        for r in rules.routes(bagStructs()) { S.insert(r.uids[0]); for u in r.uids.dropFirst() { M.insert(u) } }
        routeSetsCache = (time, S, M)
        return (S, M)
    }
    /// 웹 soloSkip(b): 시작기는 숨 고르기 동안 아껴 둔다
    func soloSkip(_ b: Item?) -> Bool {
        guard let b, croute == nil, !prologue else { return false }
        return routeSets().S.contains(b.uid) && comboCD > 0
    }
    /// 웹 comboMul(b)
    func comboMul(_ b: Item) -> Double { if let C = croute, C.uids.contains(b.uid) { return C.mul }; return 1 }

    /// 웹 comboOpen(i, T, chain): 시작기가 맞으면 콤보 창이 열린다
    func comboOpen(_ i: Int, _ T: Actor?, _ chain: Int = 0) {
        guard !demo, croute == nil, let T, !T.dead else { return }
        if chain == 0 && comboCD > 0 { return }
        guard bag.indices.contains(i) else { return }
        let b = bag[i]
        guard rules.role(b.id) == "S" else { return }
        let bs = bagStructs(), R = rules.route(from: b.bagItem, in: bs, state: "G")
        if R.count < 2 { return }
        let key = R.map { String($0.uid) }.joined(separator: ">"), n = comboUse[key] ?? 0
        let mul = max(0.7, 1 - 0.08 * Double(n)) * (lastCombo != nil && lastCombo != key ? 1.06 : 1)   // 같은 경로 반복은 약하게 감쇠 · 다른 콤보로 바꾸면 보너스
        croute = ComboRun(uids: R.map(\.uid), k: chain != 0 ? 0 : 1, key: key, name: rules.comboName(R), mul: mul, t: 2.4, T: T, chain: chain)
        emit(.comboRoute(name: croute!.name, step: croute!.k, length: R.count))
    }
    /// 웹 comboOnUse(b)
    func comboOnUse(_ b: Item) {
        guard let C = croute, C.k < C.uids.count, C.uids[C.k] == b.uid else { return }
        C.k += 1; C.t = 2.4; if rules.role(b.id) == "F" { C.fin = true }
        emit(.comboRoute(name: C.name, step: C.k, length: C.uids.count))
    }
    /// 웹 comboPick(H, T): 콤보 창 — 경로의 다음 블록(쿨다운 무시) · 상태가 안 맞으면 직전 블록의 다른 이웃으로 갈래
    func comboPick(_ H: Actor, _ T: Actor) -> Int {
        guard let C = croute else { return -1 }
        guard let tg = C.T, !tg.dead, tg.anim != "death" else { comboEnd(false); return -1 }
        if C.k >= C.uids.count { return -1 }
        let st = liveSt(tg)
        var b = bag.first { $0.uid == C.uids[C.k] }
        if b == nil || (C.k > 0 && !rules.fits(rules.stateIn(b!.id), st)) {
            let used = Array(C.uids.prefix(C.k)), usedSet = Set(used)
            let bs = bagStructs()
            var alt: BagItem?
            if let pv = bs.first(where: { $0.uid == used.last }) {
                let cand = rules.adjacentIn(bs, pv).filter { rules.isSkill($0) && !usedSet.contains($0.uid) && rules.role($0.id) != "X" && rules.fits(rules.stateIn($0.id), st) }
                alt = stableSort(cand) { a, c in
                    let pa = a.uid == pv.pin ? 0 : 1, pc = c.uid == pv.pin ? 0 : 1; if pa != pc { return pa - pc }
                    let fa = rules.stateIn(a.id) == st ? 0 : 1, fc = rules.stateIn(c.id) == st ? 0 : 1; if fa != fc { return fa - fc }
                    return rules.readKey(a) - rules.readKey(c)
                }.first
            }
            guard let alt else { comboEnd(false); return -1 }
            C.uids = used + rules.route(from: alt, in: bs, state: st, used: usedSet).map(\.uid); C.branch = true
            b = bag.first { $0.uid == alt.uid }
        }
        guard let bb = b else { return -1 }
        return bag.firstIndex { $0 === bb } ?? -1
    }
    /// 웹 comboTick(dt)
    func comboTick(_ dt: Double) {
        if comboCD > 0 { comboCD -= dt }
        let C = croute, H = hero
        comboIdle = (C != nil || !foes().contains { !$0.dead }) ? 0 : comboIdle + dt
        if let B = bossBreak { let t = B.t - dt; if t <= 0 || B.a.dead || !ents.contains(where: { $0 === B.a }) { bossBreak = nil } else { bossBreak!.t = t } }
        guard let C else { if on && !foes().contains(where: { !$0.dead }) { comboUse = [:] }; return }   // 싸움이 끝나면 반복 기록을 비운다
        C.t -= dt
        if C.t <= 0 { comboEnd(false); return }
        if C.k >= C.uids.count, let H, canAct(H) || (H.action != nil && H.action!.fired && !heroAirborne(H)) { comboEnd(true) }
    }
    /// 웹 comboEnd(done)
    func comboEnd(_ done: Bool) {
        guard let C = croute else { return }
        croute = nil
        if C.hits >= 2 {
            comboUse[C.key, default: 0] += 1; lastCombo = C.key; stats.combos += 1
            metaCombo(C)
            if !nv { say(C.name + (done && C.fin ? "!" : ""), "\(C.book != nil ? "도감 콤보 완성 · " : "")\(C.hits) HIT", 1.3) }   // 네이티브: 화면 가운데 콤보 이름 알림 없음(감독 2026-10-14 — 화면을 가린다)
        }
        emit(.comboEnded(count: C.hits, total: C.uids.count))
        if done && C.fin && C.chain == 0, let T = C.T, !T.dead, T.jug != nil {   // 콤보 잇기: 마무리 뒤에도 떠 있으면 다른 경로의 시작기로
            let st = liveSt(T)
            if let nx = rules.routes(bagStructs()).first(where: { r in !r.uids.contains(where: { C.uids.contains($0) }) && rules.fits(rules.stateIn(bag.first { $0.uid == r.uids[0] }?.id ?? ""), st) }),
               let i0 = bag.firstIndex(where: { $0.uid == nx.uids[0] }) {
                comboOpen(i0, T, 1)
                if let N = croute { N.name = "콤보 잇기 · " + N.name; N.hits = C.hits; return }
            }
        }
        comboCD = 3.5   // 숨 고르기
    }
    /// 웹 metaCombo · metaBook: 콤보 노트 · 도감 기록
    func metaCombo(_ C: ComboRun) {
        let ids = C.uids.compactMap { u in bag.first { $0.uid == u }?.id }
        if ids.count < 2 { return }
        let done = Array(ids.prefix(C.k != 0 ? C.k : ids.count))
        if let B = rules.recipe(done) {
            if prologue || pBag { if !meta.cseen.contains(B.id) { meta.cseen.insert(B.id); emit(.metaChanged) } }   // 프롤로그: 도감엔 목격만(웹 META.cseen)
            else {
                var e = meta.cbook[B.id] ?? [0, 0]; let fresh = meta.cbook[B.id] == nil; e[0] += 1; e[1] = max(e[1], C.hits); meta.cbook[B.id] = e
                if fresh { C.book = B.id; talkSoon("book1", B.id) }
            }
        }
        if prologue || pBag { return }   // 프롤로그 콤보는 노트에 기록하지 않는다
        let key = ids.joined(separator: ">")
        var e = meta.combos[key] ?? [0, 0]; e[0] += 1; e[1] = max(e[1], C.hits); meta.combos[key] = e
        if meta.comboNames[key] == nil { meta.comboNames[key] = C.name.replacingOccurrences(of: "콤보 잇기 · ", with: "") }
        emit(.metaChanged)
    }

    // MARK: 고유 콤보 마무리

    /// 웹 sigCheck(b): 지금까지 나간 순서가 도감 레시피와 딱 맞나
    func sigCheck(_ b: Item) -> ComboRecipe? {
        guard let C = croute, !C.sig, let k = C.uids.firstIndex(of: b.uid) else { return nil }
        var ids: [String] = []
        for u in C.uids.prefix(k + 1) { guard let o = bag.first(where: { $0.uid == u }) else { return nil }; ids.append(o.id) }
        guard let B = rules.recipe(ids), B.route.count == ids.count else { return nil }
        return B
    }
    /// 웹 sigFire(B, T): 고유 콤보 효과(주변 적 피해 · 띄우기 · 넘어뜨리기 · 경직)
    func sigFire(_ B: ComboRecipe, _ T: Actor) {
        guard let S = data.sig[B.id], let H = hero else { return }
        let x = T.x, y = T.y - 30 - (T.jug?.h ?? 0)
        comicSFX(x, y - 34, S.w, force: true); shake(3.4); slowT = max(slowT, 0.24); fx("sig_" + S.k, x, y, H.f)
        if S.k == "quake" { groundImpact(x, T.y, 1.6) }
        let sc = 1 + 0.15 * Double(ci) + 0.25 * Double(stageIdx)
        for a in foes() {
            if a === T || a.dead || a.held || a.e == nil || abs(a.x - x) > S.r { continue }
            a.sigKill = true; a.finKill = true
            if let stn = S.stun, stn != 0 { a.e!.stun = stn; a.action = nil; a.queue = []; damage(H, a, jsRound(S.dmg * sc), HitOpts()) }
            else { var o = HitOpts(); o.knock = S.react == nil; o.react = S.react; damage(H, a, jsRound(S.dmg * sc), o) }
            if !a.dead { a.sigKill = false; a.finKill = false }
        }
        stats.sigs += 1
    }

    // MARK: 두목

    /// 웹 bossBreak(a): 두목 무너지는 순간(체력 75% · 30%)
    func bossBreakStart(_ a: Actor) {
        guard let e = a.e else { return }
        e.brk += 1; bossBreak = (a, 3.2, 3.2); e.stun = 3.2; a.action = nil; a.queue = []
        comicSFX(a.x, a.y - 78, "무너졌다!", force: true); shake(3); slowT = max(slowT, 0.35); sfx("brass")
        comboCD = 0; let S = routeSets().S
        for (k, b) in bag.enumerated() where S.contains(b.uid) { b.t = max(b.t, cdOf(k)) }   // 숨 고르기 끝 · 시작기 바로
        stats.breaks += 1; emit(.bossBreak(actor: a.id))
    }
    /// 웹 bossScene(a): 무너진 동안 콤보로 쓰러뜨리면 명장면
    func bossScene(_ a: Actor) {
        items.append(FloorItem(kind: "gear", id: pickGear(), x: a.x + 10, z: a.z))
        emit(.textPop(x: a.x - 20, y: a.y - 92, text: "명장면!")); comicSFX(a.x, a.y - 84, "명장면!", force: true)
        if let t = a.e?.t { meta.bossScenes[t, default: 0] += 1; emit(.metaChanged) }
        stats.bossScenes += 1
    }

    // MARK: 몸 간격 · 벽 · 볼링

    func solidFoe(_ a: Actor) -> Bool { a.e != nil && !a.dead && !a.hidden && !a.held && a.jug == nil && a.spike == nil && !a.pass && !a.kane && !a.carDummy && !a.carOwner && !isDown(a) }
    /// 웹 bodySep(): 서 있는 몸끼리 너무 붙지 않게(주인공 ↔ 적 20px · 적끼리 14px)
    func bodySep() {
        guard let H = hero else { return }
        let F = ents.filter(solidFoe), W0 = AW0(), W1 = AW1()
        let heroSolid = !H.hidden && !H.dead && !heroAirborne(H) && !["throw", "suplex", "spcHold", "spcLift", "spcSlam"].contains(H.anim)
        if heroSolid {
            for a in F {
                let dx = a.x - H.x, ad = abs(dx); if ad >= data.sepHF { continue }
                let sd = ad > 0.5 ? jsSign(dx) : H.f, ov = data.sepHF - ad
                var fa = ov * 0.7, fh = ov * 0.3
                let nx = a.x + sd * fa
                if nx < W0 || nx > W1 { let room = sd > 0 ? W1 - a.x : a.x - W0; fa = max(0, room); fh = ov - fa }   // 벽에 붙은 적이면 주인공을 민다
                a.x += sd * fa; H.x = max(W0, min(W1, H.x - sd * fh))
            }
        }
        if F.count > 1 {
            for i in 0..<F.count { for j in (i + 1)..<F.count {
                let A = F[i], B = F[j], dx = B.x - A.x, ad = abs(dx); if ad >= data.sepFF { continue }
                let sd = ad > 0.5 ? jsSign(dx) : (i % 2 == 1 ? 1 : -1), ov = (data.sepFF - ad) * 0.5
                if nvG && !tower && !A.nvg.tok && !B.nvg.tok && (A.x > W1 || B.x > W1 || A.x < W0 || B.x < W0) {   // 네이티브 공방: 칸 끝 너머에서 기다리는 적끼리는 벽에 눌러 겹치지 않게
                    A.x -= sd * ov; B.x += sd * ov; continue
                }
                A.x = max(W0, min(W1, A.x - sd * ov)); B.x = max(W0, min(W1, B.x + sd * ov))
            } }
        }
    }
    /// 웹 wallCheck(a): 끝 벽까지 날아간 적은 벽에 부딪혀 튕겨 나온다
    func wallCheck(_ a: Actor) {
        if nv, let J = a.jug, J.nvWall { nvStampWallCheck(a, J); return }   // 네이티브 결재 쌍장 날림: 벽에 박힌다(무도장 벽 포함 — World+NativeOffice)
        if demo || a.dojo || state != "fight" || a.held || a.kane || a.carDummy || a.carOwner { return }
        let J = a.jug, vx = J?.vx ?? a.kb, dir = jsSign(vx), W0 = AW0(), W1 = AW1()
        if dir == 0 || abs(vx) < (J != nil ? 85 : 90) { return }
        if !(dir < 0 ? a.x <= W0 : a.x >= W1) || time - ((a.wallT ?? 0) != 0 ? a.wallT! : -9) < 0.5 { return }
        a.wallT = time
        let sp = abs(vx), h = J.map { max(0, $0.h) } ?? a.airOv, wx = dir < 0 ? W0 - 4 : W1 + 4
        a.x = dir < 0 ? W0 : W1
        if let J {
            J.vx = -dir * min(130, sp * 0.42); J.vy = max(J.vy, J.h < 30 ? 120 : 40); J.hitT = time + 0.18; J.wallP = time + 0.13; J.spinR *= 0.4; J.wallB = true; poleT = time; a.kb = J.vx
        } else {
            a.kb = -dir * min(110, sp * 0.45)
            if !a.dead && a.def.jw && !data.falls.contains(a.anim) { setAnim(a, "rWall"); if let e = a.e, !e.boss { e.stun = max(e.stun, 0.5) } }   // 서서 부딪히면 벽에 붙었다 휘청
        }
        a.hs = max(a.hs, 3); a.shkA = 2; shake(sp > 200 ? 2.8 : 2); shoveX += dir * 3
        fx("spark", wx, a.y - 26 - h); comicSFX(wx - dir * 20, a.y - 96 - h, "쾅!", force: true); sfx("thud")
        if nv { fx("wallImpact", dir < 0 ? W0 : W1, a.y - 22 - h, dir); emit(.haptic(.medium)) }   // 네이티브: 날아간 적이 벽에 부딪힌 자국(벽꿍과 같은 무대 픽셀) · 진동
        if let e = a.e, !a.dead {
            let dm = max(1, jsRound(4 * (1 + 0.12 * Double(ci))))
            if e.hp > dm { e.hp -= dm; stats.dealt += dm; score += 60; emit(.damagePop(target: a.id, value: Int(jsRound(dm * data.dmgK)), style: "hit", label: nil)) }
        }
        stats.walls += 1
    }
    /// 웹 bowlCheck(a): 크게 날아가는 적이 서 있는 적과 겹치면 넘어뜨린다
    func bowlCheck(_ a: Actor) {
        guard let H = hero else { return }
        let v = a.kb != 0 ? a.kb : (a.jug?.vx ?? 0)
        let sx = jsSign(v); if sx == 0 { return }
        let x0 = (a.bwt != nil && time - a.bwt! < 0.15) ? a.bwx! : a.x
        a.bwx = a.x; a.bwt = time
        let lo = min(x0, a.x) - 9, hi = max(x0, a.x) + 9
        for o in foes() {
            if o === a || o.dead || o.held || o.jug != nil || isDown(o) || o.bowlT > time { continue }
            if o.x < lo || o.x > hi || (o.x - x0) * sx < -3 { continue }
            o.bowlT = time + 1.2; o.finKill = croute != nil; comicSFX(o.x, o.y - 58, "볼링!", force: true)
            var opt = HitOpts(); opt.react = "sweep"
            damage(H, o, jsRound(6 * (1 + 0.15 * Double(ci))), opt); if !o.dead { o.finKill = false }
            if a.kb != 0 { a.kb *= 0.55 }; if let J = a.jug, J.vx != 0 { J.vx *= 0.55 }
            stats.bowls += 1; break
        }
    }
}
