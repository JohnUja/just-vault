# 🔐 AWS SSO Setup Guide - Just Vault

## Current Configuration ✅

You're using **AWS IAM Identity Center (SSO)** - this is the **recommended and more secure** approach!

**Your Setup:**
- ✅ Authentication: AWS IAM Identity Center (SSO)
- ✅ Profile: `just-vault`
- ✅ Role: AdministratorAccess
- ✅ Account ID: `491085415425`
- ✅ Region: `us-east-1`
- ✅ Output: `json`

---

## How SSO Works

Instead of long-lived access keys, SSO provides:
- **Temporary credentials** (valid for a few hours)
- **Automatic refresh** when you log in
- **Better security** (no static keys to manage)
- **Role-based access** (you assume a role)

---

## Using AWS CLI with SSO

### Login (When Credentials Expire)

```bash
# Login to SSO (opens browser for authentication)
aws sso login --profile just-vault
```

**When to run:**
- First time using CLI
- When credentials expire (usually every 8-12 hours)
- If you get "credentials expired" errors

### All Commands Need Profile Flag

**Important:** All AWS CLI commands must include `--profile just-vault`

```bash
# ✅ CORRECT - With profile
aws s3 ls --profile just-vault
aws dynamodb describe-table --table-name JustVault --profile just-vault
aws sts get-caller-identity --profile just-vault

# ❌ WRONG - Without profile (won't work)
aws s3 ls
aws dynamodb describe-table --table-name JustVault
```

---

## Updated Setup Script (SSO Version)

Here's the updated setup script that uses your SSO profile:

```bash
#!/bin/bash
# setup-aws-sso.sh - Complete AWS setup for Just Vault (SSO version)

set -e  # Exit on error

PROFILE="just-vault"
REGION="us-east-1"
ACCOUNT_ID="491085415425"
BUCKET_NAME="just-vault-prod-blobs"
TABLE_NAME="JustVault"
USER_POOL_NAME="just-vault-prod-user-pool"
IDENTITY_POOL_NAME="just-vault-prod-identity-pool"

echo "🚀 Setting up Just Vault AWS infrastructure (SSO)..."
echo "Profile: $PROFILE"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Verify SSO login
echo "🔐 Verifying SSO authentication..."
aws sts get-caller-identity --profile $PROFILE || {
    echo "❌ Not logged in. Please run: aws sso login --profile $PROFILE"
    exit 1
}
echo "✅ SSO authenticated"
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
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile $PROFILE

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --profile $PROFILE

# Enable Intelligent-Tiering
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket $BUCKET_NAME \
  --id "EntireBucket" \
  --intelligent-tiering-configuration '{
    "Id": "EntireBucket",
    "Status": "Enabled",
    "Filter": {}
  }' \
  --profile $PROFILE

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
    Key=App,Value=just-vault \
  --profile $PROFILE

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
  --output text \
  --profile $PROFILE)

echo "✅ User Pool created: $USER_POOL_ID"

# Step 4: Create User Pool Client
echo "📱 Creating User Pool Client..."
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name "just-vault-ios-client" \
  --generate-secret \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH \
  --query 'UserPoolClient.ClientId' \
  --output text \
  --profile $PROFILE)

echo "✅ User Pool Client created: $CLIENT_ID"

# Continue with remaining steps (IAM roles, Identity Pool, etc.)
# ... (rest of setup script with --profile $PROFILE added to all commands)

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Configuration Summary:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $TABLE_NAME"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
```

---

## Environment Variables (For SDK Usage)

### Option 1: Use AWS SDK Profile (Recommended for iOS)

The AWS SDK for Swift can use the same SSO profile:

```swift
// In your iOS app
import AWSCore

// Configure to use SSO profile
let credentialsProvider = AWSCredentialsProviderChain()
// SDK will automatically use ~/.aws/config and ~/.aws/credentials
```

**Note:** For iOS app, you'll still need to use Cognito Identity Pool for end users (not SSO). SSO is for your admin/CLI access.

### Option 2: Export Temporary Credentials (For Scripts)

If you need environment variables for scripts:

```bash
# Get temporary credentials from SSO session
aws configure export-credentials --profile just-vault --format env

# This outputs:
# export AWS_ACCESS_KEY_ID=...
# export AWS_SECRET_ACCESS_KEY=...
# export AWS_SESSION_TOKEN=...
```

