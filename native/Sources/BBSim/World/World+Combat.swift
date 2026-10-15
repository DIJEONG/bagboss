import Foundation
import BBContent
import BBAnim

// 웹 28-attack-feel.js 규칙(atkStartup · cueFor · timeToCue · JUST_W) + 29-combat-flow.js(useSkill · 쉬기 · heroAI · foeAI · foeStrike ·
// 협공 flankCall · 쭈그리기 heroDuck · 직접 조작 manual · 저스트 justCounter) + 13 strapAir.

extension World {
    // MARK: 28 attack-feel

    /// 웹 atkStartup(a): 시작부터 적중 자세까지 걸리는 시간(초)
    func atkStartup(_ a: String) -> Double {
        guard let S = data.seqJW[a], let c = data.jwCue[a] else { return 0 }
        var t = 0.0
        for s in S { if s.pose == c { break }; t += s.n }
        return t / 1000
    }
    /// 웹 cueFor(c, anim, fb)
    func cueFor(_ c: Actor, _ anim: String, _ fb: String?) -> String? { (c.def.jw ? data.jwCue[anim] : nil) ?? fb }
    /// 웹 timeToCue(c): 적 공격의 타격 순간까지 남은 게임 시간
    func timeToCue(_ c: Actor) -> Double? {
        guard let A = c.action, !A.fired, let cue = A.cue else { return nil }
        let seq = seqOf(c.anim, c), i = c.si
        guard seq.indices.contains(i) else { return nil }
        if seq[i].pose == cue { return 0 }
        var t = Double(max(0, c.hold)) / animFps
        for k in (i + 1)..<max(i + 1, seq.count) {
            let s = seq[k]
            if s.pose == cue { return t }
            var nn = s.n
            if c.e != nil, let w = data.foeW[c.anim], !smearPose(s.pose) { nn = s.n * (data.foeTell[w] ?? 1) }
            t += Double(max(1, jsRoundI(nn * animFps / 1000))) / animFps
        }
        return nil
    }
    /// 웹 JUST_W: 타격 직전 0.16초(이어폰이 있으면 넓게)
    func justW() -> Double { 0.16 * (1 + pv("ear", 0.4, 0.1)) }

    // MARK: 29 기술 쓰기

