//
//  FileGridView.swift
//  Just Vault
//
//  Grid view item for files with thumbnail
//

import SwiftUI

struct FileGridView: View {
    let file: VaultFile
    @State private var showPreview = false
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: {
            showPreview = true
        }) {
            VStack(spacing: 8) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 120)
                    
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        Image(systemName: iconForFile(file))
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // File name
                Text(file.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
        }
        .sheet(isPresented: $showPreview) {
            FilePreviewView(file: file)
        }
        .task {
            await loadThumbnail()
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
    
    private func loadThumbnail() async {
        // TODO: Load thumbnail from local storage or generate
        // For now, just use icon
    }
}




