import Foundation
import BBCore
import BBContent

// 웹 30-train-env.js: 열차(trainUpdate) · 조명 전환(updateLightTrans) · 제동(brakeUpdate) · 판 진행(gameUpdate — 웨이브 · 도착 · 승차 · 매점 · 정리 · 종점) ·
// 환승(startTransfer · transferUpdate) · 노선 읽기(loadStage) · 판 시작(startRun) + 25-lines.js setStage + 34-shop.js 규칙(shopPick · openShop · finishArrange · showResult) +
// 44-story.js 대화 대기열(talkSoon · talkTick).

extension World {
    /// 웹 setStage(k)
    func setStage(_ k: Int) { stageIdx = k }
    var startStop: String { stage.start }

    // MARK: 열차

    /// 웹 trainUpdate(dt): 가감속 · 짧은 정차역 · 레일 이음매 · 진동 · 문
    func trainUpdate(_ dt: Double) {
        tr.t += dt
        if leg < line.count, let B = line[leg].bridge, let pe = prevEx {
            let e0 = legStart + B.b0, e1 = e0 + B.len
            if pe < e1 && tr.ex >= e1 { press = 0.42; sfx("press"); tr.jolt = 1.6; tr.strapV += 2.2; shake(2); say("", "귀가 먹먹해진다 — 터널 진입 압력파", 1.4); emit(.tunnelPressure) }
            if pe < e0 && tr.ex >= e0 { press = 0.16; tr.jolt = 0.8 }
        }
        prevEx = tr.ex
        press = max(0, press - dt * 0.5)
        if departT > 0 {
            departT -= dt; if departT <= 0.9 { doorWant = false }
            if departT <= 0 && tr.door < 0.05 { departT = 0; tr.phase = "accel"; legStart = tr.ex; atStop = nil; qi = 0 }
        }
        // 짧은 정차역: 다가오면 제동 → 서서 문 열고 승하차 → 문 닫고 출발
        let Lq: CarDef? = leg < line.count ? line[leg] : nil
        let q: [JSONValue]? = Lq?.quick.flatMap { qs in qi < qs.count ? qs[qi].array : nil }
        if let q, quickStop == nil, !arriving, tr.phase == "cruise" || tr.phase == "accel", state == "fight", tr.ex >= legStart + (q[1].double ?? 0) - 1100 {
            tr.phase = "brake"; tr.stopAt = legStart + (q[1].double ?? 0); quickStop = q
            let id = q[0].string ?? ""; say(data.stations[id] ?? id, "잠시 정차합니다", 2.2); emit(.stationApproach(station: id, quick: true, terminal: false))
        }
        if let qs = quickStop, tr.phase == "stop" {
            atStop = qs[0].string
            if qDwell == nil { qDwell = 3.2; doorWant = true; boarded = false; emit(.doors(open: true)) }
            if !boarded && tr.door > 0.95 { boarded = true; boardAt((qs[2].array ?? []).compactMap(\.string)) }
            qDwell! -= dt; if qDwell! <= 0 { doorWant = false }
            if qDwell! <= 0 && tr.door < 0.03 { tr.phase = "accel"; quickStop = nil; qDwell = nil; qi += 1; atStop = nil; emit(.doors(open: false)) }
        }
        var onBridge = false
        if let L = Lq, let B = L.bridge { onBridge = tr.ex > legStart + B.b0 - 400 && tr.ex < legStart + B.b0 + B.len }
        let vmax: Double = onBridge && !foes().isEmpty ? 380 : expr ? 1100 : 720   // 싸우는 동안엔 다리를 천천히
        let tgt = tr.phase == "cruise" || tr.phase == "accel" ? vmax : 0
        if tr.phase == "accel" { tr.a = 260; if tr.v >= vmax - 20 { tr.phase = "cruise" } }
        else if tr.phase == "cruise" { tr.a = (tgt - tr.v) * 0.8 }
        else if tr.phase == "brake" {
            let remain = tr.stopAt - tr.ex
            tr.a = remain > 4 ? -min(420, tr.v * tr.v / (2 * max(20, remain))) : -tr.v * 6
            if tr.v < 6 && remain < 30 { tr.v = 0; tr.a = 0; tr.phase = "stop" }
        } else { tr.a = 0 }
        tr.v = max(0, tr.v + tr.a * dt); tr.ex += tr.v * dt
        tr.joint -= tr.v * dt
        if tr.joint <= 0 && tr.v > 40 { tr.joint += 430; tr.bumps.append(0); tr.bumps.append(0.13) }   // 앞 대차 · 뒤 대차
        var i = tr.bumps.count - 1
        while i >= 0 { tr.bumps[i] -= dt; if tr.bumps[i] <= 0 { tr.jolt = 1; tr.strapV += (tr.bumps.count % 2 == 0 ? 1.4 : -1.4); tr.bumps.remove(at: i); emit(.railJoint) }; i -= 1 }
        tr.jolt = max(0, tr.jolt - dt * 9)
        let fast = min(1, tr.v / 600)
        tr.dy = jsRound(tr.jolt * 1.6 + sin(tr.t * 3.3) * 0.7 * fast)   // (웹은 빠를 때 12% 확률로 +1 떨림 — 연출 난수라 표현 쪽)
        tr.strapV += (-16 * tr.strap - 2.0 * tr.strapV - tr.a * 0.0045) * dt; tr.strap += tr.strapV * dt
        tr.door += ((tr.phase == "stop" && doorWant) ? 1 : -1) * dt * 2.2; tr.door = max(0, min(1, tr.door))
    }
    /// 웹 updateLightTrans(dt): 정전 칸 들어가고 나올 때 조명
    func updateLightTrans(_ dt: Double) {
        var k = 1.0, ek: Double?
        if var T = trans {
            T.t += dt
            let HOLD = T.to ? 1.0 : 0, OUT = T.to ? 1.5 : 0.6, IN = T.to ? 1.2 : 1.1, t = T.t - HOLD
            func sm(_ x: Double) -> Double { x * x * (3 - 2 * x) }
            if t < 0 { k = 1 }
            else if t < OUT {
                let u = t / OUT
                let flick = T.to ? 1 - 0.7 * sm(max(0, sin(u * 26))) * (u > 0.15 && u < 0.6 ? 1 : 0) : 1
                k = pow(1 - sm(u), 1.4) * flick
            } else {
                if !T.switched { T.switched = true; oneBit = T.to }
                let u = min(1, (t - OUT) / IN)
                let start = T.to ? 1 : (u < 0.4 ? 0.3 + 0.7 * pow(0.5 + 0.5 * sin(u * 55), 3) : 1)
                k = u * u * (3 - 2 * u) * start
                if u >= 1 { trans = nil; k = 1 }
            }
            if trans != nil { trans = T }
            if T.to && T.switched { ek = 0 }
        } else if oneBit == true { ek = 0 }
        lightK = k; emitK = ek ?? k
    }
    /// 웹 brakeUpdate(dt) 중 제동 불빛 세기(불꽃 · 먼지는 표현)
    func brakeUpdate(_ dt: Double) {
        let braking = tr.phase == "brake" && tr.v > 25 && tr.a < -40
        brakeGlow = braking ? min(1, brakeGlow + dt * 4) : max(0, brakeGlow - dt * 2)
    }

