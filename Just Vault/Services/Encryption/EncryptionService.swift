//
//  EncryptionService.swift
//  Just Vault
//
//  Handles file encryption/decryption using CryptoKit
//

import Foundation
import CryptoKit

class EncryptionService {
    private let secureEnclave = SecureEnclaveManager.self
    
    /// Encrypt file data using AES-256-GCM
    /// Format: [IV (12 bytes)][Ciphertext][Tag (16 bytes)]
    func encryptFile(_ data: Data, fileId: String) throws -> Data {
        // 1. Get master key from Secure Enclave
        let masterKey = try secureEnclave.getMasterKey()
        
        // 2. Derive file-specific key using HKDF
        let fileKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: fileId.data(using: .utf8)!,
            info: "file-encryption".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        // 3. Generate random nonce (IV) for GCM
        let nonce = AES.GCM.Nonce()
        
        // 4. Encrypt with AES-256-GCM
        let sealedBox = try AES.GCM.seal(data, using: fileKey, nonce: nonce)
        
        // 5. Combine nonce + ciphertext + tag
        var encryptedData = Data()
        encryptedData.append(Data(nonce))
        encryptedData.append(sealedBox.ciphertext)
        encryptedData.append(sealedBox.tag)
        
        return encryptedData
    }
    
    /// Decrypt file data
    func decryptFile(_ encryptedData: Data, fileId: String) throws -> Data {
        // Validate minimum size (12 bytes IV + 16 bytes tag = 28 bytes minimum)
        guard encryptedData.count >= 28 else {
            throw EncryptionError.invalidData
        }
        
        // 1. Get master key from Secure Enclave
        let masterKey = try secureEnclave.getMasterKey()
        
        // 2. Derive file-specific key
        let fileKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: fileId.data(using: .utf8)!,
            info: "file-encryption".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        // 3. Reconstruct sealed box from combined data
        // CryptoKit's SealedBox(combined:) expects: nonce (12 bytes) + ciphertext + tag (16 bytes)
        // Our format is already: nonce (12) + ciphertext + tag (16), so we can use it directly
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        // 5. Decrypt
        do {
            return try AES.GCM.open(sealedBox, using: fileKey)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    /// Generate a new master key (for first-time setup)
    func generateMasterKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
}

enum EncryptionError: Error {
    case keyNotFound
    case decryptionFailed
    case invalidData
    case encryptionFailed
}

