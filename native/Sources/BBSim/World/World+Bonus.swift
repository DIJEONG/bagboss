import Foundation
import BBCore

// 웹 40-bonus.js + 43-fx-smoke.js 규칙 부분: 보너스 스테이지 차 부수기(노선과 노선 사이 — 30초 안에 차 체력 460을 깎는다).
//   startBonus · carHit · carStage · carDetach(+carBones 의 뼈 자리) · carPts · bonusGrade · bonusUpdate(intro → go → owner) · finishBonus →
//   startTransfer, 그리고 30-train-env 의 갈고리(종점 → 아직 안 한 노선이면 startBonus) · 42-dojo jumpTo('bonus')(개발용 바로 가기).
// 피해 측정: 보이지 않는 허수아비(깡패 · 체력 1e7)를 주인공이 때리면 줄어든 체력만큼 차 피해(carHit).
// 연기 · 김 · 불길 입자 · 유리 · 쇳조각 · 경보음은 연출 — fx/sfx 이벤트로만 내고(위치 흔들림은 연출 난수 fxr) 규칙 수열은 쓰지 않는다.
// 차 그림 상태(파손 단계 · 떨어진 부품 · 기울기 · 흔들림 · 파편 위치)는 스냅숏 BonusView.car 로 넘긴다(뼈는 BonusCarRig.bones).

/// 웹 carBones(C) 의 결정적 부분 — 표현 쪽이 차를 그릴 때도 같은 함수를 쓴다(흔들림 sh 는 연출 난수라 바깥에서 준다)
public enum BonusCarRig {
    /// 웹 CAR_K · CAR_STAGES · CAR_HP · CAR_TIME
    public static let K = 1.3
    public static let stages: [Double] = [0.88, 0.76, 0.64, 0.52, 0.40, 0.28, 0.16, 0]
    public static let hp = 460.0, time = 30.0
    /// 웹 CAR_PTS: 부품 → [점수, 이름]
    public static let pts: [String: (Int, String)] = ["mirror": (500, "사이드미러"), "hubF": (500, "휠캡"), "bumperF": (1000, "앞범퍼"), "doorF": (1500, "앞문"), "doorR": (1500, "뒷문"),
                                                    "hood": (2000, "보닛"), "wheelF": (2000, "앞바퀴"), "trunk": (1500, "트렁크"), "bumperR": (1000, "뒷범퍼")]
    public struct Bone: Sendable, Equatable { public var x: Double, y: Double, z: Double, th: Double; public var sy: Double? }
    /// 웹 C.dentN = min(18, round(dmgF·24))
    public static func dentN(_ dmgF: Double) -> Int { min(18, jsRoundI(dmgF * 24)) }
    /// 웹 carBones(C): 부품별 자리(차 원점 기준 · CAR_K 배) — sh = 흔들림 x 오프셋((rand-.5)·2.4·shake)
    public static func bones(stage s: Int, dmgF f: Double, gone g: Set<String>, tilt: Double, sh: Double = 0) -> [String: Bone] {
        var B: [String: Bone] = [:]
        func put(_ k: String, _ x: Double, _ y: Double, _ z: Double, _ th: Double, _ sy: Double? = nil) { if !g.contains(k) { B[k] = Bone(x: x + sh, y: y, z: z, th: th, sy: sy) } }
        let sink = f * 2.2, crush = max(0, f - 0.45) * 1.6, cy = crush * 7, csy = max(0.42, 1 - crush)
        put("farW", 0, 0, 0, 0); put("body", 0, sink, 0, 0); put("detail", 0, sink, 0, 0)
        put("cabin", 0, sink + cy, 0, 0, csy); put("interior", 0, sink + cy, 0, 0, csy); put("pillar", 0, sink + cy, 0, 0, csy)
        if s < 5 { put("glassS", 0, sink + cy, 0, 0, csy) }
        if s < 8 { put(s >= 3 ? "glassX" : "glassF", 0, sink + cy, 0, 0, csy) }
        if s < 7 { put("glassB", 0, sink + cy, 0, 0, csy) }
        if s < 6 { put("wiper", 0, sink + cy * 0.3, 0, 0) }
        put("hood", 13, -13 + sink, 0, s >= 6 ? 0 : -(0.04 + f * 0.18)); put("trunk", -22, -13 + sink, 0, s >= 7 ? 0.5 : f * 0.1)
        put("bumperF", 40, -6 + sink, 0, -f * 0.25); put("bumperR", -40, -6 + sink, 0, s >= 8 ? 0.3 : 0)
        put("doorF", -2, sink, 15.6, 0); put("doorR", -20, sink, 15.6, 0); put("mirror", 15, -14.5 + sink, 15.4, 0)
        put("wheelF", 26, -5, 12, 0); put("hubF", 26, -5, 12, 0); put("wheelF2", 26, -5, 12, Double.pi / 4); put("wheelR", -26, -5, 12, 0); put("wheelR2", -26, -5, 12, Double.pi / 4)
        if s < 5 { put("lightF", 40.6, sink, 0, 0) }
        put("lightR", -40.6, sink, 0, 0)
        if dentN(f) > 0 { B["dents"] = Bone(x: sh, y: sink, z: 0, th: 0) }
        if tilt != 0 {
            let px = -26.0, py = 0.0, cs = cos(tilt), sn = sin(tilt)
            for k in Array(B.keys) { var b = B[k]!; let dx = b.x - px, dy = b.y - py; b.x = px + dx * cs - dy * sn; b.y = py + dx * sn + dy * cs; b.th += tilt; B[k] = b }
        }
        for k in Array(B.keys) { B[k]!.x *= K; B[k]!.y *= K; B[k]!.z *= K }
        return B
    }
    /// 웹 bonusGrade(BN): 다 부쉈으면 남은 초로 S(12+) · A(6+) · B, 못 부쉈으면 깎은 비율 60%+ C · D
    public static func grade(hp: Double, max: Double, t: Double, dur: Double, dealt: Double) -> BonusResult {
        var r = BonusResult()
        r.left = Swift.max(0, dur - t); r.done = hp <= 0; r.pct = 1 - hp / max
        r.grade = r.done ? (r.left >= 12 ? "S" : r.left >= 6 ? "A" : "B") : (r.pct >= 0.6 ? "C" : "D")
        let R: [String: (Int, Int)] = ["S": (5000, 4), "A": (3000, 3), "B": (2000, 2), "C": (1000, 1), "D": (300, 0)]
        r.points = R[r.grade]!.0; r.tokens = R[r.grade]!.1; r.dps = dealt / Swift.max(1, t)
        return r
    }
}

