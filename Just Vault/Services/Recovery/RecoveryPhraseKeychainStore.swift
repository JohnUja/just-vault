//
//  RecoveryPhraseKeychainStore.swift
//  Just Vault
//
//  Secure on-device storage for the recovery phrase (Keychain / Passwords).
//  Note: we can't directly drive the iOS Passwords UI, but storing in Keychain
//  allows the system to surface it where the user manages passwords (if enabled).
//

import Foundation
import Security

enum RecoveryPhraseKeychainStore {
    private static let account = "com.juvantagecloud.justvault.recoveryPhrase"
    private static let service = Bundle.main.bundleIdentifier ?? "com.juvantagecloud.justvault.recovery"
    
    static func hasSavedPhrase() -> Bool {
        return (try? loadPhraseString()) != nil
    }
    
    static func savePhrase(words: [String]) throws {
        let phrase = words.joined(separator: " ")
        let phraseData = phrase.data(using: .utf8) ?? Data()
        try save(data: phraseData)
    }
    
    static func loadWords() throws -> [String] {
        let phrase = try loadPhraseString()
        return phrase.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
    }
    
    static func deletePhrase() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "RecoveryPhraseKeychainStore", code: Int(status), userInfo: nil)
        }
    }
    
    private static func loadPhraseString() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "RecoveryPhraseKeychainStore", code: Int(status), userInfo: nil)
        }
        return str
    }
    
    private static func save(data: Data) throws {
        // Prefer synchronizable (iCloud Keychain). If it fails, fall back to device-only.
        try? deletePhrase()
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true
        ]
        
        var status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            query[kSecAttrSynchronizable as String] = false
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: "RecoveryPhraseKeychainStore", code: Int(status), userInfo: nil)
        }
    }
}

