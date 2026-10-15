import Foundation
import BBCore
import BBContent

// 웹 24-tower.js 규칙 부분: 엘리베이터 타워(한 층 = 한 웨이브 · 정원 · 문 · 천장 튕기기 · 층 부수기 · 적 특수 행동 · 구급함 · 밤바람 ·
// 야근 단계 · 오늘의 타워) — startTower · twArrive · twSpawn · twOut · twImpact · twCeil · twFoeTick · towerTick · towerResult · twDaily.
// 다른 조각의 타워 갈래(웹 GS.tower 검사)는 제자리에 넣었다: AW0/AW1 · doorOpenAt(27) · jugHit 1.55배 · jugStep 천장 · groundImpact 출렁임(13) ·
// gameUpdate 분기 · 사망 결과(30) · 매점 회복 restK · finishArrange(34) · camTick(47).
// 규칙 난수(웹 Math.random 규칙 자리 — simtrace RULE_SITES '24-tower.js'): twArrive(76) · twFoeTick(124 · 126 · 128) · towerTick(136 · 144).
// 연출 난수(전등 흔들림 · 날아간 적 회전 · 불꽃 · 말풍선 고르기)는 fxr(연출 수열)을 쓴다 — 규칙 순서에 끼어들지 않는다.

/// 웹 TWR(09-art-tower — 추출 표에 없는 화면 기하 상수)
enum TWR {
    static let L = 72.0, R = 408.0, G0 = 172.0, G1 = 308.0, GT = 126.0, CEIL = 104.0, PX = 330.0, FH = 300.0, CEIL_H = 62.0, CX = 56.0, CY = 88.0
}

/// 타워 정적 데이터(웹 TW_* 표 — 추출된 실행 값)
struct TowerData {
    let floors: [TowerFloor?]
    let top: Int, limit: Int, otMax: Int
    let wt: [String: Int]
    /// 웹 TW_HIT[fs] = [x, y, 효과음 글자, 물건 이름, 색들]
    let hit: [String: (x: Double, y: Double, word: String, name: String)]
    let barks: [String]
    let lampX: [Double]
    /// TW_MODS id 순서 · 이름
    let mods: [TowerRule]
    let ot: [TowerRule?]
    init(_ d: SimData) {
        let s = d.store
        floors = d.game.towerFloors; mods = d.game.towerMods; ot = d.game.towerOvertime
        top = (try? s.decode("TW_TOP", as: Int.self)) ?? 20
        limit = (try? s.decode("TW_LIMIT", as: Int.self)) ?? 7
        otMax = (try? s.decode("TW_OT_MAX", as: Int.self)) ?? 6
        wt = (try? s.decode("TW_WT")) ?? [:]
        var h: [String: (Double, Double, String, String)] = [:]
        if let raw: [String: [JSONValue]] = try? s.decode("TW_HIT") {
            for (k, v) in raw where v.count >= 4 { h[k] = (v[0].double ?? 0, v[1].double ?? 0, v[2].string ?? "", v[3].string ?? "") }
        }
        hit = h.mapValues { (x: $0.0, y: $0.1, word: $0.2, name: $0.3) }
        barks = (try? s.decode("TW_BARKS")) ?? []
        lampX = (try? s.decode("TW_LAMPX")) ?? [128, 352]
    }
    func floor(_ n: Int) -> TowerFloor? { n >= 0 && n < floors.count ? floors[n] : nil }
}

/// 적 하나의 타워 특수 행동 상태(웹 e.work · techDone · towerBusy · pressDone · flT · mopT · lurchT)
struct TowerFoe {
    var work = 0.0
    var techDone = false, pressDone = false, towerBusy = false
    var flT: Double?, mopT: Double?, lurchT: Double?
}

