import Foundation

// (러시 타격 자세는 impact 를 달지 않는다 — 동작 요청 없이 impact 자세에 들어서면 웹 strike() 처럼 화면 전체가 7칸 멈춰 박자가 무너진다)
// 네이티브 전용 동작(웹에 없음 — SimConfig.nativeMoves 가 켜졌을 때만 시뮬레이션이 부른다). docs/06 §8 '네이티브 동작 개편'.
//  · 이동: 출발 기울기(nv_go) · 스텝 인(nv_step) · 미끄러져 서기(nv_skid) · 질주 키(nv_run0…5 — Gait.nvRunPose)
//  · 필살기 '막차 러시'(뎀프시 롤 풍): 위빙(좌우 8자) · 좌우 훅 · 올려치기 마무리(nv_dr*)
//  · 복싱 기술: 플리커 잽 · 리버 블로 · 코크스크루 블로 · 숄더 롤 카운터 · (스매시 포즈는 어퍼컷에 통합 — overrideSequences)
//  · 버추어 파이터 참고 두 기술: 무릎 올려치기 · 파고들어 올려치기(NativeVFPoses)
// 웹 포즈 표(POSES)와 같은 문법 — 값은 JW_HERO 리그 기준(각도 22.5° 단위 · 발 목표는 다리 길이 단위 · b/h 는 [앞, 아래] px).
//  팔: B 팔 = 앞손(잽 · 리드 훅), F 팔 = 뒷손(크로스 · 리어 훅 · 어퍼). ty + = F 어깨가 앞으로(뒷손을 낼 때), ty − = B 어깨가 앞으로.
//  발: fB = 앞발(+x), fF = 뒷발(−x).
// 이 표는 웹 대조 대상이 아니다 — 기본 표(AnimTables · SequenceTable)는 그대로 두고 withNativeMoves() 로 합친 복사본을 쓴다.

public enum NativeMoves {
    /// 포즈 한 개(웹 POSES 항목과 같은 필드만)
    static func P(r: Double = 0, b: (Double, Double), h: (Double, Double), t: Double, ty: Double,
                  aF: Double, eF: Double, aB: Double, eB: Double, fF: (Double, Double), fB: (Double, Double),
                  strF: Double? = nil, strB: Double? = nil, upF: Bool? = nil, upB: Bool? = nil, air: Double? = nil,
                  smear: String? = nil, impact: Bool? = nil, snap: Bool? = nil) -> Pose {
        var p = Pose()
        p.r = r; p.b = V2(b.0, b.1); p.h = V2(h.0, h.1); p.t = t; p.ty = ty
        p.aF = aF; p.eF = eF; p.aB = aB; p.eB = eB; p.w = 4
        p.fF = V2(fF.0, fF.1); p.fB = V2(fB.0, fB.1)
        p.strF = strF; p.strB = strB; p.upF = upF; p.upB = upB; p.air = air
        p.smear = smear; p.impact = impact; p.snap = snap
        return p
    }