    /// 웹 useSkill(i, T, manual): 기술 동작 요청 — 피해는 큐 자세의 heroSkill 에서
    func useSkill(_ i: Int, _ T: Actor, _ manual: Bool) {
        guard let H = hero, bag.indices.contains(i), let it = item(bag[i].id) else { return }
        let b = bag[i]
        b.opener = !manual && !demo && croute == nil && it.cond != nil && rules.role(b.id) == "S" && !condOK(it.cond, H, T, foes())   // 시작기: 조건 없이 콤보를 열 때는 띄우기 위주로
        b.t = 0; comboOnUse(b); sfx("swing"); H.pick = nil; if it.back != true { face(H, T.x) }
        var anim = it.anim ?? "jab", cue = it.cue
        let f = H.f
        if it.combo == true {
            b.combo = time - (b.last ?? -9) < 2.4 ? ((b.combo ?? 0) + 1) % 4 : 0; b.last = time
            anim = ["jab", "cross", "hook", "upper"][b.combo!]; cue = ["m_jab", "m_cross", "hook", "up"][b.combo!]
            if nvG && b.combo! < 3 && nvGuardOf(T) == 2 { b.combo = 3; anim = "upper"; cue = "up" }   // 네이티브: 앉아 막는 상대엔 어퍼(중단)로 바꿔 친다
        }
        if H.scoopNext && anim == "upper" { anim = "scoop"; cue = data.jwCue["scoop"] }
        H.scoopNext = false
        if let J = T.jug, J.h > 6, anim == "round" || anim == "charge" || anim == "axe" { anim += "_air"; cue = data.jwCue[anim] }   // 떠 있는 적: 공중 마무리
        let HM = ["jab": "hm_swing", "cross": "hm_back", "hook": "hm_swing", "upper": "hm_up", "elbow": "hm_back", "bfist": "hm_back", "stomp": "hm_down"]   // 복도: 장도리 동작으로
        let hammer = prologue && !(pr?.bag ?? false)
        if hammer && it.combo == true { b.combo = (b.combo ?? 0) % 3; anim = ["hm_down", "hm_swing", "hm_back"][b.combo!]; cue = data.jwCue[anim] }   // 장도리 3콤보
        else if hammer, let hm = HM[anim] { anim = hm; cue = data.jwCue[anim] }
        if bonus && anim == "throw" { anim = "hook"; cue = data.jwCue["hook"] }   // 차는 들 수 없다
        let opts = ActionReq(cue: cueFor(H, anim, cue), wpn: hammer ? "w_hammer" : it.wpn) { [unowned self] _ in self.heroSkill(i, manual) }
        if let F = data.atkFeel[anim], F.step != 0, it.back != true, !holding(H) {
            let su = atkStartup(anim); if su > 0 { H.dash = f * F.step / su; H.dashT = su }
        }
        let aname = anim
        func visCue(_ pose: String) -> (Actor) -> Void { { [unowned self] c in self.emit(.actionCue(actor: c.id, anim: aname, cue: pose)) } }
        if anim.hasPrefix("hm_") { opts.cues = ["hm_dhit": visCue("hm_dhit"), "hm_hit": visCue("hm_hit"), "hm_bhit": visCue("hm_bhit")] }   // 장도리 궤적선(웹 hmTrail)
        if anim == "hook" { opts.cues = ["h_smear": visCue("h_smear")] }
        if anim == "uthrust" && bagHasLink("pull") { opts.cues = ["ut_hit_ft": visCue("ut_hit_ft")] }
        if anim == "skick" {
            let hit = opts.onCue
            opts.onCue = { [unowned self] c in   // 초승달은 타격 신호와 같은 순간에 — 회전 중심(몸통 가운데)은 마지막으로 그린 관절(웹 H.jw.W2)
                self.emit(.actionCue(actor: c.id, anim: "skick", cue: "crescent"))
                let p = self.crescentPivot(H, f); self.fxD(FxDetail(kind: "crescent", x: p.x, y: p.y, dir: f))
                hit?(c) }
            opts.cues = ["sk_jump": visCue("sk_jump"), "sk_land": visCue("sk_land")]
        }
        if (anim == "round" || anim == "round_air") && opts.cues.isEmpty {
            opts.cues = ["r_spin2": visCue("r_spin2"), "r_smear": visCue("r_smear"), "r_hit_rt": visCue("r_hit_rt")]
        }
        if anim == "fkick" {
            opts.cues = ["fk_smear": visCue("fk_smear"),
                         "fk_jump": { _ in let dd = max(0, abs(T.x - H.x) - 20); H.dash = f * dd / 0.2; H.dashT = 0.2 },
                         "fk_land": { [unowned self] _ in H.dash = 0; H.dashT = 0; self.fx("dust", H.x, H.y, H.f) }]
        }
        if anim == "charge" || anim == "charge_air" {
            opts.cues = ["ch_run": { _ in let d = max(0, abs(T.x - H.x) - 16); H.dash = f * max(300, d / 0.14); H.dashT = max(0.05, min(0.14, d / 300)) }]   // 출발 순간 튀어 나간다
        }
        if anim == "cycle" {   // 공중 자전거 차기: 뛰어올라 두 다리를 번갈아 3연타
            let st = sStats(i)
            let kickFx: (Double) -> Void = { [unowned self] k in   // 웹 kickFx: 페달 바퀴 · 연타 별
                self.emit(.actionCue(actor: H.id, anim: "cycle", cue: "kick"))
                let air = self.data.animTables.poses[live: H.pose]?.air ?? 0
                self.fxD(FxDetail(kind: "cyw", x: H.x + f * 13, y: H.y - 28 - air, dir: f))
                if let J = T.jug, !T.dead { self.fxD(FxDetail(kind: "cystar", x: T.x - f * 3, y: T.y - 34 - J.h, dir: f, s: k != 0 ? 1.25 : 1)) }
            }
            let hit = opts.onCue
            opts.onCue = { c in kickFx(0); hit?(c) }
            let extra: (Double, Bool, Bool) -> Void = { [unowned self] k, last, pop in
                kickFx(k)
                guard !T.dead, T.jug != nil else { return }
                let dx = (T.x - H.x) * f; if dx < -10 || dx > 36 { return }
                self.curSrc = b.uid; var o = HitOpts(); o.react = pop ? "launch" : "head"
                self.damage(H, T, max(1, jsRound(st.dmg * k * self.comboMul(b))), o); self.curSrc = nil
                if pop, let J = T.jug, !T.dead { J.vy = max(J.vy, 200) }   // 마지막 발: 줄어들지 않는 높이로 띄운다
                if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
                if last { self.comicSFX(T.x, T.y - 62 - (T.jug?.h ?? 0), "팍팍팍!", force: true) }
            }
            opts.cues = ["cy_jump": { [unowned self] _ in self.fx("dust", H.x, H.y, H.f); let dd = max(0, abs(T.x - H.x) - 16); if dd > 0 { H.dash = f * dd / 0.14; H.dashT = 0.14 } },
                         "cy_k2": { _ in extra(0.9, false, false) }, "cy_k3": { _ in extra(1.15, true, true) },
                         "cy_land": { [unowned self] _ in H.dash = 0; H.dashT = 0; self.fx("dust", H.x, H.y, -H.f) }]
        }
        if anim == "axe" || anim == "axe_air" {   // 도끼 차기: 수직 궤적 → 콰직
            let hit = opts.onCue, air = anim == "axe_air"
            let arcFx: (String) -> (Actor) -> Void = { pose in { [unowned self] c in   // 웹 arcFx: 단두대처럼 수직으로 떨어지는 칼날
                self.emit(.actionCue(actor: c.id, anim: aname, cue: pose))
                let ay = self.data.animTables.poses[live: H.pose]?.air ?? 0
                self.fxD(FxDetail(kind: "axv", x: T.x - f * 4, y: H.y - 96 - ay, dir: f, y1: T.y - 26 - (T.jug?.h ?? 0)))
            } }
            opts.cues = air
                ? ["axa_up": { [unowned self] _ in self.fx("dust", H.x, H.y, H.f); let dd = max(0, abs(T.x - H.x) - 14); if dd > 0 { H.dash = f * dd / 0.12; H.dashT = 0.12 } },
                   "axa_smear": arcFx("axa_smear"),
                   "cy_land": { [unowned self] _ in H.dash = 0; H.dashT = 0; self.fx("dust", H.x, H.y, -H.f) }]
                : ["ax_up": visCue("ax_up"), "ax_smear": arcFx("ax_smear")]
            opts.onCue = { [unowned self] c in
                hit?(c); let tx = T.x
                if !air { self.groundImpact(tx, H.y, 1.8) }
                self.fx("axring", tx, H.y); self.shake(3); self.comicSFX(tx, H.y - 74 - (T.jug?.h ?? 0), "콰직!", force: true); self.slowT = max(self.slowT, 0.1)
            }
        }
        if anim == "suplex" {   // 저먼 수플렉스: 허리 잡기 → 젖혀 → 뒤쪽 바닥에
            let st = sStats(i)
            opts.onCue = { [unowned self] _ in
                if !T.dead && !self.isDown(T) && abs(T.x - H.x) <= 26 {
                    T.jug = nil; T.heldBy = H; T.heldT0 = self.time; T.action = nil; T.queue = []; self.setAnim(T, "held")
                    H.kb = 0; H.dash = 0; H.dashT = 0; self.comicSFX(T.x, T.y - 72, "꽉!", force: true)
                }
            }
            opts.cues = ["sx_lift": visCue("sx_lift"),
                         "sx_slam": { [unowned self] _ in
                guard T.heldBy != nil else { return }
                T.heldBy = nil; T.airOv = 0; T.nvHold = nil
                let wall = self.nv ? self.nvWallFor(H, back: true, d: 24) : nil   // 네이티브 벽꿍: 뒤가 벽이면 벽면에 꽂힌다(World+NativeGrab)
                if self.nv { T.x = self.nvThrowLandX(H, back: true, d: 24); T.flip = !H.flip; if let wall { self.nvWallPlace(T, wall) } }   // 네이티브: 호 끝과 같은 자리 · 벽 안 · 뒤집지 않는다(머리가 주인공 쪽 — 일어나며 돌아선다)
                else { T.x = clamp(H.x - f * 24, 14, self.data.sbW - 14); T.flip = H.flip }
                self.stats.throws_ += 1; self.curSrc = b.uid; self.contribTrig(b.uid)
                var o = HitOpts(); o.knock = true; o.crit = true
                self.damage(H, T, jsRound(st.dmg * self.comboMul(b) * (wall != nil ? 1.2 : 1)), o)
                if let wall { self.nvWallHit(T, wall); self.slowT = max(self.slowT, 0.12) }
                else { self.groundImpact(T.x, T.y, 2.0); self.shake(3.6); self.slowT = max(self.slowT, 0.18); self.comicSFX(T.x, T.y - 66, "쿠웅!", force: true); self.fx("sxboom", T.x, T.y - 8) }
                if let bi = self.bag.firstIndex(where: { $0 === b }) { self.linkFire(bi, "hit"); self.linkFire(bi, "knock") }
                if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
                for o2 in self.foes() where o2 !== T && !self.isDown(o2) && !o2.dead && abs(o2.x - T.x) < 26 { var so = HitOpts(); so.knock = true; so.splash = true; self.damage(H, o2, jsRound(st.dmg * 0.35), so) }
                if self.nv { self.nvThrowRecover(H, wall: wall != nil) }   // 네이티브: 꽂은 뒤 주인공 경직만 줄인다(휘말린 적 타격으로 다시 늘어난 것까지)
                self.curSrc = nil }]
        }
        if anim == "renkan" {   // 연환퇴: 1타 살짝 띄움 · 2타 높이 띄움
            let st = sStats(i)
            opts.cues = ["rk_crouch": { _ in let dd = max(0, abs(T.x - H.x) - 17); if dd > 0 { H.dash = f * dd / 0.09; H.dashT = 0.09 } },
                         "rk_k1": { [unowned self] _ in self.fx("dust", H.x, H.y, -H.f) },
                         "rk_k2": { [unowned self] _ in
                guard !T.dead else { return }
                let dx = (T.x - H.x) * f; if dx < -10 || dx > 36 || (T.jug != nil && T.jug!.h > 70) { return }
                self.curSrc = b.uid; var o = HitOpts(); o.react = "launch"
                self.damage(H, T, max(1, jsRound(st.dmg * 1.3 * self.comboMul(b))), o); self.curSrc = nil
                if let J = T.jug, !T.dead { J.vy = max(J.vy, 230); J.vx = f * 18; J.pts = min(J.pts, 2); J.n = min(J.n, 1) }
                if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
                self.slowT = max(self.slowT, 0.06) },
                         "rk_land": { [unowned self] _ in H.dash = 0; H.dashT = 0; self.fx("dust", H.x, H.y, H.f) }]
        }
        if anim == "tetsu" {   // 철산고: 반 보 물러섬 → 파고듦 → 진각
            let hit = opts.onCue
            opts.cues = ["ts_set": { _ in H.dash = -f * 4 / 0.1; H.dashT = 0.1 },
                         "ts_step": { [unowned self] _ in self.fx("dust", H.x, H.y, -H.f); let dd = max(0, abs(T.x - H.x) - 17); if dd > 0 { H.dash = f * dd / 0.06; H.dashT = 0.06 } }]
            opts.onCue = { [unowned self] c in
                H.dash = 0; H.dashT = 0; hit?(c)
                let fxX = H.x + f * 12
                self.groundImpact(fxX, H.y, 1.6); self.fx("tsring", fxX, H.y)
                var k = CameraKick(); k.invertFrames = 2; k.shake = 3.8; self.emit(.camera(k)); self.sfx("tetsu")
                self.slowT = max(self.slowT, 0.16); self.comicSFX(T.x - f * 6, H.y - 74, "쾅!", force: true)
            }
        }
        if anim == "throw" {   // 잡기 → 들기 → 내리꽂기
            let st = sStats(i), airT = T.jug != nil
            opts.onCue = { [unowned self] _ in
                if !T.dead && !self.isDown(T) && abs(T.x - H.x) <= 28 {
                    if let J = T.jug { if self.nv { T.airOv = max(T.airOv, J.h) }; T.jug = nil; H.airOv = 9 }   // 네이티브: 떠 있던 높이에서 끌어내린다(World+NativeGrab)
                    T.heldBy = H; T.heldT0 = self.time; T.action = nil; T.queue = []; self.setAnim(T, "held"); H.kb = 0; H.dash = 0; H.dashT = 0
                }
            }
            opts.cues = ["gr_throw": { [unowned self] _ in
                guard T.heldBy != nil else { return }
                T.heldBy = nil; T.airOv = 0; T.nvHold = nil; T.x = self.nv ? self.nvThrowLandX(H, back: false, d: 30) : clamp(H.x + f * 30, 14, self.data.sbW - 14)
                let wall = self.nv ? self.nvWallFor(H, back: false, d: 30) : nil   // 네이티브 벽꿍: 앞이 벽이면 벽면에 꽂힌다(World+NativeGrab)
                if let wall { self.nvWallPlace(T, wall) }
                H.airOv = 0; self.stats.throws_ += 1; self.curSrc = b.uid; self.contribTrig(b.uid)
                var o = HitOpts(); o.knock = true; o.crit = true
                self.damage(H, T, jsRound(st.dmg * (airT ? 1.2 : 1) * (wall != nil ? 1.2 : 1)), o)
                if let wall { self.nvWallHit(T, wall) } else { self.groundImpact(T.x, T.y, airT ? 1.8 : 1.4); self.shake(3); self.fx("dust", T.x, T.y, T.f) }
                if let bi = self.bag.firstIndex(where: { $0 === b }) { self.linkFire(bi, "hit"); self.linkFire(bi, "knock") }
                for o2 in self.foes() where o2 !== T && !self.isDown(o2) && !o2.dead && abs(o2.x - T.x) < 24 { var so = HitOpts(); so.knock = true; so.splash = true; self.damage(H, o2, jsRound(st.dmg * 0.35), so) }
                if self.nv { self.nvThrowRecover(H, wall: wall != nil) }   // 네이티브: 꽂은 뒤 주인공 경직만 줄인다
                self.curSrc = nil }]
        }
        if nv && anim == "upper" && opts.cues.isEmpty {   // 깃발 켜짐 어퍼컷 = 옛 스매시 포즈: 가라앉을 때 먼지 · 퍼 올리는 궤적
            opts.cues = ["sm_dip": { [unowned self] _ in self.fx("dust", H.x, H.y, H.f) }, "sm_smear": visCue("sm_smear")]
        }
        if nv && anim.hasPrefix("nv_") {   // 네이티브 복싱 기술: 휘두름 궤적 · 타격 순간 연출(판정은 기본 경로 heroSkill)
            let hit = opts.onCue
            switch anim {
            case "nv_flick": opts.cues = ["fl_smear": visCue("fl_smear")]
            case "nv_liver":
                opts.cues = ["lv_load": { [unowned self] _ in self.fx("dust", H.x, H.y, -H.f) }, "lv_smear": visCue("lv_smear")]
                opts.onCue = { [unowned self] c in
                    hit?(c)
                    if !T.dead && T.anim == "crumple" { self.comicSFX(T.x, T.y - 78, "욱…!", force: true) }
                }
            case "nv_cork":
                opts.cues = ["ck_pull": visCue("ck_pull"), "ck_smear": visCue("ck_smear")]
                opts.onCue = { [unowned self] c in
                    hit?(c)
                    self.fxD(FxDetail(kind: "nv_cork", x: H.x + f * 22, y: H.y - 40, dir: f))
                    if !T.dead || T.anim == "rBlast" { var k = CameraKick(); k.invertFrames = 1; k.shake = 2.4; self.emit(.camera(k)) }
                }
            case "nv_roll": opts.cues = ["sr_roll": visCue("sr_roll"), "sr_smear": visCue("sr_smear")]
            case "nv_rise": nvRiseOpts(opts, H, T, b, i, visCue)   // 퇴근 승천권(World+NativeRise)
            case "nv_kneelift": nvKneeliftOpts(opts, H, T, b, visCue)   // 무릎 올려치기(World+NativeVF)
            case "nv_duckup": nvDuckupOpts(opts, H, T, b, i, visCue)    // 파고들어 올려치기(World+NativeVF)
            case "nv_beam": nvBeamOpts(opts, H, T, b, i, visCue)        // 야근 광선(World+NativeBeam)
            case "nv_slam": nvSlamOpts(opts, H, T, b, visCue)           // 서류가방 내려찍기(World+NativeOffice)
            case "nv_stamp": nvStampOpts(opts, H, T, b, visCue)         // 결재 쌍장(World+NativeOffice)
            case "nv_headbutt": nvHeadbuttOpts(opts, H, T, b, i, visCue)   // 멱살 박치기(World+NativeOffice)
            case "nv_dial": nvDialOpts(opts, H, T, b, visCue)            // 내선 연결(World+NativeDial)
            case "nv_punt": nvPuntOpts(opts, H, T, b, visCue)            // 구두 슛(World+NativePunt)
            default: break
            }
            if let F = data.atkFeel[anim], F.hs < 1 {   // 가벼운 기술(플리커 · 숄더 롤): 주인공 경직도 손맛 배율만큼 줄인다(damage 는 att.hs = max(기본, 대상) 이라 1 아래 배율이 주인공에 안 먹는다)
                let hit2 = opts.onCue
                opts.onCue = { c in hit2?(c); if H.hs > 0 { H.hs = max(1, jsRoundI(Double(H.hs) * F.hs)); H.hs0 = H.hs } }
            }
        }
        if nvG && T.e != nil { nvNoteSwitch(T, anim) }
        emit(.skillUsed(actor: H.id, anim: anim, itemUID: b.uid))
        requestAction(H, anim, opts)
    }