/// 웹 GS.tower
final class TowerRun {
    struct Lamp { var a = 0.0, v = 0.0, hang = false, flick = 0.0 }
    struct Fly { var x0: Double, y0: Double, x1: Double, y1: Double, t = 0.0, dur = 0.5, r0: Double, done = false }
    struct Fire { var x: Double, t: Double, hitT: Double }
    var floor = 1, phase = "arrive", t = 0.0, door = 0.0, pos = 0.0, vel = 0.0
    var q: [String] = [], qT = 0.0, qn = 0, over = false, buzzT = 0.0
    var dent: [Double] = [], ceilN = 0
    var lamps: [Lamp]
    var sag = 0.0, sagV = 0.0
    var kit = true, lurchT = 0.0, blackT = 0.0, blackFloor = false, dark = false, panelT = 0.0, outs = 0
    var wreck: Set<Int> = [], wrecks = 0
    var fly: [Fly] = [], fl = 0.0, shk = 0.0, alarm = 0.0, alT = 0.0, alH = false
    var t0: Double, kills0: Int
    var limit: Int
    /// 층별 탑승 목록(1…TOP — 0번은 비움)
    var waves: [[String]]
    var blackSet: Set<Int>
    /// 오늘의 타워 조건(TW_MODS 번호)
    var mods: [Int] = []
    var daily: String?
    var hpK = 1.0, dmgK = 1.0, bossK = 1.0, restK = 1.0
    var ot = 0
    var shopped = false, extra = 0
    var fires: [Fire] = []
    var windT: Double?, gust = 0.0, gdir: Double?
    var hum = 0.0
    var hinted = false, zoneShop = false, done = false, ceilSaid = false, holeSaid = false
    var result: TowerResult?
    init(lamps n: Int, t0: Double, kills0: Int, limit: Int, waves: [[String]], blackSet: Set<Int>) {
        lamps = Array(repeating: Lamp(), count: n); self.t0 = t0; self.kills0 = kills0; self.limit = limit; self.waves = waves; self.blackSet = blackSet
    }
}

extension World {
    /// 웹 hashStr(s): FNV-1a 32비트(UTF-16 첫 단위)
    static func hashStr(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for ch in s.unicodeScalars { h ^= UInt32(String(ch).utf16.first!); h = h &* 16_777_619 }
        return h
    }

    // MARK: 야근 단계 · 오늘의 타워 조건(웹 TW_OT[l].ap · TW_MODS[k].ap — lambdas.json 원문)

    /// 웹 TW_OT[l].ap(T)
    func twApplyOT(_ T: TowerRun, _ l: Int) {
        switch l {
        case 1: T.hpK *= 1.15
        case 2: T.limit -= 1
        case 3: T.blackSet.insert(3); T.blackSet.insert(13)
        case 4: T.dmgK *= 1.2
        case 5: T.kit = false; T.restK = 0.5
        case 6: T.bossK *= 1.3; for n in [10, 20] where n < T.waves.count { T.waves[n].append("guardL") }
        default: break
        }
    }
    /// 웹 TW_MODS[k].ap(T, r) — r 은 오늘의 타워 수열(mulberry(hashStr('tower'+날짜)))
    func twApplyMod(_ T: TowerRun, _ id: String, _ r: inout Mulberry32) {
        let top = twd.top
        func nonBoss(_ k: Int) -> Bool { twd.floor(k)?.boss != true }
        switch id {
        case "cap6": T.limit = 6
        case "dark2": let c = [2, 3, 4, 6, 8, 9]; T.blackSet.insert(c[Int((r.next() * Double(c.count)).rounded(.down))])
        case "rush": for k in 1...top { T.waves[k] = T.waves[k].map { $0 == "valet" && r.next() < 0.5 ? "courier" : $0 } }
        case "guard": for k in 1...top where !T.waves[k].isEmpty && nonBoss(k) && r.next() < 0.6 { T.waves[k].append("guardL") }
        case "mop": for k in 1...top where !T.waves[k].isEmpty && nonBoss(k) && r.next() < 0.6 { T.waves[k].append("janitor") }
        case "wire": for k in [3, 6, 9] where !T.waves[k].isEmpty { T.waves[k].append("tech") }
        default: break
        }
    }
    /// 웹 twDaily(dk): 날짜마다 같은 조건 두 개 + 같은 탑승 순서용 수열
    func twDaily(_ dk: String) -> (r: Mulberry32, mods: [Int]) {
        var r = Mulberry32(seed: Int32(bitPattern: World.hashStr("tower" + dk)))
        var pool = Array(twd.mods.indices), mods: [Int] = []
        for _ in 0..<2 { mods.append(pool.remove(at: Int((r.next() * Double(pool.count)).rounded(.down)))) }
        return (r, mods)
    }
    /// 웹 startTower 의 층별 탑승 목록 · 정전 층 · 조건 적용(순수 — 픽스처 대조용으로 떼어 둠)
    func twSetup(daily dk: String?, ot otWant: Int) -> TowerRun {
        let top = twd.top
        var waves: [[String]] = [[]]
        for n in 1...top { waves.append(twd.floor(n)?.w ?? []) }
        var black: Set<Int> = []
        for (n, F) in twd.floors.enumerated() where F?.black == true && n > 0 { black.insert(n) }
        let T = TowerRun(lamps: twd.lampX.count, t0: time, kills0: kills, limit: twd.limit, waves: waves, blackSet: black)
        if let dk {
            var D = twDaily(dk); T.daily = dk
            for n in 1...top where twd.floor(n)?.boss != true {
                var w = T.waves[n]
                if w.count > 1 { for i in stride(from: w.count - 1, to: 0, by: -1) { let j = Int((D.r.next() * Double(i + 1)).rounded(.down)); w.swapAt(i, j) } }
                T.waves[n] = w
            }
            for m in D.mods { twApplyMod(T, twd.mods[m].id ?? "", &D.r); T.mods.append(m) }
        }
        T.hpK = 1; T.dmgK = 1; T.bossK = 1; T.restK = 1
        T.ot = dk != nil ? 0 : max(0, min(meta.tower.ot, otWant))
        if T.ot > 0 { for l in 1...T.ot { twApplyOT(T, l) } }   // 야근 단계 조건(누적)
        return T
    }

