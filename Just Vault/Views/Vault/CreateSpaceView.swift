//
//  CreateSpaceView.swift
//  Just Vault
//
//  Create a new space
//

import SwiftUI

struct CreateSpaceView: View {
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Folder Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folder Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        TextField("Enter folder name", text: $spaceName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Icon Picker Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedIcon = icon
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    selectedIcon == icon
                                                        ? LinearGradient(
                                                            colors: [AppTheme.accent, AppTheme.accentSecondary],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                        : LinearGradient(
                                                            colors: [
                                                                Color.gray.opacity(0.2),
                                                                Color.gray.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(
                                                    selectedIcon == icon
                                                        ? Color.white.opacity(0.5)
                                                        : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .shadow(
                                            color: selectedIcon == icon
                                                ? Color.purple.opacity(0.3)
                                                : .clear,
                                            radius: 8,
                                            x: 0,
                                            y: 4
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Color Picker Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedColor = color
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 56, height: 56)
                                        
                                        // White drop shadow background
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 56, height: 56)
                                            .blur(radius: 8)
                                            .offset(x: 0, y: 4)
                                        
                                        if selectedColor == color {
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 3)
                                                .frame(width: 56, height: 56)
                                        }
                                    }
                                    .shadow(
                                        color: selectedColor == color
                                            ? Color(hex: color).opacity(0.5)
                                            : .clear,
                                        radius: selectedColor == color ? 12 : 0,
                                        x: 0,
                                        y: 6
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("New Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let trimmedName = spaceName.trimmingCharacters(in: .whitespaces)
                        if !trimmedName.isEmpty {
                            onCreate(trimmedName, selectedIcon, selectedColor)
                            dismiss()
                        }
                    }
                    .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    CreateSpaceView(onCreate: { _, _, _ in })
}
