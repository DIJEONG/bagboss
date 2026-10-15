import Foundation

// 네이티브 동작 개편 ② 필살기 '막차 러시'(주먹 계열) — 뎀프시 롤 풍 연타(SimConfig.nativeMoves).
// 웹: 0.85초 동안 칸 끝까지 등속으로 달리며 0.1초마다 잽 · 크로스 · 훅을 갈아 끼우고, 18px 안의 적을 3번까지 친 뒤 어퍼컷으로 띄운다.
// 네이티브: 같은 거리 · 같은 피해 규칙(적마다 4 × 최대 3타 · 마무리 22 띄우기 치명) · 비슷한 길이(0.88초 + 마무리)로
//   ① 들어가기(0.10초): 피카부 가드로 웅크려 출발 — 속도선 · 바람 소리
//   ② 위빙 + 좌우 훅 7박: 머리를 8자로 굴리며(위빙 자세 좌↔우) 박자마다 반대쪽 훅. 간격 0.15 → 0.07초로 빨라지고,
//      시간 배율(spcTime)도 0.45 → 0.85 로 올라 화면에서도 점점 빨라진다. 맞은 적은 앞에 차곡차곡 실려 함께 밀려 간다
//   ③ 마무리: 깊게 가라앉았다(dip) 뒷손 올려치기로 실린 무더기를 한꺼번에 띄운다 — 화면 멈춤 · 줌 펀치 · 반전 · 큰 흔들림
// 연출(속도선 · 훅 궤적 · 박자 불꽃 · 커지는 만화 글자 · 카메라 밀기/흔들림 · 진동 · 효과음 박자)은 전부 이벤트로 낸다.

extension SpecialRun {
    /// 러시 박자 시작 시각(게임 초) — 간격 0.15 · 0.15 · 0.12 · 0.10 · 0.09 · 0.08 · 0.07
    static let nvBeats: [Double] = [0.10, 0.25, 0.40, 0.52, 0.62, 0.71, 0.79]
    static let nvDur = 0.88
}

extension World {
    /// 러시 시작(spcBegin 의 fist 갈래 뒤)
    func nvRushBegin(_ S: SpecialRun) {
        guard let H = hero else { return }
        H.action = nil; H.queue = []; H.hs = 0; setAnim(H, "nv_drIn")
        sfx("whoosh"); fxD(FxDetail(kind: "nv_speed", x: H.x, y: H.y - 34, dir: S.dir, n: 0))
        var k = CameraKick(); k.zoom = 0.04; k.focus = SIMD2(H.x + S.dir * 30, H.y - 40); emit(.camera(k))
    }

