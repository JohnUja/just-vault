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
        let credentials = try await credentialManager.getCredentials()
        
        // This AWS SDK build only exposes the default credential chain configuration surface.
        // Populate the chain from the Cognito-issued credentials we stored in CredentialManager.
        setenv("AWS_ACCESS_KEY_ID", credentials.accessKeyId, 1)
        setenv("AWS_SECRET_ACCESS_KEY", credentials.secretAccessKey, 1)
        if let sessionToken = credentials.sessionToken, !sessionToken.isEmpty {
            setenv("AWS_SESSION_TOKEN", sessionToken, 1)
        } else {
            unsetenv("AWS_SESSION_TOKEN")
        }
        setenv("AWS_DEFAULT_REGION", region, 1)
        setenv("AWS_REGION", region, 1)
        
        let config = try await S3Client.S3ClientConfig(
            region: region
        )
        
        client = S3Client(config: config)
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
        print("[S3] Uploaded \(data.count) bytes -> s3://\(bucketName)/\(key)")
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

        // Let the SDK normalize either in-memory or streamed response bodies.
        guard let data = try await body.readData() else {
            throw S3Error.downloadFailed
        }
        print("[S3] Downloaded \(data.count) bytes <- s3://\(bucketName)/\(key)")
        return data
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
    
    /// Delete all S3 objects under a prefix (e.g. users/<userId>/). Used for account deletion to remove any objects even if not in DynamoDB.
    func deleteAllObjects(prefix: String) async throws {
        try await ensureClientInitialized()
        var continuationToken: String? = nil
        repeat {
            let input = ListObjectsV2Input(
                bucket: bucketName,
                continuationToken: continuationToken,
                prefix: prefix
            )
            let response = try await client?.listObjectsV2(input: input)
            let keys = (response?.contents ?? []).compactMap { $0.key }
            for key in keys {
                try? await client?.deleteObject(input: DeleteObjectInput(bucket: bucketName, key: key))
            }
            continuationToken = response?.nextContinuationToken
        } while continuationToken != nil
    }
    
    // MARK: - Helper Methods

    /// When true, ensureClientInitialized skips the Pro check (for account deletion).
    static var accountDeletionInProgress = false

    private func ensureClientInitialized() async throws {
        if !Self.accountDeletionInProgress && !shouldUseCloudSync() {
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

