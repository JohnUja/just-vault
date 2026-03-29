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
    @Published var importError: String?

    var userTier: SubscriptionTier {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let data = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return .free
        }
        return user.effectiveTier
    }

    init(space: Space) {
        self.space = space
        self.isLocked = space.isLocked
        loadFiles()
    }

    func unlockSpace() async {
        if !AppPreferences.faceIDEnabled {
            isLocked = false
            return
        }

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

    /// Call from view when vault files change (e.g. after sync) so file list and sync badges refresh.
    func refreshFilesFromNotification() {
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
                var mergedById = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
                for file in cloudFiles {
                    mergedById[file.id] = file
                }
                files = Array(mergedById.values)
            }
        } catch {
            print("Cloud sync not available: \(error.localizedDescription)")
        }
    }

    func importFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let tier = userTier
            let limit = tier.maxFileSizeBytes
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            if fileSize > limit {
                await MainActor.run {
                    importError = "File exceeds \(tier.maxFileSizeMB) MB limit for \(tier.displayName) plan. \(tier == .free ? "Upgrade to Pro for 100 MB." : tier == .pro ? "Upgrade to Pro+ for 500 MB." : "")"
                }
                return
            }

            let ext = url.pathExtension.lowercased()
            let videoExts = ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "webm"]
            if videoExts.contains(ext) {
                await MainActor.run {
                    importError = "Video files are not supported in this version."
                }
                return
            }

            let vaultFile = try await FileImportService.shared.importFile(
                url: url,
                spaceId: space.id,
                userId: space.userId
            )

            try LocalFileMetadataService.shared.saveFileMetadata(vaultFile, userId: space.userId)

            do {
                if AppPreferences.cloudBackupEnabled {
                try await DynamoDBService.shared.saveFileMetadata(vaultFile)
                SyncService.shared.queueFileForSync(vaultFile)
                }
            } catch {
                print("File saved locally only: \(error.localizedDescription)")
            }

            await MainActor.run { files.append(vaultFile) }
            await loadFilesAsync()
        } catch {
            await MainActor.run {
                importError = "Failed to import: \(error.localizedDescription)"
            }
        }
    }

    func deleteFile(_ file: VaultFile) async {
            let localStorage = LocalStorageService()
        try? localStorage.deleteEncryptedFile(fileId: file.id)

            let thumbnailId = "\(file.id)_thumb"
            try? localStorage.deleteEncryptedFile(fileId: thumbnailId)

            try? await DynamoDBService.shared.deleteFileMetadata(userId: file.userId, fileId: file.id)
        LocalFileMetadataService.shared.deleteFileMetadata(fileId: file.id, userId: file.userId, spaceId: file.spaceId)

            try? await S3Service.shared.deleteFile(key: file.s3Key)
            if let thumbnailKey = file.thumbnailS3Key {
                try? await S3Service.shared.deleteFile(key: thumbnailKey)
            }

        await SyncService.shared.reconcileCloudStateNow(lastSyncAt: Date())

            await MainActor.run {
                files.removeAll { $0.id == file.id }
            }
    }

    func removeFileFromCloud(_ file: VaultFile) async {
        do {
            try await SyncService.shared.removeFileFromCloud(file)
            await loadFilesAsync()
        } catch {
            print("Failed to remove file from cloud: \(error.localizedDescription)")
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

            try? LocalFileMetadataService.shared.updateFileMetadata(
                updatedFile,
                userId: file.userId,
                oldSpaceId: file.spaceId
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
    
    func renameFile(_ file: VaultFile, to newDisplayName: String) async {
        let trimmedName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let renamedFile = VaultFile(
            id: file.id,
            userId: file.userId,
            spaceId: file.spaceId,
            displayName: trimmedName,
            sizeBytes: file.sizeBytes,
            mimeType: file.mimeType,
            createdAt: file.createdAt,
            lastOpenedAt: file.lastOpenedAt,
            starred: file.starred,
            localPath: file.localPath,
            s3Key: file.s3Key,
            syncStatus: file.syncStatus,
            version: file.version + 1,
            thumbnailS3Key: file.thumbnailS3Key
        )
        
        try? LocalFileMetadataService.shared.updateFileMetadata(renamedFile, userId: file.userId)
        try? await DynamoDBService.shared.saveFileMetadata(renamedFile)
        
        await MainActor.run {
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files[index] = renamedFile
            }
        }
    }
}

// MARK: - View

struct SpaceDetailView: View {
    let space: Space
    let allSpaces: [Space]
    @StateObject private var viewModel: SpaceDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showMoveSheet = false
    @State private var fileToDelete: VaultFile?
    @State private var fileToMove: VaultFile?
    @State private var fileToRename: VaultFile?
    @State private var renameText = ""
    @State private var previewFile: VaultFile?
    @State private var showDeleteConfirmation = false
    @State private var viewMode: VaultFileBrowserMode = .grid
    @State private var sortOption: FileSortOption = .date
    @State private var sortDirection: SortDirection = .descending
    @State private var cloudFilter: CloudFilterOption = .all

    private var isPro: Bool {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let data = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return false }
        return user.isPro
    }

    private var hasCloudBackup: Bool {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let data = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return false }
        return user.hasCloudBackup
    }

    init(space: Space, allSpaces: [Space] = []) {
        self.space = space
        self.allSpaces = allSpaces
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
                allowedContentTypes: viewModel.userTier.allowedContentTypes,
                onDocumentPicked: { url in
                    showDocumentPicker = false
                    Task { await viewModel.importFile(from: url) }
                },
                onCancel: { showDocumentPicker = false }
            )
        }
        .alert("Import Error", isPresented: Binding(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        )) {
            Button("OK") { viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "")
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: imagePickerSource,
                onImagePicked: { image in
                    Task {
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                            let fileName = "Photo \(formatter.string(from: Date())).jpg"
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(fileName)
                            try? imageData.write(to: tempURL)
                            await viewModel.importFile(from: tempURL)
                        }
                    }
                },
                onCancel: { showImagePicker = false }
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
        .alert("Rename File", isPresented: Binding(
            get: { fileToRename != nil },
            set: { if !$0 { fileToRename = nil } }
        )) {
            TextField("File name", text: $renameText)
            Button("Save") {
                guard let file = fileToRename else { return }
                Task {
                    await viewModel.renameFile(file, to: renameText)
                    fileToRename = nil
                }
            }
            Button("Cancel", role: .cancel) {
                fileToRename = nil
            }
        } message: {
            Text("Choose a new display name for this file.")
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveFilesView(
                fileIds: fileToMove.map { [$0.id] } ?? [],
                currentSpace: space,
                allSpaces: allSpaces,
                onMove: { targetSpaceId in
                    guard let file = fileToMove else { return }
                    Task {
                        await viewModel.moveFiles([file.id], to: targetSpaceId)
                        fileToMove = nil
                    }
                }
            )
        }
        .sheet(item: $previewFile) { file in
            FilePreviewView(file: file)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultFilesDidChange)) { _ in
            viewModel.refreshFilesFromNotification()
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: space.icon)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color(hex: space.color).opacity(0.7))
                .padding(24)
                .background(
                    Circle()
                        .fill(Color(hex: space.color).opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color(hex: space.color).opacity(0.2), lineWidth: 1)
                        )
                )

            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.secondaryText)
                .padding(.top, 4)

            Text("\(space.name) is locked")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.headerTint)

            Text("Authenticate to access your files")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)

            Button {
                Task { await viewModel.unlockSpace() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 16))
                    Text("Unlock")
                        .font(.system(size: 15, weight: .semibold))
                }
                    .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(AppTheme.accentGradient)
                .cornerRadius(20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private var unlockedView: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

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
                    spaceToolbar

                    ScrollView {
                        if viewMode == .grid {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 14, alignment: .top),
                                GridItem(.flexible(), spacing: 14, alignment: .top)
                            ],
                            spacing: 16
                        ) {
                                ForEach(sortedSpaceFiles) { file in
                                    spaceFileItem(file)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.vertical, 12)
                                        } else {
                            VStack(spacing: 10) {
                                ForEach(sortedSpaceFiles) { file in
                                    spaceFileItem(file, mode: .list)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(
                        ZStack {
                            AppTheme.background
                            Color(hex: space.color).opacity(0.03)
                        }
                    )
                }
            }
        }
    }

    private var sortedSpaceFiles: [VaultFile] {
        var sorted = viewModel.files
        switch sortOption {
        case .name:
            sorted.sort { sortDirection == .ascending ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending }
        case .date:
            sorted.sort { sortDirection == .ascending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .size:
            sorted.sort { sortDirection == .ascending ? $0.sizeBytes < $1.sizeBytes : $0.sizeBytes > $1.sizeBytes }
        case .space:
            break
        }
        return sorted.filter { file in
            switch cloudFilter {
            case .all:
                return true
            case .cloud:
                return file.syncStatus == .synced
            case .local:
                return file.syncStatus != .synced
            }
        }
    }

    private func spaceFileItem(_ file: VaultFile, mode: VaultFileBrowserMode = .grid) -> some View {
        VaultFileBrowserItemView(
            file: file,
            mode: mode,
            isPro: isPro,
            onOpen: { previewFile = file },
            onPreview: { previewFile = file },
            onMove: {
                fileToMove = file
                showMoveSheet = true
            },
            onRename: {
                fileToRename = file
                renameText = file.displayName
            },
            onDelete: {
                fileToDelete = file
                showDeleteConfirmation = true
            },
            onCloudUpload: {
                SyncService.shared.queueFileForSync(file, force: true)
            },
            onCloudDelete: {
                Task { await viewModel.removeFileFromCloud(file) }
            }
        )
    }

    private var spaceToolbar: some View {
        HStack(spacing: 10) {
            Text("\(sortedSpaceFiles.count) \(sortedSpaceFiles.count == 1 ? "file" : "files")")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText)

            Spacer()

            if hasCloudBackup {
                Picker("Storage Filter", selection: $cloudFilter) {
                    ForEach(CloudFilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            Button {
                viewMode = viewMode == .grid ? .list : .grid
            } label: {
                Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.outline, lineWidth: 1))
                    )
            }

            Menu {
                Button { toggleSpaceSort(.name) } label: {
                    Label("Name", systemImage: sortOption == .name ? "checkmark" : "circle")
                }
                Button { toggleSpaceSort(.date) } label: {
                    Label("Date", systemImage: sortOption == .date ? "checkmark" : "circle")
                }
                Button { toggleSpaceSort(.size) } label: {
                    Label("Size", systemImage: sortOption == .size ? "checkmark" : "circle")
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.outline, lineWidth: 1))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func toggleSpaceSort(_ option: FileSortOption) {
        if sortOption == option {
            sortDirection = sortDirection == .ascending ? .descending : .ascending
        } else {
            sortOption = option
            sortDirection = option == .name ? .ascending : .descending
        }
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.headerTint)
                }

                Image(systemName: space.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle().fill(Color(hex: space.color).opacity(0.8))
                    )

                Text(space.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.headerTint)

                Spacer()

                Menu {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Files", systemImage: "doc")
                    }
                    Button {
                        imagePickerSource = .photoLibrary
                        showImagePicker = true
                    } label: {
                        Label("Photos", systemImage: "photo")
                    }
                    Button {
                        imagePickerSource = .camera
                        showImagePicker = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: space.color))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color(hex: space.color).opacity(0.12))
                .frame(height: 3)
        }
        .background(AppTheme.cardBackground)
    }
}

