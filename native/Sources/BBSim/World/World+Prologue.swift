import Foundation
import BBCore
import BBContent

// 웹 39-prologue.js(지하 복도 · 거리 연출) + 44-story.js 프롤로그 서사(보스의 가방 콤보 쇼 · 배신자 빅터 케인) + 41-hints-save.js restoreKit.
//   startPrologue → corridorUpdate(카메라 트래킹 · CORR_WAVES · 문 doorTick · 진자 전등 lampTick · 금고실 vaultOpen · 콤보 쇼 scTick/tapFire '탭!')
//   → 철문(P.out) → startCine/cineUpdate(달리기 · 장도리 던지기 · 지하철 계단) → endCine/endPrologue → kaneStart/kaneUpdate(슥! · 서류 흩어짐) → 첫 소개 대화(talkOnce intro)
// 그리기(drawCorridor · drawCineProps · 레터박스)는 표현 몫 — 스냅숏 PrologueView/CineView/KaneView 가 웹 변수 이름 그대로 넘긴다.
// 전등 흔들림(lampTick · corrLamps)의 난수는 연출 수열(fxr)을 쓴다(웹도 연출 자리) — 규칙 자리는 doorTick(쾅쾅 문) · corridorUpdate(보이는 문 고르기)뿐.

/// 복도 문(웹 P.doors[wxc] = { st:'shut'|'open'|'bang', t, n, max, burst })
struct CorrDoor { var st = "shut"; var t = 0.0; var n: Int? = nil; var max = 0; var burst = false }
/// 진자 전등(웹 P.lamps[wx] = { a, v })
struct CorrLamp { var a: Double; var v = 0.0 }

/// 웹 GS.prologue
final class PrologueRun {
    var x = 0.0, wi = 0
    var doors: [Int: CorrDoor] = [:]
    var lamps: [Int: CorrLamp] = [:]
    var bangT: Double?
    var bag = false, out = false, outT = 0.0
    var scK: String?, scOpen = false, scFired = 0.0
}
/// 웹 GS.cine(복도 → 거리 → 지하철 입구)
final class CineRun {
    var t = 0.0, stage = 0, fade = 0.0, flash = 1.0
    var stepT = 0.0, t3 = 0.0
    var toss: (t: Double, x0: Double, y0: Double)?
    var hammerIn = false, cap2 = false, cap3 = false
}
/// 웹 GS.kane(막차 안: 빅터 케인 장면)
final class KaneRun {
    var t = 0.0, ph = 0
    var held: [String]
    var K: Actor?
    var side = 1.0
    var d0 = 0.0, t5 = 0.0, t6 = 0.0, ex: Double?
    init(held: [String]) { self.held = held }
}
/// 웹 GS.tapW(콤보 쇼 '탭!' 창: 1.5초 안에 누르면 저스트, 아니면 자동)
final class TapWindow {
    var t = 0.0
    let i: Int
    var T: Actor?
    init(i: Int, T: Actor) { self.i = i; self.T = T }
}

extension World {
    var prologue: Bool { get { pr != nil } set { if !newValue { pr = nil } } }
    var cine: Bool { get { cn != nil } set { if !newValue { cn = nil } } }
    var kane: Bool { get { kn != nil } set { if !newValue { kn = nil } } }

    // MARK: 가방

    /// 웹 scBag(k): 프롤로그 가방(장도리 네 수 · 낙뢰 · 무너뜨려 꽂기 · 서류가방 결재)
    func scBag(_ k: String) -> [Item] {
        (sd.scBag[k] ?? []).filter { item($0.id) != nil }.map { s in let it = newItem(s.id, 1, nil); it.x = s.x; it.y = s.y; it.rot = 0; return it }
    }
    /// 웹 {...b} 복사(같은 uid 의 새 객체)
    func copyItem(_ b: Item) -> Item {
        let it = Item(id: b.id, uid: b.uid, tier: b.tier, opt: b.opt)
        it.x = b.x; it.y = b.y; it.rot = b.rot; it.sx = b.sx; it.sy = b.sy; it.pin = b.pin; it.t = b.t
        it.combo = b.combo; it.last = b.last; it.emp = b.emp; it.opener = b.opener; it.linkMark = b.linkMark; it.isNew = b.isNew
        return it
    }
    /// 웹 hasPro(): 프롤로그 전용 기술(장도리)이 가방에 있나
    func hasPro() -> Bool { bag.contains { item($0.id)?.pro == true } }
    /// 웹 restoreKit(): 맡겨 둔 시작 가방을 돌려받는다
    func restoreKit() { if hasPro(), let K = pKit { bag = K.map(copyItem); renderBag() } }

