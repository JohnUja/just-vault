//
//  SettingsView.swift
//  Just Vault
//
//  App settings and configuration
//

import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authService: AuthenticationService
    @State private var developerModeEnabled = DeveloperMode.isEnabled
    @State private var showPaywall = false
    @State private var pendingFaceIDDisable = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                List {
                #if DEBUG
                Section("Developer") {
                    Toggle("Developer Mode", isOn: $developerModeEnabled)
                        .tint(.green)
                        .onChange(of: developerModeEnabled) { oldValue, newValue in
                            DeveloperMode.isEnabled = newValue
                            if newValue, DeveloperMode.overrideTier == nil {
                                DeveloperMode.overrideTier = .proPlus
                            }
                            NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
                        }
                    
                    if developerModeEnabled {
                        Picker("Simulate subscription", selection: Binding(
                            get: { DeveloperMode.overrideTier ?? .proPlus },
                            set: { newValue in
                                DeveloperMode.overrideTier = newValue
                                NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
                            }
                        )) {
                            Text("Free (6 spaces, 25 MB/file, no cloud)").tag(SubscriptionTier.free)
                            Text("Pro (6 spaces, 100 MB/file, 10 GB cloud)").tag(SubscriptionTier.pro)
                            Text("Pro+ (unlimited spaces, 500 MB/file, 50 GB cloud)").tag(SubscriptionTier.proPlus)
                        }
                        .pickerStyle(.menu)
                        Text("Each tier unlocks the max allowed for that plan. Face ID for spaces still applies to all tiers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    NavigationLink("Developer tools") {
                        DeveloperToolsView()
                    }
                }
                #endif
                
                // Account Section
                Section("Account") {
                    NavigationLink("Display name") {
                        EditDisplayNameView()
                            .environmentObject(authService)
                    }

                    HStack {
                        Text("Subscription")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.subscriptionTier)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.isPro {
                        Button("Manage Subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                    
                    Button(viewModel.isPro ? "Change Plan" : "Upgrade to Pro") {
                        showPaywall = true
                    }
                    .foregroundColor(AppTheme.accent)
                    
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authService.signOut()
                        }
                    }
                }
                
                // Storage Section (only meaningful for Pro users)
                if viewModel.isPro {
                    Section("Storage") {
                        HStack {
                            Text("Cloud Storage")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(viewModel.storageLabel)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: viewModel.usagePercent)
                            .tint(viewModel.storageTint)
                    }
                }
                
                // Security Section
                Section("Security") {
                    NavigationLink {
                        RecoverySettingsView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recovery")
                                    .foregroundColor(.primary)
                                Text("Recommended if this device is lost, replaced, or reset")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("Recommended")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.clear))
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.accent, lineWidth: 0.85)
                                )
                        }
                    }
                    
                    Toggle("Face ID / Touch ID for Spaces", isOn: Binding(
                        get: { viewModel.faceIDEnabled },
                        set: { newValue in
                            if !newValue {
                                pendingFaceIDDisable = true
                            } else {
                                viewModel.faceIDEnabled = true
                                AppPreferences.faceIDEnabled = true
                            }
                        }
                    ))
                        .tint(AppTheme.accent)
                    
                    Text("When enabled, Face ID or Touch ID is required to open locked spaces. This does not affect app login.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Backup & Sync Section (visible for Pro/Pro+ users)
                if viewModel.isPro {
                    Section("Backup & Sync") {
                        Toggle("Automatic Cloud Backup", isOn: $viewModel.cloudBackupEnabled)
                            .tint(AppTheme.accent)
                            .onChange(of: viewModel.cloudBackupEnabled) { _, newValue in
                                AppPreferences.cloudBackupEnabled = newValue
                                if newValue {
                                    Task {
                                        await SyncService.shared.syncAllEligibleLocalFiles()
                                    }
                                }
                            }
                        
                        Text("If your subscription ends, automatic cloud backup and sync will stop. Your files remain encrypted on your device, but cloud-backed recovery may not be available until your subscription is active again (and you still need to have saved your recovery phrase or recovery questions).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("When turned on, new files are automatically backed up to the cloud. This is off by default. Use Sync Now below to manually push eligible local files right away.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Sync Now") {
                            Task {
                                await SyncService.shared.syncAllEligibleLocalFiles(force: true)
                                await SyncService.shared.processSyncQueue(force: true)
                            }
                        }
                        .foregroundColor(AppTheme.accent)
                        
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(viewModel.lastSyncTime)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Support") {
                    Button {
                        openURLString("mailto:\(AppConfig.supportEmail)")
                    } label: {
                        SupportRowIconLabel(title: "Email support", systemImage: "envelope")
                    }
                    .foregroundColor(.primary)

                    Button {
                        requestReview()
                    } label: {
                        SupportRowIconLabel(title: "Rate \(AppConfig.appName)", systemImage: "star")
                    }
                    .foregroundColor(.primary)

                    if let policy = URL(string: AppConfig.privacyPolicyWebURLString) {
                        Button {
                            UIApplication.shared.open(policy)
                        } label: {
                            SupportRowIconLabel(title: "Privacy Policy (web)", systemImage: "safari")
                        }
                        .foregroundColor(.primary)
                    }

                    if let terms = URL(string: AppConfig.termsOfServiceWebURLString) {
                        Button {
                            UIApplication.shared.open(terms)
                        } label: {
                            SupportRowIconLabel(title: "Terms of Service (web)", systemImage: "doc.text")
                        }
                        .foregroundColor(.primary)
                    }

                    if let url = URL(string: AppConfig.relatedAppJustScanStoreURLString) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(AppTheme.headerTint)
                                    .symbolRenderingMode(.monochrome)
                                    .frame(width: 24, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Just Scan")
                                        .foregroundColor(.primary)
                                    Text("Our barcode scanning app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(AppTheme.headerTint.opacity(0.45))
                            }
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

                    NavigationLink("Privacy Policy (in app)") {
                        PrivacyPolicyView()
                    }

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                }

                // Delete account — at very bottom
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permanently delete your account and all data. You will need Face ID and must type a confirmation phrase. This cannot be undone.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        NavigationLink(destination: DeleteAccountView().environmentObject(authService)) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete account")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Delete account")
                } footer: {
                    Text("All data will be wiped from the app and cloud, including your user profile, files, and spaces.")
                }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.outline, lineWidth: 1)
                        )
                )
                .listSectionSeparatorTint(AppTheme.outline.opacity(0.6))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(authService)
            }
            .alert("Disable Biometric Lock?", isPresented: $pendingFaceIDDisable) {
                Button("Disable", role: .destructive) {
                    viewModel.faceIDEnabled = false
                    AppPreferences.faceIDEnabled = false
                }
                Button("Keep Enabled", role: .cancel) {}
            } message: {
                Text("Disabling Face ID / Touch ID means anyone with device access can open your locked spaces without authentication.")
            }
            .onAppear {
                viewModel.loadFromUser(authService.currentUser)
            }
            .onReceive(authService.$currentUser) { user in
                viewModel.loadFromUser(user)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vaultFilesDidChange)) { _ in
                if let date = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
                    viewModel.lastSyncDate = date
                    viewModel.updateLastSyncTime()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
                Task {
                    let refreshedUser = await authService.loadCurrentUser()
                    await MainActor.run {
                        authService.currentUser = refreshedUser
                        viewModel.loadFromUser(refreshedUser)
                    }
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func openURLString(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Support row visuals (outline SF Symbols, no extra chrome)

private struct SupportRowIconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppTheme.headerTint)
                .symbolRenderingMode(.monochrome)
                .frame(width: 24, alignment: .center)
            Text(title)
                .foregroundColor(.primary)
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var subscriptionTier: String = "Free"
    @Published var isPro: Bool = false
    @Published var isFreeTrial: Bool = false
    @Published var usedMB: Double = 0
    @Published var quotaMB: Double = 0
    @Published var faceIDEnabled: Bool = true
    @Published var cloudBackupEnabled: Bool = false
    @Published var lastSyncTime: String = "Never"
    @Published var lastSyncDate: Date?
    
    var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    var storageTint: Color {
        if usagePercent > AppConfig.storageCriticalThreshold { return AppTheme.error }
        if usagePercent > AppConfig.storageWarningThreshold { return AppTheme.warning }
        return AppTheme.success
    }
    
    var storageLabel: String {
        if quotaMB >= 1000 {
            return String(format: "%.1f GB / %.0f GB", usedMB / 1000, quotaMB / 1000)
        }
        return "\(Int(usedMB)) MB / \(Int(quotaMB)) MB"
    }
    
    init() {
        loadSettings()
    }
    
    func loadFromUser(_ user: User?) {
        guard let user else {
            subscriptionTier = "Free"
            isPro = false
            usedMB = 0
            quotaMB = 0
            return
        }
        subscriptionTier = user.effectiveTier.displayName
        isPro = user.hasCloudBackup
        usedMB = user.cloudStorageUsedMB
        quotaMB = user.effectiveCloudStorageQuotaMB
        cloudBackupEnabled = user.hasCloudBackup ? AppPreferences.cloudBackupEnabled : false
        if let syncDate = user.lastSyncAt {
            lastSyncDate = syncDate
            updateLastSyncTime()
        } else if lastSyncDate == nil {
            updateLastSyncTime()
        }
    }
    
    func setDeveloperModeProPlus(authService: AuthenticationService) async {
        guard var user = authService.currentUser else { return }
        user.subscriptionTier = .proPlus
        user.subscriptionStatus = .active
        user.cloudStorageQuotaBytes = Int64(AppConfig.proPlusTierCloudStorageMB * 1_000_000)
        authService.currentUser = user
        try? await authService.saveUserToLocalStorage(user)
        try? await DynamoDBService.shared.saveUserProfile(user)
        loadFromUser(user)
    }
    
    private func loadSettings() {
        faceIDEnabled = AppPreferences.faceIDEnabled
        cloudBackupEnabled = AppPreferences.cloudBackupEnabled
        
        if let syncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = syncDate
            updateLastSyncTime()
        }
    }
    
    func updateLastSyncTime() {
        if let date = lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastSyncTime = formatter.string(from: date)
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        } else {
            lastSyncTime = "Never"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
