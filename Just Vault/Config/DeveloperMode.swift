//
//  DeveloperMode.swift
//  Just Vault
//
//  Developer mode configuration for testing pro features
//

import Foundation

struct DeveloperMode {
    private static let isEnabledKey = "developerModeEnabled"
    
    static var isEnabled: Bool {
        get {
            #if DEBUG
            // In debug builds, default to enabled
            return UserDefaults.standard.object(forKey: isEnabledKey) as? Bool ?? true
            #else
            // In release builds, default to disabled
            return UserDefaults.standard.bool(forKey: isEnabledKey)
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isEnabledKey)
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

