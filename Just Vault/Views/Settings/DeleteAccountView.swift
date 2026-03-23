//
//  DeleteAccountView.swift
//  Just Vault
//
//  Delete account flow: Face ID → type confirmation phrase → final confirm → wipe all data and sign out.
//

import SwiftUI
import LocalAuthentication

private let kConfirmationPhrase = "DELETE MY ACCOUNT"

struct DeleteAccountView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) var dismiss

    @State private var step: Step = .warning
    @State private var typedPhrase = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalAlert = false

    private var userId: String? { authService.currentUser?.id }

    enum Step {
        case warning   // show warning, tap to continue → Face ID
        case typePhrase // Face ID passed, show text field
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    // Red caution emoji centered at top
                    Text("⚠️")
                        .font(.system(size: 52))
                        .padding(.top, 8)

                    // Delete account — no container, no extra bold/padding
                    Text("Delete account")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.red)

                    // Permanently remove text in white container, red outline, red text, centered
                    Text("This will permanently remove all your data from this app and from the cloud, including your user profile, files, and spaces. You must confirm with Face ID and type the exact phrase below. This cannot be undone.")
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 1.5))

                    if step == .typePhrase {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type the following exactly to continue:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                            Text(kConfirmationPhrase)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.outline, lineWidth: 1)
                                )
                            TextField(kConfirmationPhrase, text: $typedPhrase)
                                .textContentType(.none)
                                .autocorrectionDisabled()
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.outline, lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 48)

                    // Continue button lower: teal outline, teal text, white fill
                    if step == .warning {
                        Button(action: requireFaceID) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent, lineWidth: 2))
                                .cornerRadius(14)
                        }
                        .padding(.top, 16)
                    } else {
                        Button(action: { showFinalAlert = true }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .tint(AppTheme.accent)
                                } else {
                                    Text("Continue")
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(typedPhrase.trimmingCharacters(in: .whitespaces) == kConfirmationPhrase ? AppTheme.accent : .gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(typedPhrase.trimmingCharacters(in: .whitespaces) == kConfirmationPhrase ? AppTheme.accent : Color.gray, lineWidth: 2))
                            .cornerRadius(14)
                        }
                        .disabled(typedPhrase.trimmingCharacters(in: .whitespaces) != kConfirmationPhrase || isDeleting)
                        .padding(.top, 16)
                    }
                }
                .padding(24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you sure you want to delete?", isPresented: $showFinalAlert) {
            Button("DELETE NOW", role: .destructive) {
                performDeletion()
            }
            Button("I change my mind", role: .cancel) {
                showFinalAlert = false
            }
        } message: {
            Text("All your data will be wiped from the app and cloud, including your user profile, files, and spaces. This cannot be undone.")
        }
    }

    private func requireFaceID() {
        errorMessage = nil
        let context = LAContext()
        var authError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        Task {
            do {
                let success = try await context.evaluatePolicy(policy, localizedReason: "Confirm identity to delete account")
                await MainActor.run {
                    if success { step = .typePhrase }
                    else { errorMessage = "Authentication failed." }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Authentication failed. You must verify your identity to continue."
                }
            }
        }
    }

    private func performDeletion() {
        guard let userId = userId else { return }
        showFinalAlert = false
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await authService.deleteAccount(userId: userId)
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Deletion failed. Try again."
                }
            }
        }
    }
}