    // MARK: 시작

    /// 웹 startPrologue(): 지하 2층 기계실 — 시작 가방은 맡겨 두고 장도리 네 수로
    func startPrologue() {
        guard let H = hero else { return }
        pr = PrologueRun()
        schedule(after: 3.2) { $0.hint("move") }
        setState("corridor"); ents = [H]; props = []; cans = []; ev = nil; pt = nil
        pKit = bag.map(copyItem); bag = scBag("hammer"); stash = []; renderBag()
        H.x = 60; H.flip = false; H.wpn = "w_hammer"; setAnim(H, "idle")
        tr.v = 0; tr.phase = "stop"; tr.door = 0; doorWant = false; departT = 9999; atStop = nil
        emit(.storyBeat("prologue"))
        say("자정. 보스가 죽었다.", "지하 기계실에 묶여 있었다. 공구함엔 장도리 하나.", 3.2)
    }

    // MARK: 문 · 전등

    /// 웹 doorAt(wxc)
    func doorAt(_ wxc: Int) -> CorrDoor { if let D = pr!.doors[wxc] { return D }; pr!.doors[wxc] = CorrDoor(); return pr!.doors[wxc]! }
    /// 웹 visibleDoors(): 화면(세로 크롭) 안의 문 자리(구간 240마다 +120)
    func visibleDoors() -> [Int] {
        guard let P = pr else { return [] }
        var out: [Int] = []
        var wxc = Int((P.x / 240).rounded(.down)) * 240 + 120
        while Double(wxc) < P.x + data.sbW {
            let sx = Double(wxc) - P.x
            if sx > camX + 40 && sx < camX + viewW - 40 { out.append(wxc) }
            wxc += 240
        }
        return out
    }
    /// 웹 doorOpen(wxc, list): 문이 열리고 적이 나온다
    func doorOpen(_ wxc: Int, _ list: [String]?) {
        guard let P = pr else { return }
        _ = doorAt(wxc); P.doors[wxc]!.st = "open"; P.doors[wxc]!.t = 0; sfx("door", 1); emit(.storyBeat("door:open:\(wxc)"))
        guard let list, !list.isEmpty else { return }
        let before = Set(ents.map(ObjectIdentifier.init))
        spawnWave(list, fromDoors: false)
        let n = Double(list.count)
        for (k, a) in ents.filter({ !before.contains(ObjectIdentifier($0)) }).enumerated() {
            a.x = Double(wxc) - P.x + (Double(k) - (n - 1) / 2) * 12; a.flip = a.x > (hero?.x ?? 0); a.e?.cdT = -0.8 - Double(k) * 0.4
        }
    }
    /// 웹 doorTick(dt): 열린 문 닫기 · 두드리는 문(쿵! → 가끔 BAM! 하고 열림) · 새로 두드릴 문 고르기
    func doorTick(_ dt: Double) {
        guard let P = pr else { return }
        for wxc in P.doors.keys.sorted() {   // 웹 for..in: 정수 열쇠는 오름차순
            guard var D = P.doors[wxc] else { continue }
            D.t += dt; P.doors[wxc] = D
            if D.st == "open" && D.t > 1.8 { P.doors[wxc]!.st = "shut"; sfx("door", 0) }
            if D.st == "bang" {
                let n = Int((D.t / 0.5).rounded(.down))
                if n != D.n {
                    P.doors[wxc]!.n = n
                    if n < D.max { sfx("thud"); comicSFX(Double(wxc) - P.x, data.floorY - 96, "쿵!", force: true); fx("drop", Double(wxc) - P.x, data.floorY - 82) }
                    else if D.burst && foes().count < 7 { doorOpen(wxc, ["stick"]); shake(2); comicSFX(Double(wxc) - P.x, data.floorY - 96, "BAM!", force: true) }
                    else { P.doors[wxc]!.st = "shut" }
                }
            }
        }
        P.bangT = (P.bangT ?? 6) - dt
        if P.bangT! <= 0 {
            P.bangT = 9 + rnd() * 8
            let vis = visibleDoors().filter { doorAt($0).st == "shut" }
            if !vis.isEmpty {
                let w = vis[rndInt(vis.count)]
                var D = doorAt(w); D.st = "bang"; D.t = 0; D.n = -1; D.max = 3 + rndInt(3); D.burst = !P.bag && rnd() < 0.5   // 보스의 가방 쇼 동안엔 두드리기만
                P.doors[w] = D
            }
        }
    }
    /// 웹 corrLamps(): 화면 근처 전등(200마다 · 처음 보면 살짝 기운 채로) — 표현용 위치
    @discardableResult
    func corrLamps() -> [(wx: Int, ax: Double, x: Double, y: Double)] {
        guard let P = pr else { return [] }
        var out: [(Int, Double, Double, Double)] = []
        var wx = Int(((P.x - 80) / 200).rounded(.down)) * 200 + 60
        while Double(wx) < P.x + data.sbW + 80 {
            if P.lamps[wx] == nil { P.lamps[wx] = CorrLamp(a: (fxRnd() - 0.5) * 0.1) }
            let st = P.lamps[wx]!, ax = Double(wx) - P.x
            out.append((wx, ax, ax + sin(st.a) * sd.lampL, sd.lampTop + cos(st.a) * sd.lampL))
            wx += 200
        }
        return out
    }
    /// 웹 lampTick(dt): 진자 운동(감쇠 · 작은 떨림)
    func lampTick(_ dt: Double) {
        guard let P = pr else { return }
        for k in P.lamps.keys.sorted() {
            var st = P.lamps[k]!
            st.v += (-(9.8 * 60 / sd.lampL) * sin(st.a) - 0.55 * st.v) * dt + (fxRnd() - 0.5) * 0.25 * dt
            st.a += st.v * dt; P.lamps[k] = st
        }
    }
    /// 웹 lampKick(sx, str): 근처 충격 · 배관 울림에 전등이 흔들린다
    func lampKick(_ sx: Double, _ str: Double) {
        guard let P = pr else { return }
        for L in corrLamps() { let d = L.ax - sx; if abs(d) < 90 { P.lamps[L.wx]!.v += (d == 0 ? 1 : jsSign(d)) * str * (1 - abs(d) / 90) } }
    }

