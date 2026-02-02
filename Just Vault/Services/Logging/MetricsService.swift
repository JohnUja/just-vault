//
//  MetricsService.swift
//  Just Vault
//
//  CloudWatch Metrics service
//

import Foundation

class MetricsService {
    static let shared = MetricsService()
    
    private let namespace = "JustVault"
    private var metricBuffer: [MetricData] = []
    private let bufferSize = 20
    
    private init() {}
    
    /// Put a custom metric
    func putMetric(
        name: String,
        value: Double,
        unit: String = "Count",
        dimensions: [String: String]? = nil
    ) {
        let metric = MetricData(
            metricName: name,
            value: value,
            unit: unit,
            timestamp: Date(),
            dimensions: dimensions
        )
        
        metricBuffer.append(metric)
        
        // Upload when buffer reaches threshold
        if metricBuffer.count >= bufferSize {
            uploadMetrics()
        }
    }
    
    /// Upload buffered metrics to CloudWatch
    private func uploadMetrics() {
        guard !metricBuffer.isEmpty else { return }
        
        // TODO: Implement CloudWatch Metrics upload using AWS SDK
        // When AWS SDK is properly configured, implement:
        // 1. Convert metrics to CloudWatch format
        // 2. Upload via PutMetricData API
        
        let metricsToUpload = metricBuffer
        metricBuffer.removeAll()
        
        Task {
            // Placeholder - will implement with AWS SDK
            print("📊 Would upload \(metricsToUpload.count) metrics to CloudWatch")
        }
    }
    
    /// Force upload remaining metrics
    func flush() {
        if !metricBuffer.isEmpty {
            uploadMetrics()
        }
    }
    
    // Convenience methods for common metrics
    func trackAuthenticationSuccess(userId: String? = nil) {
        putMetric(name: "AuthenticationSuccess", value: 1.0)
        if let userId = userId {
            putMetric(name: "AuthenticationSuccess", value: 1.0, dimensions: ["UserId": userId])
        }
    }
    
    func trackAuthenticationFailure() {
        putMetric(name: "AuthenticationFailure", value: 1.0)
    }
    
    func trackFileImport(sizeBytes: Int64, durationMs: Int) {
        putMetric(name: "FileImport", value: 1.0)
        putMetric(name: "FileImportSize", value: Double(sizeBytes), unit: "Bytes")
        putMetric(name: "FileImportDuration", value: Double(durationMs), unit: "Milliseconds")
    }
    
    func trackSyncOperation(success: Bool, durationMs: Int) {
        if success {
            putMetric(name: "SyncSuccess", value: 1.0)
        } else {
            putMetric(name: "SyncFailure", value: 1.0)
        }
        putMetric(name: "SyncDuration", value: Double(durationMs), unit: "Milliseconds")
    }
}

struct MetricData {
    let metricName: String
    let value: Double
    let unit: String
    let timestamp: Date
    let dimensions: [String: String]?
}