    // MARK: 시작 · 층 도착

    /// 웹 startTower(opts): 판을 새로 시작해 1층 주차장에서 문이 열린다
    func startTower() {
        let daily = config.daily, keep = config
        var c = config; c.stage = 0; config = c; startRun(devStart: true); config = keep   // 웹: startRun({stage:0, daily}) 뒤 RUNCFG 복원
        devRun = false
        prologue = false; ev = nil; props = []; cans = []; items = []; shots = []
        for a in ents where a !== hero { retire(a) }
        ents = [hero]; setState("fight"); wave = 99; nextWaveAt = 1e9; departT = 0; atStop = nil; arriving = false; quickStop = nil; oneBit = false; trans = nil
        tr.phase = "stop"; tr.v = 0; tr.a = 0; tr.door = 0; tr.dy = 0; tr.jolt = 0
        let H = hero!; H.x = 140; H.flip = false; setAnim(H, "idle")
        let T = twSetup(daily: daily ? (config.dateKey ?? "1970-01-01") : nil, ot: config.towerOT)
        tw = T; tower = true
        playSpeed = 1.25   // 웹 setGameSpeed(GAME_SPD)
        sfx("chime")
        if let dk = T.daily { say("오늘의 타워 · \(dk)", T.mods.map { twd.mods[$0].name }.joined(separator: " · "), 3.0) }
        else if T.ot > 0 { say("엘리베이터 타워 · 야근 \(T.ot)단계", (1...T.ot).compactMap { twd.ot[$0]?.name }.joined(separator: " · "), 3.0) }
        else { say("엘리베이터 타워", "1층 주차장에서 20층 총주방장실까지 · 정원을 넘기면 문이 안 닫혀요", 3.0) }
        emit(.towerFloor(floor: T.floor))
    }
    /// 웹 twArrive(): 층 도착 — 기록 · 회계사가 누른 버튼만큼 더 탄다 · 토큰 1 · 점수
    func twArrive() {
        guard let T = tw else { return }
        let F = twd.floor(T.floor)
        T.phase = "arrive"; T.t = 0; T.door = 0; T.shopped = false; T.blackFloor = T.blackSet.contains(T.floor) && T.blackFloor
        if T.floor > meta.tower.best { meta.tower.best = T.floor; emit(.metaChanged) }
        if T.extra > 0 && T.floor < T.waves.count && !T.waves[T.floor].isEmpty && F?.boss != true {   // 회계사가 누른 버튼
            let pool = T.floor > 10 ? ["accountant", "waiter", "chef"] : ["valet", "janitor", "guardL"]
            for _ in 0..<T.extra { T.waves[T.floor].append(pool[rndInt(pool.count)]) }
            T.extra = 0
        }
        tokens += 1; score += 200 * T.floor; renderBag()
        let blackNote = T.blackSet.contains(T.floor) && F?.black != true
        say("\(T.floor)F · \(F?.name ?? "")", blackNote ? "전기가 나갔다 — 손전등 불빛만 움직인다" : (F?.desc ?? ""), 2.2)
        emit(.towerFloor(floor: T.floor))
    }
    /// 웹 twWt(a) · twWeight(): 정원 무게
    func twWt(_ a: Actor) -> Int { twd.wt[a.e!.t] ?? (a.e!.heavy ? 3 : 2) }
    func twWeight() -> Int { foes().reduce(0) { $0 + twWt($1) } }
    /// 웹 twSpawn(t, k): 층 배율(1~10층 +5%/층 · 11층부터 1.25+4%/층) × 야근 배율로 한 명 태운다
    func twSpawn(_ t: String, _ k: Int) {
        guard let T = data.enemy(t), let TT = tw, let H = hero else { return }
        let fl = Double(TT.floor)
        let m = (fl <= 10 ? 1 + 0.05 * (fl - 1) : 1.25 + 0.04 * (fl - 11)) * TT.hpK * (T.boss == true ? TT.bossK : 1)
        let x = TWR.G0 + 24 + Double((k * 31) % 92)
        let dm = jsRound(T.dmg * 0.8 * (fl <= 10 ? 1 + 0.04 * (fl - 1) : 1.2 + 0.03 * (fl - 11)) * TT.dmgK)
        let e = Enemy(t: t, def: T, hp: jsRound(T.hp * m), dmg: dm, cd: T.cd * 1.2, cdT: -1.1 - Double(k) * 0.35)
        metaFoe(t)
        let a = mkActor(defFor(T, k), x: x, z: 1 + Double((k * 3) % 5), flip: x > H.x, pose: "st0", remap: T.remap, grammar: T.grammar, e: e)
        setAnim(a, "idle"); ents.append(a)
        fx("dust", x, data.floorY)
        if T.boss == true { bossIntro(a) }
        else if k == 0 && fxr.next() < 0.6, !twd.barks.isEmpty { emit(.bark(actor: a.id, key: twd.barks[Int(fxr.next() * Double(twd.barks.count))])) }   // 말풍선 고르기는 연출 난수
        emit(.waveSpawned(types: [t], fromDoors: true))
        nvKOArmed = true   // 네이티브 KO 마무리: 새 웨이브마다 한 번
    }

