//
//  CenterHubHexagon.swift
//  Just Vault
//
//  Center hub hexagon with master controls
//

import SwiftUI

struct CenterHubHexagon: View {
    @Binding var showSettings: Bool
    @Binding var showSearch: Bool
    @Binding var showUpgrade: Bool
    var hubHexSide: CGFloat = 120
    let isPro: Bool
    let allSpacesLocked: Bool
    let syncStatus: SyncStatus
    let totalFiles: Int
    let onToggleLockAll: () -> Void
    let onSyncNow: () -> Void
    
    @State private var pulseOpacity: CGFloat = 0.6

    private var s: CGFloat { hubHexSide / 120 }
    
    var body: some View {
        ZStack {
            // Outer soft glow
            HexagonShape()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.accent.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 75 * s
                    )
                )
                .frame(width: 150 * s, height: 150 * s)
                .blur(radius: 18 * s)
            
            // Main hex body
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.955, blue: 0.945),
                            Color(red: 0.92, green: 0.915, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: hubHexSide, height: hubHexSide)
                .overlay(
                    HexagonShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    HexagonShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.5),
                                    AppTheme.accent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5 * s)
                        )
                )
                .shadow(color: AppTheme.accent.opacity(0.15), radius: 12 * s, x: 0, y: 6 * s)
                .shadow(color: Color.black.opacity(0.06), radius: 4 * s, x: 0, y: 2 * s)
            
            // Content
            VStack(spacing: 6 * s) {
                VStack(spacing: 1) {
                    Text("\(totalFiles)")
                        .font(.system(size: 22 * s, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.headerTint)
                    
                    Text(totalFiles == 1 ? "file" : "files")
                        .font(.system(size: 10 * s, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                // Lock state pill
                Text(allSpacesLocked ? "all locked" : "vault open")
                    .font(.system(size: 9 * s, weight: .semibold))
                    .foregroundColor(allSpacesLocked ? .white : AppTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(allSpacesLocked ? AppTheme.accent : AppTheme.background.opacity(0.8))
                    )
                
                // Sync indicator
                HStack(spacing: 4 * s) {
                    Text(syncStatusText)
                        .font(.system(size: 9 * s, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Circle()
                        .fill(syncIndicatorColor)
                        .frame(width: 7 * s, height: 7 * s)
                        .shadow(color: syncIndicatorColor.opacity(0.6), radius: 3)
                        .opacity(pulseOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .contextMenu {
            Button(action: { showSearch = true }) {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            Button(action: onToggleLockAll) {
                Label(allSpacesLocked ? "Unlock All Vaults" : "Lock All Vaults",
                      systemImage: allSpacesLocked ? "lock.open.fill" : "lock.fill")
            }
            
            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape.fill")
            }
            
            Button(action: onSyncNow) {
                Label("Sync Now", systemImage: "arrow.clockwise")
            }
        }
    }
    
    private var syncStatusText: String {
        if !isPro { return "local only" }
        switch syncStatus {
        case .synced:  return "synced"
        case .syncing: return "syncing"
        case .pending: return "syncing"
        case .error:   return "not synced"
        case .localOnly: return "local only"
        }
    }
    
    private var syncIndicatorColor: Color {
        if !isPro { return AppTheme.secondaryText }
        switch syncStatus {
        case .synced:  return AppTheme.success
        case .syncing: return AppTheme.warning
        case .pending: return AppTheme.warning
        case .error:   return AppTheme.error
        case .localOnly: return AppTheme.secondaryText
        }
    }
}

struct HubButton: View {
    let icon: String
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppTheme.background.opacity(0.6)))
        }
    }
}
