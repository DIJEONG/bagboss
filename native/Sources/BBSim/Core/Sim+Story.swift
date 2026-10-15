import Foundation
import BBCore

// K(프롤로그 · 스토리 · 무도장)의 바깥 계약 — 스냅숏 값 타입(SimAPI 에 '더하기만' 한 SimSnapshot 필드가 쓴다).
// 필드 이름은 웹 변수 이름을 그대로 따른다(GS.prologue · P.doors · P.lamps · GS.cine · GS.kane · GS.tapW · GS.talk · GS.dojoSeq · DJ · GS.skinPv).
// 규칙은 World+Prologue/Story/Dojo.swift. 여기는 읽기(fillStory)뿐이다.

/// 웹 GS.prologue(지하 복도) — 그리기(drawCorridor · corridorLights)가 읽는 값
public struct PrologueView: Sendable, Equatable {
    /// 복도 문(웹 P.doors[wxc]: st shut · open · bang, t 경과 초, n 두드린 횟수 · max) — sx = 화면 x(wxc - P.x)
    public struct Door: Sendable, Equatable { public var wxc: Int, sx: Double, st: String, t: Double, n: Int?, max: Int }
    /// 진자 전등(웹 corrLamps(): wx 세계 자리 · a 각도 · v 각속도 · ax 매단 점 화면 x · x/y 전구 화면 자리)
    public struct Lamp: Sendable, Equatable { public var wx: Int, a: Double, v: Double, ax: Double, x: Double, y: Double }
    /// 카메라 트래킹 거리(웹 P.x — 세상이 뒤로 흐른 양) · 다음 웨이브 번호(웹 P.wi)
    public var x = 0.0, wi = 0
    /// 보스의 가방을 열었나(웹 P.bag) · 끝 철문이 열렸나(웹 P.out) · 열린 뒤 초(웹 P.outT)
    public var bag = false, out = false, outT = 0.0
    /// 콤보 쇼 열쇠(웹 P.scK: thunder · bridge · signoff) · 쇼 콤보가 열렸나(scOpen) · 시작기를 쓴 시각(scFired)
    public var scK: String? = nil, scOpen = false, scFired = 0.0
    public var doors: [Door] = []
    public var lamps: [Lamp] = []
    /// 다음 두드림까지(웹 P.bangT)
    public var bangT = 6.0
    /// 복도 길이(웹 CORR_LEN) · 진행률(웹 HUD P.x/CORR_LEN) · 철문까지 m(웹 HUD round((CORR_LEN-P.x)/10)) · 끝 철문 화면 x(웹 drawCorridor ex = CORR_LEN+440-P.x)
    public var len = 1500.0, progress = 0.0, metersLeft = 150, exitX = 1940.0
    /// 전등 매다는 높이 · 줄 길이(웹 LAMP_TOP · LAMP_L)
    public var lampTop = 36.0, lampL = 62.0
    public init() {}
}
/// 웹 GS.cine(복도 → 비 내리는 거리 → 지하철 입구) — 장면 brawl(노아르 거리), 비 · 레터박스는 표현
public struct CineView: Sendable, Equatable {
    /// 경과 초 · 단계(0 달리기 · 3 계단) · 어두워짐(fade) · 첫 하얀 빛(flash) · 계단 초(t3)
    public var t = 0.0, stage = 0, fade = 0.0, flash = 1.0, t3 = 0.0
    /// 거리 카메라(웹 GS.cam · camOX = -round(cam))
    public var cam = 0.0, camOX = 0.0
    /// 장도리 던지기(웹 C.toss — 포물선은 drawCineProps 식) · 쓰레기통에 꽂힘
    public var tossT: Double? = nil, tossX0 = 0.0, tossY0 = 0.0, hammerIn = false
    /// 웹 CINE 상수(쓰레기통 · 지하철 입구 x · 바닥 y)
    public var trash = 560.0, ent = 1000.0, y = 222.0
    public init() {}
}
/// 웹 GS.kane(막차 안 빅터 케인 장면)
public struct KaneView: Sendable, Equatable {
    /// 경과 초 · 단계(0 다가옴 … 4 슥! · 5 퇴장 · 6 사라짐 · 7 자막)
    public var t = 0.0, ph = 0
    public var kane: ActorID? = nil
    /// 케인이 선 쪽(-1 왼쪽에서 · 1 오른쪽에서) · 장면 뒤에 태울 적(웹 S.held)
    public var side = 1.0
    public var held: [String] = []
    public init() {}
}
/// 웹 GS.tapW(콤보 쇼 '탭!' — 줄어드는 금색 고리: 웹 45-hud u = t/1.5, 반지름 30-20u)
public struct TapWindowView: Sendable, Equatable {
    public var t = 0.0, dur = 1.5, progress = 0.0
    public var target: ActorID? = nil
    /// 고리 자리(웹 W.T.d.x · W.T.d.y-34)
    public var x = 0.0, y = 0.0
    public var uid: Int? = nil
    public init() {}
}
/// 웹 GS.talk(대화 상자) — 글자 찍기 · 목소리(VOX) · 초상화는 표현
public struct TalkView: Sendable, Equatable {
    public var key = ""
    /// 지금 줄 번호 · 줄 수(고른 뒤 끼워 넣은 줄 포함)
    public var i = 0, count = 0
    /// 말하는 사람(웹 CAST 열쇠: cond · saboo · minnie · me) · 이름 · 색
    public var who = "cond", name = "", color = "#ffffff"
    /// 대사(<b>…</b> 강조 그대로 — 번역 키는 <b> 를 뺀 원문)
    public var text = ""
    /// 내 차례면 고를 것(웹 L[1].map(o=>o[0]))
    public var choices: [String]? = nil
    /// 뒤에 줄 선 대화 수(웹 GS.talkQ)
    public var queued = 0
    public init() {}
}
/// 마지막 도움말(웹 hint(k) → 0.4초 뒤 say('도움말 · '+제목, 본문, 4.2))
public struct HintView: Sendable, Equatable {
    public var key = "", title = "", body = ""
    public var age = 0.0, life = 4.2
    public init() {}
}
/// 무도장(웹 GS.demo · GS.dojoSeq · DJ · GS.cc)
public struct DojoView: Sendable, Equatable {
    /// 마지막 타격(웹 DJ.hit: me = 주인공이 맞음 · n 동작 이름 · r 반응)
    public struct Hit: Sendable, Equatable { public var me: Bool, n: String, dmg: Double, crit: Bool, air: Bool, r: String }
    /// 지나가는 행인(웹 DJ.walkers — 표현)
    public struct Walker: Sendable, Equatable { public var x: Double, v: Double, um: Bool, t: Double }
    /// 시연 진행(웹 GS.dojoSeq) — steps 는 'id' · 'id:콤보칸' · 'id:scoop' · '@strap'
    public struct Seq: Sendable, Equatable {
        public var name = "", steps: [String] = [], i = 0, t = 0.0, cur: Int? = nil
        public var custom = false, single = false
        /// 단계별 적중 수 · 공중 적중 · 최고 높이
        public var hits: [Int] = [], airs: [Bool] = [], maxH = 0.0
    }
    public var dummy: ActorID? = nil
    /// 허수아비 종류(웹 OPT.djDummy: punk · heavy · brute · boss4)
    public var dummyType = "punk"
    public var seq: Seq? = nil
    /// 마지막 결과 글(웹 #djRes) · 커스텀 결과(웹 GS.ccRes: hit · air · miss)
    public var result: String? = nil
    public var ccRes: [String]? = nil
    /// 커스텀 콤보 순서(웹 GS.cc)
    public var cc: [String] = []
    public var hit: Hit? = nil
    /// 기둥 튕기기 시연(웹 GS.dojoPole) · 반복(웹 DJ.rep) · 확대(웹 DJ.zoom) · 배경(웹 DJ.bg dojo · cross)
    public var pole = false, rep = false, zoom = 1.0, bg = "dojo"
    /// 08-art-dojo 소품: 간판 · 전등 2 · 샌드백 각도(웹 DJ.sign.a · DJ.lamps[].a · DJ.bag.a) · 목인장 · 북 떨림(초) · 깨진 송판 · 무기 걸이
    public var sign = 0.0, lamps: [Double] = [], bagA = 0.0, mook = 0.0, drum = 0.0, brd = false, rack = false
    public var walkers: [Walker] = []
    /// 부서지는 소품(네이티브): 번호 · 종류 · x · 깨짐 · 깨진 뒤 초 · 날아온 방향
    public struct Obj: Sendable, Equatable { public var id: Int, kind: String, x: Double, broken: Bool, age: Double, dir: Double }
    public var objs: [Obj] = []
    /// 치명타 켜짐(네이티브 무도장 — 패널 '치명' 켜기 · 끄기)
    public var crit = true
    public init() {}
}
/// 웹 GS.skinPv(스킨 미리보기 · 자세 편집기 — 배경 없이 스튜디오)
public struct SkinPreviewView: Sendable, Equatable {
    /// 경과 초 · 단계(0 서기 · 1 걷기 · 2 몸짓 · 3 돌기 · 4 돌려차기) · 돌기(바퀴, 웹 P.spin) · 보기 회전(도, 웹 V.view)
    public var t = 0.0, ph = -1, spin = 0.0, view = 0.0
    public var cx = 240.0
    public var fixed: String? = nil, play: String? = nil
    public var z1 = false
    public init() {}
}