**⚠️ Warning:** These expire quickly (hours), so only use for short-lived scripts.

---

## Updated Individual Commands

All commands from `AWS_CLI_SETUP.md` need `--profile just-vault`:

### S3 Commands

```bash
# Create bucket
aws s3api create-bucket \
  --bucket just-vault-prod-blobs \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1 \
  --profile just-vault

# List bucket
aws s3 ls s3://just-vault-prod-blobs --profile just-vault
```

### DynamoDB Commands

```bash
# Create table
aws dynamodb create-table \
  --table-name JustVault \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --profile just-vault

# Describe table
aws dynamodb describe-table --table-name JustVault --profile just-vault
```

### Cognito Commands

```bash
# Create user pool
aws cognito-idp create-user-pool \
  --pool-name just-vault-prod-user-pool \
  --profile just-vault

# List user pools
aws cognito-idp list-user-pools --max-results 10 --profile just-vault
```

---

## Setting Default Profile (Optional)

You can set a default profile to avoid typing `--profile` every time:

```bash
# Set environment variable
export AWS_PROFILE=just-vault

# Now commands work without --profile flag
aws s3 ls
aws sts get-caller-identity

# Add to your ~/.zshrc or ~/.bashrc to make permanent
echo 'export AWS_PROFILE=just-vault' >> ~/.zshrc
```

**Note:** This is optional - you can always use `--profile just-vault` explicitly.

---

## For iOS App (Important Distinction)

### Your SSO Profile (Admin Access)
- **Purpose:** For you (developer) to manage AWS resources
- **Used by:** AWS CLI, setup scripts, infrastructure management
- **Not used by:** iOS app end users

### Cognito Identity Pool (End User Access)
- **Purpose:** For app users to access their own S3/DynamoDB data
- **Used by:** iOS app (via AWS SDK)
- **Authentication:** Apple Sign In → Cognito → Temporary AWS credentials
- **Setup:** Still needed (this is different from your SSO)

**Key Point:** Your SSO is for **admin** access. End users use **Cognito Identity Pool** (which we'll set up).

---

## GitHub Actions / CI/CD (If Needed Later)

For automation, you have options:

### Option 1: OIDC (Recommended)
- Use GitHub OIDC to assume AWS role
- No long-lived keys needed
- More secure

### Option 2: Temporary Credentials
- Export from SSO session
- Use in GitHub Secrets
- Rotate regularly

### Option 3: IAM User (If Required)
- Create dedicated IAM user for CI/CD
- Use access keys (store in GitHub Secrets)
- Limit permissions

**For now:** Not needed until you set up CI/CD.

---

## Verification Commands

```bash
# Verify SSO login
aws sts get-caller-identity --profile just-vault

# Check S3 access
aws s3 ls --profile just-vault

# Check DynamoDB access
aws dynamodb list-tables --profile just-vault

# Check Cognito access
aws cognito-idp list-user-pools --max-results 1 --profile just-vault
```

---

## Troubleshooting

### "The SSO session associated with this profile has expired"

**Solution:**
```bash
aws sso login --profile just-vault
```

### "Unable to locate credentials"

**Solution:**
- Make sure you've run `aws sso login --profile just-vault`
- Check that profile exists: `aws configure list-profiles`
- Verify profile config: `cat ~/.aws/config`

### "Access Denied"

**Solution:**
- Verify your SSO role has necessary permissions
- Check that you're using the correct profile: `--profile just-vault`
- Verify account ID matches: `aws sts get-caller-identity --profile just-vault`

---

## Next Steps

1. ✅ **You're already set up!** SSO is configured and working
2. ✅ **Run setup script** with `--profile just-vault` on all commands
3. ✅ **Continue with infrastructure setup** from `AWS_CLI_SETUP.md` (just add `--profile just-vault`)

---

## Summary

✅ **SSO is better** - More secure than access keys  
✅ **Use `--profile just-vault`** on all CLI commands  
✅ **Login when needed:** `aws sso login --profile just-vault`  
✅ **For iOS app:** Still uses Cognito Identity Pool (different from your SSO)  

**You're all set!** 🚀

