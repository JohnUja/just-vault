//
//  BubbleSizeCalculator.swift
//  Just Vault
//
//  Calculates bubble size based on file count
//

import Foundation
import SwiftUI

struct BubbleSizeCalculator {
    static let baseRadius: CGFloat = 40  // Base radius (4cm equivalent)
    static let maxRadius: CGFloat = 80   // Max radius at 20 files
    static let maxFileCount: Int = 20
    
    /// Calculate bubble radius based on file count
    static func radius(for fileCount: Int) -> CGFloat {
        let fileCount = min(fileCount, maxFileCount)  // Cap at max
        let growthRate = (maxRadius - baseRadius) / CGFloat(maxFileCount)
        let calculatedRadius = baseRadius + (CGFloat(fileCount) * growthRate)
        return min(calculatedRadius, maxRadius)
    }
    
    /// Calculate bubble mass for gravitational physics
    /// Mass = area (πr²) - bigger bubbles have more mass
    static func mass(for fileCount: Int) -> CGFloat {
        let radius = radius(for: fileCount)
        return .pi * radius * radius
    }
}

