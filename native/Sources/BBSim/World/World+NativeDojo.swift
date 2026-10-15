import Foundation

// 네이티브 무도장 다듬기(SimConfig.nativeMoves — 꺼지면 이 파일은 불리지 않는다 → 웹 42-dojo 와 같다).
// docs/07 I8 · I9:
//   · 체력: 무도장 주인공은 죽지 않는다 — 시연마다 9999 로 채우고(예시 가방 renderBag 이 120 으로 되돌리던 것 포함), 절반 아래면 바로 채운다.
//     혹시 쓰러져 결과 화면 상태(over)가 됐어도 다음 시연 명령에서 일으켜 세운다.
//   · 단독 시연 조건: 밟기는 허수아비를 먼저 넘어뜨린 뒤(바닥에 눕고 나서 밟는다) · 공중 기술(공중 자전거)은 먼저 띄운 뒤 ·
//     날아차기는 처음부터 날아들 거리(85px)에서 · 기둥 회전차기는 무도장 나무 기둥(DJ_POLES) 옆 · 매달려 차기는 천장 손잡이(dj_ring) 아래,
//     둘 다 실전 envMove 와 같은 타격 큐로 허수아비가 실제로 맞는다 · 반응 시연은 40px(24px 는 눕는 몸이 주인공 발과 겹침) ·
//     얼굴부터 꽂히기(rSpike)는 실전처럼 높이(18px)에서 0.03초 꽂혀 머리가 바닥 아래로 박히지 않는다.
//   기술 자체의 동작 · 큐 타이밍은 그대로다(조건만 맞춘다).

extension World {
    /// 무도장 체력: 9999 고정 · 절반 아래면 채운다 · 쓰러졌으면 일으킨다(매 틱 — dojoDummyTick 에서)
    func nvDojoKeepAlive() {
        guard demo, let H = hero else { return }
        if maxHP < 9999 { maxHP = 9999 }
        if hp < maxHP * 0.5 { hp = maxHP; lagH = hp }
        if H.dead || state == "over" { nvDojoRevive() }
    }
    /// 시연 명령마다: 체력을 채우고, 쓰러져 있었다면 제자리에 세운다
    func nvDojoRevive() {
        guard demo, let H = hero else { return }
        maxHP = 9999; hp = 9999; lagH = hp
        if H.dead || state == "over" {
            H.dead = false; H.keepBody = false; wait = 0
            if state != "fight" { setState("fight") }
            dojoReset(24)
        }
    }

    /// 단독 기술 시연의 조건 맞추기 — 처리했으면 true(아니면 웹 dojoHero 그대로)
    func nvDojoHero(_ id: String, _ combo: Int?) -> Bool {
        guard let it = item(id) else { return false }
        let single = { [self] in
            bag = [dojoItem(id, 9900, t: 99, tier: 2)]
            dj?.seq = DojoSeq(steps: [DojoStep(id, combo)], name: "", custom: false, single: true)
        }
        if it.cond == "down" {   // 밟기: 먼저 넘어뜨린다(웹은 이미 누운 'down' 에 헛친다)
            guard let D0 = dojoDummy(), !isFalling(D0), D0.jug == nil else { return false }
            let rc = it.reach ?? 24
            dojoReset(max(12, min(rc - 6, 24)))
            guard let D = dojoDummy(), let H = hero else { return true }
            face(D, H.x); setAnim(D, "fall"); D.after = "getup"
            single(); return true
        }
        if it.cond == "air" {   // 공중 자전거: 먼저 띄운다(타격 없이 — 허수아비가 튀어 오른다)
            dojoReset(24)
            guard let D = dojoDummy(), let H = hero else { return true }
            jugHit(D, "launch", D.x >= H.x ? 1 : -1, D, HitOpts(), 1)
            fx("dust", D.x, D.y, D.f); sfx("swing")
            single(); return true
        }
        if id == "fkick" {   // 날아차기: 72px 뒷걸음 왕복 없이 처음부터 날아들 거리에서
            dojoReset(85); single(); return true
        }
        if id == "nv_beam" {   // 야근 광선: 광선이 보이게 떨어진(90px) 자리에서 — 뒤에 소품을 놓으면 광선이 꿰뚫어 깬다
            dojoReset(90); single(); return true
        }
        if id == "nv_stamp" {   // 결재 쌍장: 오른쪽 벽 앞(벽까지 약 60px — 무도장 확대 2배에서도 벽이 화면 안) — 날아가 벽에 박히는 것까지 보이게(World+NativeOffice)
            dojoReset(22)
            guard let H = hero, let D = dojoDummy() else { return true }
            H.x = AW1() - 80; D.x = H.x + 22; face(D, H.x)
            single(); return true
        }
        if id == "nv_dial" {   // 내선 연결: 멀리(120px) 떨어진 자리에서 — 수화기가 날아가 끌어오는 것까지 보이게(World+NativeDial)
            dojoReset(120); single(); return true
        }
        if id == "nv_duckup" {   // 파고들어 올려치기: 내디딤이 보이게 조금 떨어진(34px) 자리에서(World+NativeVF)
            dojoReset(34); single(); return true
        }
        return false
    }

    /// 기둥 회전차기 · 매달려 차기를 소품 옆에서 — 처리했으면 true
    func nvDojoMisc(_ k: String) -> Bool {
        guard k == "polespin" || k == "hangkick" else { return false }
        dojoReset(30)
        guard let H = hero, let D = dojoDummy() else { return true }
        if k == "polespin" {   // 무도장 나무 기둥(DJ_POLES) 중 가까운 것 — 실전 envMove 처럼 기둥 바로 뒤에 서서 돈다
            let pole = stableSortD(sd.djPoles) { abs($0 - 250) - abs($1 - 250) }[0]
            H.flip = pole > 240; H.x = pole - H.f * 5
            D.x = pole + H.f * 26; face(D, H.x)
            let opts = ActionReq()
            var ko = HitOpts(); ko.knock = true
            opts.cues = ["ps1": { [unowned self] _ in self.envHit(H, 42, 13, ko) }, "ps2": { [unowned self] _ in H.flip.toggle(); self.envHit(H, 42, 13, ko) }]
            requestAction(H, "polespin", opts); flashText("POLE", 0.5)
        } else {   // 천장 손잡이(무도장 dj_ring = 250 에 가장 가까운 STRAP_X) 아래
            let sx = stableSortD(data.strapX) { abs($0 - 250) - abs($1 - 250) }[0]
            H.flip = false; H.x = sx; D.x = sx + 24; face(D, H.x)
            let opts = ActionReq()
            var ko = HitOpts(); ko.knock = true; ko.splash = true
            opts.cues = ["hk2": { _ in H.airOv = 0 }, "hk1": { [unowned self] _ in self.envHit(H, 40, 15, ko) }]
            requestAction(H, "hangkick", opts); hangX = sx
        }
        return true
    }

    /// 허수아비 반응 시연(웹 dojoReact — 거리 40px · 꽂기는 높이에서)
    func nvDojoReact(_ r: String) {
        dojoReset(40)
        guard let D = dojoDummy(), let H = hero else { return }
        face(D, H.x); setAnim(D, r)
        if ["fall", "launch", "rKick", "rSpin", "rSwept", "rCharge", "rSlam", "rStomp", "crumple"].contains(r) { D.after = "getup" }
        if r == "rSpike" { D.after = "getupP"; D.airOv = 18; D.spike = (18, 0, 0.03) }   // 실전 도끼 차기처럼 높이에서 꽂힌다(꽂힘 자세 sp_hit 의 화면 정지 전에 바닥에 닿게 0.03초)
    }
}
