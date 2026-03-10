# App Icon and Launch Screen Setup Instructions

## ✅ What I've Done

1. **Created LaunchScreen.storyboard** - A proper storyboard file (like Just Scan) with:
   - App icon image (justvault) centered
   - "Just™" text below icon
   - "Vault" text below that
   - Purple/orange gradient background matching the app

2. **Updated Info.plist** - Added `UILaunchStoryboardName` key pointing to "LaunchScreen"

3. **App Icon Setup** - The AppIcon asset catalog is ready, you just need to add the image

## 📝 Manual Steps You Need to Do in Xcode

### Step 1: Add justvault.png to Image Asset Catalog

1. In Xcode, open `Assets.xcassets`
2. Right-click in the asset catalog → "New Image Set"
3. Name it **"justvault"** (exactly this name, no spaces)
4. Drag `justvault.png` from your Desktop into the "Universal" slot (1024x1024)
5. Make sure it's named exactly "justvault" (not "justvault1")

### Step 2: Update App Icon

1. In Xcode, select `Assets.xcassets` → `AppIcon` (or `Appicon 1` if that's what you see)
2. Drag `justvault.png` from your Desktop into the **1024x1024** slot
3. This will be used as your app icon on the home screen

### Step 3: Add LaunchScreen.storyboard to Xcode Project

1. In Xcode, right-click on the "Just Vault" folder in the navigator
2. Select "Add Files to 'Just Vault'..."
3. Navigate to and select `LaunchScreen.storyboard`
4. Make sure "Copy items if needed" is checked
5. Make sure "Just Vault" target is selected
6. Click "Add"

### Step 4: Verify Storyboard Image Reference

1. Open `LaunchScreen.storyboard` in Xcode
2. Select the ImageView in the storyboard
3. In the Attributes Inspector, set the Image to **"justvault"**
4. The image should appear in the preview

## 🎨 Launch Screen Features

The LaunchScreen.storyboard includes:
- **App Icon**: 200x200pt, centered
- **"Just™" Text**: Bold, 30pt, centered below icon
- **"Vault" Text**: Bold, 30pt, centered below "Just™"
- **Background**: Purple/orange gradient matching app theme

## ⚠️ Important Notes

- The image asset must be named **"justvault"** (exactly) for the storyboard to work
- The app icon in AppIcon asset should use the same `justvault.png` file
- After adding the storyboard to the project, the launch screen will automatically use it
- The Info.plist already references "LaunchScreen" as the launch storyboard name

## 🔍 Verification

After setup, you should see:
1. App icon on home screen uses justvault.png
2. Launch screen shows justvault image with "Just™ Vault" text
3. Background has purple/orange gradient

