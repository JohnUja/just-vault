//
//  SearchView.swift
//  Just Vault
//
//  Search functionality for files and spaces
//

import SwiftUI

struct SearchView: View {
    let spaces: [Space]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    @State private var searchText = ""
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search files and spaces...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { oldValue, newValue in
                            Task {
                                await viewModel.search(
                                    query: newValue,
                                    spaces: spaces,
                                    userId: authService.currentUser?.id ?? ""
                                )
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // Results
                if searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Search files and spaces")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.matchingSpaces.isEmpty && viewModel.matchingFiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Spaces
                        if !viewModel.matchingSpaces.isEmpty {
                            Section("Spaces") {
                                ForEach(viewModel.matchingSpaces) { space in
                                    SpaceSearchResultRow(space: space)
                                }
                            }
                        }
                        
                        // Files
                        if !viewModel.matchingFiles.isEmpty {
                            Section("Files") {
                                ForEach(viewModel.matchingFiles) { file in
                                    FileSearchResultRow(file: file)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SpaceSearchResultRow: View {
    let space: Space
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: space.color))
                    .frame(width: 40, height: 40)
                
                Image(systemName: space.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(space.name)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("\(space.fileCount) files")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct FileSearchResultRow: View {
    let file: VaultFile
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.isPDF ? "doc.fill" : file.isImage ? "photo.fill" : "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.system(size: 16, weight: .medium))
                
                Text("\(String(format: "%.1f", file.sizeMB)) MB")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var matchingSpaces: [Space] = []
    @Published var matchingFiles: [VaultFile] = []
    @Published var isSearching = false
    
    func search(query: String, spaces: [Space], userId: String) async {
        guard !query.isEmpty else {
            matchingSpaces = []
            matchingFiles = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        let lowerQuery = query.lowercased()
        
        // Search spaces
        matchingSpaces = spaces.filter { space in
            space.name.lowercased().contains(lowerQuery) ||
            space.icon.lowercased().contains(lowerQuery)
        }
        
        // Search files - try local first, then cloud
        do {
            // Try loading from local storage first (works for all users)
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            matchingFiles = localFiles.filter { file in
                file.displayName.lowercased().contains(lowerQuery)
            }
        } catch {
            print("Failed to load files from local storage: \(error.localizedDescription)")
        }
        
        // If user has cloud backup, also try DynamoDB
        do {
            let cloudFiles = try await DynamoDBService.shared.loadAllFiles(userId: userId)
            let cloudMatches = cloudFiles.filter { file in
                file.displayName.lowercased().contains(lowerQuery)
            }
            
            // Merge results, avoiding duplicates
            let existingIds = Set(matchingFiles.map { $0.id })
            let newFiles = cloudMatches.filter { !existingIds.contains($0.id) }
            matchingFiles.append(contentsOf: newFiles)
        } catch {
            // Free user or no connection - that's okay
            print("Cloud search not available: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SearchView(spaces: [])
}

