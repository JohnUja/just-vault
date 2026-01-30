# 📦 Understanding Package Dependencies in Xcode

## 🤔 What You're Seeing:

Those packages in the list (`async-http-client`, `aws-crt-swift`, `grpc-swift`, etc.) are **NOT** packages you added directly.

They are **automatic dependencies** (also called "transitive dependencies") that Xcode added automatically when you added `aws-sdk-swift`.

## ✅ This is NORMAL!

When you add `aws-sdk-swift`, it depends on other packages:
- `aws-crt-swift` (AWS C runtime)
- `swift-nio` (networking)
- `swift-crypto` (cryptography)
- etc.

Xcode automatically downloads and includes these. **You don't need to manage them.**

---

## 🎯 What You CAN Control:

You can only control which **PRODUCTS** from `aws-sdk-swift` you link to your target:

1. **Select your target:**
   - Click "Just Vault" target (app icon)
   - Go to "Build Phases" tab
   - Expand "Link Binary With Libraries"

2. **See what's linked:**
   - You should see products like:
     - `AWSCognitoIdentity.framework`
     - `AWSCognitoIdentityProvider.framework`
     - `AWSS3.framework`
     - `AWSDynamoDB.framework`
     - Maybe `AWSCognitoSync.framework` (if you added it)

3. **Remove unwanted products:**
   - Select `AWSCognitoSync.framework` (if it's there)
   - Click "-" to remove it
   - Keep only the 4 you need

---

## 🗑️ If You Want to Start Completely Fresh:

1. **Remove the package:**
   - Select blue "Just Vault" project icon
   - Go to "Package Dependencies" tab
   - Select `aws-sdk-swift`
   - Click "-" button
   - Confirm

2. **Re-add it:**
   - Click "+" button
   - Paste: `https://github.com/awslabs/aws-sdk-swift`
   - Click "Add Package"
   - **Only select these 4 products:**
     - ✅ AWSCognitoIdentity
     - ✅ AWSCognitoIdentityProvider
     - ✅ AWSS3
     - ✅ AWSDynamoDB
   - Click "Add Package"

3. **The transitive dependencies will come back automatically** - that's normal!

---

## 💡 Bottom Line:

- **Those packages in the list?** Leave them alone - they're required by AWS SDK
- **What matters?** Only which PRODUCTS you link to your target
- **Want to clean up?** Just remove unwanted products from "Build Phases" → "Link Binary With Libraries"

---

## ✅ Quick Check:

1. Select "Just Vault" target
2. Go to "Build Phases" → "Link Binary With Libraries"
3. You should only see:
   - ✅ AWSCognitoIdentity
   - ✅ AWSCognitoIdentityProvider
   - ✅ AWSS3
   - ✅ AWSDynamoDB

If you see `AWSCognitoSync`, remove it. That's all you need to do!

