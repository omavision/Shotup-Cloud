# Authentication Architecture

> Production authentication architecture for Shotup Cloud.

---

# Overview

Shotup Cloud uses passwordless authentication based on **Sign in with Apple**, short-lived JWT access tokens, and rotating refresh tokens.

The authentication system is designed to be:

- Secure
- Stateless
- Scalable
- Native to Apple platforms
- Suitable for offline-first workflows

The backend never stores user passwords.

Identity is delegated to Apple.

---

# Authentication Flow

```
                 Sign in with Apple

                ┌──────────────────┐
                │   Shotup iPhone  │
                └─────────┬────────┘
                          │
          ASAuthorizationAppleIDCredential
                          │
                    identityToken
                          │
                          ▼
                ┌──────────────────┐
                │  Shotup Cloud    │
                └─────────┬────────┘
                          │
                  Verify Apple JWT
                          │
                          ▼
                 Find or Create User
                          │
                          ▼
          JWT Access Token + Refresh Token
                          │
                          ▼
                   Protected API Calls
```

---

# Components

The authentication system consists of:

- Sign in with Apple
- Apple Identity Token
- Apple JWKS Verification
- JWT Access Token
- Refresh Token
- JWT Middleware
- Protected Routes

---

# Sign in with Apple

Shotup Cloud uses Apple as the identity provider.

Advantages

- No password storage
- Trusted identity
- Native iOS experience
- Reduced attack surface

The client authenticates with Apple.

The backend authenticates with Apple **only by verifying the signed identity token**.

---

# Apple Identity Token

Apple returns a signed JWT containing:

- Apple User Identifier
- Email (first authorization only)
- Issuer
- Audience
- Expiration

The backend never trusts client-provided identifiers.

Everything is extracted from the verified token.

---

# Apple JWKS Verification

The backend downloads Apple's public keys.

```
https://appleid.apple.com/auth/keys
```

Verification process

1. Decode JWT header
2. Read `kid`
3. Download JWKS
4. Select matching key
5. Verify signature
6. Validate claims

Only then is the identity accepted.

---

# Claim Validation

The following claims are verified.

## Issuer

Must equal

```
https://appleid.apple.com
```

---

## Audience

Must equal

```
APPLE_BUNDLE_ID
```

Configured in

```
.env.development
```

Future production environments will use:

```
.env.production
```

---

## Expiration

Expired Apple identity tokens are rejected.

---

# User Creation

After successful verification

```
Apple User ID

↓

Find User

↓

Exists?

Yes → Update

No → Create
```

This guarantees a single account for every Apple identity.

---

# Access Tokens

After authentication

Shotup Cloud issues its own JWT.

Contents

- userID
- expiration
- subject

Lifetime

```
1 hour
```

Access tokens are intentionally short-lived.

---

# Refresh Tokens

Refresh tokens allow users to remain signed in without repeatedly authenticating with Apple.

Lifetime

```
30 days
```

Refresh tokens are random 256-bit values.

They are **never stored directly**.

Only a SHA-256 hash is stored in PostgreSQL.

---

# Refresh Token Rotation

Every refresh request performs rotation.

```
Refresh Token A

↓

Validate

↓

Revoke

↓

Generate Token B

↓

Return Token B
```

Reusing Token A results in

```
401 Unauthorized
```

This protects against replay attacks.

---

# Device Sessions

Every refresh token belongs to a device.

Future versions will expose

- iPhone
- iPad
- Mac

allowing users to revoke sessions individually.

---

# JWT Middleware

Protected routes use JWT middleware.

```
HTTP Request

↓

Authorization Header

↓

JWT Validation

↓

Authenticated User

↓

Controller
```

Controllers never parse JWTs directly.

---

# Authorization

Authentication answers

> Who are you?

Authorization answers

> Can you access this resource?

Ownership verification ensures users only access their own data.

Example

```
Project

↓

Owner

↓

Authenticated User

↓

Access Granted
```

---

# Security Layers

Every request passes through

```
HTTPS

↓

JWT Validation

↓

Authorization

↓

Ownership Check

↓

Business Logic
```

Security is enforced before business logic executes.

---

# Passwordless Design

Shotup Cloud intentionally avoids passwords.

Benefits

- No password reset
- No password database
- Lower maintenance
- Smaller attack surface
- Better user experience

Identity remains managed by Apple.

---

# Future Improvements

Planned

- Device management
- Session revocation UI
- Login history
- Push notification authentication
- Rate limiting
- Brute-force protection
- Audit logging

---

# Design Principles

Authentication should be

- Passwordless
- Stateless
- Secure
- Native
- Easy to maintain

Every new authentication feature must preserve these principles.

---

# Summary

Shotup Cloud authentication combines Apple's identity platform with JWT access tokens and rotating refresh tokens to provide a secure, scalable, and passwordless authentication system.

The backend remains stateless while maintaining strong security guarantees suitable for professional filmmaking workflows.