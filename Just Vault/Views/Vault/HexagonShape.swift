//
//  HexagonShape.swift
//  Just Vault
//
//  Hexagon shape component for hive layout
//

import SwiftUI

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        for i in 0..<6 {
            // Rotate by 30 degrees (π/6) to get flat top/bottom instead of pointy ends
            // Remove the -π/6 offset to get flat ends at top/bottom
            let angle = CGFloat.pi / 3 * CGFloat(i)  // This gives flat top/bottom
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// Hexagonal coordinate system for hive layout
struct HexCoordinate {
    let q: Int  // Column
    let r: Int  // Row
    
    func toPoint(hexSize: CGFloat, center: CGPoint) -> CGPoint {
        // For flat-top hexagons, use axial coordinates
        // hexSize is the distance from center to edge (not to vertex)
        let x = hexSize * (sqrt(3) * CGFloat(q) + sqrt(3)/2 * CGFloat(r))
        let y = hexSize * (3.0/2.0 * CGFloat(r))
        return CGPoint(x: center.x + x, y: center.y + y)
    }
}

// Generate spiral pattern for hexagon positions
func generateHexSpiral(count: Int) -> [HexCoordinate] {
    var coords: [HexCoordinate] = []
    
    // Ring positions around center (6 spots)
    // Ordered: Top, Right, Top-right, Bottom, Left, Bottom-left
    let ringPositions: [HexCoordinate] = [
        HexCoordinate(q: 0, r: -1),   // Top
        HexCoordinate(q: 1, r: 0),    // Right
        HexCoordinate(q: 1, r: -1),   // Top-right
        HexCoordinate(q: 0, r: 1),    // Bottom
        HexCoordinate(q: -1, r: 0),   // Left
        HexCoordinate(q: -1, r: 1)    // Bottom-left
    ]
    
    // For first 6, use ring positions
    for i in 0..<min(count, 6) {
        coords.append(ringPositions[i])
    }
    
    return coords
}



