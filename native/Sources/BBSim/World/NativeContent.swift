import Foundation
import BBContent
import BBAnim

// 네이티브 전용 게임 콘텐츠(SimConfig.nativeMoves) — 웹 GITEMS · COMBO_ROLE · COMBO_BOOK · ATK_FEEL · MOVE_REACH 와 같은 모양으로 적고
// SimData.variant(nativeMoves: true) 가 기본 표 뒤에 붙인다(기본 표 · 순서는 그대로 → 깃발이 꺼지면 웹과 같다).
// 복싱 기술 이름은 실제 복싱 용어(플리커 잽 · 리버 블로 · 코크스크루 블로 · 숄더 롤)만 쓴다.
// 스매시는 어퍼컷과 역할(S *→A 띄우기)이 겹쳐 감독 피드백으로 통합 — 아이템을 없애고 그 포즈를 깃발 켜짐의 어퍼컷 시퀀스에 입혔다(NativeMoves.overrideSequences).

public enum NativeContent {
    /// 새 아이템(웹 GITEMS 항목 JSON — ItemDef 로 읽는다). 순서 = 상점 · 도감 순서
    static var itemRows: [(String, [String: Any])] { [
        ("nv_flick", ["n": "플리커 잽", "icon": "punch", "fam": "fist", "shape": [[0, 0], [1, 0]], "kind": "skill", "fist": true,
                      "dmg": 5, "cd": 0.75, "anim": "nv_flick", "cue": "fl_hit", "reach": 34, "react": "head",
                      "desc": "앞손을 허리께로 늘어뜨린 채 채찍처럼 휘둘러 멀리서 빠르게 쳐요. 콤보를 여는 데 좋아요"]),
        ("nv_liver", ["n": "리버 블로", "icon": "elbow", "fam": "fist", "shape": [[0, 0], [0, 1], [1, 1]], "kind": "skill", "fist": true,
                      "dmg": 12, "cd": 2.2, "anim": "nv_liver", "cue": "lv_hit", "reach": 20, "react": "body",
                      "desc": "몸을 숙여 파고들며 옆구리에 훅을 꽂아요. 맞은 적은 숨이 막혀 무릎부터 무너져요"]),
        ("nv_cork", ["n": "코크스크루 블로", "icon": "punch", "fam": "fist", "shape": [[0, 0], [1, 0], [2, 0], [1, 1]], "kind": "skill", "fist": true,
                     "dmg": 20, "cd": 3.4, "anim": "nv_cork", "cue": "ck_hit", "reach": 28, "knock": true, "crit": true,
                     "desc": "주먹을 비틀어 꽂는 스트레이트. 가드 · 막기를 꿰뚫고 반드시 치명타, 맞은 적은 일직선으로 날아가요"]),
        ("nv_roll", ["n": "숄더 롤 카운터", "icon": "elbow", "fam": "fist", "shape": [[0, 0], [1, 0], [0, 1]], "kind": "skill", "fist": true, "cond": "counter",
                     "dmg": 15, "cd": 2.0, "anim": "nv_roll", "cue": "sr_hit", "reach": 26, "react": "body", "crit": true, "stun": 0.8,
                     "desc": "적이 치려는 순간 앞어깨를 올려 흘려 보내고, 되돌아오는 힘으로 뒷손을 꽂아요. 흘리는 동안은 맞지 않아요"]),
        // 퇴근 승천권(이름은 riseName 한 곳): 막는 중 되받아치기 · 대공 — 역할 ● 이음기(공중에서만 · 콤보를 열지 않는다 — docs/08 §8 밸런스). 솟구치며 2타(작게) → 꼭대기 1타(크게 띄움). 출발 칸 무적 · 착지 뒤 긴 빈틈
        ("nv_rise", ["n": riseName, "icon": "upper", "fam": "fist", "shape": [[0, 0], [0, 1], [0, 2]], "kind": "skill", "fist": true, "cond": "nv_aa",
                     "dmg": 20, "cd": 6.5, "anim": "nv_rise", "cue": "rs_apex", "reach": 24, "react": "launch",
                     "desc": "몸을 비틀며 주먹째 솟구쳐 한 바퀴 돌아요. 막는 중에도 튀어 오르고, 뛰어드는 적을 떨어뜨려요. 뜨는 순간은 맞지 않지만 내려오면 빈틈이 커요"]),
        // 무릎 올려치기(버추어 파이터 참고 — World+NativeVF): 바짝 붙어 뒷무릎으로 가슴을 올려 친다 → 높이 띄움(공중 콤보 시작기 G→A). 무릎을 든 채 멈칫하는 칸이 읽힌다
        ("nv_kneelift", ["n": kneeliftName, "icon": "knee", "fam": "grap", "shape": [[0, 0], [0, 1], [1, 0]], "kind": "skill",
                         "dmg": 16, "cd": 4.2, "anim": "nv_kneelift", "cue": "kl_hit", "reach": 22, "react": "launch",
                         "desc": "바짝 붙어 뒷무릎을 차올려 가슴을 올려 쳐요. 무릎을 든 채 버티는 사이 적은 높이 떠올라 공중 콤보로 이어 가요"]),
        // 파고들어 올려치기(World+NativeVF): 크게 내디뎌 깊이 숙여 앞손 1타(작게 · 잠깐 묶음) → 튀어 오르며 뒷손 어퍼컷 2타(아이템 피해 · 띄움). 서 있는 적에게만(조건 nv_ground)
        ("nv_duckup", ["n": duckupName, "icon": "upper", "fam": "fist", "shape": [[0, 0], [1, 0], [1, 1]], "kind": "skill", "fist": true, "cond": "nv_ground",
                       "dmg": 16, "cd": 4.5, "anim": "nv_duckup", "cue": "du_up", "reach": 36, "react": "launch",
                       "desc": "크게 내디디며 깊이 숙여 앞손으로 몸통을 찌르고, 웅크린 채 튀어 오르며 뒷손 어퍼컷으로 띄워요. 조금 떨어진 적에게도 파고들어요"]),
        // 야근 광선(World+NativeBeam): 두 손가락을 안경테에 대고 안경알에서 광선 — 첫 타(기본 경로) → 유지 다단(광선 위 모두 · 밀어냄) → 마지막 한 방(일직선 날림). 마무리기(F). 떠 있는 적엔 위로 꺾어 쏜다
        ("nv_beam", ["n": beamName, "icon": "charge", "shape": [[0, 0], [1, 0], [2, 0]], "kind": "skill",
                     "dmg": 14, "cd": 7.0, "anim": "nv_beam", "cue": "bm_fire", "reach": 150, "react": "body",
                     "desc": "두 손가락을 안경에 대고 광선을 쏴요. 앞에 늘어선 적을 모두 꿰뚫어 밀어내고, 끊기 전 마지막 한 방에 날려 보내요. 떠 있는 적에겐 위로 꺾어 쏴요"]),
        // 직장인 세 기술(World+NativeOffice · 자세 NativeOfficePoses)
        // 서류가방 내려찍기: 뛰어올라 가방을 머리 위에서 내려찍는다 → 떠 있든 서 있든 바닥에 꽂혀 높이 튀어 오른다(다시 띄우기 — 이음기 *→A)
        ("nv_slam", ["n": slamName, "icon": "case", "shape": [[0, 0], [1, 0], [1, 1]], "kind": "skill", "wpn": "w_case",
                     "dmg": 18, "cd": 4.8, "anim": "nv_slam", "cue": "cs_hit", "reach": 30, "react": "launch",
                     "desc": slamDesc]),
        // 결재 쌍장: 크게 미끄러져 들어가 두 손바닥으로 밀어 친다 → 일직선으로 날아가 벽에 박힌다(벽에 붙은 동안 더 칠 수 있다 — 마무리기 *→K)
        ("nv_stamp", ["n": stampName, "icon": "knuckle", "shape": [[0, 0], [0, 1], [1, 0], [1, 1]], "kind": "skill",
                      "dmg": 22, "cd": 5.5, "anim": "nv_stamp", "cue": "ss_hit", "reach": 24, "knock": true,
                      "desc": stampDesc]),
        // 멱살 박치기: 멱살을 잡아 끌어당겨 큰 머리로 두 번 박는다(잡기 — 가드를 무시) → 어질어질 휘청(시작기 G→Z)
        ("nv_headbutt", ["n": headbuttName, "icon": "throw", "fam": "grap", "shape": [[0, 0], [1, 0], [0, 1]], "kind": "skill", "cond": "grab",
                         "dmg": 15, "cd": 3.6, "anim": "nv_headbutt", "cue": "hb_hit2", "reach": 22, "stun": 1.1,
                         "desc": headbuttDesc]),
        // 내선 연결(World+NativeDial): 수화기를 던져 멀리 · 날아가는 · 벽에 박힌 적을 끌어온다 → 끌림(P) 경직 — 어퍼컷으로 잇는다. 두목은 반대로 주인공이 끌려간다
        ("nv_dial", ["n": dialName, "icon": "earph", "shape": [[0, 0], [1, 0], [2, 0]], "kind": "skill",
                     "dmg": 8, "cd": 5.0, "anim": "nv_dial", "cue": "ph_catch", "reach": 160, "react": "head",
                     "desc": dialDesc]),
        // 구두 슛(World+NativePunt): 쓰러진 적을 구두 앞코로 차 낮게 굴러가듯 멀리 날린다(이음기 D→K — 볼링 · 내선 연결로 다시 끌어오기)
        ("nv_punt", ["n": puntName, "icon": "kick", "fam": "foot", "shape": [[0, 0], [1, 0]], "kind": "skill", "cond": "down",
                     "dmg": 14, "cd": 3.0, "anim": "nv_punt", "cue": "pk_hit", "reach": 30,
                     "desc": puntDesc]),
    ] }
    /// 직장인 세 기술 표시 이름 · 설명(번역은 strings-extra 'native-moves')
    public static let slamName = "서류가방 내려찍기", stampName = "결재 쌍장", headbuttName = "멱살 박치기"
    static let slamDesc = "뛰어올라 서류가방을 머리 위에서 내려찍어요. 떠 있든 서 있든 바닥에 꽂혀 높이 튀어 오르고, 가방에서 서류가 흩날려요"
    static let stampDesc = "크게 미끄러져 들어가 두 손바닥으로 밀어 쳐요. 맞은 적은 일직선으로 날아가 벽에 박히고, 박혀 있는 동안 더 때릴 수 있어요"
    /// 내선 연결 표시 이름 · 설명(번역은 strings-extra 'native-moves')
    public static let dialName = "내선 연결"
    static let dialDesc = "유선 전화 수화기를 던져 멀리 있는 적을 낚아채 끌어와요. 날아가는 적도, 벽에 박힌 적도 끌어오고, 끌려온 적은 비틀거려 어퍼컷으로 이어 가요"
    /// 구두 슛 표시 이름 · 설명(번역은 strings-extra 'native-moves')
    public static let puntName = "구두 슛"
    static let puntDesc = "쓰러진 적을 구두 앞코로 축구공처럼 차요. 낮게 데굴데굴 굴러가며 멀리 날아가고, 서 있는 다른 적을 볼링처럼 넘어뜨려요"
    static let headbuttDesc = "멱살을 잡아 끌어당긴 뒤 큰 머리로 두 번 박아요. 잡기라 가드를 무시하고, 맞은 적은 어질어질 휘청여요"
    /// 무릎 올려치기 · 파고들어 올려치기 표시 이름(번역은 strings-extra 'native-moves')
    public static let kneeliftName = "무릎 올려치기"
    public static let duckupName = "파고들어 올려치기"
    /// 야근 광선 표시 이름(번역은 strings-extra 'native-moves')
    public static let beamName = "야근 광선"
    /// 퇴근 승천권 표시 이름(가제 — 여기만 바꾸면 아이템 · 무도장 목록이 같이 바뀐다. 번역은 strings-extra 'native-moves')
    public static let riseName = "퇴근 승천권"
    static let rolesJSON = """
    [["nv_flick", {"r": "S", "i": "G", "o": "="}], ["nv_liver", {"r": "S", "i": "G", "o": "C"}], ["nv_cork", {"r": "F", "i": "*", "o": "K"}],
     ["nv_roll", {"r": "S", "i": "G", "o": "Z"}], ["nv_rise", {"r": "L", "i": "A", "o": "A"}],
     ["nv_kneelift", {"r": "S", "i": "G", "o": "A"}], ["nv_duckup", {"r": "S", "i": "G", "o": "A"}],
     ["nv_beam", {"r": "F", "i": "*", "o": "K"}],
     ["nv_slam", {"r": "L", "i": "*", "o": "A"}], ["nv_stamp", {"r": "F", "i": "*", "o": "K"}], ["nv_headbutt", {"r": "S", "i": "G", "o": "Z"}],
     ["nv_dial", {"r": "S", "i": "*", "o": "P"}], ["nv_punt", {"r": "L", "i": "D", "o": "K"}]]
    """
    static var bookRows: [[String: Any]] { [
        ["id": "nv_peek", "n": "피카부 러시", "r": ["nv_flick", "punch", "nv_cork"], "d": "플리커로 거리를 재고 연타를 넣은 뒤 코크스크루로 꿰뚫어요"],
        ["id": "nv_liverup", "n": "간 찌르고 퍼 올리기", "r": ["nv_liver", "punch", "upper"], "d": "리버 블로로 무너뜨리고 두들긴 뒤 어퍼컷으로 띄워요"],
        ["id": "nv_rollcork", "n": "흘리고 꿰뚫기", "r": ["nv_roll", "nv_liver", "nv_cork"], "d": "숄더 롤로 흘리고 옆구리를 찌른 뒤 코크스크루로 날려요"],
        ["id": "nv_kessai", "n": "결재 라인", "r": ["nv_headbutt", "nv_liver", "nv_stamp"], "d": "멱살 박치기로 어지럽히고 옆구리를 찌른 뒤 결재 쌍장으로 벽에 박아요"],
        ["id": "nv_hotline", "n": "핫라인", "r": ["nv_dial", "upper"], "d": "수화기를 던져 멀리 있는 적을 끌어온 뒤 어퍼컷으로 띄워요"],
        ["id": "nv_kickoff", "n": "킥오프", "r": ["sweep", "nv_punt", "nv_dial", "upper"], "d": "다리를 걸어 넘어뜨리고 구두로 차 멀리 보낸 뒤 수화기로 다시 끌어와 어퍼컷으로 띄워요"],
        ["id": "nv_paperstorm", "n": "서류 폭풍", "r": ["nv_kneelift", "nv_slam", "upper", "nv_stamp"], "d": "무릎으로 띄우고 서류가방으로 바닥에 꽂아 다시 띄운 뒤 결재 쌍장으로 날려요"],
    ] }
    /// 손맛(웹 ATK_FEEL) — 러시 박자 훅 · 마무리도 여기서 무게를 받는다
    /// hs(히트스톱 배율): 플리커 0.5(견제기 — 리듬을 끊지 않게) · 숄더 롤 0.6(받아치기 창처럼 짧게 — 치명이라 기본 경직이 이미 1.5~1.9배) — docs/07 §5-4 조정
    static let feelJSON = """
    [["nv_flick", {"w": "L", "load": "fl_load", "hit": "fl_hit", "hs": 0.5, "shake": 0.9, "zoom": 0, "step": 5}],
     ["nv_liver", {"w": "M", "load": "lv_load", "hit": "lv_hit", "hs": 1.35, "shake": 1.8, "zoom": 0.045, "step": 5}],
     ["nv_cork", {"w": "H", "load": "ck_pull", "hit": "ck_hit", "hs": 1.6, "shake": 2.8, "zoom": 0.075, "step": 7, "dust": 1}],
     ["nv_roll", {"w": "M", "load": "sr_roll", "hit": "sr_hit", "hs": 0.6, "shake": 1.8, "zoom": 0.04, "step": 3}],
     ["nv_rise", {"w": "H", "load": "rs_crouch", "hit": "rs_apex", "hs": 1.25, "shake": 2.6, "zoom": 0.06, "step": 4, "dust": 1}],
     ["nv_kneelift", {"w": "H", "load": "kl_drive", "hit": "kl_hit", "hs": 1.4, "shake": 2.4, "zoom": 0.05, "step": 4, "dust": 1}],
     ["nv_duckup", {"w": "M", "load": "du_sink", "hit": "du_up", "hs": 1.2, "shake": 2.2, "zoom": 0.05, "step": 0, "dust": 1}],
     ["nv_beam", {"w": "H", "load": "bm_charge", "hit": "bm_fire", "hs": 0.6, "shake": 2.0, "zoom": 0.03, "step": 0}],
     ["nv_slam", {"w": "H", "load": "cs_top", "hit": "cs_hit", "hs": 1.2, "shake": 2.8, "zoom": 0.06, "step": 0, "dust": 1}],
     ["nv_stamp", {"w": "H", "load": "ss_set", "hit": "ss_hit", "hs": 1.3, "shake": 3.0, "zoom": 0.07, "step": 0, "dust": 1}],
     ["nv_headbutt", {"w": "H", "load": "hb_back2", "hit": "hb_hit2", "hs": 1.5, "shake": 2.6, "zoom": 0.08, "step": 0}],
     ["nv_punt", {"w": "H", "load": "pk_plant", "hit": "pk_hit", "hs": 1.2, "shake": 2.4, "zoom": 0.05, "step": 0, "dust": 1}],
     ["nv_dial", {"w": "M", "load": "ph_set", "hit": "ph_catch", "hs": 1.0, "shake": 1.4, "zoom": 0.03, "step": 0}],
     ["nv_drHL", {"w": "M", "hs": 0.8, "shake": 1.3, "zoom": 0.02, "step": 0}],
     ["nv_drHR", {"w": "M", "hs": 0.8, "shake": 1.3, "zoom": 0.02, "step": 0}],
     ["nv_drHLq", {"w": "M", "hs": 0.8, "shake": 1.5, "zoom": 0.02, "step": 0}],
     ["nv_drHRq", {"w": "M", "hs": 0.8, "shake": 1.5, "zoom": 0.02, "step": 0}],
     ["nv_drFin", {"w": "H", "hs": 2.2, "shake": 4.2, "zoom": 0.11, "step": 0, "dust": 1}]]
    """
    /// 기술별 사거리(웹 MOVE_REACH)
    public static let moveReach: [String: Double] = ["nv_flick": 34, "nv_liver": 20, "nv_cork": 28, "nv_roll": 26, "nv_lowk": 26, "nv_rise": 24, "nv_kneelift": 22, "nv_duckup": 36, "nv_beam": 150, "nv_slam": 30, "nv_stamp": 24, "nv_headbutt": 22, "nv_dial": 160, "nv_punt": 30]
    /// 충격파 단계(웹 SW_T — 표현이 읽는다)
    public static let swTier: [String: Int] = ["nv_cork": 3, "nv_liver": 2, "nv_roll": 1, "nv_rise": 3, "nv_kneelift": 2, "nv_duckup": 3, "nv_beam": 3, "nv_slam": 3, "nv_stamp": 3, "nv_headbutt": 2, "nv_dial": 1, "nv_punt": 2, "nv_drFin": 4, "nv_drHL": 1, "nv_drHR": 1, "nv_drHLq": 1, "nv_drHRq": 1]
    /// 새 아이템 id(순서대로)
    public static var itemIDs: [String] { items.map(\.0) }