    // MARK: 판 진행

    /// 웹 gameUpdate(dt)
    func gameUpdate(_ dt: Double) {
        guard on else { return }
        if skinPv != nil { skinPvTick(dt); return }   // 스킨 미리보기: 세상은 멈추고 주인공만
        if cine { cineUpdate(dt); return }             // 프롤로그 거리 연출
        if talkActive { return }   // 대화 중엔 멈춘다
        talkTick()
        if kane { kaneUpdate(dt) }                     // 막차 안: 배신자 빅터 케인
        if nvSnow != nil { nvSnowTick() }             // 네이티브 눈 승강장: 붙잡힌 동안 열차는 서 있다
        if state != "bonus" && !tower { trainUpdate(dt); brakeUpdate(dt) }
        updateLightTrans(dt)
        if let C = cut, C.pause { return }   // 컷인 동안은 전투가 멈춘다
        shoveX = max(-5, min(5, shoveX)) * exp(-dt * 13)
        for a in ents where a.e != nil {   // 바닥에 떨어지는 쿵
            if data.falls.contains(a.anim) && a.pose == "kd3" && a.landP != "kd3" { fx("dust", a.x, a.y, a.f); sfx("thud") }
            a.landP = a.pose
        }
        if comboDmg != 0 && time - (lastHit ?? -9) > comboWin() {   // 연타가 끝나면 합계
            if combo >= 8, let H = hero { comicSay(H, "quip:combo") }
            if combo >= 3 { emit(.comboTotal(hits: combo, damage: comboDmg)) }
            comboDmg = 0
        }
        if freeze > 0 { return }
        guard let H = hero else { return }
        lagH += (hp - lagH) * min(1, dt * 2.5); mcd = max(0, mcd - dt); manualT = max(0, manualT - dt); fade = max(0, fade - dt * 2); if flashT > 0 { flashT -= dt }
        do {   // 가드 가중치: 상대가 140px 안이면 걸으면서 가드를 올린다
            let F = foes()
            for a in ents where !a.pass {
                let opp = a === H ? F : [H]
                let dmin = opp.isEmpty ? 999 : opp.map { abs($0.x - a.x) }.min()!
                a.guardW += ((dmin < 140 ? 1 : 0) - a.guardW) * min(1, dt * 3.5)
            }
        }
        let lean = max(-0.32, min(0.32, -tr.a * 0.0011))   // 관성 기울기
        for a in ents {
            let tg = lean * (a.pass && a.pose == "sb_sit" ? 0.35 : 1)
            a.tiltS += (tg - a.tiltS) * min(1, dt * 3.2)
            a.tilt = a.tiltS * ((a.pass || a.anim == "idle" || a.anim == "walk") ? 1 : 0.3)
            if nv && !a.pass { a.tilt += a.nvm.lean }   // 네이티브: 출발 · 질주는 앞으로, 미끄러질 땐 뒤로 기운다
            if !a.pass {
                a.x += -tr.a * 0.012 * dt * (a.e?.heavy == true ? 0.4 : 1)
                if holding(a) { a.kb = 0; a.dash = 0; a.dashT = 0 }
                if a.jug != nil { jugStep(a, dt) }
                if a.kb != 0 && !(a.hs > 0) { a.x += a.kb * dt; a.kb *= pow(a.jug?.nvKeep ?? 0.02, dt); if abs(a.kb) < 2 { a.kb = 0 } }   // nvKeep: 네이티브 무릎 날림(길게 미끄러지듯)
                if a.e != nil && !a.dojo && !demo && (abs(a.kb) > 70 || (a.jug != nil && abs(a.jug!.vx) > 70 && a.jug!.h < 34)) { bowlCheck(a) }
                if let S = a.spike {   // 도끼 차기: 꽂히는 0.07초
                    let t = S.t + dt; a.spike = (S.h0, t, S.dur); a.airOv = S.h0 * max(0, 1 - t / S.dur)
                    if t >= S.dur { a.spike = nil; a.airOv = 0; groundImpact(a.x, a.y, 1.3); shake(2.4) }
                }
                if a.dash != 0 {   // 남은 돌진 시간만큼만
                    a.x += a.dash * min(dt, max(0, a.dashT)); a.dashT -= dt
                    if a.dashT <= 0 { a.dash = 0; if a.anim == "walk" { setAnim(a, "idle") } }
                }
                if let e = a.e, !a.dead, !a.dojo, abs(a.kb) > 55, doorOpenAt(a.x) {   // 열린 문 밖으로!
                    a.dead = true; a.hidden = true; kills += 1; stats.outs += 1; score += 400; metaFoe(e.t, true); if tower { twOut(a) }
                    comicSFX(a.x, a.y - 50, "WHOOSH!"); emit(.textPop(x: a.x - 8, y: a.y - 60, text: "400")); drop(a)
                    emit(.foeDowned(target: a.id, cause: .doorOut, at: SIMD2(a.x, a.y)))
                }
                if a.e != nil && !a.hidden { wallCheck(a) }
                a.x = max(AW0() - 2, min(AW1() + 2, a.x))
            }
            a.y = data.floorY + jsRound(a.z) + tr.dy
        }
        bodySep()   // 몸끼리 겹치지 않게
        for a in ents {
            guard let Hh = a.heldBy else {
                if a.nvHold?.phase == "wall" { nvWallTick(a) }   // 네이티브 벽꿍: 벽에 붙었다 미끄러진다(World+NativeGrab)
                else if var S = a.nvHold, S.phase == "drop" {   // 네이티브: 놓친 몸은 떨어진다(웹은 머리 위에서 한 틱에 바닥으로) — 'fall' 동작 · 시간은 그대로, 높이만
                    S.p += 900 * dt; a.airOv = max(0, a.airOv - S.p * dt)
                    if a.airOv <= 0 { a.nvHold = nil; fx("dust", a.x, a.y, a.f) } else { a.nvHold = S }
                } else if a.nvHold != nil && spc?.tgt !== a { a.nvHold = nil }
                continue
            }
            let f = Hh.f
            if (Hh.anim != "throw" && Hh.anim != "suplex") || Hh.dead || time - (a.heldT0 ?? time) > 2.2 {   // 주인공이 맞거나 동작이 끊기면 놓친다
                if nv && a.airOv > 1 { a.heldBy = nil; a.nvHold = NvHold(phase: "drop"); setAnim(a, "fall"); a.after = "getup"; continue }
                a.heldBy = nil; a.airOv = 0; setAnim(a, "fall"); a.after = "getup"; continue
            }
            if nv { nvHeldPlace(a, Hh, dt: dt); continue }   // 네이티브: 손에 붙이기 · 메치기 호(World+NativeGrab)
            let S: (Double, Double, String)
            if Hh.anim == "suplex" {
                S = ["sx_grab": (11, 0, "hl0"), "sx_lift": (7, 8, "hl1"), "sx_arch": (-4, 20, "hl2"), "sx_slam": (-22, 0, "kd3")][Hh.pose] ?? (12, 0, "hl0")
            } else if Hh.pose == "gr_lift" { S = (2, data.spcLift, Int((time * 10).rounded(.down)) % 2 == 1 ? "hl1" : "hl1b") }
            else if Hh.pose == "gr_throw" { S = (24, 10, "hl2") } else { S = (13, 0, "hl0") }
            a.x = Hh.x + f * S.0; a.airOv = S.1; a.pose = S.2; a.prev = S.2; a.flip = !Hh.flip; a.z = Hh.z + 1; a.kb = 0
        }
        for a in ents where a.pass { passengerUpdate(a, dt) }
        let gone = ents.filter { $0.hidden && $0 !== H }
        if !gone.isEmpty { gone.forEach(retire); ents = ents.filter { !$0.hidden || $0 === H } }
        // 병 · 상자
        for si in shots.indices {
            shots[si].x += shots[si].vx * dt; shots[si].t += dt
            let s = shots[si]
            if s.friendly {
                if let e = foes().first(where: { !isDown($0) && abs($0.x - s.x) < 9 }) {
                    shots[si].dead = true; var o = HitOpts(); o.knock = true; o.splash = true
                    damage(H, e, jsRound(12 * (1 + 0.12 * Double(ci))), o); comicSFX(e.x, e.y - 86, "THUNK!")
                }
                if s.x < 0 || s.x > data.sbW { shots[si].dead = true }
                continue
            }
            let toward = jsSign(H.x - s.x) == jsSign(s.vx), dist = abs(s.x - H.x)
            if toward && dist < 44 && !s.ai { shots[si].ai = true; if manualT <= 0 { heroDuck() } }   // 쭈그리기가 준비돼 있으면 자동으로
            if !shots[si].dead && !shots[si].dodged && dist < 6 && !H.dead && isDucking(H) {   // 머리 위로 휙
                shots[si].dodged = true; sfx("dodge"); score += 60; linkFire(duckSlot(), "dodge"); stats.dodges += 1; flashText("DODGE", 0.7); emit(.perfectDodge(by: H.id))
            }
            if nv && !shots[si].dead && !shots[si].dodged && dist < 6 && !H.dead && nvRiseDodges(H, .high) {   // 네이티브 퇴근 승천권: 솟으며 병을 흘린다
                shots[si].dodged = true; stats.nvg.riseInvuln += 1; sfx("dodge")
            }
            if !shots[si].dead && !shots[si].dodged && dist < 6 && !H.dead {
                shots[si].dead = true; sfx(s.kind == "news" ? "thud" : "glass")
                let umb = bag.first { item($0.id)?.block == true }
                if let umb, rnd() < 0.6 + 0.07 * Double(umb.tier - 1) { fx("spark", s.x, s.y); emit(.blocked(target: H.id, kind: .shield)) }
                else {
                    let dummy = Actor(id: -1, def: .passenger(), x: s.x, y: s.y, flip: s.vx < 0, z: 0, pose: "m_idle0", remap: 0, grammar: nil, e: nil, pass: false)
                    var o = HitOpts(); o.react = "head"; damage(dummy, H, s.kind == "news" ? NativeContent.paperShotDmg : 7, o)
                }
            }
            if shots[si].x < 0 || shots[si].x > data.sbW { shots[si].dead = true }
        }
        shots.removeAll { $0.dead }
        for ci2 in cans.indices {
            cans[ci2].v += -tr.a * 0.03 * dt; cans[ci2].v *= pow(0.6, dt); cans[ci2].x += cans[ci2].v * dt
            if cans[ci2].x < 16 || cans[ci2].x > data.sbW - 16 { cans[ci2].v = -cans[ci2].v * 0.5; cans[ci2].x = max(16, min(data.sbW - 16, cans[ci2].x)) }
        }
        // 시간제 운행: 구간마다 정해진 시간 → 다음 역 도착(적이 남아 있어도)
        let FIGHTING = ["fight", "arrive", "board", "final", "corridor", "bonus"].contains(state)
        if FIGHTING {
            time += dt
            for k in items.indices { items[k].t += dt }
            for (i, b) in bag.enumerated() {
                guard let it = item(b.id) else { continue }
                if it.kind == "skill" || it.kind == "dodge" { b.t = min(cdOf(i), b.t + dt) }
                else if it.kind == "heal" {
                    let hc = (it.cd ?? 10) - Double(b.tier - 1); b.t = min(hc, b.t + dt)
                    if b.t >= hc && hp < maxHP * 0.5 && !H.dead {
                        b.t = 0; let v = min((it.heal ?? 18) + 6 * Double(b.tier - 1), maxHP - hp); hp += v
                        emit(.damagePop(target: H.id, value: Int(jsRound(v * data.dmgK)), style: "heal", label: nil))
                    }
                }
            }
            if !(H.hs > 0) && spc == nil { heroAI(dt) }
            comboTick(dt)
            if demo && dj?.seq != nil && !(H.hs > 0) { dojoSeqTick(dt) }
            if demo { dojoDummyTick(dt); djTick(dt); nvObjTick(dt); djRepTick(dt) }
            if nvBeam != nil { nvBeamTick(dt) }   // 네이티브 야근 광선: 다단 · 반동 · 사라짐(World+NativeBeam)
            if nvCord != nil { nvDialTick(dt) }   // 네이티브 내선 연결: 수화기 날아감 · 끌어오기(World+NativeDial)
            if nv && spc == nil { nvSampleAttackers() }
            if nvG && spc == nil { nvCrowdTick(dt) }   // 네이티브 공방: 공격권 · 대기 자리 · 끼어들기 · 가드 게이지(World+NativeCrowd)
            if spc == nil { for a in foes() where !(a.hs > 0) { foeAI(a, dt) } }
            if nv && spc == nil { nvMoveTick(dt) }
            pickup(); spcUpdate(dt)
            if config.autoSpecial && sp >= 100 && (foes().count >= 3 || foes().contains { $0.e!.boss }) { trySpecial() }
            if var eh = equipHint {
                eh.t -= dt; equipHint = eh
                if eh.t <= 0 { equipHint = nil; if manualT <= 0 { quickEquip(eh.uid) } else { renderBag() } }   // 방치 중이면 알아서 장착
            }
            passTrainUpdate(dt); evUpdate(dt); slipUpdate(); envCD = max(0, envCD - dt)
            if H.dead {
                if H.anim == "down" { wait += dt; if wait > 1.2 { wait = 0; if tower { towerResult(false) } else { showResult(false) } } }
                return
            }
        }
        if state == "corridor" { corridorUpdate(dt); return }   // 프롤로그 지하 복도
        if state == "bonus" { bonusUpdate(dt); return }
        if tower && state == "fight" { towerTick(dt); return }   // 엘리베이터 타워: 층 진행
        guard ci < line.count else { return }
        let L = line[ci], dur = legDur(L)
        if FIGHTING && !H.dead {
            let nf = foes().count
            if prevFoes > 0 && nf == 0 && state == "fight" && wave < L.waves.count { comicSay(H, "quip:wave") }
            prevFoes = nf; idleT = nf > 0 ? 0 : idleT + dt
            if idleT > 6 && !thought && H.rest == nil { thought = true; comicSay(H, "quip:think", "think") }
            if nf > 0 { thought = false }
        }
        if state == "fight" && !demo {
            expr = clearT != nil && L.end != true && wave >= L.waves.count && foes().isEmpty && legT - clearT! > 1.8 && !arriving && quickStop == nil && qi >= (L.quick?.count ?? 0) && !prologue && !cine
            if expr && !exprSaid { exprSaid = true; say("", "급행 운행 — 다음 역까지 빠르게", 1.6) }
            if (tr.phase != "stop" || departT == 0) && spc == nil { legT += dt * (expr ? 4 : 1) }
            let FW = foes()
            let last1 = FW.count == 1 && !FW[0].e!.boss && (FW[0].jug != nil || isDown(FW[0]) || FW[0].e!.hp < FW[0].e!.max * 0.35)   // 마지막 한 명이 떠 있거나 쓰러졌거나 빈사면 다음 웨이브가 미리
            if wave < L.waves.count {
                if FW.isEmpty || last1 { waveT -= dt }
                let due = legT >= nextWaveAt || ((FW.isEmpty || last1) && waveT <= 0)
                if due && FW.count + L.waves[wave].count > foeCap() { nextWaveAt = legT + 4 }   // 꽉 차 있으면 미뤄진다
                else if due { spawnWave(L.waves[wave], fromDoors: false); wave += 1; nextWaveAt = legT + dur * 0.32; waveT = 0.6 }
            } else if foes().isEmpty, let ct = clearT, L.end != true, filler < 2, dur - legT > 18, legT - ct > 1.6 {   // 옆 칸에서 넘어온다
                filler += 1
                let R2 = stage.reinf
                var list = [R2[rndInt(R2.count)], R2[rndInt(R2.count)]]
                if ci > 1 { list.append(R2[rndInt(R2.count)]) }
                spawnWave(list, fromDoors: false); say("옆 칸에서 넘어왔다!", list.compactMap { data.enemy($0)?.name }.joined(separator: " · "), 1.8)
            } else if foes().isEmpty && clearT == nil {
                clearT = legT
                if L.end != true {
                    flashText("CLEAR", 1.0); sfx("clear"); comicSay(H, "quip:clear", "speech"); skinGesture(); emit(.legCleared)
                    say("", "\(data.stations[L.stop ?? ""] ?? "")까지 \(max(0, Int((dur - legT).rounded(.up))))초 — 정시 클리어", 2.0)
                }
            }
            if clearT != nil && !foes().isEmpty { clearT = nil }
            if !arriving && legT >= dur - 3.2 && quickStop == nil && (tr.phase == "cruise" || tr.phase == "accel") {   // 도착: 남은 시간 3초에 제동
                arriving = true; tr.phase = "brake"; tr.stopAt = tr.ex + 1100; nextStop = L.stop
                let nm = data.stations[L.stop ?? ""] ?? (L.stop ?? "")
                say(L.end == true ? "이번 역은 종점 \(nm)입니다" : "곧 \(nm)에 도착합니다", "", 2.6)
                emit(.stationApproach(station: L.stop ?? "", quick: false, terminal: L.end == true))
            }
            if arriving && tr.phase == "stop" { arriving = false; setState("arrive"); doorWant = true; atStop = L.stop; arrOpen = false; emit(.doors(open: true)) }
        } else if state == "arrive" {
            if !arrOpen && tr.door > 0.95 {
                arrOpen = true; boardAt([]); let left = foes().count
                if L.end != true && !H.dead { let v = min(maxHP - hp, jsRound(maxHP * 0.12)); if v > 0 { hp += v; emit(.damagePop(target: H.id, value: Int(jsRound(v * data.dmgK)), style: "heal", label: nil)) } }   // 역에 서면 숨 돌리기
                if L.end == true { setState(left > 0 ? "final" : "end"); wait = 0; if left > 0 { say("종점 — 끝까지", "남은 적을 모두 쓰러뜨려야 내릴 수 있어요", 2.2) } }
                else if left == 0 {
                    let bonusPts = 500 + jsRoundI(max(0, dur - (clearT ?? dur)) * 25)
                    score += bonusPts; tokens += 2; stats.onTime += 1
                    emit(.textPop(x: H.x - 10, y: H.y - 84, text: "+\(bonusPts)")); say("정시 클리어", "보너스 \(bonusPts)점 · 토큰 +2 · 급행 게이지 +25", 2.0); spcGain(25)
                    emit(.arrived(onTime: true, bonus: bonusPts))
                    if L.shop == true { setState("shop"); openShop() } else { startBoard() }
                } else {
                    stats.late += 1; say("남은 적 \(left)명", "매점은 닫혔다 — 남은 적이 따라오고, 이 역에서 더 탄다", 2.4)
                    emit(.arrived(onTime: false, bonus: 0)); startBoard()
                }
            }
        } else if state == "board" {
            boardT -= dt; if boardT <= 0 { doorWant = false }
            if boardT <= 0 && tr.door < 0.03 {
                tr.phase = nvSnow?.held == true ? "stop" : "accel"; setState("fight"); atStop = nil; legT = 0; expr = false; exprSaid = false; nextWaveAt = 1.2; waveT = 0; clearT = nil; emit(.doors(open: false))
            }
        } else if state == "final" { if foes().isEmpty { setState("end"); wait = 0 } }
        else if state == "end" && stageIdx + 1 < data.game.stages.count {
            if tr.phase == "stop" { wait += dt; if wait > 1.6 { if !daily && bonusSt[stageIdx] != true { startBonus() } else { startTransfer() } } }
        }
        else if state == "transfer" { transferUpdate(dt) }
        else if state == "arrange" { if !arrTouched { arrT -= dt }; if arrT <= 0 { finishArrange() } }
        else if state == "end" { if tr.phase == "stop" { wait += dt; if wait > 1.5 { wait = 0; showResult(true) } } }
    }

