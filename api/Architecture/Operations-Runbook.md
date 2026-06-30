# Shotup Cloud Operations Runbook

## Purpose

This runbook documents how to operate, monitor, troubleshoot, and maintain the Shotup Cloud backend in production.

## 1. Overview

Shotup Cloud is a Vapor backend serving an iOS local-first client. The backend stores metadata in PostgreSQL, stores media binaries in Cloudflare R2, and protects user APIs with JWT authentication.

Primary components:

- Vapor API server for auth, sync, media upload/download, and repair verification.
- DigitalOcean Managed PostgreSQL for users, project metadata, sync events, refresh tokens, and `media_assets`.
- Cloudflare R2 for original JPEG binaries.
- JWT authentication for protected API routes.
- iOS client with local SQLite, offline queues, retry behavior, and repair tooling.

Typical production request flow:

1. iOS authenticates and receives a JWT access token plus refresh token.
2. iOS syncs project, scene, and shot metadata to the Vapor API.
3. Vapor validates JWT auth and writes metadata to PostgreSQL.
4. iOS requests a media upload URL from the API.
5. Vapor validates ownership and creates a pending `media_assets` row.
6. iOS uploads the JPEG directly to R2 through a presigned PUT URL.
7. iOS confirms upload with the API.
8. Vapor verifies the R2 object and marks the `media_assets` row uploaded.

## 2. Production Components

### API Server

Responsibilities:

- Serve `/api/v1` routes.
- Validate JWT Bearer tokens.
- Apply metadata sync through `SyncService`.
- Issue presigned upload/download URLs through `MediaService` and `R2StorageService`.
- Maintain `media_assets` state through `MediaRepository`.
- Emit structured logs and trace IDs.

Failure symptoms:

- Health check failures.
- Increased 5xx responses.
- Uploads stuck before `request-upload` or `confirm-upload`.
- Sync requests returning dependency or database errors.
- Authentication requests failing unexpectedly.

Recovery:

- Confirm the health endpoint.
- Check recent deploys and environment changes.
- Inspect structured logs by `traceID`, `userID`, `frameID`, and `objectKey`.
- Verify database connectivity.
- Verify R2 configuration and credentials.
- Restart the API process if it is unhealthy.
- Roll back the deploy if failures correlate with a new version.

### PostgreSQL

Responsibilities:

- Store users, projects, scenes, shots, media metadata, refresh tokens, and sync events.
- Enforce foreign key constraints and unique constraints.
- Provide canonical backend state for media reconciliation.

Backups:

- Use managed PostgreSQL automated backups.
- Confirm backup retention meets production requirements.
- Test restore procedures before they are needed.

Common issues:

- Connection exhaustion.
- Migration failure.
- TLS/CA verification failure.
- Slow queries or degraded database latency.
- Constraint violations caused by malformed or out-of-order data.

Recovery:

- Check managed database status.
- Verify connection string, SSL mode, and CA certificate path.
- Scale database or tune connection pooling if exhausted.
- Restore from backup only when data corruption or destructive data loss is confirmed.

### Cloudflare R2

Responsibilities:

- Store original JPEG binaries.
- Accept presigned PUT uploads.
- Serve presigned GET downloads.
- Provide object existence checks used by `confirm-upload`.

Common issues:

- R2 service degradation.
- Invalid credentials.
- Incorrect bucket or endpoint configuration.
- Expired presigned URLs.
- Upload timeout or object not visible during confirmation.

Recovery:

- Check Cloudflare R2 service status.
- Verify R2 environment variables and bucket name.
- Retry failed uploads with fresh presigned URLs.
- Treat temporary `confirm-upload` object-not-found failures as retryable.
- Keep local queue items durable until confirmation succeeds.

### iOS Clients

Responsibilities:

- Capture media into local storage.
- Persist metadata and queue state in local SQLite.
- Retry transient failures.
- Run repair workflows when backend media metadata is missing.

Offline queue:

The iOS client must preserve pending metadata and media work across offline sessions, app restarts, and transient backend or R2 failures.

Retry behavior:

`MediaUploadWorker` and `MediaUploadQueue` should retry network failures, dependency-not-ready failures, and temporary storage failures with backoff. Permanent failures should be explicit.