    // MARK: 문밖 · 층 부수기 · 천장

    /// 웹 twOut(a): 문밖으로 날린 적은 층 안으로 굴러 들어가 그 층의 물건에 부딪힌다
    func twOut(_ a: Actor) {
        guard let T = tw else { return }
        T.outs += 1
        guard let F = twd.floor(T.floor), T.phase != "move", let h = twd.hit[F.fs] else { return }
        let x0 = max(TWR.G0 + 14, min(TWR.G1 - 14, a.x)), y0 = a.y - 34 - (a.jug?.h ?? 0)
        T.fly.append(.init(x0: x0, y0: y0, x1: TWR.G0 + h.x, y1: TWR.GT + h.y, r0: (fxr.next() * 4).rounded(.down)))
    }
    /// 웹 twImpact(fl): 처음엔 층이 부서진 모습으로(+600) · 그다음부턴 작은 반응(+200)
    func twImpact(_ fl: Int) {
        guard let T = tw, let F = twd.floor(fl), let h = twd.hit[F.fs] else { return }
        let x = TWR.G0 + h.x, y = TWR.GT + h.y, first = !T.wreck.contains(fl)
        if first { T.wreck.insert(fl); T.wrecks += 1 }
        let pts = first ? 600 : 200; score += pts; T.fl = first ? 0.5 : 0.25; T.shk = first ? 0.5 : 0.3; shake(first ? 2.4 : 1.4)
        fx("twfall", x, y, first ? 22 : 9)
        emit(.textPop(x: x - 24, y: y - 18, text: "+\(pts) \(h.name)\(first ? "!" : "")"))
        comicSFX(x, y - 10, first ? h.word : "BAM!", force: true)
        if F.fs == "park" { T.alarm = first ? 6 : max(T.alarm, 3) }
        sfx("twImpact:" + F.fs)
        if first { stats.wrecks += 1 }
    }
    /// 웹 twCeil(a, J): 띄운 적이 천장에 부딪혀 꺾여 내려온다 · 천장이 찌그러지고 전등이 흔들린다 · 찌그러짐이 쌓이면 전등이 매달린다
    func twCeil(_ a: Actor, _ J: Jug) {
        guard let T = tw else { return }
        J.h = TWR.CEIL_H; J.vy = -max(90, J.vy * 0.5); J.hitT = time + 0.16; a.hs = max(a.hs, 3); a.shkA = 2
        let x = a.x, y = TWR.CEIL + 2
        fx("spark", x, y + 2); fx("twceil", x, y + 3)
        comicSFX(x, y + 20, "쾅!", force: true); sfx("thud"); shake(2.6); T.sagV += 6
        if T.dent.count < 7 && !T.dent.contains(where: { abs($0 - x) < 14 }) { T.dent.append(jsRound(max(TWR.L + 10, min(TWR.R - 10, x)))) }
        for i in T.lamps.indices {
            let lx = twd.lampX[i], d = abs(lx - x)
            if d < 150 { let s: Double = fxr.next() < 0.5 ? -1 : 1; T.lamps[i].v += s * (1.6 + fxr.next()) * (1 - d / 150); T.lamps[i].flick = max(T.lamps[i].flick, 0.25) }
            if !T.lamps[i].hang && T.dent.filter({ abs($0 - lx) < 70 }).count >= 2 {
                T.lamps[i].hang = true; T.lamps[i].v += 2.5; fx("twlamp", lx, y + 2)
                if !T.holeSaid { T.holeSaid = true; say("", "천장판이 떨어져 전등이 매달렸다", 1.6) }
            }
        }
        T.ceilN += 1; stats.ceils += 1
        if let e = a.e, !a.dead {
            let dm = max(1, jsRound(5 * (1 + 0.06 * Double(T.floor - 1))))
            if e.hp > dm { e.hp -= dm; stats.dealt += dm; score += 80; emit(.damagePop(target: a.id, value: Int(jsRound(dm * data.dmgK)), style: "hit", label: nil)) }
        }
        if !T.ceilSaid { T.ceilSaid = true; hint("tower") }
    }

