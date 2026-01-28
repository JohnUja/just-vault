# ⚡ SSO Quick Start - Just Vault

## Your Current Setup ✅

- **Profile:** `just-vault`
- **Account:** `491085415425`
- **Region:** `us-east-1`
- **Status:** ✅ SSO configured and working

---

## Quick Reference

### Login (When Needed)

```bash
aws sso login --profile just-vault
```

**When:** First time, or when credentials expire (every 8-12 hours)

### All Commands Need Profile

```bash
# ✅ Always include --profile just-vault
aws s3 ls --profile just-vault
aws dynamodb list-tables --profile just-vault
aws sts get-caller-identity --profile just-vault
```

### Set Default Profile (Optional)

```bash
# Set once, then you can omit --profile
export AWS_PROFILE=just-vault

# Add to ~/.zshrc to make permanent
echo 'export AWS_PROFILE=just-vault' >> ~/.zshrc
```

---

## Run Setup Script

```bash
cd "/Users/johnuja/Desktop/Just Vault"

# Make sure you're logged in
aws sso login --profile just-vault

# Run setup script
./scripts/setup-aws-sso.sh
```

---

## Key Points

1. **SSO is better** - More secure than access keys
2. **Use `--profile just-vault`** on all commands
3. **Login when expired** - `aws sso login --profile just-vault`
4. **For iOS app** - Still uses Cognito Identity Pool (different from your SSO)

---

## Full Documentation

- **SSO Setup:** `docs/AWS_SSO_SETUP.md` (complete guide)
- **CLI Setup:** `docs/AWS_CLI_SETUP.md` (add `--profile just-vault` to commands)

---

**You're ready to proceed!** 🚀

