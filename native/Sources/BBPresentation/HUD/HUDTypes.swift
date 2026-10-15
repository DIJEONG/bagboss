import Foundation

// HUD 그리기 입력(웹 이름 그대로 — 픽스처 JSON 이 바로 풀린다).
//   HitFx  = 웹 HITFX 한 칸(k 별로 쓰는 필드가 다르다)
//   HUDFrame = 그 프레임에 drawUI 가 GS · CAMX · VW … 에서 읽는 값(스냅숏 · 카메라에서 만든다)

/// 웹 HITFX 한 칸
public struct HitFx: Sendable, Equatable, Codable {
    public struct Puff: Sendable, Equatable, Codable { public var dx = 0.0, dy = 0.0, r = 0.0, vy = 0.0, vx = 0.0; public init(dx: Double = 0, dy: Double = 0, r: Double = 0, vy: Double = 0, vx: Double = 0) { self.dx = dx; self.dy = dy; self.r = r; self.vy = vy; self.vx = vx } }
    public struct GPuff: Sendable, Equatable, Codable { public var dx = 0.0, vx = 0.0, rise = 0.0, r = 0.0, d = 0.0; public init(dx: Double, vx: Double, rise: Double, r: Double, d: Double) { self.dx = dx; self.vx = vx; self.rise = rise; self.r = r; self.d = d } }
    /// twfall · debris(vx · vy · s · c) · xcspark(a · l)
    public struct Part: Sendable, Equatable, Codable { public var vx: Double?, vy: Double?, s: Double?, c: String?, a: Double?, l: Double?; public init(vx: Double? = nil, vy: Double? = nil, s: Double? = nil, c: String? = nil, a: Double? = nil, l: Double? = nil) { self.vx = vx; self.vy = vy; self.s = s; self.c = c; self.a = a; self.l = l } }
    public struct Crack: Sendable, Equatable, Codable { public var sd = 1.0, a = 0.0, n = 3; public init(sd: Double, a: Double, n: Int) { self.sd = sd; self.a = a; self.n = n } }
    /// pages(vx · vy · r · vr · ph) · sk_glint(a · v · s)
    public struct Bit: Sendable, Equatable, Codable { public var vx: Double?, vy: Double?, r: Double?, vr: Double?, ph: Double?, a: Double?, v: Double?, s: Double? }

