# M8 - Cloud Download and Multi-Device Sync Plan

## Purpose

This document plans the next milestone after Phase 7 Cloud Sync Foundation. Phase 8 focuses on cloud download, fresh-device restore, and the first steps toward reliable multi-device sync.

## 1. Phase 8 Goals

Phase 8 goals:

- Cloud project list.
- Pull sync from backend to iOS.
- Media download recovery.
- New-device restore.
- Multi-device readiness.

The main outcome should be that a user can install Shotup on a fresh device, sign in, see cloud-backed projects, restore project metadata into local SQLite, and download missing media when needed.

## 2. Current Completed Foundation

Phase 7 completed the core upload and reconciliation foundation:

- Media upload flow through `POST /api/v1/media/request-upload`.
- Upload confirmation through `POST /api/v1/media/confirm-upload`.
- Download URL issuance through `POST /api/v1/media/request-download`.
- Media existence verification through `POST /api/v1/media/exists`.
- Orphan repair using backend-aware media checks.
- PostgreSQL validation for users, projects, scenes, shots, sync events, refresh tokens, and `media_assets`.
- Cloudflare R2 validation for presigned upload, presigned download, and object existence checks.
- Final reconciliation validation: 80 shots, 80 `media_assets`, 0 orphaned media.

The foundation proves that Shotup can push local metadata and media to the cloud. Phase 8 should make the reverse path robust: discovering cloud projects, pulling metadata, and restoring media onto a device.

## 3. Proposed Backend Work

### Cloud project listing

Add a backend capability for listing projects available to the authenticated user. This should return enough metadata for the iOS app to present cloud projects before fully restoring all nested scenes, shots, and media.

Important fields may include project ID, title, updated timestamp, deletion state, and summary counts. Exact response shape should be defined during implementation.

### Updated-since sync pull

Extend pull sync so iOS can request backend changes since its last sync token. The existing `SyncService` already returns `changes` in the sync response; Phase 8 should harden this into a reliable pull path for fresh devices and existing devices.

The server should remain authoritative for sync tokens and `updatedAt` values where applicable.

### Media manifest endpoint

Add a proposed media manifest capability that returns media availability for a set of frames or a project. This should help iOS decide what can be downloaded, what is pending, and what is missing.

The manifest should not expose presigned URLs directly unless the request is explicitly a download request. It should describe media state.

### Batch media exists endpoint

Add a batch version of media existence verification so repair and restore workflows can avoid one request per frame.

This should build on the current single-frame `POST /api/v1/media/exists` behavior, preserving ownership checks and database-only lookup semantics.

### Pagination

Large projects and multi-device histories require pagination. Project lists, pull sync results, and media manifests should support bounded response sizes.

Pagination should be stable across retries and should avoid forcing iOS to load an entire account into memory.

### Conflict metadata

Introduce enough metadata to detect future conflicts, even if Phase 8 still resolves with last-write-wins. Useful fields may include server update time, device ID, sync sequence, and operation source.

This is preparation for richer conflict handling in later milestones.

## 4. Proposed iOS Work

### Pull metadata into local SQLite

iOS should be able to pull project, scene, and shot metadata from the backend and materialize it into local SQLite. The local schema should preserve server IDs so future sync and media operations refer to the same objects.

### Download missing media

iOS should detect frames with backend-uploaded media but no local JPEG. It should enqueue download work and call `POST /api/v1/media/request-download` when a full-size original is needed.

### Project restore flow

Add a restore flow for a signed-in user on a fresh device:

1. Login.
2. Fetch cloud project list.
3. Select or automatically restore projects.
4. Pull project hierarchy metadata.
5. Populate local SQLite.
6. Download media on demand or in the background.

### Cloud status UI

The app should present clear cloud state:

- Local only.
- Syncing.
- Available in cloud.
- Missing local media.
- Downloading.
- Download failed.
- Up to date.

### Download queue improvements

The download queue should support retry, backoff, cancellation, progress, local cache writes, and durable state across app restarts.

## 5. Multi-Device Sync Strategy

Initial strategy:

- Use last-write-wins for Phase 8.
- Treat server `updatedAt` or server sync sequence as authoritative for ordering.
- Preserve `deviceID` on sync requests.
- Track enough metadata to support conflict detection later.

Conflict detection later:

- Detect when two devices update the same entity from the same base version.
- Store conflict metadata for user-visible or automatic resolution.
- Consider field-level merge only after the basic multi-device flow is stable.

Device ID tracking:

The existing sync request includes `deviceID`. Phase 8 should define how the backend records or interprets this value for auditing, diagnostics, and future conflict handling.

## 6. Download Strategy

Download should be metadata first.

Recommended model:

1. Pull project, scene, and shot metadata.
2. Store metadata locally.
3. Show projects and shots immediately.
4. Fetch thumbnails later when thumbnail support exists.
5. Download full media on demand.
6. Allow background download for selected projects or recently opened projects.

Thumbnails later:

The current schema has no thumbnails table. Phase 8 can plan thumbnail support but should not require it for fresh-device restore.

Full media on demand:

Original JPEG downloads can be large. Downloading full media only when needed reduces time-to-usable on fresh devices and avoids surprising storage/network use.

Background download queue:

The iOS download queue should support durable state, retry, backoff, progress, and cancellation. It should use `request-download` to obtain short-lived presigned URLs as work begins.

## 7. API Candidates

The following APIs are proposed. They do not exist yet unless implemented in Phase 8.

### Proposed: `GET /api/v1/projects/cloud`

Purpose:

List cloud projects owned by the authenticated user for restore and project picker flows.

### Proposed: `POST /api/v1/sync/pull`

Purpose:

Pull backend changes since a sync token without requiring a push batch. This may be separate from or folded into the existing `POST /api/v1/sync` contract.

### Proposed: `POST /api/v1/media/manifest`

Purpose:

Return media metadata for a project or frame set, including object availability and upload status, without issuing download URLs.

### Proposed: `POST /api/v1/media/exists/batch`

Purpose:

Check backend media existence for many frame IDs in one request. This supports repair, restore validation, and efficient missing-media detection.

## 8. Risks

Conflicts:

Multiple devices can edit the same project hierarchy. Last-write-wins is simple but can lose intent. Phase 8 should capture metadata for future conflict handling.

Duplicate IDs:

Fresh-device restore depends on stable server IDs. iOS must not create duplicate local IDs for entities that already exist in the cloud.

Deleted records:

Soft-deleted projects, scenes, and shots need clear restore and sync semantics. Tombstones must not resurrect deleted data accidentally.

Large projects:

Large project hierarchies and media sets require pagination, batching, and memory-conscious client processing.

Slow networks:

Fresh-device restore must remain usable on slow or unreliable networks. Metadata should restore before large media files.

## 9. Acceptance Criteria

Phase 8 should be considered complete when:

- A user can install the app on a fresh device.
- The user can log in.
- The app can list cloud projects.
- The app can restore projects, scenes, and shots into local SQLite.
- The app can identify frames with cloud media.
- The app can download media for restored frames.
- Database counts and local counts match for restored projects.
- Missing media recovery works without manual SQL intervention.
- Download failures remain retryable and do not corrupt local metadata.

Validation target:

- Compare backend project, scene, shot, and media counts to local SQLite counts after restore.
- Open restored projects and verify frames can resolve local or downloadable media.

## 10. Recommended Implementation Order

1. Backend: define cloud project listing response shape.
2. Backend: implement proposed `GET /api/v1/projects/cloud`.
3. Backend: add tests for project listing ownership and empty account behavior.
4. Backend: define pull sync behavior for fresh devices.
5. Backend: implement proposed `POST /api/v1/sync/pull` or extend existing `POST /api/v1/sync` with a pull-only mode.
6. Backend: add pagination for project listing and pull responses.
7. Backend: define media manifest response shape.
8. Backend: implement proposed `POST /api/v1/media/manifest`.
9. Backend: implement proposed `POST /api/v1/media/exists/batch`.
10. Backend: add integration tests for media manifest, batch exists, and ownership boundaries.
11. iOS: add cloud project list client and UI.
12. iOS: implement metadata pull into local SQLite using stable server IDs.
13. iOS: add fresh-device restore flow.
14. iOS: improve download queue durability, retry, and progress.
15. iOS: integrate `request-download` for missing media recovery.
16. iOS: validate local/backend counts after restore.
17. iOS and backend: run multi-device smoke tests with two devices using the same account.
18. iOS and backend: document known conflict behavior and hand off remaining conflict resolution to the next milestone.
