# 🚀 AWS CLI SETUP GUIDE - JUST VAULT

## Quick Answers to Your Questions

### ✅ **YES - You can run everything in terminal!**
All AWS resources can be set up using AWS CLI commands. This guide provides all the commands you need.

### ✅ **NO - No manual scaling setup needed!**
Everything scales automatically:
- **S3:** Unlimited, auto-scales
- **DynamoDB (on-demand):** Auto-scales, no configuration needed
- **Cognito:** Auto-scales, no configuration needed

### ✅ **NO - CloudFormation/Terraform NOT required for V1!**
You can set everything up manually via:
- AWS Console (GUI)
- AWS CLI (terminal) ← **This guide**
- CloudFormation/Terraform (optional, for later)

**For V1/MVP:** AWS CLI is perfect. CloudFormation is nice-to-have for production but not required.

---

## Prerequisites

### 1. Install AWS CLI

```bash
# macOS
brew install awscli

# Or download from: https://aws.amazon.com/cli/
```

### 2. Configure AWS Credentials

**Option A: AWS SSO (Recommended - More Secure)**
```bash
# Configure SSO profile
aws configure sso --profile just-vault

# Login when needed
aws sso login --profile just-vault

# Verify
aws sts get-caller-identity --profile just-vault
```

**Option B: Access Keys (Traditional)**
```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1` (or your preferred region)
- Default output format: `json`

### 3. Verify Installation

```bash
aws --version

# For SSO:
aws sts get-caller-identity --profile just-vault

# For Access Keys:
aws sts get-caller-identity
```

**Note:** If using SSO, all commands in this guide need `--profile just-vault` flag. See `AWS_SSO_SETUP.md` for SSO-specific instructions.

---

## Setup Script

Create a setup script to run everything at once:

```bash
#!/bin/bash
# setup-aws.sh - Complete AWS setup for Just Vault

set -e  # Exit on error

REGION="us-east-1"
PROFILE="just-vault"  # Change to "default" if using access keys
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
BUCKET_NAME="just-vault-prod-blobs"
TABLE_NAME="JustVault"
USER_POOL_NAME="just-vault-prod-user-pool"
IDENTITY_POOL_NAME="just-vault-prod-identity-pool"

echo "🚀 Setting up Just Vault AWS infrastructure..."
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Step 1: Create S3 Bucket
echo "📦 Creating S3 bucket..."
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION \
  --profile $PROFILE

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Enable Intelligent-Tiering
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket $BUCKET_NAME \
  --id "EntireBucket" \
  --intelligent-tiering-configuration '{
    "Id": "EntireBucket",
    "Status": "Enabled",
    "Filter": {}
  }'

echo "✅ S3 bucket created"

# Step 2: Create DynamoDB Table
echo "📊 Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags \
    Key=Environment,Value=production \
    Key=App,Value=just-vault

echo "✅ DynamoDB table created"

# Step 3: Create Cognito User Pool
echo "🔐 Creating Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name $USER_POOL_NAME \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": false,
      "RequireLowercase": false,
      "RequireNumbers": false,
      "RequireSymbols": false
    }
  }' \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": false
    }
  ]' \
  --auto-verified-attributes [] \
  --mfa-configuration OFF \
  --query 'UserPool.Id' \
  --output text)

echo "✅ User Pool created: $USER_POOL_ID"

# Step 4: Create User Pool Client
echo "📱 Creating User Pool Client..."
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name "just-vault-ios-client" \
  --generate-secret \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH \
  --query 'UserPoolClient.ClientId' \
  --output text)

echo "✅ User Pool Client created: $CLIENT_ID"

# Step 5: Create IAM Role for Authenticated Users
echo "👤 Creating IAM Role..."
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "cognito-identity.amazonaws.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "cognito-identity.amazonaws.com:aud": "IDENTITY_POOL_ID_PLACEHOLDER"
      },
      "ForAnyValue:StringLike": {
        "cognito-identity.amazonaws.com:amr": "authenticated"
      }
    }
  }]
}
EOF

ROLE_ARN=$(aws iam create-role \
  --role-name JustVaultAuthenticatedUserRole \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --query 'Role.Arn' \
  --output text)

echo "✅ IAM Role created: $ROLE_ARN"

# Step 6: Create S3 Policy
cat > /tmp/s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOwnPrefixOnly",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::$BUCKET_NAME",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "users/\${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    },
    {
      "Sid": "RWOwnObjectsOnly",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/users/\${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
EOF

# Step 7: Create DynamoDB Policy
cat > /tmp/dynamodb-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ],
    "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$TABLE_NAME",
    "Condition": {
      "ForAllValues:StringLike": {
        "dynamodb:LeadingKeys": [
          "USER#\${cognito-identity.amazonaws.com:sub}"
        ]
      }
    }
  }]
}
EOF

# Attach policies to role
aws iam put-role-policy \
  --role-name JustVaultAuthenticatedUserRole \
  --policy-name S3AccessPolicy \
  --policy-document file:///tmp/s3-policy.json

aws iam put-role-policy \
  --role-name JustVaultAuthenticatedUserRole \
  --policy-name DynamoDBAccessPolicy \
  --policy-document file:///tmp/dynamodb-policy.json

echo "✅ IAM Policies attached"

# Step 8: Create Cognito Identity Pool
echo "🆔 Creating Identity Pool..."
IDENTITY_POOL_ID=$(aws cognito-identity create-identity-pool \
  --identity-pool-name $IDENTITY_POOL_NAME \
  --allow-unauthenticated-identities \
  --cognito-identity-providers \
    ProviderName=cognito-idp.$REGION.amazonaws.com/$USER_POOL_ID,ClientId=$CLIENT_ID \
  --query 'IdentityPoolId' \
  --output text)

echo "✅ Identity Pool created: $IDENTITY_POOL_ID"

# Update trust policy with actual Identity Pool ID
sed "s/IDENTITY_POOL_ID_PLACEHOLDER/$IDENTITY_POOL_ID/g" /tmp/trust-policy.json > /tmp/trust-policy-updated.json
aws iam update-assume-role-policy \
  --role-name JustVaultAuthenticatedUserRole \
  --policy-document file:///tmp/trust-policy-updated.json

# Set authenticated role
aws cognito-identity set-identity-pool-roles \
  --identity-pool-id $IDENTITY_POOL_ID \
  --roles authenticated=$ROLE_ARN

echo "✅ Identity Pool configured"

# Step 9: Create CloudWatch Log Groups
echo "📝 Creating CloudWatch Log Groups..."
aws logs create-log-group --log-group-name /aws/just-vault/app
aws logs create-log-group --log-group-name /aws/just-vault/sync
aws logs create-log-group --log-group-name /aws/just-vault/errors

aws logs put-retention-policy --log-group-name /aws/just-vault/app --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/sync --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/errors --retention-in-days 30

echo "✅ CloudWatch Log Groups created"

# Step 10: Add Cost Allocation Tags
echo "💰 Tagging resources..."
aws s3api put-bucket-tagging \
  --bucket $BUCKET_NAME \
  --tagging 'TagSet=[{Key=Environment,Value=production},{Key=App,Value=just-vault}]'

aws dynamodb tag-resource \
  --resource-arn "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$TABLE_NAME" \
  --tags Key=Environment,Value=production Key=App,Value=just-vault

echo "✅ Resources tagged"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Configuration Summary:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $TABLE_NAME"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Identity Pool ID: $IDENTITY_POOL_ID"
echo "  IAM Role: $ROLE_ARN"
echo ""
echo "⚠️  Next Steps:"
echo "  1. Configure Apple Sign In in Cognito User Pool (via Console)"
echo "  2. Add these values to your iOS app configuration"
echo "  3. Test authentication flow"
```