    // MARK: 적 특수 행동

    /// 웹 twFoeTick(dt): 수리 기사(패널 배선 → 정전) · 회계사(버튼 → 다음 층에 더 탄다) · 총주방장(플랑베 불꽃) · 청소부(웅덩이) · 관리인(패널 내리쳐 덜컹)
    func twFoeTick(_ dt: Double) {
        guard let T = tw, let H = hero else { return }
        for a in foes() {
            let e = a.e!, D = e.def
            if D.tech == true {
                let ok = !T.dark && !e.tw.techDone && canAct(a) && a.jug == nil && !isDown(a) && e.stun <= 0 && !a.held
                e.tw.towerBusy = ok
                if ok {
                    if abs(a.x - TWR.PX) > 6 { face(a, TWR.PX); moveTo(a, TWR.PX, e.spd, dt) }
                    else {
                        if a.anim == "walk" { setAnim(a, "idle") }
                        a.flip = false; e.tw.work += dt
                        if fxr.next() < dt * 4 { fx("spark", TWR.PX + 2 + fxr.next() * 8, 146 + fxr.next() * 36) }
                        if e.tw.work >= 5 {
                            e.tw.work = 0; e.tw.techDone = true; e.tw.towerBusy = false; T.blackT = 10; T.panelT = 1.2
                            comicSFX(TWR.PX, 120, "ZZT!", force: true); sfx("twZap"); say("", "수리 기사가 배선을 끊었다 — 정전", 1.8)
                        }
                    }
                } else if e.tw.work > 0 && !canAct(a) { e.tw.work = max(0, e.tw.work - dt * 1.5) }
            }
            if D.presser == true {   // 회계사: 패널로 몰려가 층 버튼을 전부 누른다 → 다음 층에 더 탄다
                let ok = !e.tw.pressDone && canAct(a) && a.jug == nil && !isDown(a) && e.stun <= 0 && !a.held
                e.tw.towerBusy = ok
                if ok {
                    if abs(a.x - TWR.PX) > 6 { face(a, TWR.PX); moveTo(a, TWR.PX, e.spd, dt) }
                    else {
                        if a.anim == "walk" { setAnim(a, "idle") }
                        a.flip = false; e.tw.work += dt
                        if e.tw.work >= 3 {
                            e.tw.work = 0; e.tw.pressDone = true; e.tw.towerBusy = false; T.extra = min(3, T.extra + 1); T.panelT = 2.2
                            comicSFX(TWR.PX, 120, "BEEP!", force: true); sfx("twBeep"); say("", "회계사가 버튼을 다 눌렀다 — 다음 층에 더 탄다", 1.8)
                        }
                    }
                } else if e.tw.work > 0 && !canAct(a) { e.tw.work = max(0, e.tw.work - dt * 1.5) }
            }
            if D.flambe == true {   // 총주방장: 플랑베 — 바닥에 불꽃을 붙인다
                e.tw.flT = (e.tw.flT ?? 5) - dt
                if e.tw.flT! <= 0 && canAct(a) && a.jug == nil && !isDown(a) {
                    e.tw.flT = 7 + rnd() * 2
                    let fx0 = jsRound(max(TWR.L + 16, min(TWR.R - 16, H.x + (rnd() * 30 - 15))))
                    T.fires.append(.init(x: fx0, t: 3.6, hitT: 0.3)); if T.fires.count > 3 { T.fires.removeFirst() }
                    comicSFX(fx0, 150, "화르륵!", force: true); sfx("twFlame"); face(a, H.x); foeStrike(a, "bat")
                }
            }
            if D.janitor == true {
                e.tw.mopT = (e.tw.mopT ?? 2.5) - dt
                if e.tw.mopT! <= 0 && canAct(a) && a.jug == nil && !isDown(a) {
                    e.tw.mopT = 6 + rnd() * 3
                    let px = jsRound(a.x - 8)
                    props = props.filter { $0.k != "puddle" || abs($0.x - px) > 18 }
                    if props.filter({ $0.k == "puddle" }).count < 3 { props.append(Prop(k: "puddle", x: px)); comicSFX(a.x, a.y - 70, "찰박"); sfx("twMop") }
                }
            }
            if e.t == "mgr" {
                e.tw.lurchT = (e.tw.lurchT ?? 7) - dt
                if e.tw.lurchT! <= 0 && canAct(a) && a.jug == nil && !isDown(a) {
                    e.tw.lurchT = 9 + rnd() * 3; T.lurchT = 0.8; T.sagV += 14; shake(3.2); T.panelT = 1
                    for i in T.lamps.indices { let s: Double = fxr.next() < 0.5 ? -1 : 1; T.lamps[i].v += s * 2.2; T.lamps[i].flick = 0.5 }
                    comicSFX(240, 130, "덜컹!", force: true); sfx("thud"); face(a, H.x); foeStrike(a, "charge")
                }
            }
        }
    }

