//
//  DynamoDBService.swift
//  Just Vault
//
//  Service for interacting with DynamoDB for metadata storage
//

import Foundation
import AWSDynamoDB
import ClientRuntime

class DynamoDBService {
    static let shared = DynamoDBService()
    
    private var client: DynamoDBClient?
    private let credentialManager = CredentialManager.shared
    private let tableName = AWSConfig.dynamoDBTableName
    private let region = AWSConfig.region
    
    private init() {}
    
    // MARK: - Client Initialization
    
    func initializeClient() async throws {
        // Get credentials from CredentialManager (credentials will be used by SDK's default provider)
        let _ = try await credentialManager.getCredentials()
        
        // Create DynamoDB client configuration
        // AWS SDK for Swift v1 uses default credential provider chain
        // Credentials will be provided via environment or default chain
        // For now, create client with region - credentials will be handled by SDK
        let config = try await DynamoDBClient.DynamoDBClientConfiguration(
            region: region
        )
        
        client = DynamoDBClient(config: config)
        
        // Note: In production, you may need to configure credentials explicitly
        // The SDK should pick up credentials from the default provider chain
        // If needed, we can set credentials via environment variables or config file
    }
    
    // MARK: - User Profile Operations
    
    func saveUserProfile(_ user: User) async throws {
        try await ensureClientInitialized()
        
        // Create DynamoDB item
        let item: [String: DynamoDBClientTypes.AttributeValue] = [
            "PK": .s("USER#\(user.id)"),
            "SK": .s("PROFILE"),
            "id": .s(user.id),
            "appleUserId": .s(user.appleUserId),
            "email": user.email.map { .s($0) } ?? .null(true),
            "name": user.name.map { .s($0) } ?? .null(true),
            "createdAt": .s(ISO8601DateFormatter().string(from: user.createdAt)),
            "lastActiveAt": .s(ISO8601DateFormatter().string(from: user.lastActiveAt)),
            "subscriptionTier": .s(user.subscriptionTier.rawValue),
            "subscriptionStatus": .s(user.subscriptionStatus.rawValue),
            "cloudStorageUsedBytes": .n(String(user.cloudStorageUsedBytes)),
            "cloudStorageQuotaBytes": .n(String(user.cloudStorageQuotaBytes))
        ]
        
        let input = PutItemInput(
            item: item,
            tableName: tableName
        )
        
        _ = try await client?.putItem(input: input)
    }
    
    func loadUserProfile(userId: String) async throws -> User? {
        try await ensureClientInitialized()
        
        let input = GetItemInput(
            key: [
                "PK": .s("USER#\(userId)"),
                "SK": .s("PROFILE")
            ],
            tableName: tableName
        )
        
        let response = try await client?.getItem(input: input)
        guard let item = response?.item else {
            return nil
        }
        
        return try parseUserFromItem(item)
    }
    
    // MARK: - Space Operations
    
    func saveSpace(_ space: Space) async throws {
        try await ensureClientInitialized()
        
        let item: [String: DynamoDBClientTypes.AttributeValue] = [
            "PK": .s("USER#\(space.userId)"),
            "SK": .s("SPACE#\(space.id)"),
            "id": .s(space.id),
            "userId": .s(space.userId),
            "name": .s(space.name),
            "icon": .s(space.icon),
            "color": .s(space.color),
            "isLocked": .bool(space.isLocked),
            "orderIndex": .n(String(space.orderIndex)),
            "createdAt": .s(ISO8601DateFormatter().string(from: space.createdAt)),
            "fileCount": .n(String(space.fileCount))
        ]
        
        let input = PutItemInput(
            item: item,
            tableName: tableName
        )
        
        _ = try await client?.putItem(input: input)
    }
    
