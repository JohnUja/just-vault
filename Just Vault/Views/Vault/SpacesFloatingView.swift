//
//  SpacesFloatingView.swift
//  Just Vault
//
//  Free-floating bubbles with physics-based gravitational pull
//

import SwiftUI
import Combine
import Foundation

struct SpacesFloatingView: View {
    let spaces: [Space]
    @Binding var vaultMode: VaultMode
    let syncStatus: SyncStatus
    let onAddSpace: () -> Void
    let onSpaceTap: (Space) -> Void
    let onFocusSpace: (Space) -> Void
    let onShowFocusInfo: () -> Void
    let onOrganize: () -> Void
    
    @StateObject private var physicsEngine: SpacesPhysicsEngine
    @State private var physicsTimer: Timer?
    @State private var containerSize: CGSize = .zero
    
    init(
        spaces: [Space],
        vaultMode: Binding<VaultMode>,
        syncStatus: SyncStatus,
        onAddSpace: @escaping () -> Void,
        onSpaceTap: @escaping (Space) -> Void,
        onFocusSpace: @escaping (Space) -> Void,
        onShowFocusInfo: @escaping () -> Void,
        onOrganize: @escaping () -> Void
    ) {
        self.spaces = spaces
        self._vaultMode = vaultMode
        self.syncStatus = syncStatus
        self.onAddSpace = onAddSpace
        self.onSpaceTap = onSpaceTap
        self.onFocusSpace = onFocusSpace
        self.onShowFocusInfo = onShowFocusInfo
        self.onOrganize = onOrganize
        
        // Initialize physics engine
        let screenSize = UIScreen.main.bounds.size
        _physicsEngine = StateObject(wrappedValue: SpacesPhysicsEngine(screenSize: screenSize))
    }
    
    var body: some View {
        ScrollView {
            geometryContent
        }
        .onDisappear {
            stopPhysicsLoop()
        }
        .onChange(of: spaces) { oldSpaces, newSpaces in
            updatePhysicsForSpaces(newSpaces, containerSize: containerSize)
        }
        .onChange(of: physicsEngine.bubbleStates) { oldStates, newStates in
            // Trigger view update when physics states change
            // This ensures bubbles move smoothly
        }
    }
    
    private var geometryContent: some View {
        GeometryReader { geometry in
            ZStack {
                bubblesView
                addSpaceButton(geometry: geometry)
            }
            .frame(width: geometry.size.width, height: max(geometry.size.height, containerSize.height))
            .onAppear {
                containerSize = geometry.size
                physicsEngine.updateScreenSize(geometry.size)
                initializeBubbles(containerSize: geometry.size)
                startPhysicsLoop()
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                containerSize = newSize
                physicsEngine.updateScreenSize(newSize)
            }
        }
        .frame(height: max(UIScreen.main.bounds.height, containerSize.height))
    }
    
    @ViewBuilder
    private var bubblesView: some View {
        ForEach(spaces) { space in
            if let bubbleState = physicsEngine.bubbleStates[space.id] {
                bubbleView(for: space, state: bubbleState)
            }
        }
    }
    
    private func bubbleView(for space: Space, state: BubblePhysics) -> some View {
        SpaceBubbleView(
            space: space,
            isFocused: vaultMode.focusedSpaceId == space.id,
            isDimmed: vaultMode.isFocusMode && vaultMode.focusedSpaceId != space.id,
            vaultMode: vaultMode,
            radius: state.radius,
            position: .zero,  // Position handled by .position() modifier
            onTap: {
                onSpaceTap(space)
            },
            onFocus: {
                onFocusSpace(space)
            },
            onShowFocusInfo: onShowFocusInfo,
            onLongPress: {
                // Long press handled by SpaceBubbleView
            }
        )
        .position(state.position)
        .zIndex(vaultMode.focusedSpaceId == space.id ? 10 : 1)
    }
    
    @ViewBuilder
    private func addSpaceButton(geometry: GeometryProxy) -> some View {
        if !vaultMode.isFocusMode {
            Button(action: onAddSpace) {
                AddSpacePetalView()
                    .frame(width: 80, height: 80)
            }
            .position(addButtonPosition(in: geometry.size))
        }
    }
    
    // MARK: - Physics Management
    
    private func initializeBubbles(containerSize: CGSize) {
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        
        for space in spaces {
            // Skip if already initialized
            if physicsEngine.bubbleStates[space.id] != nil { continue }
            
            // Start bubbles near center with slight random offset
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...150)
            let initialPosition = CGPoint(
                x: center.x + CGFloat(Foundation.cos(angle)) * distance,
                y: center.y + CGFloat(Foundation.sin(angle)) * distance
            )
            
            physicsEngine.addBubble(
                spaceId: space.id,
                fileCount: space.fileCount,
                initialPosition: initialPosition
            )
        }
    }
    
    private func startPhysicsLoop() {
        let engine = physicsEngine
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            Task { @MainActor in
                // Only update if bubbles are moving
                if engine.hasActivePhysics() {
                    engine.updatePhysics()
                }
            }
        }
    }
    
    private func stopPhysicsLoop() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }
    
    private func updatePhysicsForSpaces(_ spaces: [Space], containerSize: CGSize) {
        for space in spaces {
            if let existingBubble = physicsEngine.bubbleStates[space.id] {
                // Update file count (bubble size changes)
                if existingBubble.fileCount != space.fileCount {
                    physicsEngine.updateBubbleFileCount(spaceId: space.id, newFileCount: space.fileCount)
                }
            } else {
                // New space - add to physics
                let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 50...150)
                let initialPosition = CGPoint(
                    x: center.x + CGFloat(Foundation.cos(angle)) * distance,
                    y: center.y + CGFloat(Foundation.sin(angle)) * distance
                )
                
                physicsEngine.addBubble(
                    spaceId: space.id,
                    fileCount: space.fileCount,
                    initialPosition: initialPosition
                )
            }
        }
        
        // Remove deleted spaces
        let currentSpaceIds = Set(spaces.map { $0.id })
        let physicsIds = Set(physicsEngine.bubbleStates.keys)
        let deletedIds = physicsIds.subtracting(currentSpaceIds)
        
        for deletedId in deletedIds {
            physicsEngine.bubbleStates.removeValue(forKey: deletedId)
        }
    }
    
    private func addButtonPosition(in size: CGSize) -> CGPoint {
        // Position add button at bottom center
        return CGPoint(x: size.width / 2, y: size.height - 100)
    }
}