    // MARK: 층 진행

    /// 웹 towerTick(dt): 출렁임 · 전등 · 날아간 적 · 경보 · 정전 · 구급함 · 적 특수 행동 · 불꽃 · 밤바람 · 층 진행 단계
    func towerTick(_ dt: Double) {
        guard let T = tw, let H = hero else { return }
        T.t += dt
        let F = twd.floor(T.floor)
        T.sagV += (-60 * T.sag - 7 * T.sagV) * dt; T.sag += T.sagV * dt
        for i in T.lamps.indices {
            var L = T.lamps[i]; let k = L.hang ? 5.0 : 22, c = L.hang ? 0.35 : 2.6
            L.v += (-k * L.a - c * L.v) * dt; L.a += L.v * dt; L.a = max(-0.52, min(0.52, L.a)); L.flick = max(0, L.flick - dt)
            T.lamps[i] = L
        }
        T.lurchT = max(0, T.lurchT - dt); T.panelT = max(0, T.panelT - dt); T.fl = max(0, T.fl - dt * 1.6); T.shk = max(0, T.shk - dt)
        var impacts = 0
        for i in T.fly.indices { T.fly[i].t += dt; if T.fly[i].t >= T.fly[i].dur && !T.fly[i].done { T.fly[i].done = true; impacts += 1 } }
        for _ in 0..<impacts { twImpact(T.floor) }
        T.fly.removeAll { $0.done }
        if T.alarm > 0 { T.alarm -= dt; T.alT -= dt; if T.alT <= 0 { T.alT = 0.28; T.alH.toggle(); sfx("twAlarm", T.alH ? 920 : 700) } }   // 주차장 차 경보
        let lurch = T.lurchT > 0 ? (rnd() - 0.5) * 4 : 0
        tr.dy = jsRound(T.sag + lurch + (T.phase == "move" && T.vel > 20 ? sin(T.t * 9) * 0.5 : 0))
        let blk = T.blackSet.contains(T.floor)
        if T.blackT > 0 { T.blackT -= dt; if T.blackT <= 0 && !(blk && T.blackFloor) { say("", "전기가 돌아왔다", 1.4) } }
        T.dark = (blk && T.blackFloor) || T.blackT > 0
        if T.kit && hp < maxHP * 0.35 && !H.dead {   // 비상 구급함
            T.kit = false; let v = jsRound(maxHP * 0.3); hp = min(maxHP, hp + v)
            emit(.damagePop(target: H.id, value: Int(jsRound(v * data.dmgK)), style: "heal", label: nil)); comicSFX(368, 132, "와장창", force: true); sfx("glass")
            say("", "비상 구급함 — 체력 30% 회복", 1.8)
        }
        twFoeTick(dt)
        if !T.fires.isEmpty {   // 불꽃: 밟은 사람은 데인다(적도)
            for i in T.fires.indices {
                T.fires[i].t -= dt; T.fires[i].hitT -= dt
                if T.fires[i].hitT <= 0 {
                    T.fires[i].hitT = 0.6
                    let fxX = T.fires[i].x
                    let src = Actor(id: -1, def: .passenger(), x: fxX, y: data.floorY, flip: false, z: 0, pose: "m_idle0", remap: 0, grammar: nil, e: nil, pass: false)
                    var o = HitOpts(); o.react = "body"
                    if abs(H.x - fxX) < 14 && !H.dead && !heroAirborne(H) { damage(src, H, jsRound(4 * T.dmgK), o) }
                    for a in foes() where !a.e!.boss && abs(a.x - fxX) < 14 && a.jug == nil && !isDown(a) { damage(src, a, 4, o) }
                }
            }
            T.fires.removeAll { $0.t <= 0 }
        }
        if F?.wind == true && T.phase != "move" && T.door > 0.5 {   // 루프탑: 밤바람이 칸을 민다
            T.windT = (T.windT ?? 1.2) - dt
            if T.windT! <= 0 {
                T.windT = 3.2 + rnd() * 1.4; T.gust = 1.3; T.gdir = -(T.gdir ?? 1)
                comicSFX(240, 140, "휘잉!", force: true); sfx("twWind"); fx("twwind", 240, 150, T.gdir!)
            }
        }
        if T.gust > 0 {
            T.gust -= dt
            let g = T.gdir ?? 1
            for a in ents { if a.held || a.pass || a.dead { continue }; a.x += g * (a === H ? 16 : 34) * dt }
            for i in T.lamps.indices { T.lamps[i].v += g * dt * 2.2 }
        }
        switch T.phase {
        case "move":
            let tgt = Double(T.floor) * TWR.FH, nf = foes().count, vmax: Double = nf > 0 ? 62 : 230, rem = tgt - T.pos, dec = 90.0
            if rem <= T.vel * T.vel / (2 * dec) + 1 { T.vel = max(10, T.vel - dec * dt) }
            else { T.vel = min(vmax + 40, max(0, T.vel + (T.vel < vmax ? (nf > 0 ? 70 : 150) : -160) * dt)) }   // 빈 칸은 빨리
            T.pos = min(tgt, T.pos + T.vel * dt); T.hum += dt; if T.hum > 0.6 { T.hum = 0; sfx("twHum") }
            if T.pos >= tgt { T.pos = tgt; T.vel = 0; T.floor += 1; T.sagV += 5; twArrive() }
        case "arrive":
            if T.t > 0.45 { T.phase = "open"; T.t = 0; sfx("twDing") }
        case "open":
            T.door = min(1, T.door + dt * 1.7)
            if T.door >= 1 {
                T.phase = F?.rest == true ? "rest" : "board"; T.t = 0; T.q = T.floor < T.waves.count ? T.waves[T.floor] : []; T.qn = 0; T.qT = 0.15
                emit(.doors(open: true))
                if F?.ice == true {   // 냉동 창고: 냉기에 바닥이 언다
                    for x in [128.0, 226, 330] where !props.contains(where: { abs($0.x - x) < 20 }) { props.append(Prop(k: "puddle", x: x, ice: true)) }
                    comicSFX(240, 150, "쩍")
                }
                if blk { T.blackFloor = true; for i in T.lamps.indices { T.lamps[i].flick = 0.6 } }
                if !T.hinted && !T.q.isEmpty { T.hinted = true; schedule(after: 1.6) { $0.hint("tower") } }
            }
        case "board":
            T.qT -= dt
            if !T.q.isEmpty && T.qT <= 0 && foes().count >= 6 {   // 칸이 미어터지면 나머지는 다음 엘리베이터를 기다린다
                T.q = []; if let A = foes().first(where: { !$0.e!.boss }) { emit(.bark(actor: A.id, key: "꽉 찼네 — 다음 거 탈게")) }
            }
            if !T.q.isEmpty && T.qT <= 0 { let t = T.q.removeFirst(); let k = T.qn; T.qn += 1; twSpawn(t, k); T.qT = 0.42 }
            if T.q.isEmpty && T.t > 0.7 { T.phase = "hold"; T.t = 0 }
        case "hold":
            let over = twWeight() > T.limit; T.over = over
            if over { T.buzzT -= dt; if T.buzzT <= 0 { T.buzzT = 0.75; sfx("twBuzz") }; T.t = 0; return }   // 정원 초과: 문이 안 닫힌다
            if T.t > (F?.boss == true ? 1.2 : !foes().isEmpty ? 1.4 : 0.8) { T.phase = "close"; T.t = 0 }
        case "rest":
            if T.t > 0.9 && !T.shopped { T.shopped = true; setState("shop"); openShop() }
        case "close":
            T.over = false; T.door = max(0, T.door - dt * 1.7)
            if T.door <= 0 {
                sfx("clack"); T.sagV += 4; emit(.doors(open: false))
                if F?.boss == true { T.phase = "boss"; T.t = 0 } else if T.floor >= twd.top { T.phase = "clear"; T.t = 0 } else { T.phase = "move"; T.t = 0; T.vel = 0 }
            }
        case "boss":
            if foes().isEmpty {
                flashText("CLEAR", 1.2); sfx("clear")
                if T.floor >= twd.top { T.phase = "clear"; T.t = 0 }
                else {   // 구간 돌파: 토큰 · 매점(회복 + 하나 고르기) 뒤 계속 오른다
                    let z = Int((Double(T.floor) / 10).rounded(.up)); tokens += 4; renderBag()
                    say("\(z)구간 돌파!", "토큰 +4 · 매점에서 하나 골라요 — \(T.floor + 1)층부터 다음 구간", 2.2); T.phase = "zone"; T.t = 0
                }
            }
        case "zone":
            if T.t > 1.8 && !T.zoneShop { T.zoneShop = true; setState("shop"); openShop() }
        case "clear":
            if T.t > 2.6 && !T.done { T.done = true; towerResult(true) }
        default: break
        }
    }

