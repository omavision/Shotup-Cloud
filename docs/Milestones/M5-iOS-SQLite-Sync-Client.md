# M5 — iOS SQLite Sync Client

## Goal

Build the iOS-side SQLite synchronization client that can reliably store Project / Scene / Shot data locally, track offline edits, exchange changes with the Shotup Cloud `/api/v1/sync` endpoint, and keep the local database consistent with the M4.5 backend sync contract.

This milestone is planning only until implementation begins. No iOS sync code is introduced by this document.

## Current Backend Readiness

M4.5 establishes the backend contract needed for the first production-ready iOS SQLite sync client.

Backend capabilities available to the iOS client:

- Authenticated `/api/v1/sync` endpoint.
- Supported sync entities: `project`, `scene`, and `shot`.
- Supported operations: `upsert` and `delete`.
- String-based payload compatibility through `[String:String]?`.
- Persistent `syncToken` values based on per-user `SyncEvent.sequence`.
- `lastSyncToken` support for incremental downloads.
- Full initial download behavior when `lastSyncToken` is `null`.
- Tombstone `DownloadChange` objects for incremental delete events.
- Coarse Last Write Wins conflict behavior with conflict responses when the server version is newer.

Backend limitations the iOS client must account for:

- Clients should treat `syncToken` as opaque even though it is currently a sequence string.
- Payload values are string-based for v1 compatibility.
- Media, camera setup, and lens setup are not part of this milestone.
- Conflict metadata is intentionally coarse and does not include field-level merge details.

## Expected iOS Responsibilities

The iOS client owns local-first persistence and sync orchestration.

Responsibilities:

- Store supported entities in a local SQLite database.
- Support local create, update, and soft delete while offline.
- Track unsynced local changes in a durable upload queue.
- Store the latest successful server `syncToken`.
- Upload pending local changes to `/api/v1/sync`.
- Download and merge server changes into SQLite.
- Apply tombstones from the server.
- Surface basic sync status to the user.
- Retry safely after network, authentication, or server failures.

The iOS client should make local reads and writes independent of immediate network availability.

## Local Change Tracking

Each locally editable sync entity should have enough metadata to determine whether it needs upload.

Expected local metadata:

- Stable UUID primary key shared with the server.
- Entity update timestamp used in sync payloads.
- Local deletion marker for soft deletes.
- Dirty flag or equivalent pending-change marker.
- Last local operation: `upsert` or `delete`.
- Optional retry/error metadata for diagnostics.

Local edits should produce deterministic sync changes:

- Create and update produce `operation: "upsert"`.
- Delete produces `operation: "delete"` and should keep enough local state to upload the tombstone.
- Repeated edits to the same entity may be coalesced before upload when safe.

## Upload Queue

The upload queue is the durable boundary between local editing and server synchronization.

Queue requirements:

- Survive app termination and relaunch.
- Preserve enough entity payload data to build `SyncChange` requests.
- Avoid duplicate uploads for the same final local state when possible.
- Preserve dependency order where needed, such as project before scene and scene before shot.
- Mark entries as uploaded only after the server accepts the sync response.
- Keep failed entries available for retry.

The initial queue can be simple and entity-based. A later milestone can introduce more advanced batching, compaction, or dependency graph handling.

## SyncToken Storage

The iOS client stores the latest successful `syncToken` returned by the backend.

Rules:

- Store the token durably in SQLite or another persistent app store.
- Send it as `lastSyncToken` on the next sync request.
- Send `null` for the first sync or after an explicit local sync reset.
- Treat the token as opaque client-side state.
- Update the stored token only after local upload results and downloaded changes have been handled successfully.

If merge processing fails after a response is received, the client should not advance the stored token until it can safely replay the download.

## Download Merge

Downloaded `DownloadChange` objects must be merged into SQLite after upload handling.

Merge rules:

- Apply `project`, `scene`, and `shot` changes by stable UUID.
- For `upsert`, create the row if missing or update the existing row.
- Preserve local-only pending edits when a server download would otherwise overwrite unsynced local state.
- Keep parent relationships valid, such as scene to project and shot to scene.
- Apply downloaded changes in response order.
- Advance the local `syncToken` only after all downloaded changes are applied.

The first sync with `lastSyncToken: null` should be treated as a full initial download of active entities. Later syncs should merge only incremental changes returned by the server.

## Tombstone Handling

The backend returns delete tombstones during incremental sync.

iOS tombstone behavior:

