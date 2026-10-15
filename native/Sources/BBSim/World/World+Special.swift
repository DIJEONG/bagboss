import Foundation

// 웹 47-special-ui.js 규칙 부분: 급행 게이지(spcGain) · 필살기(trySpecial · startSpecial · spcBegin · spcUpdate · spcFinish) ·
// 필살기 시간 배율(spcCamTick 의 spcTime) · 두목 등장 · 분노(bossIntro · bossRage) · 컷인 길이(cutDur)와 진행(웹은 그리기 drawCut0 가 민다) ·
// 세로 화면 카메라(camTick 의 CAMX — 필살기가 '화면에 보이는 적'만 치므로 규칙이 읽는다).

extension World {
    /// 웹 spcGain(v)
    func spcGain(_ v: Double) {
        if spc != nil { return }
        let was = sp; sp = min(100, was + v)
        if was < 100 && sp >= 100 { sfx("ready"); hint("sp"); comicSay(hero, "…끝내 볼까.", "think"); emit(.specialReady) }
    }
    /// 웹 spcKind(): 가방에서 등급 합이 가장 큰 계열
    func spcKind() -> String {
        var sum = ["fist": 0, "foot": 0, "grap": 0]
        for b in bag { if let f = item(b.id)?.fam { sum[f, default: 0] += b.tier } }
        var best = "fist"
        for k in ["fist", "foot", "grap"] where sum[k]! > sum[best]! { best = k }
        return best
    }
    /// 웹 canSpecial
    func canSpecial() -> Bool { on && spc == nil && cut == nil && hero != nil && !hero.dead && ["fight", "arrive", "board", "final"].contains(state) && !foes().isEmpty }
    /// 웹 trySpecial
    @discardableResult
    func trySpecial() -> Bool { if sp >= 100 && canSpecial() { startSpecial(); return true }; return false }
    /// 웹 startSpecial: 컷인 → (컷인이 끝나면) spcBegin
    func startSpecial() {
        let kind = spcKind(); cmdPush(["fist": "막차 러시", "foot": "회전 폭풍", "grap": "종착역"][kind] ?? "필살기", "sp")
        let H = hero!; sp = 0; sfx("gong"); emit(.specialUsed)
        for a in foes() { a.action = nil; a.queue = [] }
        H.action = nil; H.queue = []; setAnim(H, "idle")
        cut = CutState(k: "spc", kind: kind, dur: cutDur("spc_" + kind, 1.05)); emit(.cutIn(kind: "spc", actor: H.id, seconds: cut!.dur))
        meta.spc[kind, default: 0] += 1; emit(.metaChanged)
    }
    /// 웹 cutDur(key, full): 이미 본 컷인은 짧게
    func cutDur(_ key: String, _ full: Double) -> Double {
        let seen = meta.seenCut.contains(key); meta.seenCut.insert(key); emit(.metaChanged)
        return config.shortCut && seen ? min(full, 0.5) : full
    }
    /// 웹 drawCut0 의 시간 진행 · 끝 처리(그리기 대신 규칙 시계로)
    func cutAdvance(_ rdt: Double) {
        guard var C = cut else { return }
        C.t += rdt; cut = C
        if C.t >= C.dur {
            cut = nil
            if C.k == "spc", let k = C.kind { spcBegin(k) }
            if C.k == "vs" || C.k == "rage", let b = C.boss { comicSay(b, C.k == "vs" ? "bossLine:" + (b.e?.t ?? "") : (data.bossInfo[b.e?.t ?? ""]?.rage ?? "…"), "shout") }
            emit(.cutInEnded(kind: C.k))
        }
    }
    /// 웹 spcBegin(kind)
    func spcBegin(_ kind: String) {
        guard let H = hero else { return }
        let S = SpecialRun(kind: kind, x0: H.x); spc = S; sfx("slowIn")
        for a in foes() { a.e!.stun = max(a.e!.stun, 9) }
        if kind == "fist" {
            let L = foes().filter { $0.x < H.x }.count, R = foes().count - L
            S.dir = R >= L ? 1 : -1; S.x1 = S.dir > 0 ? data.sbW - 28 : 28; H.flip = S.dir < 0
            if nv { nvRushBegin(S) }   // 네이티브: 뎀프시 롤 풍 러시(World+NativeRush)
        }
        if kind == "foot" { S.pole = (prologue || tower) ? H.x : data.poles.reduce(data.poles[0]) { abs($1 - H.x) < abs($0 - H.x) ? $1 : $0 } }
        if kind == "grap" { S.tgt = stableSortD(foes()) { $1.e!.hp - $0.e!.hp }.first; S.dir = (S.tgt?.x ?? 0) < data.sbW / 2 ? 1 : -1 }
    }
    /// 웹 spcVis(a): 화면에 보이는 적만
    func spcVis(_ a: Actor) -> Bool { let x = a.x; return x >= camX - 6 && x <= camX + viewW + 6 && x > -4 && x < data.sbW + 4 }
    func legRunOff() { for a in ents { a.legRun = false } }
    /// 웹 spcUpdate(dt)
    func spcUpdate(_ dt: Double) {
        guard let S = spc, let H = hero else { return }
        S.t += dt
        let K = (1 + 0.12 * Double(ci)) * (1 + 0.2 * Double(stageIdx))
        func hit(_ a: Actor, _ d: Double, _ o: HitOpts) {
            if a.dead || !spcVis(a) { return }
            damage(H, a, max(1, jsRound(d * K * (a.e!.boss ? 0.5 : 1))), o); S.n += 1; spcHitT = 0.09
        }
        if S.kind == "fist" && nv { nvRushUpdate(S, dt, hit: hit) }   // 네이티브: 위빙 + 좌우 훅 + 올려치기
        else if S.kind == "fist" {   // 막차 러시: 칸 끝까지 달리며 연타 → 어퍼컷으로 전원 띄우기
            let dur = 0.85
            if S.t < dur {
                let nx = S.x0 + (S.x1 - S.x0) * min(1, S.t / dur), mdx = nx - H.x; H.x = nx; H.gph += abs(mdx) / 66; H.legRun = true
                let sw = Int((S.t / 0.1).rounded(.down)); if sw != S.sw { S.sw = sw; setAnim(H, ["jab", "cross", "hook"][sw % 3]); sfx("swing") }
                for a in foes() {
                    let id = ObjectIdentifier(a)
                    if !a.dead && spcVis(a) && (a.x - H.x) * S.dir > -6 && abs(a.x - H.x) < 18 && (S.hits[id] ?? 0) < 3 && S.t - (S.hl[id] ?? -1) > 0.07 {
                        S.hits[id] = (S.hits[id] ?? 0) + 1; S.hl[id] = S.t; var o = HitOpts(); o.react = "head"; hit(a, 4, o)
                        if !S.carry.contains(where: { $0 === a }) { S.carry.append(a) }
                    }
                }
                for (k, a) in S.carry.enumerated() where !a.dead {   // 열차처럼 앞으로 밀고 간다
                    let nx2 = max(16, min(data.sbW - 16, H.x + S.dir * (14 + Double(k) * 9))); a.gph -= abs(nx2 - a.x) / 66; a.legRun = true; a.x = nx2; a.kb = 0; a.flip = S.dir > 0
                }
            } else if !S.fin {
                S.fin = true; legRunOff(); setAnim(H, "upper")
                var grp = S.carry
                for a in foes() where (a.x - H.x) * S.dir > -8 && abs(a.x - H.x) < 34 && !grp.contains(where: { $0 === a }) { grp.append(a) }
                for a in grp { var o = HitOpts(); o.react = "launch"; o.crit = true; hit(a, 22, o) }
                spcFinish()
            }
        }
        if S.kind == "foot" {   // 회전 폭풍: 기둥을 잡고 연속 회전
            let dur = 1.15
            if S.t < 0.15 { H.x += (S.pole - (H.flip ? -5 : 5) - H.x) * min(1, dt * 14) }
            else if S.t < dur {
                if H.anim != "polespin" { setAnim(H, "polespin") }
                let tk = Int((S.t / 0.17).rounded(.down))
                if tk != S.tk {
                    S.tk = tk; H.flip.toggle(); sfx("swing"); fxD(FxDetail(kind: "swirl", x: S.pole, y: H.y - 30, n: tk))
                    for a in foes() { let d = abs(a.x - S.pole); if d < 110 { if d < 46 { hit(a, 5, HitOpts()) }; a.kb = jsSign(S.pole - a.x) * 70 } }
                }
            } else if !S.fin {
                S.fin = true
                for a in foes() where abs(a.x - S.pole) < 72 { var o = HitOpts(); o.knock = true; hit(a, 20, o) }
                fxD(FxDetail(kind: "swirl", x: S.pole, y: H.y - 30, n: 99, big: true))   // 마지막 큰 소용돌이
                spcFinish()
            }
        }
        if S.kind == "grap" {   // 종착역: 가장 센 적을 잡아 칸 끝까지 끌고 가 바닥에 꽂는다
            if S.tgt == nil || S.tgt!.dead { if !S.fin { S.fin = true; spcFinish() } }
            else if let T = S.tgt {
                if S.t < 0.3 { let mdx = (T.x - S.dir * 14 - H.x) * min(1, dt * 12); H.x += mdx; H.gph += abs(mdx) / 66; H.legRun = abs(mdx) > 0.2; face(H, T.x) }
                else {
                    let f = S.dir
                    func place(_ dx: Double, _ air: Double, _ pose: String) { T.x = H.x + f * dx; T.airOv = air; T.pose = pose; T.prev = pose; T.flip = f > 0; T.kb = 0; T.dash = 0; T.action = nil; T.queue = []; T.anim = "held" }
                    if S.t < 1.0 {
                        if !S.grab { S.grab = true; setAnim(H, "spcHold"); sfx("swing") }
                        H.flip = f < 0
                        if S.t > 0.42 {
                            let ox = H.x; H.x = max(30, min(data.sbW - 30, H.x + f * 240 * dt)); let mdx = H.x - ox
                            H.gph += abs(mdx) / 66; H.legRun = abs(mdx) > 0.05; T.gph -= abs(mdx) / 66; T.legRun = H.legRun
                        }
                        if nv { nvSpcPlace(T, H, nil)
                            if nvGrabTune && S.t > 0.42 { S.dustT -= dt; if S.dustT <= 0 { S.dustT = 0.07; fx("dust", T.x, T.y, -f) } }   // 끌리는 발 먼지(눈 승강장 = 눈가루)
                        } else { place(13, 0, "hl0") }
                    } else if S.t < 1.28 {
                        if !S.lift { S.lift = true; legRunOff(); setAnim(H, "spcLift"); sfx("swing") }
                        if nv { nvSpcPlace(T, H, nil) } else { place(2, data.spcLift, Int((time * 10).rounded(.down)) % 2 == 1 ? "hl1" : "hl1b") }
                    } else if S.t < 1.4 {
                        if !S.slam { S.slam = true; setAnim(H, "spcSlam") }
                        if nv { nvSpcPlace(T, H, (S.t - 1.28) / 0.12) } else { place(24, 10, "hl2") }
                    } else if !S.fin {
                        S.fin = true; T.airOv = 0; T.anim = "idle"; T.nvHold = nil
                        var o = HitOpts(); o.knock = true; o.crit = true; hit(T, 42, o); groundImpact(T.x, T.y, 1.8); fx("wave", T.x, T.y)
                        for a in foes() where a !== T { let d = abs(a.x - T.x); if d < 90 { var so = HitOpts(); so.knock = d < 60; so.splash = true; hit(a, max(4, 16 * (1 - d / 90)), so) } }
                        shake(3); spcFinish()
                    }
                }
            }
        }
        if S.fin {
            if S.finT == nil { S.finT = S.t }
            if S.t > S.finT! + 0.55 { legRunOff(); spc = nil; for a in foes() { a.e!.stun = min(a.e!.stun, 0.8) } }
        }
    }
    /// 웹 spcFinish
    func spcFinish() {
        guard let S = spc else { return }
        comicSFX(data.sbW / 2, 96, ["fist": "KA-POW!", "foot": "WHOOOSH!", "grap": "KA-BOOM!"][S.kind] ?? "KA-POW!", force: true); sfx("boom"); spcRel = 0
        emit(.comboTotal(hits: S.n, damage: 0))
    }
    /// 웹 spcCamTick(rdt) 중 규칙에 닿는 부분: 필살기 시간 배율(spcTime) · 줌(camZ)
    func spcCamTick(_ rdt: Double) {
        guard hero != nil else { return }
        let S = spc
        spcHitT = max(0, spcHitT - rdt)
        let djZ = demo && S == nil && (dj?.zoom ?? 1) > 1, Dm = djZ ? dojoDummy() : nil   // 무도장 확대: 주인공과 허수아비 사이를 크게
        var zT = bn != nil ? 1.3 : djZ ? (dj?.zoom ?? 1) : 1.0, tK = 1.0   // 보너스: 주인공과 차 사이를 크게
        if let S, !S.fin, nv, S.kind == "fist" {   // 네이티브 러시: 점점 다가가며(줌 1.3 → 1.5) 점점 빨라진다(0.45 → 0.85) · 박자마다 짧게 멈칫
            let p = min(1, S.t / SpecialRun.nvDur); zT = S.nvFin0 != nil ? 1.58 : 1.3 + 0.2 * p
            tK = S.nvFin0 != nil ? 0.32 : spcHitT > 0 ? 0.28 : 0.45 + 0.4 * p; spcRel = 0
        }
        else if let S, !S.fin { zT = 1.38; tK = spcHitT > 0 ? 0.2 : 0.5; spcRel = 0 }
        else if let S, S.fin { spcRel = (spcRel ?? 0) + rdt; let r = spcRel!; zT = r < 0.12 ? 1.55 : 1.55 - 0.55 * min(1, (r - 0.12) / 0.6); tK = r < 0.45 ? 0.15 : 0.15 + 0.85 * min(1, (r - 0.45) / 0.35) }
        else if let r0 = spcRel, r0 < 1.4 {
            spcRel = r0 + rdt; let r = spcRel!
            zT = max(1, 1.55 - 0.55 * min(1, (r - 0.12) / 0.6)); tK = 0.15 + 0.85 * min(1, max(0, (r - 0.45) / 0.35))
            if r >= 1.4 { zT = 1; tK = 1; spcRel = nil }
        }
        camZ += (zT - camZ) * min(1, rdt * (zT > camZ ? 9 : 5))
        if let H = hero, skinPv == nil {   // 웹 GS.camC(확대 중심 — 표현용, 규칙은 읽지 않는다)
            let tx = bn != nil ? ((H.x + bn!.car.x) / 2 + 10 - cam) / W : djZ ? ((H.x + (Dm?.x ?? H.x)) / 2) / W : H.x / W
            let ty = bn != nil ? (bn!.car.y - 34) / data.sbH : djZ ? (H.y - 40 - (Dm?.jug.map { $0.h * 0.5 } ?? 0)) / data.sbH : (H.y - 44) / data.sbH
            let c0 = camC ?? SIMD2(tx, ty), k = min(1, rdt * 10)
            camC = SIMD2(c0.x + (tx - c0.x) * k, c0.y + (ty - c0.y) * k)
        }
        spcTime += (tK - spcTime) * min(1, rdt * 14)
    }
    /// 웹 camTick(rdt): 세로 화면 카메라(주인공 앞 + 적 무게중심)
    func camTick(_ rdt: Double) {
        guard viewW < W, on, let H = hero else { camX = 0; return }
        if tower { camX += ((W - viewW) / 2 - camX) * min(1, rdt * 6); return }   // 타워: 칸이 화면에 꼭 맞게 가운데 고정
        if let B = bn { let c = (H.x + B.car.x) / 2; camX += (max(0, min(W - viewW, c - viewW / 2)) - camX) * min(1, rdt * 3); return }
        if cine { let sx = H.x - cam; camX += (max(0, min(W - viewW, sx - viewW / 2 + 20)) - camX) * min(1, rdt * 3); return }   // 프롤로그 거리
        let F = foes(); var c = H.x + H.f * 22
        if !F.isEmpty && spc == nil { let fx = F.reduce(0) { $0 + $1.x } / Double(F.count); c = c * 0.62 + fx * 0.38 }
        let tx = max(0, min(W - viewW, c - viewW / 2))
        camX += (tx - camX) * min(1, rdt * (spc != nil ? 6 : 2.6))
    }

