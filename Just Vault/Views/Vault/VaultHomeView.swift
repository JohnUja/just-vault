//
//  VaultHomeView.swift
//  Just Vault
//
//  Main vault home screen with flower/petal layout
//

import SwiftUI
import UIKit
import LocalAuthentication

// MARK: - Vault Mode Enum

enum VaultMode: Equatable {
    case browse
    case organize
    case focus(spaceId: String)
    case locked
    
    var isFocusMode: Bool {
        if case .focus = self { return true }
        return false
    }
    
    var focusedSpaceId: String? {
        if case .focus(let spaceId) = self { return spaceId }
        return nil
    }
}

struct VaultHomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad’s default `TabView` uses a top/sidebar style; compact size class restores a bottom icon tab bar like iPhone.
    private var tabViewHorizontalSizeClassOverride: UserInterfaceSizeClass {
        if UIDevice.current.userInterfaceIdiom == .pad { return .compact }
        return horizontalSizeClass ?? .compact
    }
    @StateObject private var viewModel: VaultHomeViewModel
    @State private var showFocusInfo = false
    @State private var selectedTab = 0
    @State private var selectedSpace: Space?
    @State private var showSpaceDetail = false
    @State private var showCreateSpace = false
    @State private var pendingCreateSpaceOrderIndex: Int?
    @State private var showPaywall = false
    @State private var showAddFileSpaceSelector = false
    @State private var selectedSpaceForFile: Space?
    @State private var spaceToEdit: Space?
    @State private var showEditSpace = false
    @State private var spaceToDelete: Space?
    @State private var showDeleteConfirmation = false
    @State private var showMoveFilesToSpace = false
    @State private var showSearch = false
    @State private var fileToPreviewFromSearch: VaultFile?
    @State private var fileImportError: String?
    @AppStorage("hasSeenAddDocumentsOnboarding") private var hasSeenAddDocumentsOnboarding = false
    @State private var showAddDocumentsOnboarding = false

    init() {
        // Initialize with placeholder - will be set in onAppear
        _viewModel = StateObject(wrappedValue: VaultHomeViewModel())
    }

    private var vaultTitle: String {
        let name = viewModel.user?.name?.trimmingCharacters(in: .whitespaces) ?? ""
        if name.isEmpty { return "My Vault" }
        let first = name.components(separatedBy: " ").first ?? name
        return "\(first)'s Vault"
    }

    /// Use device idiom so honeycomb stays large on iPad even when we override size class for the tab bar.
    private var isRegularWidth: Bool { UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular }
    private var hiveLayoutScale: CGFloat { isRegularWidth ? 1.22 : 1.0 }
    private var hiveFrameHeight: CGFloat { isRegularWidth ? 540 : 442 }
    private var hiveSpaceHexSide: CGFloat { isRegularWidth ? 138 : 120 }
    private var hiveCenterHubSide: CGFloat { isRegularWidth ? 132 : 120 }

    var body: some View {
        Group {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                ZStack {
                    AppTheme.backgroundGradient.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header — single line: "(Name)'s Vault" when name is set, else "My Vault"
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        // White outline (approx) using multi-direction shadows.
                                        Text(vaultTitle)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: -1, y: 0)
                                        Text(vaultTitle)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: 1, y: 0)
                                        Text(vaultTitle)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: 0, y: -1)
                                        Text(vaultTitle)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: 0, y: 1)
                                        
                                        Text(vaultTitle)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(AppTheme.headerTint)
                                    }
                                    if let user = viewModel.user {
                                        let tierColor = PaywallView.tierAccent(user.effectiveTier)
                                        Text(user.effectiveTier.displayName)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(tierColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.clear)
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(tierColor, lineWidth: 1.5)
                                                    )
                                            )
                                    }
                                }

                                Spacer()

                                HStack(spacing: 10) {
                                    headerShortcutButton(icon: "doc.badge.plus") {
                                        if selectedSpaceForFile == nil {
                                            selectedSpaceForFile = viewModel.spaces.first
                                        }
                                        showAddFileSpaceSelector = true
                                    }

                                    headerShortcutButton(icon: "magnifyingglass") {
                                        showSearch = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                        
                        // Focus Mode Banner
                        if viewModel.vaultMode.isFocusMode, let focusedSpace = viewModel.focusedSpace {
                            FocusModeBanner(
                                spaceName: focusedSpace.name,
                                onExit: {
                                    Task { @MainActor in
                                        viewModel.exitFocusMode()
                                    }
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Hexagon Hive View
                        SpacesHiveView(
                            allSpaces: viewModel.spaces,
                            vaultMode: $viewModel.vaultMode,
                            isPro: viewModel.user?.isPro ?? false,
                            allowsAdditionalPages: viewModel.user?.effectiveTier == .proPlus,
                            syncStatus: effectiveCenterSyncStatus(viewModel: viewModel),
                            hiveLayoutScale: hiveLayoutScale,
                            spaceHexSide: hiveSpaceHexSide,
                            centerHubHexSide: hiveCenterHubSide,
                            onSpaceTap: { space in
                                // Regular tap: always open space (preview/thumbnails)
                                selectedSpace = space
                                showSpaceDetail = true
                            },
                            onSpaceLongPress: { _ in
                                // Long press is reserved for the context menu only.
                            },
                            onSpaceEdit: { space in
                                spaceToEdit = space
                                showEditSpace = true
                            },
                            onSpaceLock: { space in
                                viewModel.lockSpace(space)
                            },
                            onSpaceUnlock: { space in
                                viewModel.unlockSpace(space)
                            },
                            onSpaceDelete: { space in
                                spaceToDelete = space
                                showDeleteConfirmation = true
                            },
                            onGhostTap: { orderIndex in
                                if orderIndex < 6,
                                   let userId = viewModel.user?.id,
                                   let missing = DefaultSpacesService.shared.nextMissingDefault(
                                    existingSpaces: viewModel.spaces, userId: userId
                                   ) {
                                    viewModel.createSpaceFromDefault(missing)
                                } else {
                                    pendingCreateSpaceOrderIndex = orderIndex
                                    showCreateSpace = true
                                }
                            },
                            onLockAll: {
                                viewModel.toggleVaultLockState()
                            },
                            onSyncNow: {
                                viewModel.startSyncFromUI()
                            },
                            showSearch: $showSearch
                        )
                        .frame(height: hiveFrameHeight)
                        
                        // Recent Files Preview (like JustScan)
                        if !viewModel.recentFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Files")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(AppTheme.headerTint)
                                    Spacer()
                                    Button("See All") {
                                        selectedTab = 1 // Switch to Files tab
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.accent)
                                }
                                .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.recentFiles.prefix(6)) { file in
                                            RecentFileCard(file: file)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                            .frame(minHeight: 0)
                        }

                        Spacer(minLength: viewModel.recentFiles.isEmpty ? 34 : 18)
                        
                        // Cloud Backup Bar (persistent at bottom)
                        CloudBackupBar(
                            tier: viewModel.user?.effectiveTier ?? .free,
                            usedMB: viewModel.user?.cloudStorageUsedMB ?? 0,
                            quotaMB: viewModel.user?.effectiveCloudStorageQuotaMB ?? 0,
                            backupEnabled: AppPreferences.cloudBackupEnabled,
                            isSyncing: viewModel.isSyncingInProgress,
                            hasPendingSync: viewModel.hasPendingSync,
                            onBackup: {
                                if (viewModel.user?.hasCloudBackup ?? false) {
                                    if !AppPreferences.cloudBackupEnabled {
                                        AppPreferences.cloudBackupEnabled = true
                                    }
                                    viewModel.startSyncFromUI()
                                } else {
                                    showPaywall = true
                                }
                            }
                        )
                        .padding(.bottom, 24)
                    }
                }
                .sheet(isPresented: $showFocusInfo) {
                    FocusModeInfoSheet()
                }
                .popover(isPresented: $showCreateSpace) {
                    CreateSpacePopupView(onCreate: { name, icon, color in
                        viewModel.createSpace(
                            name: name,
                            icon: icon,
                            color: color,
                            orderIndex: pendingCreateSpaceOrderIndex
                        )
                        pendingCreateSpaceOrderIndex = nil
                        showCreateSpace = false
                    })
                }
                .navigationDestination(isPresented: $showSpaceDetail) {
                    if let space = selectedSpace {
                        SpaceDetailView(space: space, allSpaces: viewModel.spaces)
                    }
                }
                .alert("Space Limit Reached", isPresented: $viewModel.showUpgradePrompt) {
                    Button("Upgrade to Pro") {
                        showPaywall = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Free tier allows \(AppConfig.freeTierMaxSpaces) spaces. Upgrade to Pro for \(AppConfig.proTierMaxSpaces) spaces.")
                }
                .alert("File Too Large", isPresented: Binding(
                    get: { fileImportError != nil },
                    set: { if !$0 { fileImportError = nil } }
                )) {
                    Button("OK") { fileImportError = nil }
                    if viewModel.user?.effectiveTier != .proPlus {
                        Button("Upgrade") {
                            fileImportError = nil
                            showPaywall = true
                        }
                    }
                } message: {
                    Text(fileImportError ?? "")
                }
                .fullScreenCover(isPresented: $showPaywall) {
                    PaywallView()
                        .environmentObject(authService)
                }
                .sheet(isPresented: $showSearch) {
                    SearchView(
                        spaces: viewModel.spaces,
                        onOpenSpace: { space in
                            showSearch = false
                            selectedSpace = space
                            showSpaceDetail = true
                        },
                        onOpenFile: { file in
                            showSearch = false
                            fileToPreviewFromSearch = file
                        }
                    )
                    .environmentObject(authService)
                    .presentationBackground(AppTheme.backgroundGradient)
                }
                .sheet(item: $fileToPreviewFromSearch) { file in
                    FilePreviewView(file: file)
                }
                .sheet(item: $spaceToEdit) { space in
                    EditSpaceView(space: space) { name, icon, color in
                        viewModel.updateSpace(space, name: name, icon: icon, color: color)
                        spaceToEdit = nil
                    }
                }
                .confirmationDialog(
                    spaceToDelete?.fileCount == 0 ? "Delete \"\(spaceToDelete?.name ?? "")\"?" : "Delete \(spaceToDelete?.name ?? "Space")?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    if let space = spaceToDelete, space.fileCount > 0, viewModel.spaces.count > 1 {
                        Button("Move files to another space first") {
                            showDeleteConfirmation = false
                            showMoveFilesToSpace = true
                        }
                    }
                    Button(spaceToDelete?.fileCount == 0 ? "Delete" : "Delete space and all files", role: .destructive) {
                        if let space = spaceToDelete {
                            Task {
                                do {
                                    let context = LAContext()
                                    var authError: NSError?
                                    let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
                                        ? .deviceOwnerAuthenticationWithBiometrics
                                        : .deviceOwnerAuthentication
                                    let ok = try await context.evaluatePolicy(policy, localizedReason: "Confirm deletion")
                                    if ok { try await viewModel.deleteSpace(space) }
                                } catch {
                                    print("Delete cancelled: \(error.localizedDescription)")
                                }
                                spaceToDelete = nil
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { spaceToDelete = nil }
                } message: {
                    Text(spaceToDelete?.fileCount == 0
                         ? "This space is empty. It will be removed."
                         : "All files inside this space will be permanently deleted, including any cloud backups. This cannot be undone.")
                }
                .sheet(isPresented: $showMoveFilesToSpace) {
                    if let source = spaceToDelete {
                        MoveFilesToSpaceView(
                            sourceSpace: source,
                            otherSpaces: viewModel.spaces.filter { $0.id != source.id },
                            onSelect: { target in
                                Task {
                                    do {
                                        try await viewModel.moveAllFiles(from: source, to: target)
                                        try await viewModel.deleteSpace(source)
                                        await MainActor.run {
                                            showMoveFilesToSpace = false
                                            spaceToDelete = nil
                                        }
                                    } catch {
                                        print("Move/delete failed: \(error.localizedDescription)")
                                    }
                                }
                            },
                            onCancel: {
                                showMoveFilesToSpace = false
                            }
                        )
                    }
                }
                .overlay {
                    // IMPORTANT: keep a single overlay modifier to avoid SwiftUI
                    // intermediate rendering states (which can look like “stuck/black” UI).
                    if showAddDocumentsOnboarding {
                        standalonePopUpOverlay(onDismiss: {
                            showAddDocumentsOnboarding = false
                            hasSeenAddDocumentsOnboarding = true
                        }, content: {
                            AddImportantDocumentsSheet(
                                spaces: viewModel.spaces,
                                allowedContentTypes: (viewModel.user?.effectiveTier ?? .free).allowedContentTypes,
                                onImport: { url, space in
                                    await importFileToSpace(url: url, space: space)
                                },
                                onDismiss: {
                                    showAddDocumentsOnboarding = false
                                    hasSeenAddDocumentsOnboarding = true
                                }
                            )
                        })
                    }
                }
                .fullScreenCover(isPresented: $showAddFileSpaceSelector) {
                    AddFileSpaceSelectorView(
                        spaces: viewModel.spaces,
                        allowedContentTypes: (viewModel.user?.effectiveTier ?? .free).allowedContentTypes,
                        selectedSpace: selectedSpaceForFile,
                        onSpaceSelected: { space in
                            selectedSpaceForFile = space
                        },
                        onOpenSpace: { space in
                            selectedSpace = space
                            showSpaceDetail = true
                            showAddFileSpaceSelector = false
                        },
                        onDocumentPicked: { url, space in
                            Task {
                                await importFileToSpace(url: url, space: space)
                            }
                        },
                        onImagePicked: { image, sourceType, space in
                            Task {
                                if let imageData = image.jpegData(compressionQuality: 0.8) {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                                    let prefix = sourceType == .camera ? "Camera" : "Photo"
                                    let fileName = "\(prefix) \(formatter.string(from: Date())).jpg"
                                    let tempURL = FileManager.default.temporaryDirectory
                                        .appendingPathComponent(fileName)
                                    try? imageData.write(to: tempURL)
                                    await importFileToSpace(url: tempURL, space: space)
                                }
                            }
                        },
                        onRequestDismiss: { showAddFileSpaceSelector = false }
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save all data before app goes to background
                    viewModel.saveAllData()
                    viewModel.lockVault()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        await viewModel.unlockVault()
                    }
                }
                .onAppear {
                    viewModel.setAuthService(authService)
                    Task {
                        await viewModel.loadUser()
                        // Load spaces after user is loaded
                        viewModel.refreshSpaces()
                        await viewModel.loadRecentFiles()
                        
                        // Show “add important documents” onboarding once, ~3s after spaces are loaded
                        if !hasSeenAddDocumentsOnboarding {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            await MainActor.run {
                                if !hasSeenAddDocumentsOnboarding {
                                    showAddDocumentsOnboarding = true
                                }
                            }
                        }
                    }
                }
                .onChange(of: viewModel.user) { oldUser, newUser in
                    if newUser != nil {
                        Task {
                            await viewModel.loadRecentFiles()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
                    Task {
                        await viewModel.loadUser()
                        await viewModel.loadRecentFiles()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .showAddDocumentsOnboardingAgain)) { _ in
                    hasSeenAddDocumentsOnboarding = false
                    showAddDocumentsOnboarding = true
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            // Files Tab
            FilesView(spaces: viewModel.spaces)
                .tabItem {
                    Label("Files", systemImage: "doc.fill")
                }
                .tag(1)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(AppTheme.accent)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                showSpaceDetail = false
                selectedSpace = nil
            }
        }
        }
        .environment(\.horizontalSizeClass, tabViewHorizontalSizeClassOverride)
    }
    
    /// When automatic cloud backup is off, don't show "syncing" or "pending" in the center hub.
    private func effectiveCenterSyncStatus(viewModel: VaultHomeViewModel) -> SyncStatus {
        let raw = viewModel.isSyncingInProgress ? SyncStatus.syncing : viewModel.syncStatus
        if !AppPreferences.cloudBackupEnabled && (raw == .pending || raw == .syncing) {
            return .localOnly
        }
        return raw
    }

    // MARK: - File Import Helper

    private func importFileToSpace(url: URL, space: Space) async {
        let vm = viewModel
        let tier = vm.user?.effectiveTier ?? .free

        do {
            let ext = url.pathExtension.lowercased()
            let videoExts = ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "webm"]
            if videoExts.contains(ext) {
                print("File rejected: video formats are not supported in this version")
                return
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            if fileSize > tier.maxFileSizeBytes {
                let message = "File exceeds \(tier.maxFileSizeMB) MB limit for \(tier.displayName). \(tier == .free ? "Upgrade to Pro for 100 MB per file." : tier == .pro ? "Upgrade to Pro+ for 500 MB per file." : "")"
                await MainActor.run { fileImportError = message }
                return
            }

            let vaultFile = try await FileImportService.shared.importFile(
                url: url,
                spaceId: space.id,
                userId: space.userId
            )
            
            // Save metadata locally so files appear in All Files and space previews
            try LocalFileMetadataService.shared.saveFileMetadata(vaultFile, userId: space.userId)
            
            let hasCloudBackup = await MainActor.run {
                return vm.user?.hasCloudBackup ?? false
            }
            
            if hasCloudBackup {
                if AppPreferences.cloudBackupEnabled {
                    try? await DynamoDBService.shared.saveFileMetadata(vaultFile)
                    SyncService.shared.queueFileForSync(vaultFile)
                }
            }
            
            await MainActor.run {
                vm.refreshSpaces()
                Task { await vm.loadRecentFiles() }
                NotificationCenter.default.post(name: NSNotification.Name("VaultFilesDidChange"), object: nil)
            }
        } catch {
            print("Failed to import file: \(error.localizedDescription)")
        }
    }
}

private extension VaultHomeView {
    /// Standalone centered pop-up (not a bottom sheet): dimmed background + card in the middle.
    @ViewBuilder
    func standalonePopUpOverlay<Content: View>(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
                content()
                    .frame(maxWidth: 340, maxHeight: min(480, geo.size.height * 0.72))
                    .background(AppTheme.backgroundGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func headerShortcutButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.headerTint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(.white)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.outline, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// Storage Meter Component
struct StorageMeterView: View {
    let usedMB: Double
    let quotaMB: Double
    let isPro: Bool
    
    var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloud Storage")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(Int(usedMB)) MB / \(Int(quotaMB)) MB")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Modern Progress Bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.cardOutline)
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: usagePercent > 0.9 
                                    ? [Color.red, Color.orange]
                                    : [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * usagePercent, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(12) // Reduced padding to make box smaller
        .background(
            RoundedRectangle(cornerRadius: 16) // Smaller corner radius
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Focus Mode Banner

struct FocusModeBanner: View {
    let spaceName: String
    let onExit: () -> Void
    @State private var isVisible = true
    
    var body: some View {
        HStack {
            Image(systemName: "target")
                .foregroundColor(AppTheme.accent)
            Text("Focusing on: \(spaceName)")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Focus Mode Info Sheet

struct FocusModeInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                
                Text("Focus Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(
                        icon: "hand.tap.fill",
                        title: "How to Use",
                        description: "Long-press any space bubble, then select 'Focus on [Space Name]'"
                    )
                    
                    InfoRow(
                        icon: "eye.fill",
                        title: "What It Does",
                        description: "Focus Mode lets you work with one space at a time. The center vault shows stats and actions for that space only."
                    )
                    
                    InfoRow(
                        icon: "moon.fill",
                        title: "Visual Changes",
                        description: "The selected space glows, while other spaces are dimmed to reduce distraction."
                    )
                    
                    InfoRow(
                        icon: "arrow.uturn.backward",
                        title: "Auto-Exit",
                        description: "Focus mode exits automatically when you navigate, background the app, or after 30 seconds of inactivity."
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
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
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Spaces Layout Engine

struct SpacesLayoutEngine {
    let spaceCount: Int
    
    private let baseCenterRadius: CGFloat = 70
    private let basePetalRadius: CGFloat = 70
    private let basePetalDistance: CGFloat = 160
    
    var centerRadius: CGFloat {
        switch spaceCount {
        case 0, 1: return 62
        case 2: return 66
        default: return baseCenterRadius
        }
    }
    
    var petalRadius: CGFloat {
        switch spaceCount {
        case 0, 1: return 50
        case 2: return 60
        case 3...4: return 65
        default: return basePetalRadius
        }
    }
    
    var petalDistance: CGFloat {
        switch spaceCount {
        case 0, 1: return 120
        case 2: return 140
        case 3...4: return 150
        default: return basePetalDistance
        }
    }
    
    var addPetalRadius: CGFloat {
        petalRadius * 0.75
    }
    
    var stemWidth: CGFloat {
        4
    }
}

// MARK: - Spaces Flower Layout

struct SpacesFlowerView: View {
    let spaces: [Space]
    @Binding var vaultMode: VaultMode
    let syncStatus: SyncStatus
    let onAddSpace: () -> Void
    let onSpaceTap: (Space) -> Void
    let onFocusSpace: (Space) -> Void
    let onShowFocusInfo: () -> Void
    let onOrganize: () -> Void
    
    @State private var orbitAngle: Double = 0
    
    // Use layout engine
    private var layout: SpacesLayoutEngine {
        SpacesLayoutEngine(spaceCount: spaces.count)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                stemsView(center: center)
                vaultCoreView(center: center)
                spacePetalsView(center: center)
                addSpacePetalView(center: center)
            }
        }
        .frame(height: 500) // Increased height for better flower layout
        .onChange(of: vaultMode) { oldValue, newMode in
            handleModeChange(newMode)
        }
    }
    
    @ViewBuilder
    private func stemsView(center: CGPoint) -> some View {
        ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
            stemForSpace(space: space, index: index, center: center)
        }
    }
    
    private func stemForSpace(space: Space, index: Int, center: CGPoint) -> some View {
        let angle = angleForPetal(at: index, total: spaces.count)
        let petalPosition = positionForPetal(center: center, angle: angle, distance: layout.petalDistance)
        
        return Path { path in
            let startPoint = center
            let endPoint = petalPosition
            let controlPoint = CGPoint(
                x: (startPoint.x + endPoint.x) / 2,
                y: (startPoint.y + endPoint.y) / 2 - 10 // Slight curve
            )
            
            path.move(to: startPoint)
            path.addQuadCurve(to: endPoint, control: controlPoint)
        }
        .stroke(
            LinearGradient(
                colors: [
                    Color(hex: space.color).opacity(0.5),
                    Color(hex: space.color).opacity(0.3),
                    Color(hex: space.color).opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: layout.stemWidth, lineCap: .round, lineJoin: .round)
        )
        .opacity(vaultMode.isFocusMode && vaultMode.focusedSpaceId != space.id ? 0.15 : 1.0)
        .shadow(color: Color(hex: space.color).opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func vaultCoreView(center: CGPoint) -> some View {
        VaultCoreView(
            vaultMode: vaultMode,
            spaces: spaces,
            totalFileCount: spaces.reduce(0) { $0 + $1.fileCount },
            spaceCount: spaces.count,
            syncStatus: syncStatus,
            onOrganize: onOrganize
        )
        .frame(width: layout.centerRadius * 2, height: layout.centerRadius * 2)
        .contentShape(Circle())
        .clipShape(Circle())
        .position(center)
    }
    
    @ViewBuilder
    private func spacePetalsView(center: CGPoint) -> some View {
        ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
            spacePetalView(space: space, index: index, center: center)
        }
    }
    
    private func spacePetalView(space: Space, index: Int, center: CGPoint) -> some View {
        let angle = angleForPetal(at: index, total: spaces.count)
        let position = positionForPetal(center: center, angle: angle, distance: layout.petalDistance)
        let isFocused = vaultMode.focusedSpaceId == space.id
        let isDimmed = vaultMode.isFocusMode && !isFocused
        
        // Get radius from physics or use default
        let radius = BubbleSizeCalculator.radius(for: space.fileCount)
        
        return SpaceBubbleView(
            space: space,
            isFocused: isFocused,
            isDimmed: isDimmed,
            vaultMode: vaultMode,
            radius: radius,
            position: position,
            onTap: { onSpaceTap(space) },
            onFocus: { onFocusSpace(space) },
            onShowFocusInfo: onShowFocusInfo,
            onLongPress: {
                // Long press handled by SpaceBubbleView
            }
        )
        .position(position)
        .zIndex(isFocused ? 10 : 1)
    }
    
    @ViewBuilder
    private func addSpacePetalView(center: CGPoint) -> some View {
        if !vaultMode.isFocusMode {
            let addIndex = spaces.count
            let angle = angleForPetal(at: addIndex, total: spaces.count + 1)
            let position = positionForPetal(center: center, angle: angle, distance: layout.petalDistance)
            
            // Stem for add button
            Path { path in
                path.move(to: center)
                path.addLine(to: position)
            }
            .stroke(
                AppTheme.secondaryText.opacity(0.5),
                style: StrokeStyle(lineWidth: layout.stemWidth, lineCap: .round, dash: [5, 5])
            )
            
            Button(action: onAddSpace) {
                AddSpacePetalView()
                    .frame(width: layout.addPetalRadius * 2, height: layout.addPetalRadius * 2)
            }
            .position(position)
        }
    }
    
    private func handleModeChange(_ newMode: VaultMode) {
        if newMode == .organize {
            // Start orbit animation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                orbitAngle = 360
            }
        } else {
            orbitAngle = 0
        }
    }
    
    // Calculate angle for petal position (evenly distributed around circle)
    private func angleForPetal(at index: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        let baseAngle = (2 * .pi) / CGFloat(total)
        return baseAngle * CGFloat(index) - (.pi / 2) // Start from top
    }
    
    // Calculate position for petal based on angle and distance
    private func positionForPetal(center: CGPoint, angle: CGFloat, distance: CGFloat) -> CGPoint {
        return CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
    }
}

// MARK: - Vault Core (Enhanced)

struct VaultCoreView: View {
    let vaultMode: VaultMode
    let spaces: [Space]
    let totalFileCount: Int
    let spaceCount: Int
    let syncStatus: SyncStatus
    let onOrganize: () -> Void
    
    @State private var pulseScale: CGFloat = 1.0
    
    var focusedSpace: Space? {
        guard let spaceId = vaultMode.focusedSpaceId else { return nil }
        return spaces.first { $0.id == spaceId }
    }
    
    var body: some View {
        ZStack {
            baseCircle
            orbitRing
            contentView
        }
        .simultaneousGesture(tapGesture)
        .contextMenu {
            VaultCoreContextMenu(vaultMode: vaultMode, onOrganize: onOrganize)
        }
        .onAppear {
            handleAppear()
        }
        .onChange(of: vaultMode) { oldValue, newMode in
            handleModeChange(newMode)
        }
    }
    
    private var baseCircle: some View {
        Circle()
            .fill(gradientForMode(vaultMode))
            .shadow(color: shadowColorForMode(vaultMode), radius: 10, x: 0, y: 5)
            .scaleEffect(pulseScale)
    }
    
    @ViewBuilder
    private var orbitRing: some View {
        if vaultMode == .organize {
            Circle()
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: vaultMode)
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 4) {
            iconView
            statsView
            syncStatusDot
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let focusedSpace = focusedSpace {
            Image(systemName: focusedSpace.icon)
                .font(.system(size: 28))
                .foregroundColor(AppTheme.headerTint)
            Text(focusedSpace.name)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.headerTint)
                .lineLimit(1)
        } else {
            Image(systemName: iconForMode(vaultMode))
                .font(.system(size: 28))
                .foregroundColor(AppTheme.headerTint)
        }
    }
    
    @ViewBuilder
    private var statsView: some View {
        if let focusedSpace = focusedSpace {
            Text("\(focusedSpace.fileCount) files")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        } else {
            Text("\(totalFileCount) files")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
            Text("\(spaceCount) spaces")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var syncStatusDot: some View {
        Circle()
            .fill(syncStatusColor)
            .frame(width: 6, height: 6)
    }
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                handleTap()
            }
    }
    
    private func handleTap() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 0.95
        }
        withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
            pulseScale = 1.0
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleAppear() {
        // Breathing glow animation for browse mode
        if vaultMode == .browse {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
    
    private func handleModeChange(_ newMode: VaultMode) {
        if newMode == .browse {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        } else if case .focus = newMode {
            // Pulse for focus mode
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        } else {
            pulseScale = 1.0
        }
    }
    
    private func gradientForMode(_ mode: VaultMode) -> LinearGradient {
        switch mode {
        case .browse:
            return LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .organize:
            return LinearGradient(
                colors: [AppTheme.gold, AppTheme.gold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .focus:
            return LinearGradient(
                colors: [AppTheme.goldLight, AppTheme.gold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked:
            return LinearGradient(
                colors: [AppTheme.secondaryText, AppTheme.secondaryText],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func shadowColorForMode(_ mode: VaultMode) -> Color {
        switch mode {
        case .browse, .organize, .focus:
            return .black.opacity(0.2)
        case .locked:
            return .black.opacity(0.4)
        }
    }
    
    private func iconForMode(_ mode: VaultMode) -> String {
        switch mode {
        case .browse: return "lock.shield.fill"
        case .organize: return "slider.horizontal.3"
        case .focus: return "target"
        case .locked: return "lock.fill"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncStatus {
        case .synced:
            return AppTheme.success
        case .syncing:
            return AppTheme.accent
        case .pending:
            return AppTheme.warning
        case .error:
            return AppTheme.error
        case .localOnly:
            return AppTheme.secondaryText
        }
    }
}

// MARK: - Vault Core Context Menu

struct VaultCoreContextMenu: View {
    let vaultMode: VaultMode
    let onOrganize: () -> Void
    
    var body: some View {
        if vaultMode == .organize {
            Button(action: onOrganize) {
                Label("Exit Organize", systemImage: "xmark.circle")
            }
        } else {
            Button(action: onOrganize) {
                Label("Organize Spaces", systemImage: "slider.horizontal.3")
            }
        }
        
        Button(action: {}) {
            Label("Lock Vault", systemImage: "lock.fill")
        }
        
        Button(action: {}) {
            Label("View All Files", systemImage: "doc.fill")
        }
        
        Button(action: {}) {
            Label("Sync Now", systemImage: "arrow.clockwise")
        }
        
        Button(action: {}) {
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
}

// Add Space Petal (Dashed circle)
// Add Space Petal (Dashed circle) - Smaller size
struct AddSpacePetalView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.outline)
                .overlay(
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        .foregroundColor(.gray.opacity(0.4))
                )
            
            VStack(spacing: 2) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                Text("Add")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Space Bubble Component (Enhanced Flower Petal)

struct SpaceBubbleView: View {
    let space: Space
    let isFocused: Bool
    let isDimmed: Bool
    let vaultMode: VaultMode
    let radius: CGFloat  // Dynamic radius from physics
    let position: CGPoint  // Position from physics
    let onTap: () -> Void
    let onFocus: () -> Void
    let onShowFocusInfo: () -> Void
    let onLongPress: () -> Void  // Long press handler
    
    @State private var glowOpacity: Double = 0
    @State private var isShaking = false
    @State private var shakeOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var isOrganizeMode: Bool {
        vaultMode == .organize
    }
    
    var body: some View {
        ZStack {
            // Outer glow ring (for focused state)
            if isFocused {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: space.color).opacity(0.3),
                                Color(hex: space.color).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 70,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .opacity(glowOpacity)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
            }
            
            // Main bubble with gradient
            ZStack {
                // Shadow layer
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: radius * 2, height: radius * 2)
                    .offset(x: 0, y: 4)
                    .blur(radius: 8)
                
                // Main circle with gradient (dynamic size)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: space.color),
                                Color(hex: space.color).opacity(0.8),
                                Color(hex: space.color).opacity(0.6)
                            ],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: radius * 0.2,
                            endRadius: radius * 0.7
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(
                        // Inner highlight
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        // Border
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                
                // Content (scales with bubble size)
                VStack(spacing: 6) {
                    Image(systemName: space.icon)
                        .font(.system(size: radius * 0.45, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    .white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    
                    Text(space.name)
                        .font(.system(size: radius * 0.16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.headerTint)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    
                    // File count badge (if has files)
                    if space.fileCount > 0 {
                        Text("\(space.fileCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.headerTint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .opacity(isDimmed ? 0.25 : 1.0)
        .blur(radius: isDimmed ? 3 : 0)
        .offset(x: isShaking ? shakeOffset : 0)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .contentShape(Circle())  // Circular hit area
        .clipShape(Circle())
        .simultaneousGesture(
            // Long press gesture (triggers shake + context menu)
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    triggerLongPress()
                }
        )
        .simultaneousGesture(
            // Tap gesture
            TapGesture()
                .onEnded {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onTap()
                }
        )
        .contextMenu {
            SpaceContextMenu(
                space: space,
                onFocus: onFocus,
                onShowFocusInfo: onShowFocusInfo
            )
        }
        .onAppear {
            if isFocused {
                glowOpacity = 1.0
                pulseScale = 1.1
            }
        }
        .onChange(of: isFocused) { oldValue, focused in
            if focused {
                withAnimation {
                    glowOpacity = 1.0
                    pulseScale = 1.1
                }
            } else {
                withAnimation {
                    glowOpacity = 0
                    pulseScale = 1.0
                }
            }
        }
    }
    
    // MARK: - Long Press Handler
    
    private func triggerLongPress() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Start shake animation
        withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
            isShaking = true
            shakeOffset = CGFloat.random(in: -2...2)
        }
        
        // Call long press handler
        onLongPress()
        
        // Stop shaking after context menu appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isShaking = false
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Space Context Menu

struct SpaceContextMenu: View {
    let space: Space
    let onFocus: () -> Void
    let onShowFocusInfo: () -> Void
    
    var body: some View {
        Button(action: onFocus) {
            Label("Focus on \(space.name)", systemImage: "target")
        }
        
        Divider()
        
        Button(action: {}) {
            Label("Rename Space", systemImage: "pencil")
        }
        
        Button(action: {}) {
            Label("Change Icon", systemImage: "photo")
        }
        
        Button(action: {}) {
            Label("Change Color", systemImage: "paintpalette")
        }
        
        Divider()
        
        Button(action: onShowFocusInfo) {
            Label("What is Focus Mode?", systemImage: "info.circle")
        }
        
        Divider()
        
        Button(role: .destructive, action: {}) {
            Label("Delete Space", systemImage: "trash")
        }
    }
}


// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ViewModel

@MainActor
class VaultHomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var spaces: [Space] = []
    @Published var showCreateSpace = false
    @Published var vaultMode: VaultMode = .browse
    @Published var totalFileCount: Int = 0
    @Published var spaceCount: Int = 0
    @Published var syncStatus: SyncStatus = .synced
    @Published var showUpgradePrompt = false
    @Published var showPaywall = false
    @Published var recentFiles: [VaultFile] = []
    @Published var isSyncingInProgress = false
    /// True when there are local files with .pending or .error that can be synced (for cloud bar "Sync Now" vs "Up to date").
    @Published var hasPendingSync = false
    
    private let localStorage = LocalStorageService()
    private var focusModeTimer: Timer?
    private let authContext = LAContext()
    private weak var authService: AuthenticationService?
    
    var focusedSpace: Space? {
        guard let spaceId = vaultMode.focusedSpaceId else { return nil }
        return spaces.first { $0.id == spaceId }
    }
    
    init() {
        loadSpaces()
        calculateStats()
    }
    
    func setAuthService(_ service: AuthenticationService) {
        self.authService = service
    }
    
    func loadUser() async {
        // Try to load from AuthenticationService first
        if let loadedUser = await authService?.loadCurrentUser() {
            user = loadedUser
            await MainActor.run { authService?.currentUser = loadedUser }
            await loadRecentFiles()
            return
        }
        
        // If no user found, check if authService has currentUser
        if let currentUser = authService?.currentUser {
            user = currentUser
            await loadRecentFiles()
            return
        }
        
        // Fallback to placeholder for first-time users
        user = User(
            id: "placeholder",
            appleUserId: "placeholder",
            email: nil,
            name: nil,
            createdAt: Date(),
            lastActiveAt: Date(),
            subscriptionTier: .free,
            subscriptionStatus: .none,
            cloudStorageUsedBytes: 0,
            cloudStorageQuotaBytes: Int64(AppConfig.freeTierCloudStorageMB * 1_000_000)
        )
    }
    
    /// Recent files are always from local storage (last opened / uploaded). Cloud is never required to show them.
    func loadRecentFiles() async {
        guard let userId = user?.id else {
            await MainActor.run { recentFiles = [] }
            return
        }
        
        // Always load from local first — recent files must work without AWS (e.g. expired credentials).
        var allFiles: [VaultFile] = []
        do {
            allFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
        } catch {
            print("Failed to load local files for recent: \(error.localizedDescription)")
            await MainActor.run { recentFiles = [] }
            return
        }
        
        // Optionally merge with DynamoDB for sync status; never let AWS failure clear recent files.
        if let user = user, user.hasCloudBackup {
            do {
                let cloudFiles = try await DynamoDBService.shared.loadAllFiles(userId: userId)
                var mergedById = Dictionary(uniqueKeysWithValues: allFiles.map { ($0.id, $0) })
                for file in cloudFiles {
                    mergedById[file.id] = file
                    try? LocalFileMetadataService.shared.saveFileMetadata(file, userId: userId)
                }
                allFiles = Array(mergedById.values)
            } catch {
                // AWS failed (e.g. credentials expired) — keep local list; don't clear recent files
                if !error.localizedDescription.contains("Cloud sync is only available") {
                    print("Failed to load cloud files for recent (using local only): \(error.localizedDescription)")
                }
            }
        }
        
        let sorted = allFiles.sorted {
            let lhsDate = $0.lastOpenedAt ?? $0.createdAt
            let rhsDate = $1.lastOpenedAt ?? $1.createdAt
            return lhsDate > rhsDate
        }
        await MainActor.run {
            recentFiles = Array(sorted.prefix(6))
        }
    }
    
    /// Called when user taps Sync Now. Marks pending files as .syncing (orange), runs sync, then refreshes.
    func startSyncFromUI() {
        guard user?.hasCloudBackup == true, let userId = user?.id else { return }
        isSyncingInProgress = true
        Task {
            do {
                let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
                let pending = localFiles.filter { $0.syncStatus == .pending || $0.syncStatus == .error }
                await SyncService.shared.addFilesToQueueOnly(pending)
                for var file in pending {
                    file.syncStatus = .syncing
                    try? LocalFileMetadataService.shared.updateFileMetadata(file, userId: userId)
                }
                if !pending.isEmpty {
                    NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
                }
            } catch {
                print("Failed to queue sync: \(error.localizedDescription)")
            }
            await SyncService.shared.processSyncQueue(force: true)
            await loadSpacesAsync()
            await calculateStatsAsync()
            await loadRecentFiles()
            await MainActor.run { isSyncingInProgress = false }
        }
    }

    func refreshSpaces() {
        Task {
            await loadSpacesAsync()
            await calculateStatsAsync()
        }
    }
    
    private func loadSpaces() {
        Task {
            await loadSpacesAsync()
        }
    }
    
    private func loadSpacesAsync() async {
        guard let userId = user?.id, userId != "placeholder" else {
            await MainActor.run { spaces = [] }
            return
        }

        let hasCloudBackup = user?.hasCloudBackup ?? false
        var localSpaces = normalizedSpaces(loadSpacesFromLocalStorage(userId: userId))

        if DefaultSpacesService.shared.shouldCreateDefaults(existingSpaces: localSpaces) {
            if hasCloudBackup, let cloudSpaces = try? await DynamoDBService.shared.loadSpaces(userId: userId), !cloudSpaces.isEmpty {
                localSpaces = normalizedSpaces(cloudSpaces)
                saveSpacesToLocalStorage(spaces: localSpaces, userId: userId)
            } else {
                let defaultSpaces = DefaultSpacesService.shared.createDefaultSpaces(userId: userId)
                localSpaces = normalizedSpaces(defaultSpaces)
                saveSpacesToLocalStorage(spaces: localSpaces, userId: userId)

                if hasCloudBackup {
                    for space in localSpaces {
                        try? await DynamoDBService.shared.saveSpace(space)
                    }
                }
            }
        }

        await MainActor.run {
            spaces = localSpaces
        }

        guard hasCloudBackup else { return }

        do {
            let dynamoDBSpaces = try await DynamoDBService.shared.loadSpaces(userId: userId)
            let mergedSpaces = normalizedSpaces(localSpaces + dynamoDBSpaces)

            await MainActor.run {
                spaces = mergedSpaces
            }

            saveSpacesToLocalStorage(spaces: mergedSpaces, userId: userId)
        } catch {
            let msg = error.localizedDescription
            if !msg.contains("Cloud sync is only available") {
                print("Failed to load spaces from DynamoDB: \(msg)")
            }
        }
    }
    
    private func loadSpacesFromLocalStorage(userId: String) -> [Space] {
        let key = "spaces_\(userId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let spaces = try? JSONDecoder().decode([Space].self, from: data) else {
            return []
        }
        return spaces
    }
    
    private func saveSpacesToLocalStorage(spaces: [Space], userId: String) {
        let key = "spaces_\(userId)"
        let normalized = normalizedSpaces(spaces)
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }

    private func normalizedSpaces(_ input: [Space]) -> [Space] {
        var bestByOrderIndex: [Int: Space] = [:]

        for space in input {
            guard let existing = bestByOrderIndex[space.orderIndex] else {
                bestByOrderIndex[space.orderIndex] = space
                continue
            }

            if space.fileCount > existing.fileCount ||
                (space.fileCount == existing.fileCount && space.createdAt < existing.createdAt) {
                bestByOrderIndex[space.orderIndex] = space
            }
        }

        return bestByOrderIndex.values.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    func calculateStats() {
        Task {
            await calculateStatsAsync()
        }
    }
    
    private func calculateStatsAsync() async {
        guard let userId = user?.id else {
            await MainActor.run {
                totalFileCount = 0
                spaceCount = spaces.count
                syncStatus = .synced
            }
            return
        }
        
        // Count local files for all users
        do {
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            let filesBySpace = Dictionary(grouping: localFiles) { $0.spaceId }

            var updatedSpaces = spaces
            for (index, space) in updatedSpaces.enumerated() {
                updatedSpaces[index] = Space(
                    id: space.id,
                    userId: space.userId,
                    name: space.name,
                    icon: space.icon,
                    color: space.color,
                    isLocked: space.isLocked,
                    orderIndex: space.orderIndex,
                    createdAt: space.createdAt,
                    fileCount: filesBySpace[space.id]?.count ?? 0
                )
            }
            await MainActor.run {
                spaces = updatedSpaces
                totalFileCount = localFiles.count
                spaceCount = updatedSpaces.count
            }
            saveSpacesToLocalStorage(spaces: updatedSpaces, userId: userId)
        } catch {
            print("Failed to count local files: \(error.localizedDescription)")
        }

        // For cloud users: compute sync status from LOCAL files (so pending/syncing reflects reality).
        // We already have spaces and totalFileCount from local files above; do not overwrite with DynamoDB.
        guard let user = user, user.hasCloudBackup else {
            await MainActor.run {
                syncStatus = .synced
                hasPendingSync = false
            }
            return
        }
        
        do {
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            let hasPending = localFiles.contains { $0.syncStatus == .pending }
            let hasSyncing = localFiles.contains { $0.syncStatus == .syncing }
            let hasError = localFiles.contains { $0.syncStatus == .error }
            let hasCloudEligible = localFiles.contains { f in
                switch f.syncStatus {
                case .synced, .syncing, .pending, .error: return true
                case .localOnly: return false
                }
            }
            
            let newSyncStatus: SyncStatus
            if hasError {
                newSyncStatus = .error
            } else if hasSyncing {
                newSyncStatus = .syncing
            } else if hasPending {
                newSyncStatus = .pending
            } else if !hasCloudEligible {
                newSyncStatus = .localOnly
            } else {
                newSyncStatus = .synced
            }
            
            await MainActor.run {
                syncStatus = newSyncStatus
                hasPendingSync = hasPending || hasError
            }
        } catch {
            print("Failed to calculate stats: \(error.localizedDescription)")
            await MainActor.run {
                syncStatus = .synced
                hasPendingSync = false
            }
        }
    }
    
    func enterOrganizeMode() {
        guard vaultMode != .locked else { return }
        vaultMode = .organize
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func exitOrganizeMode() {
        if vaultMode == .organize {
            vaultMode = .browse
        }
    }
    
    func enterFocusMode(spaceId: String) {
        guard vaultMode != .locked else { return }
        vaultMode = .focus(spaceId: spaceId)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-exit after 30 seconds of inactivity
        startFocusModeTimer()
    }
    
    @MainActor
    func exitFocusMode() {
        if vaultMode.isFocusMode {
            vaultMode = .browse
            stopFocusModeTimer()
        }
    }
    
    private func startFocusModeTimer() {
        stopFocusModeTimer()
        focusModeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
            self?.exitFocusMode()
            }
        }
    }
    
    private func stopFocusModeTimer() {
        focusModeTimer?.invalidate()
        focusModeTimer = nil
    }
    
    func lockVault() {
        updateAllSpacesLockState(isLocked: true)
        vaultMode = .locked
        stopFocusModeTimer()
    }
    
    func toggleVaultLockState() {
        let shouldUnlockAll = !spaces.isEmpty && spaces.allSatisfy(\.isLocked)
        
        if shouldUnlockAll {
            updateAllSpacesLockState(isLocked: false)
            vaultMode = .browse
        } else {
            lockVault()
        }
    }
    
    func unlockVault() async {
        guard vaultMode == .locked else { return }
        
        if !AppPreferences.faceIDEnabled {
            await MainActor.run {
                updateAllSpacesLockState(isLocked: false)
                vaultMode = .browse
            }
            return
        }
        
        // Check if biometrics are available
        var error: NSError?
        guard authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available - fallback to device passcode
            if authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                do {
                    let success = try await authContext.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: "Unlock \(AppConfig.appName) to access your encrypted files"
                    )
                    if success {
                        await MainActor.run {
                            vaultMode = .browse
                        }
                    }
                } catch {
                    // User cancelled or authentication failed
                    print("Authentication failed: \(error.localizedDescription)")
                }
            }
            return
        }
        
        // Evaluate biometric authentication
        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock \(AppConfig.appName) to access your encrypted files"
            )
            
            if success {
                await MainActor.run {
                    updateAllSpacesLockState(isLocked: false)
                    vaultMode = .browse
                    
                    // Haptic feedback on successful unlock
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        } catch {
            // Handle authentication errors
            let nsError = error as NSError
            if nsError.domain == LAError.errorDomain,
               let code = LAError.Code(rawValue: nsError.code) {
                switch code {
                case .userCancel:
                    // User cancelled - keep locked
                    break
                case .userFallback:
                    // User chose fallback - could show passcode option
                    break
                case .biometryNotAvailable:
                    // Biometrics not available - could fallback to passcode
                    print("Biometrics not available")
                case .biometryNotEnrolled:
                    // No biometrics enrolled - could fallback to passcode
                    print("Biometrics not enrolled")
                default:
                    print("Authentication error: \(nsError.localizedDescription)")
                }
            } else {
                print("Authentication error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if user can create more spaces
    func canCreateSpace() -> Bool {
        // Developer mode: always allow
        if DeveloperMode.isEnabled {
            return true
        }
        
        guard let user = user else { return false }

        return spaces.count < user.effectiveTier.maxSpaces
    }
    
    func createSpace(name: String, icon: String, color: String, orderIndex: Int? = nil) {
        guard let userId = user?.id else { return }
        
        // Check space limit BEFORE creating
        guard canCreateSpace() else {
            showUpgradePrompt = true
            return
        }
        
        let newSpace = Space.create(
            userId: userId,
            name: name,
            icon: icon,
            color: color,
            orderIndex: orderIndex ?? nextAvailableOrderIndex()
        )
        
        // Add to local array immediately
        spaces.append(newSpace)
        calculateStats()
        
        // Save to local storage immediately
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        UserDefaults.standard.synchronize()  // Force immediate write
        
        // Save to DynamoDB asynchronously (don't block UI)
        Task {
            do {
                // Only save to DynamoDB if user has cloud backup
                if let user = user, user.hasCloudBackup {
                try await DynamoDBService.shared.saveSpace(newSpace)
                }
            } catch {
                print("Failed to save space to DynamoDB: \(error.localizedDescription)")
                // Space is still saved locally, so user can continue
            }
        }
    }

    private func nextAvailableOrderIndex() -> Int {
        let used = Set(spaces.map(\.orderIndex))
        var candidate = 0
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }
    
    func createSpaceFromDefault(_ space: Space) {
        spaces.append(space)
        calculateStats()
        if let userId = user?.id {
            saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        }
        Task {
            if let user = user, user.hasCloudBackup {
                try? await DynamoDBService.shared.saveSpace(space)
            }
        }
    }

    /// Save all data before app closes
    func saveAllData() {
        guard let userId = user?.id else { return }
        
        // Save spaces to local storage
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        // Save user to local storage (via AuthenticationService)
        if let user = user, let authService = authService {
            Task {
                try? await authService.saveUserToLocalStorage(user)
            }
        }
        
        // Force synchronize UserDefaults
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Space Management
    
    func updateSpace(_ space: Space, name: String? = nil, icon: String? = nil, color: String? = nil) {
        guard let userId = user?.id,
              let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        
        let updatedSpace = Space(
            id: space.id,
            userId: space.userId,
            name: name ?? space.name,
            icon: icon ?? space.icon,
            color: color ?? space.color,
            isLocked: space.isLocked,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            fileCount: space.fileCount
        )
        
        spaces[index] = updatedSpace
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        // Save to DynamoDB if user has cloud backup
        if let user = user, user.hasCloudBackup {
            Task {
                try? await DynamoDBService.shared.saveSpace(updatedSpace)
            }
        }
    }
    
    func lockSpace(_ space: Space) {
        guard let userId = user?.id,
              let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        
        let updatedSpace = Space(
            id: space.id,
            userId: space.userId,
            name: space.name,
            icon: space.icon,
            color: space.color,
            isLocked: true,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            fileCount: space.fileCount
        )
        
        spaces[index] = updatedSpace
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        if let user = user, user.hasCloudBackup {
            Task {
                try? await DynamoDBService.shared.saveSpace(updatedSpace)
            }
        }
    }
    
    func unlockSpace(_ space: Space) {
        guard let userId = user?.id,
              let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        
        let updatedSpace = Space(
            id: space.id,
            userId: space.userId,
            name: space.name,
            icon: space.icon,
            color: space.color,
            isLocked: false,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            fileCount: space.fileCount
        )
        
        spaces[index] = updatedSpace
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        if let user = user, user.hasCloudBackup {
            Task {
                try? await DynamoDBService.shared.saveSpace(updatedSpace)
            }
        }
    }
    
    private func updateAllSpacesLockState(isLocked: Bool) {
        guard let userId = user?.id else { return }
        
        let updatedSpaces = spaces.map { space in
            Space(
                id: space.id,
                userId: space.userId,
                name: space.name,
                icon: space.icon,
                color: space.color,
                isLocked: isLocked,
                orderIndex: space.orderIndex,
                createdAt: space.createdAt,
                fileCount: space.fileCount
            )
        }
        
        spaces = updatedSpaces
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        if let user = user, user.hasCloudBackup {
            Task {
                for space in updatedSpaces {
                    try? await DynamoDBService.shared.saveSpace(space)
                }
            }
        }
    }
    
    /// Move all files from one space to another (local + DynamoDB), then caller can delete the source space.
    func moveAllFiles(from sourceSpace: Space, to targetSpace: Space) async throws {
        guard let userId = user?.id, sourceSpace.id != targetSpace.id else { return }
        let files = try LocalFileMetadataService.shared.loadFilesForSpace(userId: userId, spaceId: sourceSpace.id)
        for file in files {
            let updatedFile = file.with(spaceId: targetSpace.id)
            try LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: userId, oldSpaceId: sourceSpace.id)
            if user?.hasCloudBackup == true {
                try await DynamoDBService.shared.saveFileMetadata(updatedFile)
            }
        }
        NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
        await loadSpacesAsync()
        await calculateStatsAsync()
    }

    func deleteSpace(_ space: Space) async throws {
        guard let userId = user?.id,
              let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }

        // Delete every file in this space (local + cloud) so All Files and counts stay correct
        let filesInSpace = (try? LocalFileMetadataService.shared.loadFilesForSpace(userId: userId, spaceId: space.id)) ?? []
        let localStorage = LocalStorageService()
        for file in filesInSpace {
            try? localStorage.deleteEncryptedFile(fileId: file.id)
            try? localStorage.deleteEncryptedFile(fileId: "\(file.id)_thumb")
            LocalFileMetadataService.shared.deleteFileMetadata(fileId: file.id, userId: file.userId, spaceId: file.spaceId)
            try? await DynamoDBService.shared.deleteFileMetadata(userId: file.userId, fileId: file.id)
            try? await S3Service.shared.deleteFile(key: file.s3Key)
            if let thumbKey = file.thumbnailS3Key { try? await S3Service.shared.deleteFile(key: thumbKey) }
        }
        try? await SyncService.shared.reconcileCloudStateNow(lastSyncAt: Date())

        // Remove space from local array and storage
        spaces.remove(at: index)
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)

        // Delete space from DynamoDB if user has cloud backup
        if let user = user, user.hasCloudBackup {
            try await DynamoDBService.shared.deleteSpace(userId: userId, spaceId: space.id)
        }

        NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
        await loadSpacesAsync()
        calculateStats()
    }
}

#Preview {
    VaultHomeView()
}

