//
//  AppPreferences.swift
//  Just Vault
//

import Foundation

enum AppPreferences {
    private static let faceIDEnabledKey = "faceIDEnabled"
    private static let faceIDPreferenceSetKey = "faceIDPreferenceSet"
    private static let cloudBackupEnabledKey = "cloudBackupEnabled"

    static var faceIDEnabled: Bool {
        get {
            if !UserDefaults.standard.bool(forKey: faceIDPreferenceSetKey) {
                UserDefaults.standard.set(true, forKey: faceIDEnabledKey)
                UserDefaults.standard.set(true, forKey: faceIDPreferenceSetKey)
                return true
            }
            return UserDefaults.standard.bool(forKey: faceIDEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: faceIDEnabledKey)
            UserDefaults.standard.set(true, forKey: faceIDPreferenceSetKey)
        }
    }

    static var cloudBackupEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: cloudBackupEnabledKey) == nil {
                UserDefaults.standard.set(false, forKey: cloudBackupEnabledKey)
                return false
            }
            return UserDefaults.standard.bool(forKey: cloudBackupEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cloudBackupEnabledKey)
        }
    }
}

extension Notification.Name {
    static let userProfileDidChange = Notification.Name("UserProfileDidChange")
    static let vaultFilesDidChange = Notification.Name("VaultFilesDidChange")
    /// Posted when AWS credentials are expired; UI should offer one-tap re-sign-in.
    static let credentialsExpiredNeedsReSignIn = Notification.Name("CredentialsExpiredNeedsReSignIn")
    /// DEBUG: Reset and show “add important documents” onboarding again (Developer tools).
    static let showAddDocumentsOnboardingAgain = Notification.Name("ShowAddDocumentsOnboardingAgain")
}
