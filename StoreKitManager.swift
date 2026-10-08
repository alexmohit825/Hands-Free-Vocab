import SwiftUI
import StoreKit

/// Native StoreKit 2 manager for Orator: Executive Lexicon.
/// Handles the one-time Lifetime Unlock in-app purchase ($4.99), transaction updates,
/// and local entitlement caching.
@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()

    /// Product ID registered in App Store Connect
    public static let lifetimeProductID = "com.Alex.HandsFreeVocab.lifetime_unlock"

    @Published public private(set) var isUnlocked: Bool = false
    @Published public private(set) var lifetimeProduct: Product? = nil
    @Published public private(set) var isPurchasing: Bool = false
    @Published public private(set) var errorMessage: String? = nil

    private var updateListenerTask: Task<Void, Never>? = nil

    private init() {
        // Check cached local unlock status immediately to prevent UI flash
        self.isUnlocked = UserDefaults.standard.bool(forKey: "orator_is_unlocked")

        // Start listening for transaction updates (purchases outside app, restores, ask-to-buy)
        updateListenerTask = listenForTransactions()

        // Fetch products and verify actual App Store entitlements asynchronously
        Task {
            await loadProducts()
            await updatePurchasedStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await self.handle(transaction: transaction)
                    await transaction.finish()
                } catch {
                    print("[StoreKit] Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Load Products

    public func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeProductID])
            self.lifetimeProduct = products.first { $0.id == Self.lifetimeProductID }
            print("[StoreKit] Loaded product: \(String(describing: self.lifetimeProduct?.displayName)) - \(self.lifetimeProduct?.displayPrice ?? "N/A")")
        } catch {
            print("[StoreKit] Failed to fetch products: \(error)")
            self.errorMessage = "Unable to load App Store products."
        }
    }

    // MARK: - Entitlement Verification

    public func updatePurchasedStatus() async {
        var hasActiveEntitlement = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.lifetimeProductID && transaction.revocationDate == nil {
                    hasActiveEntitlement = true
                    break
                }
            }
        }

        self.isUnlocked = hasActiveEntitlement
        UserDefaults.standard.set(hasActiveEntitlement, forKey: "orator_is_unlocked")
        print("[StoreKit] Verified active unlock status: \(hasActiveEntitlement)")
    }

    // MARK: - Purchase Flow

    public func purchaseLifetime() async -> Bool {
        guard let product = lifetimeProduct else {
            await loadProducts()
            guard let product = lifetimeProduct else {
                self.errorMessage = "Store connection unavailable. Please check your internet connection."
                return false
            }
            return await executePurchase(product)
        }
        return await executePurchase(product)
    }

    private func executePurchase(_ product: Product) async -> Bool {
        self.isPurchasing = true
        self.errorMessage = nil

        do {
            let result = try await product.purchase()
            self.isPurchasing = false

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handle(transaction: transaction)
                await transaction.finish()
                return true

            case .userCancelled:
                print("[StoreKit] User cancelled purchase.")
                return false

            case .pending:
                print("[StoreKit] Purchase pending approval (Ask to Buy).")
                return false

            @unknown default:
                return false
            }
        } catch {
            self.isPurchasing = false
            self.errorMessage = error.localizedDescription
            print("[StoreKit] Purchase failed: \(error)")
            return false
        }
    }

    // MARK: - Restore Purchases

    public func restorePurchases() async {
        self.isPurchasing = true
        self.errorMessage = nil
        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
            self.isPurchasing = false
        } catch {
            self.isPurchasing = false
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func handle(transaction: StoreKit.Transaction) async {
        if transaction.productID == Self.lifetimeProductID && transaction.revocationDate == nil {
            self.isUnlocked = true
            UserDefaults.standard.set(true, forKey: "orator_is_unlocked")
            print("[StoreKit] Successfully verified and unlocked Orator Lifetime Full Access!")
        }
    }
}

private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified(_, let error):
        throw error
    case .verified(let safe):
        return safe
    }
}