    // MARK: 쉬기

    /// 웹 restWanted: 다 잡고 도착까지 6초 넘게 남으면 앉거나 기댄다
    func restWanted() -> Bool {
        guard ci < line.count, state == "fight", let ct = clearT, !arriving, !prologue, !bonus, !cine else { return false }
        let L = line[ci], left = legDur(L) - legT
        return left > 6 && legT - ct > 1.2
    }
    func restTick(_ H: Actor, _ dt: Double) {
        if H.rest == nil {
            let pass = ents.filter { $0.pass && !$0.hidden }
            let free = stableSortD([70.0, 190, 290, 410].filter { x in !inDoor(x) && !pass.contains { abs($0.x - x) < 18 } }) { abs($0 - H.x) - abs($1 - H.x) }
            if let x = free.first { H.rest = RestState(mode: "sit", x: x) }
            else {
                let d = data.doors.reduce(9999.0) { b, dd in abs((dd.0 + dd.1) / 2 - H.x) < abs(b - H.x) ? (dd.0 + dd.1) / 2 : b }
                let dd = data.doors.first { ($0.0 + $0.1) / 2 == d }!
                H.rest = RestState(mode: "lean", x: H.x < d ? dd.0 - 6 : dd.1 + 6, door: d)
            }
        }
        H.rest!.t += dt
        if !H.rest!.on {
            let rx = H.rest!.x
            if abs(H.x - rx) > 2 { face(H, rx); moveTo(H, rx, heroSpd() * 0.5, dt); return }
            H.rest!.on = true; H.rest!.t = 0
            if H.rest!.mode == "sit" { H.z = -2; face(H, data.sbW / 2); setAnim(H, "rest_sit") }
            else { face(H, (H.rest!.door ?? 0) < H.x ? H.x + 10 : H.x - 10); setAnim(H, "rest_lean") }
        }
        if H.rest!.on && !H.rest!.said && H.rest!.t > 1.4 { H.rest!.said = true; comicSay(H, "quip:rest", "think") }
    }
    func restEnd(_ H: Actor) { if H.anim == "rest_sit" || H.anim == "rest_lean" { setAnim(H, "idle") }; H.z = 3; H.rest = nil }