    public var k: String
    public var x = 0.0, y = 0.0
    public var t = 0.0, life = 0.2
    public var vx: Double?, vy: Double?
    public var col: String?, a: Double?
    public var big: Bool?, red: Bool?
    public var f: Double?
    public var n: Int?
    public var r0: Double?, r1: Double?, r: Double?, w: Double?
    public var kind: String?, ph: Double?
    public var y0: Double?, y1: Double?, s: Double?, c: String?, text: String?
    public var a0: Double?, a1: Double?
    public var steam: Bool?
    public var b: [Puff]?, puffs: [GPuff]?, parts: [Part]?, cr: [Crack]?, pts: [[Double]]?, P: [Bit]?
    public init(k: String, x: Double, y: Double, life: Double) { self.k = k; self.x = x; self.y = y; self.life = life }
    enum CodingKeys: String, CodingKey { case k, x, y, t, life, vx, vy, col, a, big, red, f, n, r0, r1, r, w, kind, ph, y0, y1, s, c, text, a0, a1, steam, b, puffs, parts, cr, pts, P }
    /// 웹 칸은 종류마다 필드가 다르다 — 없는 값은 기본값(axv 는 y 가 없다 등)
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        k = try c.decode(String.self, forKey: .k)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0; y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        t = try c.decodeIfPresent(Double.self, forKey: .t) ?? 0; life = try c.decodeIfPresent(Double.self, forKey: .life) ?? 0.2
        vx = try c.decodeIfPresent(Double.self, forKey: .vx); vy = try c.decodeIfPresent(Double.self, forKey: .vy)
        col = try c.decodeIfPresent(String.self, forKey: .col); a = try c.decodeIfPresent(Double.self, forKey: .a)
        big = try c.decodeIfPresent(Bool.self, forKey: .big); red = try c.decodeIfPresent(Bool.self, forKey: .red)
        f = try c.decodeIfPresent(Double.self, forKey: .f); n = try c.decodeIfPresent(Int.self, forKey: .n)
        r0 = try c.decodeIfPresent(Double.self, forKey: .r0); r1 = try c.decodeIfPresent(Double.self, forKey: .r1)
        r = try c.decodeIfPresent(Double.self, forKey: .r); w = try c.decodeIfPresent(Double.self, forKey: .w)
        kind = try c.decodeIfPresent(String.self, forKey: .kind); ph = try c.decodeIfPresent(Double.self, forKey: .ph)
        y0 = try c.decodeIfPresent(Double.self, forKey: .y0); y1 = try c.decodeIfPresent(Double.self, forKey: .y1)
        s = try c.decodeIfPresent(Double.self, forKey: .s); self.c = try c.decodeIfPresent(String.self, forKey: .c)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        a0 = try c.decodeIfPresent(Double.self, forKey: .a0); a1 = try c.decodeIfPresent(Double.self, forKey: .a1)
        steam = try c.decodeIfPresent(Bool.self, forKey: .steam)
        b = try c.decodeIfPresent([Puff].self, forKey: .b); puffs = try c.decodeIfPresent([GPuff].self, forKey: .puffs)
        parts = try c.decodeIfPresent([Part].self, forKey: .parts); cr = try c.decodeIfPresent([Crack].self, forKey: .cr)
        pts = try c.decodeIfPresent([[Double]].self, forKey: .pts); P = try c.decodeIfPresent([Bit].self, forKey: .P)
    }
}

/// 웹 GS.critFx 한 칸(치명타 X 자 섬광)
public struct CritFx: Sendable, Equatable, Codable {
    public var x: Double, y: Double, t = 0.0, big = false, f = 1.0
    public init(x: Double, y: Double, t: Double = 0, big: Bool = false, f: Double = 1) { self.x = x; self.y = y; self.t = t; self.big = big; self.f = f }
}

/// 웹 GS.sw 한 칸(투명 충격파 — 후처리 uSW) · GS.smear(방향 번짐)
public struct Shockwave: Sendable, Equatable, Codable {
    public var x: Double, y: Double, t0: Double, life: Double, r0: Double, r1: Double, w: Double, amp: Double, dark: Double
}
public struct Smear: Sendable, Equatable, Codable { public var x: Double, y: Double, f: Double, t0: Double, life: Double, R: Double }

/// 웹 GS.cut(컷인) — t 는 진행 초
public struct CutView: Sendable, Equatable, Codable {
    public var k: String
    public var kind: String?
    /// 두목 종류(vs · rage)
    public var boss: String?
    public var t: Double, dur: Double
    public init(k: String, kind: String? = nil, boss: String? = nil, t: Double, dur: Double) { self.k = k; self.kind = kind; self.boss = boss; self.t = t; self.dur = dur }
}

/// 네이티브 퇴근 승천권 지붕 뚫기 구멍(칸 · 층이 바뀔 때까지 남는다). 좌표 = 무대 픽셀(천장 선 y).
/// 그림은 오버레이가 아니라 무대 G-버퍼(NativeRiseArt — 카메라 · 조명 · 팔레트 · 디더를 무대와 함께 받는다)
public struct RoofHole: Sendable, Equatable, Codable {
    public var x: Double, y: Double
    /// car · hatch · tile
    public var kind: String
    public var f = 1.0, age = 0.0
    /// 모양 씨앗(들쭉날쭉한 가장자리 · 젖혀진 철판 · 파편 — 같은 씨앗이면 같은 구멍)
    public var seed: UInt64 = 0
    /// 뚫고 나간 적(지붕 뒤로 밀어 그린다 — 앞 입술이 몸을 가린다)
    public var target: Int?
    /// 세울 때 천장 선 기준(객차 흔들림 dy · 복도 스크롤 x) — 그릴 때 지금 값과의 차만큼 따라 움직인다
    public var dy0 = 0.0, scroll0 = 0.0
    /// 세운 곳(노선 · 칸 · 타워 층) — 바뀌면 지운다
    public var stage = 0, car = 0, floor = -1
    /// '…쿵' 뒤 흐른 초(없으면 nil)
    public var thud: Double?
    public init(x: Double, y: Double, kind: String) { self.x = x; self.y = y; self.kind = kind }
}

