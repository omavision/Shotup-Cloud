# Local Development Setup

## Purpose

This guide explains how to run the Shotup Cloud API locally for development.

## 1. Prerequisites

Required tools and services:

- macOS.
- Xcode or a compatible Swift toolchain.
- Homebrew.
- PostgreSQL client tools, especially `psql`.
- Access to a DigitalOcean Managed PostgreSQL database.
- Cloudflare R2 credentials for a Shotup media bucket.

Recommended installs:

```bash
brew install postgresql@16
```

Confirm Swift is available:

```bash
swift --version
```

Confirm `psql` is available:

```bash
psql --version
```

## 2. Clone and Enter Project

Clone the repository:

```bash
git clone https://github.com/<your-org>/Shotup-Cloud.git
```

Enter the API package:

```bash
cd Shotup-Cloud/api
```

Resolve Swift dependencies:

```bash
swift package resolve
```

## 3. Configure `.env.development`

Create `api/.env.development` from the example file or create it manually:

```bash
cp .env.example .env.development
```

Set the following values with development credentials. Do not commit real secrets.

```bash
DATABASE_HOST=<digitalocean-postgres-host>
DATABASE_PORT=25060
DATABASE_NAME=<database-name>
DATABASE_USERNAME=<database-username>
DATABASE_PASSWORD=<database-password>
DATABASE_SSL_MODE=require
DATABASE_CA_CERT=Certificates/digitalocean-ca.crt

JWT_SECRET=<local-development-jwt-secret>

R2_ACCOUNT_ID=<cloudflare-account-id>
R2_ACCESS_KEY_ID=<r2-access-key-id>
R2_SECRET_ACCESS_KEY=<r2-secret-access-key>
R2_BUCKET=shotup-media-dev
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
```

The backend reads configuration from process environment variables. Before running migrations or starting the server, export the file into the current shell:

```bash
set -a
source .env.development
set +a
```

Expected R2 bucket names are currently:

- `shotup-media-dev`
- `shotup-media-prod`

For local development, use `shotup-media-dev`.

## 4. DigitalOcean PostgreSQL Notes

Use DigitalOcean Managed PostgreSQL for development parity with production-like TLS behavior.

TLS requirements:

- Set `DATABASE_SSL_MODE=require`.
- Set `DATABASE_CA_CERT` to the DigitalOcean CA certificate file.
- The repository includes `Certificates/digitalocean-ca.crt` for the backend TLS trust root path used by local development.

Run migrations before using the API against a new database.

Example `psql` connection command:

```bash
PGSSLMODE=require \
PGSSLROOTCERT=Certificates/digitalocean-ca.crt \
psql \
  --host="$DATABASE_HOST" \
  --port="$DATABASE_PORT" \
  --username="$DATABASE_USERNAME" \
  --dbname="$DATABASE_NAME"
```

Inside `psql`, verify connectivity:

```sql
SELECT current_database(), current_user, now();
```

## 5. Run Migrations

From `api/`, after exporting `.env.development`:

```bash
swift run api migrate --yes
```

The backend registers migrations in `configure.swift` for users, projects, scenes, shots, media assets, refresh tokens, and sync events.

If a migration fails, fix the database or environment issue before starting the server. Avoid manually editing migration-created tables unless you know the local database is disposable.

## 6. Start Server

From `api/`, after exporting `.env.development`:

```bash
swift run api serve
```

By default, Vapor serves locally on:

```text
http://localhost:8080
```

## 7. Health Check

Check the API health endpoint:

```bash
curl http://localhost:8080/api/v1/health
```

Expected response shape:

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "Shotup Cloud API",
    "version": "0.1.0"
  },
  "message": null
}
```

## 8. Dev Login Curl Example

Use dev login to create or update a development user and receive tokens:

```bash
curl -X POST "http://localhost:8080/api/v1/auth/dev-login" \
  -H "Content-Type: application/json" \
  -d '{
    "appleUserID": "dev.local.user",
    "email": "dev@example.com",
    "displayName": "Local Developer"
  }'
```

The response includes:

- `accessToken`
- `refreshToken`
- `tokenType`
- `expiresIn`
- `user`

Use the access token on protected routes:

```bash
curl "http://localhost:8080/api/v1/me" \
  -H "Authorization: Bearer ACCESS_TOKEN_PLACEHOLDER"
```

## 9. Common Errors

### `certificate verify failed`

Likely causes:

- `DATABASE_SSL_MODE` is not set to `require`.
- `DATABASE_CA_CERT` points to a missing or wrong certificate file.
- The CA certificate does not match the DigitalOcean database cluster.

Recovery:

- Confirm `Certificates/digitalocean-ca.crt` exists.
- Confirm `DATABASE_CA_CERT=Certificates/digitalocean-ca.crt`.
- Re-download the CA certificate from DigitalOcean if the cluster changed.

### `permission denied for schema public`

Likely causes:

- The database user does not have permission to create tables.
- You are connected to the wrong database.
- Migrations are running with a restricted user.

Recovery:

- Confirm `DATABASE_NAME` and `DATABASE_USERNAME`.
- Grant schema privileges to the development database user.
- Use a database/user intended for local development migrations.

### Old `psql` without SSL support

Likely symptoms:

- `psql` cannot connect with `PGSSLMODE=require`.
- SSL options are ignored or rejected.

Recovery:

- Install a current PostgreSQL client with Homebrew.
- Ensure the Homebrew `psql` is first in `PATH`.
- Re-run `psql --version`.

### Missing R2 env variables

Likely symptoms:

- Server startup fails with `Missing required R2 environment variable`.
- Media endpoints return storage configuration errors.

Required variables:

- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET`
- `R2_ENDPOINT`

Recovery:

- Add the missing values to `.env.development`.
- Export the environment again with `set -a; source .env.development; set +a`.
- Restart the server.

## 10. Useful SQL Diagnostics

Count core tables:

```sql
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS project_count FROM projects;
SELECT COUNT(*) AS scene_count FROM scenes;
SELECT COUNT(*) AS shot_count FROM shots;
SELECT COUNT(*) AS media_asset_count FROM media_assets;
```

Check media status:

```sql
SELECT status, COUNT(*) AS count
FROM media_assets
GROUP BY status
ORDER BY status;
```

Find shots without media assets:

```sql
SELECT s.id AS shot_id, s.scene_id, s.created_at
FROM shots s
LEFT JOIN media_assets ma ON ma.shot_id = s.id
WHERE s.deleted_at IS NULL
  AND ma.id IS NULL
ORDER BY s.created_at;
```

Find pending uploads:

```sql
SELECT id, shot_id, object_key, created_at, updated_at
FROM media_assets
WHERE status = 'pending'
ORDER BY updated_at DESC;
```

Find media for a frame:

```sql
SELECT id, user_id, project_id, scene_id, shot_id, object_key, bucket, status, uploaded_at
FROM media_assets
WHERE shot_id = '{frameID}'
ORDER BY created_at DESC;
```

Check latest sync events:

```sql
SELECT user_id, entity, entity_id, operation, sequence, created_at
FROM sync_events
ORDER BY sequence DESC
LIMIT 20;
```
