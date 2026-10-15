import Foundation
import BBContent

// 버추어 파이터(아키라) 참고 두 기술(SimConfig.nativeMoves — 깃발이 꺼지면 이 동작 · 아이템이 없어 이 파일은 불리지 않는다 → 웹 그대로). docs/07 §7-VF.
//  · 무릎 올려치기(nv_kneelift — 2026-10-13 영상 재분석으로 새로 짰다 · 자세 NativeKneePoses): 앞굽이에서 뒷무릎을 끌어올려 큐 kl_hit(100ms) 한 방 — 기본 경로 heroSkill(아이템 피해 · 반응 launch).
//    주인공은 거의 제자리(작은 뜀 · 앞으로 8px)에서 무릎을 0.3초 든 채 버틴다. 맞은 상대는 몸이 뒤로 접혔다(air_hit) → 눕힌 채(kv_lay — 몸 전체 회전 nvKneeRoll) 뒤 대각선 위로 길게 날아간다:
//    높이 약 38px(올라가는 속도 nvKneeVy) · 가로 nvKneeVx 를 느리게 잃으며(nvKneeKeep) 약 80px · 등으로 떨어져 한 번 튕긴다. 내디딤 칸(kl_plant)에서 바닥 먼지.
//  · 파고들어 올려치기(nv_duckup): 칸 신호 du_step(내디딤 — 상대 앞까지 미끄러져 들어감) → du_jab(1타: 오른손 낮게 · 몸통 · 아이템 피해 ×0.3 · 잠깐 묶음)
//    → du_rise(웅크림에서 튀어 오름 — 먼지) → 큐 du_up(2타: 기본 경로 heroSkill · 아이템 피해 · 띄움). 조건 'nv_ground' = 서 있는 상대(36+4px 안).
// 규칙 난수는 쓰지 않는다(치명 굴림은 기본 경로 heroSkill 그대로).

/// 두 기술 만화 글자(문구는 여기 한 곳 · 영어는 strings-extra 'native-moves' — 이미 있는 효과음만 쓴다)
public enum NvVFText {
    /// 무릎이 꽂히는 순간
    public static let knee = "퍼억!"
    /// 파고드는 1타
    public static let jab = "퍽!"
    /// 튀어 오르는 어퍼컷
    public static let upper = "솟구쳐!"
}

extension World {
    /// 1타 피해 배율(아이템 피해 × k) · 1타 뒤 상대 묶음(초)
    static let nvDuckJabK = 0.3, nvDuckJabStun = 0.5
    /// 내디딤 최대 거리(px) · 1타가 닿는 앞 거리(px)
    static let nvDuckLunge = 26.0, nvDuckJabReach = 30.0
    /// 띄움 세기(올라가는 속도 · 뒤로) — 파고들어 올려치기
    static let nvDuckVy = 250.0, nvDuckVx = 16.0
    /// 무릎 날림(영상: 몸을 눕힌 채 뒤 대각선 위로 길게) — 올라가는 속도(최고 ≈ vy²/2G = 38px) · 가로 속도 · 초당 남는 가로 비율 · 눕힘(바퀴 — 몸 전체 회전) · 접히는 시간(초)
    static let nvKneeVy = 220.0, nvKneeVx = 170.0, nvKneeKeep = 0.35, nvKneeRoll = -0.08, nvKneeFold = 0.1
    /// 무릎 경직 상한(경직 칸 — 20fps 칸 · 2 = 0.1초. 기본 히트스톱 × 손맛 배율이면 0.25초 가까이 굳는다)
    static let nvKneeHs = 2
    /// 무릎 올려치기 앞으로 들어가는 거리(px) · 시간(초 — 끌어올림 ~ 타격)
    static let nvKneeStep = 8.0, nvKneeStepT = 0.1

    /// 조건 'nv_ground'(파고들어 올려치기): 서 있는(떠 있지 않고 눕지 않은) 상대가 앞 40px 안
    func nvGroundOK(_ H: Actor, _ T: Actor?) -> Bool {
        guard let T, !T.dead, !T.held, T.jug == nil, !isDown(T) else { return false }
        return abs(T.x - H.x) <= (item("nv_duckup")?.reach ?? 36) + 4
    }

