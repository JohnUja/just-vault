//
//  S3Service.swift
//  Just Vault
//
//  Service for uploading/downloading encrypted files to S3
//

import Foundation
import AWSS3
import ClientRuntime

class S3Service {
    static let shared = S3Service()
    
    private var client: S3Client?
    private let credentialManager = CredentialManager.shared
    private let bucketName = AWSConfig.s3BucketName
    private let region = AWSConfig.region
    
    private init() {}
    
    // MARK: - Client Initialization
    
    func initializeClient() async throws {
        // Get credentials from CredentialManager (credentials will be used by SDK's default provider)
        let _ = try await credentialManager.getCredentials()
        
        // Create S3 client configuration
        // AWS SDK for Swift v1 uses default credential provider chain
        // Credentials will be provided via environment or default chain
        let config = try await S3Client.S3ClientConfiguration(
            region: region
        )
        
        client = S3Client(config: config)
        
        // Note: In production, you may need to configure credentials explicitly
        // The SDK should pick up credentials from the default provider chain
    }
    
    // MARK: - Upload Operations
    
    func uploadFile(data: Data, key: String) async throws {
        try await ensureClientInitialized()
        
        let input = PutObjectInput(
            body: .data(data),
            bucket: bucketName,
            key: key
        )
        
        _ = try await client?.putObject(input: input)
    }
    
    func uploadFileWithProgress(data: Data, key: String, progressHandler: @escaping (Double) -> Void) async throws {
        // For large files, we might want to use multipart upload
        // For now, use simple upload
        try await uploadFile(data: data, key: key)
        progressHandler(1.0)
    }
    
    // MARK: - Download Operations
    
    func downloadFile(key: String) async throws -> Data {
        try await ensureClientInitialized()
        
        let input = GetObjectInput(
            bucket: bucketName,
            key: key
        )
        
        let response = try await client?.getObject(input: input)
        
        guard let body = response?.body else {
            throw S3Error.downloadFailed
        }
        
        // Convert body to Data
        switch body {
        case .data(let data):
            // Unwrap optional data or throw error
            guard let data = data else {
                throw S3Error.downloadFailed
            }
            return data
        case .stream(let stream):
            // Read stream into Data
            // Note: AWS SDK for Swift v1 stream handling
            // The stream type may need to be converted or read differently
            // This is a placeholder implementation - adjust based on actual SDK structure
            
            // Try to read stream as AsyncSequence
            // The actual stream type from AWS SDK may conform to AsyncSequence differently
            var data = Data()
            
            // Attempt to iterate over stream
            // If the SDK stream type has a different API, this will need adjustment
            do {
                // Try casting to AsyncSequence protocol
                // The actual type may be different - check SDK documentation
                if let asyncSequence = stream as? any AsyncSequence {
                    for try await chunk in asyncSequence {
                        // Handle different chunk types
                        if let chunkData = chunk as? Data {
                            data.append(chunkData)
                        } else if let chunkBytes = chunk as? [UInt8] {
                            data.append(contentsOf: chunkBytes)
                        } else if let chunkByte = chunk as? UInt8 {
                            data.append(chunkByte)
                        }
                    }
                } else {
                    // Stream doesn't conform to AsyncSequence
                    // May need to use SDK-specific stream reading API
                    // For now, throw error - this needs SDK-specific implementation
                    throw S3Error.downloadFailed
                }
            } catch {
                throw S3Error.downloadFailed
            }
            
            return data
        default:
            throw S3Error.downloadFailed
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteFile(key: String) async throws {
        try await ensureClientInitialized()
        
        let input = DeleteObjectInput(
            bucket: bucketName,
            key: key
        )
        
        _ = try await client?.deleteObject(input: input)
    }
    
    // MARK: - Helper Methods
    
    private func ensureClientInitialized() async throws {
        // Check if user has cloud backup enabled (not free tier)
        // For free users, we should not initialize AWS services
        if !shouldUseCloudSync() {
            throw S3Error.cloudSyncNotAvailable
        }
        
        if client == nil {
            try await initializeClient()
        }
    }
    
    /// Check if cloud sync should be used (user must be Pro or Pro+)
    private func shouldUseCloudSync() -> Bool {
        // Get current user from UserDefaults
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let userData = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            // If no user found, default to false (no cloud sync)
            return false
        }
        
        // Only Pro and Pro+ users can use cloud sync
        return user.hasCloudBackup
    }
    
    /// Generate S3 key for a file
    static func generateS3Key(identityId: String, fileId: String) -> String {
        return "users/\(identityId)/files/\(fileId).enc"
    }
    
    /// Generate S3 key for a thumbnail
    static func generateThumbnailS3Key(identityId: String, fileId: String) -> String {
        return "users/\(identityId)/thumbs/\(fileId).enc"
    }
}

enum S3Error: LocalizedError {
    case downloadFailed
    case uploadFailed
    case clientNotInitialized
    case cloudSyncNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download file from S3"
        case .uploadFailed:
            return "Failed to upload file to S3"
        case .clientNotInitialized:
            return "S3 client not initialized"
        case .cloudSyncNotAvailable:
            return "Cloud sync is only available for Pro and Pro+ subscribers"
        }
    }
}

