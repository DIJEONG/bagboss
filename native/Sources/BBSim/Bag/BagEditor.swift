import Foundation
import BBCore
import BBContent

// 가방 편집 상태 기계(웹 33-bag-ui2 의 rotateItem · discardItem · askMerge · pushUndo/doUndo · 끌어 놓기 pointerup 분기,
// 27-actors quickEquip, 26-bag-model autoPack). UI 는 상태를 직접 바꾸지 않고 BagIntent 를 넣는다(docs/06 §2.7).
// 순수 값 타입 — 난수는 합성 굴림값(roll)으로 주입받는다.

/// 가방 화면이 다루는 판 상태 일부(웹 GS.bag · GS.stash · GS.tokens · GS.imprints · GS.uid · GS.selUid · 아이템 isNew)
public struct BagState: Sendable, Equatable, Codable {
    public var bag: [BagItem]
    public var stash: [BagItem]
    public var tokens: Int
    /// 각인 칸 "x,y" → holster · pocket · worn
    public var imprints: [String: String]
    /// 마지막으로 낸 uid(웹 GS.uid)
    public var uid: Int
    public var selUid: Int?
    /// 새로 들어온 보류함 아이템(웹 isNew) — 한 번 탭으로 빈자리에 장착
    public var newUids: Set<Int>

    public init(bag: [BagItem] = [], stash: [BagItem] = [], tokens: Int = 0, imprints: [String: String] = [:], uid: Int? = nil, selUid: Int? = nil, newUids: Set<Int> = []) {
        self.bag = bag; self.stash = stash; self.tokens = tokens; self.imprints = imprints
        self.uid = uid ?? (bag + stash).map(\.uid).max() ?? 0
        self.selUid = selUid; self.newUids = newUids
    }

    public enum Place: Sendable, Equatable { case bag(Int), stash(Int) }
    public func locate(_ uid: Int) -> Place? {
        if let i = bag.firstIndex(where: { $0.uid == uid }) { return .bag(i) }
        if let i = stash.firstIndex(where: { $0.uid == uid }) { return .stash(i) }
        return nil
    }
    /// 웹 findAny
    public func item(_ uid: Int) -> BagItem? {
        switch locate(uid) { case .bag(let i): bag[i]; case .stash(let i): stash[i]; case nil: nil }
    }
    public func inBag(_ uid: Int) -> Bool { bag.contains { $0.uid == uid } }
}

/// 끌어 놓을 곳
public enum BagTarget: Sendable, Equatable {
    /// 가방 칸(왼쪽 위 칸 · 방향)
    case bag(x: Int, y: Int, rot: Int)
    /// 보류함 칸(접힌 발자국 기준 왼쪽 위 · 방향)
    case stash(x: Int, y: Int, rot: Int)
    case trash
}

/// UI → 편집기 행동
public enum BagIntent: Sendable, Equatable {
    case select(Int?)
    case move(uid: Int, to: BagTarget)
    case rotate(uid: Int)
    case quickEquip(uid: Int)
    /// 합성: src(재료)를 dst 에 겹친다. roll ∈ [0,1) 은 주입한 난수(웹 Math.random 한 번)
    case merge(src: Int, dst: Int, boost: Bool, roll: Double)
    case discard(uid: Int)
    case autoPack
    case undo
    /// 콤보 갈림길 고정 핀 켜고 끄기(웹 .rt-fork)
    case togglePin(from: Int, to: Int)
}

/// 행동 결과 — 바뀌었는지와 웹 say() 문구
public struct BagOutcome: Sendable, Equatable {
    public var changed: Bool
    public var title: String?
    public var message: String?
    /// 합성이면 성공 여부
    public var merged: Bool?
    public static let none = BagOutcome(changed: false)
    public init(changed: Bool, title: String? = nil, message: String? = nil, merged: Bool? = nil) {
        self.changed = changed; self.title = title; self.message = message; self.merged = merged
    }
}

public struct BagEditor: Sendable {
    public let catalog: BagCatalog
    public private(set) var state: BagState
    /// 되돌리기(웹 GS.undo · 최대 20)
    public private(set) var undoStack: [Snapshot] = []
    /// 편집 가능(웹 canEdit) — 장면 · 컷신 중엔 false
    public var canEdit = true
    /// 전투 중(웹 inCombat) — 옮긴 기술의 쿨다운이 처음부터
    public var inCombat = false

