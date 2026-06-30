# Shotup Cloud API Reference

## Purpose

This document describes the Phase 7 Shotup Cloud backend API surface for authentication, sync, media upload, media download, and media existence verification.

## 1. Overview

Base path:

```text
/api/v1
```

The backend is a Vapor API backed by PostgreSQL and Cloudflare R2:

- PostgreSQL stores users, project/scene/shot metadata, auth sessions, sync events, and `media_assets` metadata.
- Cloudflare R2 stores media binaries.
- The API issues presigned R2 URLs for direct client upload and download.

Most successful responses use the JSON `APIResponse<T>` wrapper:

```json
{
  "success": true,
  "data": {},
  "message": null
}
```

Protected routes require JWT Bearer auth:

```text
Authorization: Bearer {accessToken}
```

## 2. Authentication

Authentication routes are mounted under:

```text
/api/v1/auth
```

Implemented routes:

- `POST /api/v1/auth/dev-login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/apple`

### Dev Login

`POST /api/v1/auth/dev-login` is present for development login.

Request fields:

- `appleUserID`
- `email`
- `displayName`

Response data fields:

- `accessToken`
- `refreshToken`
- `tokenType`
- `expiresIn`
- `user`

`tokenType` is currently `Bearer`. `expiresIn` is currently `3600` seconds.

### Refresh

`POST /api/v1/auth/refresh` rotates a refresh token and returns a new auth response.

Request fields:

- `refreshToken`

Response data fields match dev-login.

### Apple Sign-In

`POST /api/v1/auth/apple` verifies an Apple identity token and returns the same auth response shape. This is the production-oriented sign-in path.

## 3. Health

```text
GET /api/v1/health
```

Purpose:

Health check for the API process.

Response data fields:

- `status`
- `service`
- `version`

Example response data:

```json
{
  "status": "ok",
  "service": "Shotup Cloud API",
  "version": "0.1.0"
}
```

## 4. Sync

```text
POST /api/v1/sync
```

Purpose:

Synchronizes metadata changes between iOS local SQLite and backend PostgreSQL. Phase 7 sync covers project, scene, and shot entity sync.

Auth:

Requires JWT Bearer auth.

Request shape:

```json
{
  "deviceID": "ios-device-1",
  "lastSyncToken": "123",
  "changes": [
    {
      "entity": "project",
      "operation": "upsert",
      "id": "00000000-0000-0000-0000-000000000001",
      "updatedAt": "2026-06-30T12:00:00Z",
      "payload": {
        "title": "Project title"
      }
    }
  ]
}
```

Entities:

- `project`
- `scene`
- `shot`

Operations:

- `upsert`
- `delete`

Response data fields:

- `syncToken`
- `serverTime`
- `changes`
- `conflicts`

Dependency ordering:

`SyncService` applies incoming changes in dependency order:

1. Project
2. Scene
3. Shot

This prevents child records from being applied before parents exist.

Conflict behavior:

Per-change failures are returned in `conflicts`. A failed change does not stop the whole batch. Unsupported entities, validation failures, and handler `Abort` reasons are represented as conflicts with `entity`, `id`, and `reason`.

## 5. Media Request Upload

```text
POST /api/v1/media/request-upload
```

Purpose:

Creates or resets a pending `media_assets` row and returns a presigned Cloudflare R2 PUT URL for uploading the original JPEG.

Auth:

Requires JWT Bearer auth.

Request fields:

- `projectID`
- `sceneID`
- `frameID`
- `contentType`

Example request body:

```json
{
  "projectID": "11111111-1111-1111-1111-111111111111",
  "sceneID": "22222222-2222-2222-2222-222222222222",
  "frameID": "33333333-3333-3333-3333-333333333333",
  "contentType": "image/jpeg"
}
```

Response data fields:

- `uploadURL`
- `objectKey`
- `expiresAt`
- `requiredHeaders`

Behavior:

`MediaService.requestUpload` verifies project ownership, scene membership, shot/frame membership, and supported content type. It uses `R2StorageService` to create a presigned upload URL and `MediaRepository.upsertPendingUpload` to persist a `pending` media asset.

Errors:

- `400`: unsupported content type.
- `401`: invalid or missing auth.
- `403`: unauthorized project.
- `404`: missing dependency, such as `Project not found`, `Scene not found`, or `Frame not found`.

## 6. Media Confirm Upload

```text
POST /api/v1/media/confirm-upload
```

Purpose:

Confirms that the client uploaded the JPEG to R2 and marks the backend `media_assets` row as uploaded.

Auth:

Requires JWT Bearer auth.

Request fields:

- `objectKey`
- `size`
- `mimeType`
- `checksum`

`checksum` is optional.

Example request body:

```json
{
  "objectKey": "users/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/projects/11111111-1111-1111-1111-111111111111/scenes/22222222-2222-2222-2222-222222222222/frames/33333333-3333-3333-3333-333333333333/original.jpg",
  "size": 245678,
  "mimeType": "image/jpeg",
  "checksum": "sha256-placeholder"
}
```

Response data:

```json
{
  "success": true
}
```

Behavior:

`MediaService.confirmUpload` checks for a pending media asset, verifies that it belongs to the authenticated user, checks that the object exists in R2, validates the MIME type, and calls `MediaRepository.markUploaded`. The row transitions from `pending` to `uploaded`.

## 7. Media Request Download

```text
POST /api/v1/media/request-download
```

