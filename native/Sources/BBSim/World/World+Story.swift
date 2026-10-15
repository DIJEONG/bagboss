import Foundation
import BBCore
import BBContent

// 웹 44-story.js: 막차의 동료들(CAST) · 대화 대본(TALK) · 대화 흐름(talk · tkNext · tkPick · tkSkip · tkEnd · talkOnce · talkSoon · talkSafe · talkTick)
// + 41-hints-save.js 도움말(HINTS · hint 는 World.swift) + 프롤로그 정적 값 묶음(StoryData — 39 · 42 · 44 · 08 의 상수).
// 글자 찍기(타자) · 목소리(blip) · 초상화는 표현 몫 — 시뮬레이션은 '지금 몇 번째 줄 · 누가 · 무슨 말 · 고를 것'만 들고,
// 대화가 떠 있는 동안 판을 멈춘다(웹 gameUpdate 의 `if(GS.talk) return`). 표현이 SimIntent.talkNext / talkPick / talkDone 으로 넘긴다.

/// 대화 한 줄(웹 TALK 배열 원소): 동료가 말한다 [who, html] · 내가 고른다 ['me', [[text, insert, picked]]]
public enum TalkLine: Sendable, Equatable {
    case say(who: String, text: String)
    case choose([TalkChoice])
}
/// 고르기 하나(웹 [text, insert?, picked?]) — insert 는 고른 뒤 바로 다음에 끼워 넣는 줄
public struct TalkChoice: Sendable, Equatable {
    public var text: String
    public var insert: TalkLine?
    public var picked: String?
    public init(_ text: String, _ insert: TalkLine? = nil, picked: String? = nil) { self.text = text; self.insert = insert; self.picked = picked }
}

/// 진행 중 대화(웹 GS.talk = { lines, i, done, picked, choices })
final class TalkRun {
    let key: String
    var lines: [TalkLine]
    var i = -1
    var picked: String?
    var choices: [TalkChoice]?
    let done: ((World, String?) -> Void)?
    init(key: String, lines: [TalkLine], done: ((World, String?) -> Void)?) { self.key = key; self.lines = lines; self.done = done }
}

