import Foundation

// 웹 13-rig-grammar.js 규칙 부분: 반응 고르기(reactKey · deathOf) · 공중 콤보(jugHit · jugStep · jugRollRate · jugRefund) · 바닥 충격(groundImpact).
// 주의(웹 원본 그대로): jugStep 의 '공기 저항 · 넉백 갱신 · 회전' 줄은 웹에서 주석 뒤에 붙어 실행되지 않는다(J.vx 는 바뀌지 않고, 이동은 kb 로).

extension World {
    /// 웹 reactKey(att, o): 공격자의 지금 동작과 타격 성격으로 맞는 쪽 반응
    func reactKey(_ att: Actor, _ o: HitOpts) -> String {
        var a = att.anim
        if a.hasSuffix("_air") { a.removeLast(4) }
        if o.splash { return "rKick" }
        if nv && a == "nv_punt" { return "rKick" }   // 구두 슛: 쓰러진 적을 차 띄운다(World+NativePunt — 조건 down 이라 react 는 'down')
        if o.react == "down" { return "rStomp" }
        if nv && a.hasPrefix("nv_") {   // 네이티브 기술(World+NativeRush · NativeContent)
            if o.react == "launch" || a.hasPrefix("nv_drFin") { return "launch" }
            if a.hasPrefix("nv_dr") { return "rHook" }
            switch a { case "nv_flick": return "hit"; case "nv_liver": return "hitB"; case "nv_cork": return o.knock ? "fall" : "rCross"; case "nv_roll": return "rCross"; case "nv_duckup": return "hitB"; case "nv_kneelift": return "rKnee"
            case "nv_slam": return "launch"; case "nv_stamp": return o.knock ? "rBlast" : "rCross"; case "nv_headbutt": return o.react == "head" ? "hit" : "rElbow"   // 직장인 세 기술(World+NativeOffice)
            case "nv_dial": return "hit"   // 내선 연결: 머리에 작게 — 바로 끌림으로 바뀐다(World+NativeDial)
            default: break }
        }
        switch a {
        case "hm_swing": return o.knock ? "rSpin" : "rHook"
        case "hm_back": return "rCross"
        case "hm_up": return "launch"
        case "hm_down": return o.knock ? "fall" : "hit"
        case "throw", "suplex": return "rSlam"
        case "tetsu": return "rTetsu"
        case "renkan": return o.react == "launch" ? "launch" : "rkPop"
        case "axe": return "crumple"
        case "bkick": return o.knock ? "rKick" : "hitB"
        case "bfist": return "rHook"
        case "sweep": return "rSwept"
        case "charge": return "rCharge"
        case "round", "bat": return o.knock ? "rSpin" : "rHook"
        case "kick": return o.knock ? "rKick" : "hitB"
        case "knee": return "rKnee"
        case "elbow": return "rElbow"
        default: break
        }
        if a == "upper" || a == "scoop" || a == "skick" || o.react == "launch" { return "launch" }
        if a == "hook" { return "rHook" }
        if a == "cross" || a == "hbutt" { return "rCross" }
        if o.knock { return "fall" }
        if o.react == "body" { return "hitB" }
        return "hit"
    }
    /// 웹 deathOf(rk)
    func deathOf(_ rk: String) -> String {
        if data.falls.contains(rk) && rk != "rStomp" { return rk + "D" }
        if rk == "rKnee" || rk == "hitB" || rk == "rElbow" { return "deathFwd" }
        if rk == "rStomp" { return "rSlamD" }
        return "death"
    }

    /// 웹 jugRollRate(J): 땅에 닿을 때 딱 한 바퀴가 끝나게
    func jugRollRate(_ J: Jug) {
        if J.rollT == 0 || J.roll <= J.rollT { J.rollR = 0; return }
        let g = data.jugG * (1 + data.jugGUp * Double(J.n))
        let T = max(0.18, (max(0, J.vy) + (J.vy * J.vy + 2 * g * max(0, J.h)).squareRoot()) / g)
        J.rollR = (J.rollT - J.roll) / T
    }
    /// 웹 jugRefund(k): 띄운 주먹 계열 기술 쿨다운 되돌리기
    func jugRefund(_ k: Double) {
        guard let i = bag.firstIndex(where: { $0.uid == curSrc }), let it = item(bag[i].id) else { return }
        if it.fam == "fist" || it.combo == true { let cd = cdOf(i); bag[i].t = min(cd, bag[i].t + cd * k) }
    }