    public static let undoMax = 20
    public static let lockNote = "장면이 끝나면 정리할 수 있어요"

    public struct Snapshot: Sendable, Equatable, Codable {
        public var bag: [BagItem], stash: [BagItem], tokens: Int, sel: Int?, newUids: Set<Int>
    }

    public init(catalog: BagCatalog, state: BagState) { self.catalog = catalog; self.state = state }

    var rules: BagRules { catalog.rules }
    func name(_ id: String) -> String { catalog.item(id)?.name ?? id }

    // MARK: 판정(UI 가 놓기 전에 묻는다)

    /// 웹 pointerup 의 합성 조건: 같은 아이템 · 같은 ★ · ★5 미만 · 대상이 가방이나 보류함에 있음
    public func canMerge(src: Int, dst: Int) -> Bool {
        guard src != dst, let a = state.item(src), let b = state.item(dst) else { return false }
        return a.id == b.id && a.tier == b.tier && b.tier < BagSpec.tierMax
    }
    /// 합성 성공 확률(웹 askMerge: min(.95, p + 부스트))
    public func mergeChance(dst: Int, boost: Bool) -> Double {
        let t = state.item(dst)?.tier ?? 1
        return min(0.95, catalog.mergeChance(tier: t) + (boost ? BagSpec.mergeBoost : 0))
    }
    public var canBoost: Bool { state.tokens >= BagSpec.boostCost }
    public var canUndo: Bool { canEdit && !undoStack.isEmpty }

    // MARK: 행동

    @discardableResult
    public mutating func apply(_ intent: BagIntent) -> BagOutcome {
        switch intent {
        case .select(let u): state.selUid = u; return BagOutcome(changed: true)
        case .move(let u, let t): return move(u, to: t)
        case .rotate(let u): return rotate(u)
        case .quickEquip(let u): return quickEquip(u)
        case .merge(let s, let d, let boost, let roll): return merge(src: s, dst: d, boost: boost, roll: roll)
        case .discard(let u): return discard(u)
        case .autoPack: return autoPack()
        case .undo: return undo()
        case .togglePin(let f, let t): return togglePin(from: f, to: t)
        }
    }

    /// 웹 pushUndo
    mutating func pushUndo() {
        guard canEdit else { return }
        undoStack.append(Snapshot(bag: state.bag, stash: state.stash, tokens: state.tokens, sel: state.selUid, newUids: state.newUids))
        if undoStack.count > Self.undoMax { undoStack.removeFirst() }
    }
    /// 웹 cdReset: 전투 중 기술을 옮기면 쿨다운이 처음부터
    mutating func cdReset(_ uid: Int) {
        guard inCombat else { return }
        switch state.locate(uid) {
        case .bag(let i) where catalog.item(state.bag[i].id)?.kind == "skill": state.bag[i].t = 0
        case .stash(let i) where catalog.item(state.stash[i].id)?.kind == "skill": state.stash[i].t = 0
        default: break
        }
    }

    /// 웹 doUndo
    mutating func undo() -> BagOutcome {
        guard canEdit, let s = undoStack.popLast() else { return .none }
        state.bag = s.bag; state.stash = s.stash; state.tokens = s.tokens; state.selUid = s.sel; state.newUids = s.newUids
        return BagOutcome(changed: true, message: "되돌렸어요")
    }

