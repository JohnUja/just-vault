//
//  RecoverySettingsView.swift
//  Just Vault
//
//  Recovery settings for account and encryption key management
//

import SwiftUI
import UIKit
import LocalAuthentication

struct RecoverySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @State private var recoveryPhrase: [String] = []
    @State private var infoMessage: String?
    @State private var isBackingUp = false
    @State private var showSetRecoveryQuestions = false
    /// Pre-loaded question texts for "Change recovery questions" so the sheet shows the user's chosen questions (not defaults).
    @State private var existingRecoveryQuestionTexts: [String]? = nil
    @State private var faceIDError: String?
    @State private var showRegenerateConfirmation = false
    @State private var showReplaceStoredPhraseAlert = false
    @State private var pendingBackupAfterStoredPhraseReplace = false
    /// True only after a successful "Back up key to cloud" this session; cleared when phrase is regenerated.
    @State private var isCurrentPhraseBackedUp = false
    /// 24h rate limit: max 2 recovery-phrase actions (regenerate + backup) per 24h to cap DynamoDB writes.
    @AppStorage("recoveryPhraseActionCount") private var storedRecoveryPhraseActionCount = 0
    @AppStorage("recoveryPhraseActionResetTimestamp") private var storedRecoveryPhraseActionResetTimestamp: Double = 0
    private let maxRecoveryPhraseActionsPer24h = 2

    private var userId: String? { UserDefaults.standard.string(forKey: "currentUserId") }
    private var hasCloudBackup: Bool {
        guard let userId = userId,
              let data = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return false }
        return user.hasCloudBackup
    }
    
    /// Vault key must exist on this device to generate/regenerate phrase and to back up key to cloud (we wrap the key with the phrase).
    private var hasVaultKeyOnDevice: Bool { SecureEnclaveManager.hasMasterKey() }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                
                List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery questions (retrieval mode)")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Answer one of your 3 questions to unlock on a new device. Available for all accounts. You set these after sign-up.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if let uid = userId {
                            Button(action: openChangeRecoveryQuestions) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Change recovery questions")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.accentGradient)
                                .cornerRadius(12)
                            }
                            .disabled(showSetRecoveryQuestions)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Recovery questions")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery phrase (last resort)")
                            .font(.system(size: 16, weight: .semibold))
                        Text("A 12-word phrase that can unlock your vault on another device. Generate it here (requires vault key on this device). Back up your key to the cloud so this phrase works when you recover; available for all accounts.\n\nFor security, we only display the phrase right when you generate/regenerate it. We don't persist the words in-app after you leave—save it somewhere you can access (e.g. Notes, a password manager).")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if !hasVaultKeyOnDevice {
                            Text("Vault key is not on this device. Unlock with a recovery question or phrase first. You need the key on this device to generate a recovery phrase or back up the key to the cloud.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.vertical, 4)
                        }
                        
                        Button(action: onRegenerateButtonTapped) {
                            Text(recoveryPhrase.isEmpty ? "Generate recovery phrase" : "Regenerate recovery phrase")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(hasVaultKeyOnDevice ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(hasVaultKeyOnDevice ? AppTheme.accentGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(12)
                        }
                        .disabled(!hasVaultKeyOnDevice)
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        
                        if recoveryPhrase.isEmpty {
                            if RecoveryPhraseKeychainStore.hasSavedPhrase() {
                                Button("Copy saved recovery phrase") {
                                    do {
                                        let savedWords = try RecoveryPhraseKeychainStore.loadWords()
                                        let phrase = savedWords.joined(separator: " ")
                                        UIPasteboard.general.string = phrase
                                        infoMessage = "Saved recovery phrase copied from device Passwords/Keychain."
                                    } catch {
                                        infoMessage = "Could not load saved recovery phrase: \(error.localizedDescription)"
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 6)
                                .padding(.horizontal, 20)
                            }
                            
                            Text("Tip: We recommend you save your recovery phrase somewhere you can access if you lose your device (Notes, a password manager, etc.). If you didn’t save it, you’ll need to use recovery questions (if set) or regenerate a new phrase.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.warning)
                                .padding(.top, 6)
                        }
                        
                        if !recoveryPhrase.isEmpty {
                            Text("Your 12-word phrase (copy or back up below)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(recoveryPhrase.enumerated()), id: \.offset) { index, word in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .leading)
                                        Text(word)
                                            .font(.system(size: 14, weight: .medium))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .padding()
                            .background(AppTheme.background)
                            .cornerRadius(12)
                            
                            Text("What to do with this phrase")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                            Text("Your key is backed up to the cloud when you generate (or tap \"Back up key to cloud\") so this phrase works when you recover on another device. Copy phrase — copies the 12 words to store offline.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                            
                            Text("Copy or back up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                            Button("Copy recovery phrase") {
                                copyRecoveryPhraseOnly()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                            .padding(.top, 4)
                            .disabled(recoveryPhrase.isEmpty)
                            
                            Button(action: {
                                guard !recoveryPhrase.isEmpty else { return }
                                if RecoveryPhraseKeychainStore.hasSavedPhrase() {
                                    pendingBackupAfterStoredPhraseReplace = false
                                    showReplaceStoredPhraseAlert = true
                                } else {
                                    do {
                                        try RecoveryPhraseKeychainStore.savePhrase(words: recoveryPhrase)
                                        infoMessage = "Recovery phrase saved on this device. You can copy it later anytime."
                                    } catch {
                                        infoMessage = "Could not save to device secure storage: \(error.localizedDescription)"
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text(RecoveryPhraseKeychainStore.hasSavedPhrase() ? "Replace saved phrase" : "Save phrase on this device")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.accent, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            if !hasVaultKeyOnDevice {
                                Text("Back up key to cloud requires the vault key on this device. Unlock with a recovery question or phrase first.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            if isCurrentPhraseBackedUp {
                                Text("Key already backed up to cloud.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            Button(action: onBackUpKeyToCloudButtonTapped) {
                                HStack {
                                    if isBackingUp {
                                        ProgressView()
                                            .tint(AppTheme.accent)
                                    } else {
                                        Image(systemName: "icloud.and.arrow.up.fill")
                                        Text("Back up key to cloud")
                                    }
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(hasVaultKeyOnDevice && !isCurrentPhraseBackedUp ? AppTheme.accent : .gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hasVaultKeyOnDevice && !isCurrentPhraseBackedUp ? AppTheme.accent : Color.gray.opacity(0.5), lineWidth: 1.5))
                                .cornerRadius(12)
                            }
                            .disabled(isBackingUp || !hasVaultKeyOnDevice || isCurrentPhraseBackedUp)
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Recovery phrase")
                } footer: {
                    Text("Keep your phrase private. Anyone with the full phrase may be able to restore access to your vault.")
                }

                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.outlineStrong, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                        )
                )
                .listSectionSeparatorTint(AppTheme.outline.opacity(0.8))
                }
            }
            .navigationTitle("Recovery Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSetRecoveryQuestions) {
                if let uid = userId {
                    SetRecoveryQuestionsView(userId: uid, existingQuestionTexts: existingRecoveryQuestionTexts) {
                        showSetRecoveryQuestions = false
                        existingRecoveryQuestionTexts = nil
                    }
                    .environmentObject(authService)
                }
            }
            .alert("Recovery Info", isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button("OK") { infoMessage = nil }
            } message: {
                Text(infoMessage ?? "")
            }
            .confirmationDialog("Generate new recovery phrase?", isPresented: $showRegenerateConfirmation, titleVisibility: .visible) {
                Button("Generate new phrase", role: .destructive) {
                    showRegenerateConfirmation = false
                    requireFaceID(reason: "Regenerate recovery phrase") { generateRecoveryPhrase() }
                }
                Button("Cancel", role: .cancel) {
                    showRegenerateConfirmation = false
                }
            } message: {
                Text("The old phrase will no longer work. Only this new phrase (and your recovery questions, if set) will unlock your vault. Make sure to save or back up the new phrase.")
            }
            .alert("Replace saved recovery phrase?", isPresented: $showReplaceStoredPhraseAlert) {
                Button("Replace") {
                    do {
                        try RecoveryPhraseKeychainStore.savePhrase(words: recoveryPhrase)
                        infoMessage = "Recovery phrase replaced in your Passwords / Keychain."
                    } catch {
                        infoMessage = "Could not replace phrase on this device: \(error.localizedDescription)"
                    }
                    if pendingBackupAfterStoredPhraseReplace {
                        pendingBackupAfterStoredPhraseReplace = false
                        backUpRecoveryKeyToCloud()
                    }
                }
                Button("Keep existing", role: .cancel) {
                    if pendingBackupAfterStoredPhraseReplace {
                        pendingBackupAfterStoredPhraseReplace = false
                        backUpRecoveryKeyToCloud()
                    }
                }
            } message: {
                Text("You already have a saved recovery phrase on this device. Replacing updates the saved copy so it stays in sync.")
            }
            .alert("Authentication required", isPresented: Binding(
                get: { faceIDError != nil },
                set: { if !$0 { faceIDError = nil } }
            )) {
                Button("OK") { faceIDError = nil }
            } message: {
                Text(faceIDError ?? "Face ID or device passcode is required.")
            }
        }
    }

    /// Open "Change recovery questions" sheet: load existing questions first, then one Face ID, then present. Avoids double Face ID and ensures sheet shows user's chosen questions.
    private func openChangeRecoveryQuestions() {
        guard let uid = userId, !showSetRecoveryQuestions else { return }
        Task {
            var loaded: [String]? = nil
            if let data = try? await DynamoDBService.shared.loadRecoveryQuestions(userId: uid), data.questions.count == 3 {
                loaded = data.questions
            }
            await MainActor.run {
                existingRecoveryQuestionTexts = loaded
                requireFaceID(reason: "Change recovery questions") {
                    showSetRecoveryQuestions = true
                }
            }
        }
    }

    private func requireFaceID(reason: String, then action: @escaping () -> Void) {
        faceIDError = nil
        let context = LAContext()
        var authError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        Task {
            do {
                let success = try await context.evaluatePolicy(policy, localizedReason: "Confirm identity to \(reason)")
                await MainActor.run {
                    if success { action() }
                    else { faceIDError = "Authentication failed." }
                }
            } catch {
                await MainActor.run {
                    faceIDError = "Authentication failed. You must verify your identity to continue."
                }
            }
        }
    }

    /// True if under the 24h limit for regenerate/backup actions (max 2 per 24h). In DEBUG, no limit (developer convenience).
    private func canDoRecoveryPhraseActionMore() -> Bool {
        #if DEBUG
        return true
        #else
        let now = Date().timeIntervalSince1970
        if storedRecoveryPhraseActionResetTimestamp == 0 || (now - storedRecoveryPhraseActionResetTimestamp) >= 24 * 3600 {
            return true
        }
        return storedRecoveryPhraseActionCount < maxRecoveryPhraseActionsPer24h
        #endif
    }

    /// Seconds until the 24h window resets; nil if not at limit.
    private func timeUntilRecoveryPhraseReset() -> TimeInterval? {
        guard !canDoRecoveryPhraseActionMore() else { return nil }
        let now = Date().timeIntervalSince1970
        let resetAt = storedRecoveryPhraseActionResetTimestamp + 24 * 3600
        return max(0, resetAt - now)
    }

    private func recoveryPhraseLimitMessage() -> String {
        guard let secs = timeUntilRecoveryPhraseReset() else { return "You can regenerate or back up again in 24 hours." }
        let hours = Int(secs / 3600)
        let mins = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "You can regenerate or back up again in \(hours) hour\(hours == 1 ? "" : "s")."
        }
        return "You can regenerate or back up again in \(mins) minute\(mins == 1 ? "" : "s")."
    }

    /// Called only when the user taps "Generate/Regenerate recovery phrase". Never called from the Backup button.
    private func onRegenerateButtonTapped() {
        guard hasVaultKeyOnDevice else {
            infoMessage = "Vault key must be on this device. Unlock with a recovery question or phrase first."
            return
        }
        guard canDoRecoveryPhraseActionMore() else {
            infoMessage = recoveryPhraseLimitMessage()
            return
        }
        if !recoveryPhrase.isEmpty {
            showRegenerateConfirmation = true
        } else {
            requireFaceID(reason: "Regenerate recovery phrase") { generateRecoveryPhrase() }
        }
    }

    /// Called only when the user taps "Back up key to cloud". Only runs backup; never shows regenerate confirmation.
    private func onBackUpKeyToCloudButtonTapped() {
        guard canDoRecoveryPhraseActionMore() else {
            infoMessage = recoveryPhraseLimitMessage()
            return
        }
        backUpRecoveryKeyToCloud()
    }

    /// Generate or regenerate phrase.
    /// Uploads the wrapped key to cloud so this phrase works on recovery.
    /// If the user already saved a phrase on-device (Keychain/Passwords), we prompt whether to replace it before we sync to cloud.
    private func generateRecoveryPhrase() {
        do {
            recoveryPhrase = try BIP39Service().generateRecoveryPhrase(wordCount: 12)
            isCurrentPhraseBackedUp = false
            recordRecoveryPhraseAction()
            
            // If a phrase is already saved locally (Passwords/Keychain), prompt replace before backing up to cloud.
            if RecoveryPhraseKeychainStore.hasSavedPhrase() {
                pendingBackupAfterStoredPhraseReplace = true
                showReplaceStoredPhraseAlert = true
            } else {
                // No local saved phrase: just back up to cloud immediately.
                backUpRecoveryKeyToCloud()
            }
        } catch {
            infoMessage = "Failed to generate a recovery phrase."
        }
    }

    private func recordRecoveryPhraseAction() {
        let now = Date().timeIntervalSince1970
        var count = storedRecoveryPhraseActionCount
        if storedRecoveryPhraseActionResetTimestamp == 0 || (now - storedRecoveryPhraseActionResetTimestamp) >= 24 * 3600 {
            count = 0
            storedRecoveryPhraseActionResetTimestamp = now
        }
        count += 1
        storedRecoveryPhraseActionCount = count
    }
    
    /// Uploads the vault key wrapped with the *existing* recovery phrase (does not generate a new phrase). Rate limited to cap DynamoDB writes.
    private func backUpRecoveryKeyToCloud() {
        guard hasVaultKeyOnDevice else {
            infoMessage = "Vault key must be on this device to back up. Unlock with a recovery question or phrase first."
            return
        }
        guard let userId = userId, !recoveryPhrase.isEmpty else {
            infoMessage = "Generate a recovery phrase first."
            return
        }
        guard !isCurrentPhraseBackedUp else {
            infoMessage = "Key already backed up to cloud."
            return
        }
        isBackingUp = true
        Task {
            do {
                try await DynamoDBService.shared.initializeClient()
                let wrapped = try RecoveryService.shared.wrapMasterKey(phraseWords: recoveryPhrase)
                try await RecoveryService.shared.uploadWrappedKey(wrapped, userId: userId)
                await MainActor.run {
                    recordRecoveryPhraseAction()
                    isCurrentPhraseBackedUp = true
                    isBackingUp = false
                    infoMessage = "Recovery key backed up to cloud. You can restore your vault on a new device by entering this phrase."
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    let fallback = "Could not save to cloud. Your session may have expired: sign out and sign in, then try again."
                    infoMessage = (error as? LocalizedError)?.errorDescription ?? fallback
                }
            }
        }
    }
    
    /// Copy only. No Face ID, no backup popup. Use this for the "Copy recovery phrase" button.
    private func copyRecoveryPhraseOnly() {
        guard !recoveryPhrase.isEmpty else { return }
        let phrase = recoveryPhrase.joined(separator: " ")
        UIPasteboard.general.string = phrase
        infoMessage = "Recovery phrase copied. Store it somewhere safe and clear your clipboard when done."
    }
    
    private func copyRecoveryPhrase() {
        copyRecoveryPhraseOnly()
    }
}

#Preview {
    RecoverySettingsView()
}

