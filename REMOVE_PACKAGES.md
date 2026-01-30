# 🗑️ How to Remove AWS Packages in Xcode

## Quick Steps:

### Option 1: Remove Individual Package Products (Recommended)

1. **Select your target:**
   - In Project Navigator, click the **"Just Vault" target** (app icon, not the blue project icon)
   - Go to **"Build Phases"** tab (at the top)

2. **Find "Link Binary With Libraries":**
   - Expand this section
   - Find any unwanted packages (like `AWSCognitoSync`)
   - Select them and click the **"-" button** to remove

3. **Clean up:**
   - Press **⌘B** to build (this will show if anything is broken)
   - If there are import errors, remove those imports from your code

---

### Option 2: Remove Entire Package (If you want to start fresh)

1. **Select the project:**
   - In Project Navigator, click the **blue "Just Vault" project icon** (at the very top)
   - Go to **"Package Dependencies"** tab

2. **Remove the package:**
   - Find `aws-sdk-swift` in the list
   - Select it
   - Click the **"-" button** (bottom left)
   - Confirm removal

3. **Re-add with correct products:**
   - Click **"+" button**
   - Paste: `https://github.com/awslabs/aws-sdk-swift`
   - Click "Add Package"
   - **Only select these 4:**
     - ✅ AWSCognitoIdentity
     - ✅ AWSCognitoIdentityProvider
     - ✅ AWSS3
     - ✅ AWSDynamoDB
   - Click "Add Package"

---

## 🎯 Recommended Approach:

**Use Option 2** - Start fresh and only add the 4 packages you need.

This is cleaner and ensures you don't have any leftover dependencies.

---

## After Removing:

1. **Clean build folder:**
   - Product → Clean Build Folder (or ⌘⇧K)

2. **Build again:**
   - Press ⌘B

3. **Check for errors:**
   - If you see import errors, remove those import statements from your code

---

## ✅ What You Should Have:

**Package Dependencies:**
- `aws-sdk-swift` (with only 4 products selected)

**Products Selected:**
- ✅ AWSCognitoIdentity
- ✅ AWSCognitoIdentityProvider
- ✅ AWSS3
- ✅ AWSDynamoDB

**That's it!** 4 packages, clean and simple. ✅

