# ➕ How to Add AWS SDK Products to Your Target

## The Problem:
Your "Link Binary With Libraries" is empty, which means the AWS SDK products haven't been linked to your target yet.

## Solution: Add the Products

### Step 1: Add Products to "Link Binary With Libraries"

1. **In "Build Phases" tab** (you're already here!)
2. **Find "Link Binary With Libraries"** section
3. **Click the "+" button** (top left of that section)
4. **A dialog will appear** showing available frameworks

### Step 2: Select the 4 Products You Need

In the dialog, search for and add these 4:

1. **AWSCognitoIdentity**
   - Search for "CognitoIdentity"
   - Select it
   - Click "Add"

2. **AWSCognitoIdentityProvider**
   - Search for "CognitoIdentityProvider"
   - Select it
   - Click "Add"

3. **AWSS3**
   - Search for "S3"
   - Select it
   - Click "Add"

4. **AWSDynamoDB**
   - Search for "DynamoDB"
   - Select it
   - Click "Add"

### Step 3: Verify

After adding all 4, your "Link Binary With Libraries" should show:
- ✅ AWSCognitoIdentity.framework
- ✅ AWSCognitoIdentityProvider.framework
- ✅ AWSS3.framework
- ✅ AWSDynamoDB.framework

---

## Alternative: If Products Don't Appear in Dialog

If the products don't show up in the "+" dialog, it means they weren't selected when you added the package.

### Fix: Re-add the Package with Products Selected

1. **Remove the package:**
   - Select blue "Just Vault" project icon
   - Go to "Package Dependencies" tab
   - Select `aws-sdk-swift`
   - Click "-" button
   - Confirm

2. **Re-add with products:**
   - Click "+" button
   - Paste: `https://github.com/awslabs/aws-sdk-swift`
   - Click "Add Package"
   - **When "Choose Package Products" dialog appears:**
     - Select these 4:
       - ✅ AWSCognitoIdentity
       - ✅ AWSCognitoIdentityProvider
       - ✅ AWSS3
       - ✅ AWSDynamoDB
     - Make sure "Add to Target: Just Vault" is selected
   - Click "Add Package"

3. **Now they should appear in "Link Binary With Libraries"**

---

## ✅ Quick Check:

After adding, "Link Binary With Libraries" should show 4 items, not 0.

If it's still empty, the products weren't selected when adding the package. Use the "Alternative" method above.