    struct Pair<T: Decodable>: Decodable {
        let k: String, v: T
        init(from d: Decoder) throws { var c = try d.unkeyedContainer(); k = try c.decode(String.self); v = try c.decode(T.self) }
    }
    static func pairs<T: Decodable>(_ s: String, _ t: T.Type) -> [(String, T)] {
        (try! JSONDecoder().decode([Pair<T>].self, from: Data(s.utf8))).map { ($0.k, $0.v) }
    }
    static func json(_ v: Any) -> Data { try! JSONSerialization.data(withJSONObject: v) }
    static let items: [(String, ItemDef)] = itemRows.map { ($0.0, try! JSONDecoder().decode(ItemDef.self, from: json($0.1))) }
    static let roles: [(String, ComboRole)] = pairs(rolesJSON, ComboRole.self)
    static let book: [ComboRecipe] = try! JSONDecoder().decode([ComboRecipe].self, from: json(bookRows))
    static let feel: [(String, AttackFeel)] = pairs(feelJSON, AttackFeel.self)
    /// 표현용: 기술 무게(웹 ATK_FEEL[anim].w)
    public static var atkWeight: [String: String] { Dictionary(uniqueKeysWithValues: feel.map { ($0.0, $0.1.w) }) }

    // MARK: 무도장(콤보 연구실) — 깃발이 켜지면 웹 DOJO 목록 뒤에 붙는다(순서 = 웹 목록 다음 인덱스)
    /// 기술 탭(이름 · 아이템 id)
    public static let dojoHero: [(name: String, id: String)] = [(riseName, "nv_rise"), ("플리커 잽", "nv_flick"), ("리버 블로", "nv_liver"), ("코크스크루 블로", "nv_cork"), ("숄더 롤 카운터", "nv_roll"),
                                                                         (kneeliftName, "nv_kneelift"), (duckupName, "nv_duckup"), (beamName, "nv_beam"),
                                                                         (slamName, "nv_slam"), (stampName, "nv_stamp"), (headbuttName, "nv_headbutt"), (dialName, "nv_dial"), (puntName, "nv_punt")]
    /// 커스텀 콤보 최대 단수(웹 CC_MAX 8 → 16). 편집기 두 줄 × 8칸과 같다 — 시연은 단계마다 제한 시간(6초)이 따로라 길어도 끝난다.
    /// 저장('dotlab-cc')은 배열 그대로라 8단 이하 저장본도 그대로 읽히고, 웹은 앞 8개만 읽는다(BBPersistence CustomCombo.nativeMaxSteps 와 같은 값)
    public static let dojoCCMax = 16
    /// 커스텀 콤보 팔레트(이름 · 'id' 값)
    public static var dojoMoves: [(name: String, value: String)] { dojoHero.map { ($0.name, $0.id) } }
    /// 콤보 시연(웹 DOJO.combo 와 같은 '이름 · 설명' 꼴) — 도감 콤보 3개
    public static let dojoCombos: [(name: String, steps: [DojoStep])] = [
        ("피카부 러시 · 플리커 잽 → 원투 → 코크스크루", [DojoStep("nv_flick"), DojoStep("punch", 0), DojoStep("punch", 1), DojoStep("nv_cork")]),
        ("간 찌르고 퍼 올리기 · 리버 블로 → 훅 → 어퍼컷", [DojoStep("nv_liver"), DojoStep("punch", 2), DojoStep("upper")]),
        ("흘리고 꿰뚫기 · 숄더 롤 → 리버 블로 → 코크스크루", [DojoStep("nv_roll"), DojoStep("nv_liver"), DojoStep("nv_cork")]),
        ("결재 라인 · 멱살 박치기 → 리버 블로 → 결재 쌍장", [DojoStep("nv_headbutt"), DojoStep("nv_liver"), DojoStep("nv_stamp")]),
        ("서류 폭풍 · 무릎 올려치기 → 서류가방 내려찍기 → 어퍼컷 → 결재 쌍장", [DojoStep("nv_kneelift"), DojoStep("nv_slam"), DojoStep("upper"), DojoStep("nv_stamp")]),
        ("핫라인 · 내선 연결 → 어퍼컷", [DojoStep("nv_dial"), DojoStep("upper")]),
        ("킥오프 · 다리걸기 → 구두 슛 → 내선 연결 → 어퍼컷", [DojoStep("sweep"), DojoStep("nv_punt"), DojoStep("nv_dial"), DojoStep("upper")]),
    ]
    /// 예시 가방(웹 DEMO_BAGS 꼴: id · x · y · rot)
    public static let demoBags: [(n: String, L: [(id: String, x: Int, y: Int, rot: Int)])] = [
        ("복싱 가방 1", [("nv_flick", 0, 0, 0), ("punch", 2, 0, 0), ("nv_cork", 3, 0, 0), ("nv_roll", 0, 2, 0), ("nv_liver", 2, 2, 0), ("duck", 5, 3, 0)]),
        ("복싱 가방 2", [("nv_liver", 0, 0, 0), ("punch", 2, 0, 0), ("upper", 3, 0, 0), ("nv_cork", 0, 2, 0), ("nv_flick", 4, 3, 0)]),
    ]
    /// 필살기 탭에서 주먹 계열 이름(네이티브 러시)
    public static let dojoSpcFist = "막차 러시(뎀프시)"

