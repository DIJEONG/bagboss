import Foundation
import BBAnim
import BBSim

// 피격 반응 다양화(docs/11 §9) — 규칙의 타격 이벤트(HitInfo)를 '맞은 자리 · 방향 · 세기 · 몸무게'로 읽는다.
// 읽기만 한다: 규칙(BBSim)은 이 값을 모르고, 고르기는 BBAnim HitReact(결정적 해시)가 한다.

public enum HitReactMap {
    /// 고른 입력 하나
    public struct Read: Sendable, Equatable {
        public var zone: HitZone, dir: HitDir, tier: HitTier, mass: HitMass, hold: Double
    }

    /// 때린 동작 → 맞은 자리(높이 표 — BBSim NativeContent heroHeights · foeHeights 와 같은 갈래: 상단 = 머리 · 중단 = 몸통 · 하단 = 다리)
    public static let legsMoves: Set<String> = ["sweep", "stomp", "nv_lowk"]
    public static let bodyMoves: Set<String> = ["kick", "knee", "charge", "charge_air", "tetsu", "renkan", "skick", "bkick", "uthrust", "hangkick", "nv_liver", "nv_kneelift", "nv_duckup", "nv_stamp"]
    /// 위에서 내려찍기 · 아래에서 올려 치기
    public static let aboveMoves: Set<String> = ["axe", "axe_air", "hm_down", "stomp", "jkick", "nv_slam"]
    public static let belowMoves: Set<String> = ["upper", "scoop", "skick", "nv_rise", "hm_up", "renkan", "nv_kneelift", "nv_duckup"]
    /// 몸통 반응(규칙이 고른 반응 이름)
    static let bodyReacts: Set<String> = ["hitB", "rKnee", "rElbow"]

    /// 타격 하나 → 반응 입력. 쓰러짐 · 띄움 · 공중 · 처치 · 서서 맞는 반응이 아니면 nil(웹 그대로)
    public static func read(_ h: HitInfo, target T: SimSnapshot.ActorView) -> Read? {
        guard !h.dead, !h.airborne, HitReact.standing.contains(h.targetAnim) else { return nil }
        var a = h.attackerAnim
        if a.hasSuffix("_air") && !aboveMoves.contains(a) { a.removeLast(4) }
        let zone: HitZone = legsMoves.contains(a) || h.reaction == "rSwept" ? .legs
            : bodyMoves.contains(a) || bodyReacts.contains(h.reaction) || h.reactOpt == "body" ? .body : .head
        // 방향: 밀리는 쪽(h.dir) 이 맞는 쪽이 보는 쪽과 같으면 등 뒤에서 맞은 것
        let facing: Double = T.flip ? -1 : 1
        let dir: HitDir = h.dir * facing > 0 ? .back
            : aboveMoves.contains(h.attackerAnim) ? .above
            : belowMoves.contains(a) ? .below : .front
        let tier: HitTier = h.big || h.counter || h.bigCrit || h.just || h.weight == .heavy ? .heavy
            : h.crit || h.weight == .medium ? .medium : .light
        let mass = HitReact.mass(type: T.enemyType, hero: T.isHero, boss: T.isBoss)
        return Read(zone: zone, dir: dir, tier: tier, mass: mass, hold: Double(h.freezeFrames) * 0.05)
    }
}