    /// 새 키 포즈(이름은 모두 기존 POSES 와 겹치지 않는다)
    public static let poses: [String: Pose] = [
        // ── 이동 ──
        // 출발: 뒷발로 바닥을 밀며 몸을 앞으로 던진다(가드는 유지)
        "nv_go": P(r: 1, b: (0, 6), h: (2, 2), t: 2.7, ty: -0.3, aF: 5.4, eF: 0.4, aB: 5.0, eB: 0.5, fF: (-0.78, 0), fB: (0.32, 0)),
        // 스텝 인: 앞발을 크게 내딛고 뒷발이 끌려온다(셔플) — 가드 높게
        "nv_step0": P(r: 3, b: (1, 5), h: (2, 2), t: 2.1, ty: -0.5, aF: 5.8, eF: 0.36, aB: 5.0, eB: 0.6, fF: (-0.62, 0), fB: (0.85, -0.12)),
        "nv_step1": P(r: 2, b: (1, 4), h: (1, 1.5), t: 1.8, ty: -0.45, aF: 5.7, eF: 0.36, aB: 5.1, eB: 0.6, fF: (-0.4, -0.06), fB: (0.66, 0)),
        // 미끄러져 서기: 앞발을 박고 상체를 뒤로 젖혀 속도를 죽인다 → 가드로 가라앉기
        "nv_skid0": P(r: -2, b: (-1, 7), h: (0, 2), t: 0.5, ty: -0.6, aF: 5.2, eF: 0.5, aB: 4.7, eB: 0.62, fF: (-0.5, 0), fB: (1.0, 0)),
        "nv_skid1": P(r: -1, b: (0, 5), h: (1, 1.6), t: 1.3, ty: -0.5, aF: 5.6, eF: 0.4, aB: 5.0, eB: 0.6, fF: (-0.5, 0), fB: (0.72, 0)),

        // ── 막차 러시(뎀프시 롤 풍) ──
        // 들어가기: 피카부 가드로 낮게 웅크린다
        "dr_in": P(r: 1, b: (0, 9), h: (2, 3), t: 2.6, ty: 0, aF: 6.6, eF: 0.3, aB: 6.4, eB: 0.32, fF: (-0.6, 0), fB: (0.55, 0)),
        // 위빙: 머리를 낮춰 좌우로 굴린다(8자) — wL = 몸이 B 쪽(리드)으로 기울며 F 훅을 장전, wR = 반대
        // 크게: 몸통(t) · 비틀기(ty) · 골반 앞뒤(r · b.x) · 무릎(b.y 13 = 깊게 굽힘) · 머리 궤적(h)을 같이 흔들어 화면에서 6~10px 좌우로 읽히게(감독 피드백)
        "dr_wL": P(r: -5, b: (-3, 13), h: (-3, 6), t: 1.3, ty: 1.2, aF: 6.4, eF: 0.3, aB: 6.8, eB: 0.3, fF: (-0.72, 0), fB: (0.52, 0)),
        "dr_wR": P(r: 3, b: (3, 13), h: (5, 7), t: 3.4, ty: -1.2, aF: 6.8, eF: 0.3, aB: 6.2, eB: 0.32, fF: (-0.52, 0), fB: (0.72, 0)),
        // 리드(B) 훅: 왼쪽에서 휘어 들어온다 — 휘두름 칸 · 타격 칸
        "dr_hLs": P(r: 3, b: (0, 7), h: (1, 3), t: 2.0, ty: -0.6, aF: 6.4, eF: 0.32, aB: 4.8, eB: 0.5, fF: (-0.62, 0), fB: (0.62, 0),
                    strB: 1.25, upB: true, smear: "b"),
        "dr_hL": P(r: 8, b: (1, 4), h: (-2, 3), t: 1.9, ty: -1.6, aF: 6.4, eF: 0.32, aB: 4.2, eB: 0.58, fF: (-0.7, 0), fB: (0.62, 0),
                   upB: true, snap: true),
        // 리어(F) 훅: 반대편에서
        "dr_hRs": P(r: 3, b: (0, 7), h: (1, 3), t: 2.0, ty: 0.6, aF: 4.8, eF: 0.5, aB: 6.4, eB: 0.32, fF: (-0.62, 0), fB: (0.62, 0),
                    strF: 1.25, upF: true, smear: "b"),
        "dr_hR": P(r: 8, b: (1, 4), h: (-2, 3), t: 1.9, ty: 1.6, aF: 4.2, eF: 0.58, aB: 6.4, eB: 0.32, fF: (-0.74, 0), fB: (0.6, 0),
                   upF: true, snap: true),
        // 마무리: 깊게 가라앉았다가(dip) 뒷손 올려치기로 한 무더기를 띄운다
        "dr_fdip": P(r: -1, b: (-1, 12), h: (1, 4), t: 2.9, ty: -1.0, aF: 1.4, eF: 0.55, aB: 6.4, eB: 0.32, fF: (-0.66, 0), fB: (0.66, 0)),
        "dr_fsm": P(r: 5, b: (1, 2), h: (2, 0), t: 0.8, ty: 0.5, aF: 6.8, eF: 0.85, aB: 6.0, eB: 0.4, fF: (-0.55, 0), fB: (0.62, 0),
                    strF: 1.6, smear: "b"),
        "dr_fup": P(r: 7, b: (1, -2), h: (2, -2), t: -0.2, ty: 0.75, aF: 7.8, eF: 0.95, aB: 5.6, eB: 0.4, fF: (-0.42, -0.1), fB: (0.66, -0.18),
                    air: 6, snap: true),
        "dr_fup_ft": P(r: 8, b: (1, -3), h: (2, -2.4), t: -0.5, ty: 0.9, aF: 8.4, eF: 0.92, aB: 5.8, eB: 0.4, fF: (-0.4, -0.16), fB: (0.6, -0.28),
                       air: 9),
        "dr_land": P(r: 2, b: (0, 6), h: (1, 2), t: 1.8, ty: -0.3, aF: 5.8, eF: 0.4, aB: 5.0, eB: 0.6, fF: (-0.55, 0), fB: (0.62, 0)),

        // ── 플리커 잽(디트로이트식): 앞손을 허리 아래로 늘어뜨린 옆으로 선 낮은 가드 → 어깨가 먼저 솟고 손목이 아래→위 바깥 호로 채찍처럼 →
        //    같은 호로 즉시 회수. 앞팔은 FK(위팔 uB · 아래팔 lB 각도 — 0 아래 · 4 앞 · 8 위)로 '휘는 팔'을 직접 그린다(잽의 곧은 IK 팔과 다르게).
        //    몸통은 측면(ty −1.5 — 앞어깨가 앞으로 · 가슴이 옆을 본다)으로 세우고(t 0.9 — 잽 1.7 보다 꼿꼿), 뒷손은 턱 옆에 높게.
        "fl_load": FKB(P(r: -1, b: (-1, 2), h: (0, 0), t: 0.9, ty: -1.5, aF: 6.2, eF: 0.32, aB: 0, eB: 1, fF: (-0.55, 0), fB: (0.62, 0), snap: true), uB: 0.4, lB: 2.6),   // 손이 '툭' 떨어진다(섞지 않음)
        "fl_smear": FKB(P(r: 2, b: (0, 2), h: (1, -1), t: 0.8, ty: -1.75, aF: 6.2, eF: 0.32, aB: 0, eB: 1, fF: (-0.55, 0), fB: (0.72, 0), smear: "b"), uB: 2.6, lB: 3.0),
        "fl_hit": FKB(P(r: 5, b: (1, 2), h: (2, -1), t: 0.8, ty: -1.85, aF: 6.2, eF: 0.32, aB: 0, eB: 1, fF: (-0.58, 0), fB: (0.8, 0), impact: true, snap: true), uB: 4.3, lB: 5.0),
        "fl_hit_ft": FKB(P(r: 5, b: (1, 2), h: (2, -1), t: 0.8, ty: -1.8, aF: 6.2, eF: 0.32, aB: 0, eB: 1, fF: (-0.58, 0), fB: (0.8, 0)), uB: 4.6, lB: 6.2),
        "fl_rt": FKB(P(r: 2, b: (0, 2), h: (1, 0), t: 0.85, ty: -1.6, aF: 6.2, eF: 0.32, aB: 0, eB: 1, fF: (-0.55, 0), fB: (0.7, 0)), uB: 2.4, lB: 1.4),
        "fl_low": FKB(P(r: 0, b: (-1, 2), h: (0, 0), t: 0.9, ty: -1.45, aF: 6.0, eF: 0.34, aB: 0, eB: 1, fF: (-0.52, 0), fB: (0.6, 0)), uB: 0.5, lB: 2.4),
        // 플리커 장착 시 대기(감독 피드백): 낮은 손 가드로 천천히 숨쉬기 — 앞손은 허리 옆에 느슨히 늘어뜨리고(팔꿈치 살짝 굽힘)
        //   숨에 맞춰 몸이 1px 오르내리며 손끝이 조금만 흔들린다(칸 사이 차이를 작게 — 떨림 없이)
        "fl_idle0": FKB(P(r: 0, b: (-1, 2), h: (0, 0), t: 0.9, ty: -1.45, aF: 6.0, eF: 0.34, aB: 0, eB: 1, fF: (-0.52, 0), fB: (0.6, 0)), uB: 0.7, lB: 1.9),
        "fl_idle1": FKB(P(r: 0, b: (-1, 2.5), h: (0, 0.5), t: 0.95, ty: -1.45, aF: 6.0, eF: 0.35, aB: 0, eB: 1, fF: (-0.52, 0), fB: (0.6, 0)), uB: 0.8, lB: 2.05),
        "fl_idle2": FKB(P(r: 0, b: (-1, 3), h: (0, 1), t: 1.0, ty: -1.45, aF: 6.0, eF: 0.36, aB: 0, eB: 1, fF: (-0.52, 0), fB: (0.6, 0)), uB: 0.9, lB: 2.2),

        // ── 리버 블로: 앞쪽으로 몸을 숙여 낮게 파고들며 앞손 훅을 옆구리(간)에 ──
        "lv_load": P(r: 0, b: (0, 8), h: (2, 3), t: 2.3, ty: 0.7, aF: 6.2, eF: 0.32, aB: 3.4, eB: 0.5, fF: (-0.55, 0), fB: (0.62, 0)),
        "lv_smear": P(r: 4, b: (1, 8), h: (2, 3), t: 2.4, ty: -0.4, aF: 6.2, eF: 0.32, aB: 3.2, eB: 0.6, fF: (-0.62, 0), fB: (0.7, 0),
                      strB: 1.3, smear: "b"),
        "lv_hit": P(r: 6, b: (1, 8), h: (2, 3), t: 2.5, ty: -1.4, aF: 6.2, eF: 0.32, aB: 3.3, eB: 0.42, fF: (-0.68, 0), fB: (0.72, 0),
                    upB: true, impact: true, snap: true),
        "lv_hit_ft": P(r: 6.5, b: (1.2, 8), h: (2.4, 3), t: 2.5, ty: -1.6, aF: 6.2, eF: 0.32, aB: 3.2, eB: 0.4, fF: (-0.7, 0), fB: (0.72, 0), upB: true),
        "lv_rec": P(r: 3, b: (0, 5), h: (1, 2), t: 1.9, ty: -0.6, aF: 5.8, eF: 0.36, aB: 5.0, eB: 0.6, fF: (-0.55, 0), fB: (0.62, 0)),

        // ── 코크스크루 블로: 뒷손을 비틀어 꽂는 스트레이트(어깨 · 허리를 끝까지 돌린다) ──
        "ck_load": P(r: -1, b: (0, 4), h: (1, 1), t: 1.4, ty: -0.95, aF: 4.4, eF: 0.38, aB: 5.4, eB: 0.5, fF: (-0.55, 0), fB: (0.6, 0)),
        "ck_pull": P(r: -2, b: (0, 4.5), h: (0, 1), t: 1.3, ty: -1.1, aF: 4.0, eF: 0.35, aB: 5.6, eB: 0.5, fF: (-0.58, 0), fB: (0.6, 0)),
        "ck_smear": P(r: 6, b: (2, 3.5), h: (3, 1), t: 2.2, ty: 0.9, aF: 4.1, eF: 1, aB: 5.9, eB: 0.36, fF: (-0.82, 0), fB: (0.7, -0.06),
                      strF: 1.5, smear: "b"),
        "ck_hit": P(r: 8, b: (2, 3.5), h: (3.5, 1), t: 2.4, ty: 1.35, aF: 4.0, eF: 1, aB: 6.0, eB: 0.34, fF: (-0.88, 0), fB: (0.72, -0.08),
                    strF: 1.15, impact: true, snap: true),
        "ck_hit_ft": P(r: 9, b: (2.4, 3.6), h: (3.8, 1), t: 2.5, ty: 1.6, aF: 4.0, eF: 1, aB: 6.0, eB: 0.32, fF: (-0.9, 0), fB: (0.72, -0.1), strF: 1.1),
        "ck_rt": P(r: 4, b: (1, 3.5), h: (2, 1.1), t: 2.0, ty: 0.4, aF: 4.8, eF: 0.62, aB: 5.6, eB: 0.45, fF: (-0.68, 0), fB: (0.62, 0)),

        // ── 스매시 포즈(깃발 켜짐의 어퍼컷 — overrideSequences): 몸을 낮춰 뒷손을 비스듬히 퍼 올린다 ──
        "sm_load": P(r: 0, b: (0, 6), h: (1, 2), t: 2.0, ty: -0.8, aF: 2.6, eF: 0.55, aB: 5.4, eB: 0.5, fF: (-0.58, 0), fB: (0.58, 0)),
        "sm_dip": P(r: -1, b: (-1, 9), h: (1, 3), t: 2.5, ty: -1.0, aF: 1.8, eF: 0.55, aB: 5.6, eB: 0.5, fF: (-0.64, 0), fB: (0.62, 0)),
        "sm_smear": P(r: 5, b: (1, 3), h: (2, 1), t: 1.4, ty: 0.5, aF: 5.4, eF: 0.9, aB: 5.8, eB: 0.4, fF: (-0.55, 0), fB: (0.66, 0),
                      strF: 1.5, smear: "b"),
        "sm_hit": P(r: 7, b: (1, 1), h: (2, 0), t: 0.9, ty: 0.7, aF: 6.2, eF: 0.9, aB: 5.8, eB: 0.4, fF: (-0.5, -0.04), fB: (0.66, 0),
                    air: 1.5, impact: true, snap: true),
        "sm_hit_ft": P(r: 7.5, b: (1.2, 0), h: (2.2, -0.6), t: 0.6, ty: 0.85, aF: 6.8, eF: 0.92, aB: 5.8, eB: 0.4, fF: (-0.48, -0.08), fB: (0.66, 0), air: 2.4),
        "sm_rt": P(r: 3, b: (0.5, 3), h: (1.5, 1), t: 1.4, ty: 0.2, aF: 6.0, eF: 0.6, aB: 5.4, eB: 0.5, fF: (-0.5, 0), fB: (0.6, 0)),

        // ── 숄더 롤 카운터: ① 앞어깨를 턱 앞까지 올리고(sr_roll) ② 몸통을 뒤로 돌려 젖혀 흘리고(sr_roll2 — 가장 깊게, 뒷손은 허리에 장전)
        //    ③ 되감기 시작(sr_roll3) — 이 세 칸이 흘리기(SLIP) 판정 · 그 회전 반동으로 뒷손 크로스가 몸통째 튀어 나간다(크로스보다 비틀기 · 이동이 크다)
        "sr_roll": P(r: -2, b: (-1, 5), h: (-2, 4), t: 0.6, ty: -1.95, aF: 6.4, eF: 0.32, aB: 7.6, eB: 0.36, fF: (-0.62, 0), fB: (0.52, 0), upB: true, snap: true),
        "sr_roll2": P(r: -5, b: (-3, 6), h: (-4, 4), t: -0.7, ty: -2.1, aF: 2.6, eF: 0.42, aB: 7.4, eB: 0.38, fF: (-0.72, 0), fB: (0.42, 0), upB: true),
        "sr_roll3": P(r: -3, b: (-2, 6), h: (-2, 3.5), t: 0.3, ty: -1.4, aF: 3.0, eF: 0.4, aB: 6.8, eB: 0.4, fF: (-0.7, 0), fB: (0.5, 0), upB: true),
        "sr_ret": P(r: 0, b: (0, 4.5), h: (0, 2), t: 1.4, ty: -0.6, aF: 5.0, eF: 0.4, aB: 3.6, eB: 0.6, fF: (-0.6, 0), fB: (0.56, 0)),
        "sr_smear": P(r: 6, b: (2, 4), h: (3, 1.5), t: 2.0, ty: 1.0, aF: 4.1, eF: 1, aB: 6.4, eB: 0.4, fF: (-0.82, 0), fB: (0.7, -0.05),
                      strF: 1.5, smear: "b"),
        "sr_hit": P(r: 9, b: (2.5, 4), h: (3.5, 1.5), t: 2.4, ty: 1.3, aF: 4, eF: 1, aB: 6.0, eB: 0.4, fF: (-0.9, 0), fB: (0.72, -0.08),
                    strF: 1.15, impact: true, snap: true),
        "sr_hit_ft": P(r: 10, b: (2.8, 4), h: (4, 1.5), t: 2.5, ty: 1.45, aF: 4, eF: 1, aB: 5.9, eB: 0.4, fF: (-0.92, 0), fB: (0.74, -0.08), strF: 1.08),
        "sr_rt": P(r: 4, b: (1, 3.5), h: (2, 1.1), t: 2.0, ty: 0.3, aF: 4.9, eF: 0.6, aB: 5.3, eB: 0.5, fF: (-0.68, 0), fB: (0.62, 0)),
    ].merging(risePoses) { a, _ in a }.merging(vfPoses) { a, _ in a }.merging(klPoses) { a, _ in a }.merging(bmPoses) { a, _ in a }.merging(ofPoses) { a, _ in a }   // 직장인 세 기술(NativeOfficePoses) · 야근 광선(NativeBeamPoses) · 무릎 올려치기(NativeKneePoses) · 파고들어 올려치기(NativeVFPoses)

