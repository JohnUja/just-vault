//
//  EditSpaceView.swift
//  Just Vault
//
//  Edit space name, icon, and color
//

import SwiftUI

struct EditSpaceView: View {
    let space: Space
    let onSave: (String, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var spaceName: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    
    let icons = [
        "doc.text.fill", "briefcase.fill", "heart.fill", "house.fill",
        "star.fill", "book.fill", "camera.fill", "folder.fill"
    ]
    
    let colors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500",
        "#AF52DE", "#5856D6", "#00C7BE", "#FFCC00"
    ]
    
    init(space: Space, onSave: @escaping (String, String, String) -> Void) {
        self.space = space
        self.onSave = onSave
        _spaceName = State(initialValue: space.name)
        _selectedIcon = State(initialValue: space.icon)
        _selectedColor = State(initialValue: space.color)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    SpaceHexagonView(
                        space: Space(
                            id: space.id,
                            userId: space.userId,
                            name: spaceName,
                            icon: selectedIcon,
                            color: selectedColor,
                            isLocked: space.isLocked,
                            orderIndex: space.orderIndex,
                            createdAt: space.createdAt,
                            fileCount: space.fileCount
                        ),
                        isSelected: false,
                        onTap: {},
                        onLongPress: {},
                        onEdit: {},
                        onLock: {},
                        onUnlock: {},
                        onDelete: {}
                    )
                    .frame(width: 100, height: 100)
                }
                .padding(.top, 20)
                
                // Folder Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter folder name", text: $spaceName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 20)
                
                // Icons
                VStack(spacing: 12) {
                    Text("Icon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach(icons.prefix(4), id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon,
                                    onSelect: { selectedIcon = icon }
                                )
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ForEach(icons.suffix(4), id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon,
                                    onSelect: { selectedIcon = icon }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Colors
                VStack(spacing: 12) {
                    Text("Color")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach(colors.prefix(4), id: \.self) { color in
                                ColorButton(
                                    color: color,
                                    isSelected: selectedColor == color,
                                    onSelect: { selectedColor = color }
                                )
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ForEach(colors.suffix(4), id: \.self) { color in
                                ColorButton(
                                    color: color,
                                    isSelected: selectedColor == color,
                                    onSelect: { selectedColor = color }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Save Button
                Button(action: {
                    onSave(spaceName.trimmingCharacters(in: .whitespaces), selectedIcon, selectedColor)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Space")
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
    EditSpaceView(
        space: Space.create(userId: "test", name: "Test Space"),
        onSave: { _, _, _ in }
    )
}