    // MARK: 새 적(웹 ETYPES 항목 JSON — EnemyDef 로 읽는다) · 노선 배치 · 무도장 상대
    // 생김새는 look.hair 의 'nv_' 머리 이름으로 고른다 → BBAnim NativeLooks(헤드기어 · 미식축구 헬멧 · 신문팔이 모자 · 몸 크기).
    // 재질 바꾸기(remap)는 0 — 정해 둔 색(빨강 헤드기어 · 파랑 저지 · 갈색 트위드)이 다른 적과 섞이지 않게 그대로 쓴다.
    static var enemyRows: [(String, [String: Any])] { [
        // 스파링꾼: 주인공 복싱의 거울 — 잽 · 잽 · 훅 · 어퍼, 잘 빠지고(evade) 팔로 쳐낸다(parry). 체력은 중간
        ("nv_spar", ["n": "스파링꾼", "hp": 34, "dmg": 8, "cd": 1.7, "spd": 40, "remap": 0, "moves": ["jab", "jab", "hook", "upper"], "reach": 24,
                     "evade": 0.35, "shield": true, "parry": true, "look": ["hair": "nv_spar", "coat": "WATER"]]),
        // 라인배커: 머리 박치기 · 몸통 돌진. 무겁고(heavy) 앞에서 오는 공격을 어깨 보호대로 막는다(shield) · 먼 거리는 크게 달려든다(dash)
        ("nv_lineback", ["n": "라인배커", "hp": 80, "dmg": 12, "cd": 2.8, "spd": 24, "dash": 120, "remap": 0, "moves": ["hbutt", "charge", "charge"], "reach": 26,
                         "heavy": true, "shield": true, "look": ["hair": "nv_lineback", "coat": "ARMOR"]]),
        // 신문팔이 소년: 거리를 두고 신문 뭉치를 던지고(range · 병 던지기 규칙) 붙으면 말아 쥔 신문으로 치고 빠진다(hitrun). 약하고 빠르다
        ("nv_newsboy", ["n": "신문팔이 소년", "hp": 18, "dmg": 5, "cd": 2.6, "spd": 50, "remap": 0, "range": 110, "moves": ["throw"], "reach": 22,
                        "hitrun": true, "wpn": "w_paper", "look": ["hair": "nv_newsboy", "coat": "WOOD"]]),
    ] }
    static let enemies: [(String, EnemyDef)] = enemyRows.map { ($0.0, try! JSONDecoder().decode(EnemyDef.self, from: json($0.1))) }
    /// 새 적 id(순서대로 — 도감 적 목록 끝)
    public static var enemyIDs: [String] { enemies.map(\.0) }
    /// 신문 뭉치를 던지는 적(투사체 모양 'news' · 맞으면 퍽 · 피해 5)
    public static let paperThrowers: Set<String> = ["nv_newsboy"]
    public static let paperShotDmg = 5.0