Purpose:

Returns a presigned Cloudflare R2 GET URL for a previously uploaded frame.

Auth:

Requires JWT Bearer auth.

Request fields:

- `frameID`

Example request body:

```json
{
  "frameID": "33333333-3333-3333-3333-333333333333"
}
```

Response data fields:

- `downloadURL`
- `objectKey`
- `expiresAt`

Errors:

- `404`: missing media asset.
- `409`: media exists but is not uploaded yet.
- `403`: authenticated user does not own the media asset.

## 8. Media Exists

```text
POST /api/v1/media/exists
```

Purpose:

Supports reconciliation and repair tooling by checking whether the backend has media metadata for a frame.

Auth:

Requires JWT Bearer auth.

Request fields:

- `frameID`

Example request body:

```json
{
  "frameID": "33333333-3333-3333-3333-333333333333"
}
```

Response data fields:

- `exists`
- `mediaAssetID`
- `objectKey`
- `status`

Example response data when media exists:

```json
{
  "exists": true,
  "mediaAssetID": "44444444-4444-4444-4444-444444444444",
  "objectKey": "users/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/projects/11111111-1111-1111-1111-111111111111/scenes/22222222-2222-2222-2222-222222222222/frames/33333333-3333-3333-3333-333333333333/original.jpg",
  "status": "uploaded"
}
```

Behavior:

This endpoint performs a database lookup only. It does not call R2 and does not return a presigned URL. It should be used for repair and reconciliation instead of using `request-download` as an existence probe.

## 9. Error Semantics

- `400`: validation or client input error, such as unsupported content type.
- `401`: authentication failure, such as missing or invalid JWT.
- `403`: authorization failure. The user is authenticated but does not own the requested resource.
- `404`: missing resource or dependency, such as missing project, scene, frame, pending media asset, or media asset.
- `409`: state conflict, such as requesting download before media is uploaded.

Transient dependency-not-ready handling on iOS:

`Project not found`, `Scene not found`, and `Frame not found` during media upload usually mean metadata sync has not completed yet. The iOS upload queue should retry metadata sync and then retry upload rather than treating these as permanent failures.

## 10. Traceability

Media routes support `X-Trace-ID`.

```text
X-Trace-ID: {traceID}
```

One upload attempt should use the same trace ID for:

- `POST /api/v1/media/request-upload`
- `POST /api/v1/media/confirm-upload`

`MediaUploadTrace` resolves the trace ID from the request header or generates one if missing. Media responses include the trace ID header. `MediaController` logs structured events for upload request, upload confirm, and download request lifecycle events.

## 11. Security Notes

- Media routes are JWT protected.
- Sync routes are JWT protected.
- Media operations enforce ownership checks.
- Presigned R2 URLs expire.
- Only `image/jpeg` is currently supported for upload and confirm.
- R2 credentials remain backend-only.
- Object keys are storage identifiers, not authorization credentials.

## 12. Example Requests

### dev-login

```bash
curl -X POST "http://localhost:8080/api/v1/auth/dev-login" \
  -H "Content-Type: application/json" \
  -d '{
    "appleUserID": "dev.user.001",
    "email": "dev@example.com",
    "displayName": "Dev User"
  }'
```

### media/exists

```bash
curl -X POST "http://localhost:8080/api/v1/media/exists" \
  -H "Authorization: Bearer ACCESS_TOKEN_PLACEHOLDER" \
  -H "Content-Type: application/json" \
  -d '{
    "frameID": "33333333-3333-3333-3333-333333333333"
  }'
```

### media/request-upload

```bash
curl -X POST "http://localhost:8080/api/v1/media/request-upload" \
  -H "Authorization: Bearer ACCESS_TOKEN_PLACEHOLDER" \
  -H "Content-Type: application/json" \
  -H "X-Trace-ID: trace-0001" \
  -d '{
    "projectID": "11111111-1111-1111-1111-111111111111",
    "sceneID": "22222222-2222-2222-2222-222222222222",
    "frameID": "33333333-3333-3333-3333-333333333333",
    "contentType": "image/jpeg"
  }'
```

### media/confirm-upload

```bash
curl -X POST "http://localhost:8080/api/v1/media/confirm-upload" \
  -H "Authorization: Bearer ACCESS_TOKEN_PLACEHOLDER" \
  -H "Content-Type: application/json" \
  -H "X-Trace-ID: trace-0001" \
  -d '{
    "objectKey": "users/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/projects/11111111-1111-1111-1111-111111111111/scenes/22222222-2222-2222-2222-222222222222/frames/33333333-3333-3333-3333-333333333333/original.jpg",
    "size": 245678,
    "mimeType": "image/jpeg",
    "checksum": "sha256-placeholder"
  }'
```

### media/request-download

```bash
curl -X POST "http://localhost:8080/api/v1/media/request-download" \
  -H "Authorization: Bearer ACCESS_TOKEN_PLACEHOLDER" \
  -H "Content-Type: application/json" \
  -d '{
    "frameID": "33333333-3333-3333-3333-333333333333"
  }'
```

## 13. Known Limitations

- `dev-login` is development-only.
- The media exists endpoint does not check R2 object existence.
- No batch media existence endpoint yet.
- No collaboration endpoints yet.

## 14. Future API Candidates

These endpoints do not exist yet and are listed as future candidates:

- Batch media exists.
- Project members.
- Cloud project list.
- Device registration.
- Background sync diagnostics.