/// 네이티브 퇴근 승천권 종이 회오리 — 솟구칠 때 가방 · 양복에서 터져 나온 서류가 몸의 회전에 휘말려 돌다 흩날려 떨어진다.
/// 무대 G-버퍼에 픽셀로(NativeRiseArt.paper). 나이만으로 매 프레임 다시 계산한다(씨앗 고정 — 결정적)
public struct RisePaper: Sendable, Equatable, Codable {
    public var actor: Int
    /// 쓴 방향(+1 오른쪽 — 돌기 방향) · 흐른 초(게임 속도)
    public var f = 1.0, age = 0.0
    /// 솟구친 자리(주인공 발 x · 바닥 y — 회오리 축)
    public var x = 0.0, y = 0.0
    /// 지붕 뚫기로 이어짐: 구멍 x · 천장 y(몇 장은 구멍으로 빨려 올라가고 몇 장은 빛줄기로 되돌아 내려온다)
    public var roof: [Double]?
    /// 움직임 줄이기(장 수 적게 · 짧게)
    public var calm = false
    public var seed: UInt64 = 0
    public init(actor: Int, f: Double, x: Double, y: Double) { self.actor = actor; self.f = f; self.x = x; self.y = y }
}

/// 웹 GS.wipe(칸 이동 문 전환)
public struct WipeView: Sendable, Equatable, Codable { public var t: Double; public var label: String?; public init(t: Double, label: String?) { self.t = t; self.label = label } }

/// 웹 GS.cmdLog 한 칸(age = 지금 − 넣은 시각)
public struct CmdView: Sendable, Equatable, Codable {
    public var name: String, age: Double
    public var sp = false, crit = false, link = false
    public var fam: String?
    public init(name: String, age: Double, sp: Bool = false, crit: Bool = false, link: Bool = false, fam: String? = nil) { self.name = name; self.age = age; self.sp = sp; self.crit = crit; self.link = link; self.fam = fam }
}

/// drawUI 가 한 프레임에 읽는 값(웹 전역 · GS)
public struct HUDFrame: Sendable, Equatable, Codable {
    public struct Stop: Sendable, Equatable, Codable { public var label: String, here = false, passed = false, next = false; public init(label: String, here: Bool = false, passed: Bool = false, next: Bool = false) { self.label = label; self.here = here; self.passed = passed; self.next = next } }
    public struct Foe: Sendable, Equatable, Codable {
        public var x: Double, y: Double, hp: Double, max: Double
        public var boss = false, bossInfo = false
        /// 공격 예고: action && !fired 이면 무게(L · M · H, FOE_W 없으면 nil 이고 hasAction 만 참)
        public var hasAction = false, w: String?, tt: Double?
        /// 네이티브 공방(docs/08): [가드 자세 0·1·2, 게이지 0..1, 막은 뒤 지난 초, 크래시 0·1, 끼어들기 예고 0·1] — 옛 픽스처엔 없어 선택값
        public var gd: [Double]?
        public init(x: Double, y: Double, hp: Double, max: Double) { self.x = x; self.y = y; self.hp = hp; self.max = max }
    }
    public struct Boss: Sendable, Equatable, Codable { public var t: String, hp: Double, max: Double, raged = false, lag: Double; public init(t: String, hp: Double, max: Double, raged: Bool, lag: Double) { self.t = t; self.hp = hp; self.max = max; self.raged = raged; self.lag = lag } }
    public struct Break: Sendable, Equatable, Codable { public var x: Double, y: Double, k: Double }
    public struct TapW: Sendable, Equatable, Codable { public var x: Double, y: Double, t: Double }
    public struct Combo: Sendable, Equatable, Codable { public var n: Int, since: Double, win: Double, dmg: Int; public init(n: Int, since: Double, win: Double, dmg: Int) { self.n = n; self.since = since; self.win = win; self.dmg = dmg } }

