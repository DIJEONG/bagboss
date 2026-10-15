// 장면 구성 입력 — 웹 drawSubwayBack · subwayLights · subwayFX(타워면 drawTowerBack · towerLights · towerFX)와
// render() 의 광원 합성이 읽는 상태를 '정확히 그것만' 모은 값. Sim 스냅숏(N3)에서 채워진다.
// 필드 이름은 웹 이름(GS · TR 필드)을 따르고, 웹에서 없을 수 있는 값은 옵셔널로 둔다(`x||0` · `x??1` 구분 보존).
// tools/js/extract/scenes.mjs 의 input 과 같은 모양이다(JSON 으로 바로 읽힌다).

public struct SceneInput: Sendable, Equatable, Codable {
    /// 웹 scene · GS.state
    public var scene: String = "subway"
    public var state: String = "fight"
    /// render(time) 의 time(gameTime) · GS.time(게임 시계)
    public var time: Double = 0
    public var gsTime: Double = 0
    /// STAGE 가 STAGES 의 몇 번인지 · GS.stageIdx(광고 · 색 보정용 — 따로 읽는다)
    public var stage: Int = 0
    public var stageIdx: Double?
    /// GS.ci(객차) · GS.leg(구간) · GS.legStart(구간 시작 거리)
    public var ci: Double?
    public var leg: Double?
    public var legStart: Double?
    public var arriving: Bool = false
    public var nextStop: String?
    public var on: Bool = true
    /// GS.prologue(복도) · 무도장 데모(GS.demo && DJ.on) — 그리기 상태는 corridor · dojoRoom(없으면 SceneFrame.unported)
    public var prologue: Bool = false
    public var dojo: Bool = false
    public var oneBit: Bool = false
    public var invF: Double = 0
    public var press: Double = 0
    public var brakeGlow: Double = 0
    /// 제동 불꽃(없으면 nil — 웹 `if(GS.brakeSp)`)
    public var brakeSp: [BrakeSpark]?
    public var props: [Prop] = []
    public var cans: [Can] = []
    public var shots: [Shot] = []
    public var items: [Item] = []
    /// 옆 선로로 지나가는 열차 진행(GS.pt.t) — 없으면 nil
    public var passT: Double?
    public var lightK: Double?
    public var emitK: Double?
    /// GS.bits 배열이 있는지(불꽃 파편을 넣을 곳)
    public var hasBits: Bool = false
    public var train: Train = Train()
    /// 손잡이를 잡고 선 승객(GS.ents 중 pass · 안 숨음 · goal 없음 — 원래 순서)
    public var holders: [Holder] = []
    /// 손잡이 흔들림(웹 STRAPS[x].a)
    public var straps: [Strap] = []
    /// 브로드웨이 쇼 칸 천장 조명(웹 SHOW_LAMPS)
    public var showLamps: [ShowLamp] = []
    public var hero: Hero?
    /// 살아 있는 적(foes()) — 손전등(e.lamp) · 쓰러짐(isDown) · 저글 여부
    public var foes: [Foe] = []
    public var eye: Eye = Eye()
    /// 개발 스위치(__dotlab.WINR_OFF)
    public var winROff: Bool = false
    /// 화면 흔들림(SHK()) · 충격 반전(IMPF>0) — 렌더 어댑터만 쓴다
    public var shake: Double = 0
    public var impactInvert: Bool = false
    public var tower: Tower?
    /// brawl 장면(웹 scene==='brawl' — 보너스 차 부수기 · 프롤로그 뒤 비 오는 거리 GS.cine). 있으면 지하철 대신 느와르 거리 갈래로 그린다
    public var brawl: Brawl?
    /// 프롤로그 지하 복도(웹 GS.prologue) — prologue 가 참이고 이 값이 있으면 복도를 그린다
    public var corridor: Corridor?
    /// 무도장(웹 DJ — GS.demo && DJ.on) — dojo 가 참이고 이 값이 있으면 무도장(또는 건널목)을 그린다
    public var dojoRoom: DojoRoom?

    public init() {}

