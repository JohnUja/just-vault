//
//  EditSpaceView.swift
//  Just Vault
//
//  Edit space name, icon, and color — same form as Create Space, different title/button.
//

import SwiftUI

struct EditSpaceView: View {
    let space: Space
    let onSave: (String, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var spaceName: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    
    init(space: Space, onSave: @escaping (String, String, String) -> Void) {
        self.space = space
        self.onSave = onSave
        _spaceName = State(initialValue: space.name)
        _selectedIcon = State(initialValue: space.icon)
        _selectedColor = State(initialValue: space.color)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                    
                    // Folder Name (same label as Create)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Space Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Work, Personal, Projects", text: $spaceName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 20)
                    
                    // Icons — same set as Create Space
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Icon")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(CreateSpacePopupView.icons, id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon,
                                    onSelect: { selectedIcon = icon }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Colors — same set as Create Space
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Color")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(CreateSpacePopupView.colors, id: \.self) { color in
                                ColorButton(
                                    color: color,
                                    isSelected: selectedColor == color,
                                    onSelect: { selectedColor = color }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Save button inside ScrollView so keyboard doesn't cover it
                    Button(action: {
                        onSave(spaceName.trimmingCharacters(in: .whitespaces), selectedIcon, selectedColor)
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accentGradient)
                            .cornerRadius(12)
                    }
                    .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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

