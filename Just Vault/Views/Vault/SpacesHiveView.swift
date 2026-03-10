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
    let syncStatus: SyncStatus
    let onSpaceTap: (Space) -> Void
    let onSpaceLongPress: (Space) -> Void
    let onSpaceEdit: (Space) -> Void
    let onSpaceLock: (Space) -> Void
    let onSpaceUnlock: (Space) -> Void
    let onSpaceDelete: (Space) -> Void
    let onGhostTap: () -> Void
    let onLockAll: () -> Void
    let onSyncNow: () -> Void
    
    @State private var currentPage: Int = 0
    @State private var hexPositions: [String: HexCoordinate] = [:]
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var showUpgrade = false
    
    // Chunk spaces into pages of 6
    var pages: [[Space]] {
        allSpaces.chunked(into: 6)
    }
    
    // Current page spaces
    var currentPageSpaces: [Space] {
        guard currentPage < pages.count else { return [] }
        return pages[currentPage]
    }
    
    // Ghost slots for current page
    var ghostSlots: Int {
        let filled = currentPageSpaces.count
        let maxSlots = 6
        let available = maxSlots - filled
        
        // Free users: Show all 6 ghost slots on first page, but limit creation to 3
        if !isPro {
            // Always show all 6 slots on first page for visual consistency
            if currentPage == 0 {
                return maxSlots - filled  // Show all available slots
            }
            return 0
        }
        
        // Pro users: always show 6 slots (filled + ghost) on every page
        // If current page is full (6 spaces), show all 6 ghost slots on next page
        if filled == maxSlots {
            // This page is full, next page should show 6 ghost slots
            return 0  // Current page has no ghost slots
        }
        
        // Show available slots on current page
        return available
    }
    
    // Calculate ghost slots for a specific page
    private func ghostSlotsForPage(_ pageIndex: Int) -> Int {
        let pageSpaces = pageIndex < pages.count ? pages[pageIndex] : []
        let pageFilled = pageSpaces.count
        
        if pageIndex == currentPage {
            return ghostSlots
        } else if isPro && pageFilled == 6 {
            // Full page - next page should show 6 ghost slots
            return 6
        } else if isPro {
            // Pro user on non-current page - show available slots
            return max(0, 6 - pageFilled)
        } else {
            // Free user - only show ghost slots on first page
            return (pageIndex == 0) ? max(0, 6 - pageFilled) : 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
            
            ZStack {
                // Center Hub (ALWAYS visible, fixed position)
                CenterHubHexagon(
                    showSettings: $showSettings,
                    showSearch: $showSearch,
                    showUpgrade: $showUpgrade,
                    isPro: isPro,
                    syncStatus: syncStatus,
                    totalFiles: allSpaces.reduce(0) { $0 + $1.fileCount },
                    onLockAll: onLockAll,
                    onSyncNow: onSyncNow
                )
                .position(center)
                .zIndex(100)
                
                // Paginated spaces
                TabView(selection: $currentPage) {
                    ForEach(0..<max(pages.count, 1), id: \.self) { pageIndex in
                        HivePageView(
                            spaces: pageIndex < pages.count ? pages[pageIndex] : [],
                            ghostSlots: ghostSlotsForPage(pageIndex),
                            center: center,
                            hexPositions: hexPositions,
                            onSpaceTap: onSpaceTap,
                            onSpaceLongPress: onSpaceLongPress,
                            onSpaceEdit: onSpaceEdit,
                            onSpaceLock: onSpaceLock,
                            onSpaceUnlock: onSpaceUnlock,
                            onSpaceDelete: onSpaceDelete,
                            onGhostTap: onGhostTap
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .onAppear {
                assignHexPositions()
            }
            .onChange(of: allSpaces) { oldSpaces, newSpaces in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    assignHexPositions()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showUpgrade) {
                PaywallView()
            }
        }
    }
    
    // Assign positions in ring around center
    // Hexagon has 6 sides: one at top, one at bottom, 2 at sides (left/right), and 2 at diagonal positions
    private func assignHexPositions() {
        var positions: [String: HexCoordinate] = [:]
        
        // Ring positions around center hexagon (6 spots)
        // Positioned to align with hexagon faces: top, bottom, left, right, and two diagonal positions
        let ringPositions: [HexCoordinate] = [
            HexCoordinate(q: 0, r: -1),   // Top (directly above center)
            HexCoordinate(q: 1, r: 0),    // Right (directly to the right, parallel to right face)
            HexCoordinate(q: 1, r: -1),   // Top-right (diagonal, adjacent to top-right face)
            HexCoordinate(q: 0, r: 1),    // Bottom (directly below center)
            HexCoordinate(q: -1, r: 0),   // Left (directly to the left, parallel to left face)
            HexCoordinate(q: -1, r: 1)    // Bottom-left (diagonal, adjacent to bottom-left face)
        ]
        
        // Assign positions to current page spaces
        for (index, space) in currentPageSpaces.enumerated() {
            if index < ringPositions.count {
                positions[space.id] = ringPositions[index]
            }
        }
        
        hexPositions = positions
    }
}

struct HivePageView: View {
    let spaces: [Space]
    let ghostSlots: Int
    let center: CGPoint
    let hexPositions: [String: HexCoordinate]
    let onSpaceTap: (Space) -> Void
    let onSpaceLongPress: (Space) -> Void
    let onSpaceEdit: (Space) -> Void
    let onSpaceLock: (Space) -> Void
    let onSpaceUnlock: (Space) -> Void
    let onSpaceDelete: (Space) -> Void
    let onGhostTap: () -> Void
    
    // Ring positions (same as in SpacesHiveView)
    // Ordered: Top, Right, Top-right, Bottom, Left, Bottom-left
    let ringPositions: [HexCoordinate] = [
        HexCoordinate(q: 0, r: -1),   // Top
        HexCoordinate(q: 1, r: 0),    // Right
        HexCoordinate(q: 1, r: -1),   // Top-right
        HexCoordinate(q: 0, r: 1),    // Bottom
        HexCoordinate(q: -1, r: 0),   // Left
        HexCoordinate(q: -1, r: 1)    // Bottom-left
    ]
    
    var body: some View {
        ZStack {
            // Filled space hexagons
            ForEach(spaces) { space in
                if let coord = hexPositions[space.id] {
                    SpaceHexagonView(
                        space: space,
                        isSelected: false,
                        onTap: { onSpaceTap(space) },
                        onLongPress: { onSpaceLongPress(space) },
                        onEdit: { onSpaceEdit(space) },
                        onLock: { onSpaceLock(space) },
                        onUnlock: { onSpaceUnlock(space) },
                        onDelete: { onSpaceDelete(space) }
                    )
                    .position(coord.toPoint(hexSize: 90, center: center))
                    .zIndex(10)
                }
            }
            
            // Ghost slots
            ForEach(0..<ghostSlots, id: \.self) { index in
                let slotIndex = spaces.count + index
                if slotIndex < ringPositions.count {
                    GhostHexagonView(onTap: onGhostTap)
                        .position(ringPositions[slotIndex].toPoint(hexSize: 90, center: center))
                        .zIndex(1)
                }
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

