# 🚀 Phase 1: Xcode Project Configuration Guide

## Current Status
- ✅ Bundle ID: `com.juvantagecloud.justvault` (already set in Xcode)
- ✅ Team: JOHN UJA (already configured)
- ✅ Auto-signing: Enabled

---

## Step 1: Add "Sign in with Apple" Capability

### In Xcode:
1. **Select your project** in the Project Navigator (blue icon at top)
2. **Select the "Just Vault" target** (under TARGETS)
3. **Click the "Signing & Capabilities" tab** (you're already here!)
4. **Click the "+ Capability" button** (top left of the capabilities section)
5. **Search for "Sign in with Apple"** and double-click it
6. ✅ Done! You should see "Sign in with Apple" appear in the capabilities list

**Why:** Required for Apple Sign In authentication flow.

---

## Step 2: Add Background Modes Capability

### In Xcode:
1. **Still in "Signing & Capabilities" tab**
2. **Click "+ Capability" again**
3. **Search for "Background Modes"** and double-click it
4. **Check the boxes for:**
   - ☑️ "Background fetch" (for sync operations)
   - ☑️ "Background processing" (for file uploads/downloads)
5. ✅ Done!

**Why:** Allows the app to sync files in the background.

---

## Step 3: Install Swift Package Dependencies

### In Xcode:
1. **Select your project** in Project Navigator (blue icon)
2. **Select the "Just Vault" project** (not target, the project itself)
3. **Click "Package Dependencies" tab** (at the top)
4. **Click the "+" button** (bottom left)

### Add AWS SDK for Swift:
5. **Paste this URL:**
   ```
   https://github.com/awslabs/aws-sdk-swift
   ```
6. **Click "Add Package"**
7. **Select version:** "Up to Next Major Version" with `1.0.0`
8. **Click "Add Package"**
9. **Select these products:**
   - ☑️ `AWSCognitoIdentity` (for Identity Pool)
   - ☑️ `AWSCognitoIdentityProvider` (for User Pool)
   - ☑️ `AWSS3` (for S3 file storage)
   - ☑️ `AWSDynamoDB` (for metadata storage)
10. **Click "Add Package"**

### Add BIP39 Library:
11. **Click "+" again** (in Package Dependencies)
12. **Paste this URL:**
    ```
    https://github.com/keefertaylor/Bip39.swift
    ```
13. **Click "Add Package"**
14. **Select version:** "Up to Next Major Version" with `1.0.0`
15. **Click "Add Package"**
16. **Select product:**
    - ☑️ `Bip39`
17. **Click "Add Package"**

✅ **Done!** You should see both packages in the Package Dependencies list.

**Why:**
- AWS SDK: Required for Cognito, S3, and DynamoDB integration
- BIP39: Required for generating recovery phrases

---

## Step 4: Configure Info.plist Privacy Descriptions

### In Xcode:
1. **Find "Info.plist"** in Project Navigator (or "Info" tab in target settings)
2. **If you see "Info" tab** in target settings, use that (easier)
3. **If you see Info.plist file**, open it

### Add Privacy Descriptions:
4. **Click "+" to add new row** for each of these:

#### a) Photo Library Access (for importing photos):
   - **Key:** `NSPhotoLibraryUsageDescription`
   - **Type:** String
   - **Value:** `"Just Vault needs access to your photos to securely store them in your vault."`

#### b) Camera Access (for taking photos):
   - **Key:** `NSCameraUsageDescription`
   - **Type:** String
   - **Value:** `"Just Vault needs camera access to capture photos and securely store them in your vault."`

#### c) Files Access (for importing documents):
   - **Key:** `NSDocumentsFolderUsageDescription`
   - **Type:** String
   - **Value:** `"Just Vault needs access to your files to securely store them in your vault."`

#### d) Network Access (for cloud sync):
   - **Key:** `NSAppTransportSecurity` (Dictionary)
   - **Value:** (empty dictionary is fine - allows HTTPS)

✅ **Done!** These descriptions appear in iOS permission dialogs.

**Why:** iOS requires privacy descriptions for any permission the app requests.

---

## Step 5: Verify Everything Works

### Build the Project:
1. **Press ⌘B** (or Product → Build)
2. **Check for errors:**
   - ✅ If it builds successfully → You're done with Phase 1!
   - ❌ If there are errors → See troubleshooting below

### Common Issues:

#### Issue: "Cannot find type 'AuthenticationService'"
**Fix:** The `AuthenticationService` class needs to be `ObservableObject`. It already is, but make sure the file is added to the target.

#### Issue: "Missing import statements"
**Fix:** We'll add imports as we implement features. For now, the build should work with stubs.

#### Issue: Package dependency errors
**Fix:** 
- Go to File → Packages → Reset Package Caches
- Then File → Packages → Resolve Package Versions

---

## ✅ Phase 1 Complete Checklist

- [ ] Sign in with Apple capability added
- [ ] Background Modes capability added (with fetch & processing)
- [ ] AWS SDK for Swift installed (4 products selected)
- [ ] BIP39 library installed
- [ ] Info.plist privacy descriptions added (4 keys)
- [ ] Project builds successfully (⌘B)

---

## 🎯 What's Next?

Once Phase 1 is complete, we'll move to **Phase 2: Stage 1 Foundation**:
1. Implement Apple Sign In flow
2. Implement Cognito token exchange
3. Implement encryption service
4. Implement BIP39 recovery phrases
5. Set up local file storage

---

**Need help?** Let me know if you hit any issues during setup!

