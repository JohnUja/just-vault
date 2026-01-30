//
//  VaultHomeView.swift
//  Just Vault
//
//  Main vault home screen with flower/petal layout
//

import SwiftUI

struct VaultHomeView: View {
    @StateObject private var viewModel = VaultHomeViewModel()
    
    var body: some View {
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
                        Button("+ Add Space") {
                            // TODO: Show create space modal
                        }
                        .font(.body)
                    }
                    .padding()
                    
                    // Storage Meter
                    StorageMeterView(
                        usedMB: viewModel.user?.cloudStorageUsedMB ?? 0,
                        quotaMB: viewModel.user?.cloudStorageQuotaMB ?? 250,
                        isPro: viewModel.user?.isPro ?? false
                    )
                    .padding(.horizontal)
                    
                    // Spaces (Flower/Petal Layout)
                    SpacesFlowerView(spaces: viewModel.spaces) {
                        // TODO: Show create space modal
                        viewModel.showCreateSpace = true
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Navigation
                    BottomNavigationView()
                }
            }
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

// Spaces Flower Layout - Radial/Petal Arrangement
struct SpacesFlowerView: View {
    let spaces: [Space]
    let onAddSpace: () -> Void
    
    // Flower layout parameters
    private let centerRadius: CGFloat = 60 // Vault Core size
    private let petalRadius: CGFloat = 80 // Space bubble size
    private let petalDistance: CGFloat = 140 // Distance from center to petal center
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Vault Core (Center)
                VaultCoreView()
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(center)
                
                // Space Petals (Around center)
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    let angle = angleForPetal(at: index, total: spaces.count)
                    let position = positionForPetal(center: center, angle: angle, distance: petalDistance)
                    
                    SpaceBubbleView(space: space)
                        .frame(width: petalRadius * 2, height: petalRadius * 2)
                        .position(position)
                }
                
                // Add Space Petal (if not at max)
                if spaces.count < 8 { // Max 8 petals for visual clarity
                    let addIndex = spaces.count
                    let angle = angleForPetal(at: addIndex, total: spaces.count + 1)
                    let position = positionForPetal(center: center, angle: angle, distance: petalDistance)
                    
                    Button(action: onAddSpace) {
                        AddSpacePetalView()
                            .frame(width: petalRadius * 2, height: petalRadius * 2)
                    }
                    .position(position)
                }
            }
        }
        .frame(height: 400) // Fixed height for flower layout
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

// Vault Core (Center of flower)
struct VaultCoreView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                Text("Vault")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}

// Add Space Petal (Dashed circle)
struct AddSpacePetalView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                        .foregroundColor(.gray.opacity(0.5))
                )
            
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                Text("Add")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Space Bubble Component
struct SpaceBubbleView: View {
    let space: Space
    
    var body: some View {
        Button {
            // TODO: Navigate to space detail
        } label: {
            VStack(spacing: 8) {
                Image(systemName: space.icon)
                    .font(.system(size: 40))
                Text(space.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 160, height: 160)
            .background(Color(hex: space.color))
            .foregroundColor(.white)
            .cornerRadius(80)
        }
    }
}

// Bottom Navigation
struct BottomNavigationView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        HStack {
            TabButton(icon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(icon: "doc.fill", label: "Files", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabButton(icon: "gearshape.fill", label: "Settings", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .frame(height: 60)
        .background(Color(uiColor: .systemBackground))
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
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

// ViewModel
@MainActor
class VaultHomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var spaces: [Space] = []
    @Published var showCreateSpace = false
    
    private let localStorage = LocalStorageService()
    
    init() {
        loadUser()
        loadSpaces()
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
}

#Preview {
    VaultHomeView()
}