    // MARK: 복도 진행

    /// 웹 corridorUpdate(dt)
    func corridorUpdate(_ dt: Double) {
        guard let P = pr, let H = hero else { return }
        corrLamps()   // (웹은 그리기가 전등을 만든다)
        lampTick(dt)
        if H.anim != "hangkick" && H.airOv != 0 { H.airOv = 0 }
        if !P.out && !P.bag && H.wpn != "w_hammer" { H.wpn = "w_hammer" }
        if H.x > 230 && P.x < sd.corrLen {   // 카메라 트래킹: 세상이 뒤로 흐른다
            let d = min(H.x - 230, sd.corrLen - P.x); H.x -= d; P.x += d
            for a in ents where a !== H { a.x -= d }
        }
        if H.x < 24 { H.x = 24 }
        let CW = sd.corrWaves
        while P.wi < CW.count && P.x >= CW[P.wi].at && foes().count < 7 {
            let w = CW[P.wi]
            if w.sc != nil && (!P.bag || !foes().isEmpty) { break }
            if let sck = w.sc {
                bag = scBag(sck); renderBag(); P.scK = sck
                if let B = data.game.comboBook.first(where: { $0.id == sck }) { say(B.name, B.desc, 2.6) }
            }
            if w.side == 0 {
                let vis = visibleDoors()
                if !vis.isEmpty { doorOpen(vis[rndInt(vis.count)], w.list); P.wi += 1; continue }   // 문에서 등장(보이는 문이 없으면 앞쪽에서)
            }
            let before = Set(ents.map(ObjectIdentifier.init))
            spawnWave(w.list, fromDoors: false)
            for (k, a) in ents.filter({ !before.contains(ObjectIdentifier($0)) }).enumerated() {
                a.x = w.side < 0 ? -12 - Double(k) * 16 : data.sbW + 10 + Double(k) * 16; a.flip = w.side >= 0; a.e?.cdT = -1.2 - Double(k) * 0.5
                if let sck = w.sc { a.sc = sck }
            }
            P.wi += 1
        }
        doorTick(dt)
        if !P.bag && P.wi >= sd.corrVault && foes().isEmpty && P.x >= 700 { vaultOpen() }   // 금고실: 보스의 서류가방
        if P.bag && !P.out { scTick() }
        if P.wi >= CW.count && foes().isEmpty && P.x >= sd.corrLen - 1 && H.x > 392 && !P.out {   // 철문이 열린다
            P.out = true; P.outT = 0; sfx("door", 1); emit(.storyBeat("exit"))
        }
        if P.out {
            P.outT += dt
            let ox = H.x; H.x = min(H.x + 40 * dt, 446); H.gph += abs(H.x - ox) / (4 * 0.3 * 24)   // 웹 advGait(걷기)
            face(H, H.x + 10); if H.anim != "walk" { setAnim(H, "walk") }
            if P.outT > 1.3 && !cine { startCine() }
        }
    }
    /// 웹 vaultOpen(): 금고실 — 보스의 서류가방(낙뢰 콤보)
    func vaultOpen() {
        guard let P = pr, let H = hero else { return }
        P.bag = true; pBag = true; H.wpn = nil
        comicSFX(H.x + 6, H.y - 28, "클랭!", force: true); sfx("hitK", 3); shake(1.5)
        bag = scBag("thunder"); renderBag(); emit(.storyBeat("vault"))
        say("보스의 가방", "서류 한 장 한 장이, 보스가 내게 가르친 싸움이다.", 3.4)
    }
    /// 웹 scTick(): 콤보 쇼 — 평소 기술은 쉬고, 기회가 오면 슬로 + '탭!'(1.5초 안에 안 누르면 자동)
    func scTick() {
        guard let P = pr, let H = hero else { return }
        if croute == nil && !foes().contains(where: { $0.sc == nil && !$0.dead }) { for b in bag { b.t = 0 } }
        let SF = foes().filter { $0.sc != nil && !$0.dead && $0.anim != "death" }
        for a in SF { a.e!.cdT = min(a.e!.cdT, -3); a.e!.hp = max(a.e!.hp, 999) }   // 쇼 동안 적은 덤비지 않고, 콤보가 끝날 때 쓰러진다
        if croute != nil { P.scOpen = true }
        if P.scFired != 0 && croute == nil && tapW == nil {
            if P.scOpen && time - P.scFired > 0.35 { for a in SF { a.e!.hp = 1; var o = HitOpts(); o.knock = true; damage(H, a, 9, o) }; P.scFired = 0; P.scOpen = false }
            else if !P.scOpen && time - P.scFired > 2.4 { P.scFired = 0 }
            return
        }
        if tapW == nil && croute == nil && P.scFired == 0 && !SF.isEmpty && canAct(H) {
            guard let st = bag.first(where: { rules.role($0.id) == "S" }), let it = item(st.id) else { return }
            let T = stableSortD(SF) { abs($0.x - H.x) - abs($1.x - H.x) }[0], d = abs(T.x - H.x)
            if d <= (it.reach.map { max($0 + 4, 48) } ?? .nan) && d >= 8, let i = bag.firstIndex(where: { $0 === st }) {
                tapW = TapWindow(i: i, T: T); slowT = 1.6; emit(.tapWindow(open: true, just: false))   // 기회: 슬로 + 탭!
            }
        }
    }
    /// 웹 tapFire(just): '탭!' 응답(just) · 시간 초과(자동) — 닿지 않으면 파고들어 시작기를 쓴다
    func tapFire(_ just: Bool) {
        guard let W = tapW else { return }
        tapW = nil; slowT = 0; emit(.tapWindow(open: false, just: just))
        guard let H = hero, let T = W.T, !T.dead, bag.indices.contains(W.i) else { return }
        if H.anim == "walk" { setAnim(H, "idle") }
        face(H, T.x)
        if let it = item(bag[W.i].id) {
            let sg = jsSign(T.x - H.x) == 0 ? 1 : jsSign(T.x - H.x)
            if let rc = it.reach, abs(T.x - H.x) > rc - 2 && canAct(H) { H.x = T.x - sg * max(10, rc - 4); fx("fklines", H.x, H.y, H.f) }   // 파고들기
        }
        if canAct(H) { useSkill(W.i, T, just); pr?.scFired = time }
        if just { comicSFX(T.x, T.y - 62, "JUST!", force: true); shake(2.6); fx("tapok", T.x, T.y - 34) }
    }

