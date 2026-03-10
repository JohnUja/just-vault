//
//  GravitationalPhysics.swift
//  Just Vault
//
//  Calculates gravitational pull toward center based on bubble mass
//

import Foundation
import SwiftUI

struct GravitationalPhysics {
    var center: CGPoint
    let gravitationalConstant: CGFloat = 0.5  // Adjust for pull strength
    
    mutating func updateCenter(_ newCenter: CGPoint) {
        center = newCenter
    }
    
    /// Calculate gravitational pull for a bubble
    /// - Parameters:
    ///   - bubblePosition: Current position of the bubble
    ///   - bubbleMass: Mass of the bubble (based on size/file count)
    ///   - otherBubbles: Other bubbles for repulsion calculation
    /// - Returns: Pull vector toward center (with repulsion from other bubbles)
    func calculatePull(
        bubblePosition: CGPoint,
        bubbleMass: CGFloat,
        otherBubbles: [(position: CGPoint, mass: CGFloat, radius: CGFloat)]
    ) -> CGVector {
        // 1. Pull toward center (stronger for bigger bubbles)
        let centerVector = CGVector(
            dx: center.x - bubblePosition.x,
            dy: center.y - bubblePosition.y
        )
        let distanceToCenter = sqrt(centerVector.dx * centerVector.dx + centerVector.dy * centerVector.dy)
        
        // Gravitational force = (mass / distance²) * constant
        // Bigger bubbles (more mass) have stronger pull
        let centerPullStrength = (bubbleMass / max(distanceToCenter * distanceToCenter, 1.0)) * gravitationalConstant
        
        // Normalize and scale
        let normalizedCenter = normalize(vector: centerVector)
        var totalPull = CGVector(
            dx: normalizedCenter.dx * centerPullStrength,
            dy: normalizedCenter.dy * centerPullStrength
        )
        
        // 2. Repulsion from other bubbles (prevents touching)
        for otherBubble in otherBubbles {
            let repulsionVector = CGVector(
                dx: bubblePosition.x - otherBubble.position.x,
                dy: bubblePosition.y - otherBubble.position.y
            )
            let distance = sqrt(repulsionVector.dx * repulsionVector.dx + repulsionVector.dy * repulsionVector.dy)
            let minDistance: CGFloat = otherBubble.radius + 10  // Minimum gap between bubbles
            
            if distance < minDistance && distance > 0 {
                // Strong repulsion when too close
                let repulsionStrength = (minDistance - distance) / minDistance * 2.0
                let normalizedRepulsion = normalize(vector: repulsionVector)
                totalPull.dx += normalizedRepulsion.dx * repulsionStrength
                totalPull.dy += normalizedRepulsion.dy * repulsionStrength
            }
        }
        
        return totalPull
    }
    
    private func normalize(vector: CGVector) -> CGVector {
        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard magnitude > 0 else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    }
}