Repair workflow:

`OrphanedMediaUploadRepairScanner` and `BackendMediaVerifier` use the media exists endpoint to identify backend-missing media and re-enqueue local files into the normal upload path. `SyncDashboard` exposes repair controls in debug tooling.

## 3. Deployment Checklist

Before deployment:

- Confirm the target environment and release version.
- Review migration changes.
- Confirm PostgreSQL is reachable.
- Confirm R2 bucket and endpoint configuration.
- Confirm JWT secret configuration.
- Confirm environment variables are present.
- Confirm TLS CA certificate path and file contents.
- Verify secrets are not committed to the repository.
- Build the backend.
- Run backend tests in CI or locally against an appropriate test environment.
- Run smoke tests after deployment.

Database migrations:

- Apply migrations in the registered Vapor order.
- Confirm migrations complete before serving traffic requiring new schema.
- Roll back only with an explicit database plan.

Environment variables:

- `DATABASE_HOST`
- `DATABASE_PORT`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_NAME`
- `DATABASE_SSL_MODE`
- `DATABASE_CA_CERT`
- `JWT_SECRET`
- R2 account, bucket, endpoint, access key, and secret key values

TLS certificates:

- Use CA verification for managed PostgreSQL in production.
- Ensure `DATABASE_CA_CERT` points to the deployed CA bundle.

Secrets:

- Store secrets in the deployment platform secret manager.
- Rotate leaked or suspected-leaked credentials immediately.

Build verification:

- Confirm the Vapor application starts cleanly.
- Confirm migrations are registered.
- Confirm protected routes reject missing auth.

Smoke tests:

- `GET /api/v1/health`
- Auth login or token refresh.
- Metadata sync with no changes.
- Media exists for a known frame.
- Request upload for a test frame.
- Request download for an uploaded test frame.

## 4. Monitoring

Monitor:

- API latency by route.
- Database latency and connection pool pressure.
- Upload success rate.
- Upload failures by stage: `request-upload`, R2 PUT, `confirm-upload`.
- Download failures.
- Authentication failures.
- Repair executions.
- Error rates by status code.

Suggested operational signals:

- p50, p95, and p99 API latency.
- 4xx rate separated from 5xx rate.
- Count of pending `media_assets`.
- Count of uploaded `media_assets`.
- Queue repair counts from client/debug tooling.
- Confirm-upload object-not-found failures.
- R2 PUT and GET failure rates as observed by iOS clients.

## 5. Logging

The backend uses structured logs for media operations in `MediaController`. Logs should be searchable by stable fields.

Useful fields:

- `traceID`
- `requestID`
- `userID`
- `projectID`
- `sceneID`
- `frameID`
- `mediaAssetID`
- `objectKey`
- `status`
- `duration`
- `error`

Existing media log events include:

- `media.upload.request.started`
- `media.upload.request.completed`
- `media.upload.request.failed`
- `media.upload.confirm.started`
- `media.upload.confirm.completed`
- `media.upload.confirm.failed`
- `media.download.request.started`
- `media.download.request.completed`
- `media.download.request.failed`

Example log metadata:

```json
{
  "event": "media.upload.confirm.completed",
  "traceID": "trace-0001",
  "userID": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "objectKey": "users/.../original.jpg",
  "status": "uploaded",
  "confirmDurationMs": 82,
  "putDurationMs": 1420,
  "totalDurationMs": 1502
}
```

## 6. Health Checks

Current implemented health route:

```text
GET /api/v1/health
```

Some infrastructure may probe or expose this as `GET /health`; if so, that should be configured at the load balancer or routing layer. The Vapor route currently lives under `/api/v1/health`.

Expected response data:

```json
{
  "status": "ok",
  "service": "Shotup Cloud API",
  "version": "0.1.0"
}
```

Database connectivity:

The current health controller reports API process health. A deeper production health check may additionally verify PostgreSQL connectivity with a lightweight query.

R2 connectivity:

R2 connectivity is not currently required by the basic health route. A deeper health check may verify R2 configuration or perform a non-mutating storage check, but it should avoid expensive object operations on every load balancer probe.

## 7. Troubleshooting Guide

### Uploads stuck pending

Likely causes:

- Metadata dependencies are not synced.
- `request-upload` returns `Project not found`, `Scene not found`, or `Frame not found`.
- R2 PUT is failing.
- `confirm-upload` cannot see the object.
- Auth token refresh is failing.
- Upload worker is not retrying pending items.

Diagnostic SQL:

```sql
SELECT id, shot_id, object_key, status, created_at, updated_at
FROM media_assets
WHERE status = 'pending'
ORDER BY updated_at DESC;
```

Recovery:

- Confirm metadata sync is completing.
- Retry pending uploads from the iOS client.
- Check logs for `media.upload.request.failed` and `media.upload.confirm.failed`.
- Verify R2 configuration.
- If backend media metadata is missing, run repair through `SyncDashboard`.

### Media exists locally but not in cloud

Diagnostic steps:

1. Confirm the local JPEG still exists.
2. Check whether the shot exists in PostgreSQL.
3. Call `POST /api/v1/media/exists` for the frame.
4. If `exists` is false, run orphan repair.
5. Verify a new upload attempt reaches `confirm-upload`.

Repair workflow:

`OrphanedMediaUploadRepairScanner` scans local uploaded state, `BackendMediaVerifier` checks backend state, and backend-missing media is re-enqueued into `MediaUploadQueue`.

Expected outcome:

The normal upload path completes and a new `media_assets` row reaches `uploaded`.

### JWT failures

Common causes:

- Expired access token.
- Invalid refresh token.
- Changed or missing `JWT_SECRET`.
- Clock skew.
- User logged out or token revoked.

Recovery:

- Refresh the token.
- Reauthenticate if refresh fails.
- Confirm `JWT_SECRET` is stable across deploys.
- Check auth logs and 401 rates.

### Database unavailable

Recovery:

- Check managed PostgreSQL status.
- Confirm network access from the API server.
- Verify TLS settings and CA certificate.
- Check connection limits.
- Restart the API after database connectivity is restored if needed.
- Avoid running repair or migrations until database stability is restored.

### Cloudflare R2 unavailable

Recovery:

- Check Cloudflare status.
- Confirm R2 credentials and endpoint.
- Pause or let client upload queues back off.
- Do not mark uploads complete without successful `confirm-upload`.
- Once R2 recovers, retry pending media uploads.

## 8. SQL Diagnostics

Count projects:

```sql
SELECT COUNT(*) AS project_count FROM projects;
```

Count scenes:

```sql
SELECT COUNT(*) AS scene_count FROM scenes;
```

Count shots:

```sql
SELECT COUNT(*) AS shot_count FROM shots;
```

Count media assets:

```sql
SELECT COUNT(*) AS media_asset_count FROM media_assets;
```

Media by status:

```sql
SELECT status, COUNT(*) AS count
FROM media_assets
GROUP BY status
ORDER BY status;
```

Find orphaned shots:

```sql
SELECT s.id AS shot_id, s.scene_id, s.created_at
FROM shots s
LEFT JOIN media_assets ma ON ma.shot_id = s.id
WHERE s.deleted_at IS NULL
  AND ma.id IS NULL
