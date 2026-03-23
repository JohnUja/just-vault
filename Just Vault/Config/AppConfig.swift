//
//  AppConfig.swift
//  Just Vault
//
//  App-wide configuration constants
//

import Foundation

struct AppConfig {
    // App Information
    /// Product name (home screen, permissions, in-app copy).
    static let appName = "Keep"
    /// Company wordmark next to the logo (shown with ™), not the app display name.
    static let companyWordmark = "JUST"
    static let bundleId = "com.juvantagecloud.justvault"
    
    // Free Tier Limits
    static let freeTierCloudStorageMB = 0
    static let freeTierMaxSpaces = 6
    
    // Pro Tier Limits
    static let proTierCloudStorageMB = 10_000 // 10 GB
    static let proTierMaxSpaces = 6
    
    // Pro+ Tier Limits
    static let proPlusTierCloudStorageMB = 50_000 // 50 GB
    static let proPlusTierMaxSpaces = Int.max
    
    // Performance thresholds
    static let performanceWarningThreshold = 15  // Warn at 15 spaces
    static let gridViewThreshold = 10  // Consider grid view at 10+ spaces
    
    /// Free trial length for **yearly** paid plans only (monthly should have no intro offer in App Store Connect). Keep in sync with ASC.
    static let subscriptionYearlyFreeTrialDays = 14

    // MARK: - Web & App Store links (update for production)

    static let supportEmail = "support@juvantage.com"

    /// Hosted legal pages (Settings → Support opens in Safari).
    static let privacyPolicyWebURLString = "https://juvantagecloud.com/keep/privacy-policy"
    static let termsOfServiceWebURLString = "https://juvantagecloud.com/keep/terms-of-service"

    /// Just Scan on the App Store (Settings → Support cross-promo).
    static let relatedAppJustScanStoreURLString = "https://apps.apple.com/app/id6757631823"

    // Subscription Pricing (Product IDs for StoreKit)
    static let proMonthlyProductID = "com.juvantagecloud.justvault.pro.monthly"
    static let proYearlyProductID = "com.juvantagecloud.justvault.pro.yearly"
    static let proPlusMonthlyProductID = "com.juvantagecloud.justvault.proplus.monthly"
    static let proPlusYearlyProductID = "com.juvantagecloud.justvault.proplus.yearly"
    
    // Legacy pricing (for display only, actual prices come from StoreKit)
    static let proMonthlyPrice = 6.99
    static let proYearlyPrice = 59.99
    static let proPlusMonthlyPrice = 9.99
    static let proPlusYearlyPrice = 79.99
    
    // Per-File Size Limits (tier-based)
    static let freeMaxFileSizeBytes: Int64  = 25  * 1_024 * 1_024  // 25 MB
    static let proMaxFileSizeBytes: Int64   = 100 * 1_024 * 1_024  // 100 MB
    static let proPlusMaxFileSizeBytes: Int64 = 500 * 1_024 * 1_024 // 500 MB

    static func maxFileSizeBytes(for tier: SubscriptionTier) -> Int64 {
        switch tier {
        case .free:    return freeMaxFileSizeBytes
        case .pro:     return proMaxFileSizeBytes
        case .proPlus: return proPlusMaxFileSizeBytes
        }
    }

    static func maxFileSizeMB(for tier: SubscriptionTier) -> Int {
        Int(maxFileSizeBytes(for: tier) / (1_024 * 1_024))
    }

    // Storage Thresholds (for upgrade prompts)
    static let storageWarningThreshold = 0.75 // 75%
    static let storageCriticalThreshold = 0.90 // 90%
}