    // MARK: 주인공 AI

    /// 웹 heroAI(dt): 자동 전투
    func heroAI(_ dt: Double) {
        if nv, let H0 = hero, padTick(H0, dt) { return }   // 네이티브 패드가 조종 중이면 자동 AI 는 쉰다(World+NativePad)
        guard let H = hero, !demo, !kane, !H.anim.hasPrefix("gx_") else { return }
        if H.dead { return }
        if let B = bn, B.phase != "go" { return }
        if holding(H) { return }
        let F = foes().filter { $0.anim != "death" }
        if F.isEmpty && state == "corridor" { if canAct(H) || H.anim == "walk" { face(H, H.x + 10); moveTo(H, H.x + 30, heroSpd() * 0.85, dt) }; return }   // 복도: 앞으로 밀고 나간다
        if !F.isEmpty && H.rest != nil { restEnd(H) }
        if F.isEmpty && restWanted() { restTick(H, dt); return }
        if F.isEmpty && H.rest != nil { restEnd(H) }
        if F.isEmpty {
            if canAct(H) && (arriving || clearT != nil || state == "arrive") {   // 내릴 문 앞으로
                let dx = (data.doors[1].0 + data.doors[1].1) / 2 - 14
                if abs(H.x - dx) > 2 { face(H, dx); moveTo(H, dx, heroSpd() * 0.6, dt) } else if H.anim == "walk" { setAnim(H, "idle") }
            }
            return
        }
        func dist(_ a: Actor) -> Double { abs(a.x - H.x) }
        let Fa = F.filter { !$0.held }, live = Fa.filter { !isDown($0) }
        var T: Actor? = stableSortD(live.isEmpty ? Fa : live) { dist($0) - dist($1) }.first
        if nvG, let t0 = T, nvGuardOf(t0) > 0,   // 네이티브: 가드를 올린 대기 적보다 조금 먼(20px 안) 무방비 적을 먼저 — 막기만 두들기지 않게
           let t1 = stableSortD(live.filter { $0 !== t0 && nvGuardOf($0) == 0 && dist($0) < dist(t0) + 20 }, { dist($0) - dist($1) }).first { T = t1 }
        if let bb = bossBreak, !bb.a.dead, dist(bb.a) < 170 { T = bb.a }   // 무너진 두목을 노린다
        let front = stableSortD(live.filter { !behindOf(H, $0) }) { dist($0) - dist($1) }.first
        let rear = stableSortD(live.filter { behindOf(H, $0) }) { dist($0) - dist($1) }.first
        if let fr = front, let re = rear, dist(fr) < 52, dist(re) < 44, bag.contains(where: { item($0.id)?.back == true }) { T = fr }   // 앞을 본 채로 버틴다
        if !bonus && !live.contains(where: { $0.jug != nil }) && envMove(H, live) { spcGain(5); return }   // 기둥 · 손잡이 · 짐 상자
        if T != nil && !canAct(H), let A = H.action, A.fired, !H.dead, !data.falls.contains(H.anim), !heroAirborne(H), !(nv && H.anim == "nv_rise"),   // 네이티브 승천권: 착지 빈틈은 끊지 않는다
           live.contains(where: { $0.jug != nil && $0.jug!.h < 66 && dist($0) < 44 }) || (croute != nil && croute!.k < croute!.uids.count && croute!.T != nil && !croute!.T!.dead && dist(croute!.T!) < 56) {
            let C = croute
            let nx = (C != nil && C!.k < C!.uids.count) ? (bag.firstIndex { $0.uid == C!.uids[C!.k] } ?? -1) : -1
            let ji = nx >= 0 ? nx : (bag.indices.first { k in let q = item(bag[k].id); return q?.kind == "skill" && q?.cond == nil && (q?.fam == "fist" || q?.combo == true) && bag[k].t >= cdOf(k) && !soloSkip(bag[k]) } ?? -1)
            if ji >= 0 { H.action = nil; H.queue = []; setAnim(H, "idle") }   // 착지 · 공중 콤보 캔슬
        }
        if let T, !canAct(H), !H.dead, !data.falls.contains(H.anim), H.anim != "getup", H.anim != "duck", !heroAirborne(H), !(nv && H.anim == "nv_rise") {   // 반격 끊어 쓰기(네이티브 승천권 착지 빈틈은 빼고)
            let recov = H.action.map { $0.fired } ?? (time - (hurtAt ?? -9) > 0.15)
            let cix = recov ? (bag.indices.first { k in item(bag[k].id)?.cond == "counter" && bag[k].t >= cdOf(k) && !soloSkip(bag[k]) } ?? -1) : -1
            if cix >= 0 && condOK("counter", H, T, Fa) && dist(T) <= (item(bag[cix].id)?.reach ?? 0) + 4 {
                H.action = nil; H.queue = []; setAnim(H, "idle"); face(H, T.x); useSkill(cix, T, false); return
            }
        }
        if nvG, T != nil, nvHeroGuard(H, live) { return }   // 네이티브 공방: 앞에서 공격 예고 → 가드(World+NativeGuard)
        guard var T, canAct(H) else { return }
        if nvG && nvc.repick { nvc.repick = false; H.pick = nil }   // 막혔다 → 높이를 바꿔 다시 고른다
        // 조건 기술이 성립하면 바로 끼어든다. 아니면 고른 기본기를 쓸 때까지 유지
        var situ: [Int] = []
        for (k, b) in bag.enumerated() { if let q = item(b.id), q.kind == "skill", q.cond != nil, b.t >= cdOf(k), condOK(q.cond, H, T, Fa), !soloSkip(b) { situ.append(k) } }
        var i = H.pick ?? -1
        let pickValid = H.pick != nil && i >= 0 && i < bag.count
        if !situ.isEmpty && !(pickValid && item(bag[i].id)?.cond != nil && situ.contains(i)) { i = situ[rndInt(situ.count)]; H.pick = i }
        else if !pickValid || bag[i].t < cdOf(i) || (!routeSets().S.contains(bag[i].uid) && !condOK(item(bag[i].id)?.cond, H, T, Fa)) || soloSkip(bag[i]) { i = pickSkill(H, T, Fa); H.pick = i }
        if croute == nil && comboCD <= 0 {   // 콤보 우선: 숨 고르기가 끝나면 시작기부터
            let S = routeSets().S
            if let si = bag.indices.first(where: { S.contains(bag[$0].uid) && bag[$0].t >= cdOf($0) }) { i = si; H.pick = si }
        }
        if croute != nil { let cix = comboPick(H, T); if cix >= 0 { i = cix; H.pick = cix; if let C = croute, let ct = C.T, !ct.dead { T = ct } } }
        if i < 0 { face(H, T.x); approach(H, T.x + (T.x >= H.x ? -1 : 1) * 24, heroSpd(), dt, heroSpd() * 3.4); return }
        if croute == nil && !tower, let J = T.jug, J.h >= 22 && J.h < 64 && dist(T) < 38 && time - (hangT2 ?? -9) > 2 && time - (linkAt["air"] ?? -9) < 2.5 && canAct(H) {
            if nvSnow?.held != true, let sx = data.strapX.first(where: { abs($0 - H.x) < 26 }) { strapAir(H, T, sx); return }   // 눈 승강장엔 손잡이가 없다   // 손잡이 공중전
        }
        let tc: Actor? = croute == nil && time - (linkAt["scoop"] ?? -9) < 1.6
            ? Fa.first { a in ((a.jug != nil && a.jug!.trip && a.jug!.h < 26) || (data.falls.contains(a.anim) && time - ((a.tripLandT ?? 0) != 0 ? a.tripLandT! : -9) < 0.45)) && dist(a) < 40 } : nil
        if let tc {   // 걸고 퍼올리기
            if let si = bag.indices.first(where: { (bag[$0].id == "upper" || bag[$0].id == "punch") && bag[$0].t >= cdOf($0) && !soloSkip(bag[$0]) }) {
                let b = bag[si]; if b.id == "punch" { b.combo = 2; b.last = time }; H.scoopNext = true; i = si; H.pick = si; T = tc
            }
        } else if croute == nil, let J = T.jug, !J.trip, J.n >= 2, J.h >= 4, J.h < 42, time - (linkAt["airgrab"] ?? -9) < 3 {   // 공중 잡아 꽂기
            if let ti = bag.indices.first(where: { bag[$0].id == "throw" && bag[$0].t >= cdOf($0) && !soloSkip(bag[$0]) }) { i = ti; H.pick = ti }
        } else if croute == nil, let J = T.jug, J.h < 66 {   // 공중 콤보: 빠른 주먹으로 이어 친다
            if let ji = bag.indices.first(where: { k in let q = item(bag[k].id); return q?.kind == "skill" && q?.cond == nil && (q?.fam == "fist" || q?.combo == true) && bag[k].t >= cdOf(k) && !soloSkip(bag[k]) }) { i = ji; H.pick = ji }
        }
        guard bag.indices.contains(i), let it = item(bag[i].id) else { return }
        let tgt: Actor
        if it.cond == "down" {
            tgt = stableSortD(Fa.filter { a in isFalling(a) || (a.jug != nil && !a.jug!.gb && a.jug!.h < 36 && bagHasLink("gbounce")) }) { dist($0) - dist($1) }.first ?? T
        } else if it.back == true { tgt = rear ?? T } else { tgt = T }
        let d = dist(tgt), reach = (it.combo == true ? 24 : it.cond == "grab" ? 28 : (it.reach ?? 0)) + (tgt.jug != nil ? 8 : 0)
        if it.back == true {   // 뒤 공격: 돌아서지 않고 그 자리에서
            if rear != nil, d <= reach + 4 { if H.anim == "walk" { setAnim(H, "idle") }; useSkill(i, tgt, false) }
            else if let rear, d <= 60 { H.x += jsSign(rear.x - H.x) * heroSpd() * 0.7 * dt; if H.anim != "walk" { setAnim(H, "walk") } }
            else { H.pick = nil }
            return
        }
        face(H, tgt.x)
        if it.cond == "gap" || (d <= reach + 2 && d >= 8) || (nv && it.cond == "nv_aa" && d <= 70) { if H.anim == "walk" { setAnim(H, "idle") }; useSkill(i, tgt, false); return }   // 네이티브 대공(승천권): 뛰어드는 적은 그 자리에서
        let sj = heroSpd() * (tgt.jug != nil ? (tgt.jug!.wallB && time - (poleT ?? -9) < 1.4 ? 2.2 : 1.6) : 1)
        let chase = tgt.e != nil && (tgt.e!.retreatT > 0 || abs(tgt.kb) > 30 || tgt.jug != nil)
        approach(H, tgt.x + (tgt.x >= H.x ? -1 : 1) * max(data.sepHF, reach - 4), sj, dt, max(sj * 1.2, heroSpd() * 3.4), chase)   // 떠 있는 적은 빠르게 쫓는다
    }

