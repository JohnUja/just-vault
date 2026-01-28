# 🔑 AWS Credentials Setup Guide

## What's Happening?

You're running `aws configure` which is asking for your AWS credentials. This is **normal and required** before you can set up your AWS infrastructure.

## Step-by-Step: Getting Your AWS Credentials

### Option 1: If You Already Have AWS Account

1. **Go to AWS Console:**
   - Visit: https://console.aws.amazon.com
   - Sign in to your account

2. **Create Access Keys:**
   - Click on your username (top right)
   - Click **"Security credentials"**
   - Scroll down to **"Access keys"** section
   - Click **"Create access key"**
   - Choose **"Command Line Interface (CLI)"**
   - Click **"Next"**
   - Add description (optional): "Just Vault CLI Access"
   - Click **"Create access key"**

3. **Copy Your Credentials:**
   - **Access Key ID:** Copy this (starts with `AKIA...`)
   - **Secret Access Key:** Copy this (long string) - **You can only see this once!**
   - ⚠️ **IMPORTANT:** Save the Secret Access Key somewhere safe - you won't see it again!

4. **Continue with `aws configure`:**
   - Paste your Access Key ID when prompted
   - Paste your Secret Access Key when prompted
   - Enter region: `us-east-1` (or your preferred region)
   - Enter output format: `json`

---

### Option 2: If You DON'T Have AWS Account Yet

1. **Create AWS Account:**
   - Go to: https://aws.amazon.com
   - Click **"Create an AWS Account"**
   - Follow the signup process
   - ⚠️ **Note:** You'll need a credit card, but AWS Free Tier covers most of what we need

2. **After Account is Created:**
   - Follow **Option 1** above to create access keys

---

## What Each Field Means

When `aws configure` asks you:

1. **AWS Access Key ID:**
   - **What it is:** Your username for AWS API access
   - **Format:** Starts with `AKIA...` (20 characters)
   - **Example:** `AKIAIOSFODNN7EXAMPLE`

2. **AWS Secret Access Key:**
   - **What it is:** Your password for AWS API access
   - **Format:** Long random string (40 characters)
   - **Example:** `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
   - ⚠️ **Keep this secret!** Never share it or commit it to git

3. **Default region name:**
   - **What it is:** Which AWS data center to use
   - **Recommended:** `us-east-1` (cheapest, most services)
   - **Other options:** `us-west-2`, `eu-west-1`, etc.

4. **Default output format:**
   - **What it is:** How AWS CLI formats responses
   - **Recommended:** `json` (easiest to parse)
   - **Other options:** `text`, `table`, `yaml`

---

## Security Best Practices

✅ **DO:**
- Keep your Secret Access Key private
- Use IAM users with limited permissions (not root account)
- Rotate keys regularly
- Use different keys for different projects

❌ **DON'T:**
- Commit keys to git (they're in `.gitignore`)
- Share keys publicly
- Use root account keys for CLI
- Leave keys in code or config files

---

## After Configuration

Once you've entered all 4 values, you can:

1. **Verify it worked:**
   ```bash
   aws sts get-caller-identity
   ```
   This should show your AWS account ID and user info.

2. **Continue with AWS setup:**
   - Follow `docs/AWS_CLI_SETUP.md` to set up your infrastructure

---

## Troubleshooting

### "Invalid credentials"
- Double-check you copied the keys correctly
- Make sure there are no extra spaces
- Try creating new access keys

### "Access denied"
- Check that your IAM user has necessary permissions
- Make sure you're using the right region

### "Can't find credentials"
- Run `aws configure` again
- Check that credentials are saved in `~/.aws/credentials`

---

## Where Credentials Are Stored

After running `aws configure`, your credentials are saved in:
- **Location:** `~/.aws/credentials`
- **Format:** Plain text (so keep your computer secure!)
- **Already in .gitignore:** ✅ Yes, so they won't be committed to git

---

## Next Steps

Once `aws configure` is complete:

1. ✅ Verify: `aws sts get-caller-identity`
2. ✅ Continue with: `docs/AWS_CLI_SETUP.md`
3. ✅ Set up your infrastructure

---

**You're doing great! This is a one-time setup.** 🚀