    /// 노선 배치 — 같은 수의 적을 바꿔 넣는다(웨이브 크기 · 난수 소비 수는 그대로). 역 분위기에 맞춰:
    ///   D 업타운(42번가 · 125번가 신문 가판) = 신문팔이 · 4 브롱크스 · L 브루클린(동네 복싱 체육관) = 스파링꾼 · 7 플러싱(메츠 구장) = 라인배커
    static let stagePatches: [StagePatch] = [
        StagePatch("D", .wave(car: 1, wave: 0), ["pick", "nv_newsboy", "punk"]),
        StagePatch("D", .wave(car: 3, wave: 1), ["nv_newsboy", "punk", "punk"]),
        StagePatch("D", .wave(car: 5, wave: 2), ["rusher", "punk", "nv_newsboy"]),
        StagePatch("D", .quick(car: 4, stop: 0), ["nv_newsboy", "punk"]),
        StagePatch("4", .wave(car: 1, wave: 0), ["nv_spar", "punk", "weasel"]),
        StagePatch("4", .wave(car: 2, wave: 1), ["gear", "brute", "nv_spar"]),
        StagePatch("4", .wave(car: 3, wave: 1), ["nv_spar", "weasel", "slasher"]),
        StagePatch("L", .wave(car: 3, wave: 2), ["punkg", "breaker", "nv_spar"]),
        StagePatch("L", .wave(car: 4, wave: 1), ["bouncer", "punkg", "nv_spar"]),
        StagePatch("7", .wave(car: 0, wave: 2), ["skater", "skater", "nv_newsboy"]),
        StagePatch("7", .wave(car: 3, wave: 1), ["nv_lineback", "skater", "thrower"]),
        StagePatch("7", .wave(car: 4, wave: 2), ["batter", "nv_lineback", "skater"]),
        StagePatch("7", .wave(car: 5, wave: 0), ["nv_lineback", "neonbig", "skater"]),
        StagePatch("7", .fight(car: 5), ["batter", "nv_lineback"]),
        StagePatch("7", .wave(car: 6, wave: 2), ["nv_lineback", "batter", "skater"]),
    ]

