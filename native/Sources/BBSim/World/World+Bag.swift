import Foundation
import BBCore
import BBContent

// 웹 26-bag-model.js(pv · computeSets · linkFire · fitBag · stashPut · newItem · rollOpt · addToStash · autoPack)
// + 27 sStats · heroMax · heroSpd + 33-bag-ui2.js 규칙 부분(impOf · watchFlow · genImprints · contribAdd/Trig · cmdSkill)
// + renderBag 의 규칙 부분(최대 체력 · 세트 다시 계산 · 보류함 정리).
// 판정 자체(모양 · 닿음 · 능력치)는 Bag/BagModel.swift(BagRules — 웹 대조 완료)를 그대로 쓴다.

extension World {
    var rules: BagRules { data.catalog.rules }
    /// 가방 값 사본(BagRules 입력)
    func bagStructs() -> [BagItem] { bag.map(\.bagItem) }

    /// 웹 pv(kind, base, per): 같은 종류 보조 아이템 합
    func pv(_ kind: String, _ base: Double, _ per: Double) -> Double {
        bag.reduce(0) { item($1.id)?.kind == kind ? $0 + base + per * Double($1.tier - 1) : $0 }
    }
    /// 웹 has(k)
    func has(_ k: String) -> Int { bag.filter { item($0.id)?.kind == k }.count }
    /// 웹 heroMax · heroSpd
    func heroMax() -> Double { 120 + jsRound(pv("armor", 30, 15)) }
    func heroSpd() -> Double { 46 * (1 + pv("shoes", 0.3, 0.05)) }
    /// 웹 comboWin()
    func comboWin() -> Double { 2.2 + pv("gum", 1.5, 0.3) }

    /// 웹 sStats(i) — 가방 배치 · 세트 · 각인이 같으면 다시 계산하지 않는다
    func sStats(_ i: Int) -> BagRules.ItemStats {
        var h = Hasher()
        for b in bag { h.combine(b.uid); h.combine(b.id); h.combine(b.x); h.combine(b.y); h.combine(b.rot); h.combine(b.tier); h.combine(b.opt?.k); h.combine(b.opt?.v) }
        h.combine(i); h.combine(setsVersion); h.combine(imprintsVersion)
        let key = h.finalize()
        if let c = statsCache[key] { return c }
        let st = rules.stats(i, bag: bagStructs(), sets: sets, imprints: imprints)
        if statsCache.count > 512 { statsCache.removeAll(keepingCapacity: true) }
        statsCache[key] = st
        return st
    }
    /// sStats(i).cd — 기술이 아니면 웹은 NaN(비교가 늘 거짓)
    func cdOf(_ i: Int) -> Double { sStats(i).cd ?? .nan }

    /// 웹 adjItems(i) → 가방 안 위치들
    func adjItems(_ i: Int) -> [Int] { rules.adjacent(i, in: bagStructs()) }
    /// 웹 cellsOf(b)
    func cellsOf(_ b: Item) -> [Cell] { rules.cells(b.bagItem) }

    /// 웹 computeSets
    @discardableResult
    func computeSets() -> [String: [Int]] {
        let on = rules.sets(bagStructs())
        if on != sets { sets = on; setsVersion &+= 1 }
        if on["foot"] != nil && self.on { stats.footSet = 1 }
        return on
    }
    /// 웹 inSet(b)
    func inSet(_ b: Item) -> Bool { guard let f = item(b.id)?.fam else { return false }; return sets[f]?.contains(b.uid) ?? false }
    /// 웹 impOf(b)
    func impOf(_ b: Item) -> Set<String> { rules.imprints(b.bagItem, imprints) }

    // MARK: 연계(LINKS)

    /// 웹 bagHasLink(id)
    func bagHasLink(_ id: String) -> Bool {
        if demo { return true }
        guard let L = data.catalog.links.first(where: { $0.id == id }) else { return false }
        let bs = bagStructs()
        return bag.indices.contains { i in L.a(bag[i].id) && rules.adjacent(i, in: bs).contains { L.b(bag[$0].id) } }
    }
    /// 웹 srcLinked(id): 지금 기술(curSrc)이 그 연계의 a 쪽이고 b 쪽이 닿아 있나
    func srcLinked(_ id: String) -> Bool {
        if demo { return true }
        guard let i = bag.firstIndex(where: { $0.uid == curSrc }), let L = data.catalog.links.first(where: { $0.id == id }) else { return false }
        return L.a(bag[i].id) && adjItems(i).contains { L.b(bag[$0].id) }
    }
    /// 웹 CHAIN_K
    func chainK(_ t: Int) -> Double { 0.15 + 0.04 * Double(t - 1) }

