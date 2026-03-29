//
//  FilesView.swift
//  Just Vault
//
//  All files view across all spaces
//

import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @EnvironmentObject var authService: AuthenticationService
    let spaces: [Space]
    
    @State private var sortOption: FileSortOption = .name
    @State private var sortDirection: SortDirection = .ascending
    @State private var viewMode: VaultFileBrowserMode = .grid
    @State private var cloudFilter: CloudFilterOption = .all
    @State private var previewFile: VaultFile?
    @State private var fileToDelete: VaultFile?
    @State private var fileToMove: VaultFile?
    @State private var fileToRename: VaultFile?
    @State private var renameText = ""
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                
                if viewModel.files.isEmpty {
                    EmptyFilesView()
                } else {
                    browserView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.setUserId(authService.currentUser?.id ?? "placeholder")
                viewModel.setSpaces(spaces)
                loadSavedSortState()
            }
            .onChange(of: spaces) { _, newSpaces in
                viewModel.setSpaces(newSpaces)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VaultFilesDidChange"))) { _ in
                viewModel.reloadFiles()
            }
            .sheet(item: $previewFile) { file in
                FilePreviewView(file: file)
            }
            .sheet(isPresented: $showMoveSheet) {
                MoveFilesView(
                    fileIds: fileToMove.map { [$0.id] } ?? [],
                    currentSpace: currentSpaceForMove,
                    allSpaces: spaces,
                    onMove: { targetSpaceId in
                        guard let file = fileToMove else { return }
                        Task {
                            await viewModel.moveFile(file, to: targetSpaceId)
                            fileToMove = nil
                        }
                    }
                )
            }
            .alert("Delete File", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    guard let file = fileToDelete else { return }
                    Task {
                        await viewModel.deleteFile(file)
                        fileToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    fileToDelete = nil
                }
            } message: {
                Text("Delete '\(fileToDelete?.displayName ?? "this file")'?")
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
                Text("Choose a new display name.")
            }
        }
    }
    
    private var browserView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBar
                if authService.currentUser?.hasCloudBackup ?? false {
                    VStack(alignment: .leading, spacing: 4) {
                        cloudFilterPicker
                        Text("Local only = on this device · Cloud = backed up")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 20)
                }
                
                if viewMode == .grid {
                    LazyVGrid(columns: gridColumns, spacing: 18) {
                        ForEach(filteredSortedFiles) { file in
                            VaultFileBrowserItemView(
                                file: file,
                                mode: .grid,
                                isPro: authService.currentUser?.isPro ?? false,
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredSortedFiles) { file in
                            VaultFileBrowserItemView(
                                file: file,
                                mode: .list,
                                isPro: authService.currentUser?.isPro ?? false,
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Files")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.headerTint)

            HStack(spacing: 10) {
                Text("\(filteredSortedFiles.count) \(filteredSortedFiles.count == 1 ? "file" : "files")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)

                Spacer()

                Button(action: toggleViewMode) {
                    Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(AppTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(AppTheme.outline, lineWidth: 1)
                                )
                        )
                }

                Menu {
                    sortMenuButton(for: .name, ascendingLabel: "Name A-Z", descendingLabel: "Name Z-A")
                    sortMenuButton(for: .date, ascendingLabel: "First Added", descendingLabel: "Last Added")
                    sortMenuButton(for: .size, ascendingLabel: "Smallest", descendingLabel: "Biggest")
                    sortMenuButton(for: .space, ascendingLabel: "Space A-Z", descendingLabel: "Space Z-A")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortButtonLabel)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(AppTheme.outline, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16, alignment: .top),
            GridItem(.flexible(), spacing: 16, alignment: .top)
        ]
    }
    
    private var sortedFiles: [VaultFile] {
        viewModel.sortedFiles(by: sortOption, direction: sortDirection)
    }

    /// All = every file. Cloud = backed up to cloud. Local = only on this device (not synced).
    private var filteredSortedFiles: [VaultFile] {
        sortedFiles.filter { file in
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

    private var cloudFilterPicker: some View {
        Picker("Storage Filter", selection: $cloudFilter) {
            ForEach(CloudFilterOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var sortButtonLabel: String {
        switch (sortOption, sortDirection) {
        case (.name, .ascending): return "Name A-Z"
        case (.name, .descending): return "Name Z-A"
        case (.date, .ascending): return "First Added"
        case (.date, .descending): return "Last Added"
        case (.size, .ascending): return "Smallest"
        case (.size, .descending): return "Biggest"
        case (.space, .ascending): return "Space A-Z"
        case (.space, .descending): return "Space Z-A"
        }
    }
    
    private var currentSpaceForMove: Space {
        guard
            let file = fileToMove,
            let space = spaces.first(where: { $0.id == file.spaceId })
        else {
            return Space.create(userId: authService.currentUser?.id ?? "placeholder", name: "Current Space")
        }
        return space
    }
    
    private func toggleViewMode() {
        viewMode = viewMode == .grid ? .list : .grid
        saveSortState()
    }
    
    private func toggleSort(for option: FileSortOption) {
        if sortOption == option {
            sortDirection = sortDirection == .ascending ? .descending : .ascending
        } else {
            sortOption = option
            switch option {
            case .name, .space:
                sortDirection = .ascending
            case .date, .size:
                sortDirection = .descending
            }
        }
        saveSortState()
    }
    
    @ViewBuilder
    private func sortMenuButton(for option: FileSortOption, ascendingLabel: String, descendingLabel: String) -> some View {
        Button {
            toggleSort(for: option)
        } label: {
            Label(
                sortOption == option && sortDirection == .descending ? descendingLabel : ascendingLabel,
                systemImage: sortOption == option ? "checkmark" : "circle"
            )
        }
    }
    
    private func loadSavedSortState() {
        if let savedSort = UserDefaults.standard.string(forKey: "fileSortOption"),
           let option = FileSortOption.allCases.first(where: { $0.rawValue == savedSort }) {
            sortOption = option
        }
        
        if let savedDirection = UserDefaults.standard.string(forKey: "fileSortDirection"),
           let direction = SortDirection(rawValue: savedDirection) {
            sortDirection = direction
        }
        
        if let savedMode = UserDefaults.standard.string(forKey: "fileViewMode") {
            viewMode = savedMode == "list" ? .list : .grid
        }
    }
    
    private func saveSortState() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: "fileSortOption")
        UserDefaults.standard.set(sortDirection.rawValue, forKey: "fileSortDirection")
        UserDefaults.standard.set(viewMode == .grid ? "grid" : "list", forKey: "fileViewMode")
    }
}

enum SortDirection: String {
    case ascending
    case descending
}

struct EmptyFilesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(AppTheme.accent.opacity(0.4))
                .padding(18)
                .background(
                    Circle().fill(AppTheme.accent.opacity(0.06))
                )
            
            Text("No Files Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.headerTint)
            
            Text("Files you add to your spaces will appear here")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
class FilesViewModel: ObservableObject {
    @Published var files: [VaultFile] = []
    private var userId: String = "placeholder"
    private var allSpaces: [Space] = []
    
    func sortedFiles(by option: FileSortOption, direction: SortDirection) -> [VaultFile] {
        var sorted = files
        switch option {
        case .name:
            sorted.sort { direction == .ascending ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending }
        case .date:
            sorted.sort { direction == .ascending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .size:
            sorted.sort { direction == .ascending ? $0.sizeBytes < $1.sizeBytes : $0.sizeBytes > $1.sizeBytes }
        case .space:
            sorted.sort { lhsFile, rhsFile in
                let lhs = allSpaces.first(where: { $0.id == lhsFile.spaceId })?.name ?? lhsFile.spaceId
                let rhs = allSpaces.first(where: { $0.id == rhsFile.spaceId })?.name ?? rhsFile.spaceId
                return direction == .ascending
                    ? lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                    : lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
            }
        }
        return sorted
    }
    
    var filesGroupedBySpace: [FileGroup] {
        Dictionary(grouping: files) { $0.spaceId }
            .map { spaceId, files in
                // Get space info
                let space = allSpaces.first { $0.id == spaceId }
                return FileGroup(
                    spaceId: spaceId,
                    spaceName: space?.name ?? "Unknown",
                    spaceIcon: space?.icon ?? "folder.fill",
                    spaceColor: space?.color ?? "#2A7C7B",
                    files: files
                )
            }
            .sorted { $0.spaceName < $1.spaceName }
    }
    
    init() {
        // Don't load until userId is set
    }
    
    func setUserId(_ id: String) {
        userId = id
        loadFiles()
    }
    
    /// Call after file import so All Files list updates
    func reloadFiles() {
        loadFiles()
    }
    
    func setSpaces(_ spaces: [Space]) {
        allSpaces = spaces
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
        await loadFilesAsync()
    }
    
    func moveFile(_ file: VaultFile, to targetSpaceId: String) async {
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
        
        try? LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: file.userId, oldSpaceId: file.spaceId)
        try? await DynamoDBService.shared.saveFileMetadata(updatedFile)
        await loadFilesAsync()
    }
    
    func deleteFile(_ file: VaultFile) async {
        let localStorage = LocalStorageService()
        try? localStorage.deleteEncryptedFile(fileId: file.id)
        try? localStorage.deleteEncryptedFile(fileId: "\(file.id)_thumb")
        LocalFileMetadataService.shared.deleteFileMetadata(fileId: file.id, userId: file.userId, spaceId: file.spaceId)
        try? await DynamoDBService.shared.deleteFileMetadata(userId: file.userId, fileId: file.id)
        try? await S3Service.shared.deleteFile(key: file.s3Key)
        if let thumbnailKey = file.thumbnailS3Key {
            try? await S3Service.shared.deleteFile(key: thumbnailKey)
        }
        await SyncService.shared.reconcileCloudStateNow(lastSyncAt: Date())
        
        await loadFilesAsync()
    }

    func removeFileFromCloud(_ file: VaultFile) async {
        do {
            try await SyncService.shared.removeFileFromCloud(file)
        } catch {
            print("Failed to remove file from cloud: \(error.localizedDescription)")
        }

        await loadFilesAsync()
    }
    
    private func loadFiles() {
        Task {
            await loadFilesAsync()
        }
    }
    
    private func loadFilesAsync() async {
        guard userId != "placeholder" else { return }
        
        var allFiles: [VaultFile] = []
        
        // Always load from local storage first (works for all users)
        do {
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            allFiles = localFiles
        } catch {
            print("Failed to load local files: \(error.localizedDescription)")
        }
        
        // Try to load from DynamoDB (for Pro users) and merge
        do {
            let cloudFiles = try await DynamoDBService.shared.loadAllFiles(userId: userId)
            var mergedById = Dictionary(uniqueKeysWithValues: allFiles.map { ($0.id, $0) })
            for file in cloudFiles {
                mergedById[file.id] = file
                try? LocalFileMetadataService.shared.saveFileMetadata(file, userId: userId)
            }
            allFiles = Array(mergedById.values)
        } catch {
            // If DynamoDB fails (free user or no connection), use local files only
            let message = error.localizedDescription
            if !message.contains("Cloud sync is only available") {
                print("Failed to load cloud files: \(message)")
            }
        }
        
        await MainActor.run {
            files = allFiles
        }
    }
}

struct FileGroup {
    let spaceId: String
    let spaceName: String
    let spaceIcon: String
    let spaceColor: String
    let files: [VaultFile]
}

#Preview {
    FilesView(spaces: [])
}