    /// 웹 skinGesture(): 정시 클리어 몸짓
    func skinGesture() { guard let H = hero, !H.dead, H.def.jw else { return }; if H.anim == "idle" || H.anim == "walk" { setAnim(H, "gx_jw") } }

    /// 웹 startTransfer
    func startTransfer() { setState("transfer"); trT = 0; trLoaded = false; trNext = stageIdx + 1; emit(.stageTransfer(stage: trNext)) }
    /// 웹 transferUpdate(dt): 암전 → 카드 → 새 노선
    func transferUpdate(_ dt: Double) {
        trT += dt; fade = min(1, trT / 0.8)
        if trT > 2.2 && !trLoaded { trLoaded = true; loadStage(trNext); setState("transfer") }
        if trT > 4.4 { fade = 1; setState("fight"); emit(.runCheckpoint); say("\(stage.short) · 1호차 · \(data.cars[line[0].car].name)", stage.intro, 3.2) }
    }
    /// 웹 loadStage(k)
    func loadStage(_ k: Int) {
        if !devRun { meta.lines.insert(k); emit(.metaChanged) }
        setStage(k); hp = min(maxHP, hp + jsRound(maxHP * 0.5))
        tr.v = 0; tr.ex = 0; tr.phase = "stop"; tr.door = 1; tr.stopAt = 0; leg = 0; legStart = 0; qi = 0; quickStop = nil; qDwell = nil; departT = 2.4; doorWant = true
        atStop = startStop; nextStop = line[0].stop; stationDone = -1; prevEx = nil
        enterCar(0)
    }

