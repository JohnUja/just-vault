# 🔐 Just Vault

A local-first, encrypted personal document vault for iOS. Built with enterprise-grade security, designed for simplicity, and architected for scale.

## Overview

Just Vault is a secure document management app that provides:

- ✅ **Zero-knowledge encryption** - We never see your data
- ✅ **Offline-first** - Works without internet
- ✅ **Secure cloud backup** - For device loss recovery
- ✅ **Local-first architecture** - Instant access, no loading
- ✅ **Enterprise-grade security** - AES-256-GCM, Secure Enclave

## Architecture

### Three-Layer Model

```
Layer 1: Local Encrypted Vault (Primary)
  → Always available, works offline, instant access

Layer 2: Encrypted Cloud Mirror (S3)
  → Insurance against device loss, zero plaintext

Layer 3: Metadata Sync (DynamoDB)
  → File index, spaces, sync status — no content
```

### Tech Stack

- **iOS:** SwiftUI, CryptoKit, StoreKit 2
- **AWS:** Cognito, S3, DynamoDB, IAM, CloudWatch
- **Security:** AES-256-GCM, Secure Enclave, BIP39 recovery phrases

## Documentation

Complete documentation suite in `/docs`:

- **ARCHITECTURE.md** - System architecture, flows, AWS setup
- **IMPLEMENTATION_PLAN.md** - 4-stage development roadmap
- **AWS_CLI_SETUP.md** - Complete AWS infrastructure setup
- **AWS_RESOURCES.md** - Cost analysis and optimization
- **UI_UX_DESIGN.md** - All 16 screens with diagrams
- **APP_STORE_LAUNCH.md** - Complete launch checklist
- **OBSERVABILITY_PLAN.md** - Monitoring and logging
- **TRACKING_ANALYTICS.md** - Analytics strategy
- **BUILD_REPORT.md** - Journey and learnings
- **NEXT_STEPS.md** - Roadmap to production

## Quick Start

### Prerequisites

- Xcode 16+
- iOS 16.0+
- AWS Account
- Apple Developer Account

### Setup

1. **AWS Infrastructure:**
   ```bash
   # Follow docs/AWS_CLI_SETUP.md
   aws configure
   # Run setup script
   ```

2. **Xcode Project:**
   - Open `Just Vault.xcodeproj`
   - Configure bundle ID: `com.justvault.app`
   - Add Sign in with Apple capability
   - Install dependencies

3. **Development:**
   - Follow `docs/IMPLEMENTATION_PLAN.md`
   - Reference `docs/UI_UX_DESIGN.md` for screens

## Features

### V1 Features

- ✅ Apple Sign In
- ✅ Local encryption (AES-256-GCM)
- ✅ Cloud sync (S3 + DynamoDB)
- ✅ Recovery phrase (BIP39)
- ✅ Subscriptions (StoreKit 2)
- ✅ Spaces organization
- ✅ File import/export

### Post-V1

- 🔄 OCR search
- 🔄 Multi-device sync
- 🔄 iPad optimization
- 🔄 Higher storage tiers

## Cost Analysis

**Per 10GB Pro User:**
- S3 Storage: $0.23/month
- DynamoDB: $0.0003/month
- Cognito: $0 (first 50K users free)
- **Total: ~$0.23/user/month**

**Margins:** 94%+ after Apple's 30% cut

## Security

- **Encryption:** AES-256-GCM via CryptoKit
- **Key Storage:** Secure Enclave (hardware-isolated)
- **Recovery:** BIP39 recovery phrases
- **Zero-Knowledge:** We never see user data
- **IAM Isolation:** Per-user data isolation

## Development Timeline

- **Planning:** 1 day (documentation)
- **Development:** 3 days (MVP)
- **Testing:** 1-2 days
- **Total:** ~1 week to production

## License

Private project - All rights reserved

## Contact

For questions about architecture, implementation, or collaboration.

---

**Built with Swift, AWS, and a focus on user privacy. Zero-knowledge, local-first, production-ready.**

