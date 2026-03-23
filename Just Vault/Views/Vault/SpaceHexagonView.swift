//
//  SpaceHexagonView.swift
//  Just Vault
//
//  Individual space hexagon with glow based on file count
//

import SwiftUI

struct SpaceHexagonView: View {
    let space: Space
    /// Default 120; increase on iPad so the hive matches the larger layout ring.
    var hexSide: CGFloat = 120
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEdit: () -> Void
    let onLock: () -> Void
    let onUnlock: () -> Void
    let onDelete: () -> Void
    
    var glowIntensity: CGFloat {
        let maxFiles = 20.0
        return min(CGFloat(space.fileCount) / maxFiles, 1.0)
    }
    
    private var spaceColor: Color {
        Color(hex: space.color)
    }
    
    @State private var suppressTap = false

    private var k: CGFloat { hexSide / 120 }
    
    var body: some View {
        ZStack {
            content
        }
        .contentShape(HexagonShape())
        .onTapGesture {
            guard !suppressTap else { return }
            onTap()
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    suppressTap = true
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        suppressTap = false
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
    
    private var content: some View {
        ZStack {
            // Soft glow behind hex (brighter = more files)
            HexagonShape()
                .fill(
                    RadialGradient(
                        colors: [
                            spaceColor.opacity(0.15 + glowIntensity * 0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 136, height: 136)
                .blur(radius: 12)
            
            // Hex body with 3D gradient fill
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            spaceColor.opacity(0.42),
                            spaceColor.opacity(0.22),
                            spaceColor.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: hexSide, height: hexSide)
                .overlay(
                    HexagonShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
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
                                    spaceColor.opacity(0.8),
                                    spaceColor.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5 * k)
                        )
                )
                .shadow(color: spaceColor.opacity(0.3), radius: 10 * k, x: 0, y: 6 * k)
                .shadow(color: Color.black.opacity(0.08), radius: 4 * k, x: 0, y: 2 * k)
            
            // Icon + label
            VStack(spacing: 5 * k) {
                Image(systemName: space.icon)
                    .font(.system(size: 26 * k, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: spaceColor.opacity(0.6), radius: 3, x: 0, y: 1)
                
                Text(space.name)
                    .font(.system(size: 11 * k, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
            }
            
            // Lock badge
            if space.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9 * k, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(spaceColor.opacity(0.7))
                            .shadow(color: spaceColor.opacity(0.4), radius: 2)
                    )
                    .offset(x: 30 * k, y: -30 * k)
            }
            
            // File count badge
            if space.fileCount > 0 {
                Text("\(space.fileCount)")
                    .font(.system(size: 9 * k, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(spaceColor.opacity(0.65))
                    )
                    .offset(x: -30 * k, y: -30 * k)
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