    /// useSkill 갈래: 무릎 올려치기
    func nvKneeliftOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let f = H.f
        opts.cues = [
            // 끌어올림: 디딤발로 바닥을 밀며 반 걸음 들어간다(먼지)
            "kl_drive": { [unowned self] c in
                visCue("kl_drive")(c); self.fx("dust", H.x, H.y, -H.f)
                if !T.dead { H.dash = f * World.nvKneeStep / World.nvKneeStepT; H.dashT = World.nvKneeStepT }
            },
            // 내디딤: 무릎 다리를 앞으로 딛는다(먼지)
            "kl_plant": { [unowned self] c in visCue("kl_plant")(c); self.fx("dust", H.x + f * 6, H.y, H.f) },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let before = Set(self.foes().filter { $0.jug == nil }.map(\.id))
            hit?(c)
            // 이번 한 방에 뜬 적만 눕혀 날린다(원래 떠 있던 적은 기본 공중 규칙 그대로)
            var launched = false
            for a in self.ents where a.e != nil && before.contains(a.id) && abs(a.x - H.x) < 34 {
                guard let J = a.jug, !J.roofOut else { continue }
                let hv = a.e?.heavy == true ? 0.6 : 1
                J.vy = World.nvKneeVy * hv; J.vx = f * World.nvKneeVx * hv; a.kb = J.vx
                J.up = "kv_lay"; J.fall = "kv_fall"; J.hitT = self.time + World.nvKneeFold   // 먼저 무릎에 꺾여 접힌다(air_hit)
                J.nvRollT = World.nvKneeRoll; J.nvKeep = World.nvKneeKeep; J.forceB = true
                a.hs = min(a.hs, World.nvKneeHs); a.hs0 = max(1, a.hs)
                launched = true
            }
            // 경직은 짧게(영상: 무릎이 꽂히고 멈추지 않고 바로 솟는다 — 길게 멈추면 타격 칸이 굳어 보인다)
            if launched { H.hs = min(H.hs, World.nvKneeHs); H.hs0 = max(1, H.hs) }
            if launched || (!T.dead && T.anim == "rKnee") {
                self.comicSFX(T.x - f * 4, T.y - 80 - (T.jug?.h ?? 0), NvVFText.knee, force: true)
                self.slowT = max(self.slowT, 0.06)   // 무릎이 꽂혀 상대가 접히는 순간만 아주 짧게(영상은 느려지지 않고 이어진다)
            }
        }
    }

    /// 무릎 날림 한 걸음(jugStep 안): 접힌 뒤 몸을 눕힌다(회전을 목표로 부드럽게) · 가로 속도는 넉백과 같이 느리게 준다
    func nvKneeFlyStep(_ a: Actor, _ J: Jug, _ dt: Double) {
        if let rt = J.nvRollT, J.t > World.nvKneeFold * 0.6 {
            J.roll += (rt - J.roll) * min(1, dt * 9)
            if rt == 0 && abs(J.roll) < 0.002 { J.roll = 0; J.nvRollT = nil }
        }
        if J.nvKeep != nil { J.vx = a.kb }   // 착지 · 튕김 때 넘겨받는 가로 속도도 같이 준다
    }

    /// useSkill 갈래: 파고들어 올려치기(1타는 칸 신호 · 2타는 큐)
    func nvDuckupOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ i: Int, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let st = sStats(i), f = H.f
        opts.cues = [
            // 내디딤: 상대 앞(15px)까지 미끄러져 들어간다 — 1타 칸 직전까지(0.15초)
            "du_step": { [unowned self] c in
                visCue("du_step")(c); self.fx("dust", H.x, H.y, -H.f)
                let dd = min(World.nvDuckLunge, max(0, abs(T.x - H.x) - 15))
                if dd > 0 && !T.dead { H.dash = f * dd / 0.15; H.dashT = 0.15 }
            },
            // 1타: 오른손(뒷손) 낮게(몸통) — 작게 · 짧게 묶어 2타가 이어지게
            "du_jab": { [unowned self] c in
                visCue("du_jab")(c); H.dash = 0; H.dashT = 0
                guard !T.dead, !T.held, T.jug == nil, !self.isDown(T) else { return }
                let dx = (T.x - H.x) * f
                if dx < -8 || dx > World.nvDuckJabReach { return }
                self.curSrc = b.uid; var o = HitOpts(); o.react = "body"
                let blocked0 = self.nvc.blockedNow; self.nvc.blockedNow = false
                self.damage(H, T, max(1, jsRound(st.dmg * World.nvDuckJabK * self.comboMul(b))), o); self.curSrc = nil
                let blocked = self.nvG && self.nvc.blockedNow; self.nvc.blockedNow = blocked0
                if !T.dead && !blocked, let e = T.e {
                    e.stun = max(e.stun, World.nvDuckJabStun); T.action = nil; T.queue = []
                    T.kb = f * 6   // 거의 밀리지 않게(2타가 닿는다)
                    self.comicSFX(T.x - f * 2, T.y - 40, NvVFText.jab)
                }
                H.hs = min(H.hs, 1); H.hs0 = max(1, H.hs); T.hs = min(T.hs, 3)   // 1타 경직은 짧게(리듬이 끊기지 않게)
                if let C = self.croute, C.uids.contains(b.uid) { C.hits += 1 }
            },
            // 튀어 오름: 웅크림에서 몸을 펴며 바닥을 박찬다(양쪽 먼지)
            "du_rise": { [unowned self] c in visCue("du_rise")(c); self.fx("dust", H.x - f * 3, H.y, -H.f); self.fx("dust", H.x + f * 3, H.y, H.f) },
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let before = Set(self.foes().filter { $0.jug == nil }.map(\.id))
            hit?(c)
            var launched = false
            for a in self.ents where a.e != nil && before.contains(a.id) && abs(a.x - H.x) < 40 {
                guard let J = a.jug, !J.roofOut else { continue }
                let hv = a.e?.heavy == true ? 0.6 : 1
                J.vy = max(J.vy, World.nvDuckVy * hv); J.vx = f * World.nvDuckVx * hv; J.up = "air_up"; J.fall = "air_back"; a.kb = J.vx
                launched = true
            }
            if launched { self.comicSFX(T.x + f * 6, T.y - 86 - (T.jug?.h ?? 0), NvVFText.upper, force: true) }
        }
    }
}