    // ── 퇴근 승천권(감독 참고 그림 rising_ref — 솟구치며 한 바퀴 도는 올려치기). 치는 손 = F(뒷손), 앞발 = B ──
    //  탁(웅크림 1칸) → 쭉(솟구침 · 꼭대기에서 멈칫) → 휘익(돌며 내려옴) → 쿵(깊게 눌려 착지 · 긴 회복)
    //  spin(몸 전체 돌기 — 바퀴)은 키마다 0.5 바퀴보다 작게 넘긴다(lerpPose 가 [-0.5, 0.5) 로 감아 짧은 쪽으로 돈다 — 정확히 0.5 는 거꾸로 돈다).
    //  0 → 0.06 → 0.25(옆) → 0.48(등) → 0.62 → 0.82 → 1.0(≡ 0, 정면) — 착지 이후는 1.0 그대로(c_over 의 0 과 같은 각도라 돌지 않는다)
    //  주먹은 얼굴 앞을 바짝 지나 수직으로(팔꿈치를 몸에 붙인 채 eF 0.42 → 0.75 → 1) · 앞무릎은 솟구치는 칸부터 높이(fB y −0.5 ~ −0.66) · 뒷다리는 곧게 늘어뜨린다
    static let risePoses: [String: Pose] = [
        // 1 웅크림: 무릎 깊게 · 치는 주먹은 허리에 장전 · 앞손은 턱 앞 · 몸통 살짝 비틀기(앞어깨가 앞)
        "rs_crouch": P(r: -1, b: (-1, 12), h: (1, 3.5), t: 2.4, ty: -1.1, aF: 1.4, eF: 0.32, aB: 6.8, eB: 0.3, fF: (-0.64, 0), fB: (0.6, 0)),
        // 2 솟구침(첫 타): 주먹이 얼굴 앞을 바짝 지나 위로 · 앞무릎을 차올린다 · 뜨기 시작
        "rs_launch": P(r: 2, b: (1, 2), h: (2, 0), t: 0.9, ty: 0.55, aF: 6.4, eF: 0.42, aB: 4.2, eB: 0.3, fF: (-0.56, 0), fB: (0.36, -0.5),
                       air: 9, smear: "b", impact: true, snap: true),
        // 3 오름(둘째 타): 팔이 펴지며 머리 위로 · 옆모습(¼ 바퀴)
        "rs_rise": P(r: 2, b: (1, 1), h: (1.5, 0), t: 0.25, ty: 0.85, aF: 7.4, eF: 0.75, aB: 4.0, eB: 0.28, fF: (-0.22, 0), fB: (0.42, -0.62),
                     air: 22, smear: "b"),
        // 4 꼭대기(큰 타 · 큐): 몸 전체가 한 줄로 · 팔은 머리 위로 쭉 · 머리는 팔 밑으로 · 빈 주먹은 가슴 · 앞무릎 높이 · 뒷발 늘어뜨림 · 등(½ 바퀴 직전)
        "rs_apex": P(r: 1, b: (0, 0), h: (0.5, 1.5), t: -0.4, ty: 1.0, aF: 8.0, eF: 1, aB: 3.6, eB: 0.28, fF: (-0.06, 0), fB: (0.4, -0.66),
                     strF: 1.1, air: 34, impact: true, snap: true),
        // 5 매달림(멈칫 — 0.1초): 꼭대기 그대로 조금 더 떠서 천천히 돈다
        "rs_hang": P(r: 1, b: (0, 0), h: (0.5, 1.6), t: -0.3, ty: 0.9, aF: 8.1, eF: 1, aB: 3.6, eB: 0.28, fF: (-0.08, 0), fB: (0.38, -0.64),
                     strF: 1.08, air: 37),
        // 6 내려옴: 주먹은 아직 위 · 두 무릎을 접는다
        "rs_fall": P(r: 0, b: (0, 2), h: (1, 1.2), t: 0.4, ty: 0.5, aF: 7.9, eF: 0.95, aB: 4.2, eB: 0.3, fF: (-0.2, -0.32), fB: (0.34, -0.46), air: 22),
        "rs_fall2": P(r: 0, b: (0, 3), h: (1, 1.5), t: 0.9, ty: 0.2, aF: 7.2, eF: 0.75, aB: 5.0, eB: 0.32, fF: (-0.4, -0.12), fB: (0.48, -0.16), air: 7),
        // 7 착지: 깊게 눌린다 → 천천히 일어선다(빈틈)
        "rs_land": P(r: 0, b: (0, 12), h: (1, 3.5), t: 2.1, ty: 0.15, aF: 4.2, eF: 0.42, aB: 5.0, eB: 0.36, fF: (-0.68, 0), fB: (0.64, 0)),
        "rs_rec": P(r: 0, b: (0, 7), h: (1, 2), t: 1.7, ty: -0.2, aF: 5.2, eF: 0.42, aB: 5.6, eB: 0.4, fF: (-0.6, 0), fB: (0.58, 0)),
    ].reduce(into: [String: Pose]()) { o, kv in
        var p = kv.value
        p.spin = ["rs_launch": 0.06, "rs_rise": 0.25, "rs_apex": 0.48, "rs_hang": 0.62, "rs_fall": 0.82, "rs_fall2": 1.0, "rs_land": 1.0, "rs_rec": 1.0][kv.key]
        o[kv.key] = p
    }

