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
        
        let config = try await DynamoDBClient.DynamoDBClientConfig(
            region: region
        )
        
        client = DynamoDBClient(config: config)
    }

    /// Call on sign out so the next DynamoDB call uses fresh credentials after sign in. Otherwise recovery questions and wrapped key load can use stale credentials and return nil.
    func clearClient() {
        client = nil
    }
    
    // MARK: - User Profile Operations
    
    func saveUserProfile(_ user: User, wrappedMasterKey: Data? = nil) async throws {
        try await ensureClientInitialized(requirePro: false)
        
        var item: [String: DynamoDBClientTypes.AttributeValue] = [
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
            "cloudStorageQuotaBytes": .n(String(user.cloudStorageQuotaBytes)),
            "lastSyncAt": user.lastSyncAt.map { .s(ISO8601DateFormatter().string(from: $0)) } ?? .null(true)
        ]
        if let wrapped = wrappedMasterKey {
            item["wrappedMasterKey"] = .s(wrapped.base64EncodedString())
        }
        
        // Preserve recovery-question attributes so profile saves (sync, tier, name, etc.) never wipe them.
        let getInput = GetItemInput(
            key: ["PK": .s("USER#\(user.id)"), "SK": .s("PROFILE")],
            tableName: tableName
        )
        let getResponse = try await client?.getItem(input: getInput)
        if let existing = getResponse?.item {
            let recoveryKeys = [
                "recoveryQuestion1", "recoveryQuestion2", "recoveryQuestion3",
                "wrappedMasterKeyByRecovery1", "wrappedMasterKeyByRecovery2", "wrappedMasterKeyByRecovery3"
            ]
            for key in recoveryKeys {
                if let value = existing[key] {
                    item[key] = value
                }
            }
        }
        
        let input = PutItemInput(
            item: item,
            tableName: tableName
        )
        
        _ = try await client?.putItem(input: input)
    }
    
    /// Load only the wrapped master key for recovery (not part of in-memory User).
    func loadWrappedMasterKey(userId: String) async throws -> Data? {
        try await ensureClientInitialized(requirePro: false)
        let input = GetItemInput(
            key: [
                "PK": .s("USER#\(userId)"),
                "SK": .s("PROFILE")
            ],
            tableName: tableName
        )
        let response = try await client?.getItem(input: input)
        guard let item = response?.item,
              let attr = item["wrappedMasterKey"],
              case .s(let base64) = attr,
              !base64.isEmpty,
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return data
    }

    /// Recovery questions (retrieval mode): 3 question texts + 3 wrapped master-key blobs.
    struct RecoveryQuestionsData {
        let questions: [String]  // count 3
        let wrappedBlobs: [Data] // count 3
    }

    func saveRecoveryQuestions(userId: String, questions: [String], wrappedBlobs: [Data]) async throws {
        try await ensureClientInitialized(requirePro: false)
        guard questions.count == 3, wrappedBlobs.count == 3 else { return }
        let input = GetItemInput(
            key: ["PK": .s("USER#\(userId)"), "SK": .s("PROFILE")],
            tableName: tableName
        )
        let response = try await client?.getItem(input: input)
        guard var item = response?.item else { throw DynamoDBError.cloudSaveFailed }
        item["recoveryQuestion1"] = .s(questions[0])
        item["recoveryQuestion2"] = .s(questions[1])
        item["recoveryQuestion3"] = .s(questions[2])
        item["wrappedMasterKeyByRecovery1"] = .s(wrappedBlobs[0].base64EncodedString())
        item["wrappedMasterKeyByRecovery2"] = .s(wrappedBlobs[1].base64EncodedString())
        item["wrappedMasterKeyByRecovery3"] = .s(wrappedBlobs[2].base64EncodedString())
        let putInput = PutItemInput(item: item, tableName: tableName)
        _ = try await client?.putItem(input: putInput)
    }

    func loadRecoveryQuestions(userId: String) async throws -> RecoveryQuestionsData? {
        try await ensureClientInitialized(requirePro: false)
        let input = GetItemInput(
            key: ["PK": .s("USER#\(userId)"), "SK": .s("PROFILE")],
            tableName: tableName
        )
        let response = try await client?.getItem(input: input)
        guard let item = response?.item else { return nil }
        func str(_ attr: DynamoDBClientTypes.AttributeValue?) -> String? {
            guard let a = attr, case .s(let v) = a else { return nil }
            return v
        }
        guard let q1 = str(item["recoveryQuestion1"]), !q1.isEmpty,
              let q2 = str(item["recoveryQuestion2"]), !q2.isEmpty,
              let q3 = str(item["recoveryQuestion3"]), !q3.isEmpty,
              let b1 = str(item["wrappedMasterKeyByRecovery1"]), !b1.isEmpty,
              let b2 = str(item["wrappedMasterKeyByRecovery2"]), !b2.isEmpty,
              let b3 = str(item["wrappedMasterKeyByRecovery3"]), !b3.isEmpty,
              let d1 = Data(base64Encoded: b1),
              let d2 = Data(base64Encoded: b2),
              let d3 = Data(base64Encoded: b3) else {
            return nil
        }
        return RecoveryQuestionsData(questions: [q1, q2, q3], wrappedBlobs: [d1, d2, d3])
    }

    func loadUserProfile(userId: String) async throws -> User? {
        // User profile restore must work after reinstall / post-delete recovery, before we know the tier.
        try await ensureClientInitialized(requirePro: false)
        
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

    /// When true, ensureClientInitialized skips the Pro check (for account deletion using current credentials).
    private static var accountDeletionInProgress = false

    /// If requirePro is false, allow DynamoDB for auth/recovery (profile, recovery questions) even when user is free tier (e.g. post–account-deletion recovery setup).
    private func ensureClientInitialized(requirePro: Bool = true) async throws {
        if requirePro && !Self.accountDeletionInProgress && !shouldUseCloudSync() {
            throw DynamoDBError.cloudSyncNotAvailable
        }
        if client == nil {
            try await initializeClient()
        }
    }

    /// Delete all cloud data for a user (profile, spaces, file metadata, and S3 objects). Uses current credentials; call from Delete Account flow only.
    func deleteAllUserCloudData(userId: String) async throws {
        Self.accountDeletionInProgress = true
        S3Service.accountDeletionInProgress = true
        defer {
            Self.accountDeletionInProgress = false
            S3Service.accountDeletionInProgress = false
        }
        try await ensureClientInitialized()
        // Wipe all S3 objects under this user's prefix (catches any orphans not in DynamoDB)
        try? await S3Service.shared.deleteAllObjects(prefix: "users/\(userId)/")
        let files = (try? await loadAllFiles(userId: userId)) ?? []
        for file in files {
            try? await S3Service.shared.deleteFile(key: file.s3Key)
            if let thumb = file.thumbnailS3Key { try? await S3Service.shared.deleteFile(key: thumb) }
            try? await deleteFileMetadata(userId: userId, fileId: file.id)
        }
        let spaces = (try? await loadSpaces(userId: userId)) ?? []
        for space in spaces {
            try? await deleteSpace(userId: userId, spaceId: space.id)
        }
        let input = DeleteItemInput(
            key: ["PK": .s("USER#\(userId)"), "SK": .s("PROFILE")],
            tableName: tableName
        )
        _ = try await client?.deleteItem(input: input)
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
            cloudStorageQuotaBytes: quotaBytes,
            lastSyncAt: extractString(item["lastSyncAt"]).flatMap { ISO8601DateFormatter().date(from: $0) }
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
    case cloudSaveFailed

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .clientNotInitialized:
            return "DynamoDB client not initialized"
        case .cloudSyncNotAvailable:
            return "Cloud sync is only available for Pro and Pro+ subscribers"
        case .cloudSaveFailed:
            return "Could not save to cloud"
        }
    }
}

// MARK: - Credentials Configuration
// Note: AWS SDK for Swift v1 will use default credential provider chain
// Credentials from Cognito Identity Pool will be available via environment
// or can be configured through the SDK's credential provider system