    // MARK: 적 AI

    /// 웹 foeAI(a, dt)
    func foeAI(_ a: Actor, _ dt: Double) {
        guard !demo, !a.kane, let H = hero, let e = a.e else { return }
        if a.carDummy || a.carOwner || e.tw.towerBusy { return }   // 보너스 허수아비 · 차 주인 · 타워 특수 행동 중
        if a.held { return }
        e.cdT += dt
        if a.anim == "stagger" && !(e.stun > 0) { setAnim(a, "idle") }
        if e.stun > 0 {   // 경직 동안은 휘청거린다
            e.stun -= dt
            if e.stun > 0.2 && canAct(a) && a.jug == nil { setAnim(a, "stagger"); stats.stag += 1 }
            return
        }
        if !canAct(a) || H.dead { return }
        if e.retreatT > 0 {   // 치고 빠지기
            e.retreatT -= dt; let away: Double = a.x >= H.x ? 1 : -1; face(a, H.x)
            moveTo(a, max(AW0() + 2, min(AW1() - 2, H.x + away * 80)), e.spd * 1.2, dt); return
        }
        let side: Double = a.x >= H.x ? 1 : -1, dist = abs(a.x - H.x); face(a, H.x)
        if let range = e.def.range, range != 0 {   // 병 던지는 놈: 거리를 두고 던진다
            let atWall = a.x <= 20 || a.x >= data.sbW - 20
            if dist < range - 20 && !atWall { moveTo(a, max(14, min(data.sbW - 14, H.x + side * range)), e.spd, dt) }
            else if e.cdT >= e.cd {
                e.cdT = 0
                if dist <= (data.moveReach["jab"] ?? 24) {
                    a.lastMove = "jab"; requestAction(a, "jab", ActionReq(cue: cueFor(a, "jab", "m_jab")) { [unowned self] c in self.foeHit(c) })
                } else {
                    a.lastMove = "throw"
                    let kind = nv && NativeContent.paperThrowers.contains(e.t) ? "news" : ""   // 네이티브: 신문팔이 소년은 신문 뭉치
                    requestAction(a, "jab", ActionReq(cue: cueFor(a, "jab", "m_jab")) { [unowned self] c in self.shots.append(Shot(x: c.x - side * 8, y: c.y - 52, vx: -side * 150, kind: kind)); self.sfx("throw") })
                }
            } else if a.anim == "walk" { setAnim(a, "idle") }
            return
        }
        if nvG && nvCrowdFoe(a) { nvMelee(a, e, H, dt); return }   // 네이티브 공방: 공격권 · 대기 자리 · 가드(World+NativeCrowd)
        let close = foes().filter { abs($0.x - H.x) < 36 && $0 !== a }.count
        let wait = close >= 2 && dist > 34
        let spd = (e.dash ?? 0) != 0 && dist > 60 ? e.dash! : e.spd
        let rs = e.boss ? e.spd * 2 : max(e.dash ?? 0, min(120, max(90, e.spd * 2.6)))   // 멀어지면 달려서 다시 붙는다
        if e.next == nil {   // 같은 공격을 연달아 잘 안 쓴다
            let ms = e.moves; var m = ms[rndInt(ms.count)]
            if ms.count > 1 && m == a.lastMove && rnd() < 0.75 { let alt = ms.filter { $0 != a.lastMove }; m = alt[rndInt(alt.count)] }
            e.next = m
        }
        if e.next == "fkick" && dist < 50 { let alt = e.moves.filter { $0 != "fkick" }; let r = rndInt(alt.count); e.next = alt.indices.contains(r) ? alt[r] : "jab" }
        let gapMv = e.next == "fkick", inGap = dist >= 50 && dist <= 110
        let rch = wpnReach(e.next, e.wpn)
        if e.flankAt != 0 && time >= e.flankAt {   // 협공: 반대편 동료와 거의 동시에
            e.flankAt = 0
            if !gapMv && dist <= rch + 4 { e.cdT = 0; let mv = e.next!; e.next = nil; e.fl = true; foeStrike(a, mv); return }
        }
        let inR = !gapMv && !wait && dist <= rch && dist >= data.sepHF - 1
        if inR && a.anim == "walk" { setAnim(a, "idle") }
        let there = gapMv ? (dist <= 110 || approach(a, H.x + side * 90, spd, dt, rs)) : inR ? true : approach(a, H.x + side * (wait ? 64 : max(data.sepHF, rch - 3)), spd, dt, rs)
        if gapMv && inGap && a.anim == "walk" { setAnim(a, "idle") }
        if !wait && (gapMv ? inGap : ((there || dist <= rch) && dist <= rch + 4)) && e.cdT >= e.cd { e.cdT = 0; let mv = e.next!; e.next = nil; foeStrike(a, mv) }
    }

