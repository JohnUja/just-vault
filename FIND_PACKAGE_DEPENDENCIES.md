# 📦 How to Find Package Dependencies in Xcode

## Quick Steps:

1. **In the Project Navigator (left sidebar):**
   - Click on the **blue "Just Vault" project icon** at the very top
   - This is the PROJECT, not the target (not the one with the app icon)

2. **In the main editor area (middle pane):**
   - Look at the **tabs at the top** of the editor
   - You should see tabs like: "General", "Signing & Capabilities", "Resource Tags", "Info", "Build Settings", etc.
   - **Click on "Package Dependencies"** tab

3. **If you don't see "Package Dependencies" tab:**
   - Make sure you clicked the **blue project icon** (not the target)
   - The target shows "Signing & Capabilities"
   - The project shows "Package Dependencies"

---

## Visual Guide:

```
Project Navigator (Left):
├── 📘 Just Vault (PROJECT) ← Click THIS (blue icon)
│   ├── Just Vault (target) ← NOT this one
│   ├── Just VaultTests
│   └── Just VaultUITests

Editor Area (Middle):
When PROJECT is selected:
├── General
├── Signing & Capabilities
├── Resource Tags
├── Info
├── Build Settings
├── Build Phases
├── Build Rules
└── 📦 Package Dependencies ← THIS TAB
```

---

## Alternative Method:

If you still can't find it:

1. **File → Add Package Dependencies...** (from menu bar)
2. This will open the package search dialog directly

---

## Once You're There:

1. You'll see a list of packages (probably empty)
2. Click the **"+" button** (bottom left or top right)
3. Paste the package URL
4. Click "Add Package"

---

**Need help?** Let me know if you still can't find it!

