//
//  SpacesPhysicsEngine.swift
//  Just Vault
//
//  Main physics engine for bubble physics simulation
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SpacesPhysicsEngine: ObservableObject {
    @Published var bubbleStates: [String: BubblePhysics] = [:]
    
    private var gravitationalPhysics: GravitationalPhysics
    private var screenSize: CGSize
    
    init(screenSize: CGSize) {
        self.screenSize = screenSize
        let screenCenter = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        self.gravitationalPhysics = GravitationalPhysics(center: screenCenter)
    }
    
    func updateScreenSize(_ newSize: CGSize) {
        screenSize = newSize
        // Update center
        let newCenter = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
        gravitationalPhysics.updateCenter(newCenter)
    }
    
    /// Update physics for all bubbles
    func updatePhysics() {
        // Calculate gravitational pull for each bubble
        for (id, var bubble) in bubbleStates {
            // Get other bubbles for repulsion calculation
            let otherBubbles = bubbleStates.filter { $0.key != id }.map { 
                (position: $0.value.position, mass: $0.value.mass, radius: $0.value.radius)
            }
            
            // Calculate gravitational pull
            let pull = gravitationalPhysics.calculatePull(
                bubblePosition: bubble.position,
                bubbleMass: bubble.mass,
                otherBubbles: otherBubbles
            )
            
            // Update bubble physics
            bubble.update(gravitationalPull: pull)
            
            // Boundary collision (bounce off edges)
            handleBoundaryCollision(&bubble)
            
            bubbleStates[id] = bubble
        }
        
        // Check bubble-to-bubble collisions (prevent touching)
        handleBubbleCollisions()
    }
    
    private func handleBoundaryCollision(_ bubble: inout BubblePhysics) {
        let margin: CGFloat = bubble.radius + 20
        
        if bubble.position.x < margin {
            bubble.position.x = margin
            bubble.velocity.dx *= -0.7  // Bounce with damping
        }
        if bubble.position.x > screenSize.width - margin {
            bubble.position.x = screenSize.width - margin
            bubble.velocity.dx *= -0.7
        }
        if bubble.position.y < margin {
            bubble.position.y = margin
            bubble.velocity.dy *= -0.7
        }
        if bubble.position.y > screenSize.height - margin {
            bubble.position.y = screenSize.height - margin
            bubble.velocity.dy *= -0.7
        }
    }
    
    private func handleBubbleCollisions() {
        let bubbleIds = Array(bubbleStates.keys)
        
        for i in 0..<bubbleIds.count {
            for j in (i+1)..<bubbleIds.count {
                guard var bubble1 = bubbleStates[bubbleIds[i]],
                      var bubble2 = bubbleStates[bubbleIds[j]] else { continue }
                
                let dx = bubble2.position.x - bubble1.position.x
                let dy = bubble2.position.y - bubble1.position.y
                let distance = sqrt(dx * dx + dy * dy)
                let minDistance = bubble1.radius + bubble2.radius + 10  // 10pt gap
                
                // Collision detected - separate bubbles
                if distance < minDistance && distance > 0 {
                    // Calculate separation
                    let overlap = minDistance - distance
                    let separationX = (dx / distance) * overlap * 0.5
                    let separationY = (dy / distance) * overlap * 0.5
                    
                    // Separate bubbles
                    bubble1.position.x -= separationX
                    bubble1.position.y -= separationY
                    bubble2.position.x += separationX
                    bubble2.position.y += separationY
                    
                    // Add repulsion velocity (gentle push apart)
                    let repulsionStrength: CGFloat = 2.0
                    bubble1.velocity.dx -= (dx / distance) * repulsionStrength
                    bubble1.velocity.dy -= (dy / distance) * repulsionStrength
                    bubble2.velocity.dx += (dx / distance) * repulsionStrength
                    bubble2.velocity.dy += (dy / distance) * repulsionStrength
                    
                    bubbleStates[bubbleIds[i]] = bubble1
                    bubbleStates[bubbleIds[j]] = bubble2
                }
            }
        }
    }
    
    /// Add a new bubble to the physics simulation
    func addBubble(spaceId: String, fileCount: Int, initialPosition: CGPoint) {
        let radius = BubbleSizeCalculator.radius(for: fileCount)
        let mass = BubbleSizeCalculator.mass(for: fileCount)
        
        bubbleStates[spaceId] = BubblePhysics(
            position: initialPosition,
            velocity: CGVector(dx: 0, dy: 0),
            radius: radius,
            mass: mass,
            fileCount: fileCount
        )
    }
    
    /// Update bubble size when file count changes
    func updateBubbleFileCount(spaceId: String, newFileCount: Int) {
        guard var bubble = bubbleStates[spaceId] else { return }
        
        bubble.fileCount = newFileCount
        bubble.radius = BubbleSizeCalculator.radius(for: newFileCount)
        bubble.mass = BubbleSizeCalculator.mass(for: newFileCount)
        
        bubbleStates[spaceId] = bubble
    }
    
    /// Check if any bubbles are still moving
    func hasActivePhysics() -> Bool {
        return bubbleStates.values.contains { bubble in
            abs(bubble.velocity.dx) > 0.1 || abs(bubble.velocity.dy) > 0.1
        }
    }
}

