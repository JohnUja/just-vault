//
//  Space.swift
//  Just Vault
//
//  Space model (the "petals" in the flower UI)
//

import Foundation

struct Space: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let icon: String // SF Symbol name
    let color: String // Hex color
    let isLocked: Bool
    let orderIndex: Int
    let createdAt: Date
    let fileCount: Int
    
    // Computed properties
    var displayColor: String {
        color
    }
}

// Space creation helper
extension Space {
    static func create(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        icon: String = "doc.text.fill",
        color: String = "#007AFF",
        isLocked: Bool = false,
        orderIndex: Int = 0
    ) -> Space {
        Space(
            id: id,
            userId: userId,
            name: name,
            icon: icon,
            color: color,
            isLocked: isLocked,
            orderIndex: orderIndex,
            createdAt: Date(),
            fileCount: 0
        )
    }
}