    /// 웹 startRun(cfg) — devStart: 개발 시작(무도장 · 바로 가기 — 웹 GS.devStart: 이어 하기 · 노선 기록을 건드리지 않고 프롤로그도 없다)
    func startRun(devStart: Bool = false) {
        tower = false; tw = nil; bn = nil; nvSnow = nil; croute = nil; comboCD = 0; comboUse = [:]; lastCombo = nil
        schedule(after: 2.4) { $0.routeHintMaybe() }   // 웹 setTimeout(routeHintMaybe, 2400)
        if pr != nil { pr = nil; props = []; cans = []; ev = nil; pt = nil }   // 남아 있던 프롤로그(지하 복도)를 끝낸다
        cn = nil; kn = nil; tapW = nil; pBag = false; pKit = nil; skinPv = nil; scene = "subway"; talkRun = nil; talkQ = []
        daily = config.daily; rerolls = 0
        setStage(0); contrib = [:]; contribRun = [:]; imprints = genImprints(); imprintsVersion &+= 1; sp = 0; spc = nil; cut = nil; bonus = false; bonusDone = false; bonusSt = [:]
        on = true; expr = false; exprSaid = false; press = 0; prevEx = nil; slowT = 0; score = 0; kills = 0; stats = RunStats(); time = 0; stationDone = -1; doorWant = false
        bag = []; stash = []; tokens = 0; selUid = nil
        let kits = data.game.kits
        let kit = config.daily && config.dateKey != nil ? kits[Int(World.hashStr(config.dateKey!) % UInt32(kits.count))]   // 웹 dailyKit()
            : kits.first { $0.id == config.kit } ?? kits[0]
        for s in kit.bag {
            let it = newItem(s.id, 1, s.opt); it.x = s.x; it.y = s.y; it.rot = s.rot; bag.append(it); metaItem(s.id, 1)
        }
        fitBag()
        maxHP = heroMax(); hp = maxHP; lagH = hp
        hero = mkActor(.hero(), x: 40, z: 3, pose: "st0"); hero.isHero = true
        tr = TrainState(); tr.door = 1
        leg = 0; legStart = 0; qi = 0; quickStop = nil; qDwell = nil; oneBit = nil; arriving = false; atStop = startStop; departT = 2.2; doorWant = true; nextStop = line[0].stop
        freeze = 0
        enterCar(0); renderBag()
        let sg = config.daily ? 0 : min(config.stage, data.game.stages.count - 1)
        devRun = devStart; demo = false; dj = nil
        if sg == 0 && !config.daily && config.prologue && !devStart { startPrologue() }   // 웹: OPT.prologue · 자동 점검(webdriver)이 아님 · 이어 하기 아님
        if sg > 0 {   // 중간 노선 시작: 아이템 하나 · 토큰 6
            loadStage(sg); tokens += 6
            let pool = realItems().filter { item($0)?.kind == "skill" }
            addToStash(pool[rndInt(pool.count)], 1, false, rollOpt("punch", 0.6)); renderBag()
        }
        emit(.stateChanged(state))
    }

