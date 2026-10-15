import Foundation

// 네이티브 동작 개편 ① 이동 판단(SimConfig.nativeMoves — 웹과 일부러 다르다. 꺼지면 이 파일은 불리지 않는다).
// 웹 approach: '멀면(주인공 34px · 적 56px) 무조건 질주' → 여기서는 거리와 '이유'로 고른다.
//   · 작은 틈(≤30px)       : 스텝 인 — 앞발을 내딛는 짧은 셔플(0.11초 돌진) 뒤 바로 친다(주인공만)
//   · 중간 거리            : 가드를 올린 채 걷기(빠른 걸음 — 보폭 위상 gph 는 거리로만 나아가 발이 미끄러지지 않는다)
//   · 멀고 이유가 있을 때  : 질주 — 1칸 출발 기울기(nv_go) → 가속 → 최고 속도 → 남은 거리가 제동 거리가 되면 앞발을 박고 미끄러져 선다(nv_skid · 먼지)
//     이유(주인공): 쫓기(떠 있는 · 밀려난 적) · 대상이 치려고 준비 중 · 마지막 웨이브 정리 · 콤보 경로 진행 · 탭 창 · 남은 시간 10초 미만 · 아주 멂(150px+)
//   · 히스테리시스: 질주는 들어갈 때(70px)보다 훨씬 가까워질 때까지(26px) 유지 · 걷기로 바뀐 뒤 0.25초 안엔 다시 질주하지 않는다 → 깜빡임 없음
//   · 적: 같은 규칙이되 무겁게(가속 · 감속이 느리고 질주 문턱이 멀다 · 덩치(heavy)는 더 느리다). 스텝 인은 없다
// 상태는 Actor.nvm(NvMove) — 규칙 난수를 쓰지 않는다(결정적).

/// 인물 한 명의 이동 상태(네이티브)
struct NvMove {
    /// 0 서기 · 1 걷기 · 2 질주 · 3 미끄러져 서기
    var mode = 0
    /// 지금 속력(px/s, 진행 방향 dir 기준)
    var v = 0.0, dir = 0.0
    /// 지금 상태에 머문 시간 · 마지막 상태 전환 시각(깜빡임 방지)
    var t = 0.0, changedAt = -9.0
    /// 몸 기울기(라디안 — 관절 tilt 에 더한다) · 목표
    var lean = 0.0, leanT = 0.0
    /// 이번 틱에 이동 명령을 받았는가(frameNo)
    var cmd = -1
    /// 마지막 스텝 인 · 미끄러짐 먼지 시각
    var stepAt = -9.0, dustAt = -9.0
    /// 상태 전환 기록(테스트용 — 개수만)
    var switches = 0
    /// 미끄러짐이 멈출 목표 x(지나치지 않게) · 마지막 미끄러짐이 끝난 시각(직후 작은 보정엔 질주하지 않는다)
    var tx: Double?, skidEndAt = -9.0
}

/// 이동 손맛 값(주인공 · 적 · 덩치)
struct NvMoveParams {
    var enter: Double, exit: Double, farAlways: Double
    var walkK: Double, accel: Double, walkAccel: Double, decel: Double, skidV: Double
    /// 미끄러져 서기 감속(px/s²) — 걷기 감속(decel)보다 부드럽게 해서 미끄러짐이 눈에 보이게(주인공 156px/s → 약 0.15초 · 13px — 감독 피드백으로 짧게: 620 → 900)
    var skidDecel: Double
    static let hero = NvMoveParams(enter: 70, exit: 26, farAlways: 150, walkK: 1.6, accel: 950, walkAccel: 520, decel: 1300, skidV: 95, skidDecel: 900)
    static let foe = NvMoveParams(enter: 92, exit: 40, farAlways: 92, walkK: 1, accel: 560, walkAccel: 300, decel: 760, skidV: 70, skidDecel: 700)
    static let heavy = NvMoveParams(enter: 100, exit: 46, farAlways: 100, walkK: 1, accel: 380, walkAccel: 220, decel: 520, skidV: 60, skidDecel: 520)
    /// 미끄러짐이 끝나는 속력
    static let skidEndV = 22.0
    /// 지금 속력 v 에서 미끄러져 멈출 때까지 가는 거리
    func slide(_ v: Double) -> Double { max(0, v * v - NvMoveParams.skidEndV * NvMoveParams.skidEndV) / (2 * skidDecel) }
}

extension World {
    var nv: Bool { config.nativeMoves }

