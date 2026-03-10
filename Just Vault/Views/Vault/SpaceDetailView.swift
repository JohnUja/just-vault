//
//  SpaceDetailView.swift
//  Just Vault
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - ViewModel

@MainActor
class SpaceDetailViewModel: ObservableObject {
    let space: Space
    @Published var files: [VaultFile] = []
    @Published var isImporting = false
    @Published var isLocked: Bool

    init(space: Space) {
        self.space = space
        self.isLocked = space.isLocked
        loadFiles()
    }

    func unlockSpace() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                do {
                    let success = try await context.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: "Unlock space"
                    )
                    if success { isLocked = false }
                } catch {
                    print("Failed to unlock: \(error.localizedDescription)")
                }
            }
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock space"
            )
            if success { isLocked = false }
        } catch {
            print("Failed to unlock: \(error.localizedDescription)")
        }
    }

    private func loadFiles() {
        Task { await loadFilesAsync() }
    }

    private func loadFilesAsync() async {
        do {
            let localFiles = try LocalFileMetadataService.shared.loadFilesForSpace(
                userId: space.userId,
                spaceId: space.id
            )
            await MainActor.run { files = localFiles }
        } catch {
            print("Failed to load files from local storage: \(error.localizedDescription)")
        }

        do {
            let cloudFiles = try await DynamoDBService.shared.loadFilesForSpace(
                userId: space.userId,
                spaceId: space.id
            )

            for file in cloudFiles {
                try? LocalFileMetadataService.shared.saveFileMetadata(file, userId: space.userId)
            }

            await MainActor.run {
                let existingIds = Set(files.map { $0.id })
                let newFiles = cloudFiles.filter { !existingIds.contains($0.id) }
                files.append(contentsOf: newFiles)
            }
        } catch {
            print("Cloud sync not available: \(error.localizedDescription)")
        }
    }

    func importFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let vaultFile = try await FileImportService.shared.importFile(
                url: url,
                spaceId: space.id,
                userId: space.userId
            )

            try LocalFileMetadataService.shared.saveFileMetadata(vaultFile, userId: space.userId)

            do {
                try await DynamoDBService.shared.saveFileMetadata(vaultFile)
                SyncService.shared.queueFileForSync(vaultFile)
            } catch {
                print("File saved locally only (free tier): \(error.localizedDescription)")
            }

            await MainActor.run { files.append(vaultFile) }
            await loadFilesAsync()
        } catch {
            print("Failed to import file: \(error.localizedDescription)")
        }
    }

    func deleteFile(_ file: VaultFile) async {
        do {
            let localStorage = LocalStorageService()
            try localStorage.deleteEncryptedFile(fileId: file.id)

            let thumbnailId = "\(file.id)_thumb"
            try? localStorage.deleteEncryptedFile(fileId: thumbnailId)

            try? await DynamoDBService.shared.deleteFileMetadata(userId: file.userId, fileId: file.id)

            try? await S3Service.shared.deleteFile(key: file.s3Key)
            if let thumbnailKey = file.thumbnailS3Key {
                try? await S3Service.shared.deleteFile(key: thumbnailKey)
            }

            await MainActor.run {
                files.removeAll { $0.id == file.id }
            }
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }

    func moveFiles(_ fileIds: [String], to targetSpaceId: String) async {
        for fileId in fileIds {
            guard let file = files.first(where: { $0.id == fileId }) else { continue }

            let updatedFile = VaultFile(
                id: file.id,
                userId: file.userId,
                spaceId: targetSpaceId,
                displayName: file.displayName,
                sizeBytes: file.sizeBytes,
                mimeType: file.mimeType,
                createdAt: file.createdAt,
                lastOpenedAt: file.lastOpenedAt,
                starred: file.starred,
                localPath: file.localPath,
                s3Key: file.s3Key,
                syncStatus: file.syncStatus,
                version: file.version,
                thumbnailS3Key: file.thumbnailS3Key
            )

            try? await DynamoDBService.shared.saveFileMetadata(updatedFile)

            await MainActor.run {
                if let index = files.firstIndex(where: { $0.id == fileId }) {
                    files[index] = updatedFile
                }
            }
        }

        await loadFilesAsync()
    }
}

// MARK: - View

struct SpaceDetailView: View {
    let space: Space
    @StateObject private var viewModel: SpaceDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    @State private var selectedFiles: Set<String> = []
    @State private var showMoveSheet = false

