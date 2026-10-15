import Foundation
import BBAnim

// 웹 16-anim.js(enterStep · requestAction · setAnim · advance · stepAnim) + 13-rig-grammar.js seqOf.
// 판정 타이밍(큐 자세 → onCue)이 여기서 나온다. 칸 길이: 3D 인물(msT)은 ms → round(n·animFps/1000), 옛 표는 BF(n).

extension World {
    /// 웹 seqOf(name, c)
    /// 플리커 장착 대기 — 주인공(JW) 시퀀스라 길이는 ms(웹 JW idle 과 같은 단위 · 한 바퀴 0.9초)
    static let flickIdle = [SStep("fl_idle0", 150), SStep("fl_idle1", 150), SStep("fl_idle2", 150), SStep("fl_idle2", 150), SStep("fl_idle1", 150), SStep("fl_idle0", 150)]
    func seqOf(_ name: String, _ c: Actor) -> [SStep] {
        if let ov = c.seqOv, ov.anim == name { return ov.seq }
        // 네이티브: 플리커 잽을 가방에 넣은 주인공은 대기 자세도 디트로이트식 낮은 손(감독 피드백 — 깃발 꺼짐은 웹 그대로)
        if name == "idle", config.nativeMoves, c.isHero, bag.contains(where: { $0.id == "nv_flick" }) { return Self.flickIdle }
        if c.def.jw, let s = data.seqJW[name] { return s }
        let g = c.grammar ?? data.grammar, mma = c.def.mma
        func G(_ k: String) -> Double { Double(g[k] ?? data.grammar[k] ?? 0) }
        switch name {
        case "idle": return mma ? [SStep("m_idle0", 4), SStep("m_idle1", 4)] : [SStep("idle0", 6), SStep("idle1", 6)]
        case "jkick": return [SStep("b_jkW", 3), SStep("b_jk", 4), SStep("b_jkL", 2), SStep("m_idle0", 2)]
        case "hook": return [SStep("hookW", 3), SStep("hook", 2), SStep("m_idle0", 4)]
        case "upper": return [SStep("upW", 3), SStep("up", 3), SStep("m_idle0", 4)]
        case "elbow": return [SStep("elbW", 2), SStep("elb", 2), SStep("m_idle0", 3)]
        case "knee": return [SStep("knW", 3), SStep("kn", 3), SStep("m_idle0", 3)]
        case "round": return [SStep("rhW", 3), SStep("rh", 3), SStep("m_idle0", 4)]
        case "sweep": return [SStep("swW", 3), SStep("sw", 3), SStep("swW", 2), SStep("m_idle0", 3)]
        case "hbutt": return [SStep("hbW", 3), SStep("hb", 2), SStep("m_idle0", 4)]
        case "hitB": return [SStep("m_hitB", 4), SStep("m_idle0", 3)]
        case "pass": return [SStep(c.passPose ?? "sb_sit", 9999)]
        case "bat": return [SStep("batW", 4), SStep("batS", 2), SStep("batF", 3), SStep("m_idle0", 3)]
        case "launch": return [SStep("m_hit", 1), SStep("m_lift", 3), SStep("death1", 2), SStep("death2", 7)]
        case "fall": return [SStep("m_hit", 1), SStep("death0", 2), SStep("death1", 2), SStep("death2", 7)]
        case "getup": return [SStep("death1", 3), SStep("m_idle1", 2)]
        case "jab": return [SStep("m_jabW", 2), SStep("m_jab", 2), SStep("m_idle0", 3)]
        case "cross": return [SStep("m_crossW", 3), SStep("m_cross", 2), SStep("m_idle0", 4)]
        case "kick": return [SStep("m_kickW", 3), SStep("m_kick", 2), SStep("m_idle0", 4)]
        case "attack": return [SStep("windup", G("pre")), SStep("strike", G("hit")), SStep("follow", G("fol")), SStep("recover", G("rec"))]
        case "guard": return [SStep("block", 4), SStep("recover", 2)]
        case "drink": return [SStep("cast0", 3), SStep("cast1", 5), SStep("recover", 3)]
        case "hit": return mma ? [SStep("m_hit", 3), SStep("m_idle0", 3)] : [SStep("hit", 3), SStep("recover", 2)]
        case "walk": return mma ? [SStep("b_walk0", 2), SStep("b_walk1", 2), SStep("b_walk2", 2), SStep("b_walk3", 2)]
                                : [SStep("walk0", 3), SStep("walk1", 3), SStep("walk2", 3), SStep("walk3", 3)]
        case "block": return [SStep("block", 12), SStep("recover", 3)]
        case "cast": return [SStep("cast0", 4), SStep("cast1", 8), SStep("cast2", 3), SStep("recover", 4)]
        case "death": return [SStep("death0", 3), SStep("death1", 4), SStep("death2", 14), SStep("death2", 10, true)]
        case "down": return [SStep("death2", 9999)]
        default: return [SStep("idle0", 6)]
        }
    }

