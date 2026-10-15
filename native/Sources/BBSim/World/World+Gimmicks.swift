import Foundation

// 웹 37-gimmicks.js 규칙 부분: 환경 기술(envHit · envMove) · 반대편 열차 교행(passTrainUpdate) · 타격음 등급(hitTier · hitKind) ·
// 승객 이벤트(legEvent · evUpdate · crowdK) · 바닥 사물(propsInit · slipUpdate).

extension World {
    /// 웹 envHit(H, reach, dmg, o)
    func envHit(_ H: Actor, _ reach: Double, _ dmg: Double, _ o: HitOpts) {
        let f = H.f
        for a in foes() { let dx = (a.x - H.x) * f; if dx > -6 && dx < reach && !isDown(a) && !a.held { damage(H, a, jsRound(dmg * (1 + 0.12 * Double(ci))), o) } }
    }
    /// 웹 envMove(H, live): 기둥 회전차기 · 손잡이 매달려 차기 · 짐 상자 던지기
    func envMove(_ H: Actor, _ live: [Actor]) -> Bool {
        if tower || envCD > 0 || !canAct(H) || croute != nil || tapW != nil || (pr?.bag ?? false) { return false }
        let near = live.filter { abs($0.x - H.x) < 40 }
        let pole = prologue ? nil : data.poles.first { abs($0 - H.x) < 16 }
        if let pole, near.count >= 2 || (near.contains { behindOf(H, $0) } && near.contains { !behindOf(H, $0) }) {   // 기둥을 잡고 한 바퀴 — 앞뒤 모두
            H.x = pole - H.f * 5; setAnim(H, "idle"); cmdPush("기둥 회전차기", "env")
            let opts = ActionReq()
            var ko = HitOpts(); ko.knock = true
            opts.cues = ["ps1": { [unowned self] _ in self.envHit(H, 42, 13, ko) }, "ps2": { [unowned self] _ in H.flip.toggle(); self.envHit(H, 42, 13, ko) }]
            requestAction(H, "polespin", opts)
            envCD = 6; flashText("POLE", 0.5); return true
        }
        let sx = prologue ? Optional(jsRound(H.x)) : nvSnow?.held == true ? nil : data.strapX.first { abs($0 - H.x) < 9 }, tgt = live.first { !behindOf(H, $0) && abs($0.x - H.x) < 34 }
        if let sx, tgt != nil, rnd() < 0.4 {   // 손잡이에 매달려 두 발로
            H.x = sx; setAnim(H, "idle")
            if prologue { H.airOv = 20; lampKick(H.x, 2.4); sfx("clack") }   // 복도: 문 위 배수관까지 뛰어올라 잡는다
            cmdPush("매달려 차기", "env")
            let opts = ActionReq()
            var ko = HitOpts(); ko.knock = true; ko.splash = true
            opts.cues = ["hk2": { _ in H.airOv = 0 }, "hk1": { [unowned self] _ in self.envHit(H, 40, 15, ko) }]
            requestAction(H, "hangkick", opts); envCD = prologue ? 12 : 6; hangX = sx; return true
        }
        let bx = props.firstIndex { $0.k == "box" && abs($0.x - H.x) < 14 }
        let far = live.first { !behindOf(H, $0) && abs($0.x - H.x) > 30 && abs($0.x - H.x) < 170 }
        if let bx, let far {   // 짐 상자를 집어 던진다
            props.remove(at: bx); face(H, far.x); let f = H.f; setAnim(H, "idle")
            requestAction(H, "cross", ActionReq(cue: data.jwCue["cross"]) { [unowned self] _ in self.shots.append(Shot(x: H.x + f * 10, y: H.y - 42, vx: f * 280, friendly: true)); self.sfx("swing") })
            envCD = 4; return true
        }
        return false
    }

