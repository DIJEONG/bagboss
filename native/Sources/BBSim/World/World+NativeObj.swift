import Foundation

// 무도장 부서지는 소품(네이티브 — 사용자가 마음대로 놓는다 · docs/07 §7-OB). 웹엔 없다: 놓지 않으면(빈 목록) 아무 일도 없다 → 웹 그대로.
//  · 종류: 유리 부스(glass — 키 큼 · 몸이 박힌다) · 나무 상자(crate — 낮음 · 부서지며 조금 늦춘다) · 장지문(shoji — 키 큼 · 쉽게 찢고 지나간다)
//  · 판정: 날아가는(jug) 적의 발 x 가 소품 반폭(hw) 안 · 높이 J.h ≤ 소품 키(top) · 가로 속도(넉백 kb · 공중 vx 중 큰 것)가 깨짐 문턱 이상이면 깨진다.
//    문턱보다 느리면(40 이상) 부딪혀 튕겨 나온다(깨지지 않음). 한 비행에 소품 하나는 한 번만.
//  · 깨지면: 효과 fx('objBreak:종류', x, y, 방향) · 소리 · 만화 글자 · 흔들림 · 진동 · 날아가던 몸이 멈칫(히트스톱)하고 속도를 잃는다(유리는 거의 다 — 박힌다).
//  · 복구: 다음 시연이 시작될 때(깨진 지 0.5초가 지났으면) 저절로 · 패널 '모두 복구'.
// 규칙 난수는 쓰지 않는다.

/// 소품 놓기 명세(앱 저장 · 복원 — 'djObj')
public struct DojoObjSpec: Sendable, Equatable, Codable {
    public var kind: String, x: Double
    public init(kind: String, x: Double) { self.kind = kind; self.x = x }
}

/// 소품 종류 값(반폭 · 키 · 깨짐 문턱 속도 · 깨진 뒤 남는 속도 배율 · 멈칫 프레임)
public struct DojoObjKind: Sendable {
    public let id: String, hw: Double, top: Double, breakSpd: Double, keep: Double, hs: Int
    /// 만화 글자 · 소리
    public let word: String, sfx: String
    public static let all: [DojoObjKind] = [
        .init(id: "glass", hw: 12, top: 64, breakSpd: 110, keep: 0.12, hs: 5, word: "와장창!", sfx: "glass"),
        .init(id: "crate", hw: 10, top: 24, breakSpd: 80, keep: 0.45, hs: 3, word: "콰직!", sfx: "thud"),
        .init(id: "shoji", hw: 12, top: 70, breakSpd: 60, keep: 0.7, hs: 2, word: "부욱!", sfx: "clack"),
    ]
    public static func of(_ k: String) -> DojoObjKind? { all.first { $0.id == k } }
    /// 놓을 수 있는 최대 개수 · 놓는 범위(무대 x)
    public static let maxCount = 6, minX = 40.0, maxX = 440.0
}

/// 놓인 소품 하나(규칙 상태)
struct DojoObj {
    let id: Int
    var kind: String, x: Double
    var broken = false, age = 0.0, dir = 1.0
}

