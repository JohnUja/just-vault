//
//  SettingsView.swift
//  Just Vault
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    HStack {
                        Text("Subscription")
                        Spacer()
                        Text(viewModel.subscriptionTier)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.isPro {
                        Button("Manage Subscription") {
                            // TODO: Open subscription management
                        }
                    } else {
                        Button("Upgrade to Pro") {
                            // TODO: Show upgrade screen
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    HStack {
                        Text("Cloud Storage")
                        Spacer()
                        Text("\(Int(viewModel.usedMB)) MB / \(Int(viewModel.quotaMB)) MB")
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.usagePercent)
                        .tint(viewModel.usagePercent > 0.9 ? .red : .blue)
                }
                
                // Security Section
                Section("Security") {
                    Button("Recovery Settings") {
                        // TODO: Show recovery settings
                    }
                    
                    Toggle("Face ID", isOn: $viewModel.faceIDEnabled)
                    
                    Button("Change Passcode") {
                        // TODO: Show passcode change
                    }
                }
                
                // Backup & Sync Section
                Section("Backup & Sync") {
                    Toggle("Cloud Backup", isOn: $viewModel.cloudBackupEnabled)
                    
                    Button("Sync Now") {
                        // TODO: Trigger sync
                    }
                    
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(viewModel.lastSyncTime)
                            .foregroundColor(.secondary)
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // TODO: Open privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // TODO: Open terms
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var subscriptionTier: String = "Free"
    @Published var isPro: Bool = false
    @Published var usedMB: Double = 0
    @Published var quotaMB: Double = 250
    @Published var faceIDEnabled: Bool = true
    @Published var cloudBackupEnabled: Bool = false
    @Published var lastSyncTime: String = "Never"
    
    var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // TODO: Load from UserDefaults or Core Data
    }
}

#Preview {
    SettingsView()
}