    /// 웹 bossIntro(a): 두목 등장 VS 컷인
    func bossIntro(_ a: Actor) {
        guard let e = a.e, data.bossInfo[e.t] != nil else { return }
        schedule(after: 2.6) { $0.hint("boss") }
        sfx("brass"); emit(.bossAppear(actor: a.id))
        cut = CutState(k: "vs", boss: a, dur: cutDur("vs_" + e.t, 1.9)); emit(.cutIn(kind: "vs", actor: a.id, seconds: cut!.dur))
    }
    /// 웹 bossRage(a): 체력 절반 — 빨라진다
    func bossRage(_ a: Actor) {
        guard let e = a.e else { return }
        e.raged = true; e.cd *= 0.72; e.spd *= 1.18; sfx("rage"); emit(.bossRage(actor: a.id))
        cut = CutState(k: "rage", boss: a, dur: cutDur("rage_" + e.t, 1.0)); emit(.cutIn(kind: "rage", actor: a.id, seconds: cut!.dur))
    }
}

extension World {
    /// 네이티브 종착역: 웹 place(dx, air, 자세) 대신 손에 붙이기 · 꽂기 호(World+NativeGrab) — arcP = 꽂는 0.12초 진행
    func nvSpcPlace(_ T: Actor, _ H: Actor, _ arcP: Double?) {
        T.kb = 0; T.dash = 0; T.action = nil; T.queue = []
        if T.anim != "held" { T.anim = "held"; T.si = 0 }
        nvHeldPlace(T, H, arcP: arcP.map { max(0, min(1, $0)) })
    }
}