// MARK: - Empty Space

struct EmptySpaceView: View {
    let spaceName: String
    @Binding var showDocumentPicker: Bool
    @Binding var showImagePicker: Bool
    @Binding var imagePickerSource: UIImagePickerController.SourceType

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(AppTheme.accent.opacity(0.5))
                    .padding(20)
                    .background(
                        Circle()
                            .fill(AppTheme.accent.opacity(0.08))
                    )

                Text("Your \(spaceName) space is ready")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)

                Text("Tap + above to add your first file")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            HStack(spacing: 16) {
                emptyStateButton(icon: "doc", label: "Files") {
                    showDocumentPicker = true
                }
                emptyStateButton(icon: "photo", label: "Photos") {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }
                emptyStateButton(icon: "camera", label: "Camera") {
                    imagePickerSource = .camera
                    showImagePicker = true
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyStateButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.accent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1.5)
                    )
            )
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    /// Called when the user cancels; clears SwiftUI sheet/fullScreenCover so it doesn’t stick on a blank screen.
    var onCancel: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        let onCancel: (() -> Void)?

        init(onDocumentPicked: @escaping (URL) -> Void, onCancel: (() -> Void)?) {
            self.onDocumentPicked = onDocumentPicked
            self.onCancel = onCancel
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
                .appendingPathComponent(url.lastPathComponent)
            
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

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel?()
        }
    }
}
