//
//  User.swift
//  Just Vault
//
//  User model and subscription status
//

import Foundation
import UniformTypeIdentifiers

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
    var lastSyncAt: Date? = nil
    
    var cloudStorageUsedMB: Double {
        Double(cloudStorageUsedBytes) / 1_000_000.0
    }
    
    var cloudStorageQuotaMB: Double {
        Double(cloudStorageQuotaBytes) / 1_000_000.0
    }

    var effectiveCloudStorageQuotaBytes: Int64 {
        max(cloudStorageQuotaBytes, effectiveTier.cloudStorageMB * 1_000_000)
    }

    var effectiveCloudStorageQuotaMB: Double {
        Double(effectiveCloudStorageQuotaBytes) / 1_000_000.0
    }
    
    var cloudStorageUsagePercent: Double {
        guard cloudStorageQuotaBytes > 0 else { return 0 }
        return Double(cloudStorageUsedBytes) / Double(cloudStorageQuotaBytes)
    }

    var effectiveCloudStorageUsagePercent: Double {
        guard effectiveCloudStorageQuotaBytes > 0 else { return 0 }
        return Double(cloudStorageUsedBytes) / Double(effectiveCloudStorageQuotaBytes)
    }
    
    var isPro: Bool {
        if DeveloperMode.isEnabled, let override = DeveloperMode.overrideTier {
            return override == .pro || override == .proPlus
        }
        if DeveloperMode.isEnabled { return true }
        return subscriptionTier == .pro || subscriptionTier == .proPlus
    }
    
    var hasCloudBackup: Bool {
        if DeveloperMode.isEnabled, let override = DeveloperMode.overrideTier {
            return override != .free
        }
        if DeveloperMode.isEnabled { return true }
        return subscriptionTier != .free
    }
    
    var effectiveTier: SubscriptionTier {
        if DeveloperMode.isEnabled, let override = DeveloperMode.overrideTier {
            return override
        }
        if DeveloperMode.isEnabled { return .proPlus }
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
        case .free: return 6
        case .pro: return 6
        case .proPlus: return Int.max
        }
    }

    /// Allowed document-picker content types (no video in v1).
    var allowedContentTypes: [UTType] {
        let optionals: [UTType?] = [
            // Images
            .pdf, .jpeg, .png, .heic, .tiff, .gif, .bmp,
            UTType(tag: "webp", tagClass: .filenameExtension, conformingTo: .image), // WebP
            // Documents & text
            .plainText, .rtf, .commaSeparatedText, // CSV
            .spreadsheet, // Excel, Numbers, etc.
            .presentation, // PowerPoint, Keynote
            UTType(tag: "docx", tagClass: .filenameExtension, conformingTo: .data), // Word
            UTType(tag: "doc", tagClass: .filenameExtension, conformingTo: .data),  // Word (legacy)
            UTType(tag: "pages", tagClass: .filenameExtension, conformingTo: .data), // Apple Pages
            UTType(tag: "numbers", tagClass: .filenameExtension, conformingTo: .data), // Apple Numbers
            UTType(tag: "key", tagClass: .filenameExtension, conformingTo: .data),   // Apple Keynote
            // Archives
            .zip, .gzip,
            // Intentionally not including `.data` to keep document picker fast and focused.
        ]
        return optionals.compactMap { $0 }
    }

    var maxFileSizeBytes: Int64 {
        AppConfig.maxFileSizeBytes(for: self)
    }

    var maxFileSizeMB: Int {
        AppConfig.maxFileSizeMB(for: self)
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case expired
    case canceled
    case none
}

// MARK: - Subscription billing period (StoreKit)

enum BillingPeriod {
    case monthly
    case yearly
}