ORDER BY s.created_at;
```

Find duplicate object keys:

```sql
SELECT object_key, COUNT(*) AS count
FROM media_assets
GROUP BY object_key
HAVING COUNT(*) > 1;
```

Find pending uploads:

```sql
SELECT id, shot_id, object_key, created_at, updated_at
FROM media_assets
WHERE status = 'pending'
ORDER BY updated_at DESC;
```

Find uploaded media:

```sql
SELECT id, shot_id, object_key, size_bytes, uploaded_at
FROM media_assets
WHERE status = 'uploaded'
ORDER BY uploaded_at DESC;
```

Find media for a frame:

```sql
SELECT id, user_id, project_id, scene_id, shot_id, object_key, bucket, status, uploaded_at
FROM media_assets
WHERE shot_id = '{frameID}'
ORDER BY created_at DESC;
```

## 9. Operational Procedures

Restart backend:

- Drain traffic if the platform supports it.
- Restart the Vapor process or service.
- Confirm `/api/v1/health` returns `ok`.
- Watch 5xx rates and startup logs.

Deploy new version:

- Build the release artifact.
- Confirm environment variables and secrets.
- Apply migrations if required.
- Deploy one environment at a time.
- Run smoke tests.

Rollback:

- Prefer application rollback before database rollback.
- Confirm whether the new version introduced migrations.
- If migrations are backward-compatible, roll back the app version.
- If schema rollback is required, use a reviewed database recovery plan.

Apply migrations:

- Ensure database backup coverage is active.
- Run migrations through the Vapor migration mechanism.
- Confirm migration logs.
- Verify expected tables and indexes.

Verify deployment:

- Health route returns success.
- Auth works.
- Sync works.
- Media exists endpoint works.
- Upload and download smoke tests work.

Verify uploads:

- Create or use a test frame.
- Call `request-upload`.
- PUT a JPEG to R2.
- Call `confirm-upload`.
- Confirm `media_assets.status = 'uploaded'`.

Verify downloads:

- Use a frame with uploaded media.
- Call `request-download`.
- Confirm the returned URL can retrieve the object before expiration.

Verify media exists endpoint:

- Call `POST /api/v1/media/exists` for a known uploaded frame.
- Confirm `exists: true`, `objectKey`, and `status: uploaded`.

## 10. Incident Response

Recommended order:

1. Confirm health endpoint.
2. Check logs.
3. Check database.
4. Check R2.
5. Run repair.
6. Verify counts.
7. Resume service.

Incident notes:

- Preserve local media and queue state.
- Avoid destructive database changes during active incidents.
- Separate auth failures from storage failures.
- Confirm whether failures are global or isolated to a user/project/frame.
- Use `traceID` to connect request-upload and confirm-upload logs.

## 11. Capacity Planning

Database growth:

- `sync_events` grows with metadata change volume.
- `media_assets` grows with uploaded frame count.
- Projects, scenes, and shots grow with user activity.

Media growth:

- R2 storage grows with original JPEG count and size.
- Future thumbnails and versions will increase object count.

Storage costs:

- Track R2 object storage, request volume, and egress.
- Track PostgreSQL storage and backup retention.

Upload throughput:

- Monitor request-upload and confirm-upload latency.
- Monitor client-observed R2 PUT duration.
- Watch for spikes in pending media assets.

Connection pooling:

- Ensure Vapor/Postgres connection settings match database capacity.
- Watch connection exhaustion during sync or repair spikes.

Future scaling:

- Add background reconciliation workers.
- Add metrics and alerting.
- Consider queue-specific throttling for upload and repair.
- Partition or archive high-volume sync event history if needed.

## 12. Backup and Disaster Recovery

Database backups:

- Use managed PostgreSQL automated backups.
- Periodically test restores.
- Document retention period and restore point objective.

R2 durability:

- R2 stores media binaries separately from metadata.
- PostgreSQL `object_key` values are required to locate and authorize those objects.

Restore strategy:

1. Restore PostgreSQL metadata first.
2. Confirm users, project hierarchy, shots, and `media_assets` are present.
3. Verify R2 buckets and objects remain available.
4. Run media existence checks on representative frames.
5. Run repair only for local clients that can re-upload missing backend media.

Recovery priorities:

1. Protect user identity and project metadata.
2. Protect shot metadata and sync state.
3. Restore media metadata.
4. Reconcile R2 objects and local client queues.

Expected recovery workflow:

- Bring up database from backup.
- Deploy API with correct secrets and R2 credentials.
- Confirm health and auth.
- Confirm sync routes.
- Confirm media exists and download for known uploaded frames.
- Let clients retry pending uploads.
- Run repair where backend metadata is missing but local media remains available.

## 13. Current Validation

Current verified state:

- 80 shots
- 80 `media_assets`
- 0 orphaned shots
- Repair workflow validated
- Media exists endpoint validated
- Upload reconciliation validated

## 14. Future Operations Improvements

- Metrics dashboard.
- Prometheus metrics export.
- Grafana dashboards.
- Alerting for 5xx rate, auth failures, pending uploads, and repair failures.
- Automatic reconciliation.
- Nightly repair jobs.
- Admin dashboard.
- Background health verification for PostgreSQL and R2.