/// 웹 GS.bonus
final class BonusRun {
    struct Debris { var key: String, x: Double, y: Double, z: Double, th: Double, vx: Double, vy: Double, vth: Double; var landed = false, clanked = false, lastVy = 0.0 }
    struct Car { var x = 330.0, y = 226.0, stage = 0, gone: Set<String> = [], tilt = 0.0, shake = 0.0, flash = 0.0, dmgF = 0.0, debris: [Debris] = [] }
    var t = 0.0, dur = BonusCarRig.time, hp = BonusCarRig.hp, max = BonusCarRig.hp, dealt = 0.0
    var car = Car()
    var phase = "intro", pt = 0.0, score = 0, hitPts = 0, partPts = 0, maxCombo = 0, hits = 0
    var dummy: Actor?, owner: Actor?
    var alarm = false, alarmOff = false, fire = false
    var res: BonusResult?
    var knelt = false, said = false, skip = false
    var smT = 0.0, stT = 0.0, fiT = 0.0, beepS: Int?
}

extension World {
    /// 웹 NFLOOR(06-art-arenas — 느와르 거리 바닥선)
    static let NFLOOR = 196.0

    /// 웹 startBonus(): 차 부수기 — 보이지 않는 허수아비로 피해를 잰다
    func startBonus() {
        guard let H = hero else { return }
        setState("bonus"); bonusDone = true; bonusSt[stageIdx] = true; items = []; ev = nil
        let B = BonusRun(); B.car.y = World.NFLOOR + 30
        bn = B; bonus = true
        for a in ents where a !== H { retire(a) }
        ents = [H]
        spawnWave(["brute"], fromDoors: false)
        if let D = ents.first(where: { $0.e != nil }) {   // 숨김(hidden)은 '탈 차례 기다리는 적'이라 정리 대상 — 그리기만 생략(invis)
            D.carDummy = true; D.invis = true; D.e!.hp = 1e7; D.e!.max = 1e7; D.e!.cd = 1e9; D.e!.cdT = -1e9; B.dummy = D
        }
        H.x = 70; H.y = World.NFLOOR + 26; H.flip = false; H.hidden = false; H.wpn = nil; setAnim(H, "idle"); fade = 1
        say("보너스 스테이지 · 차 부수기", "\(Int(BonusCarRig.time))초 안에 이 차를 부숴라 — 지금 서류가방의 화력을 확인할 시간", 2.6); sfx("chime")
    }
    /// 웹 jumpTo('bonus')(설정 > 바로 가기 · 개발용): 2호선으로 옮긴 뒤 보너스를 연다
    func jumpToBonus() {
        if talkRun != nil { tkSkip() }
        cut = nil; spc = nil; cine = false; bn = nil; bonus = false
        if pr != nil { pr = nil; if let H = hero { H.wpn = nil; H.hidden = false; H.airOv = 0 }; restoreKit() }   // 웹 jumpTo: 남은 프롤로그를 끝낸다
        playSpeed = 1.25   // 웹 setGameSpeed(GAME_SPD)
        loadStage(1)
        let gone = ents.filter { $0.e != nil }; gone.forEach(retire); ents = ents.filter { $0.e == nil }
        bonusDone = false; bonusSt = [:]
        startBonus()
    }
    /// 웹 pointerdown 의 보너스 결산 넘기기(owner 단계 2.4초 뒤)
    func bonusSkip() { if let B = bn, B.phase == "owner", B.pt > 2.4 { B.skip = true } }

