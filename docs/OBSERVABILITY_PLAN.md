# 📊 JUST VAULT - OBSERVABILITY PLAN

## Table of Contents

1. [Overview](#overview)
2. [AWS-Native Observability](#aws-native-observability)
3. [What to Monitor](#what-to-monitor)
4. [Logging Strategy](#logging-strategy)
5. [Metrics & Dashboards](#metrics--dashboards)
6. [Alerting Strategy](#alerting-strategy)
7. [Implementation](#implementation)

---

# OVERVIEW

**Observability Philosophy:** AWS-native only, no third-party services for V1.

This keeps costs low, reduces complexity, and provides all necessary monitoring capabilities.

---

# AWS-NATIVE OBSERVABILITY

## Services Used

| Service | Purpose | Cost |
|---------|---------|------|
| **CloudWatch Logs** | Application logs | $0.50/GB ingested (first 5GB free) |
| **CloudWatch Metrics** | Custom metrics | $0.30/metric/month (first 10 free) |
| **CloudWatch Alarms** | Alerts | Free |
| **CloudWatch Dashboards** | Visualization | Free |
| **X-Ray** | Distributed tracing | Optional, $5 per million traces |

**V1 Recommendation:** CloudWatch only (Logs + Metrics + Alarms)

---

# WHAT TO MONITOR

## 1. Authentication & Authorization

### Metrics

- `AuthenticationSuccess` - Count of successful sign-ins
- `AuthenticationFailure` - Count of failed sign-ins
- `TokenRefresh` - Count of token refreshes
- `CredentialIssuance` - Count of AWS credential requests

### Logs

```json
{
  "timestamp": "2026-01-23T10:00:00Z",
  "level": "INFO",
  "event": "authentication_success",
  "userId": "us-east-1:abc123",
  "provider": "apple",
  "duration_ms": 250
}
```

### Alarms

- **High authentication failure rate:** > 10% failure rate over 5 minutes
- **Unusual authentication pattern:** > 100 auth attempts in 1 minute

---

## 2. File Operations

### Metrics

- `FileImport` - Count of file imports
- `FileExport` - Count of file exports
- `FileDelete` - Count of file deletions
- `FilePreview` - Count of file previews
- `FileImportSize` - Average file size imported (bytes)
- `FileImportDuration` - Average import duration (ms)

### Logs

```json
{
  "timestamp": "2026-01-23T10:05:00Z",
  "level": "INFO",
  "event": "file_import",
  "userId": "us-east-1:abc123",
  "fileId": "file_7f91a2",
  "fileName": "passport.pdf",
  "fileSize": 1048576,
  "mimeType": "application/pdf",
  "spaceId": "space_001",
  "duration_ms": 1200
}
```

### Alarms

- **Large file import:** File size > 50MB
- **Slow import:** Import duration > 5 seconds

---

## 3. Sync Operations

### Metrics

- `SyncUpload` - Count of successful uploads
- `SyncDownload` - Count of successful downloads
- `SyncFailure` - Count of sync failures
- `SyncQueueSize` - Number of files pending sync
- `SyncUploadDuration` - Average upload duration (ms)
- `SyncDownloadDuration` - Average download duration (ms)
- `SyncDataTransferred` - Total bytes synced (GB)

### Logs

```json
{
  "timestamp": "2026-01-23T10:10:00Z",
  "level": "INFO",
  "event": "sync_upload",
  "userId": "us-east-1:abc123",
  "fileId": "file_7f91a2",
  "s3Key": "users/us-east-1:abc123/files/7f91a2.enc",
  "sizeBytes": 1048576,
  "duration_ms": 800,
  "success": true
}
```

```json
{
  "timestamp": "2026-01-23T10:15:00Z",
  "level": "ERROR",
  "event": "sync_failure",
  "userId": "us-east-1:abc123",
  "fileId": "file_7f91a2",
  "error": "Network timeout",
  "retryCount": 2
}
```

### Alarms

- **High sync failure rate:** > 5% failure rate over 10 minutes
- **Large sync queue:** Queue size > 100 files
- **Slow sync:** Average upload duration > 3 seconds

---

## 4. Storage Usage

### Metrics

- `StorageUsedLocal` - Total local storage used (bytes)
- `StorageUsedCloud` - Total cloud storage used (bytes)
- `StorageQuota` - User's storage quota (bytes)
- `StorageUtilization` - Percentage of quota used
- `FilesPerUser` - Average files per user
- `SpacesPerUser` - Average spaces per user

### Logs

```json
{
  "timestamp": "2026-01-23T10:20:00Z",
  "level": "INFO",
  "event": "storage_update",
  "userId": "us-east-1:abc123",
  "localBytes": 52428800,
  "cloudBytes": 52428800,
  "quotaBytes": 262144000,
  "utilizationPercent": 20.0
}
```

### Alarms

- **Storage quota exceeded:** Utilization > 100%
- **Storage quota warning:** Utilization > 80%
- **Unusual storage growth:** > 1GB increase in 1 hour

---

## 5. AWS Service Health

### Metrics (Auto-collected by AWS)

- **S3:**
  - `NumberOfObjects` - Total objects in bucket
  - `BucketSizeBytes` - Total bucket size
  - `4xxErrors` - Client errors
  - `5xxErrors` - Server errors

- **DynamoDB:**
  - `ConsumedReadCapacityUnits` - Read capacity used
  - `ConsumedWriteCapacityUnits` - Write capacity used
  - `UserErrors` - User errors (4xx)
  - `SystemErrors` - System errors (5xx)

- **Cognito:**
  - `SignInSuccesses` - Successful sign-ins
  - `SignInFailures` - Failed sign-ins
  - `TokenRefreshSuccesses` - Successful token refreshes

### Alarms

- **S3 errors:** 4xx or 5xx error rate > 1%
- **DynamoDB throttling:** Throttled requests > 0
- **Cognito errors:** Failure rate > 5%

---

## 6. Cost Tracking

### Metrics

- `EstimatedCost` - Estimated AWS cost (calculated)
- `S3Cost` - Estimated S3 cost
- `DynamoDBCost` - Estimated DynamoDB cost
- `CognitoCost` - Estimated Cognito cost
- `CostPerUser` - Average cost per user

### Alarms

- **High daily cost:** Daily cost > $50
- **Cost anomaly:** Daily cost increase > 50% vs. previous day

---

## 7. User Activity

### Metrics

- `ActiveUsers` - Daily active users
- `NewUsers` - New user registrations
- `SubscriptionConversions` - Free to Pro conversions
- `SubscriptionCancellations` - Pro cancellations
- `SessionDuration` - Average session duration (seconds)

### Logs

```json
{
  "timestamp": "2026-01-23T10:25:00Z",
  "level": "INFO",
  "event": "user_activity",
  "userId": "us-east-1:abc123",
  "action": "file_preview",
  "fileId": "file_7f91a2",
  "sessionId": "session_xyz"
}
```

---

# LOGGING STRATEGY

## Log Levels

- **ERROR:** Failures that need attention
- **WARN:** Unusual but recoverable situations
- **INFO:** Normal operations (authentication, file ops, sync)
- **DEBUG:** Detailed information for troubleshooting (disable in production)

## Structured Logging

All logs use JSON format for easy parsing:

```swift
struct LogEntry: Codable {
    let timestamp: String
    let level: String
    let event: String
    let userId: String?
    let fileId: String?
    let error: String?
    let duration_ms: Int?
    let metadata: [String: Any]?
}
```

## Log Categories

### 1. Application Logs

**Log Group:** `/aws/just-vault/app`

**Retention:** 7 days

**Contains:**
- Authentication events
- File operations
- User actions
- Errors

### 2. Sync Logs

**Log Group:** `/aws/just-vault/sync`

**Retention:** 7 days

**Contains:**
- Upload/download operations
- Sync failures
- Retry attempts

### 3. Error Logs

**Log Group:** `/aws/just-vault/errors`

**Retention:** 30 days

**Contains:**
- All ERROR level logs
- Stack traces
- Error context

### 4. AWS Service Logs

**Log Groups:**
- `/aws/cognito/userpool/just-vault-prod`
- `/aws/s3/access-logs` (if enabled)
- `/aws/dynamodb/JustVault`

**Retention:** 7 days (30 days for errors)

---

## PII Handling

**Never log:**
- File contents (even encrypted)
- Recovery phrases
- Encryption keys
- Full file paths (use fileId only)

**Safe to log:**
- User IDs (Cognito identity IDs)
- File IDs
- File names (display names only)
- File sizes
- Timestamps
- Error messages (sanitized)

**Example:**

```swift
// ❌ BAD
logger.info("User \(userId) imported file at \(fullPath)")

// ✅ GOOD
logger.info("User \(userId) imported file \(fileId) with size \(sizeBytes)")
```

---

## Log Ingestion

### From iOS App

**Option 1: Direct CloudWatch Logs (Recommended for V1)**

Use AWS SDK to send logs directly:

```swift
import AWSCore

class CloudWatchLogger {
    private let logGroupName = "/aws/just-vault/app"
    
    func log(_ entry: LogEntry) async {
        // Send to CloudWatch Logs via AWS SDK
    }
}
```

**Option 2: Local Logging + Periodic Upload**

Log locally, upload in batches:

```swift
class LocalLogger {
    private var logBuffer: [LogEntry] = []
    
    func log(_ entry: LogEntry) {
        logBuffer.append(entry)
        if logBuffer.count >= 100 {
            uploadLogs()
        }
    }
    
    private func uploadLogs() {
        // Upload batch to CloudWatch
    }
}
```

**Recommendation:** Option 2 for V1 (more efficient, works offline)

---

# METRICS & DASHBOARDS

## Custom Metrics

### Implementation

```swift
import AWSCore

class MetricsService {
    private let cloudWatch = AWSCloudWatch.default()
    
    func putMetric(
        name: String,
        value: Double,
        unit: String = "Count"
    ) async throws {
        let metric = AWSCloudWatchMetricDatum()
        metric.metricName = name
        metric.value = NSNumber(value: value)
        metric.unit = unit
        metric.timestamp = Date()
        
        let request = AWSCloudWatchPutMetricDataInput()
        request.namespace = "JustVault"
        request.metricData = [metric]
        
        try await cloudWatch.putMetricData(request)
    }
}
```

### Usage

```swift
// Track file import
await metricsService.putMetric(name: "FileImport", value: 1.0)

// Track file size
await metricsService.putMetric(
    name: "FileImportSize",
    value: Double(fileSize),
    unit: "Bytes"
)
```

---

## CloudWatch Dashboard

### Dashboard: "Just Vault - Overview"

**Widgets:**

1. **Authentication**
   - Line chart: Success vs. Failure rate (last 24h)
   - Number: Total active users today

2. **File Operations**
   - Line chart: File imports per hour
   - Number: Total files stored
   - Line chart: Average file size

3. **Sync Status**
   - Line chart: Uploads vs. Downloads
   - Number: Files pending sync
   - Line chart: Sync failure rate

4. **Storage**
   - Number: Total storage used (GB)
   - Gauge: Average storage utilization %
   - Line chart: Storage growth over time

5. **Costs**
   - Number: Estimated daily cost
   - Line chart: Cost trend (last 7 days)

6. **Errors**
   - Number: Error count (last hour)
   - Line chart: Error rate over time

---

# ALERTING STRATEGY

## Alarm Configuration

### 1. Critical Alarms (Immediate Action)

#### High Error Rate

```json
{
  "AlarmName": "HighErrorRate",
  "MetricName": "ErrorCount",
  "Namespace": "JustVault",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 1,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": ["arn:aws:sns:us-east-1:ACCOUNT:critical-alerts"]
}
```

**Action:** Email + SMS notification

---

#### Authentication Failure Spike

```json
{
  "AlarmName": "AuthFailureSpike",
  "MetricName": "AuthenticationFailure",
  "Namespace": "JustVault",
  "Statistic": "Sum",
  "Period": 60,
  "EvaluationPeriods": 1,
  "Threshold": 50,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

**Action:** Email notification

---

#### Sync Failure Rate

```json
{
  "AlarmName": "HighSyncFailureRate",
  "MetricName": "SyncFailureRate",
  "Namespace": "JustVault",
  "Statistic": "Average",
  "Period": 600,
  "EvaluationPeriods": 2,
  "Threshold": 0.05,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

**Action:** Email notification

---

### 2. Warning Alarms (Monitor)

#### Storage Quota Warning

```json
{
  "AlarmName": "StorageQuotaWarning",
  "MetricName": "StorageUtilization",
  "Namespace": "JustVault",
  "Statistic": "Average",
  "Period": 3600,
  "EvaluationPeriods": 1,
  "Threshold": 80.0,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

**Action:** Email notification (informational)

---

#### High Daily Cost

```json
{
  "AlarmName": "HighDailyCost",
  "MetricName": "EstimatedCost",
  "Namespace": "JustVault",
  "Statistic": "Sum",
  "Period": 86400,
  "EvaluationPeriods": 1,
  "Threshold": 50.0,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

**Action:** Email notification

---

### 3. Informational Alarms

#### New User Registration

```json
{
  "AlarmName": "NewUserRegistration",
  "MetricName": "NewUsers",
  "Namespace": "JustVault",
  "Statistic": "Sum",
  "Period": 3600,
  "EvaluationPeriods": 1,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

**Action:** Email notification (daily digest)

---

## SNS Topics

### Topic: `just-vault-critical-alerts`

**Subscribers:**
- Email: dev-team@example.com
- SMS: +1234567890 (on-call)

### Topic: `just-vault-warnings`

**Subscribers:**
- Email: dev-team@example.com

### Topic: `just-vault-info`

**Subscribers:**
- Email: dev-team@example.com (daily digest)

---

# IMPLEMENTATION

## Step 1: Set Up CloudWatch Log Groups

```bash
aws logs create-log-group --log-group-name /aws/just-vault/app
aws logs create-log-group --log-group-name /aws/just-vault/sync
aws logs create-log-group --log-group-name /aws/just-vault/errors

# Set retention
aws logs put-retention-policy --log-group-name /aws/just-vault/app --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/sync --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/errors --retention-in-days 30
```

---

## Step 2: Create IAM Policy for Logging

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/just-vault/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:Namespace": "JustVault"
        }
      }
    }
  ]
}
```

Attach to authenticated user role.

---

## Step 3: Implement Logging in iOS App

```swift
class Logger {
    private let logGroupName = "/aws/just-vault/app"
    private var logBuffer: [LogEntry] = []
    
    func log(_ level: LogLevel, event: String, metadata: [String: Any]? = nil) {
        let entry = LogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: level.rawValue,
            event: event,
            metadata: metadata
        )
        
        logBuffer.append(entry)
        
        // Upload when buffer reaches threshold
        if logBuffer.count >= 50 {
            uploadLogs()
        }
    }
    
    private func uploadLogs() {
        // Upload batch to CloudWatch Logs
        Task {
            // Implementation using AWS SDK
        }
    }
}
```

---

## Step 4: Create CloudWatch Dashboard

1. Go to CloudWatch Console
2. Create dashboard: "Just Vault - Overview"
3. Add widgets for each metric category
4. Set refresh interval to 1 minute

---

## Step 5: Set Up Alarms

```bash
# High error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name HighErrorRate \
  --alarm-description "Alert when error rate is high" \
  --metric-name ErrorCount \
  --namespace JustVault \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT:critical-alerts
```

---

## Step 6: Create SNS Topics

```bash
# Critical alerts
aws sns create-topic --name just-vault-critical-alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT:just-vault-critical-alerts \
  --protocol email \
  --notification-endpoint dev-team@example.com

# Warnings
aws sns create-topic --name just-vault-warnings
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT:just-vault-warnings \
  --protocol email \
  --notification-endpoint dev-team@example.com
```

---

# MONITORING CHECKLIST

## Daily

- [ ] Check CloudWatch dashboard for anomalies
- [ ] Review error logs
- [ ] Check sync failure rate
- [ ] Monitor storage growth

## Weekly

- [ ] Review cost trends
- [ ] Analyze user activity patterns
- [ ] Check alarm history
- [ ] Review log retention policies

## Monthly

- [ ] Cost optimization review
- [ ] Metrics cleanup (remove unused metrics)
- [ ] Dashboard updates
- [ ] Alert tuning

---

# COST ESTIMATION

## CloudWatch Costs (1,000 users)

- **Log ingestion:** ~100MB/month = Free (within 5GB free tier)
- **Custom metrics:** 10 metrics = Free (within 10 free tier)
- **Alarms:** Free
- **Dashboards:** Free

**Total: $0/month (within free tier)**

## CloudWatch Costs (10,000 users)

- **Log ingestion:** ~1GB/month = Free (within 5GB free tier)
- **Custom metrics:** 15 metrics = 5 × $0.30 = $1.50/month
- **Alarms:** Free
- **Dashboards:** Free

**Total: ~$1.50/month**

---

# SUMMARY

## Key Points

1. **AWS-native only:** No third-party services needed
2. **Structured logging:** JSON format for easy parsing
3. **Comprehensive metrics:** Track all critical operations
4. **Smart alerting:** Critical vs. warning vs. informational
5. **Cost-effective:** Mostly within AWS free tier

## V1 Implementation Priority

1. ✅ Set up CloudWatch log groups
2. ✅ Implement basic logging in app
3. ✅ Create overview dashboard
4. ✅ Set up critical alarms
5. ⏸️ Defer: Advanced metrics, X-Ray tracing