extension World {
    /// 소품 명령(DojoCommand.obj*) — 무도장 안에서만
    func nvObjCommand(_ c: DojoCommand) {
        guard let S = dj else { return }
        switch c {
        case .objAdd(let k, let x0):
            guard DojoObjKind.of(k) != nil, S.objs.count < DojoObjKind.maxCount else { return }
            S.objSeq += 1
            S.objs.append(DojoObj(id: S.objSeq, kind: k, x: nvObjClamp(x0 ?? nvObjDefaultX())))
        case .objMove(let id, let x): if let i = S.objs.firstIndex(where: { $0.id == id }) { S.objs[i].x = nvObjClamp(x) }
        case .objRemove(let id): S.objs.removeAll { $0.id == id }
        case .objClear: S.objs = []
        case .objRepair: nvObjRepair(force: true)
        case .objSet(let L):
            S.objs = []
            for s in L.prefix(DojoObjKind.maxCount) where DojoObjKind.of(s.kind) != nil { S.objSeq += 1; S.objs.append(DojoObj(id: S.objSeq, kind: s.kind, x: nvObjClamp(s.x))) }
        default: break
        }
    }
    func nvObjClamp(_ x: Double) -> Double { min(DojoObjKind.maxX, max(DojoObjKind.minX, jsRound(x))) }
    /// 새 소품 기본 자리: 허수아비 뒤(주인공 반대쪽) 70px
    func nvObjDefaultX() -> Double {
        guard let D = dojoDummy(), let H = hero else { return 360 }
        return D.x + (D.x >= H.x ? 1 : -1) * 70
    }
    /// 깨진 소품 되살리기(force 가 아니면 깨진 지 0.5초 지난 것만 — 시연 시작 때)
    func nvObjRepair(force: Bool) {
        guard let S = dj else { return }
        for i in S.objs.indices where S.objs[i].broken && (force || S.objs[i].age > 0.5) { S.objs[i].broken = false; S.objs[i].age = 0 }
        S.objHits = []
    }

    /// 매 틱: 날아가는 적이 소품에 부딪힘
    func nvObjTick(_ dt: Double) {
        guard let S = dj, !S.objs.isEmpty else { return }
        for i in S.objs.indices where S.objs[i].broken { S.objs[i].age += dt }
        for a in ents where a.e != nil && !a.dead {
            guard let J = a.jug, !J.roofOut else { S.objHits = S.objHits.filter { !$0.hasPrefix("\(a.id):") }; continue }
            let v = abs(a.kb) >= abs(J.vx) ? a.kb : J.vx, spd = abs(v)
            if spd < 40 || a.hs > 0 { continue }
            for i in S.objs.indices where !S.objs[i].broken {
                let o = S.objs[i]
                guard let K = DojoObjKind.of(o.kind), abs(a.x - o.x) <= K.hw, J.h <= K.top else { continue }
                let key = "\(a.id):\(o.id)"
                if S.objHits.contains(key) { continue }
                S.objHits.insert(key)
                let f: Double = v >= 0 ? 1 : -1, y = a.y - 20 - J.h
                if spd >= K.breakSpd {   // 깨진다
                    a.kb *= K.keep; J.vx *= K.keep; a.hs = max(a.hs, K.hs)
                    if o.kind == "glass" { a.x = o.x + f * 2 }   // 유리: 몸이 판 안으로 박힌다
                    nvObjBreak(i, f, comicY: y - 30)
                } else {                 // 느리면 부딪혀 튕긴다
                    a.kb = -f * min(80, spd * 0.3); J.vx = a.kb; a.x = o.x - f * (K.hw + 1); a.hs = max(a.hs, 2)
                    comicSFX(o.x, y - 20, "쿵!"); sfx("clack"); shake(1.4); djJolt(0.5)
                }
            }
        }
    }

    /// 소품 하나를 깬다(날아온 몸 · 광선 — 효과 · 글자 · 소리 · 흔들림 · 진동). comicY = 만화 글자 높이
    func nvObjBreak(_ i: Int, _ f: Double, comicY: Double) {
        guard let S = dj, S.objs.indices.contains(i), !S.objs[i].broken, let K = DojoObjKind.of(S.objs[i].kind) else { return }
        let o = S.objs[i], gy = hero?.y ?? 222
        S.objs[i].broken = true; S.objs[i].age = 0; S.objs[i].dir = f
        fx("objBreak:" + o.kind, o.x, gy - K.top / 2, f)
        comicSFX(o.x, comicY, K.word, force: true); sfx(K.sfx); if o.kind == "glass" { sfx("thud") }
        shake(o.kind == "crate" ? 2.4 : 3.2); emit(.haptic(o.kind == "shoji" ? .medium : .heavy)); djJolt(1.0)
    }
}