    /// 웹 linkFire(i, ev): src 가 적중 · 넘어뜨림 · 띄움 · 피함을 일으켰을 때 닿은 아이템 쿨다운 충전
    func linkFire(_ i: Int, _ ev: String) {
        guard bag.indices.contains(i) else { return }
        let src = bag[i]
        var fired: [Item] = []
        for j0 in adjItems(i) {
            let o = bag[j0]
            guard let j = bag.firstIndex(where: { $0 === o }), let oi = item(o.id) else { continue }
            if let L = data.catalog.links.first(where: { $0.a(src.id) && $0.b(o.id) && $0.on == ev }) {
                if !meta.links.contains(L.id) { meta.links.insert(L.id); emit(.metaChanged) }
                o.t = cdOf(j); linkAt[L.id] = time
                if L.id == "rush" { o.combo = 1; o.last = time }
                if L.id == "scoop" && o.id == "punch" { o.combo = 2; o.last = time }
                if L.id == "dodge" { o.emp = true }
                fired.append(o); stats.links += 1
                emit(.linkFired(source: src.uid, targets: [o.uid], link: L.id))
                continue
            }
            if ev == "hit" && oi.kind == "skill" && item(src.id)?.kind == "skill" && data.catalog.linkBetween(src.id, o.id) == nil {   // 연쇄는 적중 한 번에 한 번
                let cd = cdOf(j); o.t = min(cd, o.t + cd * chainK(src.tier)); emit(.chainCharged(item: o.uid))
            }
        }
        if !fired.isEmpty { hint("link"); fired.forEach { $0.linkMark = true }; flashText("LINK", 0.6) }
    }

    // MARK: 배치 · 보류함

    /// 웹 findSpot(b) — 지금 가방 기준
    func findSpot(_ b: Item) -> (x: Int, y: Int, rot: Int)? { rules.findSpot(b.bagItem, in: bagStructs()) }
    func tokenValue(_ b: Item) -> Int { rules.size(b.id) * b.tier }

