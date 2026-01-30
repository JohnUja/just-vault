# ✅ Xcode Setup Checklist (5 minutes)

**Bundle ID:** `com.juvantagecloud.justvault` ✅ (Already set)

---

## Step 1: Add Capabilities (2 minutes)

### In Xcode → Signing & Capabilities tab:

1. **Click "+ Capability"**
2. **Add "Sign in with Apple"**
   - Search for it
   - Double-click to add
   - ✅ Should appear in capabilities list

3. **Click "+ Capability" again**
4. **Add "Background Modes"**
   - Search for it
   - Double-click to add
   - Check these boxes:
     - ☑️ Background fetch
     - ☑️ Background processing

---

## Step 2: Install Swift Packages (2 minutes)

### In Xcode → Project Navigator → Select "Just Vault" (blue icon) → Package Dependencies tab:

1. **Click "+" button** (bottom left)

2. **Add AWS SDK:**
   - URL: `https://github.com/awslabs/aws-sdk-swift`
   - Version: Up to Next Major: `1.0.0`
   - Click "Add Package"
   - Select these products:
     - ☑️ `AWSCognitoIdentity`
     - ☑️ `AWSCognitoIdentityProvider`
     - ☑️ `AWSS3`
     - ☑️ `AWSDynamoDB`
   - Click "Add Package"

3. **Click "+" again**

4. **Add BIP39:**
   - URL: `https://github.com/keefertaylor/Bip39.swift`
   - Version: Up to Next Major: `1.0.0`
   - Click "Add Package"
   - Select product:
     - ☑️ `Bip39`
   - Click "Add Package"

---

## Step 3: Configure Info.plist (1 minute)

### In Xcode → Select "Just Vault" target → "Info" tab:

1. **Click "+" to add new keys:**

   **Key 1:**
   - Key: `NSPhotoLibraryUsageDescription`
   - Type: String
   - Value: `"Just Vault needs access to your photos to securely store them in your vault."`

   **Key 2:**
   - Key: `NSCameraUsageDescription`
   - Type: String
   - Value: `"Just Vault needs camera access to capture photos and securely store them in your vault."`

   **Key 3:**
   - Key: `NSDocumentsFolderUsageDescription`
   - Type: String
   - Value: `"Just Vault needs access to your files to securely store them in your vault."`

---

## Step 4: Verify Build

1. **Press ⌘B** to build
2. **Should build successfully** ✅

---

## ✅ Done!

All code is already implemented. Once you complete these 3 steps, the app will be ready to run!