/// 웹 TALK 대본(44-story.js 원문 그대로 — <b> 는 강조 표시). storytrace.mjs --fx 가 웹 TALK 를 실행해 Fixtures/sim/story_fx.json 에 남기고 StoryFixtureTests 가 대조한다.
public enum TalkScripts {
    static func L(_ who: String, _ t: String) -> TalkLine { .say(who: who, text: t) }
    static func me(_ c: [TalkChoice]) -> TalkLine { .choose(c) }
    /// 열쇠 → 대본(book 은 도감 콤보 이름을 넣는다)
    public static func lines(_ key: String, bookName: String? = nil) -> [TalkLine]? {
        switch key {
        case "intro": return [
            L("cond", "막차에 오신 걸 환영해요. 이 열차는 <b>종점</b>까지 가요. 서는 역은 몇 안 되고요."),
            L("minnie", "호외요, 호외! <b>보스의 가방</b>이 막차에서 터졌대요! …손님 거죠, 그 가방?"),
            me([TalkChoice("…짧게.", L("minnie", "네네! 서류가 <b>칸마다</b> 흩어졌어요. 싸워서 줍거나, 매점에서 되사면 돼요!")),
                TalkChoice("그래서?", L("saboo", "그래서 제가 있죠. 흩어진 서류 <b>주워 오는 게 제 전문</b>이에요. 값만 맞으면."))]),
            L("saboo", "저는 사보. 매점에서 뵙죠. 금니는 덤이고요."),
            L("cond", "정리하면 — <b>붙어 있는 서류는 순서대로 이어져요.</b> 시작기 ▶가 맞으면, 경로를 따라 콤보가 나가요.")]
        case "fork": return [
            L("cond", "갈림길이네요. 서류가 상황에 따라 <b>다른 쪽으로 갈라질</b> 수 있어요."),
            me([TalkChoice("한쪽으로만 가게 해.", L("cond", "블록을 누르면 <b>갈림</b> 단추가 나와요. 누르면 그쪽으로 고정, 다시 누르면 풀려요.")),
                TalkChoice("알아서 가겠지.", L("cond", "그럼 열차가 알아서 갑니다. 적이 떠 있으면 위로, 쓰러져 있으면 아래로요."))]),
            L("cond", "정리하면 — 갈림길은 <b>상황</b>이 고르고, 고정은 <b>손님</b>이 골라요.")]
        case "st", "starter": return [
            L("cond", "<b>시작기 ▶</b>를 얻으셨네요. 이게 맞으면 <b>콤보 창</b>이 열려요."),
            L("saboo", "▶ 한 장이면 서류 석 장 값은 하죠. 파실 생각 있으시면…"),
            me([TalkChoice("안 팔아.", L("saboo", "네네, 농담이에요. 반쯤은.")), TalkChoice("어디에 둬?", L("cond", "옆에 이음기 ●나 마무리기 ■를 붙이세요. 붙은 순서대로 이어져요."))]),
            L("cond", "정리하면 — ▶ 옆에 ●·■를 붙이면 <b>새 콤보 경로</b>가 생겨요.")]
        case "fin", "finisher": return [
            L("minnie", "<b>마무리기 ■</b>다! 마무리가 들어가면 무조건 1면이에요!"),
            me([TalkChoice("1면은 관심 없어.", L("minnie", "에이, 그래도 박수는 받잖아요!")), TalkChoice("어디에 둬?", L("cond", "경로 <b>끝</b>에요. 집어 들면 <b>금색 칸</b>이 추천 자리예요."))]),
            L("cond", "정리하면 — ■는 경로를 <b>완성</b>해요. 집으면 금색 칸을 보세요.")]
        case "shop": return [
            L("saboo", "어서 오세요. 오늘 밤 주운 서류들이에요. <b>하나만</b> 고르실 수 있어요."),
            me([TalkChoice("비싸군.", L("saboo", "토큰 2개면 <b>목록을 새로</b> 뽑아 드리죠. 제 전문이에요.")), TalkChoice("뭐가 좋지?", L("saboo", "카드 아래 <b>금색 줄</b>을 보세요. 손님 콤보가 어떻게 바뀌는지 적어 놨어요."))]),
            L("cond", "정리하면 — 고른 서류는 <b>보류함</b>으로 가요. 가방에 끌어 넣으면 경로가 이어져요.")]
        case "book", "book1": return [
            L("minnie", "호외요! <b>\(bookName ?? "")</b>, 콤보 도감 첫 완성이에요!"),
            me([TalkChoice("…그래서?", L("minnie", "열 개를 다 채우면 — <b>1면 통째로</b> 손님 거예요!")), TalkChoice("다음은?", L("minnie", "도감에 아직 흐린 콤보가 아홉 개나 남았어요!"))]),
            L("cond", "정리하면 — 도감은 <b>실전에서 성공한 콤보</b>만 채워져요.")]
        default: return nil
        }
    }
    /// 웹 talkSoon 열쇠 → TALK 이름(fin → finisher · st → starter · book1 → book)
    public static let soonKeys: [String: String] = ["intro": "intro", "fork": "fork", "st": "starter", "fin": "finisher", "shop": "shop", "book1": "book"]
}

/// 웹 CAST(동료 이름 · 색)
public struct CastMember: Sendable, Equatable { public var n: String, c: String }