    /// 웹 fitBag
    func fitBag() {
        let all = bag; bag = []
        for b in all {
            if rules.canPlace(b.bagItem, x: b.x, y: b.y, rot: b.rot, in: bagStructs(), except: b.uid) { bag.append(b); continue }
            if let sp = findSpot(b) { b.x = sp.x; b.y = sp.y; b.rot = sp.rot; bag.append(b) }
            else if !stashPut(b) { tokens += tokenValue(b) }
        }
    }
    func stashSpot(_ b: Item) -> (sx: Int, sy: Int, rot: Int)? { rules.stashSpot(b.bagItem, in: stash.map(\.bagItem)) }
    /// 웹 stashPut(it): 빈 곳이 없으면 큰 것부터 다시 채워 본다(실패하면 그대로 두고 false)
    @discardableResult
    func stashPut(_ it: Item) -> Bool {
        if let sp = stashSpot(it) { it.sx = sp.sx; it.sy = sp.sy; it.rot = sp.rot; if !stash.contains(where: { $0 === it }) { stash.append(it) }; return true }
        let prev = stash.filter { $0 !== it }, save = prev.map { ($0, $0.sx, $0.sy, $0.rot) }
        stash = []
        let order = stableSort(prev + [it]) { rules.size($1.id) - rules.size($0.id) }
        for o in order {
            guard let q = stashSpot(o) else {
                stash = prev; for (o2, x, y, r) in save { o2.sx = x; o2.sy = y; o2.rot = r }
                return false
            }
            o.sx = q.sx; o.sy = q.sy; o.rot = q.rot; stash.append(o)
        }
        return true
    }
    /// 웹 normStash
    func normStash() {
        let all = stash; var bad: [Item] = []; stash = []
        for b in all {
            if let sx = b.sx, let sy = b.sy, rules.canStash(b.bagItem, x: sx, y: sy, rot: b.rot, in: stash.map(\.bagItem), except: b.uid) { stash.append(b) } else { bad.append(b) }
        }
        for b in bad {
            if stashPut(b) { continue }
            if let sp = findSpot(b) { b.x = sp.x; b.y = sp.y; b.rot = sp.rot; bag.append(b); continue }
            tokens += tokenValue(b); say("", "보류함에 자리가 없어 \(item(b.id)?.name ?? b.id)을(를) 토큰 \(tokenValue(b))개로 바꿨어요", 1.8)
        }
    }
    /// 웹 newItem
    func newItem(_ id: String, _ tier: Int = 1, _ opt: ItemOption? = nil) -> Item { uid += 1; return Item(id: id, uid: uid, tier: tier, opt: opt) }
    /// 웹 rollOpt(id, p, Rr)
    func rollOpt(_ id: String, _ p: Double, _ R: (() -> Double)? = nil) -> ItemOption? {
        let Rr = R ?? { self.rnd() }
        if item(id)?.kind != "skill" || Rr() >= p { return nil }
        let ks = ["crit", "critd", "dmg", "cd"]
        let k = ks[Int((Rr() * Double(ks.count)).rounded(.down))]
        guard let O = data.catalog.options[k] else { return nil }
        return ItemOption(k: k, v: jsRound((O.lo + Rr() * (O.hi - O.lo)) * 100) / 100)
    }
    func metaItem(_ id: String, _ tier: Int) { if (meta.items[id] ?? 0) < tier { meta.items[id] = tier; emit(.metaChanged) } }
    /// 웹 addToStash
    @discardableResult
    func addToStash(_ id: String, _ tier: Int = 1, _ note: Bool = false, _ opt: ItemOption? = nil) -> Item? {
        let it = newItem(id, tier, opt); metaItem(id, tier)
        if !stashPut(it) {
            tokens += tokenValue(it)
            if note { say("", "보류함이 가득 차 \(item(id)?.name ?? id)을(를) 토큰 \(tokenValue(it))개로 바꿨어요", 1.8) }
            return nil
        }
        onboardItem(id); return it
    }
    /// 웹 onboardItem: 첫 시작기 · 첫 마무리기 안내(한 번씩)
    func onboardItem(_ id: String) { if pBag { return }; let r = rules.role(id); if r == "F" { talkSoon("fin") } else if r == "S" { talkSoon("st") } }
    /// 웹 autoPack
    @discardableResult
    func autoPack() -> Int {
        var n = 0
        for it in stableSort(stash, { rules.size($1.id) - rules.size($0.id) }) {
            if let sp = findSpot(it) { it.x = sp.x; it.y = sp.y; it.rot = sp.rot; bag.append(it); stash.removeAll { $0 === it }; n += 1 }
        }
        hero?.pick = nil; renderBag(); return n
    }
    /// 웹 renderBag 의 규칙 부분: 최대 체력 · 세트 · 보류함 정리 · 장착 안내 확인
    func renderBag() {
        maxHP = heroMax(); hp = min(hp, maxHP); hero?.pick = nil; computeSets(); normStash()
        if let eh = equipHint { if let hb = stash.first(where: { $0.uid == eh.uid }), findSpot(hb) != nil {} else { equipHint = nil } }
        if on && !demo { forkCheck() }   // 웹 renderRoutes: 갈림길이 생기면 talkSoon('fork')
        emit(.bagChanged)
    }
    /// 웹 cdReset(b): 전투 중 옮긴 기술은 쿨다운이 처음부터
    func cdReset(_ b: Item) { if inCombat() && item(b.id)?.kind == "skill" { b.t = 0 } }
    /// 웹 inCombat
    func inCombat() -> Bool { !foes().isEmpty && !["shop", "arrange", "transfer", "over"].contains(state) }