    /// 웹 bridgeSpan(): 다리 구간이 화면 근처에 있나
    func bridgeVisible() -> Bool {
        guard leg < line.count, let B = line[leg].bridge, on else { return false }
        let p0 = legStart + B.b0 - tr.ex + data.sbW / 2, p1 = p0 + B.len
        return !(p1 < -40 || p0 > data.sbW + 40)
    }
    /// 웹 passTrainUpdate(dt): 반대편 열차 교행 — 적이 움찔
    func passTrainUpdate(_ dt: Double) {
        ptT += dt; if ptNext == nil { ptNext = 14 + rnd() * 12 }
        if pt == nil && ptT > ptNext! && tr.phase == "cruise" && tr.v > 300 && !bridgeVisible() && quickStop == nil && !arriving && state == "fight" {
            pt = 0; ptT = 0; ptNext = 20 + rnd() * 20; sfx("pass")
            for a in foes() where !a.e!.boss && !isDown(a) {
                a.e!.stun = max(a.e!.stun, 0.5)
                if let A = a.action, !A.fired { a.action = nil; a.queue = []; setAnim(a, "idle") }
            }
        }
        if let t = pt { pt = t + dt; if pt! > 1.9 { pt = nil } }
    }

    /// 웹 hitTier(a, o, rk): 타격음 등급 0~2
    func hitTier(_ a: String, _ o: HitOpts, _ rk: String) -> Int {
        let base = a.hasSuffix("_air") ? String(a.dropLast(4)) : a
        let F = data.atkFeel[a] ?? data.atkFeel[base]
        var n = F.map { ["L": 0, "M": 1, "H": 2][$0.w] ?? 1 } ?? (base == "jab" ? 0 : 1)
        if o.blast || data.heavyRK.contains(rk) { n = 2 } else if o.crit && n < 2 { n += 1 }
        return n
    }
    /// 웹 hitKind(a, heavy)
    func hitKind(_ a: String, _ heavy: Bool) -> String {
        if prologue && a.hasPrefix("hm_") { return "hammer" }
        if heavy { return "heavy" }
        if a == "jab" || a == "nv_flick" { return "jab" }
        if ["kick", "round", "sweep", "knee", "bkick", "stomp", "polespin", "hangkick", "charge"].contains(a) { return "kick" }
        return "punch"
    }