extension World {
    /// 스냅숏 K 칸 채우기(Sim.snapshot 끝에서 부른다)
    func fillStory(_ s: inout SimSnapshot) {
        s.scene = scene; s.cam = cam; s.camC = camC
        if pr != nil || kn != nil || demo {
            for i in s.actors.indices { if let a = ents.first(where: { $0.id == s.actors[i].id }) { s.actors[i].sc = a.sc; s.actors[i].kane = a.kane; s.actors[i].dojo = a.dojo } }
        }
        s.pBag = pBag; s.pKit = pKit?.map(\.bagItem); s.demo = demo
        if let P = pr {
            var v = PrologueView()
            v.x = P.x; v.wi = P.wi; v.bag = P.bag; v.out = P.out; v.outT = P.outT; v.scK = P.scK; v.scOpen = P.scOpen; v.scFired = P.scFired
            v.doors = P.doors.keys.sorted().map { k in let D = P.doors[k]!; return .init(wxc: k, sx: Double(k) - P.x, st: D.st, t: D.t, n: D.n, max: D.max) }
            v.lamps = P.lamps.keys.sorted().map { k in
                let L = P.lamps[k]!, ax = Double(k) - P.x
                return .init(wx: k, a: L.a, v: L.v, ax: ax, x: ax + sin(L.a) * sd.lampL, y: sd.lampTop + cos(L.a) * sd.lampL)
            }
            v.bangT = P.bangT ?? 6; v.len = sd.corrLen; v.progress = min(1, P.x / sd.corrLen)
            v.metersLeft = max(0, jsRoundI((sd.corrLen - P.x) / 10)); v.exitX = sd.corrLen + 440 - P.x
            v.lampTop = sd.lampTop; v.lampL = sd.lampL
            s.prologue = v
        }
        if let C = cn {
            var v = CineView()
            v.t = C.t; v.stage = C.stage; v.fade = C.fade; v.flash = C.flash; v.t3 = C.t3; v.cam = cam; v.camOX = -jsRound(cam)
            if let T = C.toss { v.tossT = T.t; v.tossX0 = T.x0; v.tossY0 = T.y0 }
            v.hammerIn = C.hammerIn; v.trash = sd.cine.trash; v.ent = sd.cine.ent; v.y = sd.cine.y
            s.cine = v
        }
        if let K = kn { var v = KaneView(); v.t = K.t; v.ph = K.ph; v.kane = K.K?.id; v.side = K.side; v.held = K.held; s.kane = v }
        if let W = tapW {
            var v = TapWindowView(); v.t = W.t; v.progress = min(1, W.t / 1.5); v.target = W.T?.id
            v.x = W.T?.x ?? 0; v.y = (W.T?.y ?? 0) - 34; v.uid = bag.indices.contains(W.i) ? bag[W.i].uid : nil
            s.tapWindow = v
        }
        if let T = talkRun, T.i >= 0, T.i < T.lines.count {
            var v = TalkView(); v.key = T.key; v.i = T.i; v.count = T.lines.count; v.queued = talkQ.count
            switch T.lines[T.i] {
            case .say(let who, let text): v.who = who; v.text = text
            case .choose(let c): v.who = "me"; v.choices = c.map(\.text)
            }
            let C = sd.cast[v.who] ?? sd.cast["cond"]; v.name = C?.n ?? v.who; v.color = C?.c ?? "#ffffff"
            s.talk = v
        }
        if let h = lastHint, let t = sd.hints[h.key], realTime - h.at < 4.2 {
            var v = HintView(); v.key = h.key; v.title = t.0; v.body = t.1; v.age = realTime - h.at; s.hint = v
        }
        if let S = dj, demo {
            var v = DojoView()
            v.dummy = dojoDummy()?.id; v.dummyType = S.dummyType; v.result = S.result; v.ccRes = S.ccRes; v.cc = S.cc; v.hit = S.hit
            v.pole = S.pole; v.rep = S.rep; v.zoom = S.zoom; v.bg = S.bg; v.crit = S.crit
            v.sign = S.sign.a; v.lamps = S.lamps.map(\.a); v.bagA = S.bagS.a; v.mook = S.mook; v.drum = S.drum; v.brd = S.brd; v.rack = S.rack; v.walkers = S.walkers
            v.objs = S.objs.map { .init(id: $0.id, kind: $0.kind, x: $0.x, broken: $0.broken, age: $0.age, dir: $0.dir) }
            if let Q = S.seq {
                var q = DojoView.Seq(); q.name = Q.name; q.i = Q.i; q.t = Q.t; q.cur = Q.cur; q.custom = Q.custom; q.single = Q.single; q.maxH = Q.maxH
                q.steps = Q.steps.map { $0.scoop ? "\($0.id):scoop" : $0.combo != nil ? "\($0.id):\($0.combo!)" : $0.id }
                q.hits = Q.steps.indices.map { Q.hits[$0] ?? 0 }; q.airs = Q.steps.indices.map { Q.airs.contains($0) }
                v.seq = q
            }
            s.dojo = v
        }
        if let P = skinPv { var v = SkinPreviewView(); v.t = P.t; v.ph = P.ph; v.spin = P.spin; v.view = P.view; v.cx = P.cx; v.fixed = P.fixed; v.play = P.play; v.z1 = P.z1; s.skinPv = v }
    }
}
