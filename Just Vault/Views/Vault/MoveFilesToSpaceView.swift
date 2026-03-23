//
//  MoveFilesToSpaceView.swift
//  Just Vault
//
//  Pick a target space to move all files from the space being deleted.
//  Uses the same simple row style as Add File space list (rounded rect, icon, name).
//

import SwiftUI

struct MoveFilesToSpaceView: View {
    let sourceSpace: Space
    let otherSpaces: [Space]
    let onSelect: (Space) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Move all \(sourceSpace.fileCount) file(s) from \"\(sourceSpace.name)\" to:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(otherSpaces, id: \.id) { space in
                            Button(action: { onSelect(space) }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: space.color).opacity(0.14))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: space.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: space.color))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(space.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.headerTint)
                                        Text("\(space.fileCount) \(space.fileCount == 1 ? "file" : "files")")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: space.color))
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(AppTheme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(AppTheme.outline, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Move files to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
}
