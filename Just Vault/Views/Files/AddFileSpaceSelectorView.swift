//
//  AddFileSpaceSelectorView.swift
//  Just Vault
//
//  Space selector and quick-add launcher.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct AddFilePickerSession: Identifiable {
    let id = UUID()
    enum Mode {
        case document
        case image(UIImagePickerController.SourceType)
    }

    let mode: Mode
    let space: Space
}

struct AddFileSpaceSelectorView: View {
    let spaces: [Space]
    let allowedContentTypes: [UTType]
    let selectedSpace: Space?
    let onSpaceSelected: (Space) -> Void
    let onOpenSpace: (Space) -> Void
    let onDocumentPicked: (URL, Space) -> Void
    let onImagePicked: (UIImage, UIImagePickerController.SourceType, Space) -> Void
    /// When set (e.g. when shown in overlay), Back/Done call this instead of environment dismiss.
    var onRequestDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var pickerSession: AddFilePickerSession?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add File")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.headerTint)
                                Text("Choose a space first, then keep adding files, photos, or camera captures without leaving this view.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            if let selectedSpace {
                                selectedSpaceBanner(selectedSpace)
                                    .padding(.horizontal, 20)
                            }

                            VStack(spacing: 12) {
                                ForEach(spaces) { space in
                                    spaceRow(space)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    quickAddActions
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            AppTheme.cardBackground
                                .shadow(color: .black.opacity(0.06), radius: 10, y: -2)
                        )
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(AppTheme.outline)
                                .frame(height: 1)
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        if let onRequestDismiss { onRequestDismiss() }
                        else { dismiss() }
                    }
                    .foregroundColor(AppTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if let onRequestDismiss { onRequestDismiss() }
                        else { dismiss() }
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
        .fullScreenCover(item: $pickerSession) { session in
            Group {
                switch session.mode {
                case .document:
                    DocumentPicker(
                        allowedContentTypes: allowedContentTypes,
                        onDocumentPicked: { url in
                            pickerSession = nil
                            onDocumentPicked(url, session.space)
                        },
                        onCancel: { pickerSession = nil }
                    )
                    .ignoresSafeArea()
                case .image(let source):
                    ImagePicker(
                        sourceType: source,
                        onImagePicked: { image in
                            pickerSession = nil
                            onImagePicked(image, source, session.space)
                        },
                        onCancel: { pickerSession = nil }
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func selectedSpaceBanner(_ space: Space) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: space.color).opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: space.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: space.color))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Adding to")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
                Text(space.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.headerTint)
            }

            Spacer()

            Button {
                onOpenSpace(space)
                if let onRequestDismiss { onRequestDismiss() }
                else { dismiss() }
            } label: {
                Label("Open", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: space.color))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: space.color).opacity(0.45), lineWidth: 1.5)
                )
        )
    }

    private func spaceRow(_ space: Space) -> some View {
        let isSelected = selectedSpace?.id == space.id

        return HStack(spacing: 0) {
            Button {
                onSpaceSelected(space)
            } label: {
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
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: space.color))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onOpenSpace(space)
                if let onRequestDismiss { onRequestDismiss() }
                else { dismiss() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: space.color))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(hex: space.color).opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isSelected ? Color(hex: space.color) : AppTheme.outline, lineWidth: isSelected ? 1.8 : 1)
                )
        )
    }

    private var quickAddActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedSpace == nil ? "Choose a space to continue" : "Add to selected space")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText)

            HStack(spacing: 12) {
                quickActionButton(title: "Files", icon: "doc") {
                    guard let space = selectedSpace else { return }
                    pickerSession = AddFilePickerSession(mode: .document, space: space)
                }
                quickActionButton(title: "Photos", icon: "photo") {
                    guard let space = selectedSpace else { return }
                    pickerSession = AddFilePickerSession(mode: .image(.photoLibrary), space: space)
                }
                quickActionButton(title: "Camera", icon: "camera") {
                    guard let space = selectedSpace else { return }
                    pickerSession = AddFilePickerSession(mode: .image(.camera), space: space)
                }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selectedSpace != nil ? AppTheme.accent : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                selectedSpace != nil ? AppTheme.accent.opacity(0.55) : AppTheme.outline,
                                lineWidth: selectedSpace != nil ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedSpace == nil)
    }
}




