//
//  FileImportService.swift
//  Just Vault
//
//  Handles file import with encryption
//

import Foundation
import UIKit
import UniformTypeIdentifiers

class FileImportService {
    static let shared = FileImportService()
    
    private let encryptionService = EncryptionService()
    private let localStorage = LocalStorageService()
    
    private init() {}
    
    /// Import a file from URL, encrypt it, and save locally
    func importFile(url: URL, spaceId: String, userId: String) async throws -> VaultFile {
        // Step 1: Read file data from URL
        let fileData = try Data(contentsOf: url)
        
        // Step 2: Get file metadata
        let fileName = url.lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let mimeType = mimeTypeForExtension(fileExtension)
        
        // Step 3: Generate file ID
        let fileId = UUID().uuidString
        
        // Step 4: Encrypt file using EncryptionService
        let encryptedData = try encryptionService.encryptFile(fileData, fileId: fileId)
        
        // Step 5: Save encrypted file to local storage
        let localFileURL = try localStorage.saveEncryptedFile(encryptedData, fileId: fileId)
        
        // Step 6: Generate thumbnail (if image)
        var thumbnailS3Key: String? = nil
        if mimeType.hasPrefix("image/") {
            if let thumbnail = generateThumbnail(for: fileData) {
                // Encrypt thumbnail
                let thumbnailId = "\(fileId)_thumb"
                if let encryptedThumbnail = try? encryptionService.encryptFile(thumbnail, fileId: thumbnailId) {
                    _ = try? localStorage.saveEncryptedFile(encryptedThumbnail, fileId: thumbnailId)
                    thumbnailS3Key = S3Service.generateThumbnailS3Key(identityId: userId, fileId: fileId)
                }
            }
        }
        
        // Step 7: Create VaultFile model
        let s3Key = S3Service.generateS3Key(identityId: userId, fileId: fileId)
        
        let vaultFile = VaultFile(
            id: fileId,
            userId: userId,
            spaceId: spaceId,
            displayName: fileName,
            sizeBytes: Int64(fileData.count),
            mimeType: mimeType,
            createdAt: Date(),
            lastOpenedAt: nil,
            starred: false,
            localPath: localFileURL.path,
            s3Key: s3Key,
            syncStatus: .pending,
            version: 1,
            thumbnailS3Key: thumbnailS3Key
        )
        
        return vaultFile
    }
    
    /// Generate thumbnail for image data
    func generateThumbnail(for imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        // Calculate thumbnail size (max 200x200, maintaining aspect ratio)
        let maxSize: CGFloat = 200
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var thumbnailSize: CGSize
        if size.width > size.height {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        guard let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // Compress to JPEG
        return thumbnailImage.jpegData(compressionQuality: 0.8)
    }
    
    /// Get MIME type for file extension
    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic", "heif":
            return "image/heic"
        default:
            return "application/octet-stream"
        }
    }
}

