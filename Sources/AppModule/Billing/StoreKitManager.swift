import StoreKit

/// Thin wrapper around StoreKit 2 for the one subscription product this app
/// sells. Mirrors SupabaseRepository's pattern of a static-function enum —
/// AppStore owns the resulting state, this just talks to the framework.
enum StoreKitManager {
    static func fetchSubscriptionProduct() async throws -> Product? {
        let products = try await Product.products(for: [subscriptionProductID])
        return products.first
    }

    enum PurchaseOutcome {
        case verified(transaction: Transaction, jws: String)
        case pending
        case userCancelled
    }

    /// `appAccountToken` is the signed-in user's id — Apple carries it
    /// through on this and every future notification for the resulting
    /// subscription, which is how drinkmatch-backend's app-store-notifications
    /// webhook knows which account a renewal/cancellation belongs to.
    static func purchase(_ product: Product, appAccountToken: UUID) async throws -> PurchaseOutcome {
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                return .verified(transaction: transaction, jws: verification.jwsRepresentation)
            case .unverified(_, let error):
                throw error
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .userCancelled
        }
    }

    /// StoreKit's own `AppStore` type, fully qualified because `import
    /// StoreKit` brings it into scope alongside this project's own AppStore
    /// (Store/AppStore.swift) — same name, unrelated types.
    static func restorePurchases() async throws {
        try await StoreKit.AppStore.sync()
    }
}
