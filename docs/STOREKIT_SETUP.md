# StoreKit Setup Guide

## What is StoreKit?

**StoreKit** is Apple's framework for handling in-app purchases and subscriptions. It's required for any app that wants to sell subscriptions or one-time purchases through the App Store.

### Why We Need It

- **Handles Payments**: Apple processes all payments securely
- **Subscription Management**: Tracks subscription status, renewals, cancellations
- **Receipt Validation**: Verifies purchases are legitimate
- **Restore Purchases**: Allows users to restore subscriptions on new devices
- **Family Sharing**: Automatically supports family sharing for eligible subscriptions

## Implementation Status

✅ **StoreKit Service Created**: `Just Vault/Services/Subscription/StoreKitService.swift`
- Loads products from App Store
- Handles purchases
- Tracks subscription status
- Restores purchases

## Required Setup in App Store Connect

### Step 1: Create Subscription Products

You need to create **4 subscription products** in App Store Connect:

1. **Pro Monthly**
   - Product ID: `com.juvantagecloud.justvault.pro.monthly`
   - Type: Auto-Renewable Subscription
   - Price: $6.99/month
   - Subscription Group: "Just Vault Pro"

2. **Pro Yearly**
   - Product ID: `com.juvantagecloud.justvault.pro.yearly`
   - Type: Auto-Renewable Subscription
   - Price: $59.99/year
   - Subscription Group: "Just Vault Pro"

3. **Pro+ Monthly**
   - Product ID: `com.juvantagecloud.justvault.proplus.monthly`
   - Type: Auto-Renewable Subscription
   - Price: $9.99/month
   - Subscription Group: "Just Vault Pro"

4. **Pro+ Yearly**
   - Product ID: `com.juvantagecloud.justvault.proplus.yearly`
   - Type: Auto-Renewable Subscription
   - Price: $99.99/year
   - Subscription Group: "Just Vault Pro"

### Step 2: Configure Subscription Group

1. Go to App Store Connect → Your App → Subscriptions
2. Create a subscription group called "Just Vault Pro"
3. Add all 4 products to this group
4. Set Pro+ as the higher tier (users can upgrade/downgrade)

### Step 3: Set Up Subscription Levels

- **Free**: No subscription (default)
- **Pro**: 10GB storage, 20 spaces
- **Pro+**: 50GB storage, 20 spaces

### Step 4: Configure Subscription Details

For each product, you need to provide:
- **Display Name**: "Just Vault Pro" or "Just Vault Pro+"
- **Description**: What the subscription includes
- **Review Information**: Screenshots and description for App Review
- **Localizations**: (Optional) Translations for different countries

## Testing

### Sandbox Testing

1. Create sandbox test accounts in App Store Connect
2. Sign out of your Apple ID on the test device
3. When prompted during purchase, use sandbox account
4. Test all subscription flows:
   - Purchase Pro monthly
   - Purchase Pro yearly
   - Purchase Pro+ monthly
   - Purchase Pro+ yearly
   - Restore purchases
   - Cancel subscription
   - Subscription renewal

### Testing Checklist

- [ ] Products load correctly
- [ ] Purchase flow works
- [ ] Subscription status updates in app
- [ ] Restore purchases works
- [ ] Upgrade/downgrade works
- [ ] Subscription expiration handled
- [ ] Free tier users can't access Pro features

## Integration Points

### 1. PaywallView
- Shows 3 plans vertically (Free, Pro, Pro+)
- Uses StoreKitService to load products and prices
- Handles purchase flow

### 2. User Model
- `SubscriptionTier` enum: `.free`, `.pro`, `.proPlus`
- `hasCloudBackup` property: Returns `true` for Pro/Pro+
- `cloudStorageMB` property: Returns storage quota based on tier

### 3. AWS Services
- DynamoDBService and S3Service check `hasCloudBackup` before initializing
- Free users never initialize AWS clients
- Pro/Pro+ users can use cloud backup

### 4. Settings
- Shows current subscription tier
- "Upgrade to Pro" button opens PaywallView
- "Manage Subscription" opens App Store subscription management

## Important Notes

1. **Product IDs Must Match**: The product IDs in App Store Connect must exactly match the ones in `AppConfig.swift`

2. **Subscription Group**: All products must be in the same subscription group to allow upgrades/downgrades

3. **Testing**: You can only test subscriptions in sandbox mode. Real purchases require the app to be in TestFlight or App Store.

4. **Receipt Validation**: StoreKit 2 handles receipt validation automatically. No server-side validation needed for basic use.

5. **Free Tier**: Free users should never be charged. The app should work fully offline for free users.

## Next Steps

1. ✅ StoreKit service implemented
2. ⏳ Create products in App Store Connect
3. ⏳ Test in sandbox
4. ⏳ Update user model when subscription changes
5. ⏳ Handle subscription expiration
6. ⏳ Add analytics for subscription events

