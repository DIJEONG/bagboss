import Foundation
import Observation
import StoreKit
import BBPersistence

// StoreKit 2 — 주인공 양복 스킨 3종(비소모성). 웹 OPT.skin 해금과 연결(docs/01 2단계 ②).
//   상품 ID: FeatureConfig.json (com.dijeong.bagboss.skin.<스킨>) · 무료: jw
//   근거는 Transaction.currentEntitlements(기기에 서명된 거래 — 오프라인에서도 읽힌다). 결과는 'bbn-skins' 캐시(BBPersistence SkinUnlocks)에 남겨
//   앱을 켠 직후 · StoreKit 이 늦을 때도 산 스킨이 잠기지 않는다.
//   Transaction.updates 는 앱이 켜져 있는 내내 듣는다(다른 기기 구매 · 승인 대기 · 환불 · 가족 공유).
// 결제 강요 화면(페이월)은 없다: 잠긴 스킨은 가격만 보이고 미리보기는 언제나 된다.
// 시뮬레이터 시험: Xcode 에서 실행하면 스킴의 StoreKit 구성(native/App/StoreKit/BagBossSkins.storekit)이 쓰인다.

@MainActor @Observable
final class SkinStore {
    static let shared = SkinStore()

    /// 스킨 열쇠 → 상품(불러오기 전 · 스토어 연결이 없으면 비어 있다)
    private(set) var products: [String: Product] = [:]
    private(set) var unlocks = SkinUnlocks()
    /// 사는 중인 스킨(단추 막기)
    private(set) var purchasing: String?
    private(set) var restoring = false
    private(set) var productsLoaded = false
    /// 사용자에게 보일 짧은 안내(구매 대기 · 실패 · 복원 결과)
    var notice: String?

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var save: SaveStore?
    @ObservationIgnored private var updates: Task<Void, Never>?

    private var config: FeatureConfig { .shared }

    func boot(save: SaveStore?) {
        self.save = save
        unlocks = save?.skinUnlocks() ?? SkinUnlocks()
        guard updates == nil else { return }
        updates = Task.detached(priority: .background) {
            for await r in Transaction.updates {
                if case .verified(let t) = r { await t.finish() }
                await SkinStore.shared.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements(); await loadProducts() }
    }

    func isUnlocked(_ k: String) -> Bool { unlocks.isUnlocked(k, free: config.free) }
    func isFree(_ k: String) -> Bool { config.free.contains(k) }
    /// 가격 글(불러온 상품의 지역 가격) — 없으면 nil
    func price(_ k: String) -> String? { products[k]?.displayPrice }

    func loadProducts() async {
        let ids = config.skins.map(\.productID)
        guard !ids.isEmpty else { return }
        do {
            let ps = try await Product.products(for: ids)
            var m: [String: Product] = [:]
            for p in ps { if let k = config.skin(forProduct: p.id) { m[k] = p } }
            products = m
        } catch {
            #if DEBUG
            print("[store] 상품 불러오기 실패: \(error)")
            #endif
        }
        productsLoaded = true
    }

    /// 지금 가진 스킨(서명 확인된 거래 · 환불 안 됨)
    func refreshEntitlements() async {
        var owned = Set<String>()
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, t.revocationDate == nil, let k = config.skin(forProduct: t.productID) else { continue }
            owned.insert(k)
        }
        apply(owned)
    }

    private func apply(_ owned: Set<String>) {
        guard owned != unlocks.owned else { return }
        unlocks.owned = owned
        save?.setSkinUnlocks(unlocks)
        onChange?()
    }

    /// 사기 — 성공하면 true(바로 입히는 것은 부르는 쪽)
    @discardableResult
    func purchase(_ k: String) async -> Bool {
        guard purchasing == nil else { return false }
        if products[k] == nil { await loadProducts() }
        guard let p = products[k] else { notice = KE("스토어에 연결할 수 없어요. 잠시 뒤 다시 해 주세요.", "Can't reach the App Store. Try again later."); return false }
        purchasing = k; defer { purchasing = nil }
        do {
            switch try await p.purchase() {
            case .success(let v):
                guard case .verified(let t) = v else { notice = KE("구매를 확인하지 못했어요.", "Couldn't verify the purchase."); return false }
                await t.finish()
                var o = unlocks.owned; o.insert(k); apply(o)
                notice = nil
                return true
            case .pending:
                notice = KE("승인을 기다리는 중이에요(보호자 승인 등). 승인되면 바로 열려요.", "Waiting for approval. It unlocks as soon as it's approved.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            notice = KE("구매하지 못했어요: \(error.localizedDescription)", "Purchase failed: \(error.localizedDescription)")
        }
        return false
    }

    /// 구매 복원(App Store 와 거래 맞추기 — 로그인 창이 뜰 수 있다)
    func restore() async {
        guard !restoring else { return }
        restoring = true; defer { restoring = false }
        do { try await AppStore.sync() } catch {
            notice = KE("복원하지 못했어요: \(error.localizedDescription)", "Restore failed: \(error.localizedDescription)")
        }
        let before = unlocks.owned
        await refreshEntitlements()
        if notice == nil || unlocks.owned != before {
            notice = unlocks.owned.isEmpty ? KE("복원할 스킨이 없어요.", "Nothing to restore.") : KE("구매한 스킨을 되찾았어요.", "Purchases restored.")
        }
    }
}
