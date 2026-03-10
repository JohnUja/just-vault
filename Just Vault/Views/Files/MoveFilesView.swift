//
//  MoveFilesView.swift
//  Just Vault
//
//  Move files to different space
//

import SwiftUI

struct MoveFilesView: View {
    let fileIds: [String]
    let currentSpace: Space
    let allSpaces: [Space]
    let onMove: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var availableSpaces: [Space] {
        allSpaces.filter { $0.id != currentSpace.id }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Move \(fileIds.count) file\(fileIds.count == 1 ? "" : "s") to:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                ForEach(availableSpaces) { space in
                    Button(action: {
                        onMove(space.id)
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: space.color))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: space.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(space.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("\(space.fileCount) files")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Move Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MoveFilesView(
        fileIds: ["1", "2"],
        currentSpace: Space.create(userId: "test", name: "Current"),
        allSpaces: [
            Space.create(userId: "test", name: "Space 1"),
            Space.create(userId: "test", name: "Space 2")
        ],
        onMove: { _ in }
    )
}