    /// 웹 legEvent(force): 승객 이벤트(구간마다 한 번, 45%) — 쇼타임 댄서 · 버스커 · 구경꾼
    func legEvent(_ force: String? = nil) {
        ev = nil
        let L = line[ci]
        if force == nil && rnd() > 0.45 { return }
        let pass = ents.filter { $0.pass && !$0.hidden && $0.goal == nil }
        var kinds = ["dance", "busk"]; if pass.count >= 2 { kinds.append("crowd") }
        if L.end == true { if pass.count < 2 { return }; kinds = ["crowd"] }
        let k = force ?? kinds[rndInt(kinds.count)]
        let E = LegEventState(k: k, dur: k == "crowd" ? 999 : k == "dance" ? 12 : 16); ev = E
        if k == "dance" {
            for (x, c) in [(220.0, "RED"), (262.0, "GOLD")] {
                let d = mkActor(lookDef(name: "댄서", hair: "pomp", coat: c), x: x, z: 2, flip: x > 240, pose: "st0", pass: true)
                d.dancer = true; d.passPose = "st0"; setAnim(d, "idle"); ents.append(d); E.actors.append(d)
            }
            comicSay(E.actors[0], "쇼타임! 쇼타임!", "shout"); say("쇼타임!", "지하철 댄서가 통로에서 공연한다 — 근처 적은 휘두르는 다리에 걸려 넘어진다", 2.4)
        }
        if k == "busk" {
            let d = mkActor(lookDef(name: "버스커", hair: "bandana", coat: "WOOD"), x: 452, z: -1, flip: true, pose: "gt0", pass: true)
            d.wpn = "w_guitar"; d.passPose = "gt0"; setAnim(d, "busk"); ents.append(d); E.actors.append(d)
            comicSay(d, "♪ 한 곡 할게요"); say("버스커", "기타 연주가 흐르는 동안 체력이 조금씩 회복된다", 2.4)
        }
        if k == "crowd" { E.actors = Array(pass.prefix(4)); E.actors.forEach { $0.filming = true }; say("구경꾼", "승객들이 휴대폰으로 찍는다 — 연타가 길수록 점수 배율이 오른다", 2.4) }
    }
    /// 웹 evUpdate(dt)
    func evUpdate(_ dt: Double) {
        guard let E = ev, !demo, let H = hero else { return }
        E.t += dt
        if E.k == "dance" {
            for d in E.actors where !d.hidden {
                if E.t < E.dur {
                    if d.anim == "idle" {
                        let mv = ["round", "kick", "upper", "round"][rndInt(4)]; d.flip = rnd() < 0.5
                        requestAction(d, mv, ActionReq(cue: data.jwCue[mv]) { [unowned self] c in
                            let f = c.f
                            for a in self.foes() { let dx = (a.x - c.x) * f; if dx > -4 && dx < 34 && !self.isDown(a) && !a.e!.boss { var o = HitOpts(); o.knock = true; self.damage(c, a, 5, o) } }
                        })
                    }
                } else if !d.exiting && d.anim == "idle" { d.exiting = true; d.goal = data.sbW - 6; setAnim(d, "walk") }
            }
        }
        if E.k == "busk" {
            let d = E.actors.first
            if E.t < E.dur {
                E.heal += dt
                if E.heal >= 1 && !H.dead { E.heal = 0; if hp < maxHP { hp += 1 } }
            } else if let d, !d.exiting { d.exiting = true; d.wpn = nil; d.goal = data.sbW - 6; setAnim(d, "walk") }
        }
        if E.k == "crowd" {
            if [5, 10, 15].contains(combo) && E.lastCheer != combo { E.lastCheer = combo; if let a = E.actors.first(where: { !$0.hidden }) { comicSay(a, "quip:cheer", "shout") } }
        }
        if !E.actors.isEmpty && E.actors.allSatisfy({ $0.hidden }) { ev = nil }
    }
    /// 웹 crowdK(): 구경꾼 이벤트 중 연타 점수 배율
    func crowdK() -> Double { ev?.k == "crowd" ? 1 + 0.08 * Double(min(combo, 10)) : 1 }

    /// 웹 propsInit(C): 커피 웅덩이 · 짐 상자 · 캔
    func propsInit(_ C: CarConcept) {
        props = []
        func spot() -> Double { var x: Double; repeat { x = 40 + rnd() * 400 } while inDoor(x); return x }
        if rnd() < 0.5 { props.append(Prop(k: "puddle", x: spot())) }
        if rnd() < 0.55 { props.append(Prop(k: "box", x: spot())) }
        if C.key != "night" && rnd() < 0.35 { var k = 0; while k < 1 + rndInt(2) { cans.append(Can(x: spot())); k += 1 } }   // 조건식이 매번 다시 굴린다(웹 그대로)
    }
    /// 웹 slipUpdate(): 웅덩이 · 캔에 미끄러짐
    func slipUpdate() {
        for a in foes() {
            if isDown(a) || a.held || a.slipT > time || !["walk", "idle"].contains(a.anim) { continue }
            let pd = props.contains { $0.k == "puddle" && abs($0.x + 8 - a.x) < 6 }
            let cn = cans.firstIndex { abs($0.x - a.x) < 4 }
            if pd || cn != nil {
                a.slipT = time + 4; setAnim(a, "rSwept"); a.after = "getup"; a.kb = (a.flip ? 1 : -1) * 20; comicSFX(a.x, a.y - 80, "SLIP!"); sfx("dodge")
                if let cn { cans[cn].v = (rnd() < 0.5 ? -1 : 1) * 170 }
            }
        }
    }
}
