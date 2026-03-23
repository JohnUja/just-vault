//
//  DeveloperMode.swift
//  Just Vault
//
//  Developer-only configuration (tier override, etc.). In production (Release):
//  - isEnabled is always false (no way to enable; Developer UI is compiled out with #if DEBUG).
//  - Settings "Developer" section and DeveloperToolsView do not exist in the app binary.
//

import Foundation

struct DeveloperMode {
    private static let isEnabledKey = "developerModeEnabled"
    private static let overrideTierKey = "developerModeOverrideTier"
    
    static var isEnabled: Bool {
        get {
            #if DEBUG
            return UserDefaults.standard.object(forKey: isEnabledKey) as? Bool ?? true
            #else
            return UserDefaults.standard.bool(forKey: isEnabledKey)
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isEnabledKey)
        }
    }
    
    /// When developer mode is on, use this tier for limits (spaces, file size, cloud). Nil = default .proPlus for backward compatibility.
    static var overrideTier: SubscriptionTier? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: overrideTierKey),
                  let tier = SubscriptionTier(rawValue: raw) else { return nil }
            return tier
        }
        set {
            if let t = newValue {
                UserDefaults.standard.set(t.rawValue, forKey: overrideTierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: overrideTierKey)
            }
        }
    }
    
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

