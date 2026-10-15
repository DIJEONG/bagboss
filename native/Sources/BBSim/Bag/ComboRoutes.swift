import Foundation
import BBContent

// 콤보 경로(웹 32-block-art.js): 시작기 ▶에서 붙은 블록을 따라 이어지는 순서.
// 상태: G 지상 · A 공중 · T 걸림 · C 무너짐 · D 다운 · B 등 돌림 · K 날림 · P 끌림 · Z 경직 · * 아무 상태 · = 그대로

public struct ComboRoute: Sendable, Equatable {
    public var uids: [Int]
    public var key: String { uids.map(String.init).joined(separator: ">") }
    public var name: String
}

extension BagRules {
    /// 역할: S 시작기 · L 이음기 · F 마무리기 · X 경로 밖
    public func role(_ id: String) -> String {
        if let r = roles[id] { return r.r }
        return def(id)?.kind == "skill" ? "L" : "X"
    }
    func stateIn(_ id: String) -> String { roles[id]?.i ?? "*" }
    func stateOut(_ id: String) -> String { roles[id]?.o ?? "=" }
    /// 걸림은 곧 다운 · 경직 · 끌림 · 등 돌림은 서 있는 적
    static let stateOK: [String: [String]] = ["T": ["T", "D", "A"], "C": ["C", "G"], "Z": ["Z", "G"], "P": ["P", "G"], "B": ["B", "G"], "K": ["K", "A"], "A": ["A", "D"], "D": ["D"], "G": ["G"]]
    func fits(_ input: String, _ st: String) -> Bool { input == "*" || input == st || (Self.stateOK[st] ?? []).contains(input) }
    func nextState(_ id: String, _ st: String) -> String { let o = stateOut(id); return o == "=" ? st : o }
    func isSkill(_ b: BagItem) -> Bool { def(b.id)?.kind == "skill" }
    /// 읽는 순서(가장 위 줄 → 그 줄의 가장 왼쪽)
    func readKey(_ b: BagItem) -> Int {
        let c = cells(b), y = c.map(\.y).min()!
        return y * 100 + c.filter { $0.y == y }.map(\.x).min()!
    }
    func adjacentIn(_ list: [BagItem], _ b: BagItem) -> [BagItem] {
        let mine = Set(cells(b))
        return list.filter { o in o.uid != b.uid && cells(o).contains { c in
            mine.contains(Cell(c.x + 1, c.y)) || mine.contains(Cell(c.x - 1, c.y)) || mine.contains(Cell(c.x, c.y + 1)) || mine.contains(Cell(c.x, c.y - 1)) } }
    }

    /// 웹 routeFrom: 최대 6단. 우선순위 고정 핀 → 보통 이음기(시작기는 뒤로) → 딱 맞는 상태 → 읽는 순서
    public func route(from b0: BagItem, in list: [BagItem], state st0: String = "G", used used0: Set<Int> = []) -> [BagItem] {
        var R = [b0], used = used0; used.insert(b0.uid)
        var cur = b0, st = nextState(b0.id, st0)
        while R.count < 6 && !(role(cur.id) == "F" && R.count > 1) {
            let cand = adjacentIn(list, cur).filter { isSkill($0) && !used.contains($0.uid) && role($0.id) != "X" && fits(stateIn($0.id), st) }
            if cand.isEmpty { break }
            let s = st, c0 = cur
            let sorted = stableSorted(cand) { a, b in
                let pa = a.uid == c0.pin ? 0 : 1, pb = b.uid == c0.pin ? 0 : 1; if pa != pb { return pa - pb }
                let sa = role(a.id) == "S" ? 1 : 0, sb = role(b.id) == "S" ? 1 : 0; if sa != sb { return sa - sb }
                let fa = stateIn(a.id) == s ? 0 : 1, fb = stateIn(b.id) == s ? 0 : 1; if fa != fb { return fa - fb }
                return readKey(a) - readKey(b)
            }
            cur = sorted[0]; R.append(cur); used.insert(cur.uid); st = nextState(cur.id, st)
        }
        return R
    }

    /// 웹 bookOf: 도감 레시피 중 앞부분이 맞는 가장 긴 것
    public func recipe(_ ids: [String]) -> ComboRecipe? {
        var best: ComboRecipe?
        for B in book where ids.count >= B.route.count && zip(B.route, ids).allSatisfy({ $0 == $1 }) && (best == nil || B.route.count > best!.route.count) { best = B }
        return best
    }
    /// 웹 comboName
    public func comboName(_ R: [BagItem]) -> String {
        if let f = R.first, def(f.id)?.pro == true { return R.count >= 4 ? "장도리 난타" : "장도리 \(R.count)연격" }
        if let B = recipe(R.map(\.id)) { return B.name }
        let head = stateNames[stateOut(R[0].id)] ?? "연속"
        return "\(head) \(R.count)\(role(R[R.count - 1].id) == "F" ? "연격" : "연타")"
    }
    /// 웹 routesOf: 시작기마다(읽는 순서) 경로 — 2단 이상만
    public func routes(_ list: [BagItem]) -> [ComboRoute] {
        stableSorted(list.filter { isSkill($0) && role($0.id) == "S" }) { readKey($0) - readKey($1) }
            .map { route(from: $0, in: list) }
            .filter { $0.count >= 2 }
            .map { ComboRoute(uids: $0.map(\.uid), name: comboName($0)) }
    }
}

/// JS Array.prototype.sort(비교 함수)와 같은 안정 정렬
func stableSorted<T>(_ a: [T], _ cmp: (T, T) -> Int) -> [T] {
    a.enumerated().sorted { x, y in let c = cmp(x.element, y.element); return c != 0 ? c < 0 : x.offset < y.offset }.map(\.element)
}