---

## Individual Commands (If You Prefer Step-by-Step)

### 1. Create S3 Bucket

```bash
# Create bucket
aws s3api create-bucket \
  --bucket just-vault-prod-blobs \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1

# Block public access
aws s3api put-public-access-block \
  --bucket just-vault-prod-blobs \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket just-vault-prod-blobs \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Enable Intelligent-Tiering
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket just-vault-prod-blobs \
  --id "EntireBucket" \
  --intelligent-tiering-configuration '{
    "Id": "EntireBucket",
    "Status": "Enabled",
    "Filter": {}
  }'
```

---

### 2. Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name JustVault \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags \
    Key=Environment,Value=production \
    Key=App,Value=just-vault
```

---

### 3. Create Cognito User Pool

```bash
# Create User Pool
aws cognito-idp create-user-pool \
  --pool-name just-vault-prod-user-pool \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8
    }
  }' \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": false
    }
  ]' \
  --auto-verified-attributes [] \
  --mfa-configuration OFF

# Note the UserPoolId from output, then create client:
aws cognito-idp create-user-pool-client \
  --user-pool-id <USER_POOL_ID> \
  --client-name "just-vault-ios-client" \
  --generate-secret \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH
```

**⚠️ Apple Sign In:** Must be configured via AWS Console (GUI) - can't be done via CLI easily.

---

### 4. Create Cognito Identity Pool

```bash
aws cognito-identity create-identity-pool \
  --identity-pool-name just-vault-prod-identity-pool \
  --allow-unauthenticated-identities \
  --cognito-identity-providers \
    ProviderName=cognito-idp.us-east-1.amazonaws.com/<USER_POOL_ID>,ClientId=<CLIENT_ID>
```

---

### 5. Create IAM Role

```bash
# Create trust policy file
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "cognito-identity.amazonaws.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "cognito-identity.amazonaws.com:aud": "<IDENTITY_POOL_ID>"
      },
      "ForAnyValue:StringLike": {
        "cognito-identity.amazonaws.com:amr": "authenticated"
      }
    }
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name JustVaultAuthenticatedUserRole \
  --assume-role-policy-document file://trust-policy.json

