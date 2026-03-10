//
//  DefaultSpacesService.swift
//  Just Vault
//
//  Service for creating pre-defined default spaces on first launch
//

import Foundation

struct DefaultSpace {
    let name: String
    let icon: String  // SF Symbol name
    let color: String // Hex color
    let hasLockOverlay: Bool // Whether to show lock badge overlay
    let orderIndex: Int
}

class DefaultSpacesService {
    static let shared = DefaultSpacesService()
    
    private init() {}
    
    /// Pre-defined spaces configuration
    /// Based on the image: Documents, Keys, Cards, Photos, Backup, Folders
    var defaultSpaces: [DefaultSpace] {
        [
            DefaultSpace(
                name: "Documents",
                icon: "doc.text.fill",
                color: "#007AFF", // Blue
                hasLockOverlay: true,
                orderIndex: 0
            ),
            DefaultSpace(
                name: "Keys",
                icon: "key.fill",
                color: "#FF9500", // Orange
                hasLockOverlay: true,
                orderIndex: 1
            ),
            DefaultSpace(
                name: "Cards",
                icon: "creditcard.fill",
                color: "#34C759", // Green
                hasLockOverlay: false,
                orderIndex: 2
            ),
            DefaultSpace(
                name: "Photos",
                icon: "photo.stack.fill",
                color: "#AF52DE", // Purple
                hasLockOverlay: false,
                orderIndex: 3
            ),
            DefaultSpace(
                name: "Backup",
                icon: "icloud.and.arrow.up.fill",
                color: "#5856D6", // Indigo
                hasLockOverlay: false,
                orderIndex: 4
            ),
            DefaultSpace(
                name: "Folders",
                icon: "folder.fill",
                color: "#00C7BE", // Teal
                hasLockOverlay: true,
                orderIndex: 5
            )
        ]
    }
    
    /// Create all default spaces for a user
    func createDefaultSpaces(userId: String) -> [Space] {
        return defaultSpaces.map { defaultSpace in
            Space.create(
                id: UUID().uuidString,
                userId: userId,
                name: defaultSpace.name,
                icon: defaultSpace.icon,
                color: defaultSpace.color,
                isLocked: false,
                orderIndex: defaultSpace.orderIndex
            )
        }
    }
    
    /// Check if user needs default spaces (has no spaces)
    func shouldCreateDefaults(existingSpaces: [Space]) -> Bool {
        return existingSpaces.isEmpty
    }
}