    /// 무도장 상대(웹 DJ_DUMMY 뒤에 붙는다 — 기존 적 3 + 새 적 3)
    public static let dojoDummies: [(key: String, name: String)] = [
        ("weasel", "얍삽한 놈"), ("kungfu", "권법가"), ("skater", "롤러 폭주족"),
        ("nv_spar", "스파링꾼"), ("nv_lineback", "라인배커"), ("nv_newsboy", "신문팔이 소년"),
    ]
}


// MARK: - 공방(docs/08 '공방 설계') — 공격 높이 · 가드 성향 · 군중(쿵후 영화의 원) 박자
// 버추어 파이터 문법: 서서 막기는 상단 · 중단을 막고 하단에 진다 / 앉아 막기는 하단을 막고 상단은 숙여 흘리며 중단에 진다 / 잡기는 가드를 무시한다.

/// 공격 높이
public enum NvHeight: Int, Sendable {
    case high = 1, mid = 2, low = 3, grab = 4
    public var name: String { ["", "high", "mid", "low", "grab"][rawValue] }
    /// 이 자세(1 서서 · 2 앉아)가 막는가
    func blockedBy(_ stance: Int) -> Bool { stance == 1 ? (self == .high || self == .mid) : stance == 2 ? self == .low : false }
    /// 앉아 막기가 숙여 흘리는가(상단)
    func whiffs(_ stance: Int) -> Bool { stance == 2 && self == .high }
}

