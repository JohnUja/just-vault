#!/bin/bash
# setup-aws-sso.sh - Complete AWS setup for Just Vault (SSO version)
# Fixed: us-east-1 S3 bucket, public Cognito client, complete IAM setup

set -e  # Exit on error

PROFILE="just-vault"
REGION="us-east-1"
BUCKET_NAME="just-vault-prod-blobs"
TABLE_NAME="JustVault"
USER_POOL_NAME="just-vault-prod-user-pool"
IDENTITY_POOL_NAME="just-vault-prod-identity-pool"
ROLE_NAME="JustVaultAuthenticatedUserRole"

echo "🚀 Setting up Just Vault AWS infrastructure (SSO)..."
echo "Profile: $PROFILE"
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

# Get Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
echo "Account ID: $ACCOUNT_ID"
echo ""

# Step 1: Create S3 Bucket
echo "📦 Creating S3 bucket..."
# FIX: us-east-1 doesn't need LocationConstraint
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --profile $PROFILE 2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
else
  aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION \
    --profile $PROFILE 2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
fi

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

echo "✅ S3 bucket created/configured"

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
  --profile $PROFILE 2>&1 | grep -v "ResourceInUseException" || {
    echo "   Table already exists, continuing..."
  }

echo "✅ DynamoDB table created/verified"

# Step 3: Create Cognito User Pool
echo "🔐 Creating Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --profile $PROFILE --query "UserPools[?Name=='$USER_POOL_NAME'].Id" --output text 2>/dev/null || echo "")

if [ -z "$USER_POOL_ID" ]; then
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
else
  echo "✅ User Pool already exists: $USER_POOL_ID"
fi

# Step 4: Create User Pool Client (PUBLIC - no secret for iOS)
echo "📱 Creating User Pool Client (public, no secret for iOS)..."
CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --user-pool-id $USER_POOL_ID \
  --profile $PROFILE \
  --query "UserPoolClients[?ClientName=='just-vault-ios-client'].ClientId" \
  --output text 2>/dev/null || echo "")

if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id $USER_POOL_ID \
    --client-name "just-vault-ios-client" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' \
    --output text \
    --profile $PROFILE)
  echo "✅ User Pool Client created: $CLIENT_ID"
else
  echo "✅ User Pool Client already exists: $CLIENT_ID"
fi

# Step 5: Create IAM Role for Authenticated Users
echo "👤 Creating IAM Role..."
# Check if role exists
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --profile $PROFILE --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
  # Create trust policy (will update with Identity Pool ID later)
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
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --query 'Role.Arn' \
    --output text \
    --profile $PROFILE)
  echo "✅ IAM Role created: $ROLE_ARN"
else
  echo "✅ IAM Role already exists: $ROLE_ARN"
fi

# Step 6: Create and Attach S3 Policy
echo "📄 Creating S3 IAM Policy..."
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

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name S3AccessPolicy \
  --policy-document file:///tmp/s3-policy.json \
  --profile $PROFILE

echo "✅ S3 Policy attached"

# Step 7: Create and Attach DynamoDB Policy
echo "📄 Creating DynamoDB IAM Policy..."
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

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name DynamoDBAccessPolicy \
  --policy-document file:///tmp/dynamodb-policy.json \
  --profile $PROFILE

echo "✅ DynamoDB Policy attached"

# Step 8: Create Cognito Identity Pool
echo "🆔 Creating Cognito Identity Pool..."
IDENTITY_POOL_ID=$(aws cognito-identity list-identity-pools \
  --max-results 60 \
  --profile $PROFILE \
  --query "IdentityPools[?IdentityPoolName=='$IDENTITY_POOL_NAME'].IdentityPoolId" \
  --output text 2>/dev/null || echo "")

if [ -z "$IDENTITY_POOL_ID" ]; then
  IDENTITY_POOL_ID=$(aws cognito-identity create-identity-pool \
    --identity-pool-name $IDENTITY_POOL_NAME \
    --allow-unauthenticated-identities false \
    --cognito-identity-providers \
      ProviderName=cognito-idp.$REGION.amazonaws.com/$USER_POOL_ID,ClientId=$CLIENT_ID \
    --query 'IdentityPoolId' \
    --output text \
    --profile $PROFILE)
  echo "✅ Identity Pool created: $IDENTITY_POOL_ID"
else
  echo "✅ Identity Pool already exists: $IDENTITY_POOL_ID"
fi

# Step 9: Update IAM Role Trust Policy with Identity Pool ID
echo "🔗 Updating IAM Role trust policy..."
sed "s/IDENTITY_POOL_ID_PLACEHOLDER/$IDENTITY_POOL_ID/g" /tmp/trust-policy.json > /tmp/trust-policy-updated.json
aws iam update-assume-role-policy \
  --role-name $ROLE_NAME \
  --policy-document file:///tmp/trust-policy-updated.json \
  --profile $PROFILE

echo "✅ IAM Role trust policy updated"

# Step 10: Link Role to Identity Pool
echo "🔗 Linking IAM Role to Identity Pool..."
aws cognito-identity set-identity-pool-roles \
  --identity-pool-id $IDENTITY_POOL_ID \
  --roles authenticated=$ROLE_ARN \
  --profile $PROFILE

echo "✅ Identity Pool roles configured"

# Step 11: Create CloudWatch Log Groups
echo "📝 Creating CloudWatch Log Groups..."
for LOG_GROUP in "/aws/just-vault/app" "/aws/just-vault/sync" "/aws/just-vault/errors"; do
  aws logs create-log-group \
    --log-group-name $LOG_GROUP \
    --profile $PROFILE 2>&1 | grep -v "ResourceAlreadyExistsException" || true
done

aws logs put-retention-policy --log-group-name /aws/just-vault/app --retention-in-days 7 --profile $PROFILE
aws logs put-retention-policy --log-group-name /aws/just-vault/sync --retention-in-days 7 --profile $PROFILE
aws logs put-retention-policy --log-group-name /aws/just-vault/errors --retention-in-days 30 --profile $PROFILE

echo "✅ CloudWatch Log Groups created/configured"

# Step 12: Add Cost Allocation Tags
echo "💰 Tagging resources..."
aws s3api put-bucket-tagging \
  --bucket $BUCKET_NAME \
  --tagging 'TagSet=[{Key=Environment,Value=production},{Key=App,Value=just-vault}]' \
  --profile $PROFILE

aws dynamodb tag-resource \
  --resource-arn "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$TABLE_NAME" \
  --tags Key=Environment,Value=production Key=App,Value=just-vault \
  --profile $PROFILE

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
echo "⚠️  IMPORTANT: Configure Apple Sign In in Cognito User Pool via AWS Console"
echo "   User Pool ID: $USER_POOL_ID"
echo "   Steps:"
echo "   1. Go to AWS Console → Cognito → User Pools"
echo "   2. Select your User Pool: $USER_POOL_ID"
echo "   3. Sign-in experience → Federated identity provider sign-in"
echo "   4. Add Apple as OIDC provider"
echo "   5. Use your Apple Developer Client ID"
echo ""
echo "📱 iOS App Configuration:"
echo "   Add these to your iOS app:"
echo "   - User Pool ID: $USER_POOL_ID"
echo "   - Client ID: $CLIENT_ID"
echo "   - Identity Pool ID: $IDENTITY_POOL_ID"
echo "   - Region: $REGION"
echo ""
