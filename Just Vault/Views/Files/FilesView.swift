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
    let spaces: [Space] // Pass from parent
    @State private var sortOption: FileSortOption = .name
    @State private var showFilterSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - royal/wine purple
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
                
                if viewModel.files.isEmpty {
                    EmptyFilesView()
                } else {
                    // Preview grid layout (like JustScan homepage)
                    previewGridView
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilterSheet) {
                FileFilterSheet(
                    sortOption: $sortOption,
                    onApply: {
                        viewModel.sortFiles(by: sortOption)
                        // Update viewModel's internal sort option
                        viewModel.updateSortOption(sortOption)
                    }
                )
            }
            .onAppear {
                viewModel.setUserId(authService.currentUser?.id ?? "placeholder")
                viewModel.setSpaces(spaces)
                if let savedSort = UserDefaults.standard.string(forKey: "fileSortOption"),
                   let option = FileSortOption.allCases.first(where: { $0.rawValue == savedSort }) {
                    sortOption = option
                }
            }
            .onChange(of: spaces) { oldSpaces, newSpaces in
                viewModel.setSpaces(newSpaces)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VaultFilesDidChange"))) { _ in
                viewModel.reloadFiles()
            }
        }
    }
    
    // Preview grid layout (like JustScan homepage)
    private var previewGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with sort and filter options
                HStack {
                    Text("All Files")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Filter button
                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // File preview grid (3 columns like JustScan)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(viewModel.getSortedFiles(by: sortOption)) { file in
                        RecentFileCard(file: file)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

enum FileViewMode {
    case grid
    case list
}

// FileSortOption enum moved to FileFilterSheet.swift for shared access

struct EmptyFilesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.7))
            
            Text("No Files Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add files to your spaces to see them here")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileRowView: View {
    let file: VaultFile
    @State private var showPreview = false
    
    var body: some View {
        Button(action: {
            showPreview = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconForFile(file))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(file.sizeMB, specifier: "%.1f") MB")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if file.starred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
        .sheet(isPresented: $showPreview) {
            FilePreviewView(file: file)
        }
    }
    
    private func iconForFile(_ file: VaultFile) -> String {
        if file.isImage {
            return "photo.fill"
        } else if file.isPDF {
            return "doc.fill"
        } else {
            return "doc.text.fill"
        }
    }
}

@MainActor
class FilesViewModel: ObservableObject {
    @Published var files: [VaultFile] = []
    private var userId: String = "placeholder"
    private var allSpaces: [Space] = []
    
    func getSortedFiles(by option: FileSortOption) -> [VaultFile] {
        var sorted = files
        switch option {
        case .name:
            sorted.sort { $0.displayName < $1.displayName }
        case .date:
            sorted.sort { $0.createdAt > $1.createdAt }
        case .size:
            sorted.sort { $0.sizeBytes > $1.sizeBytes }
        case .space:
            sorted.sort { $0.spaceId < $1.spaceId }
        }
        return sorted
    }
    
    func updateSortOption(_ option: FileSortOption) {
        // Store sort option for persistence
        UserDefaults.standard.set(option.rawValue, forKey: "fileSortOption")
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
                    spaceColor: space?.color ?? "#007AFF",
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
    
    func sortFiles(by option: FileSortOption) {
        switch option {
        case .name:
            files.sort { $0.displayName < $1.displayName }
        case .date:
            files.sort { $0.createdAt > $1.createdAt }
        case .size:
            files.sort { $0.sizeBytes > $1.sizeBytes }
        case .space:
            files.sort { $0.spaceId < $1.spaceId }
        }
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
            let localIds = Set(allFiles.map { $0.id })
            let newFiles = cloudFiles.filter { !localIds.contains($0.id) }
            allFiles.append(contentsOf: newFiles)
        } catch {
            // If DynamoDB fails (free user or no connection), use local files only
            print("Cloud sync not available: \(error.localizedDescription)")
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

