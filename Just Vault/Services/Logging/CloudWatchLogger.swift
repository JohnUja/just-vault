//
//  CloudWatchLogger.swift
//  Just Vault
//
//  Logging service for CloudWatch integration
//

import Foundation
import OSLog

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

struct LogEntry: Codable {
    let timestamp: String
    let level: String
    let event: String
    let userId: String?
    let metadata: [String: String]?
    let message: String?
}

class CloudWatchLogger {
    static let shared = CloudWatchLogger()
    
    private let logGroupName = "/aws/just-vault/app"
    private var logBuffer: [LogEntry] = []
    private let bufferSize = 50
    private let localLogger = Logger(subsystem: "com.juvantagecloud.justvault", category: "CloudWatch")
    
    private init() {}
    
    /// Log an event (buffers locally, uploads in batches)
    func log(
        level: LogLevel,
        event: String,
        userId: String? = nil,
        metadata: [String: String]? = nil,
        message: String? = nil
    ) {
        let entry = LogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: level.rawValue,
            event: event,
            userId: userId,
            metadata: metadata,
            message: message
        )
        
        // Log locally first (for debugging)
        localLogger.log("\(level.rawValue): \(event) - \(message ?? "")")
        
        // Add to buffer
        logBuffer.append(entry)
        
        // Upload when buffer reaches threshold
        if logBuffer.count >= bufferSize {
            uploadLogs()
        }
    }
    
    /// Upload buffered logs to CloudWatch
    private func uploadLogs() {
        guard !logBuffer.isEmpty else { return }
        
        // TODO: Implement CloudWatch Logs upload using AWS SDK
        // For now, logs are buffered locally
        // When AWS SDK is properly configured, implement:
        // 1. Create log stream (if needed)
        // 2. Convert log entries to CloudWatch format
        // 3. Upload via PutLogEvents API
        
        // Clear buffer after upload attempt
        let logsToUpload = logBuffer
        logBuffer.removeAll()
        
        Task {
            // Placeholder - will implement with AWS SDK
            print("📊 Would upload \(logsToUpload.count) log entries to CloudWatch")
        }
    }
    
    /// Force upload remaining logs (call on app background/terminate)
    func flush() {
        if !logBuffer.isEmpty {
            uploadLogs()
        }
    }
    
    // Convenience methods
    func debug(_ event: String, metadata: [String: String]? = nil) {
        log(level: .debug, event: event, metadata: metadata)
    }
    
    func info(_ event: String, userId: String? = nil, metadata: [String: String]? = nil) {
        log(level: .info, event: event, userId: userId, metadata: metadata)
    }
    
    func warning(_ event: String, message: String? = nil, metadata: [String: String]? = nil) {
        log(level: .warning, event: event, metadata: metadata, message: message)
    }
    
    func error(_ event: String, message: String? = nil, metadata: [String: String]? = nil) {
        log(level: .error, event: event, metadata: metadata, message: message)
    }
}

