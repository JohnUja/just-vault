//
//  VaultFileThumbnailView.swift
//  Just Vault
//
//  Reusable encrypted file thumbnail view for grid/list browsers.
//

import SwiftUI
import UIKit
import CoreGraphics

struct VaultFileThumbnailView: View {
    let file: VaultFile
    var cornerRadius: CGFloat = 12
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Rectangle()
                    .fill(AppTheme.cardBackground)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(AppTheme.accent)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                    )
            } else {
                Rectangle()
                    .fill(AppTheme.cardBackground)
                    .overlay {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: file.id) {
            await loadThumbnail()
        }
    }
    
    private var fallbackIcon: String {
        if file.isImage { return "photo.fill" }
        if file.isPDF { return "doc.richtext.fill" }
        return "doc.text.fill"
    }
    
    private func loadThumbnail() async {
        isLoading = true
        
        if let cached = await VaultFileThumbnailCache.shared.image(for: file.id) {
            await MainActor.run {
                thumbnailImage = cached
                isLoading = false
            }
            return
        }
        
        let storage = LocalStorageService()
        // If file is only in S3 (e.g. after reinstall), download so we can generate a thumbnail
        if !storage.fileExists(fileId: file.id), file.syncStatus == .synced {
            if let data = try? await S3Service.shared.downloadFile(key: file.s3Key) {
                _ = try? storage.saveEncryptedFile(data, fileId: file.id)
            }
        }
        // If we have a thumbnail in S3 but not locally (e.g. synced from another device), fetch it
        if let thumbKey = file.thumbnailS3Key,
           !storage.fileExists(fileId: "\(file.id)_thumb"),
           file.syncStatus == .synced,
           let thumbData = try? await S3Service.shared.downloadFile(key: thumbKey) {
            _ = try? storage.saveEncryptedFile(thumbData, fileId: "\(file.id)_thumb")
        }
        
        let fileId = file.id
        let isImage = file.isImage
        let isPDF = file.isPDF
        let generated = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            do {
                let storage = LocalStorageService()
                let encryption = EncryptionService()
                
                if isImage {
                    if let thumbData = try? storage.loadEncryptedFile(fileId: "\(fileId)_thumb") {
                        let decryptedThumb = try encryption.decryptFile(thumbData, fileId: "\(fileId)_thumb")
                        if let image = UIImage(data: decryptedThumb) {
                            return image
                        }
                    }
                }
                
                let encryptedData = try storage.loadEncryptedFile(fileId: fileId)
                let decryptedData = try encryption.decryptFile(encryptedData, fileId: fileId)
                
                if isImage {
                    return UIImage(data: decryptedData)
                }
                
                if isPDF {
                    return renderVaultPDFThumbnail(from: decryptedData)
                }
                
                return nil
            } catch {
                return nil
            }
        }.value
        
        if let generated {
            await VaultFileThumbnailCache.shared.setImage(generated, for: file.id)
        }
        
        await MainActor.run {
            thumbnailImage = generated
            isLoading = false
        }
    }
    
}

private func renderVaultPDFThumbnail(from data: Data) -> UIImage? {
    guard
        let provider = CGDataProvider(data: data as CFData),
        let document = CGPDFDocument(provider),
        let page = document.page(at: 1)
    else {
        return nil
    }
    
    let pageRect = page.getBoxRect(.mediaBox)
    let scale: CGFloat = 240.0 / max(pageRect.width, pageRect.height)
    let targetSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
    
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { context in
        context.cgContext.setFillColor(UIColor.white.cgColor)
        context.cgContext.fill(CGRect(origin: .zero, size: targetSize))
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: 0, y: targetSize.height)
        context.cgContext.scaleBy(x: scale, y: -scale)
        context.cgContext.drawPDFPage(page)
        context.cgContext.restoreGState()
    }
}

actor VaultFileThumbnailCache {
    static let shared = VaultFileThumbnailCache()
    
    private var cache: [String: UIImage] = [:]
    private let maxEntries = 100
    
    func image(for fileId: String) -> UIImage? {
        cache[fileId]
    }
    
    func setImage(_ image: UIImage, for fileId: String) {
        if cache.count >= maxEntries, let firstKey = cache.keys.first {
            cache.removeValue(forKey: firstKey)
        }
        cache[fileId] = image
    }
    
    func clear() {
        cache.removeAll()
    }
}