    // MARK: 거리 연출(cine)

    /// 웹 startCine(): 철문 너머 비 내리는 거리(장면 brawl)
    func startCine() {
        guard let H = hero else { return }
        cn = CineRun(); scene = "brawl"; on = true
        for a in ents where a !== H { retire(a) }
        ents = [H]; H.hidden = false; H.x = sd.cine.start; H.y = sd.cine.y; H.z = 0; H.flip = false; H.wpn = pBag ? "w_case" : "w_hammer"
        setAnim(H, "walk"); items = []; cam = max(0, H.x - W / 2)
        setAnim(H, "run"); emit(.storyBeat("cine"))
        say("", "철문 너머는 바깥이었다.", 2.0)
    }
    /// 웹 cineUpdate(dt): 달리기 → (보스의 가방이 없으면) 장도리를 쓰레기통에 → 지하철 입구 계단
    func cineUpdate(_ dt: Double) {
        guard let C = cn, let H = hero else { return }
        C.t += dt; C.flash = max(0, C.flash - dt * 1.6)
        let K = sd.cine
        func runStep(_ v: Double) {
            let dx = v * dt; H.x += dx; H.gph += abs(dx) / 66; if H.anim != "run" { setAnim(H, "run") }
            C.stepT += dx; if C.stepT > 26 { C.stepT = 0; sfx("splash") }   // 발소리(첨벙)
        }
        if C.stage == 0 {
            runStep(K.spd)
            if pBag && !C.cap2 && H.x >= K.trash - 56 { C.cap2 = true; say("", "비. 보스의 가방을 끌어안고 뛰었다.", 2.2) }
            if !pBag && C.toss == nil && H.x >= K.trash - 56 { C.toss = (0, H.x + 10, H.y - 40); H.wpn = nil; emit(.storyBeat("toss")) }   // 지나치며 던진다
            if C.toss != nil {
                C.toss!.t += dt
                if C.toss!.t >= 0.42 && !C.hammerIn { C.hammerIn = true; sfx("hitK", 3); comicSFX(K.trash - cam, K.y - 50, "클랭!", force: true); say("", "비. 장도리는 쓰레기통에 버렸다.", 2.2) }
            }
            if H.x >= K.ent - 60 && !C.cap3 { C.cap3 = true; say("", "가장 가까운 지하철역 — 애틀랜틱 애비뉴.", 2.4) }
            if H.x >= K.ent - 6 { C.stage = 3; C.t3 = 0; emit(.storyBeat("stairs")) }
        } else if C.stage == 3 {   // 계단을 달려 내려가며 어두워진다
            C.t3 += dt; let dx = 70 * dt; H.x += dx; H.y += 46 * dt; H.gph += abs(dx) / 66
            C.fade = min(1, C.t3 / 0.9); if C.t3 > 1.05 { endCine(); return }
        }
        let tx = max(0, min(sd.nbw - W, H.x - W * 0.4)); cam += (tx - cam) * min(1, dt * 5)
    }
    /// 웹 endCine(): 지하철로 — 프롤로그 끝
    func endCine() {
        cn = nil; hero?.y = data.floorY; scene = "subway"; on = true; emit(.storyBeat("cineEnd"))
        endPrologue(); fade = 1
    }
    /// 거리 연출 넘기기(웹 무대 탭 · 스페이스: 0.6초 뒤부터)
    func cineSkip() { if let C = cn, C.t > 0.6 { endCine() } }
    /// 웹 endPrologue(): 첫 칸에 타고 — 보스의 가방을 들었으면 케인 장면, 아니면 시작 가방으로
    func endPrologue() {
        guard let H = hero else { return }
        H.wpn = nil; H.hidden = false; sfx("chime")
        schedule(after: 3.6) { w in if !w.hint("move") { w.hint("timer") }; w.emit(.runCheckpoint) }   // 웹 hint('move') || hint('timer'); saveRun()
        pr = nil; tr.phase = "stop"; tr.door = 1; tr.v = 0; doorWant = true
        enterCar(0); fade = 0; departT = 2.4; atStop = startStop; legT = 0
        if pBag { kaneStart() } else { restoreKit(); say(stage.name, stage.intro, 3) }
    }