- Treat `operation: "delete"` with `payload: null` as a server-side deletion.
- Soft-delete or remove the matching local row according to the local database strategy.
- Clear pending local upload state only when the tombstone corresponds to a successfully acknowledged local delete.
- Avoid resurrecting deleted rows from stale local state.
- Keep enough tombstone metadata to prevent repeated display of deleted entities.

Initial full downloads exclude soft-deleted server rows, so a fresh install may simply not receive deleted entities.

## Conflict Handling

M5 should implement the first iOS conflict behavior around the M4.5 backend response shape.

Initial strategy:

- Treat server conflict responses as authoritative for the affected change.
- Do not silently discard the local edit without recording the conflict state.
- Keep the local row available for user review or future retry when appropriate.
- Surface a basic conflict/error state in sync diagnostics or UI.
- Avoid field-level merge UI in this milestone.

The backend currently returns coarse conflict reasons such as a newer server version. The iOS client should be designed so richer conflict metadata can be introduced later without replacing the whole sync pipeline.

## Offline Retry Behavior

The iOS client must assume network access is intermittent.

Retry behavior:

- Queue local edits while offline.
- Retry sync when the app becomes active and network appears available.
- Retry after transient transport or server errors with backoff.
- Do not advance `syncToken` after failed sync attempts.
- Keep upload queue entries durable until acknowledged.
- Handle authentication failures separately from network failures.
- Avoid concurrent sync runs against the same local store.

Sync should be idempotent from the user's perspective. Replaying a previously attempted upload should not create duplicate server entities because entity UUIDs are stable.

## Sync Status UI

The app should expose a small amount of sync state without turning M5 into a full conflict-management UI milestone.

Expected status states:

- Not synced yet.
- Syncing.
- Up to date.
- Offline with pending changes.
- Sync failed.
- Conflict needs attention.

The UI should help the user understand whether local work is safe, pending upload, or blocked by an error. Detailed per-field conflict resolution is out of scope.

## Validation Plan

Validation should cover local persistence, sync request construction, merge behavior, and offline recovery.

Planned validation:

- Unit tests for local change tracking.
- Unit tests for upload queue creation, ordering, coalescing, and retry state.
- Unit tests for `syncToken` storage and advancement rules.
- Unit tests for download merge across project, scene, and shot.
- Unit tests for tombstone handling.
- Integration tests against the M4.5 backend contract where practical.
- Manual smoke test for first sync, offline edit, reconnect, upload, incremental download, delete, and conflict response.
- Regression test that failed sync attempts do not advance the local token.

Validation should include at least one end-to-end path for project, scene, and shot data.

## Out Of Scope

- Media upload and download.
- Cloudflare R2 integration.
- Collaboration or multi-user shared editing.
- Full conflict resolution UI.
- Typed JSON sync payload migration.
- Background sync guarantees beyond basic app lifecycle triggers.
- Server-side schema or sync protocol changes.
- Web dashboard behavior.

## Proposed Phases

### Phase 1 — Planning And Local Schema

Define the SQLite schema, local metadata fields, sync token storage location, and local repository boundaries.

### Phase 2 — Local Change Tracking

Track local create, update, and delete operations for Project, Scene, and Shot.

### Phase 3 — Upload Queue

Build durable queueing, request construction, batching rules, and retry metadata.

### Phase 4 — SyncToken Persistence

Persist and advance `syncToken` only after successful upload/download processing.

### Phase 5 — Download Merge

Apply full and incremental downloads into SQLite while preserving pending local edits.

### Phase 6 — Tombstones And Conflicts

Handle server delete tombstones and coarse conflict responses.

### Phase 7 — Offline Retry And Status UI

Add retry orchestration, sync state tracking, and user-visible sync status.

### Phase 8 — Validation

Run unit, integration, and manual smoke validation before closing the milestone.

## Acceptance Criteria

- iOS stores Project, Scene, and Shot data locally in SQLite.
- Local edits work while offline.
- Local changes are persisted in a durable upload queue.
- The client sends queued changes to `/api/v1/sync`.
- The client stores and sends `syncToken` / `lastSyncToken` correctly.
- Initial sync can populate local SQLite from server state.
- Incremental sync applies server changes since the previous token.
- Delete tombstones are handled without resurrecting deleted rows.
- Conflict responses are retained and surfaced at a basic status level.
- Failed sync attempts do not lose queued changes or advance the token.
- Sync status UI communicates pending, syncing, up-to-date, failed, offline, and conflict states.
- Validation covers project, scene, and shot sync paths.

## Final Tag

`M5-iOS-SQLite-Sync-Client`
