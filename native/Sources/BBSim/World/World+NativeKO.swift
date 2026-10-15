import Foundation

// 네이티브 KO 마무리(docs/11 §1 — SimConfig.nativeMoves 켜짐에서만). 웨이브 · 칸의 마지막 적이나 두목을 주인공 타격으로 쓰러뜨리면:
//   0.4초(실제 시간) 0.25배 슬로 → 정지 2칸(애니 20fps — 약 5틱) → 표현이 카메라를 빼 쓰러진 몸에 한 박자 머문다(BBPresentation KOFinisherCam).
// 웹 마지막 일격(화면 정지 BF(stop) + 0.9초 0.28배 슬로)을 이것으로 갈음한다 — 늘어나는 게임 시간은 약 0.38초.
// 웨이브마다 한 번(spawnWave · twSpawn 이 다시 장전) · 보너스 차 · 필살기 · 컷인 중엔 없다 · 무도장은 시연(nvKODemo)일 때만.
// 슬로 · 정지는 규칙 시계(realTime · 애니 칸)로만 흐른다 — 설정(흔들림 줄이기 등)과 무관하게 결정적.

extension World {
    static let nvKOSlow = 0.4, nvKOSlowK = 0.25, nvKOFreeze = 2

    /// damage() 의 마지막 한 방 자리: 마무리를 걸었으면 true(웹 정지 · 슬로는 건너뛴다)
    func nvKOTry(_ tgt: Actor, _ f: Double) -> Bool {
        guard nv, nvKOArmed, !bonus, spc == nil, cut == nil, !demo || nvKODemo, let e = tgt.e, !tgt.carDummy, !tgt.carOwner else { return false }
        nvKOArmed = false
        nvKOT = World.nvKOSlow; slowT = max(slowT, World.nvKOSlow)
        schedule(after: World.nvKOSlow) { w in w.freeze = max(w.freeze, World.nvKOFreeze) }
        emit(.koFinisher(KOFinisher(target: tgt.id, x: tgt.x, y: tgt.y, dir: f, boss: e.boss, slow: World.nvKOSlow, freezeFrames: World.nvKOFreeze)))
        return true
    }
}

// MARK: 개발용(앱 DebugLaunch '-kodemo' · 띠 테스트)

extension Sim {
    /// 남은 적 체력을 한 방 체력으로 낮춘다(KO 마무리를 빨리 보기 — 규칙 경로 그대로). 낮췄으면 true
    @discardableResult
    public func debugLowFoes(_ hp: Double = 1) -> Bool {
        guard w.config.nativeMoves, w.state == "fight" else { return false }
        let F = w.foes(); guard !F.isEmpty else { return false }
        for a in F { if let e = a.e { e.hp = min(e.hp, hp) } }
        return true
    }
    /// 무도장에서 KO 마무리 시연 허용(기본 꺼짐 — 무도장 시연엔 없다) · 다시 장전
    public func debugKODemo(_ on: Bool = true) { w.nvKODemo = on; w.nvKOArmed = true }
}
