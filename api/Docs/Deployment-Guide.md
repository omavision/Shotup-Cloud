# Deployment Guide

## Purpose

This guide explains how to deploy the Shotup Cloud API to a production or staging environment.

## 1. Overview

Shotup Cloud is a Vapor API backed by DigitalOcean Managed PostgreSQL and Cloudflare R2.

Core production concerns:

- Vapor API process serving `/api/v1` routes.
- DigitalOcean Managed PostgreSQL for metadata, sync events, auth sessions, and media metadata.
- Cloudflare R2 for media binaries.
- JWT authentication for protected routes.
- HTTPS/TLS for client traffic.
- TLS for PostgreSQL connections when `DATABASE_SSL_MODE=require`.
- Environment-based configuration for all secrets and deployment-specific values.

The API should be deployed as a stateless service. PostgreSQL and R2 provide persistent state.

## 2. Deployment Targets

The exact final production hosting target is TBD.

Recommended options:

### DigitalOcean App Platform

Good fit for managed app hosting with environment variables, HTTPS, logs, and integration with DigitalOcean Managed PostgreSQL.

Considerations:

- Confirm Swift/Vapor build support or deploy with Docker.
- Store secrets in App Platform environment settings.
- Ensure the DigitalOcean CA certificate is available to the app.
- Run migrations as a deployment step or one-off job.

### DigitalOcean Droplet

Good fit when more control is needed over the host, system packages, certificates, and process manager.

Considerations:

- Requires host maintenance and security patching.
- Use a service manager such as systemd.
- Configure reverse proxy TLS termination with Nginx, Caddy, or equivalent.
- Store secrets outside the repository.

### Docker-Based Deployment

The repository includes `api/Dockerfile` for building and running the Vapor service. `api/docker-compose.yml` is available for production-like local testing but is not itself a finalized production deployment plan.

Considerations:

- Build the API image from `api/Dockerfile`.
- Inject environment variables at runtime.
- Mount or bake in the PostgreSQL CA certificate securely.
- Run migrations as a separate job before serving traffic.

## 3. Required Infrastructure

Production or staging requires:

- Managed PostgreSQL database.
- Cloudflare R2 bucket.
- Production or staging domain.
- HTTPS/TLS certificate for public API traffic.
- Environment variable/secret storage.
- DigitalOcean PostgreSQL CA certificate.

Recommended bucket separation:

- Staging/development: `shotup-media-dev`
- Production: `shotup-media-prod`

## 4. Environment Variables

Use placeholders only in documentation and deployment templates. Do not commit real secrets.

```bash
APP_ENV=production
APP_NAME="Shotup Cloud API"
APP_VERSION="0.1.0"

DATABASE_HOST=<postgres-host>
DATABASE_PORT=<postgres-port>
DATABASE_NAME=<postgres-database>
DATABASE_USERNAME=<postgres-username>
DATABASE_PASSWORD=<postgres-password>
DATABASE_SSL_MODE=require
DATABASE_CA_CERT=<path-to-digitalocean-ca.crt>

JWT_SECRET=<strong-random-secret>
APPLE_BUNDLE_ID=<production-ios-bundle-id>

R2_ACCOUNT_ID=<cloudflare-account-id>
R2_ACCESS_KEY_ID=<r2-access-key-id>
R2_SECRET_ACCESS_KEY=<r2-secret-access-key>
R2_BUCKET=<shotup-media-dev-or-shotup-media-prod>
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
```

Notes:

- Use a strong unique `JWT_SECRET` per environment.
- Use `DATABASE_SSL_MODE=require` for managed PostgreSQL.
- Use `shotup-media-prod` only for production.
- Keep staging and production credentials separate.

## 5. Database Setup

Recommended setup:

1. Create a managed PostgreSQL cluster.
2. Create a database for the environment.
3. Create an application database user.
4. Grant the application user permissions for the database and schema.
5. Install or provide the DigitalOcean CA certificate to the app runtime.
6. Run Vapor migrations.

Example permission shape:

```sql
GRANT CONNECT ON DATABASE <database_name> TO <app_user>;
GRANT USAGE, CREATE ON SCHEMA public TO <app_user>;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO <app_user>;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO <app_user>;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO <app_user>;
```

Run migrations only after confirming the app user can create and modify schema objects.

## 6. Build and Run

From `api/`, build a release binary:

```bash
swift build -c release
```

Run migrations:

```bash
.build/release/api migrate --yes --env production
```

Run the server:

```bash
.build/release/api serve --env production --hostname 0.0.0.0 --port 8080
```

Docker build example:

```bash
docker build -t shotup-cloud-api:latest .
```

Docker run shape:

```bash
docker run --rm -p 8080:8080 \
  --env APP_ENV=production \
  --env DATABASE_HOST=<postgres-host> \
  --env DATABASE_PORT=<postgres-port> \
  --env DATABASE_NAME=<postgres-database> \
  --env DATABASE_USERNAME=<postgres-username> \
  --env DATABASE_PASSWORD=<postgres-password> \
  --env DATABASE_SSL_MODE=require \
  --env DATABASE_CA_CERT=<path-to-ca-cert> \
  --env JWT_SECRET=<strong-random-secret> \
  --env APPLE_BUNDLE_ID=<production-ios-bundle-id> \
  --env R2_ACCOUNT_ID=<cloudflare-account-id> \
  --env R2_ACCESS_KEY_ID=<r2-access-key-id> \
  --env R2_SECRET_ACCESS_KEY=<r2-secret-access-key> \
  --env R2_BUCKET=shotup-media-prod \
  --env R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com \
  shotup-cloud-api:latest
```

Health check:

```bash
curl https://<api-domain>/api/v1/health
```

## 7. Smoke Test

Run smoke tests after deployment.

### Health

```bash
curl https://<api-domain>/api/v1/health
```

Expected: `success: true`, `status: ok`.

### Dev Login

Use only for development or staging if enabled:

```bash
curl -X POST "https://<api-domain>/api/v1/auth/dev-login" \
  -H "Content-Type: application/json" \
  -d '{
    "appleUserID": "staging.dev.user",
    "email": "staging@example.com",
    "displayName": "Staging User"
  }'
```

Production auth should use Apple Sign-In rather than unrestricted dev login.

### Sync

```bash
curl -X POST "https://<api-domain>/api/v1/sync" \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceID": "smoke-test-device",
    "lastSyncToken": null,
    "changes": []
  }'
```

Expected: a sync response with `syncToken`, `serverTime`, `changes`, and `conflicts`.

### Media Exists

```bash
curl -X POST "https://<api-domain>/api/v1/media/exists" \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "frameID": "00000000-0000-0000-0000-000000000000"
  }'
```

Expected for an unknown frame: `exists: false`.

### Upload Flow

For a real upload smoke test:

1. Create or sync a project, scene, and shot.
2. Call `POST /api/v1/media/request-upload`.
3. PUT a JPEG to the returned presigned R2 URL.
4. Call `POST /api/v1/media/confirm-upload`.
5. Verify `media_assets.status = 'uploaded'`.

## 8. Deployment Checklist

### Before Deploy

- Confirm target environment.
- Confirm release version.
- Confirm database backup coverage.
- Confirm managed PostgreSQL is healthy.
- Confirm R2 bucket exists.
- Confirm R2 credentials are scoped for the target bucket.
- Confirm environment variables are set.
- Confirm CA certificate is available at `DATABASE_CA_CERT`.
- Confirm `JWT_SECRET` is strong and environment-specific.
- Build the release artifact.
- Run tests in CI or locally.

### During Deploy

- Deploy the app artifact or Docker image.
- Run migrations once.
- Start the API process.
- Watch startup logs.
- Confirm no secret values are printed.

### After Deploy

- Check `/api/v1/health`.
- Run auth smoke test.
- Run sync smoke test.
- Run media exists smoke test.
- Run upload smoke test in staging before production.
- Monitor logs and error rates.

## 9. Rollback Strategy

Application rollback:

- Roll back to the previous known-good app binary or container image.
- Keep environment variables unchanged unless the deploy changed them incorrectly.
- Confirm health and smoke tests after rollback.

Database migration caution:

- Avoid automatic destructive rollback of migrations.
- If a migration is backward-compatible, prefer rolling back the app only.
- If schema rollback is required, use a reviewed database plan.

Restore from backup:

- Restore only when data loss, destructive migration, or corruption requires it.
- Confirm restore point and expected data loss window.
- Verify users, projects, shots, media assets, and sync events after restore.

## 10. Security Notes

- Never commit secrets.
- Use managed secret storage in the deployment platform.
- Rotate R2 keys if exposed or suspected compromised.
- Use a strong random `JWT_SECRET`.
- Keep staging and production secrets separate.
- Production auth must replace development-only login paths for real users.
- Do not log JWTs, refresh tokens, R2 keys, database passwords, or presigned URLs.
- Use HTTPS for all public traffic.

## 11. Monitoring After Deploy

Monitor:

- API logs.
- Database connection errors.
- Database latency.
- R2 errors.
- Media upload failure rate.
- Media confirm failure rate.
- Download failure rate.
- Authentication failures.
- 4xx and 5xx response rates.
- Health endpoint status.

Useful log fields:

- `traceID`
- `userID`
- `projectID`
- `sceneID`
- `frameID`
- `objectKey`
- `requestDurationMs`
- `putDurationMs`
- `confirmDurationMs`
- `totalDurationMs`

## 12. Known Gaps

- Final production hosting target is TBD.
- CI/CD is not finalized.
- Production auth hardening is pending.
- Monitoring stack is pending.
- API rate limiting is not implemented yet.
- Admin operations dashboard is not implemented yet.