    /// 웹 foeStrike(a, mv)
    func foeStrike(_ a: Actor, _ mv: String, extraTell: Double = 0) {
        guard let H = hero, let e = a.e else { return }
        let dist = abs(a.x - H.x), rch = wpnReach(mv, e.wpn)
        a.lastMove = mv; a.windup = time; e.flankHit = e.fl; e.fl = false
        if !e.flankHit { flankCall(a) }
        if data.foeW[mv] == "H" { hint("heavy"); if manualT <= 0 && duckReady() && dist <= rch + 8 { heroDuck() } }
        let an = mv == "jab" && e.wpn == "w_umb" ? "uthrust" : mv == "jab" && e.wpn == "w_paper" ? "swat" : mv   // 무기를 든 손으로 치는 전용 동작
        var tx = (demo || time < (engageT ?? -9)) ? (data.foeTellX[data.foeW[mv] ?? ""] ?? 0) : 0
        if extraTell != 0 { tx += extraTell }   // 네이티브 끼어들기: 긴 예고(탭 받아치기 기회)
        e.cdT += tx   // 직접 누르기 시작하면(8초) 예고를 길게 — 자동 전투 템포는 그대로
        face(a, H.x)
        let fb: [String: String] = ["jab": "m_jab", "hook": "hook", "hbutt": "hb", "kick": "m_kick", "bat": "batS", "round": "rh", "upper": "up"]
        let fo = ActionReq(cue: cueFor(a, an, fb[an]), wpn: e.wpn, tell: tx) { [unowned self] c in self.foeHit(c) }
        if mv == "fkick" {
            fo.cues = ["fk_smear": { [unowned self] c in self.emit(.actionCue(actor: c.id, anim: "fkick", cue: "fk_smear")) },
                       "fk_jump": { _ in let dd = max(0, abs(H.x - a.x) - 18); a.dash = (H.x > a.x ? 1 : -1) * dd / 0.3; a.dashT = 0.3 },
                       "fk_tuck": { [unowned self] _ in if self.manualT <= 0 && self.duckReady() { self.heroDuck() } },
                       "fk_land": { [unowned self] _ in a.dash = 0; a.dashT = 0; self.fx("dust", a.x, a.y, a.f) }]
        }
        if mv == "charge" { fo.cues = ["ch_run": { _ in let dd = abs(H.x - a.x) - 16; a.dash = (H.x > a.x ? 1 : -1) * 260; a.dashT = max(0.05, min(0.3, dd / 260)) }] }   // 배치기 돌진
        if data.foeW[an] != nil { emit(.actionCue(actor: a.id, anim: an, cue: "tell")) }
        requestAction(a, an, fo)
    }

