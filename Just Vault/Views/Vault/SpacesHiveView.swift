//
//  SpacesHiveView.swift
//  Just Vault
//
//  Hexagon hive view with pagination and ghost slots
//

import SwiftUI

struct SpacesHiveView: View {
    let allSpaces: [Space]
    @Binding var vaultMode: VaultMode
    let isPro: Bool
    let allowsAdditionalPages: Bool
    let syncStatus: SyncStatus
    /// Scales ring positions (default 1). Use >1 on iPad so hexes aren’t cramped.
    var hiveLayoutScale: CGFloat = 1
    var spaceHexSide: CGFloat = 120
    var centerHubHexSide: CGFloat = 120
    let onSpaceTap: (Space) -> Void
    let onSpaceLongPress: (Space) -> Void
    let onSpaceEdit: (Space) -> Void
    let onSpaceLock: (Space) -> Void
    let onSpaceUnlock: (Space) -> Void
    let onSpaceDelete: (Space) -> Void
    let onGhostTap: (Int) -> Void
    let onLockAll: () -> Void
    let onSyncNow: () -> Void
    
    @Binding var showSearch: Bool

    @EnvironmentObject private var authService: AuthenticationService
    
    @State private var currentPage: Int = 0
    @State private var hexPositions: [String: CGPoint] = [:]
    @State private var showSettings = false
    @State private var showUpgrade = false
    
    // Group spaces into pages of 6 using stable orderIndex ranges.
    var pages: [[Space]] {
        let grouped = Dictionary(grouping: allSpaces) { max(0, $0.orderIndex / 6) }
        let maxExistingPage = grouped.keys.max() ?? 0
        let basePageCount = max(maxExistingPage + 1, 1)
        let shouldAppendEmptyPage = allowsAdditionalPages && (grouped[maxExistingPage]?.count ?? 0) == 6
        let totalPages = shouldAppendEmptyPage ? basePageCount + 1 : basePageCount

        return (0..<totalPages).map { pageIndex in
            (grouped[pageIndex] ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }
    }
    
    // Current page spaces
    var currentPageSpaces: [Space] {
        guard currentPage < pages.count else { return [] }
        return pages[currentPage]
    }
    
    // Ghost slots for current page
    private var layoutHexUnit: CGFloat { 90 * hiveLayoutScale }

    var ghostSlots: Int {
        let filled = currentPageSpaces.count
        let maxSlots = 6
        let available = max(0, maxSlots - filled)
        
        // Free users only see ghost slots on the first page.
        if !allowsAdditionalPages {
            if currentPage == 0 { return available }
            return 0
        }
        
        return available
    }
    
    // Calculate ghost slots for a specific page
    private func ghostSlotsForPage(_ pageIndex: Int) -> Int {
        let pageSpaces = pageIndex < pages.count ? pages[pageIndex] : []
        let pageFilled = pageSpaces.count
        
        if pageIndex == currentPage {
            return ghostSlots
        } else if allowsAdditionalPages {
            return max(0, 6 - pageFilled)
        } else {
            return (pageIndex == 0) ? max(0, 6 - pageFilled) : 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2 + (pages.count > 1 ? 6 : 2)
            )
            
            ZStack {
                // Center Hub (ALWAYS visible, fixed position)
                CenterHubHexagon(
                    showSettings: $showSettings,
                    showSearch: $showSearch,
                    showUpgrade: $showUpgrade,
                    isPro: isPro,
                    allSpacesLocked: !allSpaces.isEmpty && allSpaces.allSatisfy(\.isLocked),
                    syncStatus: syncStatus,
                    totalFiles: allSpaces.reduce(0) { $0 + $1.fileCount },
                    onToggleLockAll: onLockAll,
                    onSyncNow: onSyncNow
                )
                .position(center)
                .zIndex(100)
                
                // Most users only have the fixed 6 spaces, so keep this static
                // to avoid the page view causing layout jitter/bounce.
                if pages.count <= 1 {
                    HivePageView(
                        spaces: currentPageSpaces,
                        ghostSlots: ghostSlots,
                        center: center,
                        hexPositions: hexPositions,
                        layoutHexUnit: layoutHexUnit,
                        spaceHexSide: spaceHexSide,
                        onSpaceTap: onSpaceTap,
                        onSpaceLongPress: onSpaceLongPress,
                        onSpaceEdit: onSpaceEdit,
                        onSpaceLock: onSpaceLock,
                        onSpaceUnlock: onSpaceUnlock,
                        onSpaceDelete: onSpaceDelete,
                        onGhostTap: { slotIndex in
                            onGhostTap(slotIndex)
                        }
                    )
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(0..<max(pages.count, 1), id: \.self) { pageIndex in
                            HivePageView(
                                spaces: pageIndex < pages.count ? pages[pageIndex] : [],
                                ghostSlots: ghostSlotsForPage(pageIndex),
                                center: center,
                                hexPositions: hexPositions,
                                layoutHexUnit: layoutHexUnit,
                                spaceHexSide: spaceHexSide,
                                onSpaceTap: onSpaceTap,
                                onSpaceLongPress: onSpaceLongPress,
                                onSpaceEdit: onSpaceEdit,
                                onSpaceLock: onSpaceLock,
                                onSpaceUnlock: onSpaceUnlock,
                                onSpaceDelete: onSpaceDelete,
                                onGhostTap: { slotIndex in
                                    onGhostTap(pageIndex * 6 + slotIndex)
                                }
                            )
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .padding(.bottom, 8)
                }
            }
            .onAppear {
                assignHexPositions()
            }
            .onChange(of: allSpaces) { oldSpaces, newSpaces in
                if currentPage >= pages.count {
                    currentPage = max(0, pages.count - 1)
                }
                assignHexPositions()
            }
            .onChange(of: currentPage) { _, _ in
                assignHexPositions()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showUpgrade) {
                PaywallView()
                    .environmentObject(authService)
            }
        }
    }
    
    // Assign positions using the space's stable orderIndex so that
    // deleting one space never causes the others to jump positions.
    private func assignHexPositions() {
        var positions: [String: CGPoint] = [:]
        let ringPositions = Self.honeycombOffsets(hexSize: layoutHexUnit)
        
        for space in currentPageSpaces {
            let slot = space.orderIndex % ringPositions.count
            positions[space.id] = ringPositions[slot]
        }
        
        hexPositions = positions
    }
    
    static func honeycombOffsets(hexSize: CGFloat) -> [CGPoint] {
        let vertical = hexSize * 1.52
        let diagonalX = hexSize * 1.28
        let diagonalY = hexSize * 0.78
        
        return [
            CGPoint(x: 0, y: -vertical),             // Top
            CGPoint(x: diagonalX, y: -diagonalY),    // Top-right
            CGPoint(x: diagonalX, y: diagonalY),     // Bottom-right
            CGPoint(x: 0, y: vertical),              // Bottom
            CGPoint(x: -diagonalX, y: diagonalY),    // Bottom-left
            CGPoint(x: -diagonalX, y: -diagonalY)    // Top-left
        ]
    }
}

struct HivePageView: View {
    let spaces: [Space]
    let ghostSlots: Int
    let center: CGPoint
    let hexPositions: [String: CGPoint]
    let layoutHexUnit: CGFloat
    let spaceHexSide: CGFloat
    let onSpaceTap: (Space) -> Void
    let onSpaceLongPress: (Space) -> Void
    let onSpaceEdit: (Space) -> Void
    let onSpaceLock: (Space) -> Void
    let onSpaceUnlock: (Space) -> Void
    let onSpaceDelete: (Space) -> Void
    let onGhostTap: (Int) -> Void
    