    func nvParams(_ c: Actor) -> NvMoveParams { c === hero ? .hero : (c.e?.heavy == true || c.e?.boss == true) ? .heavy : .foe }

    /// 주인공이 질주할 '이유'
    func nvSprintReason(_ c: Actor, _ tx: Double, _ chase: Bool) -> Bool {
        if chase || tapW != nil || croute != nil || bossBreak != nil { return true }
        let F = foes()
        if F.contains(where: { a in abs(a.x - tx) < 40 && a.action != nil && !(a.action!.fired) && data.foeW[a.anim] != nil }) { return true }   // 치려고 준비 중
        if ci < line.count {
            let L = line[ci]
            if wave >= L.waves.count && F.count <= 2 { return true }          // 마지막 웨이브 정리
            if state == "fight" && legDur(L) - legT < 10 { return true }      // 시간이 없다
        }
        return false
    }

    func nvSetMode(_ m: inout NvMove, _ mode: Int) {
        guard m.mode != mode else { return }
        m.mode = mode; m.t = 0; m.changedAt = gameTime; m.switches += 1
    }

    /// 미끄러져 서기 시작(앞발을 박는다)
    func nvBeginSkid(_ c: Actor, _ tx: Double? = nil) {
        nvSetMode(&c.nvm, 3); c.nvm.tx = tx
        c.nvm.leanT = -0.2
        setAnim(c, "nv_skid")
        fx("dust", c.x + c.nvm.dir * 4, c.y, -c.nvm.dir); c.nvm.dustAt = gameTime
        if c === hero { sfx("dodge") }
    }

    /// 웹 approach 대신(네이티브): 도착하면 true
    @discardableResult
    func nvApproach(_ c: Actor, _ tx: Double, _ spd: Double, _ dt: Double, _ rs: Double, _ chase: Bool) -> Bool {
        var m = c.nvm
        defer { c.nvm = m }
        m.cmd = frameNo
        if m.mode == 3 { return false }   // 미끄러지는 중: 끝날 때까지 맡겨 둔다(nvMoveTick)
        let dx = tx - c.x, g = abs(dx), d = jsSign(dx), P = nvParams(c), isH = c === hero
        if g < 1.5 {   // 도착
            if m.mode == 2 && m.v > P.skidV && !chase { c.nvm = m; nvBeginSkid(c, tx); m = c.nvm; return true }
            nvSetMode(&m, 0); m.v = 0; m.leanT = 0
            if c.anim == "walk" { setAnim(c, "idle") }
            return true
        }
        // 질주 중 방향이 바뀌면(대상이 뒤로 넘어감) 먼저 미끄러져 선다
        if m.mode == 2 && d != m.dir && m.v > 60 { c.nvm = m; nvBeginSkid(c); m = c.nvm; return false }
        if m.dir != d { m.v = m.mode == 0 ? 0 : m.v * 0.3; m.dir = d }
        // 상태 고르기
        var want = m.mode == 3 ? 0 : m.mode
        let canSprint = rs > spd
        if m.mode == 2 {
            // 제동 판단은 '지금 속력'의 미끄러짐 거리로 — 빠르면 반드시 미끄러져 선다(걷기로 바로 떨어지지 않는다)
            if !chase && m.v > P.skidV && g <= P.slide(m.v) + 2 { c.nvm = m; nvBeginSkid(c, tx); m = c.nvm; return false }
            // 걷기로 내려가는 것은 느린 질주(막 출발했거나 이미 줄어든 속도)일 때만 · 질주에 들어간 뒤 0.25초는 유지(깜빡임 방지)
            if m.t > 0.25 && (!canSprint || (g <= P.exit && m.v <= P.skidV)) { want = 1 }
        } else if canSprint {
            let reason = isH ? nvSprintReason(c, tx, chase) : true
            let settled = gameTime - m.changedAt > 0.25 || m.mode == 0
            let postSkid = gameTime - m.skidEndAt < 0.6 && g < P.farAlways && !chase   // 미끄러진 직후 작은 보정은 걷기 · 스텝 인으로
            if settled && !postSkid && ((g > P.enter && reason) || g > P.farAlways || (chase && g > 24)) { want = 2 }
            else { want = 1 }
        } else { want = 1 }
        // 작은 틈: 스텝 인(주인공 · 서 있거나 걷는 중 · 질주가 아닐 때)
        if isH && want == 1 && m.mode != 2 && g > 5 && g <= 30 && gameTime - m.stepAt > 0.55 && canAct(c) && !chase {
            m.stepAt = gameTime; nvSetMode(&m, 0); m.v = 0; m.leanT = 0.18
            setAnim(c, "nv_step"); c.dash = d * g / 0.11; c.dashT = 0.11; c.gph += g / 28.8
            fx("dust", c.x - d * 5, c.y, d)
            return false
        }
        if want == 2 && m.mode != 2 {   // 출발: 한 칸 몸을 던진다(주인공 · 적 모두)
            let fromStand = m.v < 40
            nvSetMode(&m, 2); m.leanT = 0.3
            if fromStand && canAct(c) {
                c.nvm = m; setAnim(c, "nv_go"); m = c.nvm
                fx("dust", c.x - d * 5, c.y, c.f); if isH { sfx("whoosh") }
            }
        } else if want == 1 && m.mode != 1 { nvSetMode(&m, 1) }
        // 속력 · 위치
        let top = m.mode == 2 ? rs : spd * P.walkK
        let acc = m.mode == 2 ? P.accel : (m.v > top ? P.decel : P.walkAccel)
        m.v = m.v < top ? min(top, m.v + acc * dt) : max(top, m.v - acc * dt)
        if m.mode == 1 && m.v < 8 { m.v = min(top, 8 + m.v) }   // 걷기 첫 발
        let mx = d * min(g, m.v * dt); c.x += mx
        if m.mode == 2 {
            c.gph += abs(mx) / max(40, min(66, m.v * 0.42))
            c.runU = gameTime + 0.09
            m.leanT = m.v < top * 0.85 ? 0.3 : 0.14
        } else {
            c.gph += abs(mx) / (4 * 0.3 * 24) * ((mx * c.f) < -0.01 ? -1 : 1)
            m.leanT = 0.03
        }
        if c.anim == "idle" { setAnim(c, "walk") }
        return false
    }

