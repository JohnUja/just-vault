//
//  SyncService.swift
//  Just Vault
//
//  Orchestrates S3 and DynamoDB sync operations
//

import Foundation
import BackgroundTasks

enum SyncError: LocalizedError {
    case storageLimitReached
    case syncTimeout

    var errorDescription: String? {
        switch self {
        case .storageLimitReached:
            return "Cloud storage limit reached. Upgrade your plan or remove files from the cloud."
        case .syncTimeout:
            return "Sync took too long. Check your connection and try again."
        }
    }
}

// Actor for managing sync queue state (Swift 6 async-safe)
actor SyncQueueActor {
    private var syncQueue: [VaultFile] = []
    private var isProcessingQueue = false
    
    func addFile(_ file: VaultFile) -> Bool {
        // Check if file is already in queue
        if !syncQueue.contains(where: { $0.id == file.id }) {
            syncQueue.append(file)
        }
        return !isProcessingQueue
    }

    /// Add multiple files to the queue without starting processing (for UI-triggered sync so we can show orange first).
    func addFilesOnly(_ files: [VaultFile]) {
        for file in files where !syncQueue.contains(where: { $0.id == file.id }) {
            syncQueue.append(file)
        }
    }

    func startProcessing() -> Bool {
        guard !isProcessingQueue else {
            return false
        }
        isProcessingQueue = true
        return true
    }
    
    func removeNextFile() -> VaultFile? {
        guard !syncQueue.isEmpty else {
            isProcessingQueue = false
            return nil
        }
        return syncQueue.removeFirst()
    }
    
    func stopProcessing() {
        isProcessingQueue = false
    }

    func clearQueue() {
        syncQueue.removeAll()
        isProcessingQueue = false
    }
    
    func getCount() -> Int {
        return syncQueue.count
    }
}

class SyncService {
    static let shared = SyncService()
    
    private let s3Service = S3Service.shared
    private let dynamoDBService = DynamoDBService.shared
    private let localStorage = LocalStorageService()
    private let queueActor = SyncQueueActor()
    
    private init() {}