    private var ringPositions: [CGPoint] {
        SpacesHiveView.honeycombOffsets(hexSize: layoutHexUnit)
    }
    
    // Which orderIndex values are occupied by real spaces
    private var occupiedSlots: Set<Int> {
        Set(spaces.map { $0.orderIndex % ringPositions.count })
    }
    
    // Vacant ring slots (sorted) for ghost hexagons
    private var vacantSlots: [Int] {
        (0..<ringPositions.count).filter { !occupiedSlots.contains($0) }
    }
    
    var body: some View {
        ZStack {
            // Filled space hexagons -- positioned by their stable orderIndex
            ForEach(spaces) { space in
                if let point = hexPositions[space.id] {
                    SpaceHexagonView(
                        space: space,
                        hexSide: spaceHexSide,
                        isSelected: false,
                        onTap: { onSpaceTap(space) },
                        onLongPress: { onSpaceLongPress(space) },
                        onEdit: { onSpaceEdit(space) },
                        onLock: { onSpaceLock(space) },
                        onUnlock: { onSpaceUnlock(space) },
                        onDelete: { onSpaceDelete(space) }
                    )
                    .position(x: center.x + point.x, y: center.y + point.y)
                    .zIndex(10)
                }
            }
            
            // Ghost slots placed in vacant ring positions
            ForEach(vacantSlots.prefix(ghostSlots), id: \.self) { slotIndex in
                GhostHexagonView(hexSide: spaceHexSide, onTap: { onGhostTap(slotIndex) })
                    .position(
                        x: center.x + ringPositions[slotIndex].x,
                        y: center.y + ringPositions[slotIndex].y
                    )
                    .zIndex(1)
            }
        }
    }
}

// Helper extension to chunk array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