    /// 러시 진행(spcUpdate 의 fist 갈래 대신)
    func nvRushUpdate(_ S: SpecialRun, _ dt: Double, hit: (Actor, Double, HitOpts) -> Void) {
        guard let H = hero else { return }
        let dur = SpecialRun.nvDur, B = SpecialRun.nvBeats
        if S.t < dur {
            // 이동: 반 속도로 출발해 가운데서 가장 빠르고 끝에서 다시 반 속도(마무리 자리에 발을 박는다)
            let u = min(1, S.t / dur), e = 0.5 * u + 0.5 * u * u * (3 - 2 * u)
            let nx = S.x0 + (S.x1 - S.x0) * e, mdx = nx - H.x; H.x = nx; H.gph += abs(mdx) / 66; H.legRun = true; H.flip = S.dir < 0
            // 박자
            let k = B.lastIndex { S.t >= $0 } ?? -1
            if k >= 0 && k != S.nvBeat {   // 새 박자: 반대쪽으로 위빙
                S.nvBeat = k; S.nvStage = 0
                H.hs = 0; setAnim(H, k % 2 == 0 ? "nv_drWL" : "nv_drWR"); sfx("swing")   // 리드 훅 앞엔 뒤로(뒷손 쪽으로) 감고, 리어 훅 앞엔 앞으로 감는다
                fxD(FxDetail(kind: "nv_speed", x: H.x, y: H.y - 34, dir: S.dir, n: k))
            }
            if k >= 0 {
                let slow = k < 3   // 앞 박자는 휘두름 칸이 하나 더(장전 → 휘두름 → 타격)
                let t0 = B[k], left = k % 2 == 0
                if slow && S.nvStage == 0 && S.t >= t0 + 0.05 { S.nvStage = 1; H.hs = 0; setAnim(H, left ? "nv_drHL" : "nv_drHR") }
                let hitAt = t0 + (slow ? 0.10 : 0.045)
                if S.nvStage < 2 && S.t >= hitAt {
                    S.nvStage = 2; H.hs = 0; setAnim(H, left ? "nv_drHLq" : "nv_drHRq")
                    nvRushHit(S, k, hit: hit)
                }
            }
            // 몸을 굴리는 8자: 위빙 칸은 박자마다 뒤(−) · 앞(+)으로 크게, 훅 칸은 앞으로 실린다(관절 tilt, 라디안 — 머리가 7~9px 오간다)
            let target = k < 0 ? 0.2 : S.nvStage == 2 ? 0.26 : (k % 2 == 0 ? -0.22 : 0.42)
            H.nvm.lean += (target - H.nvm.lean) * min(1, dt * 30)
            for a in foes() where !a.dead && spcVis(a) && (a.x - H.x) * S.dir > -6 && abs(a.x - H.x) < 20 && !S.carry.contains(where: { $0 === a }) {
                S.carry.append(a)   // 부딪힌 적은 대열에 실린다(웹과 같은 18~20px 접촉 — 박자 사이에 지나쳐도 놓치지 않는다)
                if canAct(a) { setAnim(a, "stagger") }
            }
            for (j, a) in S.carry.enumerated() where !a.dead {   // 열차처럼 앞으로 밀고 간다(웹과 같은 대열)
                let nx2 = max(16, min(data.sbW - 16, H.x + S.dir * (14 + Double(j) * 9))); a.gph -= abs(nx2 - a.x) / 66; a.legRun = true; a.x = nx2; a.kb = 0; a.flip = S.dir > 0
            }
        } else if S.nvFin0 == nil {   // 마무리 준비: 가라앉는다
            S.nvFin0 = S.t; legRunOff(); H.hs = 0; setAnim(H, "nv_drFin"); H.nvm.lean = 0
            sfx("slowIn")
            var c = CameraKick(); c.zoom = 0.06; c.focus = SIMD2(H.x + S.dir * 16, H.y - 36); emit(.camera(c))
        } else if !S.fin, S.t >= S.nvFin0! + 0.14 {   // 올려치기: 실린 무더기를 한꺼번에 띄운다
            H.hs = 0; setAnim(H, "nv_drFinUp")
            var grp = S.carry
            for a in foes() where (a.x - H.x) * S.dir > -8 && abs(a.x - H.x) < 34 && !grp.contains(where: { $0 === a }) { grp.append(a) }
            for a in grp { var o = HitOpts(); o.react = "launch"; o.crit = true; hit(a, 22, o) }
            S.fin = true
            groundImpact(H.x + S.dir * 10, H.y, 2.0); sfx("tetsu"); emit(.haptic(.heavy))
            fxD(FxDetail(kind: "nv_finish", x: H.x + S.dir * 12, y: H.y - 46, dir: S.dir, n: grp.count, big: true))
            var c = CameraKick(); c.shake = 4.6; c.zoom = 0.16; c.invertFrames = 3; c.freezeFrames = 2; c.focus = SIMD2(H.x + S.dir * 14, H.y - 50); emit(.camera(c))
            freeze = max(freeze, 2)
            spcFinish()
        }
    }

    /// 박자 하나의 타격: 실린 대열에서 아직 3타를 다 맞지 않은 앞의 둘 + 주먹 앞 24px 안의 적 — 웹과 같은 피해 4 · 적마다 3타까지
    func nvRushHit(_ S: SpecialRun, _ k: Int, hit: (Actor, Double, HitOpts) -> Void) {
        guard let H = hero else { return }
        var n = 0, T: [Actor] = []
        for a in S.carry where !a.dead && spcVis(a) && (S.hits[ObjectIdentifier(a)] ?? 0) < 3 && T.count < 2 { T.append(a) }
        for a in foes() where !a.dead && spcVis(a) && (a.x - H.x) * S.dir > -6 && abs(a.x - H.x) < 24 && (S.hits[ObjectIdentifier(a)] ?? 0) < 3 && !T.contains(where: { $0 === a }) { T.append(a) }
        for a in T {
            let id = ObjectIdentifier(a)
            S.hits[id] = (S.hits[id] ?? 0) + 1; S.hl[id] = S.t
            var o = HitOpts(); o.react = "head"; hit(a, 4, o); n += 1
            if !S.carry.contains(where: { $0 === a }) { S.carry.append(a) }
        }
        let fx0 = H.x + S.dir * 16, fy = H.y - 40
        fxD(FxDetail(kind: "nv_hook", x: fx0, y: fy, dir: S.dir, s: 1 + 0.12 * Double(k), n: k, big: k % 2 == 1))
        if n > 0 {
            let words = ["팍!", "팍!", "팍팍!", "파바박!", "두두두둑!", "다다다다닥!", "우다다다다!"]
            comicSFX(fx0, fy - 50 - Double(k) * 3, words[min(k, words.count - 1)], force: true)
            var c = CameraKick(); c.shake = 1.2 + 0.35 * Double(k); c.zoom = 0.015 + 0.006 * Double(k); c.focus = SIMD2(fx0, fy); emit(.camera(c))
            emit(.haptic(k < 3 ? .light : .medium))
        }
    }
}
