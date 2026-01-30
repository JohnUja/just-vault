# 📦 AWS SDK Packages - What You Actually Need

## ✅ **KEEP THESE (Required for V1):**

### 1. **AWSCognitoIdentity** ✅
- **Why:** Identity Pool - exchanges Cognito tokens for AWS credentials
- **Used for:** Getting temporary AWS credentials for S3/DynamoDB access
- **Status:** ✅ Keep

### 2. **AWSCognitoIdentityProvider** ✅
- **Why:** User Pool - validates Apple Sign In tokens
- **Used for:** Authentication flow (Apple → Cognito)
- **Status:** ✅ Keep

### 3. **AWSS3** ✅
- **Why:** Encrypted file storage
- **Used for:** Uploading/downloading encrypted blobs
- **Status:** ✅ Keep

### 4. **AWSDynamoDB** ✅
- **Why:** Metadata storage (user profiles, spaces, file records)
- **Used for:** Single-table design for user data
- **Status:** ✅ Keep

---

## ❌ **REMOVE THESE (Not Needed):**

### 1. **AWSCognitoSync** ❌
- **Why NOT:** This is for syncing user attributes across devices
- **What we use instead:** DynamoDB for all metadata sync
- **Action:** Remove it - you don't need it

### 2. **AWSSSO** ❌
- **Why NOT:** This is AWS Single Sign-On (IAM Identity Center)
- **What it's for:** Enterprise SSO for AWS accounts
- **Not relevant:** You're using Cognito for user auth, not AWS SSO
- **Action:** Don't add it - not needed

---

## 🔮 **FUTURE (Maybe Later):**

### 1. **AWSCloudWatchLogs** (Optional)
- **Why:** Centralized logging
- **When:** If you want to send app logs to CloudWatch
- **For now:** Not needed - can add later if needed

### 2. **AWSSTS** (Not needed)
- **Why NOT:** Cognito Identity Pool already handles temporary credentials
- **Action:** Don't add

---

## 📋 **RECOMMENDED PACKAGE LIST:**

### For V1 (Now):
1. ✅ **AWSCognitoIdentity**
2. ✅ **AWSCognitoIdentityProvider**
3. ✅ **AWSS3**
4. ✅ **AWSDynamoDB**

### Total: **4 packages** (that's all you need!)

---

## 🎯 **What to Do:**

1. **In the "Choose Package Products" dialog:**
   - ✅ Keep: AWSCognitoIdentity, AWSCognitoIdentityProvider, AWSS3, AWSDynamoDB
   - ❌ Remove: AWSCognitoSync (change dropdown to "None")
   - ❌ Don't add: AWSSSO

2. **Click "Add Package"**

3. **You're done!** 4 packages is perfect for V1.

---

## 💡 **Why This Setup:**

- **CognitoIdentity + CognitoIdentityProvider:** Authentication flow
- **S3:** Encrypted file storage
- **DynamoDB:** Metadata (spaces, files, user profiles)

**That's everything you need!** Keep it simple for V1. You can always add more packages later if needed.

---

## 🚫 **What NOT to Add:**

- ❌ CognitoSync (we use DynamoDB)
- ❌ SSO (not relevant for app users)
- ❌ CloudWatch (optional, add later if needed)
- ❌ STS (Cognito handles this)
- ❌ Any other AWS services (not needed for V1)

**Keep it minimal!** 4 packages = clean, fast, simple. ✅