    // MARK: 매점 · 정리 · 결과(34-shop)

    /// 웹 shopPick(): 매점 카드 셋
    func shopPick() -> [(id: String, tier: Int, opt: ItemOption?)] {
        let pool = realItems(); var pick: [String] = []
        if daily, let dk = config.dateKey {   // 오늘의 판: 날짜 · 노선 · 칸 · 새로고침으로 시드를 따로 뽑아 누구에게나 같게(웹 GS.daily 갈래)
            var r = Mulberry32(seed: Int32(bitPattern: World.hashStr("\(dk):\(stageIdx):\(ci):\(rerolls)")))
            let Rr: () -> Double = { r.next() }
            if ci == 0 && stageIdx == 0 && duckSlot() < 0 && !stash.contains(where: { $0.id == "duck" }) { pick.append("duck") }
            while pick.count < 3 { let k = pool[Int((Rr() * Double(pool.count)).rounded(.down))]; if !pick.contains(k) { pick.append(k) } }
            return pick.map { k in (k, stageIdx >= 1 && Rr() < 0.3 ? 2 : 1, rollOpt(k, stageIdx >= 1 ? 0.65 : 0.45, Rr)) }
        }
        if ci == 0 && stageIdx == 0 && duckSlot() < 0 && !stash.contains(where: { $0.id == "duck" }) { pick.append("duck") }   // 첫 매점엔 쭈그리기
        while pick.count < 3 { let k = pool[rndInt(pool.count)]; if !pick.contains(k) { pick.append(k) } }
        return pick.map { k in (k, stageIdx >= 1 && rnd() < 0.3 ? 2 : 1, rollOpt(k, stageIdx >= 1 ? 0.65 : 0.45)) }
    }
    /// 웹 openShop(reroll)
    func openShop(_ reroll: Bool = false) {
        if !reroll {
            hp = min(maxHP, hp + jsRound(maxHP * 0.4 * (tw?.restK ?? 1))); shopList = shopPick()
            schedule(after: 0.42) { w in if w.state == "shop" { w.talkOnce("shop", TalkScripts.lines("shop")) } }   // 첫 매점: 사보(웹 setTimeout 420 · gOverlay 가 떠 있을 때)
        }
        emit(.shopOpened(items: shopList.map(\.id)))
    }
    /// 매점 카드 고르기(웹 .lc 클릭) · 지나가기(.skip)
    func shopChoose(_ k: Int) {
        guard state == "shop" else { return }
        if shopList.indices.contains(k) { let o = shopList[k]; if let n = addToStash(o.id, o.tier, true, o.opt) { selUid = n.uid } }
        setState("arrange"); arrT = 20 + 5 * Double(stash.count); arrTouched = false; renderBag(); hint("bag")
    }
    func shopReroll() {
        guard state == "shop", tokens >= BagSpec.rerollCost else { return }
        tokens -= BagSpec.rerollCost; rerolls += 1; shopList = shopPick(); openShop(true)
    }
    func shopCarve() {
        guard state == "shop", tokens >= 4 else { return }
        tokens -= 4
        if let worn = imprints.first(where: { $0.value == "worn" })?.key { imprints[worn] = nil; say("각인 새기기", "해진 안감을 수선했어요", 1.6) }
        else {
            var free: [String] = []
            for y in 0..<BagSpec.height { for x in 0..<BagSpec.width where imprints["\(x),\(y)"] == nil { free.append("\(x),\(y)") } }
            if !free.isEmpty { let k = free[rndInt(free.count)], t = rnd() < 0.5 ? "holster" : "pocket"; imprints[k] = t }
        }
        imprintsVersion &+= 1; openShop(true)
    }
    /// 웹 finishArrange: 남은 것 자동 정리 · 출발
    func finishArrange() {
        guard state == "arrange" else { return }
        if !stash.isEmpty { autoPack() }
        if let T = tw {   // 타워: 문을 닫고 계속 오른다(구간 돌파 뒤면 바로 출발)
            renderBag(); setState("fight")
            if T.phase == "zone" { T.phase = "move"; T.t = 0; T.vel = 0; say("다음 구간으로", "", 1.2); return }
            T.phase = "close"; T.t = 0; say("문이 닫힙니다", "", 1.2); return
        }
        startBoard(); say("문이 닫힙니다", "", 1.6)
    }
    /// 웹 showResult(win)
    func showResult(_ win: Bool) {
        if config.daily, let dk = config.dateKey { meta.daily[dk] = max(meta.daily[dk] ?? 0, score) }   // 웹 META.daily[todayKey()] — 오늘의 노선 최고 점수
        setState("over"); emit(.runEnded(win: win)); emit(.metaChanged)
    }

}