    // ── 질주(감독 참고 그림 run_ref — 16비트 벨트스크롤 달리기) — 키 6장(nvRunPose 가 보폭 위상 gph 로 고른다 · 시퀀스 칸 길이 없음) ──
    //  0 착지(F 발이 골반 앞에 닿고 B 정강이는 뒤로 차올림) → 1 눌림 · 지나감(몸 최저 · 웅크린 실루엣) → 2 체공(F 다리 뒤로 쭉 · B 무릎 높이, 두 발 다 뜸)
    //  → 3~5 좌우 반대. 팔은 다리 반대로 팔꿈치 90° — 앞주먹은 턱 높이까지, 뒷주먹은 엉덩이 뒤로.
    //  발 목표는 px(RIG_3D 다리 24 = 허벅지 11 + 정강이 13)로 적어 다리 길이 단위로 바꾼다. 딛은 발은 키 0→1 에서 11px 뒤로 = 질주 한 칸(65.5px/6) — 미끄럼 없음.
    //  팔은 FK(위팔 u · 아래팔 l, 22.5° 단위 — 0 아래 · 4 앞 · −4 뒤). 몸통 t 1.15~1.3(×leanK .6 ≈ 16~18° + 질주 기울기 nvm.lean)
    static func RUN(_ i: Int) -> Pose {
        let feet: [(Double, Double)] = [(7, 0), (-4, 0), (-17, -3), (-10, -13), (-1, -12), (7, -10)]
        let arms: [(Double, Double)] = [(-3.6, -0.3), (-0.6, 3.0), (1.8, 5.2), (2.4, 5.6), (0.4, 3.4), (-2.4, 0.9)]
        let by: [Double] = [1.5, 3, -0.5], air: [Double] = [0, 0, 3], t: [Double] = [1.35, 1.45, 1.3]
        let ty: [Double] = [-0.3, -0.08, 0.22, 0.3, 0.08, -0.22]
        let j = (i + 3) % 6, f = feet[i], g = feet[j]
        var p = Pose()
        p.r = 0; p.b = V2(0, by[i % 3]); p.h = V2(2.5, i % 3 == 1 ? 0.5 : 0); p.t = t[i % 3]; p.ty = ty[i]; p.air = air[i % 3]
        p.fF = V2((f.0 - 0.1) / 24, f.1 / 24); p.fB = V2((g.0 - 0.1) / 24, g.1 / 24)
        p.armFK = true; p.uF = arms[i].0; p.lF = arms[i].1; p.uB = arms[j].0; p.lB = arms[j].1
        return p
    }
    /// 질주 키(nv_run0…5)
    public static let runPoses: [String: Pose] = Dictionary(uniqueKeysWithValues: (0..<6).map { ("nv_run\($0)", RUN($0)) })