    func loadSpaces(userId: String) async throws -> [Space] {
        try await ensureClientInitialized()
        
        let input = QueryInput(
            expressionAttributeValues: [
                ":pk": .s("USER#\(userId)"),
                ":sk": .s("SPACE#")
            ],
            keyConditionExpression: "PK = :pk AND begins_with(SK, :sk)",
            tableName: tableName
        )
        
        let response = try await client?.query(input: input)
        guard let items = response?.items else {
            return []
        }
        
        var spaces: [Space] = []
        for item in items {
            if let space = try? parseSpaceFromItem(item) {
                spaces.append(space)
            }
        }
        
        // Sort by orderIndex
        return spaces.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    func deleteSpace(userId: String, spaceId: String) async throws {
        try await ensureClientInitialized()
        
        let input = DeleteItemInput(
            key: [
                "PK": .s("USER#\(userId)"),
                "SK": .s("SPACE#\(spaceId)")
            ],
            tableName: tableName
        )
        
        _ = try await client?.deleteItem(input: input)
    }
    
    // MARK: - File Operations
    
    func saveFileMetadata(_ file: VaultFile) async throws {
        try await ensureClientInitialized()
        
        let item: [String: DynamoDBClientTypes.AttributeValue] = [
            "PK": .s("USER#\(file.userId)"),
            "SK": .s("FILE#\(file.id)"),
            "id": .s(file.id),
            "userId": .s(file.userId),
            "spaceId": .s(file.spaceId),
            "displayName": .s(file.displayName),
            "sizeBytes": .n(String(file.sizeBytes)),
            "mimeType": .s(file.mimeType),
            "createdAt": .s(ISO8601DateFormatter().string(from: file.createdAt)),
            "lastOpenedAt": file.lastOpenedAt.map { .s(ISO8601DateFormatter().string(from: $0)) } ?? .null(true),
            "starred": .bool(file.starred),
            "localPath": .s(file.localPath),
            "s3Key": .s(file.s3Key),
            "syncStatus": .s(file.syncStatus.rawValue),
            "version": .n(String(file.version)),
            "thumbnailS3Key": file.thumbnailS3Key.map { .s($0) } ?? .null(true)
        ]
        
        let input = PutItemInput(
            item: item,
            tableName: tableName
        )
        
        _ = try await client?.putItem(input: input)
    }
    
    func loadAllFiles(userId: String) async throws -> [VaultFile] {
        try await ensureClientInitialized()
        
        let input = QueryInput(
            expressionAttributeValues: [
                ":pk": .s("USER#\(userId)"),
                ":sk": .s("FILE#")
            ],
            keyConditionExpression: "PK = :pk AND begins_with(SK, :sk)",
            tableName: tableName
        )
        
        let response = try await client?.query(input: input)
        guard let items = response?.items else {
            return []
        }
        
        var files: [VaultFile] = []
        for item in items {
            if let file = try? parseFileFromItem(item) {
                files.append(file)
            }
        }
        
        return files
    }
    
    func loadFilesForSpace(userId: String, spaceId: String) async throws -> [VaultFile] {
        let allFiles = try await loadAllFiles(userId: userId)
        return allFiles.filter { $0.spaceId == spaceId }
    }
    
    func deleteFileMetadata(userId: String, fileId: String) async throws {
        try await ensureClientInitialized()
        
        let input = DeleteItemInput(
            key: [
                "PK": .s("USER#\(userId)"),
                "SK": .s("FILE#\(fileId)")
            ],
            tableName: tableName
        )
        
        _ = try await client?.deleteItem(input: input)
    }
    
    // MARK: - Helper Methods
    
    private func ensureClientInitialized() async throws {
        // Check if user has cloud backup enabled (not free tier)
        // For free users, we should not initialize AWS services
        if !shouldUseCloudSync() {
            throw DynamoDBError.cloudSyncNotAvailable
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
    
    private func parseUserFromItem(_ item: [String: DynamoDBClientTypes.AttributeValue]) throws -> User {
        // Helper to extract string from AttributeValue
        func extractString(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .s(let value) = attr {
                return value
            }
            return nil
        }
        
        // Helper to extract number from AttributeValue
        func extractNumber(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .n(let value) = attr {
                return value
            }
            return nil
        }
        
        guard let id = extractString(item["id"]),
              let appleUserId = extractString(item["appleUserId"]),
              let createdAtString = extractString(item["createdAt"]),
              let lastActiveAtString = extractString(item["lastActiveAt"]),
              let subscriptionTierString = extractString(item["subscriptionTier"]),
              let subscriptionStatusString = extractString(item["subscriptionStatus"]),
              let usedBytesString = extractNumber(item["cloudStorageUsedBytes"]),
              let quotaBytesString = extractNumber(item["cloudStorageQuotaBytes"]),
              let usedBytes = Int64(usedBytesString),
              let quotaBytes = Int64(quotaBytesString),
              let subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString),
              let subscriptionStatus = SubscriptionStatus(rawValue: subscriptionStatusString) else {
            throw DynamoDBError.invalidData
        }
        
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: createdAtString) ?? Date()
        let lastActiveAt = formatter.date(from: lastActiveAtString) ?? Date()
        
        return User(
            id: id,
            appleUserId: appleUserId,
            email: extractString(item["email"]),
            name: extractString(item["name"]),
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            subscriptionTier: subscriptionTier,
            subscriptionStatus: subscriptionStatus,
            cloudStorageUsedBytes: usedBytes,
            cloudStorageQuotaBytes: quotaBytes
        )
    }
    
    private func parseSpaceFromItem(_ item: [String: DynamoDBClientTypes.AttributeValue]) throws -> Space {
        // Helper to extract string from AttributeValue
        func extractString(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .s(let value) = attr {
                return value
            }
            return nil
        }
        
        // Helper to extract number from AttributeValue
        func extractNumber(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .n(let value) = attr {
                return value
            }
            return nil
        }
        
        // Helper to extract bool from AttributeValue
        func extractBool(_ attr: DynamoDBClientTypes.AttributeValue?) -> Bool? {
            guard let attr = attr else { return nil }
            if case .bool(let value) = attr {
                return value
            }
            return nil
        }
        
        guard let id = extractString(item["id"]),
              let userId = extractString(item["userId"]),
              let name = extractString(item["name"]),
              let icon = extractString(item["icon"]),
              let color = extractString(item["color"]),
              let orderIndexString = extractNumber(item["orderIndex"]),
              let orderIndex = Int(orderIndexString),
              let createdAtString = extractString(item["createdAt"]),
              let fileCountString = extractNumber(item["fileCount"]),
              let fileCount = Int(fileCountString) else {
            throw DynamoDBError.invalidData
        }
        
        // Extract bool separately since it's not optional in guard let
        let isLocked = extractBool(item["isLocked"]) ?? false
        
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: createdAtString) ?? Date()
        
        return Space(
            id: id,
            userId: userId,
            name: name,
            icon: icon,
            color: color,
            isLocked: isLocked,
            orderIndex: orderIndex,
            createdAt: createdAt,
            fileCount: fileCount
        )
    }
    
