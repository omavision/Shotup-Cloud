# Environment Variables Reference

## Purpose

This reference documents environment variables used by Shotup Cloud, including purpose, whether each variable is required, example values, and security considerations.

## 1. Overview

Shotup Cloud configuration is environment-based. The Vapor API reads database, authentication, and Cloudflare R2 configuration from process environment variables.

No secrets should ever be committed. Values in `.env.development`, deployment settings, CI/CD secrets, or hosting platform secret stores must be treated as sensitive.

Use separate configurations for:

- Development
- Staging
- Production

Each environment should have separate database credentials, JWT secret, R2 bucket, and R2 access keys.

## 2. Database Variables

| Variable | Required | Example placeholder | Purpose | Security notes |
| --- | --- | --- | --- | --- |
| `DATABASE_HOST` | Yes | `db.example.com` | PostgreSQL hostname. Defaults to `localhost` in code if omitted, but should be explicit outside local defaults. | Do not expose internal database hosts publicly unless required by managed infrastructure. |
| `DATABASE_PORT` | Yes | `25060` | PostgreSQL port. Defaults to `5432` in code if omitted. DigitalOcean often uses a managed-service port such as `25060`. | Incorrect ports can cause connection failures that look like TLS or timeout issues. |
| `DATABASE_NAME` | Yes | `shotup_cloud_prod` | PostgreSQL database name. Defaults to `shotup_cloud_dev` in code if omitted. | Use separate databases for development, staging, and production. |
| `DATABASE_USERNAME` | Yes | `<database-username>` | PostgreSQL application username. Defaults to `shotup` in code if omitted. | Use least-privilege application users. Do not use owner/admin credentials unless required for migrations. |
| `DATABASE_PASSWORD` | Yes | `<database-password>` | PostgreSQL application password. Defaults to a development placeholder in code if omitted. | Secret. Store only in secret management. Rotate if exposed. |
| `DATABASE_SSL_MODE` | Recommended | `require` | Controls database TLS mode. `require` enables explicit CA trust root configuration. Defaults to `prefer` in code. | Use `require` for managed PostgreSQL in staging and production. |
| `DATABASE_CA_CERT` | Required when `DATABASE_SSL_MODE=require` | `Certificates/digitalocean-ca.crt` | Path to the CA certificate used to verify PostgreSQL TLS. | Keep certificate current for the database cluster. This is not a secret, but must be correct. |

## 3. Authentication Variables

| Variable | Required | Example placeholder | Purpose | Security notes |
| --- | --- | --- | --- | --- |
| `JWT_SECRET` | Yes | `<strong-random-secret>` | HMAC secret used to sign JWT access tokens. Code falls back to `development-secret` if omitted. | Secret. Production must set a strong environment-specific value. Rotating it invalidates existing access tokens. |
| `ACCESS_TOKEN_LIFETIME` | No, not currently implemented | `3600` | Future configurable access token lifetime. Current implementation hardcodes one hour in `JWTService`. | If added, keep production access tokens short-lived. |
| `REFRESH_TOKEN_LIFETIME` | No, not currently implemented | `2592000` | Future configurable refresh token lifetime. Current implementation hardcodes 30 days in `RefreshTokenService`. | If added, balance user experience with account risk. |
| `APPLE_BUNDLE_ID` | Yes for Apple Sign-In | `com.example.shotup` | Expected Apple app bundle ID used by `AppleTokenVerifier`. | Not a secret, but must match the production iOS app identity. |

Recommended production values:

- `JWT_SECRET`: at least 32 bytes of high-entropy random data.
- Access token lifetime: short, currently one hour.
- Refresh token lifetime: longer-lived but revocable, currently 30 days.
- `APPLE_BUNDLE_ID`: exact production bundle ID.

## 4. Cloudflare R2 Variables

| Variable | Required | Example placeholder | Purpose | Security notes |
| --- | --- | --- | --- | --- |
| `R2_ACCOUNT_ID` | Yes outside testing | `<cloudflare-account-id>` | Cloudflare account identifier used for R2 signing/configuration. | Treat as sensitive metadata. Do not expose unnecessarily. |
| `R2_ACCESS_KEY_ID` | Yes outside testing | `<r2-access-key-id>` | R2 access key ID used by the backend to sign requests. | Secret-adjacent. Store server-side only. Rotate if exposed. |
| `R2_SECRET_ACCESS_KEY` | Yes outside testing | `<r2-secret-access-key>` | R2 secret key used by the backend to sign presigned URLs and object checks. | Secret. Never send to iOS, never log, never commit. |
| `R2_BUCKET` | Yes outside testing | `shotup-media-dev` | Target R2 bucket. Current code accepts `shotup-media-dev` or `shotup-media-prod`. | Use separate buckets per environment. |
| `R2_ENDPOINT` | Yes outside testing | `https://<account-id>.r2.cloudflarestorage.com` | R2 S3-compatible endpoint. | Must match the Cloudflare account and region/account configuration. |

How these are used:

- `R2StorageService` uses them to create presigned upload URLs, presigned download URLs, and object existence checks.
- iOS never receives R2 credentials.
- iOS receives only short-lived presigned URLs generated by the backend.

## 5. Application Variables