/// 프롤로그 · 대화 · 무도장 정적 값(웹 상수 — 추출기가 구운 content 에서 읽는다)
struct StoryData {
    // 39 prologue
    var corrLen = 1500.0, corrVault = 6
    var corrWaves: [(at: Double, list: [String], side: Int, sc: String?)] = []
    var lampTop = 36.0, lampL = 62.0, crPipeY = 130.0
    var cine: (start: Double, trash: Double, ent: Double, y: Double, spd: Double) = (160, 560, 1000, 222, 150)
    var nbw = 1920.0, nfloor = 196.0
    // 44 story
    var scBag: [String: [(id: String, x: Int, y: Int)]] = [:]
    var cast: [String: CastMember] = [:]
    // 41 hints
    var hints: [String: (String, String)] = [:]
    // 42 dojo · 08 art-dojo
    var dojoHero: [(n: String, id: String, combo: Int?)] = [], dojoMisc: [(String, String)] = [], dojoSpc: [(String, String)] = []
    var dojoReact: [(String, String)] = [], dojoFoe: [(String, String)] = [], dojoMoves: [(String, String)] = []
    var dojoCombo: [(name: String, steps: [DojoStep])] = []
    var djDummy: [(String, String)] = []
    var demoBags: [(n: String, L: [(id: String, x: Int, y: Int, rot: Int)])] = []
    var ccMax = 8
    var djPoles: [Double] = [96, 384]
    var djProps: [(id: String, x: Double, hw: Double, top: Double)] = []

    init(_ data: SimData) {
        let s = data.store
        func raw(_ k: String) -> JSONValue? { try? s.raw(k) }
        corrLen = raw("CORR_LEN")?.double ?? 1500
        corrVault = raw("CORR_VAULT")?.int ?? 6
        corrWaves = (raw("CORR_WAVES")?.array ?? []).compactMap { v in
            guard let a = v.array, a.count >= 3 else { return nil }
            return (a[0].double ?? 0, (a[1].array ?? []).compactMap(\.string), a[2].int ?? 1, a.count > 3 ? a[3].string : nil)
        }
        lampTop = raw("LAMP_TOP")?.double ?? 36; lampL = raw("LAMP_L")?.double ?? 62; crPipeY = raw("CR_PIPE_Y")?.double ?? 130
        if let c = raw("CINE")?.object { cine = (c["start"]?.double ?? 160, c["trash"]?.double ?? 560, c["ent"]?.double ?? 1000, c["y"]?.double ?? 222, c["spd"]?.double ?? 150) }
        nbw = raw("NBW")?.double ?? 1920; nfloor = raw("NFLOOR")?.double ?? 196
        for (k, v) in raw("SC_BAG")?.object ?? [:] {
            scBag[k] = (v.array ?? []).compactMap { e in guard let a = e.array, a.count >= 3, let id = a[0].string else { return nil }; return (id, a[1].int ?? 0, a[2].int ?? 0) }
        }
        for (k, v) in raw("CAST")?.object ?? [:] { cast[k] = CastMember(n: v.object?["n"]?.string ?? k, c: v.object?["c"]?.string ?? "#ffffff") }
        for (k, v) in raw("HINTS")?.object ?? [:] { if let a = v.array, a.count >= 2 { hints[k] = (a[0].string ?? "", a[1].string ?? "") } }
        if let D = raw("DOJO")?.object {
            func pairs(_ k: String) -> [(String, String)] { (D[k]?.array ?? []).compactMap { e in guard let a = e.array, a.count >= 2 else { return nil }; return (a[0].string ?? "", a[1].string ?? "") } }
            dojoHero = (D["hero"]?.array ?? []).compactMap { e in guard let a = e.array, a.count >= 2 else { return nil }; return (a[0].string ?? "", a[1].string ?? "", a.count > 2 ? a[2].int : nil) }
            dojoMisc = pairs("misc"); dojoSpc = pairs("spc"); dojoReact = pairs("react"); dojoFoe = pairs("foe"); dojoMoves = pairs("moves")
            dojoCombo = (D["combo"]?.array ?? []).compactMap { e in
                guard let a = e.array, a.count >= 2 else { return nil }
                return (a[0].string ?? "", (a[1].array ?? []).compactMap(DojoStep.init(json:)))
            }
        }
        djDummy = (raw("DJ_DUMMY")?.array ?? []).compactMap { e in guard let a = e.array, a.count >= 2 else { return nil }; return (a[0].string ?? "", a[1].string ?? "") }
        demoBags = (raw("DEMO_BAGS")?.array ?? []).compactMap { e in
            guard let o = e.object else { return nil }
            return (o["n"]?.string ?? "", (o["L"]?.array ?? []).compactMap { q in guard let a = q.array, a.count >= 3, let id = a[0].string else { return nil }; return (id, a[1].int ?? 0, a[2].int ?? 0, a.count > 3 ? a[3].int ?? 0 : 0) })
        }
        ccMax = raw("CC_MAX")?.int ?? 8
        if data.nativeMoves {   // 네이티브 동작 개편: 새 기술 · 도감 콤보 · 예시 가방을 웹 목록 뒤에(인덱스는 앱 패널과 같은 순서)
            dojoHero += NativeContent.dojoHero.map { ($0.name, $0.id, nil) }
            dojoMoves += NativeContent.dojoMoves.map { ($0.name, $0.value) }
            dojoCombo += NativeContent.dojoCombos
            demoBags += NativeContent.demoBags
            dojoSpc = dojoSpc.map { $0.1 == "fist" ? (NativeContent.dojoSpcFist, $0.1) : $0 }
            djDummy += NativeContent.dojoDummies.filter { d in !djDummy.contains { $0.0 == d.key } }.map { ($0.key, $0.name) }
            ccMax = max(ccMax, NativeContent.dojoCCMax)   // 커스텀 콤보 16단(깃발 꺼지면 웹 CC_MAX 8 그대로)
        }
        djPoles = (raw("DJ_POLES")?.array ?? []).compactMap(\.double)
        if djPoles.isEmpty { djPoles = [96, 384] }
        djProps = (raw("DJ_PROPS")?.array ?? []).compactMap { e in guard let o = e.object, let id = o["id"]?.string else { return nil }; return (id, o["x"]?.double ?? 0, o["hw"]?.double ?? 0, o["top"]?.double ?? 0) }
    }
}

