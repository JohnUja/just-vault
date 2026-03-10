//
//  CenterHubHexagon.swift
//  Just Vault
//
//  Center hub hexagon with master controls
//

import SwiftUI

/// Central Vault Hub - The main control center for all vault operations
struct CenterHubHexagon: View {
    @Binding var showSettings: Bool
    @Binding var showSearch: Bool
    @Binding var showUpgrade: Bool
    let isPro: Bool
    let syncStatus: SyncStatus  // Sync status instead of boolean
    let totalFiles: Int  // Total file count
    let onLockAll: () -> Void
    let onSyncNow: () -> Void  // Sync now action
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow ring
            HexagonShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 15)
            
            // Main hexagon
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemGray5),
                            Color(uiColor: .systemGray6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    HexagonShape()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2)
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // Content - File count and sync status
            VStack(spacing: 8) {
                // File count
                if totalFiles > 0 {
                    VStack(spacing: 2) {
                        Text("\(totalFiles)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(totalFiles == 1 ? "file" : "files")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("0 files")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Sync status with indicator
                HStack(spacing: 6) {
                    // Status text (to the left of dot)
                    Text(syncStatusText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Sync indicator dot with pulse and glow (stationary, only opacity changes)
                    Circle()
                        .fill(syncIndicatorColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(syncIndicatorColor.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: syncIndicatorColor.opacity(0.8), radius: 4)
                        .opacity(pulseScale > 1.0 ? 1.0 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }
            }
        }
        .onAppear {
            // Start pulse animation (opacity only, not scale)
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.3
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
        )
        .contextMenu {
            Button(action: { showSearch = true }) {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            Button(action: onLockAll) {
                Label("Lock All Vaults", systemImage: "lock.fill")
            }
            
            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape.fill")
            }
            
            Button(action: onSyncNow) {
                Label("Sync Now", systemImage: "arrow.clockwise")
            }
        }
    }
    
    // Sync status text
    private var syncStatusText: String {
        if !isPro {
            return "not synced"
        }
        
        switch syncStatus {
        case .synced:
            return "synced"
        case .syncing:
            return "syncing"
        case .pending:
            return "syncing"
        case .error:
            return "not synced"
        }
    }
    
    // Sync indicator color based on status
    // Red if not backed up (error or no cloud), Yellow if syncing/pending, Green if synced
    private var syncIndicatorColor: Color {
        // If user is not Pro, they don't have cloud backup - show red
        if !isPro {
            return .red
        }
        
        switch syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .yellow
        case .pending:
            return .yellow
        case .error:
            return .red
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
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
        }
    }
}



