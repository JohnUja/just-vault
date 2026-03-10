//
//  BubblePhysics.swift
//  Just Vault
//
//  Physics model for individual bubbles
//

import Foundation
import SwiftUI

struct BubblePhysics: Equatable {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var mass: CGFloat
    var fileCount: Int
    
    /// Update bubble physics based on gravitational pull
    mutating func update(
        gravitationalPull: CGVector,
        damping: CGFloat = 0.95,
        timeStep: CGFloat = 0.016  // ~60fps
    ) {
        // Apply gravitational force to velocity
        velocity.dx += gravitationalPull.dx * timeStep
        velocity.dy += gravitationalPull.dy * timeStep
        
        // Apply velocity to position
        position.x += velocity.dx * timeStep
        position.y += velocity.dy * timeStep
        
        // Apply damping (gradual slowdown)
        velocity.dx *= damping
        velocity.dy *= damping
        
        // Stop very slow movement (prevent jitter)
        if abs(velocity.dx) < 0.1 { velocity.dx = 0 }
        if abs(velocity.dy) < 0.1 { velocity.dy = 0 }
    }
}