    // MARK: 결과

    /// 웹 towerResult(win): 도달 층 · 걸린 시간 · 기록(META.tower — 최고 층 · 최단 · 야근 단계별 · 오늘의 타워 · 다음 단계 열림)
    func towerResult(_ win: Bool) {
        guard let T = tw, state != "over" else { return }
        setState("over")
        let fl = win ? twd.top : T.floor, secs = max(0, jsRoundI(time - T.t0))
        var M = meta.tower
        M.runs += 1
        let prevB = M.best, prevT = M.bestT
        if fl > prevB { M.best = fl }
        let fast = win && (prevT == 0 || secs < prevT); if fast { M.bestT = secs }
        var lvBest: TowerMeta.Rec?, lvNew = false, unlocked = 0
        if T.daily == nil {
            let c = M.lv[T.ot]
            lvNew = c == nil || fl > c!.f || (fl == c!.f && secs < c!.t)
            if lvNew { M.lv[T.ot] = .init(f: fl, t: secs) }
            lvBest = M.lv[T.ot]
            if win { let nx = min(twd.otMax, T.ot + 1); if nx > M.ot { M.ot = nx; unlocked = nx } }   // 꼭대기 돌파 때 다음 단계 열림
        }
        var dBest: TowerMeta.Rec?, dNew = false
        if let dk = T.daily {
            let c = M.daily[dk]
            dNew = c == nil || fl > c!.f || (fl == c!.f && secs < c!.t)
            if dNew { M.daily[dk] = .init(f: fl, t: secs) }
            dBest = M.daily[dk]
        }
        meta.tower = M; emit(.metaChanged)
        var R = TowerResult()
        R.win = win; R.floor = fl; R.seconds = secs; R.kills = kills - T.kills0; R.outs = T.outs; R.ceils = T.ceilN; R.wrecks = T.wrecks
        R.newRecord = fl > prevB || fast || dNew || lvNew; R.unlocked = unlocked; R.ot = T.ot; R.daily = T.daily
        R.mods = T.mods.map { twd.mods[$0].id ?? "" }; R.best = M.best; R.levelBest = lvBest; R.dailyBest = dBest
        T.result = R
        emit(.towerEnded(R)); emit(.runEnded(win: win))
    }

