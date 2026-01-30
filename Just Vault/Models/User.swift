//
//  User.swift
//  Just Vault
//
//  User model and subscription status
//

import Foundation

struct User: Codable, Identifiable {
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
        subscriptionTier == .pro
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
    case pro
}

enum SubscriptionStatus: String, Codable {
    case active
    case expired
    case canceled
    case none
}

