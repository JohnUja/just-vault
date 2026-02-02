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
    
    // Expanded icon list (30+ icons)
    let icons = [
        "doc.text.fill", "briefcase.fill", "heart.fill", "house.fill",
        "star.fill", "book.fill", "camera.fill", "music.note",
        "photo.fill", "folder.fill", "lock.fill", "key.fill",
        "creditcard.fill", "dollarsign.circle.fill", "chart.bar.fill",
        "paintbrush.fill", "pencil.fill", "scissors.fill", "paperclip.fill",
        "envelope.fill", "phone.fill", "message.fill", "calendar.fill",
        "clock.fill", "bell.fill", "flag.fill", "tag.fill",
        "magnifyingglass", "map.fill", "car.fill", "airplane.fill",
        "gamecontroller.fill", "tv.fill", "headphones", "gift.fill"
    ]
    
    // Expanded color palette (20 colors)
    let colors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500", "#AF52DE",
        "#FF2D55", "#5856D6", "#00C7BE", "#FFCC00", "#FF6B6B",
        "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2", "#F8B739"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Space Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Space Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter space name", text: $spaceName)
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
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
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
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    Color.white,
                                                    lineWidth: selectedColor == color ? 3 : 0
                                                )
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    Color.blue.opacity(0.5),
                                                    lineWidth: selectedColor == color ? 1 : 0
                                                )
                                        )
                                        .shadow(
                                            color: selectedColor == color ? Color(hex: color).opacity(0.5) : .clear,
                                            radius: selectedColor == color ? 8 : 0
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