    static func S(_ a: [(String, Double)]) -> [SeqStep] { a.map { SeqStep(pose: $0.0, length: $0.1, blink: false) } }

    /// 새 동작 시퀀스(길이 ms — 게임 20fps 칸으로 반올림)
    public static let sequences: [String: [SeqStep]] = [
        "nv_go": S([("nv_go", 60)]),
        "nv_step": S([("nv_step0", 60), ("nv_step1", 50)]),
        "nv_skid": S([("nv_skid0", 9999)]),
        "nv_skidEnd": S([("nv_skid1", 60)]),
        // 막차 러시: 박자마다 '위빙' 동작 → 타격 순간 '훅' 동작으로 갈아 끼운다(규칙이 박자를 센다)
        "nv_drIn": S([("dr_in", 9999)]),
        "nv_drWL": S([("dr_wL", 9999)]),
        "nv_drWR": S([("dr_wR", 9999)]),
        "nv_drHL": S([("dr_hLs", 50), ("dr_hL", 9999)]),
        "nv_drHR": S([("dr_hRs", 50), ("dr_hR", 9999)]),
        "nv_drHLq": S([("dr_hL", 9999)]),
        "nv_drHRq": S([("dr_hR", 9999)]),
        "nv_drFin": S([("dr_fdip", 100), ("dr_fsm", 9999)]),
        "nv_drFinUp": S([("dr_fup", 150), ("dr_fup_ft", 250), ("dr_land", 150), ("c_over", 60)]),
        // 복싱 기술
        // 플리커: 길이는 그대로(큐 시각 · 판정 불변) — 낮은 손으로 돌아온 뒤(fl_low) 가드로
        "nv_flick": S([("fl_load", 40), ("fl_smear", 30), ("fl_hit", 70), ("fl_hit_ft", 60), ("fl_rt", 70), ("fl_low", 40)]),
        "nv_liver": S([("lv_load", 90), ("lv_smear", 35), ("lv_hit", 95), ("lv_hit_ft", 100), ("lv_rec", 110), ("c_over", 60)]),
        "nv_cork": S([("ck_load", 100), ("ck_pull", 50), ("ck_smear", 40), ("ck_hit", 100), ("ck_hit_ft", 110), ("ck_rt", 120), ("c_over", 60)]),
        // 숄더 롤: 흘리기 3칸(1+1+1 — 옛 sr_roll 2칸 + sr_ret 1칸과 같은 길이) → 휘두름 → 타격(큐 칸 #4 = 200ms 그대로)
        "nv_roll": S([("sr_roll", 50), ("sr_roll2", 60), ("sr_roll3", 50), ("sr_smear", 35), ("sr_hit", 90), ("sr_hit_ft", 90), ("sr_rt", 100), ("c_over", 50)]),
        // 퇴근 승천권(ms → 20fps 칸): 웅크림 1 · 솟구침 1(첫 타 · 무적) · 오름 1(둘째 타) · 꼭대기 1(큐) · 매달림 2 · 내려옴 2+1 · 착지 2 · 회복 4 · 서기 2 = 17칸(0.85초)
        "nv_rise": S([("rs_crouch", 70), ("rs_launch", 50), ("rs_rise", 50), ("rs_apex", 50), ("rs_hang", 100), ("rs_fall", 100), ("rs_fall2", 50),
                      ("rs_land", 100), ("rs_rec", 200), ("c_over", 80)]),
    ].merging(vfSequences) { a, _ in a }.merging(klSequences) { a, _ in a }.merging(bmSequences) { a, _ in a }.merging(ofSequences) { a, _ in a }

