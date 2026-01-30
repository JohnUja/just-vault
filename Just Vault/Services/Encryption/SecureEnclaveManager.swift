//
//  SecureEnclaveManager.swift
//  Just Vault
//
//  Manages master key storage in Secure Enclave
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
    
    /// Store master key in Secure Enclave
    static func storeMasterKey(_ key: SymmetricKey) throws {
        // Convert SymmetricKey to Data
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Delete existing key if present
        try? deleteMasterKey()
        
        // Create access control (requires device unlock, this device only)
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) else {
            throw SecureEnclaveError.keyCreationFailed
        }
        
        // Keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.juvantagecloud.justvault",
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: accessControl,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecureEnclaveError.keyCreationFailed
        }
    }
    
    /// Retrieve master key from Secure Enclave
    static func getMasterKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.juvantagecloud.justvault",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw SecureEnclaveError.keyNotFound
        }
        
        // Convert Data back to SymmetricKey
        return SymmetricKey(data: keyData)
    }
    
    /// Check if master key exists
    static func hasMasterKey() -> Bool {
        return (try? getMasterKey()) != nil
    }
    
    /// Delete master key (for testing/reset)
    static func deleteMasterKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: masterKeyTag,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.juvantagecloud.justvault"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureEnclaveError.keyDeletionFailed
        }
    }
}

