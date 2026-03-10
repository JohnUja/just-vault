//
//  CreateSpacePopupView.swift
//  Just Vault
//
//  Compact popup for creating a new space
//

import SwiftUI

struct CreateSpacePopupView: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (String, String, String) -> Void
    
    @State private var spaceName: String = ""
    @State private var selectedIcon: String = "doc.text.fill"
    @State private var selectedColor: String = "#007AFF"
    
    // Limited to 8 icons (4 per row)
    let icons = [
        "doc.text.fill", "briefcase.fill", "heart.fill", "house.fill",
        "star.fill", "book.fill", "camera.fill", "folder.fill"
    ]
    
    // Limited to 8 colors (4 per row)
    let colors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500",
        "#AF52DE", "#5856D6", "#00C7BE", "#FFCC00"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with orange outline accent
            VStack(spacing: 12) {
                HStack {
                    Text("Create New Space")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Organize your files into custom spaces")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                Rectangle()
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 3),
                        alignment: .bottom
                    )
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Space Name
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Space Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Work, Personal, Projects", text: $spaceName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            
                    // Icons
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Icon")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon,
                                    onSelect: { selectedIcon = icon }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Colors
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Color")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                ColorButton(
                                    color: color,
                                    isSelected: selectedColor == color,
                                    onSelect: { selectedColor = color }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            
            // Create Button (fixed at bottom)
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    let trimmedName = spaceName.trimmingCharacters(in: .whitespaces)
                    if !trimmedName.isEmpty {
                        onCreate(trimmedName, selectedIcon, selectedColor)
                        dismiss()
                    }
                }) {
                    Text("Create Space")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.orange.opacity(0.05))
                                )
                        )
                }
                .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(spaceName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            }
            .background(Color(uiColor: .systemBackground))
        }
        .frame(width: 420, height: 600)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                            .frame(width: 50, height: 50)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            ZStack {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 40, height: 40)
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 40, height: 40)
                }
            }
        }
    }
}

#Preview {
    CreateSpacePopupView(onCreate: { _, _, _ in })
}