    private func parseFileFromItem(_ item: [String: DynamoDBClientTypes.AttributeValue]) throws -> VaultFile {
        // Helper to extract string from AttributeValue
        func extractString(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .s(let value) = attr {
                return value
            }
            return nil
        }
        
        // Helper to extract number from AttributeValue
        func extractNumber(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let attr = attr else { return nil }
            if case .n(let value) = attr {
                return value
            }
            return nil
        }
        
        // Helper to extract bool from AttributeValue
        func extractBool(_ attr: DynamoDBClientTypes.AttributeValue?) -> Bool? {
            guard let attr = attr else { return nil }
            if case .bool(let value) = attr {
                return value
            }
            return nil
        }
        
        guard let id = extractString(item["id"]),
              let userId = extractString(item["userId"]),
              let spaceId = extractString(item["spaceId"]),
              let displayName = extractString(item["displayName"]),
              let sizeBytesString = extractNumber(item["sizeBytes"]),
              let sizeBytes = Int64(sizeBytesString),
              let mimeType = extractString(item["mimeType"]),
              let createdAtString = extractString(item["createdAt"]),
              let localPath = extractString(item["localPath"]),
              let s3Key = extractString(item["s3Key"]),
              let syncStatusString = extractString(item["syncStatus"]),
              let syncStatus = SyncStatus(rawValue: syncStatusString),
              let versionString = extractNumber(item["version"]),
              let version = Int(versionString) else {
            throw DynamoDBError.invalidData
        }
        
        // Extract bool separately since it's not optional in guard let
        let starred = extractBool(item["starred"]) ?? false
        
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: createdAtString) ?? Date()
        let lastOpenedAt = extractString(item["lastOpenedAt"]).flatMap { formatter.date(from: $0) }
        
        return VaultFile(
            id: id,
            userId: userId,
            spaceId: spaceId,
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
            thumbnailS3Key: extractString(item["thumbnailS3Key"])
        )
    }
}

enum DynamoDBError: LocalizedError {
    case invalidData
    case clientNotInitialized
    case cloudSyncNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .clientNotInitialized:
            return "DynamoDB client not initialized"
        case .cloudSyncNotAvailable:
            return "Cloud sync is only available for Pro and Pro+ subscribers"
        }
    }
}

// MARK: - Credentials Configuration
// Note: AWS SDK for Swift v1 will use default credential provider chain
// Credentials from Cognito Identity Pool will be available via environment
// or can be configured through the SDK's credential provider system

