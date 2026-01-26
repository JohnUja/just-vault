# ☁️ JUST VAULT - AWS RESOURCES & COST ANALYSIS

## Table of Contents

1. [AWS Services Overview](#aws-services-overview)
2. [Service Configuration](#service-configuration)
3. [Cost Analysis](#cost-analysis)
4. [Cost Optimization Strategies](#cost-optimization-strategies)
5. [Resource Limits & Scaling](#resource-limits--scaling)
6. [Infrastructure as Code](#infrastructure-as-code)

---

# AWS SERVICES OVERVIEW

## Services Used

| Service | Purpose | Cost Model |
|---------|---------|------------|
| **Cognito User Pool** | Apple Sign In authentication | $0.0055 per MAU (first 50K free) |
| **Cognito Identity Pool** | AWS credentials issuance | $0.0055 per MAU (first 50K free) |
| **S3** | Encrypted file storage | $0.023 per GB/month (Standard) |
| **DynamoDB** | Metadata storage | On-demand: $1.25 per million writes, $0.25 per million reads |
| **IAM** | Access control | Free |
| **CloudWatch** | Logging & monitoring | Logs: $0.50 per GB ingested, Metrics: $0.30 per metric/month |
| **STS** | Temporary credentials | Free (included with Cognito) |

---

# SERVICE CONFIGURATION

## 1. Cognito User Pool

### Configuration

```json
{
  "UserPoolName": "just-vault-prod-user-pool",
  "Policies": {
    "PasswordPolicy": {
      "MinimumLength": 8
    }
  },
  "SchemaAttributes": [
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": false
    }
  ],
  "AutoVerifiedAttributes": [],
  "AliasAttributes": [],
  "MfaConfiguration": "OFF"
}
```

### Apple Sign In Integration

1. Configure Apple as OIDC provider
2. Set client ID from Apple Developer
3. Configure callback URLs
4. Map Apple user attributes

### Costs

- **First 50,000 MAU:** Free
- **50,001 - 100,000 MAU:** $0.0055 per user
- **100,001+ MAU:** $0.0046 per user

**Example:** 1,000 active users = $0 (within free tier)

---

## 2. Cognito Identity Pool

### Configuration

```json
{
  "IdentityPoolName": "just-vault-prod-identity-pool",
  "AllowUnauthenticatedIdentities": false,
  "CognitoIdentityProviders": [
    {
      "ProviderName": "cognito-idp.us-east-1.amazonaws.com/USER_POOL_ID",
      "ClientId": "CLIENT_ID"
    }
  ],
  "IdentityPoolTags": {
    "Environment": "production",
    "App": "just-vault"
  }
}
```

### IAM Role Attachment

Attach IAM roles for authenticated users (see IAM section below).

### Costs

- **First 50,000 MAU:** Free
- **50,001+ MAU:** $0.0055 per user

**Example:** 1,000 active users = $0 (within free tier)

---

## 3. S3 Bucket

### Configuration

**Bucket Name:** `just-vault-prod-blobs`

**Settings:**

```json
{
  "Versioning": {
    "Status": "Suspended"
  },
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true,
    "BlockPublicPolicy": true,
    "IgnorePublicAcls": true,
    "RestrictPublicBuckets": true
  },
  "Encryption": {
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  },
  "LifecycleConfiguration": {
    "Rules": [
      {
        "Id": "MoveToIntelligentTiering",
        "Status": "Enabled",
        "Transitions": [
          {
            "Days": 0,
            "StorageClass": "INTELLIGENT_TIERING"
          }
        ]
      }
    ]
  }
}
```

### Storage Structure

```
just-vault-prod-blobs/
└── users/
    └── {identityId}/
        ├── files/
        │   └── {fileId}.enc
        └── thumbs/
            └── {thumbId}.enc
```

### Costs

**S3 Standard Storage:**
- First 50 TB: $0.023 per GB/month
- Next 450 TB: $0.022 per GB/month

**S3 Intelligent-Tiering:**
- Monitoring & automation: $0.0025 per 1,000 objects
- Storage: Same as Standard (but auto-optimizes)

**Requests:**
- PUT: $0.005 per 1,000 requests
- GET: $0.0004 per 1,000 requests
- DELETE: Free

**Example Calculation (10GB user):**
- Storage: 10 GB × $0.023 = $0.23/month
- PUT requests (100 files): 100 × $0.005/1000 = $0.0005
- GET requests (50/month): 50 × $0.0004/1000 = $0.00002
- **Total: ~$0.23/month per 10GB user**

---

## 4. DynamoDB Table

### Configuration

**Table Name:** `JustVault`

**Schema:**

```json
{
  "TableName": "JustVault",
  "KeySchema": [
    {
      "AttributeName": "PK",
      "KeyType": "HASH"
    },
    {
      "AttributeName": "SK",
      "KeyType": "RANGE"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "PK",
      "AttributeType": "S"
    },
    {
      "AttributeName": "SK",
      "AttributeType": "S"
    }
  ],
  "BillingMode": "PAY_PER_REQUEST",
  "StreamSpecification": {
    "StreamEnabled": false
  },
  "Tags": [
    {
      "Key": "Environment",
      "Value": "production"
    }
  ]
}
```

### Global Secondary Indexes (if needed)

```json
{
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "GSI-SpaceFiles",
      "KeySchema": [
        {
          "AttributeName": "PK",
          "KeyType": "HASH"
        },
        {
          "AttributeName": "spaceId",
          "KeyType": "RANGE"
        }
      ],
      "Projection": {
        "ProjectionType": "ALL"
      }
    }
  ]
}
```

### Costs

**On-Demand Mode:**
- Write: $1.25 per million write units
- Read: $0.25 per million read units
- Storage: $0.25 per GB/month

**Example Calculation (1,000 active users):**
- Writes: ~10 per user/month = 10,000 writes = $0.0125
- Reads: ~50 per user/month = 50,000 reads = $0.0125
- Storage: ~1MB per user = 1GB total = $0.25
- **Total: ~$0.28/month for 1,000 users**

**Per-user cost: ~$0.00028/month**

---

## 5. IAM Roles & Policies

### Authenticated User Role

**Role Name:** `JustVaultAuthenticatedUserRole`

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "IDENTITY_POOL_ID"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
```

**S3 Policy:** (See ARCHITECTURE.md for full policy)

**DynamoDB Policy:** (See ARCHITECTURE.md for full policy)

**Cost:** Free

---

## 6. CloudWatch

### Log Groups

**Log Group:** `/aws/cognito/userpool/just-vault-prod`

**Retention:** 7 days (to reduce costs)

### Metrics

Track:
- Authentication failures
- Sync operations
- Storage usage
- Error rates

### Costs

**Logs:**
- First 5 GB: Free
- Next 5 GB: $0.50 per GB
- Retention: $0.03 per GB/month

**Metrics:**
- First 10 metrics: Free
- Additional: $0.30 per metric/month

**Example (1,000 users):**
- Log ingestion: ~100MB/month = Free
- Custom metrics: 5 metrics = Free
- **Total: ~$0/month (within free tier)**

---

# COST ANALYSIS

## Per-User Cost Breakdown

### FREE Tier User (250 MB)

| Service | Usage | Cost |
|---------|-------|------|
| Cognito | 1 MAU | $0 (free tier) |
| S3 Storage | 250 MB | $0.00575 |
| S3 Requests | 10 PUT, 5 GET | $0.00005 |
| DynamoDB | 5 writes, 20 reads | $0.00001 |
| CloudWatch | Minimal | $0 (free tier) |
| **Total** | | **~$0.006/user/month** |

### PRO Tier User (10 GB)

| Service | Usage | Cost |
|---------|-------|------|
| Cognito | 1 MAU | $0 (free tier) |
| S3 Storage | 10 GB | $0.23 |
| S3 Requests | 100 PUT, 50 GET | $0.0007 |
| DynamoDB | 10 writes, 50 reads | $0.0003 |
| CloudWatch | Minimal | $0 (free tier) |
| **Total** | | **~$0.23/user/month** |

---

## Monthly Cost Projections

### 100 Users (90% Free, 10% Pro)

- Free users (90): 90 × $0.006 = $0.54
- Pro users (10): 10 × $0.23 = $2.30
- **Total AWS: $2.84/month**

### 1,000 Users (80% Free, 20% Pro)

- Free users (800): 800 × $0.006 = $4.80
- Pro users (200): 200 × $0.23 = $46.00
- **Total AWS: $50.80/month**

### 10,000 Users (70% Free, 30% Pro)

- Free users (7,000): 7,000 × $0.006 = $42.00
- Pro users (3,000): 3,000 × $0.23 = $690.00
- **Total AWS: $732.00/month**

**Note:** Cognito costs kick in after 50K MAU, but at 10K users still within free tier.

---

## Revenue vs. Cost Analysis

### 1,000 Users (200 Pro @ $6.99/month)

**Revenue:**
- 200 Pro users × $6.99 = $1,398/month
- After Apple's 30% cut: $978.60/month

**Costs:**
- AWS: $50.80/month
- **Net: $927.80/month**
- **Margin: 94.8%**

### 10,000 Users (3,000 Pro @ $6.99/month)

**Revenue:**
- 3,000 Pro users × $6.99 = $20,970/month
- After Apple's 30% cut: $14,679/month

**Costs:**
- AWS: $732/month
- **Net: $13,947/month**
- **Margin: 95.0%**

---

# COST OPTIMIZATION STRATEGIES

## 1. S3 Intelligent-Tiering

**Savings:** 40-68% on infrequently accessed data

**Implementation:**
- Enable Intelligent-Tiering on bucket
- Automatically moves data to cheaper tiers
- Monitoring cost: $0.0025 per 1,000 objects

**Expected Savings:** ~30% on storage costs

**Example:** 10GB user = $0.23 → $0.16/month (saves $0.07)

---

## 2. DynamoDB On-Demand vs. Provisioned

**Current:** On-Demand (recommended for V1)

**When to Switch to Provisioned:**
- Predictable, steady traffic
- > 1 million requests/month consistently

**Savings Potential:** 50-70% if traffic is predictable

**Recommendation:** Stay on-demand until traffic patterns are clear

---

## 3. CloudWatch Log Retention

**Strategy:** Short retention for most logs, longer for critical

**Implementation:**
```json
{
  "RetentionInDays": 7  // Most logs
}
```

**Critical Logs (errors, auth failures):**
```json
{
  "RetentionInDays": 30  // Important logs
}
```

**Savings:** ~80% reduction in log storage costs

---

## 4. S3 Request Optimization

### Batch Uploads

Instead of uploading immediately, batch small files:

```swift
class UploadQueue {
    private var pendingUploads: [FileUpload] = []
    private let batchSize = 10
    
    func addUpload(_ file: FileUpload) {
        pendingUploads.append(file)
        if pendingUploads.count >= batchSize {
            processBatch()
        }
    }
}
```

**Savings:** Reduces PUT request count by ~20%

### Multipart Upload for Large Files

For files > 5MB, use multipart upload:

```swift
func uploadLargeFile(_ data: Data, to s3Key: String) async throws {
    if data.count > 5_000_000 {
        try await s3Service.multipartUpload(data: data, key: s3Key)
    } else {
        try await s3Service.putObject(data: data, key: s3Key)
    }
}
```

**Savings:** More efficient, but minimal cost impact

---

## 5. DynamoDB Batch Operations

**Current:** Individual writes

**Optimization:** Batch writes where possible

```swift
func syncMultipleFiles(_ files: [VaultFile]) async throws {
    let batches = files.chunked(into: 25) // DynamoDB batch limit
    
    for batch in batches {
        try await dynamoDB.batchWrite(batch)
    }
}
```

**Savings:** Same cost, but faster and more efficient

---

## 6. S3 Lifecycle Policies

**Strategy:** Move old files to cheaper storage

**Implementation:**
```json
{
  "Rules": [
    {
      "Id": "ArchiveOldFiles",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

**Note:** Only use if users rarely access old files. Glacier retrieval has costs.

**Recommendation:** Defer until user behavior is known

---

## 7. Cost Allocation Tags

**Purpose:** Track costs per feature/environment

**Tags to Add:**
- `Environment: production`
- `App: just-vault`
- `Service: s3` / `dynamodb` / `cognito`

**Benefit:** Better cost visibility, not direct savings

---

## 8. Reserved Capacity (Future)

**When:** After 6+ months of stable traffic

**Option:** S3 Reserved Capacity (not available, but concept applies to other services)

**DynamoDB Reserved Capacity:**
- Commit to certain throughput
- Save 50-70% vs. on-demand
- **Only if traffic is predictable**

---

# RESOURCE LIMITS & SCALING

## Cognito Limits

| Limit | Value | Impact |
|-------|-------|--------|
| User Pool size | Unlimited | None |
| Identity Pool size | Unlimited | None |
| MAU (free tier) | 50,000 | Cost increase after |
| Tokens per second | 5,000 | Unlikely to hit |

**Scaling:** Automatic, no action needed

---

## S3 Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Bucket size | Unlimited | None |
| Objects per bucket | Unlimited | None |
| PUT rate | 3,500 PUT/sec | Unlikely to hit |
| GET rate | 5,500 GET/sec | Unlikely to hit |

**Scaling:** Automatic, no action needed

---

## DynamoDB Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Table size | Unlimited | None |
| Item size | 400 KB | Limit file metadata size |
| Throughput (on-demand) | Auto-scales | None |

**Scaling:** Automatic with on-demand mode

---

## When to Scale/Optimize

### Immediate Actions (V1)
- ✅ Use S3 Intelligent-Tiering
- ✅ Set CloudWatch log retention to 7 days
- ✅ Use DynamoDB on-demand
- ✅ Batch DynamoDB writes where possible

### After 1,000 Users
- Review cost allocation tags
- Analyze request patterns
- Consider DynamoDB provisioned if traffic is steady

### After 10,000 Users
- Evaluate S3 lifecycle policies
- Consider multi-region if international users
- Review CloudWatch metric costs

### After 50,000 Users
- Cognito costs start ($0.0055/MAU)
- Consider cost optimization more aggressively
- Evaluate reserved capacity options

---

# INFRASTRUCTURE AS CODE

## CloudFormation Template (Optional)

For reproducible infrastructure:

```yaml
Resources:
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: just-vault-prod-user-pool
      # ... configuration

  IdentityPool:
    Type: AWS::Cognito::IdentityPool
    Properties:
      IdentityPoolName: just-vault-prod-identity-pool
      # ... configuration

  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: just-vault-prod-blobs
      # ... configuration

  DynamoDBTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: JustVault
      # ... configuration
```

**Recommendation:** Use for production, but manual setup is fine for MVP

---

# COST MONITORING

## AWS Cost Explorer

**Setup:**
1. Enable Cost Explorer in AWS Console
2. Create cost allocation tags
3. Set up budgets

**Budgets to Create:**
- Monthly AWS spend: Alert at $100, $500, $1,000
- Per-service budgets: S3, DynamoDB, Cognito

**Alerts:**
- Email when budget threshold reached
- Set at 80% and 100% of budget

---

## Cost Anomaly Detection

**Enable:** AWS Cost Anomaly Detection

**Monitors:**
- Unusual S3 storage increases
- Spike in DynamoDB requests
- Unexpected Cognito usage

**Benefit:** Catch cost issues early

---

# SUMMARY

## Key Takeaways

1. **AWS costs are minimal:** ~$0.23 per 10GB Pro user
2. **High margins:** 94%+ after Apple's cut
3. **Free tier covers:** First 50K Cognito users, 5GB CloudWatch logs
4. **Optimization opportunities:** S3 Intelligent-Tiering, log retention, batch operations
5. **Scaling is automatic:** No manual intervention needed until 50K+ users

## Recommended V1 Configuration

- ✅ S3 with Intelligent-Tiering
- ✅ DynamoDB on-demand
- ✅ CloudWatch logs: 7-day retention
- ✅ Cost allocation tags enabled
- ✅ Budget alerts configured

**Estimated monthly cost for 1,000 users: ~$50**

