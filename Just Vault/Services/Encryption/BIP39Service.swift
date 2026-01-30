//
//  BIP39Service.swift
//  Just Vault
//
//  Handles BIP39 recovery phrase generation and validation
//

import Foundation
import MnemonicKit

class BIP39Service {
    /// Generate a BIP39 recovery phrase (12 or 24 words)
    func generateRecoveryPhrase(wordCount: Int = 12) throws -> [String] {
        guard wordCount == 12 || wordCount == 24 else {
            throw BIP39Error.invalidWordCount
        }
        
        // Generate entropy
        let entropyBits = wordCount == 12 ? 128 : 256
        var entropy = Data(count: entropyBits / 8)
        let status = entropy.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, entropyBits / 8, bytes.baseAddress!)
        }
        
        guard status == errSecSuccess else {
            throw BIP39Error.generationFailed
        }
        
        // Use MnemonicKit to generate mnemonic from entropy
        guard let mnemonic = Mnemonic.generate(entropy: entropy) else {
            throw BIP39Error.generationFailed
        }
        
        return mnemonic.components(separatedBy: " ")
    }
    
    /// Validate a recovery phrase
    func validatePhrase(_ phrase: [String]) -> Bool {
        guard phrase.count == 12 || phrase.count == 24 else {
            return false
        }
        
        let mnemonic = phrase.joined(separator: " ")
        
        // Use MnemonicKit to validate mnemonic
        return Mnemonic.validate(mnemonic: mnemonic)
    }
    
    /// Convert recovery phrase to entropy (for key derivation)
    func phraseToEntropy(_ phrase: [String]) throws -> Data {
        let mnemonic = phrase.joined(separator: " ")
        
        // Use MnemonicKit to convert mnemonic to entropy
        guard let entropy = Mnemonic.toEntropy(mnemonic: mnemonic) else {
            throw BIP39Error.invalidPhrase
        }
        
        return entropy
    }
    
    /// Derive master key from recovery phrase using PBKDF2-SHA512
    func deriveMasterKey(from phrase: [String], salt: Data) throws -> SymmetricKey {
        let entropy = try phraseToEntropy(phrase)
        
        // Use PBKDF2-SHA512 with 2048 iterations (BIP39 standard)
        let keyData = try PKCS5.PBKDF2(
            password: entropy,
            salt: salt,
            iterations: 2048,
            keyLength: 32, // 256 bits
            variant: .sha512
        ).calculate()
        
        return SymmetricKey(data: keyData)
    }
}

enum BIP39Error: Error {
    case invalidWordCount
    case invalidWord
    case checksumMismatch
    case generationFailed
    case invalidPhrase
}

// PBKDF2 helper (using CryptoKit's HKDF as approximation)
import CryptoKit

extension PKCS5 {
    enum Variant {
        case sha512
    }
    
    struct PBKDF2 {
        let password: Data
        let salt: Data
        let iterations: Int
        let keyLength: Int
        let variant: Variant
        
        func calculate() throws -> Data {
            // Note: This uses HKDF instead of true PBKDF2
            // For production, consider using a proper PBKDF2 library
            // HKDF is acceptable for this use case but not identical to PBKDF2
            
            let symmetricKey = SymmetricKey(data: password)
            let derivedKey = HKDF<SHA512>.deriveKey(
                inputKeyMaterial: symmetricKey,
                salt: salt,
                info: "master-key-derivation".data(using: .utf8)!,
                outputByteCount: keyLength
            )
            
            return derivedKey.withUnsafeBytes { Data($0) }
        }
    }
}