    /// 웹 flankCall(a): 가끔(3.5초에 한 번 이하 · 60%) 반대편 적이 0.14초 늦게 같이 친다
    func flankCall(_ a: Actor) {
        guard let H = hero else { return }
        if demo || state != "fight" || time - (flankT ?? -9) < 3.5 || rnd() > 0.6 { return }
        let sd = jsSign(a.x - H.x) != 0 ? jsSign(a.x - H.x) : 1
        guard let b = foes().first(where: { o in o !== a && !o.held && o.jug == nil && (o.e?.def.range ?? 0) == 0 && canAct(o) && !(o.e!.stun > 0) && !(o.e!.retreatT > 0) && jsSign(o.x - H.x) == -sd && abs(o.x - H.x) <= 40 && (!nvG || o.nvg.tok) }) else { return }
        flankT = time; b.e!.flankAt = time + 0.14; b.e!.cdT = min(b.e!.cdT, b.e!.cd - 0.5); stats.flanks += 1
        emit(.flankWarn(attacker: b.id))
    }

    // MARK: 쭈그리기 · 직접 조작

    func isDucking(_ H: Actor) -> Bool { H.anim == "duck" && H.pose != "c_over" }
    func duckSlot() -> Int { bag.firstIndex { $0.id == "duck" } ?? -1 }
    func duckReady() -> Bool { let i = duckSlot(); return i >= 0 && bag[i].t >= cdOf(i) }
    /// 웹 heroDuck(manualIn)
    @discardableResult
    func heroDuck(_ manualIn: Bool = false) -> Bool {
        guard let H = hero else { return false }
        if manualIn { engageT = time + 8 }
        if H.dead || H.anim == "duck" || data.reacts.contains(H.anim) || holding(H) { return false }
        let i = duckSlot()
        if i < 0 {
            if nv && manualIn { return padDuckBare(H) }   // 네이티브: 숙이기는 기본 장착(보상 · 자동 숙이기는 아이템이 있을 때만)
            if manualIn { say("", "서류가방에 쭈그리기가 있어야 숙일 수 있어요", 1.4) }; return false
        }
        if bag[i].t < cdOf(i) { if manualIn { flashText("WAIT", 0.4) }; return false }
        bag[i].t = 0; if manualIn { manualT = 2.5 }
        H.queue = []; H.action = nil; setAnim(H, "idle"); requestAction(H, "duck", ActionReq(cue: "dk1") { _ in })
        emit(.bagPulse(uid: bag[i].uid, kind: "fire")); cmdPush("피하기")
        return true
    }

