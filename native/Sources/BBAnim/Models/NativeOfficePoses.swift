import Foundation

// 직장인 기술(SimConfig.nativeMoves · docs/07 §7-OF · 내선 연결 §7-PH) — 우리 인물 비율(큰 머리 · 큰 상체 · 짧은 다리)에 맞춰 몸통 · 머리 · 팔 실루엣으로 읽히게.
//  · 서류가방 내려찍기(nv_slam — cs_*): 웅크림 → 뛰어오르며 가방을 뒤로 젖힘 → 꼭대기에서 머리 위로 → 큐 cs_hit(앞 아래로 내려찍기) → 떨어짐 → 착지 웅크림.
//    가방은 뒷손(F — 화면 쪽) 무기 w_case, w = 무기 각도(22.5° 단위 — 0 아래 · 4 앞 · 8 위 · 12 뒤).
//  · 결재 쌍장(nv_stamp — ss_*): 두 손바닥을 허리에 장전 → 크게 미끄러져 내디딤 → 큐 ss_hit(두 손바닥을 가슴 높이로 쭉) → 밀어붙임 → 가드.
//  · 멱살 박치기(nv_headbutt — hb_*): 앞손을 뻗어 멱살 → 끌어당김 → 고개 젖힘 → 1타(hb_hit1) → 더 크게 젖힘 → 큐 hb_hit2(큰 머리로 내리박기) → 놓고 물러섬.
// 문법: 다리 · 팔 모두 각도 값(NativeKneePoses 와 같다 — 다리 0° 앞 · −90° 아래 · 무릎은 허벅지 기준 굽힘 / 팔 0 아래 · 4 앞 · 8 위 · 12 뒤, 22.5° 단위).
//   F = 뒷다리 · 뒷팔(화면 쪽 — 무기를 쥔다) · B = 앞다리 · 앞팔. 칸 길이는 20fps 칸(50ms) 배수.