    public var vw = 360.0, h = 270.0, w = 480.0, uis = 3.0
    public var camX = 0.0, viewZ = 1.0, viewC: [Double] = [0.5, 0.5], shv = 0.0
    /// 웹 performance.now()/1000(깜빡임) · GS.time
    public var now = 0.0, time = 0.0
    public var on = true, hero = true
    public var lbox = 0.0
    public var tower = false, bonus = false
    // 노선도 · 점수 · 남은 시간
    public var stageColor = "#ff6319"
    public var stops: [Stop] = []
    public var score = 0
    public var timeBar: Double?
    public var foesLeft = 0
    public var manual = false
    /// AUTO · MANUAL 배지(웹 그대로면 nil · true). 네이티브 출시판은 개발자 설정에서만 켠다 — 옵셔널이라 예전 고정 값도 읽힌다
    public var modeBadge: Bool?
    // 초상 · 체력 · 필살
    public var portrait = "face:hero"
    public var portraitDX = 0.0
    public var hp = 100.0, max = 100.0, lagH = 100.0, sp = 0.0
    public var boss: Boss?
    public var foes: [Foe] = []
    public var heroX: Double?
    public var justW = 0.16
    public var flash: String?
    public var duck: [Double]?
    public var stagger: [[Double]] = []
    public var bossBreak: Break?
    public var tapW: TapW?
    public var doze: [[Double]] = []
    public var combo: Combo?
    public var skin = "jw", shades = false, noFlash = false
    public var fade = 0.0
    /// 모드 HUD 값(타워 · 보너스 · 무도장 · 거리 연출 · 복도 · 쇼 칸 전구 · 만화 페이지) — HUDModes.swift
    public var modes: HUDModes?
    /// 가방 정리 슬로 중 테두리(웹 GS.bagSlowT > 0 && inCombat()) — 옛 픽스처엔 없어 선택값
    public var bagSlow: Bool?
    /// 네이티브 공방: 주인공 가드 [x, y, 자세, 게이지, 막은 뒤 지난 초] — 가드 중 · 막은 직후만(선택값)
    public var heroGuard: [Double]?
    /// 네이티브 세로 배치(docs/09): 화면 고정 HUD(노선도 · 초상 · 체력 · 필살 게이지 · 기술 줄 · 연타 · 두목 막대) 배율 — nil = 1(웹 그대로).
    /// 무대가 커져 장면 1px 이 커지면 HUD 만 작게 그린다. 모드 HUD(타워 · 보너스 · 무도장 · 복도)에는 쓰지 않는다
    public var hudScale: Double?
    /// 위 HUD(노선도 · 기술 줄 · 연타)를 이만큼(HUD px) 아래로 — 위에 SwiftUI 역 이름 자리. nil = 0
    public var hudTop: Double?
    /// 점수를 캔버스에 그리지 않는다(SwiftUI 오른쪽 위 묶음이 그린다). nil = 웹 그대로
    public var scoreOutside: Bool?
    /// 무대 위 피해 숫자 크기 배율(네이티브 — 감독 피드백 2026-10-14: 50%). nil = 1(웹 그대로). HUD 는 화면 px 3배라 0.5 배로 그려도 글자 1칸이 1.5px 로 남는다
    public var dmgScale: Double?
    public init() {}
}