# Create and attach S3 policy
cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOwnPrefixOnly",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::just-vault-prod-blobs",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "users/\${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    },
    {
      "Sid": "RWOwnObjectsOnly",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::just-vault-prod-blobs/users/\${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name JustVaultAuthenticatedUserRole \
  --policy-name S3AccessPolicy \
  --policy-document file://s3-policy.json

# Create and attach DynamoDB policy
cat > dynamodb-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ],
    "Resource": "arn:aws:dynamodb:us-east-1:<ACCOUNT_ID>:table/JustVault",
    "Condition": {
      "ForAllValues:StringLike": {
        "dynamodb:LeadingKeys": [
          "USER#\${cognito-identity.amazonaws.com:sub}"
        ]
      }
    }
  }]
}
EOF

aws iam put-role-policy \
  --role-name JustVaultAuthenticatedUserRole \
  --policy-name DynamoDBAccessPolicy \
  --policy-document file://dynamodb-policy.json

# Link role to Identity Pool
aws cognito-identity set-identity-pool-roles \
  --identity-pool-id <IDENTITY_POOL_ID> \
  --roles authenticated=arn:aws:iam::<ACCOUNT_ID>:role/JustVaultAuthenticatedUserRole
```

---

### 6. Create CloudWatch Log Groups

```bash
aws logs create-log-group --log-group-name /aws/just-vault/app
aws logs create-log-group --log-group-name /aws/just-vault/sync
aws logs create-log-group --log-group-name /aws/just-vault/errors

aws logs put-retention-policy --log-group-name /aws/just-vault/app --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/sync --retention-in-days 7
aws logs put-retention-policy --log-group-name /aws/just-vault/errors --retention-in-days 30
```

---

## Verification Commands

### Check S3 Bucket

```bash
aws s3 ls s3://just-vault-prod-blobs
aws s3api get-bucket-encryption --bucket just-vault-prod-blobs
```

### Check DynamoDB Table

```bash
aws dynamodb describe-table --table-name JustVault
```

### Check Cognito

```bash
aws cognito-idp describe-user-pool --user-pool-id <USER_POOL_ID>
aws cognito-identity describe-identity-pool --identity-pool-id <IDENTITY_POOL_ID>
```

### Check IAM Role

```bash
aws iam get-role --role-name JustVaultAuthenticatedUserRole
aws iam list-role-policies --role-name JustVaultAuthenticatedUserRole
```

---

## Scaling - Automatic! ✅

### S3
- **No configuration needed**
- Scales automatically to unlimited
- No limits on bucket size or objects

### DynamoDB (On-Demand Mode)
- **No configuration needed**
- Auto-scales based on traffic
- Handles any traffic spike automatically
- You only pay for what you use

### Cognito
- **No configuration needed**
- Scales automatically
- Handles millions of users

**Bottom Line:** Set it and forget it. Everything scales automatically until you hit AWS account limits (which are very high).

---

## CloudFormation/Terraform - Optional

### Do You Need It?

**For V1/MVP:** ❌ **NO**

**For Production (Later):** ✅ **Nice to have**

### Why Not Required?

1. **Simple setup:** Only 4-5 AWS services
2. **One-time setup:** Not changing frequently
3. **AWS CLI works:** Can script everything
4. **Manual is fine:** Console or CLI is sufficient

### When to Consider It?

- Multiple environments (dev, staging, prod)
- Frequent infrastructure changes
- Team collaboration
- Compliance requirements
- Disaster recovery (recreate from code)

### If You Want It Later

I can create CloudFormation templates, but for V1, **AWS CLI is perfect and faster**.

---

## Quick Start Checklist

- [ ] Install AWS CLI
- [ ] Run `aws configure`
- [ ] Run setup script (or individual commands)
- [ ] Configure Apple Sign In in Cognito (via Console - one-time GUI step)
- [ ] Test with iOS app
- [ ] Done! 🎉

---

## Troubleshooting

### "Access Denied" Errors

```bash
# Check your credentials
aws sts get-caller-identity

# Verify permissions
aws iam get-user
```

### Bucket Already Exists

```bash
# List existing buckets
aws s3 ls

# Use different name or delete existing
aws s3api delete-bucket --bucket <bucket-name>
```

### Region Issues

```bash
# Set default region
aws configure set region us-east-1

# Or specify in each command
aws s3api create-bucket --bucket <name> --region us-east-1
```

---

## Summary

✅ **Terminal/CLI:** Yes, everything can be done via AWS CLI  
✅ **Scaling:** Automatic, no setup needed  
✅ **CloudFormation:** Not required for V1, optional for later  

**You're all set!** Just run the setup script and you're good to go. 🚀

