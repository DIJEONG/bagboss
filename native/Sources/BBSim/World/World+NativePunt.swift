import Foundation

// 구두 슛(nv_punt — SimConfig.nativeMoves · docs/07 §7-PK). 쓰러진 적을 구두 앞코로 축구공처럼 차 낮게(10~14px) 데굴데굴 굴러가듯 멀리 날린다.
//  · 칸 신호 pk_step(깡충 내딛기 — 누운 몸 옆까지 뛰어든다) → pk_plant(착지) → pk_swing(몸 아래에서 쓸어 냄 · 번짐)
//    → 큐 pk_hit(기본 경로 heroSkill — 조건 down: 쓰러진 적만 · 반응 rKick → 저글) → 낮고 길게: 가로 nvPuntVx · 세로 nvPuntVy · 약한 중력 · 가로 오래 남음(nvKeep)
//    · 한 바퀴 굴러간다(roll) · 한 번 튕긴다(forceB) → 바닥에 눕는다. 낮고 빠른 몸은 기존 볼링 규칙(bowlCheck)으로 서 있는 다른 적을 넘어뜨린다.
//  · 연계: 이음기 D→K — 날린 적은 내선 연결로 다시 끌어온다(도감 '킥오프').
// 규칙 난수는 쓰지 않는다(치명 굴림은 기본 경로 heroSkill 그대로).

/// 만화 글자(문구는 여기 한 곳 · 영어는 strings-extra 'native-moves')
public enum NvPuntText {
    /// 차는 순간
    public static let kick = "뻥!"
}

extension World {
    /// 날림: 가로 속도(px/s) · 세로 속도(px/s — 높이 ≈ v²/2G) · 중력 배율 · 초당 남는 가로 비율 · 구르는 바퀴 수
    static let nvPuntVx = 320.0, nvPuntVy = 95.0, nvPuntG = 0.55, nvPuntKeep = 0.35, nvPuntRoll = 1.0
    /// 디딤: 누운 몸 가운데에서 멈추는 거리(px) · 미끄러져 들어가는 최대 거리(px)
    static let nvPuntGap = 16.0, nvPuntLunge = 30.0

    /// useSkill 갈래: 구두 슛
    func nvPuntOpts(_ opts: ActionReq, _ H: Actor, _ T: Actor, _ b: Item, _ visCue: @escaping (String) -> (Actor) -> Void) {
        let f = H.f
        opts.cues = [
            // 깡충 내딛기: 누운 몸 옆(16px)까지 한 걸음에 뛰어든다
            "pk_step": { [unowned self] c in
                visCue("pk_step")(c)
                let dd = min(World.nvPuntLunge, max(0, abs(T.x - H.x) - World.nvPuntGap))
                if dd > 0 && !T.dead { H.dash = f * dd / 0.1; H.dashT = 0.1 }
                self.fx("dust", H.x, H.y, -f)
            },
            // 착지: 디딘 발 먼지
            "pk_plant": { [unowned self] c in visCue("pk_plant")(c); H.dash = 0; H.dashT = 0; self.fx("dust", H.x + f * 3, H.y, f) },
            "pk_swing": visCue("pk_swing"),
        ]
        let hit = opts.onCue
        opts.onCue = { [unowned self] c in
            let hp0 = T.e?.hp
            hit?(c)   // 기본 경로(아이템 피해 · 치명 · 연계 · 콤보 집계 — 반응 rKick 으로 띄운다)
            guard (T.e?.hp ?? 0) < (hp0 ?? 0) else { return }
            T.flash = 0   // 몸 전체 흰 번쩍임 대신 앞코 자리 불꽃
            let toe = SIMD2(T.x - f * 4, T.y - 8 - (T.jug?.h ?? 0))
            self.fx("spark", toe.x, toe.y)
            self.comicSFX(toe.x, toe.y - 56, NvPuntText.kick, force: true)
            var k = CameraKick(); k.shake = 2.2; k.zoom = 0.04; k.zoomMode = .add(cap: 0.06); k.focus = toe; self.emit(.camera(k))
            self.emit(.haptic(.heavy))
            guard let J = T.jug, !J.roofOut else { return }
            // 낮고 길게 · 한 바퀴 굴러간다(가로는 nvKeep 로 오래 — nvKneeFlyStep 이 J.vx 를 kb 에 맞춘다)
            let hv = T.e?.heavy == true ? 0.6 : 1
            J.vx = f * World.nvPuntVx * hv; J.vy = World.nvPuntVy; J.gk = World.nvPuntG; J.nvKeep = World.nvPuntKeep; J.nvRollT = nil
            J.forceB = true; J.bounced = false; J.trip = false; J.nvWall = false; J.nvSlam = false
            J.up = "air_back"; J.fall = "air_fall"; J.rollT = J.roll - World.nvPuntRoll; self.jugRollRate(J)
            T.kb = J.vx; T.hs = min(T.hs, 2); T.hs0 = max(1, T.hs)
        }
    }
}