    @State private var fileToDelete: VaultFile?
    @State private var showDeleteConfirmation = false

    init(space: Space) {
        self.space = space
        _viewModel = StateObject(wrappedValue: SpaceDetailViewModel(space: space))
    }

    var body: some View {
        Group {
            if viewModel.isLocked {
                lockedView
            } else {
                unlockedView
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(
                allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                onDocumentPicked: { url in
                    Task { await viewModel.importFile(from: url) }
                }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: imagePickerSource,
                onImagePicked: { image in
                    Task {
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent("\(UUID().uuidString).jpg")
                            try? imageData.write(to: tempURL)
                            await viewModel.importFile(from: tempURL)
                        }
                    }
                }
            )
        }
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    Task {
                        await viewModel.deleteFile(file)
                        fileToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { fileToDelete = nil }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete '\(file.displayName)'? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveFilesView(
                fileIds: Array(selectedFiles),
                currentSpace: space,
                allSpaces: [],
                onMove: { targetSpaceId in
                    Task {
                        await viewModel.moveFiles(Array(selectedFiles), to: targetSpaceId)
                        selectedFiles.removeAll()
                    }
                }
            )
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Space Locked")
                .font(.system(size: 24, weight: .bold))

            Text("This space is locked. Unlock to access files.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.unlockSpace() }
            } label: {
                Text("Unlock Now")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.32, green: 0.08, blue: 0.42), Color(red: 0.38, green: 0.1, blue: 0.48)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var unlockedView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.08, blue: 0.42),
                    Color(red: 0.38, green: 0.1, blue: 0.48),
                    Color(red: 0.28, green: 0.06, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if viewModel.files.isEmpty {
                    EmptySpaceView(
                        spaceName: space.name,
                        showDocumentPicker: $showDocumentPicker,
                        showImagePicker: $showImagePicker,
                        imagePickerSource: $imagePickerSource
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 20
                        ) {
                            ForEach(viewModel.files) { file in
                                FileCardView(
                                    file: file,
                                    isSelected: selectedFiles.contains(file.id),
                                    onSelect: {
                                        if selectedFiles.contains(file.id) {
                                            selectedFiles.remove(file.id)
                                        } else {
                                            selectedFiles.insert(file.id)
                                        }
                                    },
                                    onDelete: {
                                        fileToDelete = file
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            Text(space.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 12) {
                if !selectedFiles.isEmpty {
                    Button(action: { showMoveSheet = true }) {
                        Image(systemName: "folder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                    }

                    Button(action: {
                        Task {
                            for fileId in selectedFiles {
                                if let file = viewModel.files.first(where: { $0.id == fileId }) {
                                    await viewModel.deleteFile(file)
                                }
                            }
                            selectedFiles.removeAll()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                    }

                    Button(action: { selectedFiles.removeAll() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                } else {
                    Button(action: { /* optional selection mode */ }) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: Rectangle())
    }
}

// MARK: - Empty Space

struct EmptySpaceView: View {
    let spaceName: String
    @Binding var showDocumentPicker: Bool
    @Binding var showImagePicker: Bool
    @Binding var imagePickerSource: UIImagePickerController.SourceType

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.primary)

            VStack(spacing: 16) {
                Text("Ready to organize?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text("Start building your \(spaceName) space by adding your first file.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: { showDocumentPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                    Text("Add Your First File")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: 240)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.orange, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.orange.opacity(0.05))
                        )
                )
            }

            HStack(spacing: 24) {
                Button("Files") { showDocumentPicker = true }
                Button("Photos") {
                    showImagePicker = true
                    imagePickerSource = .photoLibrary
                }
                Button("Camera") {
                    showImagePicker = true
                    imagePickerSource = .camera
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - File Card (minimal)

struct FileCardView: View {
    let file: VaultFile
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: file.isImage ? "photo.fill" : (file.isPDF ? "doc.fill" : "doc.text.fill"))
                    .font(.system(size: 30))
                    .foregroundColor(.orange)

                Text(file.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource (required for document picker)
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Copy file to app's temporary directory so we can access it after the picker dismisses
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
            
            do {
                // Remove file if it already exists
                try? FileManager.default.removeItem(at: tempURL)
                
                // Copy file to temporary location
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Call callback with the temporary URL
                onDocumentPicked(tempURL)
            } catch {
                print("Failed to copy document: \(error.localizedDescription)")
                // Still try to use the original URL if copy fails
                onDocumentPicked(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