    public struct Train: Sendable, Equatable, Codable {
        public var ex: Double = 0, dy: Double = 0, v: Double = 0, jolt: Double = 0, door: Double = 0
        public var t: Double = 0, a: Double = 0, strap: Double = 0, flickS: Double = 0, stopAt: Double = 0
        public init() {}
    }
    public struct BrakeSpark: Sendable, Equatable, Codable { public var x: Double, y: Double, t: Double }
    public struct Prop: Sendable, Equatable, Codable { public var k: String, x: Double, ice: Bool }
    public struct Can: Sendable, Equatable, Codable { public var x: Double, v: Double }
    public struct Shot: Sendable, Equatable, Codable { public var x: Double, y: Double, t: Double, vx: Double, friendly: Bool
        /// 모양(네이티브 전용 — nil 병 · "news" 신문 뭉치)
        public var kind: String? = nil }
    public struct Item: Sendable, Equatable, Codable { public var kind: String; public var id: String?; public var x: Double, z: Double, t: Double }
    public struct Holder: Sendable, Equatable, Codable { public var strapX: Double?; public var y: Double; public var handDY: Double? }
    public struct Strap: Sendable, Equatable, Codable { public var x: Double, a: Double }
    public struct ShowLamp: Sendable, Equatable, Codable { public var x: Double, k: Double, sparkT: Double }
    public struct Hero: Sendable, Equatable, Codable { public var x: Double, y: Double, flip: Bool, hidden: Bool }
    public struct Foe: Sendable, Equatable, Codable { public var x: Double, y: Double, flip: Bool, lamp: Bool, down: Bool, jug: Bool }
    /// 눈 적응 상태 + 벽시계(웹 performance.now()/1000) · 재생 배속
    public struct Eye: Sendable, Equatable, Codable {
        public var adT: Double?
        public var outS: Double?
        public var darkA: Double?
        public var adA: Double?
        public var now: Double = 0
        public var playSpeed: Double = 1
        public init() {}
    }
    public struct Tower: Sendable, Equatable, Codable {
        public var pos: Double, floor: Int, phase: String, door: Double, shk: Double
        /// 부서진 층 번호
        public var wreck: [Int]
        public var alarm: Double
        public var fly: [Fly]
        public var sagV: Double, limit: Double, over: Bool, panelT: Double, kit: Bool
        public var dent: [Double]
        public var lamps: [Lamp]
        public var dark: Bool
        public var fires: [Fire]
        public var fl: Double
        public struct Fly: Sendable, Equatable, Codable { public var t: Double, dur: Double, x0: Double, x1: Double, y0: Double, y1: Double, r0: Double }
        public struct Lamp: Sendable, Equatable, Codable { public var a: Double, hang: Bool, flick: Double }
        public struct Fire: Sendable, Equatable, Codable { public var x: Double }
    }
}

// MARK: - N5 장면(brawl · 복도 · 무도장) 입력 — 필드 이름은 웹 GS.cine · GS.bonus · GS.prologue · DJ 이름 그대로

extension SceneInput {
    public struct Pt: Sendable, Equatable, Codable { public var x: Double, y: Double; public init(x: Double, y: Double) { self.x = x; self.y = y } }

