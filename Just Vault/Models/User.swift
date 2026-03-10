//
//  User.swift
//  Just Vault
//
//  User model and subscription status
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String // Cognito Identity ID
    let appleUserId: String // Apple Sign In user ID
    let email: String?
    let name: String?
    let createdAt: Date
    let lastActiveAt: Date
    
    // Subscription
    var subscriptionTier: SubscriptionTier
    var subscriptionStatus: SubscriptionStatus
    
    // Storage
    var cloudStorageUsedBytes: Int64
    var cloudStorageQuotaBytes: Int64
    
    var cloudStorageUsedMB: Double {
        Double(cloudStorageUsedBytes) / 1_000_000.0
    }
    
    var cloudStorageQuotaMB: Double {
        Double(cloudStorageQuotaBytes) / 1_000_000.0
    }
    
    var cloudStorageUsagePercent: Double {
        guard cloudStorageQuotaBytes > 0 else { return 0 }
        return Double(cloudStorageUsedBytes) / Double(cloudStorageQuotaBytes)
    }
    
    var isPro: Bool {
        if DeveloperMode.isEnabled {
            return true // Developer mode unlocks all features
        }
        return subscriptionTier == .pro || subscriptionTier == .proPlus
    }
    
    var hasCloudBackup: Bool {
        if DeveloperMode.isEnabled {
            return true // Developer mode unlocks cloud backup
        }
        return subscriptionTier != .free
    }
    
    var effectiveTier: SubscriptionTier {
        if DeveloperMode.isEnabled {
            return .proPlus // Developer mode = Pro+
        }
        return subscriptionTier
    }
    
    var canCreateMoreSpaces: Bool {
        if isPro {
            return true // Unlimited
        }
        // Free tier: Check space count (will be implemented with Space model)
        return true // Placeholder
    }
}

enum SubscriptionTier: String, Codable {
    case free
    case pro      // 10GB storage
    case proPlus  // 50GB storage
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .proPlus: return "Pro+"
        }
    }
    
    var cloudStorageMB: Int64 {
        switch self {
        case .free: return 0  // No cloud storage
        case .pro: return 10_000  // 10GB
        case .proPlus: return 50_000  // 50GB
        }
    }
    
    var maxSpaces: Int {
        switch self {
        case .free: return 3
        case .pro: return 20
        case .proPlus: return 20
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case expired
    case canceled
    case none
}

