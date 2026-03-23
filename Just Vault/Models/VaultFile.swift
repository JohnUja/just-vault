//
//  VaultFile.swift
//  Just Vault
//
//  File model representing a document in the vault
//

import Foundation

struct VaultFile: Codable, Identifiable {
    let id: String
    let userId: String
    let spaceId: String
    let displayName: String
    let sizeBytes: Int64
    let mimeType: String
    let createdAt: Date
    let lastOpenedAt: Date?
    let starred: Bool
    
    // Storage paths
    let localPath: String // Relative to app sandbox
    let s3Key: String // S3 object key
    
    // Sync status
    var syncStatus: SyncStatus
    var version: Int
    
    // Optional thumbnail
    let thumbnailS3Key: String?
    
    var sizeMB: Double {
        Double(sizeBytes) / 1_000_000.0
    }
    
    var fileExtension: String {
        (displayName as NSString).pathExtension.lowercased()
    }
    
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
    
    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    /// Returns a copy of this file with a different spaceId (e.g. when moving to another space).
    func with(spaceId newSpaceId: String) -> VaultFile {
        VaultFile(
            id: id,
            userId: userId,
            spaceId: newSpaceId,
            displayName: displayName,
            sizeBytes: sizeBytes,
            mimeType: mimeType,
            createdAt: createdAt,
            lastOpenedAt: lastOpenedAt,
            starred: starred,
            localPath: localPath,
            s3Key: s3Key,
            syncStatus: syncStatus,
            version: version,
            thumbnailS3Key: thumbnailS3Key
        )
    }
}

enum SyncStatus: String, Codable {
    case pending
    case syncing
    case synced
    case error
    case localOnly
}

