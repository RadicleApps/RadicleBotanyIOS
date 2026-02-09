import Foundation
import StoreKit
import SwiftData

@MainActor
final class StoreManager: ObservableObject {

    static let lifetimeID = "com.radicle.radiclebotany.lifetime"
    static let proMonthlyID = "com.radicle.radiclebotany.pro.monthly"
    static let proYearlyID = "com.radicle.radiclebotany.pro.yearly"

    static let allProductIDs: Set<String> = [lifetimeID, proMonthlyID, proYearlyID]

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var userTier: UserTier = .free
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task {
            await fetchProducts()
            await checkEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: StoreManager.allProductIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[StoreManager] Failed to fetch products: \(error)")
            errorMessage = "Unable to load products. Please try again."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlements()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased

        // Determine tier
        if purchased.contains(StoreManager.proMonthlyID) ||
            purchased.contains(StoreManager.proYearlyID) {
            userTier = .pro
        } else if purchased.contains(StoreManager.lifetimeID) {
            userTier = .lifetime
        } else {
            userTier = .free
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.checkEntitlements()
                }
            }
        }
    }

    // MARK: - Feature Check

    func isFeatureUnlocked(_ feature: Feature) -> Bool {
        feature.isUnlocked(for: userTier)
    }

    // MARK: - Helpers

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    // MARK: - Convenience Getters

    var lifetimeProduct: Product? {
        products.first { $0.id == StoreManager.lifetimeID }
    }

    var proMonthlyProduct: Product? {
        products.first { $0.id == StoreManager.proMonthlyID }
    }

    var proYearlyProduct: Product? {
        products.first { $0.id == StoreManager.proYearlyID }
    }
}
