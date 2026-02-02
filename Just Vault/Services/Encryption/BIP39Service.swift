//
//  BIP39Service.swift
//  Just Vault
//
//  Handles BIP39 recovery phrase generation and validation
//

import Foundation
import Bip39
import CryptoKit

class BIP39Service {
    /// Generate a BIP39 recovery phrase (12 or 24 words)
    func generateRecoveryPhrase(wordCount: Int = 12) throws -> [String] {
        guard wordCount == 12 || wordCount == 24 else {
            throw BIP39Error.invalidWordCount
        }
        
        // Generate mnemonic with specified entropy bits
        // 12 words = 128 bits, 24 words = 256 bits
        let entropyBits = wordCount == 12 ? 128 : 256
        let mnemonic = try Mnemonic(strength: entropyBits)
        
        // Return phrase as array of strings
        return mnemonic.mnemonic()
    }
    
    /// Validate a recovery phrase
    func validatePhrase(_ phrase: [String]) -> Bool {
        // Use BIP39 library validation
        return Mnemonic.isValid(phrase: phrase)
    }
    
    /// Convert recovery phrase to entropy (for key derivation)
    func phraseToEntropy(_ phrase: [String]) throws -> Data {
        // Create mnemonic from phrase and extract entropy
        let mnemonic = try Mnemonic(mnemonic: phrase)
        // Convert [UInt8] to Data
        return Data(mnemonic.entropy)
    }
    
    /// Derive master key from recovery phrase using BIP39 seed derivation
    /// Uses PBKDF2-SHA512 with 2048 iterations (BIP39 standard)
    func deriveMasterKey(from phrase: [String], salt: Data) throws -> SymmetricKey {
        // Create mnemonic from phrase
        let mnemonic = try Mnemonic(mnemonic: phrase)
        
        // Get BIP39 seed (uses PBKDF2-SHA512 with 2048 iterations)
        // Note: BIP39 seed uses empty passphrase by default
        // If you need a custom passphrase, use: mnemonic.seed(passphrase: "your-passphrase")
        let seed = mnemonic.seed()
        
        // Convert seed to Data (seed is [UInt8])
        let seedData = Data(seed)
        
        // Convert seed (64 bytes) to SymmetricKey (32 bytes for AES-256)
        // Use first 32 bytes of seed as master key
        let masterKeyData = seedData.prefix(32)
        return SymmetricKey(data: masterKeyData)
    }
}

enum BIP39Error: Error {
    case invalidWordCount
    case invalidWord
    case checksumMismatch
    case generationFailed
    case invalidPhrase
}

