# 📦 How to Add BIP39 Package

## Step-by-Step Instructions:

### Step 1: Open Package Dependencies
1. **In Xcode Project Navigator (left sidebar):**
   - Click the **blue "Just Vault" project icon** (at the very top, not the target)
   - Click the **"Package Dependencies" tab** (at the top of the editor area)

### Step 2: Add BIP39 Package
1. **Click the "+" button** (bottom left of Package Dependencies section)
2. **In the search/URL field, paste:**
   ```
   https://github.com/keefertaylor/Bip39.swift
   ```
3. **Click "Add Package"** (or press Enter)
4. **Wait for it to resolve** (may take 10-30 seconds)

### Step 3: Select Product
1. **When "Choose Package Products" dialog appears:**
   - You'll see a list of products
   - **Select:**
     - ✅ **Bip39** (check the box or select it)
   - **Make sure "Add to Target: Just Vault" is selected**
2. **Click "Add Package"**

### Step 4: Verify
1. **Check Package Dependencies list:**
   - You should see `Bip39` (or similar) in the list
2. **Check Build Phases:**
   - Select "Just Vault" target
   - Go to "Build Phases" tab
   - Expand "Link Binary With Libraries"
   - You should see `Bip39.framework` (or similar)

---

## ✅ That's It!

Once BIP39 is added, you're ready to:
1. Build the project (⌘B)
2. Start testing/implementing features

---

## 🎯 Quick Checklist:

- [ ] Click blue project icon
- [ ] Go to "Package Dependencies" tab
- [ ] Click "+" button
- [ ] Paste: `https://github.com/keefertaylor/Bip39.swift`
- [ ] Click "Add Package"
- [ ] Select "Bip39" product
- [ ] Click "Add Package"
- [ ] Verify it appears in Package Dependencies list

---

**Let me know when you've added it or if you hit any issues!** 🚀

