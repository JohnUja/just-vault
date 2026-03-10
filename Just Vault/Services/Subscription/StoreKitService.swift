//
//  StoreKitService.swift
//  Just Vault
//
//  StoreKit 2 service for subscription management
//

import Foundation
import StoreKit

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs
    private let productIDs: Set<String> = [
        AppConfig.proMonthlyProductID,
        AppConfig.proYearlyProductID,
        AppConfig.proPlusMonthlyProductID,
        AppConfig.proPlusYearlyProductID
    ]
    
    private init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("StoreKit Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update purchased products
            await updatePurchasedProducts()
            
            // Finish the transaction
            await transaction.finish()
            
            return transaction
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            throw StoreKitError.pending
        @unknown default:
            throw StoreKitError.unknown
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - Check Subscription Status
    
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
    }
    
    func isSubscribed(to productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
        // Check for Pro+ first (highest tier)
        if isSubscribed(to: AppConfig.proPlusMonthlyProductID) ||
           isSubscribed(to: AppConfig.proPlusYearlyProductID) {
            return .proPlus
        }
        
        // Then check for Pro
        if isSubscribed(to: AppConfig.proMonthlyProductID) ||
           isSubscribed(to: AppConfig.proYearlyProductID) {
            return .pro
        }
        
        return .free
    }
    
    // MARK: - Helper Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unverified
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Helpers
    
    func getProduct(for tier: SubscriptionTier, billing: BillingPeriod) -> Product? {
        let productID: String
        switch (tier, billing) {
        case (.pro, .monthly):
            productID = AppConfig.proMonthlyProductID
        case (.pro, .yearly):
            productID = AppConfig.proYearlyProductID
        case (.proPlus, .monthly):
            productID = AppConfig.proPlusMonthlyProductID
        case (.proPlus, .yearly):
            productID = AppConfig.proPlusYearlyProductID
        default:
            return nil
        }
        
        return products.first { $0.id == productID }
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case userCancelled
    case pending
    case unverified
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .unverified:
            return "Transaction could not be verified"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// Note: BillingPeriod is defined in OnboardingFlowView.swift

