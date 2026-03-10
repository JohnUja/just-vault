//
//  SettingsView.swift
//  Just Vault
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authService: AuthenticationService
    @State private var developerModeEnabled = DeveloperMode.isEnabled
    
    init() {
        // Initialize viewModel with authService reference
    }
    
    // Check if user is on free trial (free tier but active status)
    var isFreeTrial: Bool {
        guard let user = authService.currentUser else { return false }
        return user.subscriptionTier == .free && user.subscriptionStatus == .active
    }
    
    // Check if pro features should be visible
    var shouldShowProFeatures: Bool {
        DeveloperMode.isEnabled && !isFreeTrial
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                List {
                // Developer Mode Section (only in debug builds)
                #if DEBUG
                Section("Developer") {
                    Toggle("Developer Mode", isOn: $developerModeEnabled)
                        .onChange(of: developerModeEnabled) { oldValue, newValue in
                            DeveloperMode.isEnabled = newValue
                            if newValue {
                                // Set user to Pro+ tier when developer mode is enabled
                                Task {
                                    await viewModel.setDeveloperModeProPlus(authService: authService)
                                }
                            }
                        }
                    
                    if developerModeEnabled {
                        Text("Pro+ features unlocked for testing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                #endif
                
                // Account Section
                Section("Account") {
                    HStack {
                        Text("Subscription")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.subscriptionTier)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.isPro {
                        Button("Manage Subscription") {
                            // Open App Store subscription management
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        Button("Upgrade to Pro") {
                            // Will be handled by parent view
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    HStack {
                        Text("Cloud Storage")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(viewModel.usedMB)) MB / \(Int(viewModel.quotaMB)) MB")
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.usagePercent)
                        .tint(viewModel.usagePercent > 0.9 ? .red : Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.6))
                }
                
                // Security Section
                Section("Security") {
                    NavigationLink("Recovery Settings") {
                        RecoverySettingsView()
                    }
                    
                    Text("Manage account recovery options and backup encryption keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Face ID / Touch ID", isOn: $viewModel.faceIDEnabled)
                        .onChange(of: viewModel.faceIDEnabled) { oldValue, newValue in
                            // Save Face ID preference
                            UserDefaults.standard.set(newValue, forKey: "faceIDEnabled")
                            UserDefaults.standard.synchronize()
                        }
                    
                    Text("Enable biometric authentication for unlocking locked spaces and vaults")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Backup & Sync Section (only visible in developer mode, not free trial)
                if DeveloperMode.isEnabled && !viewModel.isFreeTrial {
                    Section("Backup & Sync") {
                        Toggle("Cloud Backup", isOn: $viewModel.cloudBackupEnabled)
                        
                        Button("Sync Now") {
                            Task {
                                await SyncService.shared.processSyncQueue()
                                // Update last sync time
                                await MainActor.run {
                                    viewModel.lastSyncDate = Date()
                                    viewModel.updateLastSyncTime()
                                }
                            }
                        }
                        
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(viewModel.lastSyncTime)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    
                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.32, green: 0.08, blue: 0.42), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                        )
                )
                .listSectionSeparatorTint(Color(red: 0.32, green: 0.08, blue: 0.42).opacity(0.3))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var subscriptionTier: String = "Free"
    @Published var isPro: Bool = false
    @Published var isFreeTrial: Bool = false // Check if user is on free trial
    @Published var usedMB: Double = 0
    @Published var quotaMB: Double = 250
    @Published var faceIDEnabled: Bool = true
    @Published var cloudBackupEnabled: Bool = false
    @Published var lastSyncTime: String = "Never"
    @Published var lastSyncDate: Date?
    
    func setDeveloperModeProPlus(authService: AuthenticationService) async {
        // Update user to Pro+ tier when developer mode is enabled
        guard var user = authService.currentUser else { return }
        
        // Set to Pro+ tier
        user.subscriptionTier = .proPlus
        user.subscriptionStatus = .active
        user.cloudStorageQuotaBytes = Int64(AppConfig.proPlusTierCloudStorageMB * 1_000_000)
        
        // Update in auth service
        authService.currentUser = user
        
        // Save to local storage
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(user)
            UserDefaults.standard.set(data, forKey: "currentUser")
        } catch {
            print("Failed to save Pro+ user: \(error.localizedDescription)")
        }
        
        // Update DynamoDB if available
        do {
            try await DynamoDBService.shared.saveUserProfile(user)
        } catch {
            print("Failed to save Pro+ to cloud: \(error.localizedDescription)")
        }
        
        // Reload settings
        loadSettings()
    }
    
    var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load Face ID preference
        faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")
        if !UserDefaults.standard.bool(forKey: "faceIDPreferenceSet") {
            // Default to true if not set
            faceIDEnabled = true
            UserDefaults.standard.set(true, forKey: "faceIDEnabled")
            UserDefaults.standard.set(true, forKey: "faceIDPreferenceSet")
        }
        
        // Load last sync time
        if let syncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = syncDate
            updateLastSyncTime()
        }
        
        // Load subscription info from authService
        // This will be updated when user changes
    }
    
    func updateLastSyncTime() {
        if let date = lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastSyncTime = formatter.string(from: date)
            
            // Save to UserDefaults
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        } else {
            lastSyncTime = "Never"
        }
    }
}

#Preview {
    SettingsView()
}