extension NativeContent {
    /// 주인공 기술 높이(동작 이름 — 주먹 콤보는 잽 · 크로스 · 훅 · 어퍼 동작으로)
    ///  상단: 잽 · 크로스 · 훅 · 팔꿈치 · 백피스트 · 돌려차기 · 날아차기 · 자전거 · 플리커 · 코크스크루(관통) · 숄더 롤 · 신문 · 서류가방 휘두르기
    ///  중단: 어퍼컷(올려 치기 — 앉은 상대를 잡는다) · 앞차기 · 니킥 · 무릎 올려치기 · 파고들어 올려치기(1타 · 2타 모두) · 어깨 돌진 · 철산고 · 연환퇴 · 섬머솔트 · 뒤차기 · 도끼 차기(내려찍기) · 우산 찌르기 · 리버 블로(가드 아래로)
    ///  하단: 다리걸기 · 밟기     잡기: 잡아 메치기 · 수플렉스
    static let heroHeights: [String: NvHeight] = [
        "jab": .high, "cross": .high, "hook": .high, "elbow": .high, "bfist": .high, "round": .high, "round_air": .high, "fkick": .high, "cycle": .high,
        "swat": .high, "bat": .high, "hm_swing": .high, "hm_back": .high,
        "nv_flick": .high, "nv_cork": .high, "nv_roll": .high, "nv_beam": .high, "nv_dial": .high,
        "upper": .mid, "scoop": .mid, "nv_rise": .mid, "kick": .mid, "knee": .mid, "charge": .mid, "charge_air": .mid, "tetsu": .mid, "renkan": .mid, "skick": .mid, "nv_kneelift": .mid, "nv_duckup": .mid, "nv_slam": .mid, "nv_stamp": .mid,
        "bkick": .mid, "axe": .mid, "axe_air": .mid, "uthrust": .mid, "hm_up": .mid, "hm_down": .mid, "hangkick": .mid, "nv_liver": .mid,
        "sweep": .low, "stomp": .low, "nv_punt": .low,
        "throw": .grab, "suplex": .grab, "nv_headbutt": .grab,
    ]
    /// 적 공격 높이(웹 ETYPES moves 이름 + 네이티브 하단기)
    static let foeHeights: [String: NvHeight] = [
        "jab": .high, "hook": .high, "round": .high, "bat": .high, "fkick": .high, "throw": .high,
        "upper": .mid, "hbutt": .mid, "kick": .mid, "charge": .mid,
        "sweep": .low, "nv_lowk": .low,
    ]
    public static func heroHeight(_ anim: String) -> NvHeight { heroHeights[anim] ?? .high }
    public static func foeHeight(_ mv: String) -> NvHeight { foeHeights[mv] ?? .high }
    /// 가드 부수기: 서서 막기 팔 아래로 파고든다(막히지 않고 게이지를 크게 깎는다) — 리버 블로
    static let underGuard: Set<String> = ["nv_liver"]
    /// 가드 게이지를 깎는 양(칸): 무게 L 1 · M 1.5 · H 2.5 / 리버 · 코크스크루(관통) 3
    static let drainW: [String: Double] = ["L": 1, "M": 1.5, "H": 2.5]
    static let breakerDrain = 3.0
    /// 적이 막아도 깎이는 몫(피해 배율 — 주인공은 막으면 0)
    static let chipK = 0.4
    /// 적 하단기 예고 무게(웹 FOE_W 꼴 — SimData 가 깃발 켜짐에서 합친다) · 맞힘 배율(웹 foeHit km 꼴)
    static let foeW: [String: String] = ["sweep": "M", "nv_lowk": "M"]
    static let foeKM: [String: Double] = ["sweep": 1.0, "nv_lowk": 0.9]