    /// 웹 carDetach(C, key, vx, vy, vth): 부품이 떨어져 파편이 된다(+부품 점수)
    func carDetach(_ key: String, _ vx: Double, _ vy: Double, _ vth: Double) {
        guard let B = bn else { return }
        let C = B.car
        guard let b = BonusCarRig.bones(stage: C.stage, dmgF: C.dmgF, gone: C.gone, tilt: C.tilt)[key] else { return }
        B.car.gone.insert(key)
        B.car.debris.append(.init(key: key, x: C.x + b.x, y: C.y + b.y, z: b.z, th: b.th, vx: vx, vy: vy, vth: vth))
        carPts(key)
    }
    /// 웹 carPts(C, key)
    func carPts(_ key: String) {
        guard let B = bn, let v = BonusCarRig.pts[key] else { return }
        B.partPts += v.0; B.score += v.0
        emit(.textPop(x: B.car.x - 5, y: B.car.y - 60, text: "+\(v.0) \(v.1)!")); sfx("coin")
    }
    /// 웹 carStage(C, n): 파손 단계마다 부품이 떨어지고 경보 · 불길 — 8단계는 폭발(슬로 0.6초)
    func carStage(_ n: Int) {
        guard let B = bn else { return }
        let x = B.car.x - camX, y = B.car.y - 56
        emit(.comicReset)   // 웹 carStage 첫머리 comicT=0
        B.car.flash = 0.05; shake(2)
        func W(_ t: String) { comicSFX(B.car.x, y, t) }
        func glass(_ dx: Double, _ dy: Double, _ k: Int) { fx("carGlass", B.car.x + dx, B.car.y + dy, Double(k)) }
        switch n {
        case 1: carDetach("mirror", 80, -190, 7); sfx("carHit", 1); W("CRASH!"); B.alarm = true   // 경보가 울리기 시작한다
        case 2: carDetach("hubF", 130, -120, 14); sfx("carHit", 0); W("KLANG!")
        case 3: glass(6, -30, 22); sfx("glass"); W("SMASH!")
        case 4: carDetach("bumperF", 110, -150, -5); sfx("carHit", 1); W("BAM!")
        case 5: carDetach("doorF", 90, -220, 4.5); glass(52, -14, 10); sfx("glass"); sfx("carHit", 1); W("KRAK!")
        case 6: carDetach("hood", 40, -300, -9); carDetach("doorR", 60, -190, -4); sfx("carHit", 1); W("WHAM!")
        case 7: carDetach("wheelF", 150, -90, 12); carDetach("wheelF2", 150, -90, 12); B.car.tilt = 0.07; glass(-10, -26, 12); sfx("carHit", 1); sfx("hiss"); W("THUD!")
        case 8:
            carDetach("trunk", -60, -260, -6); carDetach("bumperR", -100, -160, -7); B.car.tilt = 0.09; sfx("boom"); slowT = 0.6
            var k = CameraKick(); k.zoom = 0.12; k.focus = SIMD2(x, B.car.y - 20); k.shake = 4; emit(.camera(k)); emit(.haptic(.heavy))
            glass(0, -24, 24); W("KA-BOOM!"); B.alarmOff = true; B.fire = true
        default: break
        }
    }
    /// 웹 carHit(loss): 차 체력 · 타격 점수(피해 비례 · 연타 배율 최대 2배) · 단계 넘김
    func carHit(_ loss: Double) {
        guard let B = bn else { return }
        B.hp = max(0, B.hp - loss); B.dealt += loss; B.hits += 1; B.maxCombo = max(B.maxCombo, combo)
        let pts = jsRoundI((100 + loss * 8) * (1 + min(1, Double(combo) * 0.05)) / 10) * 10
        B.hitPts += pts; B.score += pts
        B.car.shake = 1; if loss > 15 { B.car.flash = 0.035 }
        B.car.dmgF = 1 - B.hp / B.max
        fx("carHit", B.car.x - 46, B.car.y - 13, loss)
        let fr = B.hp / B.max
        while B.car.stage < BonusCarRig.stages.count && fr <= BonusCarRig.stages[B.car.stage] { B.car.stage += 1; carStage(B.car.stage) }
    }