extension NativeMoves {
    /// 각도 값 자세 — leg = (뒷 허벅지, 뒷 무릎, 앞 허벅지, 앞 무릎)(도) · arm = (뒷 위팔, 뒷 아래팔, 앞 위팔, 앞 아래팔)(22.5°)
    private static func OF(t: Double, ty: Double = 0, hn: Double? = nil, air: Double = 0, r: Double = 0, bx: Double = 0, by: Double = 0, w: Double = 4,
                           leg: (Double, Double, Double, Double), arm: (Double, Double, Double, Double),
                           legH: Double? = nil, str: Double? = nil, smear: String? = nil, impact: Bool? = nil, snap: Bool? = nil) -> Pose {
        var p = Pose()
        p.r = r; p.b = V2(bx, by); p.h = V2(1, 1); p.t = t; p.ty = ty; p.hn = hn; p.air = air; p.w = w
        p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0)   // 각도 값이 아닌 자세와 섞일 때의 대략값
        p.legFK = true; p.lFT = leg.0; p.lFK = leg.1; p.lBT = leg.2; p.lBK = leg.3; p.legH = legH
        p.armFK = true; p.uF = arm.0; p.lF = arm.1; p.uB = arm.2; p.lB = arm.3
        p.strF = str; p.strB = str   // 아래팔 늘이기(쌍장 — 짧은 팔이 몸 밖으로 뻗어 보이게)
        p.smear = smear; p.impact = impact; p.snap = snap
        return p
    }

    static let ofPoses: [String: Pose] = [
        // ── 서류가방 내려찍기 ──
        // 1 웅크림: 무릎을 깊게 굽혀 뛸 준비 · 가방은 뒤 아래로 늘어뜨려 반동
        "cs_set": OF(t: 1.0, ty: -0.2, hn: 8, r: 1, w: 0, leg: (-120, -40, -62, -72), arm: (14, 14.5, 4.4, 7.2)),
        // 2 도약: 몸을 펴며 뛰어오른다 · 가방이 뒤 위로 휘둘려 올라간다 · 무릎을 끌어 올린다
        "cs_jump": OF(t: -0.3, hn: -2, air: 16, r: 1, w: 11, leg: (-95, -75, -25, -95), arm: (13, 13.5, 7.5, 9), smear: "b"),
        // 3 꼭대기: 두 손으로 가방을 머리 위 뒤로 젖힌다 · 등을 활처럼 · 다리는 앞으로 접는다
        "cs_top": OF(t: -1.2, ty: 0.2, hn: -10, air: 28, w: 10, leg: (-40, -110, 5, -115), arm: (9.2, 10.4, 8.6, 9.8)),
        // 4 내려찍기(큐): 몸을 앞으로 접으며 가방을 앞 아래로 내리꽂는다 · 앞다리가 바닥을 찾는다
        "cs_hit": OF(t: 1.9, ty: 0.3, hn: 18, air: 18, r: 2, w: 3, leg: (-70, -60, -88, -14), arm: (3.6, 3, 3.4, 2.8), impact: true, snap: true),
        // 5 떨어짐: 접은 채 내려온다 · 가방은 아래로
        "cs_fall": OF(t: 1.6, ty: 0.2, hn: 14, air: 7, r: 2, w: 1.5, leg: (-100, -30, -78, -24), arm: (2.6, 1.8, 3, 2.4)),
        // 6 착지: 깊게 웅크려 받는다 · 가방이 바닥 앞에
        "cs_land": OF(t: 1.7, ty: 0.2, hn: 12, r: 2, w: 2, leg: (-128, -34, -52, -84), arm: (2.6, 1.6, 3.2, 3)),
        // 7 일어남: 가방을 옆에 늘어뜨리고 가드
        "cs_rec": OF(t: 0.8, ty: -0.1, hn: 4, r: 1, w: 0.5, leg: (-108, -16, -76, -30), arm: (1.2, 0.6, 4.4, 7.2)),

        // ── 결재 쌍장 ── (내디딤 · 쌍장 · 밀어붙임 칸은 감독 자세 편집기 값 그대로 — 2026-10-14: 몸을 살짝 돌림 spin · 앞다리 더 앞 · 뒷무릎 펴짐 · 밀어붙임 다리 벌림)
        // 1 장전: 낮게 가라앉으며 두 손바닥을 허리 옆으로 당긴다(팔꿈치 뒤) · 몸을 살짝 돌린다
        "ss_set": OF(t: 0.5, ty: -0.4, hn: 6, r: -1, leg: (-118, -22, -64, -52), arm: (11, 4, 10.6, 4.2)),
        // 2 내디딤: 앞발을 크게 미끄러져 내딛는다 · 뒷다리 길게 · 손은 아직 허리
        "ss_step": { var p = Pose(); p.r = 2; p.b = V2(1, 0); p.h = V2(1, 1); p.t = 0.7; p.ty = -0.2; p.air = 0; p.spin = -0.041666666666666664; p.hn = 6; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 11.2; p.lF = 4; p.uB = 10.8; p.lB = 4.2; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -140; p.lFK = 16; p.lBT = -36; p.lBK = -46; p.smear = "b"; return p }(),
        // 3 쌍장(큐): 두 손바닥을 가슴 높이로 쭉 · 몸통이 앞으로 실린다 · 긴 앞굽이
        "ss_hit": { var p = Pose(); p.r = 4; p.b = V2(2, 0); p.h = V2(1, 1); p.t = 1; p.ty = 0.25; p.air = 0; p.spin = -0.041666666666666664; p.hn = 2; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.strF = 1.6; p.strB = 1.6; p.w = 4; p.armFK = true; p.uF = 4.3; p.lF = 4.1; p.uB = 4.1; p.lB = 3.9; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -148; p.lFK = 25; p.lBT = -28; p.lBK = -52; p.snap = true; p.impact = true; return p }(),
        // 4 밀어붙임: 손바닥을 끝까지 밀어 낸 채 버틴다
        "ss_push": { var p = Pose(); p.r = 4; p.b = V2(2, 0); p.h = V2(1, 1); p.t = 1.2; p.ty = 0.3; p.air = 0; p.spin = -0.041666666666666664; p.hn = 2; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.strF = 1.5; p.strB = 1.5; p.w = 4; p.armFK = true; p.uF = 4.4; p.lF = 4.2; p.uB = 4.2; p.lB = 4; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.sprF = 15; p.legFK = true; p.lFT = -150; p.lFK = 26; p.lBT = -29; p.lBK = -59; return p }(),
        // 5 가드로: 다리를 모으며 손을 거둔다
        "ss_rec": OF(t: 0.7, ty: -0.1, hn: 4, r: 2, leg: (-110, -12, -72, -30), arm: (4.4, 7.4, 4.2, 7)),

        // ── 멱살 박치기 ──
        // 1 뻗기: 앞손을 쭉 뻗어 멱살을 낚아챈다 · 반 걸음 들어간다
        "hb_reach": OF(t: 0.9, ty: 0.2, hn: 4, r: 3, bx: 1, leg: (-125, -6, -60, -30), arm: (4.4, 7.4, 4.3, 4.2)),
        // 2 끌어당김: 멱살을 쥔 주먹을 가슴으로 · 뒷손도 옷깃을 잡는다
        "hb_grab": OF(t: 0.4, ty: 0.1, hn: 0, r: 1, leg: (-115, -10, -68, -24), arm: (4.0, 5.2, 3.8, 5.0)),
        // 3 젖힘: 고개 · 상체를 뒤로 젖혀 머리를 장전
        "hb_back1": OF(t: -1.3, ty: 0, hn: -22, r: -1, leg: (-112, -14, -72, -22), arm: (3.6, 4.6, 3.4, 4.6)),
        // 4 1타: 머리로 짧게 박는다
        "hb_hit1": OF(t: 2.2, ty: 0.1, hn: 26, r: 3, bx: 2, leg: (-128, -4, -60, -38), arm: (3.8, 5.0, 3.6, 5.0), snap: true),
        // 5 크게 젖힘: 활처럼 크게 · 상대를 더 끌어당긴다
        "hb_back2": OF(t: -1.9, ty: -0.1, hn: -28, r: -2, leg: (-110, -18, -74, -20), arm: (3.4, 4.4, 3.2, 4.4)),
        // 6 2타(큐): 큰 머리로 내리박는다 · 몸 전체가 앞으로 쏠린다
        "hb_hit2": OF(t: 2.7, ty: 0.2, hn: 32, r: 5, bx: 3, leg: (-142, -2, -50, -52), arm: (3.8, 5.0, 3.6, 5.0), impact: true, snap: true),
        // 7 놓음: 손을 풀며 반 걸음 물러나 고개를 턴다
        "hb_rec": OF(t: 0.3, ty: -0.1, hn: 8, r: 0, leg: (-108, -12, -74, -24), arm: (4.4, 7.4, 4.2, 7)),

        // ── 내선 연결(수화기 던져 끌어오기 — 감독 마네킹 자세표 2026-10-14: 던지기 · 감기 시작 · Yanking · Pulling hard · Uppercut prep) ──
        // 끌어당김 · 어퍼컷 장전 칸은 감독 자세 편집기 값 그대로(2026-10-14: 끌어당김 뒷다리를 아래로 · 무릎을 더 굽혀 버팀 · 앞다리 덜 뻗음 / 장전 뒷다리 세움 · 상체를 뒤로)
        // 수화기 · 전화선은 무대 픽셀(NativeCordArt)이 뒷손(F) 자리에 그린다 — 자세는 팔 · 몸통 실루엣만.
        // 1 장전: 수화기를 쥔 뒷손을 귀 뒤로 젖히고 앞손은 상대를 겨눈다 · 몸을 뒤로 비튼다
        "ph_set": OF(t: -0.7, ty: -0.1, hn: -4, r: -1, bx: -1, leg: (-122, -18, -62, -38), arm: (10.5, 7.5, 4.2, 4.4)),
        // 2 던지기: 앞발을 크게 디딘 런지 · 던진 뒷팔은 어깨 높이로 일직선(팔-선-수화기 한 줄) · 앞팔은 뒤 아래로
        "ph_throw": OF(t: 1.3, ty: 0.25, hn: 6, r: 3, bx: 2, leg: (-150, 22, -30, -50), arm: (4.2, 4.0, 14.5, 14), snap: true),
        // 3 뻗은 채(날아가는 동안): 던진 자세 그대로 조금 가라앉는다
        "ph_reach": OF(t: 1.1, ty: 0.3, hn: 4, r: 3, bx: 2, leg: (-148, 20, -32, -52), arm: (4.1, 4.0, 14.2, 13.6)),
        // 4 감기 시작(큐 — 걸렸다): 몸통을 정면으로 돌리며 선을 쥔 뒷손을 허리로 확 당긴다 · 앞손은 아직 앞
        "ph_catch": OF(t: -0.2, ty: 0.05, hn: 0, r: 0, leg: (-115, -14, -66, -26), arm: (13.4, 3.2, 4.0, 4.2), snap: true),
        // 5 버티기(Yanking): 다리를 넓게 · 두 손으로 선을 가슴 앞에 · 상체는 꼿꼿이
        "ph_yank": OF(t: -0.6, ty: 0.1, hn: -2, r: -1, leg: (-124, -22, -58, -24), arm: (2.6, 4.6, 3.0, 4.4)),
        // 6 끌어당김(Pulling hard): 상체를 크게 뒤로 젖히고 뒷무릎을 깊게 굽혀 주저앉듯 · 손은 가슴으로 · 앞다리는 쭉 버틴다
        "ph_haul": { var p = Pose(); p.r = -2; p.b = V2(-2, 0); p.h = V2(1, 1); p.t = -1.5; p.ty = 0.4; p.air = 0; p.hn = -8; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 1.8; p.lF = 6.2; p.uB = 2.4; p.lB = 5.8; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -86; p.lFK = -51; p.lBT = -51; p.lBK = -8; return p }(),
        // 7 어퍼컷 장전(Uppercut prep): 앞발 디딤 · 뒷주먹을 허리 아래로 장전 · 앞손은 선을 늘어뜨린다
        "ph_ready": { var p = Pose(); p.r = 1; p.b = V2(0, 0); p.h = V2(1, 1); p.t = -0.6666666666666666; p.ty = 0.15; p.air = 0; p.hn = 4; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 13; p.lF = 5.2; p.uB = 1.2; p.lB = 0.8; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -99; p.lFK = -24; p.lBT = -56; p.lBK = -40; return p }(),

        // ── 구두 슛(쓰러진 적을 축구공처럼 — 2026-10-14 · 감독 레퍼런스 5장으로 재구성 → 감독이 포즈 편집기로 6장 모두 손본 값: 깡충 내딛기 → 착지 → 아래에서 쓸어 차기 → 수평 팔로스루) ── 차는 다리 = 뒷다리(F — 화면 쪽)
        // 상체를 크게 뒤로 젖혀야 상의가 다리에서 멀어져 짧은 다리(13px)를 수평까지 올려도 가려지지 않는다.
        // 골반 높이는 더 낮은 발이 정한다 → 차는 순간 차는 발은 디딘 발보다 위(−45°)여야 런지처럼 보이지 않는다.
        // 1 깡충 내딛기: 앞무릎을 들어 크게 한 걸음 뛰어든다 · 뒷다리는 뒤로 끌린다 · 팔은 달리듯(살짝 뜬다)
        "pk_step": { var p = Pose(); p.r = 1; p.b = V2(1, 0); p.h = V2(1, 1); p.t = 0.5; p.ty = 0.1; p.air = 4; p.spin = 0; p.hn = 4; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = -0.3111111111111111; p.lF = 0.8888888888888888; p.uB = 2.933333333333333; p.lB = 4.433333333333339; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -152; p.lFK = -46; p.lBT = -28; p.lBK = -70; p.smear = "b"; return p }(),
        // 2 착지: 누운 몸 바로 위에 꼿꼿이 선다 · 차는 다리는 몸 아래에서 살짝 굽힌다 · 두 팔은 벌려 균형
        "pk_plant": { var p = Pose(); p.r = 0; p.b = V2(0, 0); p.h = V2(1, 1); p.t = 0.3; p.ty = 0.05; p.air = 0; p.hn = 8; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 1.7777777777777777; p.lF = 3.777777777777777; p.uB = -0.35555555555555557; p.lB = 1.6444444444444515; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -115; p.lFK = -45; p.lBT = -92; p.lBK = -10; return p }(),
        // 3 쓸어 냄(번짐 칸): 차는 다리가 몸 아래를 지나 앞으로 · 상체가 뒤로 기울기 시작
        "pk_swing": { var p = Pose(); p.r = 1; p.b = V2(0, 0); p.h = V2(1, 1); p.t = -0.4; p.ty = 0.1; p.air = 0; p.hn = 8; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 3.2888888888888888; p.lF = 4.28888888888889; p.uB = -2.1777777777777776; p.lB = -1.5999999999999996; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.legFK = true; p.lFT = -85; p.lFK = -25; p.lBT = -96; p.lBK = -16; p.smear = "b"; return p }(),
        // 4 차기(큐): 허벅지를 수평 위까지 걷어 올린다(앞코가 머리 · 어깨에) · 고개를 젖힌다 — 2026-10-14 감독 포즈 값 그대로
        "pk_hit": { var p = Pose(); p.r = 2; p.b = V2(1, 0); p.h = V2(1, 1); p.t = -0.4444444444444444; p.ty = 0.15; p.air = 0; p.hn = 13; p.hy = 8; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = 2.0444444444444443; p.lF = 2.544444444444445; p.uB = -1.7777777777777777; p.lB = -1.277777777777778; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.strL = 1.2; p.legFK = true; p.lFT = 16; p.lFK = -38; p.lBT = -100; p.lBK = -18; p.snap = true; p.impact = true; return p }(),
        // 5 팔로스루: 다리가 수평 위에 남는다 · 팔은 앞뒤로 벌려 균형 — 감독 포즈 값 그대로
        "pk_follow": { var p = Pose(); p.r = 1; p.b = V2(1, 0); p.h = V2(1, 1); p.t = -0.4444444444444444; p.ty = 0.1; p.air = 0; p.hn = 12; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = -1.3333333333333333; p.lF = 0.4444444444444444; p.uB = 2.4; p.lB = 3.2444444444444445; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.strL = 1.3; p.legFK = true; p.lFT = 15; p.lFK = -31; p.lBT = -100; p.lBK = -11; return p }(),
        "pk_rec": { var p = Pose(); p.r = 1; p.b = V2(0, 0); p.h = V2(1, 1); p.t = 0.3; p.ty = 0; p.air = 0; p.hn = 4; p.aF = 5; p.eF = 0.5; p.aB = 5; p.eB = 0.5; p.w = 4; p.armFK = true; p.uF = -0.8888888888888888; p.lF = 2.1111111111111165; p.uB = -0.13333333333333333; p.lB = 2.6666666666666736; p.fF = V2(-0.4, 0); p.fB = V2(0.5, 0); p.sprF = 4; p.legFK = true; p.lFT = -43; p.lFK = -11; p.lBT = -76; p.lBK = -28; return p }(),
    ]

    /// 내려찍기: 웅크림 2 · 도약 2 · 꼭대기 2 · 내려찍기 1(큐 300ms) · 떨어짐 2 · 착지 2 · 일어남 3 · 서기 2 = 16칸(0.8초)
    /// 쌍장: 장전 2 · 내디딤 2 · 쌍장 1(큐 200ms) · 밀어붙임 3 · 가드 3 · 서기 2 = 13칸(0.65초)
    /// 박치기: 뻗기 2 · 끌어당김 2 · 젖힘 2 · 1타 2(300ms) · 크게 젖힘 2 · 2타 1(큐 500ms) · 놓음 3 · 서기 2 = 16칸(0.8초)
    static let ofSequences: [String: [SeqStep]] = [
        "nv_slam": S([("cs_set", 100), ("cs_jump", 100), ("cs_top", 100), ("cs_hit", 50), ("cs_fall", 100), ("cs_land", 100), ("cs_rec", 150), ("c_over", 100)]),
        "nv_stamp": S([("ss_set", 100), ("ss_step", 100), ("ss_hit", 50), ("ss_push", 150), ("ss_rec", 150), ("c_over", 100)]),
        "nv_headbutt": S([("hb_reach", 100), ("hb_grab", 100), ("hb_back1", 100), ("hb_hit1", 100), ("hb_back2", 100), ("hb_hit2", 50), ("hb_rec", 150), ("c_over", 100)]),
        "nv_punt": S([("pk_step", 100), ("pk_plant", 100), ("pk_swing", 50), ("pk_hit", 50), ("pk_follow", 150), ("pk_rec", 150), ("c_over", 100)]),
        "nv_dial": S([("ph_set", 100), ("ph_throw", 50), ("ph_reach", 150), ("ph_catch", 50), ("ph_yank", 100), ("ph_haul", 150), ("ph_ready", 100), ("c_over", 100)]),
    ]
    /// 내선 연결: 장전 2 · 던지기 1 · 날아감 3 · 감기 1(큐 300ms — 수화기가 닿는 순간) · 버티기 2 · 끌어당김 3 · 어퍼컷 장전 2 · 서기 2 = 16칸(0.8초)
    /// 구두 슛: 깡충 내딛기 2 · 착지 2 · 쓸어 냄 1 · 차기 1(큐 250ms) · 팔로스루 3 · 내려딛음 3 · 서기 2 = 14칸(0.7초)
    ///   끌기(0.25초)는 걸린 순간 경직(0.1초) 뒤 감기 · 버티기 · 끌어당김 칸과 겹친다
    static let ofCues: [String: String] = ["nv_slam": "cs_hit", "nv_stamp": "ss_hit", "nv_headbutt": "hb_hit2", "nv_dial": "ph_catch", "nv_punt": "pk_hit"]
}