    /// 웹 jugHit(t, rk, f, att, o, kres): 띄우기 · 공중 타격
    func jugHit(_ t: Actor, _ rk: String, _ f: Double, _ att: Actor, _ o: HitOpts, _ kres: Double) {
        if t.jug == nil {
            let L = data.launch[rk] ?? data.launch["fall"]!, hv = (t.e?.heavy == true ? 0.6 : 1) * (kres < 1 ? 0.8 : 1)
            let J = Jug(h: max(0.5, t.airOv), vy: L.vy * hv, vx: f * L.vx * hv, pts: Double(L.pts), rollT: L.roll ?? 0, jerkT: (L.roll ?? 0) != 0 ? 0.12 : 0,
                        up: L.up, fall: L.fall, drag: L.drag ?? 0.45, forceB: L.bounce == true, trip: L.trip == true, src: att === hero ? curSrc : nil)
            t.jug = J; jugRollRate(J)
            if att.anim == "skick" { J.gk = 0.8; J.vy *= 0.8.squareRoot() }   // 섬머솔트: 같은 높이로 더 오래 뜬다
            if tower { J.vy *= 1.55 }   // 타워: 좁은 칸 — 띄우면 천장까지
            t.action = nil; t.queue = []; t.after = nil; t.e?.stun = 0; setAnim(t, "jug"); t.pose = L.up; t.prev = L.up; t.k = 0
            if att === hero { jugRefund(1) }
        } else {
            let J = t.jug!
            let w = data.atkFeel[att.anim]?.w ?? (o.knock ? "H" : "M"), P = data.airPop[w]!
            J.n += 1; J.pts += Double(P.pts)
            if J.nvRollT != nil { J.nvRollT = 0 }; J.nvKeep = nil; J.nvWall = false; J.nvSlam = false   // 네이티브 무릎 날림 · 결재 쌍장 날림 · 내려찍기 중 다시 맞으면 보통 공중 규칙
            if J.trip { J.trip = false; J.up = "air_back"; J.fall = "air_fall" }   // 걸림 중 맞으면 걸림이 끝나고 보통 중력
            J.vy = J.pts <= data.jugLimit ? max(J.vy, P.vy * pow(data.jugDecay, Double(J.n)) * max(0.25, min(1, 1 - (J.h - 36) / 24))) : min(J.vy, -80)
            if o.knock && J.n >= 3 && att === hero { slowT = max(slowT, 0.18) }   // 저글 마무리: 잠깐 느리게
            J.vx = f * P.vx + J.vx * 0.3
            if att.anim == "upper" || att.anim == "scoop" || o.react == "launch" {   // 공중 어퍼컷: 거의 수직으로 다시 띄운다
                J.vx = f * 20; J.vy = max(J.vy, (att.anim == "scoop" ? 240 : 205) * pow(data.jugDecay, Double(J.n))); J.trip = false; J.up = "air_up"; J.fall = "air_back"
            }
            if o.knock { J.vx = f * max(abs(J.vx), 185); J.rollT = J.roll - 0.06; J.up = "air_back"; J.fall = "air_fall" }
            J.hitT = time + data.jugHitPose; J.kv -= o.knock ? 0.7 : 0.45; jugRollRate(J)
            if att === hero { jugRefund(1) }
            if att.anim == "stomp" && !J.gb { J.vy = -430; J.vx *= 0.3; J.gbReady = true; J.gbSrc = curSrc }   // 바닥 튕기기: 내리꽂는다
            if o.blast {   // 콤보 마무리: 떠 있어도 낮게 일직선으로
                J.vx = f * 340 * (t.e?.heavy == true ? 0.6 : 1); J.vy = min(max(J.vy, 40), 90); J.drag = 0.7; J.forceB = true; J.bounced = false
                J.up = "air_back"; J.fall = "air_fall"; J.rollT = J.roll; jugRollRate(J)
            }
        }
        t.kb = t.jug!.vx
    }

    /// 웹 poleOK: 연계(기둥 튕기기)가 있을 때만 기둥에 튕긴다
    func poleOK() -> Bool { tower ? false : demo ? (dj?.pole ?? false) : bagHasLink("pole") }