    /// 웹 bonusUpdate(dt)
    func bonusUpdate(_ dt: Double) {
        guard let B = bn, let H = hero else { return }
        B.car.shake = max(0, B.car.shake - dt * 5); B.car.flash = max(0, B.car.flash - dt)
        let Cx = B.car.x, Cy = B.car.y
        if let D = B.dummy {
            D.x = Cx - 50; D.y = H.y; D.kb = 0; D.e!.stun = 0; D.heldBy = nil; D.airOv = 0
            if D.anim != "idle" { D.anim = "idle"; D.action = nil; D.queue = [] }
        }
        if H.x > Cx - 58 { H.x = Cx - 58 }   // 차체에 막힌다
        if let D = B.dummy { let loss = 1e7 - D.e!.hp; D.e!.hp = 1e7; if loss > 0 && B.phase == "go" { carHit(loss) } }
        for i in B.car.debris.indices {
            var d = B.car.debris[i]
            d.vy += 420 * dt; d.x += d.vx * dt; d.y += d.vy * dt; d.th += d.vth * dt
            if d.y > Cy - 3 { d.y = Cy - 3; d.vy *= -0.35; d.vx *= 0.62; d.vth *= 0.55; if abs(d.vy) < 25 { d.vy = 0 } }
            if d.vy == 0 && !d.landed && d.y >= Cy - 3.5 { d.landed = true }
            if d.y >= Cy - 3.2 && abs(d.lastVy) > 90 && !d.clanked { d.clanked = true; sfx("carClank") }
            d.lastVy = d.vy
            B.car.debris[i] = d
        }
        // 연기 기둥 · 엔진 김 · 불길(연출 입자 — 시점만 규칙 시계로, 위치 흔들림은 연출 난수)
        if B.car.stage >= BonusCarRig.stages.count { B.smT += dt; if B.smT > 0.09 { B.smT = 0; fx("carSmoke", Cx + 4 + fxr.next() * 30, Cy - 24) } }
        if B.car.gone.contains("hood") && B.car.stage < BonusCarRig.stages.count { B.stT += dt; if B.stT > 0.2 { B.stT = 0; fx("carSteam", Cx + 34 + fxr.next() * 16, Cy - 20) } }
        if B.fire { B.fiT += dt; if B.fiT > 0.045 { B.fiT = 0; fx("carFire", Cx + 14 + fxr.next() * 40, Cy - 12 - fxr.next() * 4) } }
        if B.phase == "go" { let left = B.dur - B.t, sec = Int(left.rounded(.up)); if left <= 5 && sec != B.beepS && sec > 0 { B.beepS = sec; sfx("bonusBeep", Double(sec)) } }
        if B.phase == "intro" { B.pt += dt; if B.pt > 2.2 { B.phase = "go"; comicSFX(data.sbW / 2, 96, "FIGHT!", force: true); sfx("brass") }; return }
        if B.phase == "go" {
            B.t += dt
            if B.hp <= 0 || B.t >= B.dur {
                B.phase = "owner"; B.pt = 0
                var R = BonusCarRig.grade(hp: B.hp, max: B.max, t: B.t, dur: B.dur, dealt: B.dealt)
                tokens += R.tokens; B.alarmOff = true
                if B.hp > 0 { comicSFX(data.sbW / 2, 90, "TIME UP!", force: true) } else if R.grade == "S" { schedule(after: 0.5) { w in w.comicSFX(w.data.sbW / 2, 90, "PERFECT!", force: true) } }
                R.hit = B.hitPts; R.part = B.partPts; R.destroy = B.hp <= 0 ? 10000 : 0; R.time = B.hp <= 0 ? Int(R.left.rounded(.up)) * 1000 : 0; R.combo = B.maxCombo * 100
                R.total = R.hit + R.part + R.destroy + R.time + R.combo
                R.best = R.total > meta.bonusBest; meta.bonusBest = max(meta.bonusBest, R.total); emit(.metaChanged)
                score += R.total; B.res = R
                if let D = B.dummy { retire(D); ents = ents.filter { $0 !== D }; B.dummy = nil }
                setAnim(H, "idle")
                let n0 = ents.count
                spawnWave(["punk"], fromDoors: false)
                if ents.count > n0, let O = ents.last {
                    O.carOwner = true; O.e!.cd = 1e9; O.e!.cdT = -1e9; O.x = data.sbW + 20; O.flip = true; B.owner = O
                }
                emit(.bonusEnded(R))
            }
            return
        }
        if B.phase == "owner" {
            B.pt += dt
            if let O = B.owner, !B.knelt {
                let dx = -120 * dt; O.x += dx; O.gph += abs(dx) / 66   // 웹 advGait(달리기)
                if O.anim != "run" { setAnim(O, "run") }
                if O.x <= Cx + 56 { B.knelt = true; setAnim(O, "duck"); comicSay(O, "내 차아아!", "shout"); sfx("hurt") }
            }
            if let O = B.owner, B.knelt, O.anim != "duck" { setAnim(O, "duck") }
            if B.pt > 1.6 && !B.said { B.said = true; sfx("clear") }
            if B.pt > 8.2 || (B.skip && B.pt > 2.2) { finishBonus() }
        }
    }
    /// 웹 finishBonus(): 지하철로 돌아와 환승
    func finishBonus() {
        guard let H = hero else { return }
        bn = nil; bonus = false
        for a in ents where a !== H { retire(a) }
        ents = [H]; H.y = data.floorY
        startTransfer()
    }

