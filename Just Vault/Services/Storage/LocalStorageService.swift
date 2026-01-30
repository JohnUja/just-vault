//
//  LocalStorageService.swift
//  Just Vault
//
//  Manages local file storage in app sandbox
//

import Foundation

class LocalStorageService {
    private let fileManager = FileManager.default
    
    /// Base directory for vault files
    private var vaultDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Vault", isDirectory: true)
    }
    
    /// Directory for encrypted files
    private var filesDirectory: URL {
        vaultDirectory.appendingPathComponent("files", isDirectory: true)
    }
    
    /// Directory for metadata
    private var metadataDirectory: URL {
        vaultDirectory.appendingPathComponent("metadata", isDirectory: true)
    }
    
    init() {
        createDirectoriesIfNeeded()
    }
    
    /// Create directory structure if it doesn't exist
    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    }
    
    /// Save encrypted file to local storage
    func saveEncryptedFile(_ data: Data, fileId: String) throws -> URL {
        let fileURL = filesDirectory.appendingPathComponent("\(fileId).enc")
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Load encrypted file from local storage
    func loadEncryptedFile(fileId: String) throws -> Data {
        let fileURL = filesDirectory.appendingPathComponent("\(fileId).enc")
        return try Data(contentsOf: fileURL)
    }
    
    /// Delete encrypted file
    func deleteEncryptedFile(fileId: String) throws {
        let fileURL = filesDirectory.appendingPathComponent("\(fileId).enc")
        try fileManager.removeItem(at: fileURL)
    }
    
    /// Get file URL for a file ID
    func getFileURL(fileId: String) -> URL {
        return filesDirectory.appendingPathComponent("\(fileId).enc")
    }
    
    /// Check if file exists
    func fileExists(fileId: String) -> Bool {
        let fileURL = filesDirectory.appendingPathComponent("\(fileId).enc")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Get all encrypted file IDs
    func getAllFileIds() throws -> [String] {
        let files = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: nil)
        return files
            .filter { $0.pathExtension == "enc" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
    
    /// Calculate total storage used
    func calculateStorageUsed() throws -> Int64 {
        let files = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        var totalSize: Int64 = 0
        for file in files {
            if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
}

