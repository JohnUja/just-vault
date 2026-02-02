//
//  FilesView.swift
//  Just Vault
//
//  All files view across all spaces
//

import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.files.isEmpty {
                    EmptyFilesView()
                } else {
                    List {
                        ForEach(viewModel.files) { file in
                            FileRowView(file: file)
                        }
                    }
                }
            }
            .navigationTitle("All Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
        }
    }
}

struct EmptyFilesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Files Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add files to your spaces to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct FileRowView: View {
    let file: VaultFile
    
    var body: some View {
        HStack {
            Image(systemName: iconForFile(file))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.body)
                
                Text("\(file.sizeMB, specifier: "%.1f") MB • \(file.spaceId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if file.starred {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
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
    
    init() {
        loadFiles()
    }
    
    private func loadFiles() {
        // TODO: Load from local storage or DynamoDB
        files = []
    }
}

#Preview {
    FilesView()
}