    /// 웹 manual(side): 누른 쪽으로 즉시 공격 / 공격 준비 중인 적은 카운터 · 저스트 / 날아오는 병은 쳐냄 / 없으면 대시.
    /// lag = 터치 뒤 지난 게임 시간(저스트 판정은 터치 순간 기준)
    func manual(_ sideI: Int, lag: Double = 0) {
        guard on, state != "over", state != "shop", let H = hero, !H.dead else { return }
        let side = Double(sideI)
        manualT = 2.5; engageT = time + 8
        if holding(H) { return }
        let win = 0.42 * (1 + pv("ear", 0.6, 0.15))
        if let si = shots.firstIndex(where: { jsSign($0.x - H.x) == side && abs($0.x - H.x) < 40 }) {   // 날아오는 병은 쳐낸다
            shots[si].dead = true; fx("spark", shots[si].x, shots[si].y); score += 50; face(H, H.x + side); if canAct(H) { setAnim(H, "jab") }; return
        }
        if nvG && nvJustGuard(side, lag: lag) { return }   // 네이티브: 가드 중 · 막은 직후에 누르면 저스트 가드 → 받아치기
        var near = stableSortD(foes().filter { jsSign($0.x - H.x) == side && abs($0.x - H.x) < 46 && $0.anim != "death" }) { abs($0.x - H.x) - abs($1.x - H.x) }
        if let ai = near.firstIndex(where: { $0.action != nil && !$0.action!.fired && data.foeW[$0.anim] != nil }) { let A = near.remove(at: ai); near.insert(A, at: 0) }   // 치려고 준비하는 적을 먼저
        if let A = near.first {
            let tt0 = timeToCue(A), tt = tt0.map { $0 + lag }
            if let tt, tt <= justW(), data.foeW[A.anim] != "H", !data.falls.contains(H.anim), !data.reacts.contains(H.anim), A.e?.boss != true { justCounter(A); return }   // 저스트
            if let tt, tt > justW() { justEarly = time }
        }
        if let n0 = near.first, behindOf(H, n0), abs(n0.x - H.x) <= 34 {   // 등 뒤를 누르면 뒤 공격
            if let bi = bag.indices.first(where: { item(bag[$0].id)?.back == true && bag[$0].t >= cdOf($0) }) { H.queue = []; H.action = nil; setAnim(H, "idle"); useSkill(bi, n0, true); return }
        }
        let T = near.first
        if let T, let A = T.action, !A.fired, data.foeW[T.anim] == "H" { flashText("DUCK!", 0.6); if duckReady() && heroDuck(true) { return } }
        if let T, let A = T.action, !A.fired, data.foeW[T.anim] != "H", time - (T.windup ?? 0) < win + 0.35 {   // 카운터
            T.action = nil; T.queue = []; T.e?.stun = 1.2; T.e?.cdT = -0.6; stats.counters += 1; face(H, T.x); H.queue = []; H.action = nil; setAnim(H, "idle")
            requestAction(H, "cross", ActionReq(cue: cueFor(H, "cross", "m_cross")) { [unowned self] _ in
                if T.dead || !self.inFront(H, T, self.data.moveReach["cross"] ?? 28) { return }
                var o = HitOpts(); o.crit = true; o.counter = true; o.react = "body"
                self.damage(H, T, jsRound(14 * (1 + 0.12 * Double(self.ci))), o)
            })
            flashText("COUNTER", 0.8); emit(.counter(target: T.id)); return
        }
        if let T, abs(T.x - H.x) <= 32 {
            if !canAct(H) && H.anim != "walk" { H.queue = [] }
            let i = pickSkill(H, T, foes().filter { !$0.held })
            if i >= 0 && abs(T.x - H.x) <= (item(bag[i].id)?.reach ?? 0) + 4 { H.action = nil; setAnim(H, "idle"); useSkill(i, T, true); return }
            if mcd <= 0 {
                mcd = 0.32; face(H, T.x); H.action = nil; setAnim(H, "idle")
                requestAction(H, "jab", ActionReq(cue: cueFor(H, "jab", "m_jab")) { [unowned self] _ in
                    if self.inFront(H, T, self.data.moveReach["jab"] ?? 24) { var o = HitOpts(); o.react = "head"; self.damage(H, T, 4, o) }
                })
            }
            return
        }
        face(H, H.x + side); H.dash = side * 260; H.dashT = 0.14; if canAct(H) { setAnim(H, "walk") }
    }

    /// 웹 justCounter(T): 타격 직전 탭 — 공격을 끊고 파고들어 크로스(피해 ×2 · 무너뜨림)
    func justCounter(_ T: Actor) {
        guard let H = hero, let e = T.e else { return }
        let f: Double = T.x >= H.x ? 1 : -1, d = abs(T.x - H.x)
        H.airOv = 0; T.action = nil; T.queue = []; e.cdT = -1.4; T.hs = max(T.hs, 6); T.hs0 = T.hs; T.shkA = 1   // 적은 휘두르던 자세 그대로 굳는다
        stats.counters += 1; stats.justs += 1; face(H, T.x); H.queue = []; H.action = nil; setAnim(H, "idle")
        if d > 24 { H.dash = f * (d - 22) / 0.07; H.dashT = 0.07 }   // 순간 파고들기
        slowT = max(slowT, 0.3); flashText("JUST!", 0.9); spcGain(8); emit(.justCounter(target: T.id))
        comicSFX(T.x, T.y - 96, "저스트!", force: true); cmdPush("저스트 받아치기")
        requestAction(H, "cross", ActionReq(cue: cueFor(H, "cross", "m_cross")) { [unowned self] _ in
            if T.dead { return }
            if !self.inFront(H, T, (self.data.moveReach["cross"] ?? 28) + 10) { return }
            var o = HitOpts(); o.crit = true; o.counter = true; o.just = true; o.react = "body"
            self.damage(H, T, jsRound(22 * (1 + 0.12 * Double(self.ci)) * (1 + 0.15 * Double(self.stageIdx))), o)
            if let e2 = T.e, !T.dead { e2.stun = max(e2.stun, 1.2) }
        })
    }

    /// 웹 strapAir(H, T, sx): 손잡이 공중전(띄우고 차기 연계)
    func strapAir(_ H: Actor, _ T: Actor, _ sx: Double) {
        H.x = sx; face(H, T.x); setAnim(H, "idle"); cmdPush("손잡이 공중전", "env"); hangT2 = time; hangX = sx
        let opts = ActionReq()
        opts.cues = ["hk0": { _ in H.airOv = 6 },
                     "hk1": { [unowned self] _ in
            for a in self.foes() { let dx = (a.x - H.x) * H.f; if a.jug != nil && dx > -6 && dx < 46 { var o = HitOpts(); o.knock = true; self.damage(H, a, jsRound(22 * (1 + 0.08 * Double(self.ci))), o) } } },
                     "hk2": { _ in H.airOv = 0 }]
        requestAction(H, "hangkick", opts)
    }
}

extension World {
    /// 웹 skick cres(): 회전 중심 = (골반 + 목)/2 를 마지막으로 그린 관절(H.jw)로 월드에 — 그린 적이 없으면 (−4, −31) − 공중 높이
    func crescentPivot(_ H: Actor, _ f: Double) -> SIMD2<Double> {
        if let P = H.lastP {
            let (j, _) = solveJoints(P, rig: data.heroRig, input: JointInput(tilt: H.tilt, airOv: H.airOv, walkResidual: nil, weaponSprite: nil))
            return SIMD2(H.x + f * (j.hips.x + j.neck.x) / 2, H.y + (j.hips.y + j.neck.y) / 2)
        }
        let air = data.animTables.poses[live: "sk_kick"]?.air ?? 0
        return SIMD2(H.x + f * -4, H.y - 31 - air)
    }
}
