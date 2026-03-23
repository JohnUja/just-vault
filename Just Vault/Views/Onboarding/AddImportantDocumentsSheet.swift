//
//  AddImportantDocumentsSheet.swift
//  Just Vault
//
//  Post-login onboarding: “Let’s help you get started” + pull-up with Files / Photos / Camera.
//  Pickers use fullScreenCover(item:) — nested .sheet from the custom overlay often shows a blank white screen.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct ImportantDocsPickerSession: Identifiable {
    let id = UUID()
    enum Mode {
        case document
        case image(UIImagePickerController.SourceType)
    }

    let mode: Mode
    let space: Space
}

struct AddImportantDocumentsSheet: View {
    let spaces: [Space]
    let allowedContentTypes: [UTType]
    let onImport: (URL, Space) async -> Void
    let onDismiss: () -> Void

    private static let steps: [(prompt: String, spaceName: String)] = [
        ("Add your ID or passport", "IDs & Licenses"),
        ("Add an insurance card (health or auto)", "IDs & Licenses"),
        ("Add a tax or important document (W-2, lease)", "Documents"),
        ("Add a receipt or bill you want to keep", "Receipts")
    ]

    @State private var currentStep = 0
    @State private var pickerSession: ImportantDocsPickerSession?
    @State private var isImporting = false

    private var isLastUploadStep: Bool { currentStep == Self.steps.count - 1 }
    private var isCheckoutStep: Bool { currentStep >= Self.steps.count }

    var body: some View {
        VStack(spacing: 18) {
            if isCheckoutStep {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.accent)
                Text("You're all set")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.headerTint)
                Text("Check out your spaces and add more files anytime.")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accentGradient)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Spacer()
                        Button(action: skipStep) {
                            Text("Skip")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(spacing: 6) {
                        Text("Step \(currentStep + 1) of 5")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)

                        Text("Let's help you get started")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.headerTint)
                            .multilineTextAlignment(.center)

                        Text(Self.steps[currentStep].prompt)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)

                    if let space = spaceForStep {
                        SpacePreviewBanner(space: space)
                            .padding(.top, 8)
                    } else {
                        Text("Loading your spaces...")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 6)

                Spacer(minLength: 10)

                if isImporting {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .padding(.vertical, 8)
                    Spacer(minLength: 4)
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            addOptionButton(icon: "doc", label: "Files") {
                                openDocumentPicker()
                            }
                            addOptionButton(icon: "photo", label: "Photos") {
                                openImagePicker(source: .photoLibrary)
                            }
                            addOptionButton(icon: "camera", label: "Camera") {
                                openImagePicker(source: .camera)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(AppTheme.backgroundGradient)
        .fullScreenCover(item: $pickerSession) { session in
            Group {
                switch session.mode {
                case .document:
                    DocumentPicker(
                        allowedContentTypes: allowedContentTypes,
                        onDocumentPicked: { url in
                            let space = session.space
                            pickerSession = nil
                            Task {
                                await handleDocumentPicked(url: url, space: space)
                            }
                        },
                        onCancel: { pickerSession = nil }
                    )
                    .ignoresSafeArea()
                case .image(let source):
                    ImagePicker(
                        sourceType: source,
                        onImagePicked: { image in
                            let space = session.space
                            pickerSession = nil
                            Task {
                                await handleImagePicked(image: image, space: space, source: source)
                            }
                        },
                        onCancel: { pickerSession = nil }
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func addOptionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
                        )
                        .frame(height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.accent)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.headerTint)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(spaceForStep == nil)
    }

    private var spaceForStep: Space? {
        guard currentStep < Self.steps.count else { return nil }
        let name = Self.steps[currentStep].spaceName
        return spaces.first { $0.name == name }
    }

    private func openDocumentPicker() {
        guard let space = spaceForStep else { return }
        pickerSession = ImportantDocsPickerSession(mode: .document, space: space)
    }

    private func openImagePicker(source: UIImagePickerController.SourceType) {
        guard let space = spaceForStep else { return }
        pickerSession = ImportantDocsPickerSession(mode: .image(source), space: space)
    }

    private func skipStep() {
        if isLastUploadStep {
            currentStep = Self.steps.count
        } else {
            currentStep += 1
        }
    }

    private func handleDocumentPicked(url: URL, space: Space) async {
        isImporting = true
        await onImport(url, space)
        await MainActor.run { isImporting = false }
        advanceStep()
    }

    private func handleImagePicked(image: UIImage, space: Space, source: UIImagePickerController.SourceType) async {
        isImporting = true
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            let prefix = source == .camera ? "Camera" : "Photo"
            let fileName = "\(prefix) \(formatter.string(from: Date())).jpg"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try? imageData.write(to: tempURL)
            await onImport(tempURL, space)
        }
        await MainActor.run { isImporting = false }
        advanceStep()
    }

    private func advanceStep() {
        if isLastUploadStep {
            currentStep = Self.steps.count
        } else {
            currentStep += 1
        }
    }

    @ViewBuilder
    private func SpacePreviewBanner(space: Space) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: space.color).opacity(0.14))
                    .frame(width: 44, height: 44)
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: space.color).opacity(0.45), lineWidth: 1)
                )
        )
    }
}
