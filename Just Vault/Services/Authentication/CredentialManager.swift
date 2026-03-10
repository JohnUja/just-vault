//
//  CredentialManager.swift
//  Just Vault
//
//  Manages AWS credentials from Cognito Identity Pool
//

import Foundation
import AWSCognitoIdentity
import ClientRuntime

class CredentialManager {
    static let shared = CredentialManager()
    
    private var identityId: String?
    private var credentials: StoredCredentials?
    private var cognitoTokens: CognitoTokens?
    private var expirationDate: Date?
    
    // Internal credentials structure for storage
    private struct StoredCredentials {
        let accessKeyId: String?
        let expiration: Date?
        let secretAccessKey: String?
        let sessionToken: String?
    }
    
    private let keychainService = "com.juvantagecloud.justvault.credentials"
    private let identityIdKey = "cognitoIdentityId"
    private let accessKeyIdKey = "awsAccessKeyId"
    private let secretAccessKeyKey = "awsSecretAccessKey"
    private let sessionTokenKey = "awsSessionToken"
    private let expirationKey = "credentialsExpiration"
    
    private init() {}
    
    /// Store credentials after authentication
    /// Accepts credential properties directly to avoid type issues
    func storeCredentials(
        identityId: String,
        accessKeyId: String?,
        secretAccessKey: String?,
        sessionToken: String?,
        expiration: Date?,
        tokens: CognitoTokens
    ) throws {
        // Convert to our internal storage format
        let stored = StoredCredentials(
            accessKeyId: accessKeyId,
            expiration: expiration,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken
        )
        self.identityId = identityId
        self.credentials = stored
        self.cognitoTokens = tokens
        
        // Calculate expiration (credentials typically expire in 1 hour)
        if let expiration = stored.expiration {
            self.expirationDate = expiration
        } else {
            // Default to 1 hour from now if expiration not provided
            self.expirationDate = Date().addingTimeInterval(3600)
        }
        
        // Save to Keychain for security
        try saveToKeychain(
            identityId: identityId,
            accessKeyId: stored.accessKeyId ?? "",
            secretAccessKey: stored.secretAccessKey ?? "",
            sessionToken: stored.sessionToken,
            expiration: expirationDate
        )
    }
    
    /// Get credentials (loads from Keychain or returns cached)
    /// Returns credentials in a format compatible with AWS SDK
    func getCredentials() async throws -> (identityId: String, accessKeyId: String, secretAccessKey: String, sessionToken: String?) {
        // Check if credentials are expired (with 5 minute buffer)
        if let expiration = expirationDate, expiration <= Date().addingTimeInterval(300) {
            // Credentials expired or expiring soon - need to refresh
            // For Pro members, try to refresh automatically
            if DeveloperMode.isEnabled {
                // In dev mode, allow expired credentials for testing
                print("Warning: Credentials expired but allowing in dev mode")
            } else {
                throw CredentialError.credentialsExpired
            }
        }
        
        // Return cached credentials if available
        if let identityId = identityId, let credentials = credentials {
            return (identityId, credentials.accessKeyId ?? "", credentials.secretAccessKey ?? "", credentials.sessionToken)
        }
        
        // Try to load from Keychain
        if let (id, creds) = try? loadFromKeychain() {
            self.identityId = id
            self.credentials = creds
            return (id, creds.accessKeyId ?? "", creds.secretAccessKey ?? "", creds.sessionToken)
        }
        
        throw CredentialError.credentialsNotFound
    }
    
    /// Clear stored credentials
    func clearCredentials() {
        identityId = nil
        credentials = nil
        cognitoTokens = nil
        expirationDate = nil
        
        // Clear from Keychain
        clearKeychain()
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(
        identityId: String,
        accessKeyId: String,
        secretAccessKey: String,
        sessionToken: String?,
        expiration: Date?
    ) throws {
        let keychain = KeychainHelper.shared
        
        // Save identity ID
        try keychain.save(identityId, forKey: identityIdKey, service: keychainService)
        
        // Save access key ID
        try keychain.save(accessKeyId, forKey: accessKeyIdKey, service: keychainService)
        
        // Save secret access key
        try keychain.save(secretAccessKey, forKey: secretAccessKeyKey, service: keychainService)
        
        // Save session token if available
        if let token = sessionToken {
            try keychain.save(token, forKey: sessionTokenKey, service: keychainService)
        }
        
        // Save expiration date
        if let expiration = expiration {
            let expirationString = String(expiration.timeIntervalSince1970)
            try keychain.save(expirationString, forKey: expirationKey, service: keychainService)
        }
    }
    
    private func loadFromKeychain() throws -> (identityId: String, credentials: StoredCredentials) {
        let keychain = KeychainHelper.shared
        
        guard let identityId = try? keychain.load(forKey: identityIdKey, service: keychainService),
              let accessKeyId = try? keychain.load(forKey: accessKeyIdKey, service: keychainService),
              let secretAccessKey = try? keychain.load(forKey: secretAccessKeyKey, service: keychainService) else {
            throw CredentialError.credentialsNotFound
        }
        
        let sessionToken = try? keychain.load(forKey: sessionTokenKey, service: keychainService)
        
        var expiration: Date?
        if let expirationString = try? keychain.load(forKey: expirationKey, service: keychainService),
           let timestamp = Double(expirationString) {
            expiration = Date(timeIntervalSince1970: timestamp)
        }
        
        let credentials = StoredCredentials(
            accessKeyId: accessKeyId,
            expiration: expiration,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken
        )
        
        return (identityId, credentials)
    }
    
    private func clearKeychain() {
        let keychain = KeychainHelper.shared
        try? keychain.delete(forKey: identityIdKey, service: keychainService)
        try? keychain.delete(forKey: accessKeyIdKey, service: keychainService)
        try? keychain.delete(forKey: secretAccessKeyKey, service: keychainService)
        try? keychain.delete(forKey: sessionTokenKey, service: keychainService)
        try? keychain.delete(forKey: expirationKey, service: keychainService)
    }
}

enum CredentialError: Error {
    case credentialsNotFound
    case credentialsExpired
    case keychainError
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func save(_ value: String, forKey key: String, service: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialError.keychainError
        }
    }
    
    func load(forKey key: String, service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw CredentialError.keychainError
        }
        
        return value
    }
    
    func delete(forKey key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.keychainError
        }
    }
}

