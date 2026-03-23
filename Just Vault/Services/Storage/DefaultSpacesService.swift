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
    
    /// Pre-defined spaces: clearer names for common vault use cases (documents/photos only; no "Passwords" — we're not a password manager).
    /// Documents, IDs & Licenses, Receipts, Photos, Secure notes, Archive
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
                name: "IDs & Licenses",
                icon: "person.text.rectangle.fill",
                color: "#FF9500", // Orange
                hasLockOverlay: true,
                orderIndex: 1
            ),
            DefaultSpace(
                name: "Receipts",
                icon: "receipt.fill",
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
                name: "Secure notes",
                icon: "note.text",
                color: "#5856D6", // Indigo
                hasLockOverlay: true,
                orderIndex: 4
            ),
            DefaultSpace(
                name: "Archive",
                icon: "archivebox.fill",
                color: "#00C7BE", // Teal
                hasLockOverlay: false,
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

    /// Returns the first missing default space (by name) for a given user,
    /// preserving the original orderIndex so it appears in the correct ring slot.
    func nextMissingDefault(existingSpaces: [Space], userId: String) -> Space? {
        let existingOrderIndexes = Set(existingSpaces.map(\.orderIndex))
        guard let missing = defaultSpaces.first(where: { !existingOrderIndexes.contains($0.orderIndex) }) else {
            return nil
        }
        return Space.create(
            id: UUID().uuidString,
            userId: userId,
            name: missing.name,
            icon: missing.icon,
            color: missing.color,
            isLocked: false,
            orderIndex: missing.orderIndex
        )
    }
}

