//
//  SecureEnclaveManager.swift
//  Just Vault
//
//  Manages master key storage. Uses iCloud Keychain when possible so the key
//  can sync across the user's devices (Apple ID first); phrase is last resort.
//

import Foundation
import Security
import CryptoKit

enum SecureEnclaveError: Error {
    case keyNotFound
    case keyCreationFailed
    case keyRetrievalFailed
    case keyDeletionFailed
}

class SecureEnclaveManager {
    private static let masterKeyTag = "com.juvantagecloud.justvault.masterKey"
    private static let service = Bundle.main.bundleIdentifier ?? "com.juvantagecloud.justvault"
    
    /// Store master key in Keychain. Prefer iCloud Keychain sync so the same Apple ID
    /// can unlock the vault on other devices without the recovery phrase.
    static func storeMasterKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        try? deleteMasterKey()
        try? deleteMasterKey(synchronizable: true)
        
        // Prefer synchronizable (iCloud Keychain) so key follows the user's Apple ID
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: service,
            kSecValueData as String: keyData,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        #if !targetEnvironment(simulator)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            // Fallback: device-only (e.g. if iCloud Keychain is disabled)
            try? deleteMasterKey(synchronizable: true)
            query[kSecAttrSynchronizable as String] = false
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            #if DEBUG
            if let msg = SecCopyErrorMessageString(status, nil) as String? {
                print("SecureEnclaveManager: SecItemAdd failed with status \(status): \(msg)")
            } else {
                print("SecureEnclaveManager: SecItemAdd failed with status \(status)")
            }
            #endif
            throw SecureEnclaveError.keyCreationFailed
        }
    }
    
    /// Retrieve master key. Tries iCloud-synced key first, then device-only.
    static func getMasterKey() throws -> SymmetricKey {
        // Try synchronizable (iCloud) first — key may have synced from another device
        if let keyData = try? loadKeyData(synchronizable: true) {
            return SymmetricKey(data: keyData)
        }
        if let keyData = try? loadKeyData(synchronizable: false) {
            return SymmetricKey(data: keyData)
        }
        throw SecureEnclaveError.keyNotFound
    }
    
    private static func loadKeyData(synchronizable: Bool) throws -> Data {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: synchronizable
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw SecureEnclaveError.keyNotFound
        }
        return keyData
    }
    
    /// Check if master key exists
    static func hasMasterKey() -> Bool {
        return (try? getMasterKey()) != nil
    }
    
    /// Delete master key (for testing/reset). Removes both sync and device-only if present.
    static func deleteMasterKey() throws {
        try? deleteMasterKey(synchronizable: true)
        try? deleteMasterKey(synchronizable: false)
    }
    
    private static func deleteMasterKey(synchronizable: Bool) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: synchronizable
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureEnclaveError.keyDeletionFailed
        }
    }
}