    /// 매 틱(인공지능 뒤): 미끄러짐 · 출발 칸 이동 · 명령이 끊기면 정리 · 기울기
    func nvMoveTick(_ dt: Double) {
        for c in ents where !c.pass && !c.dead {
            var m = c.nvm
            m.t += dt
            if m.mode == 3 {
                if c.anim != "nv_skid" { nvSetMode(&m, 0); m.v = 0 }   // 맞거나 다른 동작이 끊었다
                else {
                    let P = nvParams(c)
                    m.v = max(0, m.v - P.skidDecel * dt)
                    var nx = c.x + m.dir * m.v * dt
                    if let tx = m.tx, (nx - tx) * m.dir > 0 { nx = tx; m.v = min(m.v, NvMoveParams.skidEndV - 1) }   // 목표를 지나치지 않는다
                    c.x = clamp(nx, AW0(), AW1())
                    if gameTime - m.dustAt > 0.06 { m.dustAt = gameTime; fx("dust", c.x + m.dir * 4, c.y, -m.dir) }
                    if m.v < NvMoveParams.skidEndV { nvSetMode(&m, 0); m.v = 0; m.leanT = 0; m.tx = nil; m.skidEndAt = gameTime; setAnim(c, "nv_skidEnd") }
                }
            } else if m.mode == 2 && c.anim == "nv_go" {   // 출발 칸: 인공지능이 쉬는 동안도 가속하며 나간다
                let P = nvParams(c)
                m.v = min(c === hero ? 156 : 120, m.v + P.accel * dt)
                let mx = m.dir * m.v * dt; c.x = clamp(c.x + mx, AW0(), AW1()); c.gph += abs(mx) / 40
                m.cmd = frameNo
            } else if m.mode != 0 && m.cmd != frameNo && !(c.hs > 0) {   // 이번 틱엔 움직이라는 명령이 없었다 → 멈춘다(공격 · 반응으로 넘어감)
                if m.mode == 2 && m.v > nvParams(c).skidV && (c.anim == "walk" || c.anim == "idle") { c.nvm = m; nvBeginSkid(c); m = c.nvm }
                else { nvSetMode(&m, 0); m.v = 0; m.leanT = 0 }
            }
            if !(c.anim == "walk" || c.anim == "idle" || c.anim.hasPrefix("nv_")) { m.leanT = 0 }
            m.lean += (m.leanT - m.lean) * min(1, dt * 16)
            c.nvm = m
        }
    }
}

extension World {
    /// 네이티브 숄더 롤: 흘리기(SLIP) 판정 자세 — 앞어깨를 올려 몸을 뒤로 굴리는 칸들
    func nvSlipPose(_ c: Actor) -> Bool { c.anim == "nv_roll" && (c.pose.hasPrefix("sr_roll") || c.pose == "sr_ret") }
}
