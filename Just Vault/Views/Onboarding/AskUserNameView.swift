//
//  AskUserNameView.swift
//  Just Vault
//
//  Shown once after recovery questions; friendly single-field name ask so home can show "(Name)'s Vault".
//

import SwiftUI

struct AskUserNameView: View {
    let userId: String
    let onComplete: () -> Void
    @EnvironmentObject private var authService: AuthenticationService

    @State private var displayName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("What should we call you?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.headerTint)
                        .multilineTextAlignment(.center)
                    Text("We'll use this to personalize your vault—just a first name or nickname is fine.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.headerTint)
                    .tint(AppTheme.accent)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.outline, lineWidth: 1))
                    .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.error)
                }

                Spacer(minLength: 24)

                Button(action: saveAndContinue) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(trimmedName.isEmpty ? LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing) : AppTheme.accentGradient)
                    .cornerRadius(14)
                }
                .disabled(trimmedName.isEmpty || isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private func saveAndContinue() {
        guard !trimmedName.isEmpty else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await DynamoDBService.shared.initializeClient()
                guard var user = authService.currentUser else {
                    await MainActor.run { isSaving = false; errorMessage = "Session missing. Try again." }
                    return
                }
                user = User(
                    id: user.id,
                    appleUserId: user.appleUserId,
                    email: user.email,
                    name: trimmedName,
                    createdAt: user.createdAt,
                    lastActiveAt: user.lastActiveAt,
                    subscriptionTier: user.subscriptionTier,
                    subscriptionStatus: user.subscriptionStatus,
                    cloudStorageUsedBytes: user.cloudStorageUsedBytes,
                    cloudStorageQuotaBytes: user.cloudStorageQuotaBytes,
                    lastSyncAt: user.lastSyncAt
                )
                authService.currentUser = user
                try await authService.saveUserToLocalStorage(user)
                try await DynamoDBService.shared.saveUserProfile(user)
                await MainActor.run {
                    isSaving = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not save. Try again."
                }
            }
        }
    }
}
