//
//  EditDisplayNameView.swift
//  Just Vault
//
//  Change display name (e.g. fix typo from onboarding).
//

import SwiftUI

struct EditDisplayNameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService

    @State private var displayName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Display name")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.headerTint)
                    .padding(.top, 24)

                Text("This is shown as \"(Name)'s Vault\" on your home screen.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
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

                Button(action: save) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
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
                .padding(.top, 8)

                Spacer()
            }
        }
        .navigationTitle("Display name")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = authService.currentUser?.name ?? ""
        }
    }

    private func save() {
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
                    NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
                    dismiss()
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