    /// 웹 render() brawl 갈래가 읽는 상태
    public struct Brawl: Sendable, Equatable, Codable {
        /// 웹 GS.cam(거리 카메라 — charOX = -round(cam))
        public var cam: Double
        /// 웹 GS.stage(날씨 표 — 보너스 · 거리 장면이 아닐 때만 쓰인다)
        public var stage: Double?
        /// 웹 performance.now()(ms — 보너스 비상등 깜빡임)
        public var perfNow: Double
        /// 보조광이 덮는 무리(웹 [hero, ...적].slice(1) 중 안 숨은 것 — 보너스 허수아비 포함)
        public var crowd: [Pt]
        public var cine: Cine?
        public var bonus: Bonus?
        public init(cam: Double = 0, stage: Double? = nil, perfNow: Double = 0, crowd: [Pt] = [], cine: Cine? = nil, bonus: Bonus? = nil) {
            self.cam = cam; self.stage = stage; self.perfNow = perfNow; self.crowd = crowd; self.cine = cine; self.bonus = bonus
        }
        /// 웹 GS.cine(그리기에 쓰는 것만) — 쓰레기통에 꽂힌 장도리 · 날아가는 장도리
        public struct Cine: Sendable, Equatable, Codable {
            public var hammerIn: Bool
            public var toss: Toss?
            public struct Toss: Sendable, Equatable, Codable { public var t: Double, x0: Double, y0: Double; public init(t: Double, x0: Double, y0: Double) { self.t = t; self.x0 = x0; self.y0 = y0 } }
            public init(hammerIn: Bool = false, toss: Toss? = nil) { self.hammerIn = hammerIn; self.toss = toss }
        }
        /// 웹 GS.bonus(그리기에 쓰는 것만)
        public struct Bonus: Sendable, Equatable, Codable {
            public var alarm: Bool, alarmOff: Bool, fire: Bool
            /// 연기 · 김 · 불길 입자(웹 BN.pfx — 연출 상태, BonusPuffs 가 이어 간다)
            public var pfx: [Puff]
            public var car: Car?
            public init(alarm: Bool = false, alarmOff: Bool = false, fire: Bool = false, pfx: [Puff] = [], car: Car? = nil) {
                self.alarm = alarm; self.alarmOff = alarmOff; self.fire = fire; self.pfx = pfx; self.car = car
            }
            public struct Puff: Sendable, Equatable, Codable {
                /// smk · stm · fire
                public var k: String
                public var x: Double, y: Double, t: Double, life: Double
                public init(k: String, x: Double, y: Double, t: Double, life: Double) { self.k = k; self.x = x; self.y = y; self.t = t; self.life = life }
            }
            public struct Car: Sendable, Equatable, Codable {
                public var x: Double, y: Double
                public var stage: Int
                public var gone: [String]
                public var tilt: Double, shake: Double, flash: Double, dmgF: Double
                /// 웹 C.dentN — 지난 그리기의 carBones 가 남긴 값(이번 프레임 모델의 찌그러짐 수). 새 값은 SceneEffects.dentN
                public var dentN: Int
                public var debris: [Debris]
                public struct Debris: Sendable, Equatable, Codable {
                    public var key: String, x: Double, y: Double, z: Double, th: Double
                    public init(key: String, x: Double, y: Double, z: Double, th: Double) { self.key = key; self.x = x; self.y = y; self.z = z; self.th = th }
                }
                public init(x: Double = 330, y: Double = 226, stage: Int = 0, gone: [String] = [], tilt: Double = 0, shake: Double = 0, flash: Double = 0,
                            dmgF: Double = 0, dentN: Int = 0, debris: [Debris] = []) {
                    self.x = x; self.y = y; self.stage = stage; self.gone = gone; self.tilt = tilt; self.shake = shake; self.flash = flash
                    self.dmgF = dmgF; self.dentN = dentN; self.debris = debris
                }
            }
        }
    }

    /// 웹 GS.prologue(복도 그리기에 쓰는 것만)
    public struct Corridor: Sendable, Equatable, Codable {
        /// 복도 진행(웹 P.x — 세상이 뒤로 흐른 거리)
        public var x: Double
        /// 끝 철문이 열렸나 · 연 뒤 초
        public var out: Bool, outT: Double
        public var doors: [Door]
        /// 흔들리는 전등 각도(웹 P.lamps[wx].a) — 없는 자리는 처음 그릴 때 난수로 만든다(SceneEffects.corridorLamps)
        public var lamps: [Lamp]
        public init(x: Double = 0, out: Bool = false, outT: Double = 0, doors: [Door] = [], lamps: [Lamp] = []) {
            self.x = x; self.out = out; self.outT = outT; self.doors = doors; self.lamps = lamps
        }
        /// 문(웹 P.doors[wxc]) — st: shut · open · bang
        public struct Door: Sendable, Equatable, Codable {
            public var wxc: Double, st: String, t: Double
            public init(wxc: Double, st: String, t: Double) { self.wxc = wxc; self.st = st; self.t = t }
        }
        public struct Lamp: Sendable, Equatable, Codable {
            public var wx: Double, a: Double
            public init(wx: Double, a: Double) { self.wx = wx; self.a = a }
        }
    }