extension World {
    // MARK: 대화(웹 talk · tkNext · tkPick · tkSkip · tkEnd)

    /// 웹 talk(lines, done): 대화 중이면 줄을 선다
    func talk(_ key: String, _ lines: [TalkLine], _ done: ((World, String?) -> Void)?) {
        let T = TalkRun(key: key, lines: lines, done: done)
        if talkRun != nil { talkQ.append(T); return }
        talkRun = T; emit(.talk(key: key)); tkNext()
    }
    /// 웹 tkNext: 다음 줄(내 차례면 고를 것을 띄우고 멈춘다) · 끝이면 tkEnd
    func tkNext() {
        guard let T = talkRun else { return }
        T.i += 1
        if T.i >= T.lines.count { tkEnd(); return }
        if case .choose(let c) = T.lines[T.i] { T.choices = c; return }
        T.choices = nil
    }
    /// 웹 tkPick(k): 고른 것 다음에 끼워 넣을 줄 · 고른 값
    func tkPick(_ k: Int) {
        guard let T = talkRun, let C = T.choices, C.indices.contains(k) else { return }
        let o = C[k]
        if let ins = o.insert { T.lines.insert(ins, at: T.i + 1) }
        if let p = o.picked { T.picked = p }
        T.choices = nil; tkNext()
    }
    /// 대화 상자 탭(웹 click: 고를 것이 떠 있으면 무시 · 아니면 다음 줄 — 타자 마무리는 표현 몫)
    func tkTap() { guard let T = talkRun, T.choices == nil else { return }; tkNext() }
    /// 웹 tkSkip: 건너뛰기(남은 줄의 부수 효과는 웹 TALK 에 없다) → tkEnd
    func tkSkip() { if talkRun != nil { tkEnd() } }
    /// 웹 tkEnd: done(picked) · 줄 선 다음 대화
    func tkEnd() {
        guard let T = talkRun else { return }
        talkRun = nil
        emit(.talkEnded(key: T.key, picked: T.picked))
        T.done?(self, T.picked)
        if !talkQ.isEmpty, talkRun == nil { let q = talkQ.removeFirst(); talkRun = q; emit(.talk(key: q.key)); tkNext() }
    }
    var talkActive: Bool { talkRun != nil }