    /// 웹 enterStep(c): 다음 칸으로 들어서며 큐 자세면 onCue · cues[자세]
    func enterStep(_ c: Actor) {
        var guardN = 0
        while guardN < 8 {
            guardN += 1
            let seq = seqOf(c.anim, c)
            if c.si >= seq.count {
                if data.loop.contains(c.anim) { c.si = 0; continue }
                if let a = c.after, !c.dead { c.anim = a; c.after = nil; c.si = 0; continue }
                if c.dead { if c.keepBody { c.anim = "down"; c.si = 0; continue }; c.hidden = true }   // 쓰러짐이 끝나면 사라지거나(적) 누운 채 남는다(주인공)
                c.anim = "idle"; c.si = 0; c.action = nil; c.wpn = nil
                if !c.queue.isEmpty && !c.dead { let q = c.queue.removeFirst(); c.action = q.opts; c.wpn = q.opts.wpn; c.anim = q.anim }
                continue
            }
            let st = seq[c.si], pose = st.pose
            if st.n <= 0 { c.si += 1; continue }
            var nn = st.n
            if c.e != nil, let A = c.action, !A.fired, let w = data.foeW[c.anim], !smearPose(pose) { nn = st.n * (data.foeTell[w] ?? 1) }
            if c.e != nil, let A = c.action, !A.fired, A.tell != 0, c.si == 0 { nn += A.tell * 1000 }   // 저스트 예고: 첫 준비 자세를 더 오래
            c.prev = c.pose; c.pose = pose
            c.hold = c.def.msT ? max(1, jsRoundI(nn * animFps / 1000)) : BF(nn)
            c.phaseN = c.hold; c.k = 0; c.blink = st.blink
            if pose == "land_q" { fx("dust", c.x, c.y); fx("dust", c.x, c.y, 1) }
            if let A = c.action, A.cue == pose, !A.fired { A.fired = true; A.onCue?(c) }
            if let A = c.action, let f = A.cues[pose], !A.firedCues.contains(pose) { A.firedCues.insert(pose); f(c) }   // 한 동작 안 여러 타이밍
            else if c.action == nil && ((c.anim == "attack" && pose == "strike") || (c.anim == "cast" && pose == "cast2") || data.poses[live: pose]?.impact == true) {
                // 웹 strike(c): 실험실 인물용 타격이지만 게임에서도 불린다(동작 요청 없이 타격 자세에 들어설 때 — 도끼 차기에 꽂히는 적 sp_hit ·
                // 병 쳐내기 · 필살기 연타). 규칙에 남는 효과는 화면 정지(freeze = BF(G.stop)) 하나 — 나머지(실험실 인물 · 숫자 · 불꽃)는 버린다
                freeze = BF(Gstop)
            }
            return
        }
    }

    func smearPose(_ p: String) -> Bool { if let s = data.poses[live: p]?.smear, !s.isEmpty { return true }; return false }

    /// 웹 poseAir: 떠 있음(높이 4 초과) 또는 회전(약 14° 초과)
    func poseAir(_ P: Pose?) -> Bool {
        guard let P else { return false }
        let roll = P.roll ?? 0
        let r = abs((roll.truncatingRemainder(dividingBy: 1) + 1.5).truncatingRemainder(dividingBy: 1) - 0.5)
        return (P.air ?? 0) > 4 || r > 0.04
    }
    /// 웹 heroAirborne(H): 지금 키 포즈가 공중인가
    func heroAirborne(_ H: Actor) -> Bool { poseAir(data.poses[live: H.pose]) }

    /// 웹 requestAction(c, anim, opts): 쉬고 있으면 바로, 아니면 줄(최대 2)
    @discardableResult
    func requestAction(_ c: Actor, _ anim: String, _ opts: ActionReq) -> Bool {
        if c.dead || c.hidden { return false }
        if c.anim == "idle" || (nv && World.nvGuardStill.contains(c.anim)) {   // 네이티브: 가드 자세에서 바로 공격
            c.action = opts; c.wpn = opts.wpn
            c.seqOv = nil
            if c === hero && c.def.jw && poseAir(c.lastP), let s = data.seqJW[anim] { c.seqOv = (anim, [SStep("land_q", 60)] + s) }   // 자동 착지 다리
            setAnim(c, anim); return true
        }
        if c.queue.count < 2 { c.queue.append((anim, opts)) }
        return false
    }
    /// 웹 setAnim
    func setAnim(_ c: Actor, _ name: String) { c.anim = name; c.si = 0; enterStep(c) }
    /// 웹 advance — 애니메이션 한 칸
    func advance(_ c: Actor) { c.k += 1; c.hold -= 1; if c.hold > 0 { return }; c.si += 1; enterStep(c) }

    /// 웹 stepAnim(게임 부분): 칸 진행 · 인물별 정지(hs) · 화면 정지(freeze)
    func stepAnim() {
        if on, let C = cut, C.pause { return }
        tick += 1
        let k = 12 / animFps
        for c in ents where c.flash > 0 { c.flash -= k }
        if freeze > 0 { freeze -= 1; return }
        for c in ents {
            if c.hs > 0 {
                c.hs -= 1
                c.shk = c.hs > 0 ? Double(c.hs % 2 == 1 ? 1 : -1) * c.shkA * max(0.35, Double(c.hs) / Double(c.hs0 != 0 ? c.hs0 : (c.hs != 0 ? c.hs : 1))) : 0
                continue
            }
            c.shk = 0
            advance(c)
        }
    }

    /// 웹 curPose(c) — 키 포즈 사이 보간(그리기와 같은 값). lastP 계산에 쓴다.
    func drawnPose(_ c: Actor) -> Pose? {
        var s = c.drawState ?? ActorPose(anim: c.anim, pose: c.pose)
        s.anim = c.anim; s.pose = c.pose; s.prev = c.prev; s.k = c.k; s.phaseN = c.phaseN
        s.gph = c.gph; s.guardW = c.guardW; s.runU = c.runU; s.legRun = c.legRun
        s.airOv = c.airOv; s.tilt = c.tilt
        if let J = c.jug { s.hasJug = true; s.jugRoll = J.roll; s.jugKick = J.kick } else { s.hasJug = false }
        let P = evaluatePose(&s, traits: ActorTraits(gait: true, jw: c.def.jw, isHero: c.isHero), rig: data.heroRig, time: gameTime, tables: data.animTables).pose
        c.drawState = s
        return P
    }
}
