//
//  SpaceContextMenuView.swift
//  Just Vault
//
//  Context menu for space actions
//

import SwiftUI
import LocalAuthentication

struct SpaceContextMenuView: View {
    let space: Space
    let onEdit: () -> Void
    let onLock: () -> Void
    let onUnlock: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onEdit) {
                Label("Edit Space", systemImage: "pencil")
            }
            
            if space.isLocked {
                Button(action: onUnlock) {
                    Label("Unlock Space", systemImage: "lock.open")
                }
            } else {
                Button(action: onLock) {
                    Label("Lock Space", systemImage: "lock")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Space", systemImage: "trash")
            }
        }
    }
}

