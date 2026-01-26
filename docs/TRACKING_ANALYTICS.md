# 📈 JUST VAULT - TRACKING & ANALYTICS PLAN

## Table of Contents

1. [Overview](#overview)
2. [User Analytics](#user-analytics)
3. [Cost Tracking](#cost-tracking)
4. [Performance Tracking](#performance-tracking)
5. [Business Metrics](#business-metrics)
6. [Privacy & Compliance](#privacy--compliance)
7. [Implementation](#implementation)

---

# OVERVIEW

**Analytics Philosophy:** Privacy-first, actionable metrics, AWS-native where possible.

Track what matters for business decisions, not everything.

---

# USER ANALYTICS

## Recommended Tools

### Option 1: Firebase Analytics (Recommended for V1)

**Pros:**
- Free
- Easy integration
- Good iOS support
- Privacy-compliant
- Real-time dashboards

**Cons:**
- Google-owned (privacy concerns for some)
- Requires Firebase account

### Option 2: Mixpanel

**Pros:**
- Powerful segmentation
- Funnel analysis
- Cohort analysis
- Free tier available

**Cons:**
- More complex setup
- Limited free tier

### Option 3: Custom (AWS + CloudWatch)

**Pros:**
- Full control
- No third-party data sharing
- AWS-native

**Cons:**
- More development work
- Less feature-rich dashboards

**V1 Recommendation:** Firebase Analytics (quick setup, free, good enough)

---

## Events to Track

### 1. Onboarding Events

```swift
// User completes onboarding
analytics.logEvent("onboarding_completed", parameters: [
    "step": "recovery_phrase",
    "duration_seconds": 120
])

// User skips recovery phrase (warning)
analytics.logEvent("onboarding_recovery_skipped")

// User creates first space
analytics.logEvent("onboarding_first_space_created")
```

**Metrics:**
- Onboarding completion rate
- Time to complete onboarding
- Drop-off points

---

### 2. File Operations

```swift
// File imported
analytics.logEvent("file_imported", parameters: [
    "file_type": "pdf",
    "file_size_mb": 2.5,
    "space_id": "space_001"
])

// File exported
analytics.logEvent("file_exported", parameters: [
    "file_type": "pdf",
    "export_method": "airdrop"
])

// File deleted
analytics.logEvent("file_deleted", parameters: [
    "file_type": "pdf"
])

// File previewed
analytics.logEvent("file_previewed", parameters: [
    "file_type": "pdf",
    "duration_seconds": 45
])
```

**Metrics:**
- Files imported per user
- Average file size
- File types distribution
- Export frequency

---

### 3. Space Management

```swift
// Space created
analytics.logEvent("space_created", parameters: [
    "space_count": 3,
    "is_locked": false
])

// Space locked (Face ID)
analytics.logEvent("space_locked", parameters: [
    "space_id": "space_001"
])

// Space deleted
analytics.logEvent("space_deleted")
```

**Metrics:**
- Spaces per user
- Locked spaces usage
- Space creation rate

---

### 4. Subscription Events

```swift
// Subscription viewed
analytics.logEvent("subscription_viewed", parameters: [
    "source": "storage_limit"
])

// Subscription purchase initiated
analytics.logEvent("subscription_purchase_initiated", parameters: [
    "storage_used_percent": 85.0
])

// Subscription purchased
analytics.logEvent("subscription_purchased", parameters: [
    "product_id": "pro_monthly",
    "revenue": 6.99
])

// Subscription cancelled
analytics.logEvent("subscription_cancelled", parameters: [
    "days_active": 45
])

// Subscription restored
analytics.logEvent("subscription_restored")
```

**Metrics:**
- Conversion rate (Free → Pro)
- Conversion funnel
- Churn rate
- Average revenue per user (ARPU)
- Lifetime value (LTV)

---

### 5. Storage Usage

```swift
// Storage milestone reached
analytics.logEvent("storage_milestone", parameters: [
    "storage_used_mb": 200,
    "quota_mb": 250,
    "utilization_percent": 80.0
])

// Storage quota exceeded
analytics.logEvent("storage_quota_exceeded", parameters: [
    "storage_used_mb": 260,
    "quota_mb": 250
])

// Upgrade prompt shown
analytics.logEvent("upgrade_prompt_shown", parameters: [
    "trigger": "quota_exceeded"
])
```

**Metrics:**
- Average storage usage
- Storage distribution
- Quota utilization
- Upgrade prompts

---

### 6. Sync Operations

```swift
// Sync started
analytics.logEvent("sync_started", parameters: [
    "files_count": 5,
    "total_size_mb": 10.5
])

// Sync completed
analytics.logEvent("sync_completed", parameters: [
    "files_count": 5,
    "duration_seconds": 12,
    "success": true
])

// Sync failed
analytics.logEvent("sync_failed", parameters: [
    "error": "network_timeout",
    "retry_count": 2
])
```

**Metrics:**
- Sync success rate
- Average sync duration
- Sync frequency
- Error rates

---

### 7. Security Events

```swift
// Face ID used
analytics.logEvent("face_id_used", parameters: [
    "context": "space_unlock"
])

// Recovery phrase generated
analytics.logEvent("recovery_phrase_generated")

// Recovery phrase used (restore)
analytics.logEvent("recovery_phrase_used", parameters: [
    "success": true
])
```

**Metrics:**
- Face ID adoption rate
- Recovery phrase generation rate
- Recovery phrase usage rate

---

### 8. User Engagement

```swift
// App opened
analytics.logEvent("app_opened", parameters: [
    "session_count": 15
])

// App backgrounded
analytics.logEvent("app_backgrounded", parameters: [
    "session_duration_seconds": 300
])

// Feature used
analytics.logEvent("feature_used", parameters: [
    "feature": "search",
    "query_length": 5
])
```

**Metrics:**
- Daily active users (DAU)
- Weekly active users (WAU)
- Monthly active users (MAU)
- Session duration
- Session frequency

---

## User Properties

Set user properties for segmentation:

```swift
// Set user properties
analytics.setUserProperty("subscription_status", value: "pro")
analytics.setUserProperty("storage_tier", value: "10gb")
analytics.setUserProperty("spaces_count", value: "5")
analytics.setUserProperty("files_count", value: "25")
```

**Properties:**
- Subscription status (free/pro)
- Storage tier
- Spaces count
- Files count
- Account age (days)
- Last active date

---

## Conversion Funnel

Track conversion from install to Pro:

```
1. App Installed
   ↓
2. Onboarding Completed
   ↓
3. First File Imported
   ↓
4. Storage Milestone (50% quota)
   ↓
5. Upgrade Prompt Shown
   ↓
6. Subscription Purchase Initiated
   ↓
7. Subscription Purchased
```

**Metrics:**
- Conversion rate at each step
- Drop-off points
- Time to convert
- Conversion by source

---

# COST TRACKING

## AWS Cost Explorer

### Setup

1. Enable Cost Explorer in AWS Console
2. Create cost allocation tags:
   - `Environment: production`
   - `App: just-vault`
   - `Service: s3` / `dynamodb` / `cognito`

### Budgets

Create budgets for cost monitoring:

```json
{
  "BudgetName": "JustVault-Monthly",
  "BudgetLimit": {
    "Amount": "100.00",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": [
      "App$just-vault"
    ]
  }
}
```

### Alarms

- [ ] Daily cost > $10
- [ ] Monthly cost > $100
- [ ] Cost anomaly (50% increase)

---

## Per-User Cost Calculation

### Implementation

```swift
class CostTrackingService {
    func calculatePerUserCost(
        userId: String,
        storageBytes: Int,
        dynamoDBReads: Int,
        dynamoDBWrites: Int
    ) -> Double {
        // S3 cost: $0.023 per GB/month
        let s3Cost = Double(storageBytes) / 1_000_000_000.0 * 0.023
        
        // DynamoDB cost: $0.25 per million reads, $1.25 per million writes
        let dynamoDBCost = 
            (Double(dynamoDBReads) / 1_000_000.0 * 0.25) +
            (Double(dynamoDBWrites) / 1_000_000.0 * 1.25)
        
        // Cognito: Free for first 50K MAU
        let cognitoCost = 0.0
        
        return s3Cost + dynamoDBCost + cognitoCost
    }
}
```

### Tracking

- [ ] Calculate per-user cost daily
- [ ] Store in DynamoDB (user profile)
- [ ] Aggregate monthly
- [ ] Compare to revenue

---

## Cost Allocation Tags

Tag all AWS resources:

```json
{
  "Tags": [
    {
      "Key": "Environment",
      "Value": "production"
    },
    {
      "Key": "App",
      "Value": "just-vault"
    },
    {
      "Key": "Service",
      "Value": "s3"
    }
  ]
}
```

**Benefits:**
- Track costs by service
- Identify cost drivers
- Optimize spending

---

## Cost Anomaly Detection

### AWS Cost Anomaly Detection

1. Enable Cost Anomaly Detection
2. Create monitors:
   - S3 storage anomalies
   - DynamoDB request spikes
   - Cognito usage spikes

### Custom Monitoring

```swift
func detectCostAnomaly(currentCost: Double, previousCost: Double) -> Bool {
    let increase = (currentCost - previousCost) / previousCost
    return increase > 0.5 // 50% increase
}
```

---

# PERFORMANCE TRACKING

## App Performance

### Firebase Performance (Recommended)

**Metrics:**
- App startup time
- Screen load time
- Network request duration
- File operation duration

**Implementation:**

```swift
import FirebasePerformance

// Track custom trace
let trace = Performance.startTrace(name: "file_import")
// ... perform operation
trace.stop()
```

### Custom Metrics

```swift
// Track file import performance
func trackFileImport(fileSize: Int, duration: TimeInterval) {
    analytics.logEvent("file_import_performance", parameters: [
        "file_size_mb": Double(fileSize) / 1_000_000.0,
        "duration_seconds": duration,
        "throughput_mbps": Double(fileSize) / 1_000_000.0 / duration
    ])
}
```

---

## Sync Performance

### Metrics

- Upload speed (Mbps)
- Download speed (Mbps)
- Sync duration
- Files per sync
- Success rate

### Tracking

```swift
func trackSyncPerformance(
    filesCount: Int,
    totalSizeBytes: Int,
    duration: TimeInterval,
    success: Bool
) {
    let throughput = Double(totalSizeBytes) / 1_000_000.0 / duration
    
    analytics.logEvent("sync_performance", parameters: [
        "files_count": filesCount,
        "total_size_mb": Double(totalSizeBytes) / 1_000_000.0,
        "duration_seconds": duration,
        "throughput_mbps": throughput,
        "success": success
    ])
}
```

---

## Error Tracking

### Firebase Crashlytics (Recommended)

**Track:**
- Crashes
- Non-fatal errors
- Custom logs

**Implementation:**

```swift
import FirebaseCrashlytics

// Log custom error
Crashlytics.crashlytics().record(error: error)

// Set custom keys
Crashlytics.crashlytics().setCustomValue(userId, forKey: "user_id")
```

### Custom Error Tracking

```swift
func trackError(_ error: Error, context: [String: Any]) {
    analytics.logEvent("error_occurred", parameters: [
        "error_type": String(describing: type(of: error)),
        "error_message": error.localizedDescription,
        "context": context
    ])
}
```

---

# BUSINESS METRICS

## Key Performance Indicators (KPIs)

### 1. User Acquisition

- **Downloads:** Total app downloads
- **Installs:** Successful installs
- **Activation Rate:** Users who complete onboarding
- **Source:** Where users come from (App Store search, featured, etc.)

### 2. Engagement

- **DAU/WAU/MAU:** Daily/Weekly/Monthly active users
- **Session Duration:** Average time in app
- **Session Frequency:** Sessions per user per week
- **Retention:** Day 1, Day 7, Day 30 retention

### 3. Conversion

- **Free to Pro Conversion Rate:** % of free users who upgrade
- **Time to Convert:** Average days to upgrade
- **Conversion by Trigger:** What caused conversion (quota, feature, etc.)

### 4. Revenue

- **MRR:** Monthly recurring revenue
- **ARPU:** Average revenue per user
- **LTV:** Lifetime value
- **Churn Rate:** % of subscribers who cancel

### 5. Storage

- **Average Storage Used:** Per user
- **Storage Distribution:** How users use storage
- **Quota Utilization:** % of users hitting limits

---

## Conversion Funnel Analysis

### Funnel Stages

```
1. App Installed (100%)
   ↓
2. Onboarding Started (80%)
   ↓
3. Onboarding Completed (70%)
   ↓
4. First File Imported (60%)
   ↓
5. Storage > 50% Quota (30%)
   ↓
6. Upgrade Prompt Shown (25%)
   ↓
7. Subscription Purchase Initiated (10%)
   ↓
8. Subscription Purchased (8%)
```

### Optimization

- Identify drop-off points
- A/B test improvements
- Improve conversion at each stage

---

## Cohort Analysis

### User Cohorts

Group users by:
- Sign-up date (weekly/monthly cohorts)
- Acquisition source
- Initial behavior

### Metrics per Cohort

- Retention rate (Day 1, 7, 30)
- Conversion rate
- Average storage usage
- Revenue per cohort

---

## Revenue Tracking

### StoreKit Integration

```swift
import StoreKit

// Track subscription purchase
func trackSubscriptionPurchase(_ transaction: Transaction) {
    analytics.logEvent("revenue", parameters: [
        "revenue": transaction.price,
        "currency": transaction.currencyCode,
        "product_id": transaction.productID
    ])
}
```

### Revenue Metrics

- **MRR:** Sum of all active subscriptions
- **ARPU:** MRR / Active users
- **LTV:** ARPU × Average subscription duration
- **Churn Rate:** Cancellations / Total subscribers

---

# PRIVACY & COMPLIANCE

## Privacy-First Analytics

### Data Minimization

- [ ] Only track necessary events
- [ ] No PII in events
- [ ] Hash user IDs (if needed)
- [ ] Anonymize data

### User Consent

- [ ] Request analytics consent (if required)
- [ ] Provide opt-out option
- [ ] Respect user preferences
- [ ] Clear privacy policy

### Data Retention

- [ ] Set retention policies
- [ ] Delete old data
- [ ] Comply with regulations (GDPR, CCPA)

---

## GDPR Compliance

### User Rights

- [ ] Right to access data
- [ ] Right to delete data
- [ ] Right to export data
- [ ] Right to opt-out

### Implementation

```swift
// Delete user data
func deleteUserAnalyticsData(userId: String) {
    // Delete from Firebase
    analytics.deleteUserData()
    
    // Delete from AWS
    // ... implementation
}
```

---

# IMPLEMENTATION

## Step 1: Set Up Firebase

### Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: "Just Vault"
3. Add iOS app
4. Download `GoogleService-Info.plist`
5. Add to Xcode project

### Install Firebase SDK

```swift
// Package.swift or Xcode
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
]
```

### Initialize Firebase

```swift
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebasePerformance

@main
struct Just_VaultApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## Step 2: Implement Analytics

### Analytics Service

```swift
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }
}
```

### Usage

```swift
// Log event
AnalyticsService.shared.logEvent("file_imported", parameters: [
    "file_type": "pdf",
    "file_size_mb": 2.5
])

// Set user property
AnalyticsService.shared.setUserProperty("pro", forName: "subscription_status")
```

---

## Step 3: Set Up Cost Tracking

### AWS Cost Explorer

1. Enable Cost Explorer
2. Create cost allocation tags
3. Set up budgets
4. Create alarms

### Custom Cost Tracking

```swift
class CostTrackingService {
    func trackUserCost(userId: String) async {
        // Get user's storage
        let storageBytes = await getStorageUsage(userId: userId)
        
        // Calculate cost
        let cost = calculateCost(storageBytes: storageBytes)
        
        // Store in DynamoDB
        await updateUserCost(userId: userId, cost: cost)
        
        // Log to analytics
        AnalyticsService.shared.logEvent("user_cost_calculated", parameters: [
            "cost_usd": cost,
            "storage_gb": Double(storageBytes) / 1_000_000_000.0
        ])
    }
}
```

---

## Step 4: Create Dashboards

### Firebase Dashboard

- [ ] Set up Firebase Analytics dashboard
- [ ] Create custom reports
- [ ] Set up alerts

### AWS Cost Explorer Dashboard

- [ ] Create cost dashboard
- [ ] Set up budget alerts
- [ ] Monitor daily costs

### Custom Dashboard (Optional)

- [ ] Build internal dashboard
- [ ] Aggregate metrics
- [ ] Real-time updates

---

# METRICS SUMMARY

## Daily Metrics to Monitor

- [ ] New users
- [ ] Active users (DAU)
- [ ] Subscription conversions
- [ ] Revenue
- [ ] Error rate
- [ ] Sync success rate
- [ ] AWS costs

## Weekly Metrics

- [ ] User retention
- [ ] Conversion funnel
- [ ] Storage usage trends
- [ ] Churn rate
- [ ] Feature usage

## Monthly Metrics

- [ ] MRR growth
- [ ] LTV
- [ ] Cohort analysis
- [ ] Cost per user
- [ ] Profit margins

---

# SUMMARY

## Key Takeaways

1. **Privacy-first:** Minimize data collection, respect user privacy
2. **Actionable metrics:** Track what drives business decisions
3. **Cost tracking:** Monitor AWS costs per user
4. **Performance:** Track app and sync performance
5. **Business metrics:** Focus on conversion, revenue, retention

## V1 Implementation Priority

1. ✅ Set up Firebase Analytics
2. ✅ Track core events (onboarding, file ops, subscriptions)
3. ✅ Set up AWS Cost Explorer
4. ✅ Track basic business metrics
5. ⏸️ Defer: Advanced segmentation, custom dashboards

