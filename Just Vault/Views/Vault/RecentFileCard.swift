//
//  RecentFileCard.swift
//  Just Vault
//
//  Recent file preview card for homepage (like JustScan)
//

import SwiftUI

struct RecentFileCard: View {
    let file: VaultFile
    @State private var thumbnail: UIImage?
    @State private var showPreview = false
    
    var body: some View {
        Button(action: {
            showPreview = true
        }) {
            VStack(spacing: 8) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 120)
                    
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 120)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        Image(systemName: iconForFile(file))
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // File name
                Text(file.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 100)
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
        // Try to load thumbnail from local storage
        do {
            let thumbnailData = try LocalStorageService().loadEncryptedFile(fileId: "\(file.id)_thumb")
            let decrypted = try EncryptionService().decryptFile(thumbnailData, fileId: "\(file.id)_thumb")
            if let image = UIImage(data: decrypted) {
                await MainActor.run {
                    thumbnail = image
                }
            }
        } catch {
            // No thumbnail available - that's okay
        }
    }
}