    /// 웹 DJ(무도장 그리기 상태)
    public struct DojoRoom: Sendable, Equatable, Codable {
        /// dojo · cross(건널목) — nil 이면 웹 OPT.djbg 기본 'dojo'
        public var bg: String?
        /// 현판 · 등롱 두 개 · 샌드백 흔들림 각(라디안)
        public var sign: Double
        public var lamps: [Double]
        public var bag: Double
        /// 창 밖 행인
        public var walkers: [Walker]
        /// 목인 · 북 떨림 남은 초 · 판자 · 무기 걸이 부서짐
        public var mook: Double, drum: Double
        public var brd: Bool, rack: Bool
        /// 건널목 상태(웹 DJ.xc) — 없으면 처음 그릴 때 난수로 만든다(SceneEffects.cross)
        public var xc: Cross?
        public init(bg: String? = nil, sign: Double = 0, lamps: [Double] = [0, 0], bag: Double = 0, walkers: [Walker] = [], mook: Double = 0, drum: Double = 0,
                    brd: Bool = false, rack: Bool = false, xc: Cross? = nil) {
            self.bg = bg; self.sign = sign; self.lamps = lamps; self.bag = bag; self.walkers = walkers; self.mook = mook; self.drum = drum
            self.brd = brd; self.rack = rack; self.xc = xc
        }
        public struct Walker: Sendable, Equatable, Codable {
            public var x: Double, v: Double, um: Double, t: Double
            public init(x: Double, v: Double, um: Double, t: Double) { self.x = x; self.v = v; self.um = um; self.t = t }
        }
    }

    /// 웹 DJ.xc(건널목 — 노면 전차 · 단풍)
    public struct Cross: Sendable, Equatable, Codable {
        public var tr: Tram?
        public var bell: Bool
        /// 팬터그래프 불꽃 남은 초 · 자리
        public var spk: Double, spkX: Double
        /// 다음 전차까지(웹 X.nextT — 그리기는 안 읽는다. xcReset 결과 대조용)
        public var nextT: Double
        public var leaves: [Leaf]
        /// 떨어지는 잎(y 가 있다)
        public var fall: [Leaf]
        public init(tr: Tram? = nil, bell: Bool = false, spk: Double = 0, spkX: Double = 0, nextT: Double = 0, leaves: [Leaf] = [], fall: [Leaf] = []) {
            self.tr = tr; self.bell = bell; self.spk = spk; self.spkX = spkX; self.nextT = nextT; self.leaves = leaves; self.fall = fall
        }
        public struct Tram: Sendable, Equatable, Codable {
            public var dir: Double, x: Double, warn: Double, kind: String, dist: Double
            public init(dir: Double, x: Double, warn: Double, kind: String, dist: Double) { self.dir = dir; self.x = x; self.warn = warn; self.kind = kind; self.dist = dist }
        }
        public struct Leaf: Sendable, Equatable, Codable {
            public var x: Double, gy: Double
            public var y: Double?
            public var h: Double?
            public var rot: Double, c: Double, s: Double, ph: Double
            public init(x: Double, gy: Double, y: Double? = nil, h: Double? = nil, rot: Double, c: Double, s: Double, ph: Double) {
                self.x = x; self.gy = gy; self.y = y; self.h = h; self.rot = rot; self.c = c; self.s = s; self.ph = ph
            }
        }
    }
}


/// 네이티브 전용: 신문팔이 소년이 던진 신문 뭉치 — 펼친 면(sb_news) · 접힌 면(sb_news2)을 번갈아 펄럭인다
func newsShot(_ s: SceneInput.Shot) -> String { Int(jsFloor(s.t * 12)) % 2 == 0 ? "sb_news" : "sb_news2" }
