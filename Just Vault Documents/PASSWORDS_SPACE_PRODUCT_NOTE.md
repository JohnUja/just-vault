# Passwords space — product note (cofounder question)

## The point raised

If we have a "Passwords" space (or similar), right now it would just be **another place to upload files**. But people don’t keep passwords as documents. So:

- Should the interface be **different** for passwords — e.g. more like a password manager: rows/columns, text fields for **service name, username, password, notes** — instead of “upload a file”?
- And is it **smart to offer a dedicated Passwords space at all**?

---

## Short answers

### 1. Should the interface be file-upload vs rows/columns (text fields)?

**If we support “passwords” as a first-class thing, then yes — the interface should be credential-style (rows/columns, fields), not “upload a file.”**

- Almost nobody stores passwords as documents.
- A space that only allows “upload a file” for passwords doesn’t match how people think about or use passwords.
- So either we **don’t** treat passwords as special (no dedicated Passwords space / no special UI), or we **do** and give a proper credential-style UI (service, username, password, notes, etc.).

### 2. Is it smart to have a dedicated Passwords space/feature?

**It’s a product choice with real tradeoffs.**

**Reasons to be cautious:**

- **Different product.** Password managers (1Password, Bitwarden, iCloud Keychain, etc.) are built for: secure storage of individual credentials, autofill, generation, sync, and often 2FA. That’s a different data model (items with fields, not “files”) and different UX.
- **Scope and expectations.** If we add a “Passwords” space with a real credential UI, users will expect: secure fields, maybe autofill, maybe generation. We’d be stepping into password-manager territory and the bar is high (security, UX, support).
- **Liability and support.** Handling passwords wrong has serious consequences. Staying “documents + photos” keeps the promise simpler and easier to explain.

**Reasons it could make sense (later):**

- **One app for “sensitive stuff.”** Some users want IDs, insurance, tax docs, **and** a few important passwords (e.g. recovery codes, rarely used logins) in one place. A **simple** credential list (no autofill, no generation) could fit that.
- **Differentiation.** If we do it well and clearly (e.g. “store a few important logins, not a full password manager”), it could be a plus.

**Recommendation for now:**

- **Don’t** ship a default or highlighted “Passwords” space that’s just “upload files here” — that’s misleading (people don’t store passwords as files).
- **Either:**
  - **A)** Don’t offer a Passwords space at all; keep Just Vault clearly “documents and photos.” Users can name a space “Passwords” and put whatever files they want (exports, screenshots) with no special UI or promise.  
  - **B)** Later, if we want to support passwords properly, add a **dedicated passwords experience**: credential-style UI (rows/columns, fields), secure storage model, and clear positioning (“a few important logins, not a full password manager”). Not as “a space where you upload files.”

---

## Summary for the cofounder

- **He’s right:** a “Passwords” space that only allows file upload doesn’t match how people use passwords; if we do passwords, the interface should be **credential-style (rows/columns, text fields)**, not documents.
- **Strategy:** Either we don’t position a “Passwords” space at all (keep it file-based and generic), or we commit to a proper, focused password/credential feature with the right UI and data model. The worst option is a dedicated “Passwords” space that’s just “upload a file.”
