# File Upload and Storage System Explanation

## Overview

Just Vault uses a **three-layer storage architecture** to securely store and sync your files:

1. **Local Encrypted Storage** (Primary) - Always available, works offline
2. **AWS S3 Cloud Storage** (Backup) - Encrypted mirror for recovery
3. **DynamoDB Metadata** (Index) - File metadata and sync status

---

## How File Upload Works

### Step 1: User Selects File
- User taps "Add File" button
- Chooses source: **Files**, **Photos**, or **Camera**
- System opens appropriate picker:
  - `DocumentPicker` for files (PDF, images)
  - `ImagePicker` for photos/camera

### Step 2: File Picker Returns URL
- Document picker returns a **security-scoped URL**
- This URL has limited access - must be accessed immediately
- **FIXED**: The system now properly handles security-scoped resources by:
  - Starting access to the security-scoped resource
  - Copying the file to app's temporary directory
  - Stopping access after copy

### Step 3: File Import Process (`FileImportService`)
Located in: `Just Vault/Services/Storage/FileImportService.swift`

The import process:
1. **Read file data** from URL
2. **Get metadata** (filename, extension, MIME type)
3. **Generate unique file ID** (UUID)
4. **Encrypt file** using `EncryptionService`
5. **Save encrypted file** to local storage (`LocalStorageService`)
6. **Generate thumbnail** (if image) and encrypt it
7. **Create VaultFile model** with metadata

### Step 4: Local Storage (`LocalStorageService`)
Located in: `Just Vault/Services/Storage/LocalStorageService.swift`

Files are stored in app sandbox:
```
Documents/Vault/
  ├── files/          # Encrypted files (.enc)
  └── metadata/       # File metadata
```

**Key Methods:**
- `saveEncryptedFile()` - Saves encrypted data to local storage
- `loadEncryptedFile()` - Loads encrypted file for decryption
- `deleteEncryptedFile()` - Removes file from local storage

### Step 5: Cloud Sync (Pro Users Only)
Located in: `Just Vault/Services/Sync/`

**For Pro/Pro+ users:**
1. **Save metadata to DynamoDB** (`DynamoDBService`)
   - File name, size, MIME type, space ID
   - Sync status, timestamps
   - **No file content** - only metadata

2. **Queue file for S3 upload** (`SyncService`)
   - File added to sync queue
   - Uploads happen in background
   - Retries on failure

3. **Upload to S3** (`S3Service`)
   - Encrypted file uploaded to S3
   - Path: `users/{identityId}/files/{fileId}.enc`
   - Thumbnail: `users/{identityId}/thumbs/{fileId}.enc`

**For Free users:**
- Files stored locally only
- No cloud sync
- No S3 upload

---

## File Upload Flow Diagram

```
User Action
    ↓
File Picker (DocumentPicker/ImagePicker)
    ↓
Security-Scoped URL → Copy to Temp Directory
    ↓
FileImportService.importFile()
    ↓
┌─────────────────────────────────────┐
│ 1. Read file data                   │
│ 2. Generate file ID (UUID)          │
│ 3. Encrypt file                     │
│ 4. Save to local storage            │
│ 5. Generate thumbnail (if image)    │
│ 6. Create VaultFile model           │
└─────────────────────────────────────┘
    ↓
Local Storage (Always)
    ↓
┌─────────────────────────────────────┐
│ IF Pro User:                        │
│   - Save metadata to DynamoDB       │
│   - Queue for S3 upload              │
│   - Background sync                 │
└─────────────────────────────────────┘
```

---

## Why File Upload Might Not Work

### Issue 1: Security-Scoped Resource Access ❌ **FIXED**
**Problem:** Document picker URLs are security-scoped and must be accessed immediately. The original code didn't handle this properly.

**Solution:** Updated `DocumentPicker` to:
- Start accessing security-scoped resource
- Copy file to temporary directory
- Stop accessing resource after copy

### Issue 2: Missing Permissions
Check `Info.plist` for required permissions:
- `NSPhotoLibraryUsageDescription` - For photo library access
- `NSCameraUsageDescription` - For camera access
- `UISupportsDocumentBrowser` - For document picker

### Issue 3: File Type Restrictions
Currently supports:
- PDF: `.pdf`
- Images: `.jpeg`, `.png`, `.heic`

Other file types will be rejected.

### Issue 4: Cloud Sync Not Available
- Free users: Files work locally only
- Pro users: Need valid AWS credentials and subscription

---

## File Storage Locations

### Local Storage (All Users)
```
App Sandbox/Documents/Vault/
  ├── files/
  │   ├── {fileId}.enc          # Encrypted file
  │   └── {fileId}_thumb.enc    # Encrypted thumbnail
  └── metadata/
      └── (stored in UserDefaults)
```

### Cloud Storage (Pro Users Only)
```
AWS S3 Bucket:
  users/{identityId}/
    ├── files/{fileId}.enc
    └── thumbs/{fileId}.enc

DynamoDB Table:
  PK: USER#{identityId}
  SK: FILE#{fileId}
  Attributes: name, size, mimeType, spaceId, syncStatus, etc.
```

---

## Encryption Details

- **Encryption Service**: `EncryptionService`
- **Method**: AES-256 encryption
- **Key Management**: Stored in Secure Enclave (iOS)
- **Files encrypted BEFORE** touching AWS
- AWS never sees plaintext

---

## Sync Status

Files have sync status:
- `pending` - Queued for upload
- `syncing` - Currently uploading
- `synced` - Successfully uploaded
- `error` - Upload failed (will retry)

---

## Troubleshooting

### File upload fails silently
1. Check console logs for errors
2. Verify file type is supported
3. Check available storage space
4. Verify encryption service is working

### Files not appearing
1. Check if space is locked
2. Verify file was saved to local storage
3. Check DynamoDB (Pro users) for metadata
4. Refresh spaces view

### Cloud sync not working
1. Verify user has Pro subscription
2. Check AWS credentials
3. Check network connection
4. Review sync queue status

---

## Code Files Reference

- **File Import**: `Just Vault/Services/Storage/FileImportService.swift`
- **Local Storage**: `Just Vault/Services/Storage/LocalStorageService.swift`
- **S3 Service**: `Just Vault/Services/Sync/S3Service.swift`
- **DynamoDB Service**: `Just Vault/Services/Sync/DynamoDBService.swift`
- **Sync Service**: `Just Vault/Services/Sync/SyncService.swift`
- **Document Picker**: `Just Vault/Views/Vault/SpaceDetailView.swift` (DocumentPicker struct)
- **Image Picker**: `Just Vault/Views/Vault/ImagePicker.swift`
- **File Model**: `Just Vault/Models/VaultFile.swift`

---

## Recent Fixes Applied

✅ **Fixed DocumentPicker security-scoped resource access**
   - Now properly handles iOS security-scoped URLs
   - Copies files to temporary directory for access
   - Prevents "file not accessible" errors

✅ **File upload flow verified**
   - All components in place
   - Encryption working
   - Local storage working
   - Cloud sync ready (for Pro users)

