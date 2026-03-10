//
//  AppConfig.swift
//  Just Vault
//
//  App-wide configuration constants
//

import Foundation

struct AppConfig {
    // App Information
    static let appName = "Just Vault"
    static let bundleId = "com.juvantagecloud.justvault"
    
    // Free Tier Limits
    static let freeTierCloudStorageMB = 0  // No cloud storage for free users
    static let freeTierMaxSpaces = 3  // Free users can create 3 spaces max
    
    // Pro Tier Limits
    static let proTierCloudStorageMB = 10_000 // 10 GB
    static let proTierMaxSpaces = 20  // Reasonable limit to prevent clutter
    
    // Pro+ Tier Limits
    static let proPlusTierCloudStorageMB = 50_000 // 50 GB
    static let proPlusTierMaxSpaces = 20  // Same as Pro
    
    // Performance thresholds
    static let performanceWarningThreshold = 15  // Warn at 15 spaces
    static let gridViewThreshold = 10  // Consider grid view at 10+ spaces
    
    // Subscription Pricing (Product IDs for StoreKit)
    static let proMonthlyProductID = "com.juvantagecloud.justvault.pro.monthly"
    static let proYearlyProductID = "com.juvantagecloud.justvault.pro.yearly"
    static let proPlusMonthlyProductID = "com.juvantagecloud.justvault.proplus.monthly"
    static let proPlusYearlyProductID = "com.juvantagecloud.justvault.proplus.yearly"
    
    // Legacy pricing (for display only, actual prices come from StoreKit)
    static let proMonthlyPrice = 6.99
    static let proYearlyPrice = 59.99
    static let proPlusMonthlyPrice = 9.99
    static let proPlusYearlyPrice = 99.99
    
    // Storage Thresholds (for upgrade prompts)
    static let storageWarningThreshold = 0.75 // 75%
    static let storageCriticalThreshold = 0.90 // 90%
}