| Variable | Required | Example placeholder | Purpose | Security notes |
| --- | --- | --- | --- | --- |
| `APP_ENV` | Optional, deployment-dependent | `development` | Common app environment label. Present in `.env.example`; Vapor also supports `--env`. | Not a secret. Keep consistent with deployment environment. |
| `APP_NAME` | Optional | `Shotup Cloud API` | Human-readable application name. Present in `.env.example`. | Not a secret. |
| `APP_VERSION` | Optional | `0.1.0` | Human-readable application version. Present in `.env.example`. | Not a secret. Useful for diagnostics. |
| `LOG_LEVEL` | Optional, supported by Vapor/logging environment | `debug` | Logging verbosity. Used in `docker-compose.yml` as a local/test default. | Avoid verbose logs in production if they risk exposing sensitive metadata. |
| `PORT` | Optional, implementation/deployment-dependent | `8080` | Some hosting platforms expose a port variable. Current Docker command passes `--port 8080`; code does not directly read `PORT`. | Not a secret. Confirm platform behavior before relying on it. |
| `HOST` | Optional, implementation/deployment-dependent | `0.0.0.0` | Some hosting platforms expose a host/bind variable. Current Docker command passes `--hostname 0.0.0.0`; code does not directly read `HOST`. | Not a secret. |

## 6. Development Example

Sample `.env.development` using placeholders only:

```bash
APP_ENV=development
APP_NAME="Shotup Cloud API"
APP_VERSION=0.1.0

DATABASE_HOST=db.example.com
DATABASE_PORT=25060
DATABASE_NAME=shotup_dev
DATABASE_USERNAME=<username>
DATABASE_PASSWORD=<password>
DATABASE_SSL_MODE=require
DATABASE_CA_CERT=Certificates/digitalocean-ca.crt

JWT_SECRET=<development-jwt-secret>
APPLE_BUNDLE_ID=com.example.shotup.dev

R2_ACCOUNT_ID=<cloudflare-account-id>
R2_ACCESS_KEY_ID=<r2-access-key-id>
R2_SECRET_ACCESS_KEY=<r2-secret-access-key>
R2_BUCKET=shotup-media-dev
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com

LOG_LEVEL=debug
```

Before running locally, export the file into the current shell:

```bash
set -a
source .env.development
set +a
```

## 7. Production Recommendations

- Use strong JWT secrets generated by a secure random source.
- Use separate databases for development, staging, and production.
- Use separate R2 buckets for development/staging and production.
- Rotate R2 keys after exposure, team changes, or according to security policy.
- Use least-privilege database and R2 credentials.
- Keep environment isolation strict. Development credentials should never access production data.
- Use `DATABASE_SSL_MODE=require` with a valid CA certificate for managed PostgreSQL.
- Store secrets in the deployment platform secret manager.

## 8. Common Configuration Errors

### Missing `JWT_SECRET`

Symptoms:

- Server starts with the development fallback secret.
- Tokens are invalidated unexpectedly across environments.

Resolution:

- Set `JWT_SECRET` explicitly in every non-local environment.
- Use a strong random value.

### Incorrect database port

Symptoms:

- Connection timeout.
- Connection refused.
- Server fails during startup or migrations.

Resolution:

- Confirm the managed PostgreSQL port in the provider dashboard.
- DigitalOcean managed databases may not use local default `5432`.

### Wrong CA certificate

Symptoms:

- TLS certificate verification failure.
- Database connection fails only when `DATABASE_SSL_MODE=require`.

Resolution:

- Confirm `DATABASE_CA_CERT` points to the right file.
- Re-download the CA certificate from the database provider.
- Confirm the file is present in the runtime environment.

### Expired R2 credentials

Symptoms:

- Presigned URL generation fails.
- Object existence checks fail.
- Upload confirmation returns storage-related errors.

Resolution:

- Create or rotate R2 API credentials.
- Update `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`.
- Restart the API process.

### Wrong bucket name

Symptoms:

- Startup fails with invalid R2 bucket.
- Uploads target the wrong environment.

Resolution:

- Use `shotup-media-dev` for development/staging unless a separate staging bucket is added.
- Use `shotup-media-prod` for production.
- Confirm the bucket exists in Cloudflare R2.

### Incorrect endpoint

Symptoms:

- Presigned URLs do not work.
- R2 object checks fail.
- Client PUT/GET requests fail.

Resolution:

- Confirm `R2_ENDPOINT` matches the Cloudflare account endpoint.
- Include the scheme, for example `https://...`.

### Missing `APP_ENV`

Symptoms:

- Environment-dependent behavior may be ambiguous.
- Logs and deployment diagnostics may be harder to interpret.

Resolution:

- Set `APP_ENV` consistently in deployment configuration.
- Also pass Vapor `--env` where the deployment process requires it.

## 9. Validation Checklist

Before starting the server, verify:

- [ ] Database reachable.
- [ ] TLS working.
- [ ] JWT configured.
- [ ] R2 credentials valid.
- [ ] Bucket accessible.
- [ ] Health endpoint returns success.

Useful commands:

```bash
swift run api migrate --yes
swift run api serve
curl http://localhost:8080/api/v1/health
```

## 10. Future Configuration

The following variables are future considerations and are not currently implemented unless added later:

| Future variable | Possible purpose |
| --- | --- |
| `REDIS_URL` | Queueing, cache, rate limiting, or distributed locks. |
| `S3_COMPATIBLE_STORAGE` | Alternate S3-compatible storage provider selection. |
| `PROMETHEUS_ENABLED` | Enable metrics export. |
| `METRICS_PORT` | Bind port for metrics endpoint. |
| `OTEL_ENDPOINT` | OpenTelemetry collector endpoint. |
| `MAIL_PROVIDER` | Email provider configuration. |
| `PUSH_NOTIFICATION_KEY` | Push notification credential reference. |
| `FEATURE_FLAGS` | Runtime feature flag configuration. |
