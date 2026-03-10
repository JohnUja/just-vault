//
//  LocalFileMetadataService.swift
//  Just Vault
//
//  Manages local file metadata storage for free users
//

import Foundation

class LocalFileMetadataService {
    static let shared = LocalFileMetadataService()
    
    private let localStorage = LocalStorageService()
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// Save file metadata locally (for free users)
    func saveFileMetadata(_ file: VaultFile, userId: String) throws {
        let key = "file_metadata_\(userId)_\(file.id)"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        UserDefaults.standard.set(data, forKey: key)
        
        // Also maintain a list of file IDs per space
        let spaceKey = "space_files_\(userId)_\(file.spaceId)"
        var fileIds = UserDefaults.standard.stringArray(forKey: spaceKey) ?? []
        if !fileIds.contains(file.id) {
            fileIds.append(file.id)
            UserDefaults.standard.set(fileIds, forKey: spaceKey)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// Load file metadata locally
    func loadFileMetadata(fileId: String, userId: String) throws -> VaultFile? {
        let key = "file_metadata_\(userId)_\(fileId)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultFile.self, from: data)
    }
    
    /// Load all files for a space
    func loadFilesForSpace(userId: String, spaceId: String) throws -> [VaultFile] {
        let spaceKey = "space_files_\(userId)_\(spaceId)"
        guard let fileIds = UserDefaults.standard.stringArray(forKey: spaceKey) else {
            return []
        }
        
        var files: [VaultFile] = []
        for fileId in fileIds {
            if let file = try? loadFileMetadata(fileId: fileId, userId: userId) {
                files.append(file)
            }
        }
        
        return files
    }
    
    /// Load all files for a user
    func loadAllFiles(userId: String) throws -> [VaultFile] {
        // Get all space file lists
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        let spaceKeys = keys.filter { $0.hasPrefix("space_files_\(userId)_") }
        
        var allFileIds = Set<String>()
        for key in spaceKeys {
            if let fileIds = UserDefaults.standard.stringArray(forKey: key) {
                allFileIds.formUnion(fileIds)
            }
        }
        
        var files: [VaultFile] = []
        for fileId in allFileIds {
            if let file = try? loadFileMetadata(fileId: fileId, userId: userId) {
                files.append(file)
            }
        }
        
        return files
    }
    
    /// Delete file metadata
    func deleteFileMetadata(fileId: String, userId: String, spaceId: String) {
        let key = "file_metadata_\(userId)_\(fileId)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // Remove from space list
        let spaceKey = "space_files_\(userId)_\(spaceId)"
        var fileIds = UserDefaults.standard.stringArray(forKey: spaceKey) ?? []
        fileIds.removeAll { $0 == fileId }
        UserDefaults.standard.set(fileIds, forKey: spaceKey)
        UserDefaults.standard.synchronize()
    }
}