    /// 타격 자세(웹 JW_CUE 와 같은 뜻)
    public static let cues: [String: String] = [
        "nv_flick": "fl_hit", "nv_liver": "lv_hit", "nv_cork": "ck_hit", "nv_roll": "sr_hit", "nv_rise": "rs_apex",
    ].merging(vfCues) { a, _ in a }.merging(klCues) { a, _ in a }.merging(bmCues) { a, _ in a }.merging(ofCues) { a, _ in a }

    /// 기존 동작을 깃발 켜짐에서 덮어쓰는 것(감독 피드백: 스매시를 어퍼컷에 통합 — 스매시의 더 자세한 포즈를 어퍼컷에 입힌다).
    /// 칸 길이는 웹 어퍼컷(u_load 100 · u_dip 70 · u_smear 40 · u_hit 120 · u_hit_ft 140 · u_hit_rt 150 · c_over 70)과 같게 → 큐 칸(#3 = 200ms) · 총 길이 · 판정 불변.
    /// 적(JW 리그)의 어퍼컷도 같은 표를 쓰므로 함께 바뀐다(타이밍 동일).
    public static let overrideSequences: [String: [SeqStep]] = [
        "upper": S([("sm_load", 100), ("sm_dip", 70), ("sm_smear", 40), ("sm_hit", 120), ("sm_hit_ft", 140), ("sm_rt", 150), ("c_over", 70)]),
    ]
    public static let overrideCues: [String: String] = ["upper": "sm_hit"]