    /// 웹 jugStep(a, dt): 공중 물리 한 걸음
    func jugStep(_ a: Actor, _ dt: Double) {
        guard let J = a.jug else { return }
        J.kv += (-140 * J.kick - 15 * J.kv) * dt; J.kick += J.kv * dt   // 맞을 때마다 뒤로 젖혀졌다 제자리로
        if J.roofOut { if !(a.hs > 0) { nvRoofStep(a, J, dt) }; return }   // 네이티브 퇴근 승천권: 지붕을 뚫고 날아간다(World+NativeRise)
        if a.hs > 0 { a.x += J.vx * dt * 0.05; return }   // 정지 중엔 넉백 방향으로 아주 조금만
        J.t += dt
        if J.nvRollT != nil || J.nvKeep != nil { nvKneeFlyStep(a, J, dt) }   // 네이티브 무릎 날림: 눕히기 · 가로 속도(World+NativeVF)
        let g0 = data.jugG * (1 + data.jugGUp * Double(J.n)) * (J.trip ? 0.5 : 1) * (J.gk ?? 1)
        let v0 = J.vy, h0 = J.h
        J.vy -= g0 * dt; J.h += J.vy * dt
        if tower && v0 > 0 && h0 < TWR.CEIL_H {   // 엘리베이터 천장 튕기기: 실제 궤적이 천장에 닿는 순간을 계산
            let C = TWR.CEIL_H - h0, D = v0 * v0 - 2 * g0 * C
            if D >= 0 { let tc = (v0 - D.squareRoot()) / g0; if tc <= dt { J.vy = v0 - g0 * tc; twCeil(a, J) } }
        }
        let x0 = J.px ?? a.x; J.px = a.x
        if !J.wallB && J.t > 0.05 && J.h < 46 && abs(J.vx) > 160 && poleOK() {   // 날아가다 기둥을 지나면 한 번 튕겨 온다
            let dir = jsSign(J.vx)
            if let px = (demo ? sd.djPoles : data.poles).first(where: { ($0 - x0) * ($0 - a.x) <= 0 && x0 != a.x }) {
                J.wallB = true; J.vx = -dir * min(110, abs(J.vx) * 0.33); J.vy = max(J.vy, 140); J.hitT = time + 0.18; a.hs = max(a.hs, 3); J.spinR *= 0.4; a.x = px - dir * 5; a.kb = J.vx
                if let bi = bag.firstIndex(where: { $0.uid == J.src }) { linkFire(bi, "pole") }
                if demo { djJolt(1.2) }
                fx("spark", px, a.y - 24 - J.h); shake(2.6); comicSFX(px, a.y - 60 - J.h, "CLANG!"); sfx("clack"); poleT = time
            }
        }
        let ps = J.t < J.jerkT ? "air_jerk" : J.wallP > time ? "air_wall" : time < J.hitT ? "air_hit" : J.vy > 30 ? J.up : J.fall
        if a.pose != ps { a.prev = ps; a.pose = ps; a.k = 0 }
        a.hold = 99999; a.phaseN = 99999; a.airOv = max(0, J.h)
        if J.h <= 0 && J.vy < 0 && J.gbReady && !J.gb {   // 높이 튕겨 다시 공중으로
            J.gb = true; J.gbReady = false; J.bounced = true; J.vy = 210; J.h = 0.5; J.hitT = time + 0.15; groundImpact(a.x, a.y, 1.5)
            if J.nvSlam { J.nvSlam = false; nvSlamBounce(a, J) }   // 네이티브 서류가방 내려찍기: 더 높이 · 충격파 고리(World+NativeOffice)
            if let bi = bag.firstIndex(where: { $0.uid == J.gbSrc }) { linkFire(bi, "gbounce") }
        }
        if (J.h <= 0 && J.vy < 0) || J.t > 3.5 {
            let imp = max(0, -J.vy)
            if (imp > data.jugBounceV || (J.forceB && imp > 60)) && !J.bounced && J.t <= 3.5 {   // 한 번 튕긴다
                J.bounced = true; J.vy = imp * 0.3; J.h = 0.5; J.vx *= 0.55; J.roll = J.rollT; J.rollR = 0; J.nvRollT = nil; if J.nvKeep != nil { a.kb = J.vx }; groundImpact(a.x, a.y, min(1.6, imp / 300))
            } else {
                let die = J.die
                if J.trip { a.tripLandT = time }
                a.jug = nil; a.airOv = 0; a.kb = J.vx * 0.9
                if die { setAnim(a, "jlandD") } else { setAnim(a, "jland"); a.after = "getup" }
                groundImpact(a.x, a.y, min(1.4, imp / 330 + 0.25))
            }
        }
    }

    /// 웹 groundImpact(x, y, p): 바닥 충격(먼지 · 부스러기 · 균열 · 흔들림) — 규칙 효과 없음(타워 출렁임은 타워 모드)
    func groundImpact(_ x: Double, _ y: Double, _ p0: Double) {
        let p = max(0.3, p0)
        emit(.groundImpact(x: x, y: y, power: p))
        if demo { djJolt(p * 0.7) }   // 무도장: 간판 · 전등이 흔들린다(표현 상태)
        if let T = tw { T.sagV += p * 5 }   // 타워: 큰 착지에 칸이 출렁
    }
}
