import StoreKit
import SwiftUI

/// Pawlight Pro: one non-consumable unlock (all lures, all sounds, multi-shot catches).
/// StoreKit 2 only, no server, no receipt parsing. Entitlements are re-checked at launch and
/// whenever a transaction update arrives (Ask to Buy, refunds, other devices).
@MainActor @Observable
final class ProStore {
    static let productID = "app.halflight.pawlight.pro"

    private(set) var product: Product?
    private(set) var owned = false
    private(set) var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let settings: PawSettings

    init(settings: PawSettings) {
        self.settings = settings
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }

    /// What the rest of the app checks.
    var isPro: Bool {
        #if DEBUG
        if settings.values.pretendPro { return true }
        #endif
        return owned
    }

    func isUnlocked(_ lure: Lure) -> Bool { lure.isFree || isPro }
    func isUnlocked(_ sound: LureSound) -> Bool { sound.isFree || isPro }

    func load() async {
        await refreshEntitlements()
        guard product == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var found = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                found = true
            }
        }
        owned = found
    }

    /// Feed the result of SwiftUI's `purchase` action here.
    func handle(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refreshEntitlements()
        case .success(.unverified(_, let error)):
            errorMessage = error.localizedDescription
        case .pending, .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }
}