    /// 웹 quickEquip(uid)
    @discardableResult
    func quickEquip(_ u: Int) -> Bool {
        guard let b = stash.first(where: { $0.uid == u }) else { return false }
        guard let sp = findSpot(b) else { say("", "빈자리를 만들면 넣을 수 있어요", 1.2); return false }
        b.x = sp.x; b.y = sp.y; b.rot = sp.rot; stash.removeAll { $0 === b }; bag.append(b); b.isNew = false; cdReset(b); selUid = b.uid
        if equipHint?.uid == u { equipHint = nil }
        sfx("click"); renderBag(); return true
    }
    /// 웹 gainGear(id, tier, opt)
    @discardableResult
    func gainGear(_ id: String, _ tier: Int, _ opt: ItemOption?) -> Item? {
        guard let n = addToStash(id, tier, true, opt) else { return nil }
        n.isNew = true; selUid = n.uid
        let sp = findSpot(n); if sp != nil { equipHint = (n.uid, 6) }
        renderBag()
        if !pBag { say("", sp != nil ? "\(item(id)?.name ?? id) 획득 — 보류함을 탭하면 빈자리에 바로 넣어요" : "\(item(id)?.name ?? id)을(를) 주워 보류함에 넣었어요", 2) }   // 콤보 쇼 중엔 줍기 알림을 띄우지 않는다
        emit(.pickedUp(kind: "gear", item: id))
        return n
    }

    // MARK: 방향 시너지 · 각인 · 기여

    /// 웹 watchFlow(src): 손목시계 들어오는 끝에 닿은 기술이 적중하면 나가는 끝 기술 충전
    func watchFlow(_ src: Item) {
        for w in bag where item(w.id)?.kind == "watch" && w !== src {
            let c = cellsOf(w); guard c.count >= 2 else { continue }
            let inC = c[0], outC = c[1]
            func touches(_ it: Item, _ q: Cell) -> Bool { cellsOf(it).contains { abs($0.x - q.x) + abs($0.y - q.y) == 1 } }
            if !touches(src, inC) || touches(src, outC) { continue }
            let k = 0.30 + 0.05 * Double(w.tier - 1)
            for o in bag where o !== src && o !== w && item(o.id)?.kind == "skill" && touches(o, outC) {
                guard let j = bag.firstIndex(where: { $0 === o }) else { continue }
                let cd = cdOf(j); o.t = min(cd, o.t + cd * k); emit(.chainCharged(item: o.uid))
            }
        }
    }
    /// 웹 genImprints: 각인 칸 셋(권총집 · 비밀 주머니 · 해진 안감)
    func genImprints() -> [String: String] {
        var I: [String: String] = [:], cells: [String] = []
        for y in 0..<BagSpec.height { for x in 0..<BagSpec.width { cells.append("\(x),\(y)") } }
        if config.daily, let dk = config.dateKey {   // 오늘의 판: 날짜 시드(웹 mulberry(hashStr(todayKey()+':imp')))
            var r = Mulberry32(seed: Int32(bitPattern: World.hashStr(dk + ":imp")))
            for t in ["holster", "pocket", "worn"] { let k = cells.remove(at: Int((r.next() * Double(cells.count)).rounded(.down))); I[k] = t }
            return I
        }
        for t in ["holster", "pocket", "worn"] { let k = cells.remove(at: rndInt(cells.count)); I[k] = t }
        return I
    }
    func contribAdd(_ u: Int, _ d: Double) { contrib[u, default: (0, 0)].dmg += d; contribRun[u, default: (0, 0)].dmg += d }
    func contribTrig(_ u: Int) { contrib[u, default: (0, 0)].n += 1; contribRun[u, default: (0, 0)].n += 1 }
    /// 웹 cmdSkill(b, crit, step) · cmdPush — 왼쪽 위 기술 이름 줄(표현)
    func cmdSkill(_ b: Item, _ crit: Bool, _ step: Int) {
        let it = item(b.id)
        let nm = it?.combo == true ? ["잽", "크로스", "훅", "어퍼"][step] : (it?.name ?? b.id)
        emit(.command(name: nm, tag: crit ? "crit" : b.linkMark ? "link" : (it?.fam ?? ""))); b.linkMark = false
    }
    func cmdPush(_ name: String, _ tag: String = "") { emit(.command(name: name, tag: tag)) }
}

/// JS Array.prototype.sort(비교) 와 같은 안정 정렬
func stableSort<T>(_ a: [T], _ cmp: (T, T) -> Int) -> [T] {
    a.enumerated().sorted { x, y in let c = cmp(x.element, y.element); return c != 0 ? c < 0 : x.offset < y.offset }.map(\.element)
}
func stableSortD<T>(_ a: [T], _ cmp: (T, T) -> Double) -> [T] {
    a.enumerated().sorted { x, y in let c = cmp(x.element, y.element); return c != 0 && !c.isNaN ? c < 0 : x.offset < y.offset }.map(\.element)
}