    /// 스냅숏 보너스 칸
    func bonusView(_ B: BonusRun) -> BonusView {
        var v = BonusView()
        v.phase = B.phase; v.t = B.t; v.dur = B.dur; v.left = max(0, B.dur - B.t); v.pt = B.pt
        v.hp = B.hp; v.max = B.max; v.dealt = B.dealt
        v.score = B.score; v.hitPts = B.hitPts; v.partPts = B.partPts; v.maxCombo = B.maxCombo; v.hits = B.hits
        v.alarm = B.alarm; v.alarmOff = B.alarmOff; v.fire = B.fire
        var c = BonusView.Car()
        c.x = B.car.x; c.y = B.car.y; c.stage = B.car.stage; c.gone = B.car.gone.sorted(); c.tilt = B.car.tilt; c.shake = B.car.shake; c.flash = B.car.flash
        c.dmgF = B.car.dmgF; c.dentN = BonusCarRig.dentN(B.car.dmgF)
        c.debris = B.car.debris.map { .init(key: $0.key, x: $0.x, y: $0.y, z: $0.z, th: $0.th) }
        v.car = c
        v.owner = B.owner?.id; v.knelt = B.knelt; v.skippable = B.phase == "owner" && B.pt > 2.4
        v.result = B.res
        return v
    }
}
