//
//  SyncService.swift
//  Just Vault
//
//  Orchestrates S3 and DynamoDB sync operations
//

import Foundation
import BackgroundTasks

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
    
    // MARK: - Sync File
    
    /// Sync a single file to S3 and DynamoDB
    func syncFile(_ file: VaultFile) async throws {
        // Update sync status to syncing
        var updatedFile = file
        updatedFile.syncStatus = .syncing
        
        // Update in DynamoDB
        try await dynamoDBService.saveFileMetadata(updatedFile)
        
        do {
            // Load encrypted file from local storage
            let encryptedData = try localStorage.loadEncryptedFile(fileId: file.id)
            
            // Upload to S3
            try await s3Service.uploadFile(data: encryptedData, key: file.s3Key)
            
            // Upload thumbnail if exists
            if let thumbnailS3Key = file.thumbnailS3Key {
                let thumbnailId = "\(file.id)_thumb"
                if let thumbnailData = try? localStorage.loadEncryptedFile(fileId: thumbnailId) {
                    try? await s3Service.uploadFile(data: thumbnailData, key: thumbnailS3Key)
                }
            }
            
            // Update sync status to synced
            updatedFile.syncStatus = .synced
            try await dynamoDBService.saveFileMetadata(updatedFile)
            
        } catch {
            // Update sync status to error
            updatedFile.syncStatus = .error
            try? await dynamoDBService.saveFileMetadata(updatedFile)
            throw error
        }
    }
    
    // MARK: - Sync Queue
    
    /// Queue a file for sync
    func queueFileForSync(_ file: VaultFile) {
        Task {
            let shouldStartProcessing = await queueActor.addFile(file)
            
            // Start processing if not already processing
            if shouldStartProcessing {
                await processSyncQueue()
            }
        }
    }
    
    /// Process the sync queue
    func processSyncQueue() async {
        guard await queueActor.startProcessing() else {
            return
        }
        
        while true {
            let file = await queueActor.removeNextFile()
            
            guard let file = file else {
                break
            }
            
            // Sync file
            do {
                try await syncFile(file)
            } catch {
                print("Failed to sync file \(file.id): \(error.localizedDescription)")
                // Retry logic: re-queue if not too many failures
                // For now, just log the error
            }
        }
    }
    
    /// Get pending files count
    func getPendingFilesCount() async -> Int {
        return await queueActor.getCount()
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
    
    /// Handle background sync task
    private func handleBackgroundSync(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await processSyncQueue()
            task.setTaskCompleted(success: true)
        }
    }
}

