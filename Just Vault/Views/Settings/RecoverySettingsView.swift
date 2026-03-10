//
//  RecoverySettingsView.swift
//  Just Vault
//
//  Recovery settings for account and encryption key management
//

import SwiftUI

struct RecoverySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showRecoveryPhrase = false
    @State private var recoveryPhrase: [String] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - Bright purple/pink + white gradient (app-wide)
                LinearGradient(
                    colors: [
                        Color(red: 0.9, green: 0.5, blue: 0.9), // Bright purple/pink
                        Color(red: 0.8, green: 0.4, blue: 0.85), // Medium purple/pink
                        Color.white.opacity(0.9), // White
                        Color(red: 0.85, green: 0.45, blue: 0.9).opacity(0.8) // Light purple/pink
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery Phrase")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Your recovery phrase allows you to restore access to your encrypted files if you lose your device. Store it in a secure location.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        if !recoveryPhrase.isEmpty {
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
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Generate or retrieve recovery phrase
                            generateRecoveryPhrase()
                        }) {
                            Text(recoveryPhrase.isEmpty ? "Generate Recovery Phrase" : "Regenerate Recovery Phrase")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account Recovery")
                } footer: {
                    Text("⚠️ Keep your recovery phrase secure. Anyone with access to it can decrypt your files.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Encryption Keys")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Export your encryption keys for backup purposes. These keys are required to decrypt your files.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            // Export keys
                            exportEncryptionKeys()
                        }) {
                            Text("Export Keys")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Backup")
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.8, green: 0.4, blue: 0.9), lineWidth: 2) // Bright purple/pink outline
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                        )
                )
                .listSectionSeparatorTint(Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.4)) // Bright purple/pink
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
        }
    }
    
    private func generateRecoveryPhrase() {
        // Generate a 12-word recovery phrase
        // In production, this should use a secure random generator
        let words = [
            "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
            "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid"
        ]
        
        recoveryPhrase = (0..<12).map { _ in
            words.randomElement() ?? "word"
        }
    }
    
    private func exportEncryptionKeys() {
        // TODO: Implement key export functionality
        print("Export encryption keys")
    }
}

#Preview {
    RecoverySettingsView()
}