    // MARK: 한 번만(웹 talkOnce · talkSoon · talkSafe · talkTick)

    /// 웹 talkOnce(key, lines, done): 이미 했거나 건너뛰기(웹 자동 점검 환경)면 done 만
    func talkOnce(_ key: String, _ lines: [TalkLine]?, _ done: ((World, String?) -> Void)? = nil) {
        if meta.talks.contains(key) || config.skipTalks || lines == nil { done?(self, nil); return }
        meta.talks.insert(key); emit(.metaChanged)
        talk(key, lines!, done)
    }
    /// 웹 talkSoon(key, fn): 싸움이 멈춘 틈에(같은 열쇠는 한 번만 줄 선다)
    func talkSoon(_ key: String, _ arg: String? = nil) {
        if meta.talks.contains(key) || talkQueue.contains(where: { $0.key == key }) { return }
        talkQueue.append((key, arg))
    }
    /// 웹 talkSafe(): 지금 대화를 띄워도 되나(매점 · 정리 화면 = 웹 gOverlay 가 떠 있음)
    func talkSafe() -> Bool {
        on && !tower && !prologue && !cine && !kane && spc == nil && croute == nil && !bonus && !demo && tapW == nil && foes().isEmpty
            && !["shop", "over"].contains(state)   // 웹 gOverlay(매점 · 결과)가 떠 있으면 안 된다 — 정리(sbArrange)는 무대 위라 괜찮다
    }
    /// 웹 talkTick(): 줄 선 대화 하나
    func talkTick() {
        if talkRun != nil || talkQueue.isEmpty || !talkSafe() { return }
        let q = talkQueue.removeFirst()
        talkOnce(q.key, talkLines(q.key, q.arg))
    }
    /// 열쇠 → 대본(book1 은 도감 콤보 이름)
    func talkLines(_ key: String, _ arg: String?) -> [TalkLine]? {
        let name = arg.flatMap { id in data.game.comboBook.first { $0.id == id }?.name }
        return TalkScripts.lines(TalkScripts.soonKeys[key] ?? key, bookName: name)
    }
    /// 웹 routeHintMaybe(): 프롤로그를 건너뛴 판 — 싸움이 멈춘 틈에 첫 소개
    func routeHintMaybe() { if demo || tower || prologue || kane || cine { return }; talkSoon("intro") }

    /// 웹 renderRoutes 의 갈림길 세기(nf) → talkSoon('fork') — 가방이 바뀔 때(renderBag) 부른다
    func forkCheck() {
        if pBag || meta.talks.contains("fork") || talkQueue.contains(where: { $0.key == "fork" }) { return }
        let bs = bagStructs(), R = rules.routes(bs)
        var nf = 0
        for r in R {
            let inR = Set(r.uids)
            let items = r.uids.compactMap { u in bs.first { $0.uid == u } }
            for (k, cur) in items.enumerated() {
                if k == items.count - 1 && rules.role(cur.id) == "F" { continue }
                if k >= 5 { continue }
                for o in rules.adjacentIn(bs, cur) {
                    if inR.contains(o.uid) || !rules.isSkill(o) || rules.role(o.id) == "X" || (rules.role(o.id) == "S" && rules.stateIn(o.id) != "*") { continue }
                    if nf >= 4 { break }
                    nf += 1
                }
            }
        }
        if nf > 0 { talkSoon("fork") }
    }
}
