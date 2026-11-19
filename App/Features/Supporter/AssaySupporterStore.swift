import Combine
import Foundation
import StoreKit

@MainActor final class AssaySupporterStore: ObservableObject {
    static let shared = AssaySupporterStore()
    private init() {}

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadingProducts = false
    @Published private(set) var catalogueNotice: String?
    @Published private(set) var checkedEntitlements = false
    @Published private(set) var verificationIssue = false
    @Published private(set) var hasLifetime = false
    @Published private(set) var annualUntil: Date?
    @Published private(set) var busy = false
    @Published private(set) var notice: String?
    var hasAnnual: Bool { annualUntil.map { $0 > Date() } ?? false }
    var isSupporter: Bool { hasLifetime || hasAnnual }

    private var listener: Task<Void, Never>?
    private var expiry: Task<Void, Never>?
    private var scan: Task<Void, Never>?
    private var rescan = false

    // Safe to call from the app root at launch and again on foreground entry.
    // Does not present StoreKit UI or ask the App Store to sync.
    func start() async {
        if listener == nil {
            listener = Task {
                for await result in Transaction.updates {
                    if let message = await consume(result) { notice = message }
                }
            }
        }
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let found = try await Product.products(for: SupporterSKU.allCases.map(\.rawValue))
            products = SupporterSKU.allCases.compactMap { sku in
                found.first { p in
                    guard Self.contract(p.id, p.type) == sku else { return false }
                    if sku == .lifetime { return true }
                    let period = p.subscription?.subscriptionPeriod
                    return period?.unit == .year && period?.value == 1
                }
            }
            catalogueNotice = products.count == SupporterSKU.allCases.count ? nil :
                "The App Store hasn’t returned all supporter options for this storefront."
        } catch {
            products = []
            catalogueNotice = "Couldn’t load supporter options from the App Store."
        }
    }

    private static func contract(_ id: String, _ type: Product.ProductType) -> SupporterSKU? {
        switch (SupporterSKU(rawValue: id), type) {
        case (.yearly?, .autoRenewable): return .yearly
        case (.lifetime?, .nonConsumable): return .lifetime
        default: return nil
        }
    }

    private func rule(_ tx: Transaction, _ sku: SupporterSKU) -> SupporterEntitlement {
        .evaluate(sku, revoked: tx.revocationDate != nil, upgraded: tx.isUpgraded,
                  expiration: tx.expirationDate?.timeIntervalSince1970, now: Date().timeIntervalSince1970)
    }

    // Replace, never union, the last snapshot. Coalesce overlapping scans so an
    // older scan can't republish an entitlement after a refund/account change.
    private func refreshEntitlements() async {
        if let scan { rescan = true; await scan.value; return }
        let task = Task {
            repeat {
                rescan = false
                var lifetime = false, unverified = false
                var until: Date?
                for await result in Transaction.currentEntitlements {
                    switch result {
                    case .verified(let tx):
                        guard let sku = Self.contract(tx.productID, tx.productType), rule(tx, sku) == .current else { continue }
                        if sku == .lifetime { lifetime = true }
                        else if let end = tx.expirationDate { until = max(until ?? end, end) }
                    case .unverified(let unsafe, _):
                        // Untrusted identifier is used only for a warning, never for access.
                        if SupporterSKU(rawValue: unsafe.productID) != nil { unverified = true }
                    }
                }
                if !rescan {
                    hasLifetime = lifetime
                    annualUntil = until
                    verificationIssue = unverified
                    checkedEntitlements = true
                    scheduleExpiry()
                }
            } while rescan
            scan = nil
        }
        scan = task
        await task.value
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        guard let end = annualUntil else { return }
        expiry = Task {
            do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) }
            catch { return }
            guard !Task.isCancelled else { return }
            annualUntil = nil
            await refreshEntitlements()
        }
    }

    private func consume(_ result: VerificationResult<Transaction>) async -> String? {
        switch result {
        case .unverified: verificationIssue = true; return "Purchase not verified. No supporter status granted."
        case .verified(let tx):
            guard let sku = Self.contract(tx.productID, tx.productType) else { return nil }
            let status = rule(tx, sku)
            await refreshEntitlements()
            await tx.finish()
            return status == .current ? "Supporter entitlement verified." : "Supporter status refreshed."
        }
    }
    func purchase(_ product: Product) async {
        guard !busy, !hasLifetime, !(product.id == SupporterSKU.yearly.rawValue && hasAnnual), products.contains(where: { $0.id == product.id }), Self.contract(product.id,product.type) != nil else { return }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result): notice = await consume(result)
            case .userCancelled: notice = "Purchase cancelled."
            case .pending: notice = "Awaiting App Store approval. No entitlement granted yet."
            @unknown default: notice = "Status not confirmed. Check your App Store purchase history."
            }
        } catch { notice = "Could not complete the purchase. Check the App Store before trying again." }
    }
    func restore() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refreshEntitlements(); notice = isSupporter ? "Supporter status restored." : "No verified current supporter purchase found." }
        catch { notice = "Restore was cancelled or unavailable. No access changed." }
    }
}