    /// 끌어 놓기(웹 pointerup): 휴지통 · 보류함 · 가방 칸
    mutating func move(_ uid: Int, to target: BagTarget) -> BagOutcome {
        guard canEdit else { return BagOutcome(changed: false, message: Self.lockNote) }
        guard let place = state.locate(uid), var b = state.item(uid) else { return .none }
        switch target {
        case .trash:
            return discard(uid)
        case .stash(let x, let y, let rot):   // 보류함: 그 자리에 못 두면(가방에서 왔을 때만) 빈 곳에
            let fromBag: Bool; if case .bag = place { fromBag = true } else { fromBag = false }
            var sp: (sx: Int, sy: Int, rot: Int)?
            if rules.canStash(b, x: x, y: y, rot: rot, in: state.stash) { sp = (x, y, rot) } else if fromBag { sp = rules.stashSpot(b, in: state.stash, rot0: rot) }
            guard let s = sp else { return fromBag ? BagOutcome(changed: false, message: "보류함에 자리가 모자라요") : .none }
            pushUndo()
            b.sx = s.sx; b.sy = s.sy; b.rot = s.rot
            switch place {
            case .bag(let i): state.bag.remove(at: i); state.stash.append(b)
            case .stash(let i): state.stash[i] = b
            }
            return BagOutcome(changed: true)
        case .bag(let x, let y, let rot):
            guard rules.canPlace(b, x: x, y: y, rot: rot, in: state.bag) else { return .none }
            pushUndo(); cdReset(uid); b = state.item(uid)!
            state.newUids.remove(uid)
            b.x = x; b.y = y; b.rot = rot
            switch place {
            case .bag(let i): state.bag[i] = b
            case .stash(let i): state.stash.remove(at: i); state.bag.append(b)
            }
            return BagOutcome(changed: true)
        }
    }

    /// 웹 rotateItem: 한 칸 돌리고, 안 맞으면 옆으로 조금 밀어 본다(가방 6방향 · 보류함 8방향)
    mutating func rotate(_ uid: Int) -> BagOutcome {
        guard canEdit else { return BagOutcome(changed: false, message: Self.lockNote) }
        guard state.item(uid) != nil else { return .none }
        pushUndo(); cdReset(uid)
        guard let place = state.locate(uid) else { return .none }
        switch place {
        case .stash(let i):
            let b = state.stash[i], nr = (b.rot + 1) % 4, sx = b.sx ?? 0, sy = b.sy ?? 0
            for (dx, dy) in [(0, 0), (-1, 0), (0, -1), (-1, -1), (1, 0), (0, 1), (0, -2), (-1, -2)] where rules.canStash(b, x: sx + dx, y: sy + dy, rot: nr, in: state.stash) {
                state.stash[i].sx = sx + dx; state.stash[i].sy = sy + dy; state.stash[i].rot = nr
                return BagOutcome(changed: true)
            }
            return BagOutcome(changed: true, message: "보류함에서 돌릴 자리가 모자라요")
        case .bag(let i):
            let b = state.bag[i], nr = (b.rot + 1) % 4
            for (dx, dy) in [(0, 0), (-1, 0), (0, -1), (-1, -1), (1, 0), (0, 1)] where rules.canPlace(b, x: b.x + dx, y: b.y + dy, rot: nr, in: state.bag) {
                state.bag[i].x = b.x + dx; state.bag[i].y = b.y + dy; state.bag[i].rot = nr
                return BagOutcome(changed: true)
            }
            // 웹과 같이 되돌리기 칸은 이미 쌓였다(되돌려도 그대로)
            return BagOutcome(changed: true, message: "옆 칸을 비우면 돌릴 수 있어요")
        }
    }

    /// 웹 quickEquip: 보류함 아이템을 가방 빈자리(findSpot)에
    mutating func quickEquip(_ uid: Int) -> BagOutcome {
        guard let i = state.stash.firstIndex(where: { $0.uid == uid }) else { return .none }
        guard let sp = rules.findSpot(state.stash[i], in: state.bag) else { return BagOutcome(changed: false, message: "빈자리를 만들면 넣을 수 있어요") }
        pushUndo()
        var b = state.stash.remove(at: i); b.x = sp.x; b.y = sp.y; b.rot = sp.rot
        state.bag.append(b); state.newUids.remove(uid); cdReset(uid); state.selUid = uid
        return BagOutcome(changed: true)
    }

    /// 웹 discardItem: 버리고 토큰(칸 수 × ★)을 받는다
    mutating func discard(_ uid: Int) -> BagOutcome {
        guard canEdit else { return BagOutcome(changed: false, message: Self.lockNote) }
        guard let b = state.item(uid) else { return .none }
        pushUndo()
        let v = rules.tokenValue(b)
        state.bag.removeAll { $0.uid == uid }; state.stash.removeAll { $0.uid == uid }; state.newUids.remove(uid)
        state.tokens += v; state.selUid = nil
        return BagOutcome(changed: true, message: "\(name(b.id))을(를) 버리고 토큰 \(v)개를 받았어요")
    }

