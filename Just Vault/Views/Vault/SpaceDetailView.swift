//
//  SpaceDetailView.swift
//  Just Vault
//
//  Detail view for a specific space showing its files
//

import SwiftUI

struct SpaceDetailView: View {
    let space: Space
    @StateObject private var viewModel: SpaceDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    init(space: Space) {
        self.space = space
        _viewModel = StateObject(wrappedValue: SpaceDetailViewModel(space: space))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Text(space.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // Files Grid/List
            if viewModel.files.isEmpty {
                EmptySpaceView(spaceName: space.name)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.files) { file in
                            FileCardView(file: file)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.grid.2x2")
                }
            }
        }
    }
}

struct EmptySpaceView: View {
    let spaceName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("\(spaceName) is Empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to add files")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {}) {
                Label("Add Files", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top)
            
            Spacer()
        }
    }
}

struct FileCardView: View {
    let file: VaultFile
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: iconForFile(file))
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(height: 60)
                
                Text(file.displayName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
class SpaceDetailViewModel: ObservableObject {
    let space: Space
    @Published var files: [VaultFile] = []
    
    init(space: Space) {
        self.space = space
        loadFiles()
    }
    
    private func loadFiles() {
        // TODO: Load files for this space from local storage or DynamoDB
        files = []
    }
}

#Preview {
    SpaceDetailView(space: Space.create(
        userId: "test",
        name: "Work",
        icon: "briefcase.fill",
        color: "#007AFF"
    ))
}

