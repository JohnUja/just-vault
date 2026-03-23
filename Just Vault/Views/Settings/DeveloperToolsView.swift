//
//  DeveloperToolsView.swift
//  Just Vault
//
//  DEBUG only. Backdoor / developer tools (clear vault key, etc.). Not compiled in Release.
//

#if DEBUG
import SwiftUI

struct DeveloperToolsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keyClearedAlert = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    do {
                        try SecureEnclaveManager.deleteMasterKey()
                        keyClearedAlert = true
                    } catch {
                        message = "Could not clear key: \(error.localizedDescription)"
                    }
                } label: {
                    Label("Clear vault key (test recovery)", systemImage: "key.slash.fill")
                }
                Text("Remove the vault key from this device. After clearing, force quit and reopen; you’ll see recovery questions or phrase entry.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Recovery testing")
            }
            Section {
                Button {
                    UserDefaults.standard.removeObject(forKey: "hasSeenAddDocumentsOnboarding")
                    NotificationCenter.default.post(name: .showAddDocumentsOnboardingAgain, object: nil)
                    message = "Done. Go to the Vault tab — the add-documents sheet will show in a few seconds, or immediately if you're already there."
                } label: {
                    Label("Show add documents onboarding again", systemImage: "doc.badge.plus")
                }
                Text("Resets the one-time flag so the “Let’s help you get started” sheet can appear again (3s after opening the vault).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Onboarding")
            }
        }
        .navigationTitle("Developer tools")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Key cleared", isPresented: $keyClearedAlert) {
            Button("OK") { keyClearedAlert = false }
        } message: {
            Text("Force quit the app and reopen. You’ll be asked for a recovery question or phrase.")
        }
        .alert("Developer", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}
#endif