    /// 웹 askMerge → 합성하기: 성공하면 ★+1(옵션 상속), 실패하면 재료만 잃고 토큰 1개
    mutating func merge(src: Int, dst: Int, boost wantBoost: Bool, roll: Double) -> BagOutcome {
        guard canEdit else { return BagOutcome(changed: false, message: Self.lockNote) }
        guard canMerge(src: src, dst: dst), let s = state.item(src), let d0 = state.item(dst) else { return .none }
        pushUndo()
        let t = d0.tier, p = catalog.mergeChance(tier: t)
        let boost = wantBoost && state.tokens >= BagSpec.boostCost
        if boost { state.tokens -= BagSpec.boostCost }
        let ok = roll < min(0.95, p + (boost ? BagSpec.mergeBoost : 0))
        state.bag.removeAll { $0.uid == src }; state.stash.removeAll { $0.uid == src }; state.newUids.remove(src)
        if !ok { state.tokens += 1 }
        if ok {
            var d = state.item(dst)!
            d.tier = t + 1
            if let so = s.opt {
                if let dop = d.opt {
                    if dop.k == so.k {
                        let cap = catalog.options[dop.k]?.cap ?? 1
                        d.opt = ItemOption(k: dop.k, v: min(cap, Double(JSFormat.round((dop.v + so.v * 0.5) * 100)) / 100))
                    }
                } else { d.opt = so }
            }
            let nd = d
            update(dst) { $0 = nd }
            cdReset(dst)
        }
        state.selUid = dst
        let n = name(d0.id)
        return ok ? BagOutcome(changed: true, title: "합성 성공!", message: "\(n) ★\(t + 1)", merged: true)
            : BagOutcome(changed: true, title: "합성 실패", message: "재료를 잃었지만 토큰 1개를 돌려받았어요. \(n)은(는) ★\(t) 그대로", merged: false)
    }

    /// 웹 '빈자리에 넣기'(pushUndo + autoPack): 보류함의 큰 것부터 가방 빈자리에
    mutating func autoPack() -> BagOutcome {
        guard canEdit else { return BagOutcome(changed: false, message: Self.lockNote) }
        pushUndo()
        var n = 0
        let order = stableSorted(state.stash) { rules.size($1.id) - rules.size($0.id) }
        for it in order {
            guard let sp = rules.findSpot(it, in: state.bag), let i = state.stash.firstIndex(where: { $0.uid == it.uid }) else { continue }
            var b = state.stash.remove(at: i); b.x = sp.x; b.y = sp.y; b.rot = sp.rot; state.bag.append(b); n += 1
        }
        return BagOutcome(changed: true, message: n > 0 ? "보류함의 \(n)개를 빈자리에 넣었어요" : "빈자리를 만들면 넣을 수 있어요")
    }

    mutating func togglePin(from: Int, to: Int) -> BagOutcome {
        guard state.item(from) != nil else { return .none }
        update(from) { $0.pin = $0.pin == to ? nil : to }
        return BagOutcome(changed: true)
    }

    mutating func update(_ uid: Int, _ f: (inout BagItem) -> Void) {
        switch state.locate(uid) {
        case .bag(let i): f(&state.bag[i])
        case .stash(let i): f(&state.stash[i])
        case nil: break
        }
    }

    /// 바깥(전투 쿨다운 누적 · 매점 등)이 바꾼 판 상태를 넣는다 — 되돌리기 칸은 그대로
    public mutating func replaceState(_ s: BagState) { state = s }

    // MARK: 아이템 넣기(매점 · 보상)

    /// 웹 addToStash 의 자리 잡기 부분: 새 uid 로 보류함에(빈 곳이 없으면 토큰으로). 반환 = 들어간 uid
    @discardableResult
    public mutating func addToStash(_ id: String, tier: Int = 1, opt: ItemOption? = nil, markNew: Bool = true) -> Int? {
        state.uid += 1
        var it = BagItem(id: id, uid: state.uid, tier: tier, opt: opt)
        guard let sp = rules.stashSpot(it, in: state.stash) else { state.tokens += rules.tokenValue(it); return nil }
        it.sx = sp.sx; it.sy = sp.sy; it.rot = sp.rot
        state.stash.append(it); if markNew { state.newUids.insert(it.uid) }
        return it.uid
    }
}