    // MARK: 케인

    /// 웹 kaneStart(): 함께 탄 적은 장면 뒤에 태우고, 칸 반대편에서 케인이 걸어온다
    func kaneStart() {
        guard let H = hero else { return }
        let held = foes().map { $0.e!.t }
        let gone = ents.filter { $0.e != nil }; gone.forEach(retire); ents = ents.filter { $0.e == nil }
        let S = KaneRun(held: held); kn = S; departT = 999; H.wpn = "w_case"
        let before = Set(ents.map(ObjectIdentifier.init))
        spawnWave(["kane"], fromDoors: false)
        guard let K = ents.first(where: { !before.contains(ObjectIdentifier($0)) && $0.e != nil }) else { kn = nil; pBag = false; departT = 2.4; return }
        let side: Double = H.x > data.sbW / 2 ? -1 : 1
        K.kane = true; K.e!.hp = 9999; K.e!.max = 9999; K.e!.cdT = -99; K.x = side < 0 ? 110 : data.sbW - 110; K.wpn = "w_umb"; setAnim(K, "idle"); face(K, H.x)
        S.K = K; S.side = side; emit(.storyBeat("kane"))
    }
    /// 웹 kaneSlash(): 지팡이 칼 — 서류가 흩어진다(0.86초 뒤 시작 가방으로)
    func kaneSlash() {
        guard let H = hero else { return }
        sfx("swing"); shake(3.6); comicSFX(H.x + 12, H.y - 58, "슥!", force: true)
        fx("slash", H.x + 8, H.y - 34); fx("pages", H.x + 8, H.y - 32); H.wpn = nil
        emit(.storyBeat("bagScatter"))
        schedule(after: 0.86) { w in w.bag = (w.pKit ?? []).map(w.copyItem); w.renderBag() }   // 웹 bagScatter
    }
    /// 웹 kaneUpdate(dt)
    func kaneUpdate(_ dt: Double) {
        guard let S = kn, let H = hero else { return }
        S.t += dt
        guard let K = S.K else { kn = nil; return }
        let sd2 = S.side
        func gone() { retire(K); ents = ents.filter { $0 !== K }; S.ph = 6; S.t6 = S.t }
        if S.ph < 5 { face(H, K.x); K.e?.cdT = -99; if H.anim == "walk" { setAnim(H, "idle") } }
        if S.ph < 3 { face(K, H.x); let tx = H.x - sd2 * 58; if abs(K.x - tx) > 3 { moveTo(K, tx, 34, dt) } else if K.anim == "walk" { setAnim(K, "idle") } }   // 대사하며 천천히 다가온다
        if S.ph == 0 && S.t > 0.7 { S.ph = 1; comicSay(K, "가방은 두고 가라. 보스는 이미 종점에서 내렸어.") }
        if S.ph == 1 && S.t > 3.6 { S.ph = 2; comicSay(H, "그럼 나도 종점까지 간다.") }
        if S.ph == 2 && S.t > 6.2 { S.ph = 3; S.d0 = S.t }   // 지팡이 칼: 남은 거리를 한 번에
        if S.ph == 3 { face(K, H.x); K.x += (H.x - sd2 * 26 - K.x) * min(1, dt * 16); if S.t - S.d0 > 0.22 { S.ph = 4; kaneSlash() } }
        if S.ph == 4 && S.t > 8.0 { S.ph = 5; S.t5 = S.t; comicSay(K, "종점에서 기다리지.") }
        if S.ph == 5 && S.t > S.t5 + 1.2 {   // 가까운 연결 통로 문으로 사라진다
            if S.ex == nil { S.ex = K.x > data.sbW / 2 ? data.sbW + 60 : -60 }
            face(K, S.ex!); moveTo(K, S.ex!, 72, dt)
            if K.x <= 10 || K.x >= data.sbW - 10 || S.t - S.t5 > 5 { gone() }
        }
        if S.ph < 6 && S.t > 18 { gone() }   // 안전장치
        if S.ph == 6 && S.t > S.t6 + 0.5 { S.ph = 7; say("BAG BOSS · 막차", "남은 건 서류 \(bag.count)장. 막차는 기다려 주지 않는다.", 3.4) }
        if S.ph == 7 && S.t > S.t6 + 3.8 {
            kn = nil; pBag = false; H.wpn = nil; emit(.storyBeat("kaneEnd"))
            let held = S.held
            let go: (World, String?) -> Void = { w, _ in
                w.departT = 1.4; w.say(w.stage.name, w.stage.intro, 3)
                if !held.isEmpty {
                    w.spawnWave(held, fromDoors: true)
                    w.schedule(after: 3.2) { w2 in w2.say("적이 탔다!", held.map { w2.data.enemy($0)?.name ?? $0 }.joined(separator: " · "), 1.8) }
                }
            }
            if !meta.talks.contains("intro") { schedule(after: 0.4) { $0.talkOnce("intro", TalkScripts.lines("intro"), go) } } else { go(self, nil) }   // 막차의 동료들 첫 소개
        }
    }
}
