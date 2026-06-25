# M3 — Production Authentication

## Goal

Build production-ready authentication for Shotup Cloud using JWT access tokens, refresh token rotation, and Sign in with Apple verification.

## Completed

* Refresh token database model
* Refresh token migration
* SHA-256 refresh token hashing
* Refresh token rotation
* `/api/v1/auth/refresh` endpoint
* Apple Sign In request DTO
* Apple identity JWT payload
* Apple public JWKS fetching
* Apple identity token header parsing
* Apple signature verification using JWTKit JWKS
* Apple issuer validation
* Apple audience validation using `APPLE_BUNDLE_ID`
* `/api/v1/auth/apple` endpoint skeleton connected to production auth flow

## Authentication Flow

```text
Shotup iOS
    ↓
Sign in with Apple
    ↓
Apple identityToken
    ↓
POST /api/v1/auth/apple
    ↓
Shotup Cloud verifies Apple JWT
    ↓
Find or create User
    ↓
Issue accessToken + refreshToken
```

## Refresh Token Rotation

Refresh tokens are not stored directly. The backend stores only a SHA-256 hash.

On refresh:

```text
Refresh Token A
    ↓
Validate hash
    ↓
Revoke Token A
    ↓
Issue Access Token B
    ↓
Issue Refresh Token B
```

Reusing an old refresh token returns:

```json
{
  "error": true,
  "reason": "Invalid refresh token"
}
```

## Security Notes

* Access tokens are short-lived.
* Refresh tokens are rotated.
* Refresh tokens are revocable.
* Apple identity tokens are verified using Apple's public keys.
* Apple issuer must equal `https://appleid.apple.com`.
* Apple audience must match `APPLE_BUNDLE_ID`.

## Out of Scope

* Removing `dev-login`
* Real iOS Sign in with Apple integration
* Device management UI
* Sync engine
* Media upload

## Status

Completed foundation. Ready for iOS integration testing.