    /// 앞팔(B)을 FK 각도로, 뒷팔(F)은 IK 값(aF · eF)을 같은 리그 치수(JW_HERO 위팔 8 · 아래팔 8)로 FK 로 바꿔 둔다
    static func FKB(_ p0: Pose, uB: Double, lB: Double) -> Pose {
        var p = p0
        let f = solveArm(.zero, raw(p.aF), p.eF, 8, 8 * or(p.strF, 1), up: p.upF == true)
        func ang(_ A: V2, _ B: V2) -> Double { atan2(B.x - A.x, B.y - A.y) / (Double.pi / 8) }
        p.armFK = true; p.uF = ang(.zero, f.K); p.lF = ang(f.K, f.F); p.uB = uB; p.lB = lB
        return p
    }
}

extension AnimTables {
    /// 네이티브 동작 포즈를 더한 복사본(기존 포즈는 그대로 — 이름이 겹치면 기존 것이 이긴다)
    public func withNativeMoves() -> AnimTables {
        var t = self
        t.poses = poses.merging(NativeMoves.poses) { a, _ in a }.merging(NativeMoves.guardPoses) { a, _ in a }.merging(NativeMoves.runPoses) { a, _ in a }.merging(NativeMoves.grabPoses) { a, _ in a }   // 잡기 다듬기(NativeGrabPoses) · 질주 키(nvRunPose) · 공방(가드 · 도발 · 로킥 — NativeGuardPoses)
        return t
    }
}

extension SequenceTable {
    /// 네이티브 동작 시퀀스를 더한 복사본
    public func withNativeMoves() -> SequenceTable {
        var t = self
        t.jw = jw.merging(NativeMoves.sequences) { a, _ in a }.merging(NativeMoves.guardSequences) { a, _ in a }.merging(NativeMoves.overrideSequences) { _, b in b }.merging(NativeMoves.grabSequences) { _, b in b }   // 잡아 메치기 · 수플렉스 칸 쪼개기(칸 수 합 · 큐 그대로)
        return t
    }
}
