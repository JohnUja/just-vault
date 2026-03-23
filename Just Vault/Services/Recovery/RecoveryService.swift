//
//  RecoveryService.swift
//  Just Vault
//
//  Wraps vault master key with recovery-phrase-derived key for cloud backup.
//  See RECOVERY_IMPLEMENTATION_PLAN.md and RECOVERY_ARCHITECTURE_OPTIONS.md.
//

import Foundation
import CryptoKit

enum RecoveryError: Error, LocalizedError {
    case noMasterKey
    case wrapFailed
    case unwrapFailed
    case invalidPhrase
    case cloudSaveFailed
    case cloudLoadFailed

    var errorDescription: String? {
        switch self {
        case .noMasterKey:
            return "No encryption key found. Unlock the vault first, then try again."
        case .wrapFailed:
            return "Could not prepare the recovery key. Please try again."
        case .unwrapFailed:
            return "Recovery data is invalid or corrupted. Check your phrase and try again."
        case .invalidPhrase:
            return "Recovery phrase is invalid. Check the words and try again."
        case .cloudSaveFailed:
            return "Could not save to cloud. Check your connection and try again. If it keeps failing, sign out and sign in."
        case .cloudLoadFailed:
            return "Could not load from cloud. Check your connection and try again."
        }
    }
}

class RecoveryService {
    static let shared = RecoveryService()
    private let bip39 = BIP39Service()
    private let wrapSalt = Data("justvault-recovery-wrap-v1".utf8)
    private let recoveryQuestionSaltPrefix = Data("justvault-recovery-q-".utf8)

    private init() {}

    /// Normalize answer for consistent wrap/unwrap: trim, lowercase (case-insensitive).
    static func normalizeAnswer(_ answer: String) -> String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Derive key from a single recovery answer (for question index 0, 1, or 2).
    private func deriveRecoveryQuestionKey(userId: String, questionIndex: Int, normalizedAnswer: String) -> SymmetricKey {
        let answerData = Data(normalizedAnswer.utf8)
        let inputKeyMaterial = SymmetricKey(data: SHA256.hash(data: answerData))
        var salt = recoveryQuestionSaltPrefix
        salt.append(Data(userId.utf8))
        salt.append(Data("\(questionIndex)".utf8))
        let info = Data("recovery-q".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    /// Wrap master key with each of 3 answers; returns 3 blobs (same order as answers).
    func wrapMasterKeyWithRecoveryAnswers(userId: String, answers: [String]) throws -> [Data] {
        guard answers.count == 3 else { throw RecoveryError.wrapFailed }
        let masterKey: SymmetricKey
        do {
            masterKey = try SecureEnclaveManager.getMasterKey()
        } catch {
            throw RecoveryError.noMasterKey
        }
        let plaintext = masterKey.withUnsafeBytes { Data($0) }
        var blobs: [Data] = []
        for (index, answer) in answers.enumerated() {
            let normalized = Self.normalizeAnswer(answer)
            guard normalized.count >= 2 else { throw RecoveryError.wrapFailed }
            let key = deriveRecoveryQuestionKey(userId: userId, questionIndex: index, normalizedAnswer: normalized)
            let nonce = AES.GCM.Nonce()
            guard let sealed = try? AES.GCM.seal(plaintext, using: key, nonce: nonce) else {
                throw RecoveryError.wrapFailed
            }
            var out = Data()
            out.append(Data(nonce))
            out.append(sealed.ciphertext)
            out.append(sealed.tag)
            blobs.append(out)
        }
        return blobs
    }

    /// Unwrap one blob with the given answer (questionIndex 0, 1, or 2). Returns master key on success.
    func unwrapMasterKeyWithRecoveryAnswer(wrappedBlob: Data, userId: String, questionIndex: Int, answer: String) throws -> SymmetricKey {
        guard wrappedBlob.count >= 12 + 16 else { throw RecoveryError.unwrapFailed }
        let normalized = Self.normalizeAnswer(answer)
        let key = deriveRecoveryQuestionKey(userId: userId, questionIndex: questionIndex, normalizedAnswer: normalized)
        let nonceBytes = wrappedBlob.prefix(12)
        guard let nonce = try? AES.GCM.Nonce(data: nonceBytes) else { throw RecoveryError.unwrapFailed }
        let ciphertext = wrappedBlob.dropFirst(12).dropLast(16)
        let tag = wrappedBlob.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return SymmetricKey(data: plaintext)
    }
    
    /// Derive a symmetric key from the recovery phrase for wrap/unwrap only.
    private func deriveRecoveryKey(from phraseWords: [String]) throws -> SymmetricKey {
        guard bip39.validatePhrase(phraseWords) else {
            throw RecoveryError.invalidPhrase
        }
        return try bip39.deriveMasterKey(from: phraseWords, salt: wrapSalt)
    }
    
    /// Wrap the current vault master key with the phrase-derived key. Returns ciphertext (nonce + ciphertext + tag) for storage.
    func wrapMasterKey(phraseWords: [String]) throws -> Data {
        let masterKey: SymmetricKey
        do {
            masterKey = try SecureEnclaveManager.getMasterKey()
        } catch {
            throw RecoveryError.noMasterKey
        }
        let recoveryKey = try deriveRecoveryKey(from: phraseWords)
        let plaintext = masterKey.withUnsafeBytes { Data($0) }
        let nonce = AES.GCM.Nonce()
        guard let sealed = try? AES.GCM.seal(plaintext, using: recoveryKey, nonce: nonce) else {
            throw RecoveryError.wrapFailed
        }
        var out = Data()
        out.append(Data(nonce))
        out.append(sealed.ciphertext)
        out.append(sealed.tag)
        return out
    }
    
    /// Unwrap cloud blob with the given phrase; returns the vault master key (caller should store in Keychain).
    func unwrapMasterKey(wrappedData: Data, phraseWords: [String]) throws -> SymmetricKey {
        guard wrappedData.count >= 12 + 16 else { throw RecoveryError.unwrapFailed }
        let recoveryKey = try deriveRecoveryKey(from: phraseWords)
        let nonceBytes = wrappedData.prefix(12)
        guard let nonce = try? AES.GCM.Nonce(data: nonceBytes) else { throw RecoveryError.unwrapFailed }
        let ciphertext = wrappedData.dropFirst(12).dropLast(16)
        let tag = wrappedData.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(sealedBox, using: recoveryKey)
        return SymmetricKey(data: plaintext)
    }
    
    /// Upload wrapped master key to user's cloud profile.
    func uploadWrappedKey(_ wrappedData: Data, userId: String) async throws {
        guard var user = try? await DynamoDBService.shared.loadUserProfile(userId: userId) else {
            throw RecoveryError.cloudSaveFailed
        }
        try await DynamoDBService.shared.saveUserProfile(user, wrappedMasterKey: wrappedData)
    }
    
    /// Download wrapped master key from user's cloud profile (for recovery on new device).
    func downloadWrappedKey(userId: String) async throws -> Data? {
        return try await DynamoDBService.shared.loadWrappedMasterKey(userId: userId)
    }
    
    /// After unwrapping on new device, store the master key in Keychain so the vault can decrypt.
    func storeRecoveredMasterKey(_ key: SymmetricKey) throws {
        try SecureEnclaveManager.storeMasterKey(key)
    }
}