    /// 적 가드 성향
    struct GuardStyle {
        /// 가드 게이지 칸 수(막을 때마다 L 1 · M 1.5 · H 2.5 씩 준다)
        var meter = 2.5
        /// 공격권을 쥔 채 공격 사이에 가드를 올릴 확률
        var holdP = 0.3
        /// 대기 중 앉아 막기를 고를 몫
        var lowP = 0.22
        /// 도발 · 페인트를 하는가 · 하단기(이름)와 쓰는 몫
        var taunt = false, feint = true
        var lowMove: String? = nil, lowUse = 0.0
        /// 쳐내기(권법가 · 스파링꾼 — 막는 대신 팔로 쳐낸다) · 앞 방패(우산 · 프라이팬 · 손전등 · 라인배커 — 서 있기만 해도 앞을 막는다)
        var parry = false, shield = false
    }
    static func guardStyle(_ t: String, _ d: EnemyDef) -> GuardStyle {
        var g = GuardStyle()
        if d.heavy == true { g.meter = 5; g.holdP = 0.2; g.feint = false; g.lowP = 0.1 }
        if d.boss == true { g.meter = 9; g.holdP = 0.25; g.feint = false; g.lowP = 0.15 }
        if d.hitrun == true { g.meter = 3; g.holdP = 0.15; g.lowP = 0.15 }
        g.parry = d.parry == true; g.shield = d.shield == true
        switch t {
        case "guard", "chef": g.meter = 6; g.holdP = 0.6; g.lowP = 0.2
        case "guardL": g.meter = 6; g.holdP = 0.5
        case "kungfu": g.meter = 5; g.holdP = 0.55; g.lowP = 0.45; g.taunt = true; g.lowMove = "sweep"; g.lowUse = 0.3
        case "nv_spar": g.meter = 5; g.holdP = 0.6; g.lowP = 0.4; g.taunt = true; g.lowMove = "nv_lowk"; g.lowUse = 0.3
        case "nv_lineback": g.meter = 8; g.holdP = 0.5; g.lowP = 0
        case "weasel": g.meter = 3; g.taunt = true; g.lowMove = "nv_lowk"; g.lowUse = 0.35
        case "breaker": g.meter = 3; g.taunt = true; g.lowMove = "sweep"; g.lowUse = 0.35
        case "boss3": g.lowMove = "sweep"; g.lowUse = 0.25; g.lowP = 0.3
        case "kaneB": g.holdP = 0.4; g.lowP = 0.3
        case "punk", "triad", "gear", "skater", "pick", "valet", "punkg", "slasher", "swords", "blade": g.taunt = true
        default: break
        }
        return g
    }
    /// 주인공 가드 게이지 칸 수
    static let heroMeter = 4.0

    /// 군중(쿵후 영화의 원) 박자 — 공격권(토큰)을 쥔 적만 붙어서 친다
    enum Crowd {
        /// 대기 자리(주인공과의 거리) — 첫 자리 · 간격(겹치지 않게)
        static let slot0 = 36.0, slotGap = 19.0, slotMin = 17.0
        /// 공격권 넘김 숨 고르기(초) · 공격권 쥔 적의 쿨다운 배율(압박 유지)
        static let grantMin = 0.3, grantSpread = 0.3, holderCD = 0.78
        /// 끼어들기: 판 전체 간격(초) · 예고에 더하는 초
        static let cutGap = 5.0, cutTell = 0.24
    }
}
