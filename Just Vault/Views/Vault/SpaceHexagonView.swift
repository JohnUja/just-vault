//
//  SpaceHexagonView.swift
//  Just Vault
//
//  Individual space hexagon with glow based on file count
//

import SwiftUI

struct SpaceHexagonView: View {
    let space: Space
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEdit: () -> Void
    let onLock: () -> Void
    let onUnlock: () -> Void
    let onDelete: () -> Void
    
    // Calculate glow intensity based on file count
    var glowIntensity: CGFloat {
        let maxFiles = 20.0
        return min(CGFloat(space.fileCount) / maxFiles, 1.0)
    }
    
    @State private var isLongPressing = false
    
    var body: some View {
        Button(action: {
            // Only trigger tap if not long pressing
            if !isLongPressing {
                onTap()
            }
        }) {
            ZStack {
                // Glow effect (brighter = more files)
                HexagonShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: space.color).opacity(0.3 + glowIntensity * 0.7),
                                Color(hex: space.color).opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 130, height: 130)
                    .blur(radius: 10 * glowIntensity)
                
                // Main hexagon - one black outline, subtle shadow
                HexagonShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: space.color).opacity(0.35),
                                Color(hex: space.color).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .overlay(
                        HexagonShape()
                            .stroke(Color.black.opacity(0.5), style: StrokeStyle(lineWidth: 2))
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Content: icon with space color on translucent/metallic background
                VStack(spacing: 6) {
                    ZStack {
                        // Translucent metallic icon background
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: space.icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(Color(hex: space.color))
                        
                        if shouldShowLockOverlay(for: space) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: space.color))
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                )
                                .offset(x: 14, y: 14)
                        }
                    }
                    
                    Text(space.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                // File count badge (top-right corner)
                if space.fileCount > 0 {
                    Text("\(space.fileCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .offset(x: 25, y: -25) // Top-right corner
                }
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    isLongPressing = true
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onLongPress()
                    // Reset after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isLongPressing = false
                    }
                }
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Space", systemImage: "pencil")
            }
            
            if space.isLocked {
                Button(action: onUnlock) {
                    Label("Unlock Space", systemImage: "lock.open")
                }
            } else {
                Button(action: onLock) {
                    Label("Lock Space", systemImage: "lock")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Space", systemImage: "trash")
            }
        }
    }
    
    /// Determine if space should show lock overlay badge
    /// Based on default spaces: Documents, Keys, Folders have lock overlays
    private func shouldShowLockOverlay(for space: Space) -> Bool {
        let spacesWithLock = ["Documents", "Keys", "Folders"]
        return spacesWithLock.contains(space.name)
    }
}



