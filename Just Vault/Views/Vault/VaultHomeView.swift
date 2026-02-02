//
//  VaultHomeView.swift
//  Just Vault
//
//  Main vault home screen with flower/petal layout
//

import SwiftUI
import UIKit

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
    @StateObject private var viewModel = VaultHomeViewModel()
    @State private var showFocusInfo = false
    @State private var selectedTab = 0
    @State private var selectedSpace: Space?
    @State private var showSpaceDetail = false
    @State private var showCreateSpace = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                ZStack {
                    // Background
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Vault")
                                .font(.largeTitle)
                                .bold()
                            Spacer()
                            
                            // Info button for focus mode
                            Button(action: { showFocusInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            
                            Button("+ Add Space") {
                                showCreateSpace = true
                            }
                            .font(.body)
                        }
                        .padding()
                        
                        // Focus Mode Banner
                        if viewModel.vaultMode.isFocusMode, let focusedSpace = viewModel.focusedSpace {
                            FocusModeBanner(
                                spaceName: focusedSpace.name,
                                onExit: { viewModel.exitFocusMode() }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Storage Meter
                        StorageMeterView(
                            usedMB: viewModel.user?.cloudStorageUsedMB ?? 0,
                            quotaMB: viewModel.user?.cloudStorageQuotaMB ?? 250,
                            isPro: viewModel.user?.isPro ?? false
                        )
                        .padding(.horizontal)
                        
                        // Spaces (Flower/Petal Layout)
                        SpacesFlowerView(
                            spaces: viewModel.spaces,
                            vaultMode: $viewModel.vaultMode,
                            syncStatus: viewModel.syncStatus,
                            onAddSpace: {
                                showCreateSpace = true
                            },
                            onSpaceTap: { space in
                                if viewModel.vaultMode.isFocusMode {
                                    // In focus mode, tapping another space exits focus
                                    viewModel.exitFocusMode()
                                } else {
                                    selectedSpace = space
                                    showSpaceDetail = true
                                }
                            },
                            onFocusSpace: { space in
                                viewModel.enterFocusMode(spaceId: space.id)
                            },
                            onShowFocusInfo: { showFocusInfo = true },
                            onOrganize: {
                                if viewModel.vaultMode == .organize {
                                    viewModel.exitOrganizeMode()
                                } else {
                                    viewModel.enterOrganizeMode()
                                }
                            }
                        )
                        .padding()
                        
                        Spacer()
                    }
                }
                .sheet(isPresented: $showFocusInfo) {
                    FocusModeInfoSheet()
                }
                .sheet(isPresented: $showCreateSpace) {
                    CreateSpaceView(onCreate: { name, icon, color in
                        viewModel.createSpace(name: name, icon: icon, color: color)
                        showCreateSpace = false
                    })
                }
                .sheet(item: $selectedSpace) { space in
                    SpaceDetailView(space: space)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    viewModel.lockVault()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    viewModel.unlockVault()
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            // Files Tab
            FilesView()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Used: \(Int(usedMB)) MB")
                    .font(.headline)
                Spacer()
                Text("Total: \(Int(quotaMB)) MB")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(usagePercent > 0.9 ? Color.red : Color.blue)
                        .frame(width: geometry.size.width * usagePercent, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            if !isPro {
                Button("Upgrade to Pro") {
                    // TODO: Show subscription screen
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
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
                // Stems connecting petals to center (drawn first, behind everything)
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    let angle = angleForPetal(at: index, total: spaces.count)
                    let petalPosition = positionForPetal(center: center, angle: angle, distance: layout.petalDistance)
                    
                    // Draw stem line from center to petal (organic curve)
                    Path { path in
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
                
                // Vault Core (Center) - TRUE CIRCLE
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
                
                // Space Petals (Around center)
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    let angle = angleForPetal(at: index, total: spaces.count)
                    let position = positionForPetal(center: center, angle: angle, distance: layout.petalDistance)
                    let isFocused = vaultMode.focusedSpaceId == space.id
                    let isDimmed = vaultMode.isFocusMode && !isFocused
                    
                    SpaceBubbleView(
                        space: space,
                        isFocused: isFocused,
                        isDimmed: isDimmed,
                        vaultMode: vaultMode,
                        bubbleSize: layout.petalRadius * 2, // Pass dynamic size
                        onTap: { onSpaceTap(space) },
                        onFocus: { onFocusSpace(space) },
                        onShowFocusInfo: onShowFocusInfo
                    )
                    .position(position)
                    .zIndex(isFocused ? 10 : 1)
                }
                
                // Add Space Petal (if not in focus mode)
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
        }
        .frame(height: 500) // Increased height for better flower layout
        .onChange(of: vaultMode) { oldValue, newMode in
            if newMode == .organize {
                // Start orbit animation
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    orbitAngle = 360
                }
            } else {
                orbitAngle = 0
            }
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
            // Base circle with mode-based gradient
            Circle()
                .fill(gradientForMode(vaultMode))
                .shadow(color: shadowColorForMode(vaultMode), radius: 10, x: 0, y: 5)
                .scaleEffect(pulseScale)
            
            // Orbit ring for organize mode
            if vaultMode == .organize {
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: vaultMode)
            }
            
            // Content (stats or focused space info)
            VStack(spacing: 4) {
                // Icon or space icon
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
                
                // Stats
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
                
                // Sync status dot
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 6, height: 6)
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
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
        )
        .contextMenu {
            VaultCoreContextMenu(vaultMode: vaultMode, onOrganize: onOrganize)
        }
        .onAppear {
            // Breathing glow animation for browse mode
            if vaultMode == .browse {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            }
        }
        .onChange(of: vaultMode) { oldValue, newMode in
            if newMode == .browse {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            } else if case .focus(let spaceId) = newMode {
                // Pulse for focus mode
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            } else {
                pulseScale = 1.0
            }
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
    let onTap: () -> Void
    let onFocus: () -> Void
    let onShowFocusInfo: () -> Void
    
    @State private var glowOpacity: Double = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
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
                    .frame(width: 140, height: 140)
                    .offset(x: 0, y: 4)
                    .blur(radius: 8)
                
                // Main circle with gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: space.color),
                                Color(hex: space.color).opacity(0.8),
                                Color(hex: space.color).opacity(0.6)
                            ],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
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
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.15 : (isFocused ? 1.05 : 1.0))
                    .shadow(
                        color: isDragging ? Color(hex: space.color).opacity(0.5) : Color.black.opacity(0.2),
                        radius: isDragging ? 20 : 10,
                        x: 0,
                        y: isDragging ? 8 : 4
                    )
                
                // Content
                VStack(spacing: 6) {
                    Image(systemName: space.icon)
                        .font(.system(size: 36, weight: .medium))
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
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                .offset(dragOffset)
            }
        }
        .opacity(isDimmed ? 0.25 : 1.0)
        .blur(radius: isDimmed ? 3 : 0)
        .gesture(
            // Drag gesture (only in organize mode)
            isOrganizeMode ? DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // TODO: Handle drop into center or reorder
                    // For now, snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            : nil
        )
        .simultaneousGesture(
            // Tap gesture (disabled in organize mode when dragging)
            !isDragging ? TapGesture()
                .onEnded {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onTap()
                }
            : nil
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFocused)
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
    
    private let localStorage = LocalStorageService()
    private var focusModeTimer: Timer?
    
    var focusedSpace: Space? {
        guard let spaceId = vaultMode.focusedSpaceId else { return nil }
        return spaces.first { $0.id == spaceId }
    }
    
    init() {
        loadUser()
        loadSpaces()
        calculateStats()
    }
    
    private func loadUser() {
        // TODO: Load from UserDefaults or Core Data
        // For now, create placeholder
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
    
    private func loadSpaces() {
        // TODO: Load from local storage or DynamoDB
        // For now, empty array
        spaces = []
    }
    
    func calculateStats() {
        totalFileCount = spaces.reduce(0) { $0 + $1.fileCount }
        spaceCount = spaces.count
        // TODO: Calculate actual sync status from files
        syncStatus = .synced
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
    
    func exitFocusMode() {
        if vaultMode.isFocusMode {
            vaultMode = .browse
            stopFocusModeTimer()
        }
    }
    
    private func startFocusModeTimer() {
        stopFocusModeTimer()
        focusModeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.exitFocusMode()
        }
    }
    
    private func stopFocusModeTimer() {
        focusModeTimer?.invalidate()
        focusModeTimer = nil
    }
    
    func lockVault() {
        vaultMode = .locked
        stopFocusModeTimer()
    }
    
    func unlockVault() {
        // TODO: Check Face ID
        // For now, just unlock
        if vaultMode == .locked {
            vaultMode = .browse
        }
    }
    
    func createSpace(name: String, icon: String, color: String) {
        let newSpace = Space.create(
            userId: user?.id ?? "placeholder",
            name: name,
            icon: icon,
            color: color,
            orderIndex: spaces.count
        )
        spaces.append(newSpace)
        calculateStats()
        
        // TODO: Save to local storage and DynamoDB
    }
}

#Preview {
    VaultHomeView()
}

