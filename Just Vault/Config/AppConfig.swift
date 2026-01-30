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
    static let freeTierCloudStorageMB = 250
    static let freeTierMaxSpaces = 2
    
    // Pro Tier Limits
    static let proTierCloudStorageMB = 10_000 // 10 GB
    static let proTierMaxSpaces = Int.max // Unlimited
    
    // Subscription Pricing
    static let proMonthlyPrice = 6.99
    static let proYearlyPrice = 59.99
    
    // Storage Thresholds (for upgrade prompts)
    static let storageWarningThreshold = 0.75 // 75%
    static let storageCriticalThreshold = 0.90 // 90%
}

