//
//  RecoveryPhraseEntryView.swift
//  Just Vault
//
//  Shown after sign-in on a new device when the vault key is not in Keychain
//  but a wrapped key exists in cloud. User enters recovery phrase to unlock.
//

import SwiftUI

struct RecoveryPhraseEntryView: View {
    @EnvironmentObject var authService: AuthenticationService
    let userId: String
    let onRecovered: () -> Void
    /// When non-nil, show "Back to recovery questions" so user can switch to answering a question instead.
    var onBackToRecoveryQuestions: (() -> Void)? = nil
    
    @State private var phraseText = ""
    @State private var isUnlocking = false
    @State private var errorMessage: String?
    @State private var showDeleteMyAccountSheet = false
    @State private var deleteMyAccountText = ""
    @State private var showFinalDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    
    private var phraseWords: [String] {
        phraseText
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if onBackToRecoveryQuestions != nil {
                        HStack {
                            Button(action: { onBackToRecoveryQuestions?() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle")
                                    Text("Use recovery questions instead")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(AppTheme.accent)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.accent)
                    
                    Text("Unlock your vault")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.headerTint)
                    
                    Text("Enter your 12-word recovery phrase to restore access on this device.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    Text("Use the same phrase you used when you tapped \"Back up key to cloud.\" If you never backed up, use recovery questions instead.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    
                    TextField("word1 word2 word3 ...", text: $phraseText, axis: .vertical)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(AppTheme.headerTint)
                        .tint(AppTheme.accent)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.outline, lineWidth: 1)
                        )
                        .lineLimit(3...6)
                        .padding(.horizontal, 24)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    
                    Button(action: unlockVault) {
                        HStack {
                            if isUnlocking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Unlock vault")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(phraseWords.count == 12 ? AppTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                    }
                    .disabled(phraseWords.count != 12 || isUnlocking)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Spacer(minLength: 20)
                    Button(action: { showDeleteMyAccountSheet = true }) {
                        Text("I can't recover — delete my account")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showDeleteMyAccountSheet) {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Cancel") { showDeleteMyAccountSheet = false }
                        .foregroundColor(AppTheme.accent)
                }

                Text("Type the phrase to confirm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)

                Text("DELETE MY ACCOUNT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("DELETE MY ACCOUNT", text: $deleteMyAccountText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(AppTheme.headerTint)
                    .tint(AppTheme.accent)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.outline, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                Button {
                    showFinalDeleteAlert = true
                } label: {
                    Text("Delete account and all data")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(deleteMyAccountText == "DELETE MY ACCOUNT" ? Color.red : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(deleteMyAccountText != "DELETE MY ACCOUNT")
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Text("This permanently deletes your account and all data from the app and cloud.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 10)
            .presentationDetents([.medium])
        }
        .alert("Delete account?", isPresented: $showFinalDeleteAlert) {
            Button("Delete account and all data", role: .destructive) {
                showDeleteMyAccountSheet = false
                deleteAccountAndSignOut()
            }
            Button("I change my mind", role: .cancel) {
                showFinalDeleteAlert = false
            }
        }
        .overlay {
            if isDeletingAccount {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Deleting…")
                    .tint(.white)
            }
        }
        .alert("Could not delete account", isPresented: .constant(deleteAccountError != nil)) {
            Button("OK") { deleteAccountError = nil }
        } message: {
            if let msg = deleteAccountError { Text(msg) }
        }
    }
    
    private func deleteAccountAndSignOut() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            do {
                try await authService.deleteAccount(userId: userId)
                await MainActor.run { isDeletingAccount = false }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountError = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
                }
            }
        }
    }

    private func unlockVault() {
        guard phraseWords.count == 12 else {
            errorMessage = "Enter all 12 words, separated by spaces."
            return
        }
        errorMessage = nil
        isUnlocking = true
        Task {
            do {
                guard let wrappedData = try await RecoveryService.shared.downloadWrappedKey(userId: userId) else {
                    await MainActor.run {
                        errorMessage = "No key has been backed up to the cloud for this account. On a device that has your vault key, open Recovery Settings and tap \"Back up key to cloud\" after generating your phrase. Or use \"Use recovery questions instead\" above if you set those."
                        isUnlocking = false
                    }
                    return
                }
                let masterKey = try RecoveryService.shared.unwrapMasterKey(wrappedData: wrappedData, phraseWords: phraseWords)
                try RecoveryService.shared.storeRecoveredMasterKey(masterKey)
                await MainActor.run {
                    isUnlocking = false
                    onRecovered()
                }
            } catch {
                await MainActor.run {
                    isUnlocking = false
                    errorMessage = "This phrase doesn’t match the key backed up to the cloud. Use the phrase that was on screen when you tapped \"Back up key to cloud,\" or use recovery questions instead."
                }
            }
        }
    }
}