    /// 스냅숏 타워 칸
    func towerView(_ T: TowerRun) -> TowerView {
        var v = TowerView()
        v.pos = T.pos; v.floor = T.floor; v.phase = T.phase; v.door = T.door; v.shk = T.shk
        v.wreck = T.wreck.sorted(); v.alarm = T.alarm
        v.fly = T.fly.map { .init(t: $0.t, dur: $0.dur, x0: $0.x0, x1: $0.x1, y0: $0.y0, y1: $0.y1, r0: $0.r0) }
        v.sagV = T.sagV; v.limit = Double(T.limit); v.over = T.over; v.panelT = T.panelT; v.kit = T.kit
        v.dent = T.dent; v.lamps = T.lamps.map { .init(a: $0.a, hang: $0.hang, flick: $0.flick) }; v.dark = T.dark
        v.fires = T.fires.map { .init(x: $0.x, t: $0.t) }; v.fl = T.fl
        v.t = T.t; v.vel = T.vel; v.sag = T.sag; v.weight = twWeight(); v.lurchT = T.lurchT; v.blackT = T.blackT; v.gust = T.gust; v.gdir = T.gdir ?? 1
        v.alarmHigh = T.alH; v.ot = T.ot; v.daily = T.daily; v.mods = T.mods.map { twd.mods[$0].id ?? "" }
        v.seconds = max(0, time - T.t0); v.outs = T.outs; v.ceilN = T.ceilN; v.wrecks = T.wrecks
        let best = T.daily.map { meta.tower.daily[$0]?.f ?? 0 } ?? (meta.tower.lv[T.ot]?.f ?? 0)
        v.best = max(best, T.floor)
        v.progress = min(1, T.pos / (Double(twd.top - 1) * TWR.FH))
        v.result = T.result
        return v
    }
}