    private func canUseCloudSync() -> Bool {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let userData = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return false
        }
        return user.hasCloudBackup
    }

    /// Sync to cloud only runs when Automatic Cloud Backup is ON and user has cloud backup. When off, no files are queued or processed unless force is true (e.g. user taps "Sync Now").
    private func shouldAutoSyncNow() -> Bool {
        guard AppPreferences.cloudBackupEnabled else { return false }
        return canUseCloudSync()
    }
    
    // MARK: - Sync File

    /// Per-file timeout so sync never hangs indefinitely (e.g. bad network). 60s is plenty for small files.
    private static let syncTimeoutNanoseconds: UInt64 = 60_000_000_000

    /// Sync a single file to S3 and DynamoDB. Times out after 60s per file so small files don't "sync forever".
    func syncFile(_ file: VaultFile) async throws {
        // Check storage quota before uploading
        if let userId = UserDefaults.standard.string(forKey: "currentUserId"),
           let userData = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            let newUsed = user.cloudStorageUsedBytes + file.sizeBytes
            let quota = user.effectiveCloudStorageQuotaBytes
            if newUsed > quota && quota > 0 {
                print("[Sync] Storage limit reached (\(user.cloudStorageUsedMB)/\(user.effectiveCloudStorageQuotaMB) MB). Cannot upload \(file.displayName).")
                throw SyncError.storageLimitReached
            }
        }

        var updatedFile = file
        updatedFile.syncStatus = .syncing
        try await dynamoDBService.saveFileMetadata(updatedFile)
        try? LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: file.userId)
        var uploadedToS3 = false

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    let encryptedData = try self.localStorage.loadEncryptedFile(fileId: file.id)
                    try await self.s3Service.uploadFile(data: encryptedData, key: file.s3Key)
                    if let thumbnailS3Key = file.thumbnailS3Key {
                        let thumbnailId = "\(file.id)_thumb"
                        if let thumbnailData = try? self.localStorage.loadEncryptedFile(fileId: thumbnailId) {
                            try? await self.s3Service.uploadFile(data: thumbnailData, key: thumbnailS3Key)
                        }
                    }
                    var done = file
                    done.syncStatus = .synced
                    try await self.dynamoDBService.saveFileMetadata(done)
                    try? LocalFileMetadataService.shared.updateFileMetadata(done, userId: file.userId)
                    try await self.reconcileUserCloudStorage(lastSyncAt: Date())
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.syncTimeoutNanoseconds)
                    throw SyncError.syncTimeout
                }
                try await group.next()!
                group.cancelAll()
            }
            uploadedToS3 = true
        } catch {
            if uploadedToS3 {
                updatedFile.syncStatus = .synced
                try? await dynamoDBService.saveFileMetadata(updatedFile)
                try? LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: file.userId)
                try? await reconcileUserCloudStorage(lastSyncAt: Date())
                return
            }
            updatedFile.syncStatus = .error
            try? await dynamoDBService.saveFileMetadata(updatedFile)
            try? LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: file.userId)
            print("[Sync] Failed \(file.displayName): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sync Queue
    
    /// Queue a file for sync
    func queueFileForSync(_ file: VaultFile, force: Bool = false) {
        guard force ? canUseCloudSync() : shouldAutoSyncNow() else { return }
        Task {
            let shouldStartProcessing = await queueActor.addFile(file)
            
            // Start processing if not already processing
            if shouldStartProcessing {
                await processSyncQueue(force: force)
            }
        }
    }
    
    /// Process the sync queue (one file at a time). Sync to cloud only runs when auto backup is on (or force is true) and there are files to sync.
    /// Duration: roughly a few seconds per small file (under 1 MB) to tens of seconds per large file (e.g. 10–100 MB), depending on network. No explicit timeout.
    func processSyncQueue(force: Bool = false) async {
        guard force ? canUseCloudSync() : shouldAutoSyncNow() else { return }
        guard await queueActor.startProcessing() else {
            return
        }
        var didSyncAtLeastOne = false

        while true {
            if !(force ? canUseCloudSync() : shouldAutoSyncNow()) {
                if !force {
                    await queueActor.clearQueue()
                } else {
                    await queueActor.stopProcessing()
                }
                break
            }

            let file = await queueActor.removeNextFile()

            guard let file = file else {
                break
            }

            do {
                try await syncFile(file)
                didSyncAtLeastOne = true
                print("[Sync] Successfully synced file \(file.id) to S3")
            } catch {
                print("[Sync] Failed to sync file \(file.id): \(error.localizedDescription)")
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
            }
        }

        // Update last synced time in user profile and Settings only when we actually synced something to cloud
        if didSyncAtLeastOne {
            let syncTime = Date()
            await MainActor.run {
                UserDefaults.standard.set(syncTime, forKey: "lastSyncDate")
            }
            try? await reconcileUserCloudStorage(lastSyncAt: syncTime)
        }
    }

    /// When cloud backup is enabled, push every local file that is not already synced.
    func syncAllEligibleLocalFiles(force: Bool = false) async {
        guard (force ? canUseCloudSync() : shouldAutoSyncNow()),
              let userId = UserDefaults.standard.string(forKey: "currentUserId") else { return }

        do {
            let localFiles = try LocalFileMetadataService.shared.loadAllFiles(userId: userId)
            let eligible = localFiles.filter { file in
                switch file.syncStatus {
                case .pending, .error:
                    return true
                case .syncing, .synced, .localOnly:
                    return false
                }
            }
            for file in eligible {
                queueFileForSync(file, force: force)
            }
        } catch {
            print("[Sync] Failed to load local files for bulk sync: \(error.localizedDescription)")
        }
    }
    
    /// Add files to the queue without starting processing. Call processSyncQueue(force: true) after to run.
    func addFilesToQueueOnly(_ files: [VaultFile]) async {
        await queueActor.addFilesOnly(files)
    }

    /// Get pending files count
    func getPendingFilesCount() async -> Int {
        return await queueActor.getCount()
    }
    
    func removeFileFromCloud(_ file: VaultFile) async throws {
        try await s3Service.deleteFile(key: file.s3Key)
        if let thumbnailKey = file.thumbnailS3Key {
            try? await s3Service.deleteFile(key: thumbnailKey)
        }

        let updatedFile = VaultFile(
            id: file.id,
            userId: file.userId,
            spaceId: file.spaceId,
            displayName: file.displayName,
            sizeBytes: file.sizeBytes,
            mimeType: file.mimeType,
            createdAt: file.createdAt,
            lastOpenedAt: file.lastOpenedAt,
            starred: file.starred,
            localPath: file.localPath,
            s3Key: file.s3Key,
            syncStatus: .localOnly,
            version: file.version + 1,
            thumbnailS3Key: file.thumbnailS3Key
        )

        try? LocalFileMetadataService.shared.updateFileMetadata(updatedFile, userId: file.userId)
        try? await dynamoDBService.saveFileMetadata(updatedFile)
        try await reconcileUserCloudStorage(lastSyncAt: Date())
        await MainActor.run {
            NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
        }
    }

    func reconcileCloudStateNow(lastSyncAt: Date? = nil) async {
        try? await reconcileUserCloudStorage(lastSyncAt: lastSyncAt)
        await MainActor.run {
            NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
        }
    }

    private func reconcileUserCloudStorage(lastSyncAt: Date?) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId"),
              let userData = UserDefaults.standard.data(forKey: "currentUser_\(userId)"),
              var user = try? JSONDecoder().decode(User.self, from: userData) else { return }

        let allFiles = (try? await dynamoDBService.loadAllFiles(userId: userId)) ?? []
        user.cloudStorageUsedBytes = allFiles
            .filter { $0.syncStatus == .synced }
            .reduce(into: Int64(0)) { total, file in
                total += file.sizeBytes
            }

        if let lastSyncAt {
            user.lastSyncAt = lastSyncAt
        }

        let updatedUser = user

        await MainActor.run {
            if let lastSyncAt {
                UserDefaults.standard.set(lastSyncAt, forKey: "lastSyncDate")
            }
            if let encoded = try? JSONEncoder().encode(updatedUser) {
                UserDefaults.standard.set(encoded, forKey: "currentUser_\(userId)")
            }
            NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
            print("[Sync] Cloud storage used: \(updatedUser.cloudStorageUsedMB) MB / \(updatedUser.effectiveCloudStorageQuotaMB) MB")
        }

        try await dynamoDBService.saveUserProfile(updatedUser)
    }

    // MARK: - Background Sync
    
    /// Register background sync task
    func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.juvantagecloud.justvault.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }
    
    /// Schedule background sync
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: "com.juvantagecloud.justvault.sync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error.localizedDescription)")
        }
    }
    
    /// Handle background sync task. Does nothing when Automatic Cloud Backup is off.
    private func handleBackgroundSync(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        guard AppPreferences.cloudBackupEnabled else {
            task.setTaskCompleted(success: true)
            return
        }
        Task {
            await processSyncQueue()
            task.setTaskCompleted(success: true)
        }
    }
}

