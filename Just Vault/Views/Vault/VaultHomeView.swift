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
    @StateObject private var viewModel: VaultHomeViewModel
    @State private var showFocusInfo = false
    @State private var selectedTab = 0
    @State private var selectedSpace: Space?
    @State private var showSpaceDetail = false
    @State private var showCreateSpace = false
    @State private var showPaywall = false
    @State private var showAddFileSpaceSelector = false
    @State private var selectedSpaceForFile: Space?
    @State private var showFilePickerOptions = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var spaceToEdit: Space?
    @State private var showEditSpace = false
    @State private var spaceToDelete: Space?
    @State private var showDeleteConfirmation = false
    @State private var showSearch = false
    
    init() {
        // Initialize with placeholder - will be set in onAppear
        _viewModel = StateObject(wrappedValue: VaultHomeViewModel())
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                ZStack {
                    // Background - royal/wine purple gradient
                    LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.08, blue: 0.42),   // Wine/royal purple
                            Color(red: 0.38, green: 0.1, blue: 0.48),
                            Color(red: 0.28, green: 0.06, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header - fixed height so layout doesn't bounce
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let userName = viewModel.user?.name?.components(separatedBy: " ").first {
                                    Text("Hi, \(userName)")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                HStack(spacing: 8) {
                                    Text("My Vault")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    if let user = viewModel.user {
                                        Text(user.isPro ? "Pro" : "Free")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(user.isPro ? Color(red: 0.45, green: 0.15, blue: 0.55) : Color.gray.opacity(0.6))
                                            )
                                    }
                                }
                            }
                            .frame(height: 52)
                            .padding(.top, 8)
                            
                            Spacer()
                            
                            Button(action: { showAddFileSpaceSelector = true }) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        
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
                        }
                        
                        // Storage Meter (only for Pro/Cloud users)
                        if let user = viewModel.user, user.isPro {
                            StorageMeterView(
                                usedMB: user.cloudStorageUsedMB,
                                quotaMB: user.cloudStorageQuotaMB,
                                isPro: true
                            )
                            .padding(.horizontal)
                        }
                        
                        // Hexagon Hive View
                        SpacesHiveView(
                            allSpaces: viewModel.spaces,
                            vaultMode: $viewModel.vaultMode,
                            isPro: viewModel.user?.isPro ?? false,
                            syncStatus: viewModel.syncStatus,
                            onSpaceTap: { space in
                                // Regular tap: always open space (preview/thumbnails)
                                selectedSpace = space
                                showSpaceDetail = true
                            },
                            onSpaceLongPress: { space in
                                // Long press: shortcut to add file to this space
                                selectedSpaceForFile = space
                                showFilePickerOptions = true
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
                            onGhostTap: {
                                // Ghost slots disabled - only 6 pre-defined spaces
                                // User can still add files to existing spaces
                            },
                            onLockAll: {
                                viewModel.lockVault()
                            },
                            onSyncNow: {
                                Task {
                                    await SyncService.shared.processSyncQueue()
                                }
                            }
                        )
                        .frame(height: UIScreen.main.bounds.height - 500) // Reduced height to make room for file preview
                        
                        // Recent Files Preview (like JustScan)
                        if !viewModel.recentFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Files")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button("See All") {
                                        selectedTab = 1 // Switch to Files tab
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
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
                            .padding(.vertical, 16)
                        }
                        
                        // Cloud Backup Bar (persistent at bottom)
                        CloudBackupBar(
                            isPro: viewModel.user?.isPro ?? false,
                            usedMB: viewModel.user?.cloudStorageUsedMB ?? 0,
                            quotaMB: viewModel.user?.cloudStorageQuotaMB ?? 250,
                            onBackup: {
                                if viewModel.user?.isPro ?? false {
                                    Task {
                                        await SyncService.shared.processSyncQueue()
                                    }
                                } else {
                                    showPaywall = true
                                }
                            }
                        )
                        .padding(.bottom, 10)
                    }
                }
                .sheet(isPresented: $showFocusInfo) {
                    FocusModeInfoSheet()
                }
                .popover(isPresented: $showCreateSpace) {
                    CreateSpacePopupView(onCreate: { name, icon, color in
                        viewModel.createSpace(name: name, icon: icon, color: color)
                        showCreateSpace = false
                    })
                }
                .sheet(item: $selectedSpace) { space in
                    SpaceDetailView(space: space)
                }
                .alert("Space Limit Reached", isPresented: $viewModel.showUpgradePrompt) {
                    Button("Upgrade to Pro") {
                        showPaywall = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Free tier allows \(AppConfig.freeTierMaxSpaces) spaces. Upgrade to Pro for \(AppConfig.proTierMaxSpaces) spaces.")
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
                .sheet(isPresented: $showSearch) {
                    SearchView(spaces: viewModel.spaces)
                        .environmentObject(authService)
                }
                .sheet(item: $spaceToEdit) { space in
                    EditSpaceView(space: space) { name, icon, color in
                        viewModel.updateSpace(space, name: name, icon: icon, color: color)
                        spaceToEdit = nil
                    }
                }
                .alert("Delete Space", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let space = spaceToDelete {
                            Task {
                                do {
                                    // Require Face ID before deletion
                                    let context = LAContext()
                                    var error: NSError?
                                    
                                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                                        let success = try await context.evaluatePolicy(
                                            .deviceOwnerAuthenticationWithBiometrics,
                                            localizedReason: "Confirm deletion of space"
                                        )
                                        
                                        if success {
                                            try await viewModel.deleteSpace(space)
                                            spaceToDelete = nil
                                        }
                                    } else {
                                        // Fallback to device passcode
                                        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                                            let success = try await context.evaluatePolicy(
                                                .deviceOwnerAuthentication,
                                                localizedReason: "Confirm deletion of space"
                                            )
                                            
                                            if success {
                                                try await viewModel.deleteSpace(space)
                                                spaceToDelete = nil
                                            }
                                        }
                                    }
                                } catch {
                                    print("Failed to delete space: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        spaceToDelete = nil
                    }
                } message: {
                    if let space = spaceToDelete {
                        Text("Are you sure you want to delete '\(space.name)'? This action cannot be undone.")
                    }
                }
                .sheet(isPresented: $showAddFileSpaceSelector) {
                    AddFileSpaceSelectorView(
                        spaces: viewModel.spaces,
                        onSpaceSelected: { space in
                            selectedSpaceForFile = space
                            showAddFileSpaceSelector = false
                            // Auto-trigger file picker after space selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showFilePickerOptions = true
                            }
                        }
                    )
                }
                .confirmationDialog(
                    "Add File to \(selectedSpaceForFile?.name ?? "Space")",
                    isPresented: $showFilePickerOptions,
                    titleVisibility: .visible
                ) {
                    Button("Files") {
                        showDocumentPicker = true
                    }
                    Button("Photos") {
                        imagePickerSource = .photoLibrary
                        showImagePicker = true
                    }
                    Button("Camera") {
                        imagePickerSource = .camera
                        showImagePicker = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(isPresented: $showDocumentPicker) {
                    if let space = selectedSpaceForFile {
                        DocumentPicker(
                            allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                            onDocumentPicked: { url in
                                Task {
                                    await importFileToSpace(url: url, space: space)
                                }
                            }
                        )
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    if let space = selectedSpaceForFile {
                        ImagePicker(
                            sourceType: imagePickerSource,
                            onImagePicked: { image in
                                Task {
                                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                                        let tempURL = FileManager.default.temporaryDirectory
                                            .appendingPathComponent("\(UUID().uuidString).jpg")
                                        try? imageData.write(to: tempURL)
                                        await importFileToSpace(url: tempURL, space: space)
                                    }
                                }
                            }
                        )
                    }
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
                    }
                }
                .onChange(of: viewModel.user) { oldUser, newUser in
                    if newUser != nil {
                        Task {
                            await viewModel.loadRecentFiles()
                        }
                    }
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
        .tint(.white)
    }
    
    // MARK: - File Import Helper
    
    private func importFileToSpace(url: URL, space: Space) async {
        let vm = viewModel
        
        do {
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
                try? await DynamoDBService.shared.saveFileMetadata(vaultFile)
                SyncService.shared.queueFileForSync(vaultFile)
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
                        .fill(Color.gray.opacity(0.15))
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
                .foregroundColor(.blue)
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
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
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
                .foregroundColor(.blue)
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
                Color.gray.opacity(0.3),
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
                .foregroundColor(.white)
            Text(focusedSpace.name)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
        } else {
            Image(systemName: iconForMode(vaultMode))
                .font(.system(size: 28))
                .foregroundColor(.white)
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
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .organize:
            return LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .focus:
            return LinearGradient(
                colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked:
            return LinearGradient(
                colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.5)],
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
            return .green
        case .syncing:
            return .blue
        case .pending:
            return .orange
        case .error:
            return .red
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
                .fill(Color.gray.opacity(0.1))
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    
                    // File count badge (if has files)
                    if space.fileCount > 0 {
                        Text("\(space.fileCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
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
    
    func loadRecentFiles() async {
        guard let userId = user?.id else {
            recentFiles = []
            return
        }
        
        do {
            // Load files from local storage (works for all users)
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            
            // If user has cloud backup, also load from DynamoDB
            var allFiles = localFiles
            if let user = user, user.hasCloudBackup {
                let cloudFiles = try await DynamoDBService.shared.loadAllFiles(userId: userId)
                // Merge, avoiding duplicates
                let localIds = Set(localFiles.map { $0.id })
                let newFiles = cloudFiles.filter { !localIds.contains($0.id) }
                allFiles.append(contentsOf: newFiles)
            }
            
            // Sort by most recent and take first 6
            let sorted = allFiles.sorted { $0.createdAt > $1.createdAt }
            await MainActor.run {
                recentFiles = Array(sorted.prefix(6))
            }
        } catch {
            print("Failed to load recent files: \(error.localizedDescription)")
            await MainActor.run {
                recentFiles = []
            }
        }
    }
    
    func refreshSpaces() {
        Task {
            await loadSpacesAsync()
        }
    }
    
    private func loadSpaces() {
        Task {
            await loadSpacesAsync()
        }
    }
    
    private func loadSpacesAsync() async {
        // Use placeholder if user not loaded yet (for first launch)
        var userId = user?.id ?? "placeholder"
        
        // First, load from UserDefaults (fast, offline)
        var localSpaces = loadSpacesFromLocalStorage(userId: userId)
        
        // If no spaces exist, create default spaces (first launch)
        if DefaultSpacesService.shared.shouldCreateDefaults(existingSpaces: localSpaces) {
            let defaultSpaces = DefaultSpacesService.shared.createDefaultSpaces(userId: userId)
            localSpaces = defaultSpaces
            
            // Save defaults immediately
            saveSpacesToLocalStorage(spaces: defaultSpaces, userId: userId)
            UserDefaults.standard.synchronize()
            
            // Save to DynamoDB if user has cloud backup
            if let user = user, user.hasCloudBackup {
                for space in defaultSpaces {
                    try? await DynamoDBService.shared.saveSpace(space)
                }
            }
        }
        
        // Set local spaces immediately for fast UI update
        await MainActor.run {
            spaces = localSpaces
        }
        
        // If user was placeholder but now loaded, reload with real user ID
        if userId == "placeholder", let realUserId = user?.id, realUserId != "placeholder" {
            // Reload with real user ID
            userId = realUserId
            localSpaces = loadSpacesFromLocalStorage(userId: userId)
            
            // If still no spaces, create defaults with real user ID
            if DefaultSpacesService.shared.shouldCreateDefaults(existingSpaces: localSpaces) {
                let defaultSpaces = DefaultSpacesService.shared.createDefaultSpaces(userId: userId)
                localSpaces = defaultSpaces
                saveSpacesToLocalStorage(spaces: defaultSpaces, userId: userId)
            }
            
            await MainActor.run {
                spaces = localSpaces
            }
        }
        
        // Then, sync from DynamoDB in background
        do {
            let dynamoDBSpaces = try await DynamoDBService.shared.loadSpaces(userId: userId)
            
            // Merge results (DynamoDB wins on conflict)
            var mergedSpaces = localSpaces
            for dynamoDBSpace in dynamoDBSpaces {
                if let index = mergedSpaces.firstIndex(where: { $0.id == dynamoDBSpace.id }) {
                    mergedSpaces[index] = dynamoDBSpace
                } else {
                    mergedSpaces.append(dynamoDBSpace)
                }
            }
            
            // Sort by orderIndex
            mergedSpaces.sort { $0.orderIndex < $1.orderIndex }
            
            // Update UI
            await MainActor.run {
                spaces = mergedSpaces
            }
            
            // Update local cache
            saveSpacesToLocalStorage(spaces: mergedSpaces, userId: userId)
        } catch {
            print("Failed to load spaces from DynamoDB: \(error.localizedDescription)")
            // Keep local spaces if DynamoDB fails
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
        if let data = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.synchronize()
        }
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
        
        // Only load from DynamoDB if user has cloud backup
        guard let user = user, user.hasCloudBackup else {
            // Free user - calculate stats from local files only
            // TODO: Implement local file counting for free users
            await MainActor.run {
                totalFileCount = spaces.reduce(0) { $0 + $1.fileCount }
                spaceCount = spaces.count
                syncStatus = .synced
            }
            return
        }
        
        do {
            let allFiles = try await DynamoDBService.shared.loadAllFiles(userId: userId)
            
            // Group files by spaceId
            let filesBySpace = Dictionary(grouping: allFiles) { $0.spaceId }
            
            // Update space file counts
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
            
            // Calculate sync status
            let hasPending = allFiles.contains { $0.syncStatus == .pending }
            let hasSyncing = allFiles.contains { $0.syncStatus == .syncing }
            let hasError = allFiles.contains { $0.syncStatus == .error }
            
            let newSyncStatus: SyncStatus
            if hasError {
                newSyncStatus = .error
            } else if hasSyncing {
                newSyncStatus = .syncing
            } else if hasPending {
                newSyncStatus = .pending
            } else {
                newSyncStatus = .synced
            }
            
            await MainActor.run {
                spaces = updatedSpaces
                totalFileCount = allFiles.count
                spaceCount = spaces.count
                syncStatus = newSyncStatus
            }
        } catch {
            print("Failed to calculate stats: \(error.localizedDescription)")
            await MainActor.run {
                totalFileCount = spaces.reduce(0) { $0 + $1.fileCount }
                spaceCount = spaces.count
                syncStatus = .synced
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
        // Lock all spaces
        guard let userId = user?.id else { return }
        
        var updatedSpaces = spaces
        for (index, space) in updatedSpaces.enumerated() {
            updatedSpaces[index] = Space(
                id: space.id,
                userId: space.userId,
                name: space.name,
                icon: space.icon,
                color: space.color,
                isLocked: true,  // Lock all spaces
                orderIndex: space.orderIndex,
                createdAt: space.createdAt,
                fileCount: space.fileCount
            )
        }
        
        spaces = updatedSpaces
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        // Save to DynamoDB if user has cloud backup
        if let user = user, user.hasCloudBackup {
            Task {
                for space in updatedSpaces {
                    try? await DynamoDBService.shared.saveSpace(space)
                }
            }
        }
        
        vaultMode = .locked
        stopFocusModeTimer()
    }
    
    func unlockVault() async {
        guard vaultMode == .locked else { return }
        
        // Check if biometrics are available
        var error: NSError?
        guard authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available - fallback to device passcode
            if authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                do {
                    let success = try await authContext.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: "Unlock your vault"
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
                localizedReason: "Unlock your vault"
            )
            
            if success {
                await MainActor.run {
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
        
        // Check if user is on free trial (no pro features)
        if user.subscriptionStatus == .none && !user.isPro {
            return spaces.count < AppConfig.freeTierMaxSpaces
        }
        
        let maxSpaces = user.isPro ? AppConfig.proTierMaxSpaces : AppConfig.freeTierMaxSpaces
        
        return spaces.count < maxSpaces
    }
    
    func createSpace(name: String, icon: String, color: String) {
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
            orderIndex: spaces.count
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
    
    func deleteSpace(_ space: Space) async throws {
        guard let userId = user?.id,
              let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        
        // Remove from local array
        spaces.remove(at: index)
        saveSpacesToLocalStorage(spaces: spaces, userId: userId)
        
        // Delete from DynamoDB if user has cloud backup
        if let user = user, user.hasCloudBackup {
            try await DynamoDBService.shared.deleteSpace(userId: userId, spaceId: space.id)
        }
        
        // Recalculate stats
        calculateStats()
    }
}

#Preview {
    VaultHomeView()
}

