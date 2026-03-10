# Backup & Restore System Documentation

## How Backup Works

### For Pro/Pro+ Users:

1. **File Upload Flow:**
   - User adds file to space
   - File is encrypted locally using AES-256
   - Encrypted file is saved to local storage
   - Metadata (name, size, space ID, etc.) is saved to DynamoDB
   - Encrypted file is queued for S3 upload
   - Background sync service uploads to S3: `users/{identityId}/files/{fileId}.enc`
   - Thumbnail (if image) uploaded to: `users/{identityId}/thumbs/{fileId}.enc`

2. **Space Backup:**
   - Space metadata saved to DynamoDB
   - Space ID, name, icon, color, orderIndex stored
   - User profile (subscription, storage usage) saved to DynamoDB

3. **Encryption Keys:**
   - Keys stored in iOS Keychain (device-specific)
   - Recovery phrase can be generated for cross-device restore

## How Restore Works (New Device)

### Step 1: User Signs In
- Apple Sign In authenticates user
- Cognito Identity Pool provides AWS credentials
- User profile loaded from DynamoDB

### Step 2: Restore Spaces
- Load all spaces from DynamoDB for user ID
- Recreate 6 default spaces if missing
- Restore space metadata (name, icon, color, order)

### Step 3: Restore Files
- Load file metadata from DynamoDB
- For each file:
  - Download encrypted file from S3
  - Decrypt using encryption keys (from Keychain or recovery phrase)
  - Save to local storage
  - Restore thumbnail if available

### Step 4: Sync Status
- Files marked as "synced" once downloaded
- Local files merged with cloud files
- Duplicates avoided (by file ID)

## Recovery Phrase System

### For Cross-Device Restore:
1. User generates recovery phrase (12 words)
2. Recovery phrase can derive encryption keys
3. On new device:
   - User enters recovery phrase
   - Keys are derived from phrase
   - Files can be decrypted and restored

### Security:
- Recovery phrase stored only locally (never in cloud)
- User must manually save phrase
- Phrase can regenerate keys if device is lost

## AWS Credentials Error Fix

### Issue:
`CredentialError error 0` occurs when:
- Credentials expired (1 hour default)
- Keychain access fails
- Cognito Identity Pool not configured correctly

### Solution:
1. **Check Credential Expiration:**
   - Credentials expire after 1 hour
   - Need to refresh before expiration
   - Check `expirationDate` in CredentialManager

2. **Keychain Access:**
   - Ensure app has Keychain access permission
   - Check Keychain service name matches
   - Verify credentials are being saved correctly

3. **Cognito Configuration:**
   - Verify Identity Pool ID is correct
   - Check OIDC provider is configured
   - Ensure User Pool ID matches

### For Pro Members:
- Credentials should auto-refresh
- If refresh fails, user needs to re-authenticate
- Developer mode should bypass credential checks

