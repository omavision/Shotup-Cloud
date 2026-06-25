# Persistent Sync Tokens

## Context

M4.5 Production Hardening moves Shotup Cloud from successful manual sync validation toward a reliable backend contract for the iOS SQLite sync client.

The previous synchronization engine returned a random UUID as `syncToken` after each `/sync` request. That token proved the server completed a response, but it did not identify a durable position in the change stream. M4.5 Phase 3 introduced persistent sync tokens using Option C: Global Sync Sequence.

## Goals

- Give each committed sync-visible change a durable ordering position.
- Let clients store `lastSyncToken` as their last observed sequence.
- Enable incremental downloads without relying on wall-clock timestamps.
- Preserve the current Project / Scene / Shot sync contract while hardening the token model.
- Keep the design simple enough for M4.5 and extensible enough for future entities.

## Why Random UUID Tokens Are Not Sufficient

Random UUID tokens are opaque but not meaningful.

Previous behavior:

```text
Client syncs -> server returns UUID token -> client stores UUID token
```

Problem:

```text
UUID token does not tell the server what changed before or after it.
```

A random token cannot answer:

- Which database changes happened after this token?
- Was this token issued before or after another token?
- Which rows should be included in the next incremental download?
- Can this token be used after a server restart?

Random UUID tokens are acceptable as temporary response identifiers, but they are not sufficient as persistent sync cursors.

## Why Timestamp-Only Tokens Are Risky

A timestamp token seems simple:

```text
lastSyncToken = "2026-06-25T19:00:15Z"
```

The download query could then ask for rows where:

```sql
updated_at > last_sync_time
```

This is risky because timestamps are not a perfect ordering mechanism.

Risks:

- Multiple changes can share the same timestamp precision.
- Client-provided `updatedAt` values may not match server commit order.
- Database clocks, app clocks, and client clocks can drift.
- Retried requests can reuse older timestamps.
- Concurrent writes can be committed in a different order than their timestamps imply.
- Using `>` can miss changes at the same timestamp; using `>=` can repeatedly resend changes.

Timestamp filtering may still be useful for diagnostics, but it should not be the primary sync cursor.

## Decision: Global Sync Sequence

Shotup Cloud will use a global monotonically increasing sequence for sync-visible events.

Each sync-visible mutation writes a `SyncEvent` row. The current implementation computes the next sequence in application code by reading the latest known sequence and writing `latest + 1`. The latest sequence seen by the client becomes the next `lastSyncToken`.

This keeps the M4.5 implementation simple, but a future production hardening pass may replace application-computed sequence values with a PostgreSQL sequence or another database-enforced allocator for stronger concurrency guarantees.

Conceptually:

```text
sequence 1 -> project upsert
sequence 2 -> scene upsert
sequence 3 -> shot upsert
sequence 4 -> shot delete
```

The client stores:

```text
lastSyncToken = "4"
```

The next download asks for:

```text
all SyncEvents where sequence > 4
```

## Why This Was Chosen

Global Sync Sequence was chosen because it gives the backend a durable, simple, total ordering of sync-visible events.

Benefits:

- No reliance on clock precision.
- Easy incremental query: `sequence > lastSequence`.
- Stable across server restarts.
- Easy for clients to store as a string token.
- Works across Project, Scene, Shot, and future entities.
- Supports delete tombstones naturally.
- Keeps M4.5 conflict handling separate from cursor mechanics.

Tradeoff:

- All sync-visible changes share one sequence stream.
- The event table can grow and will eventually need retention or compaction rules.

## SyncEvent Table Concept

M4.5 will introduce a persistent event log for sync-visible changes.

Conceptual fields:

| Field | Purpose |
| --- | --- |
| `sequence` | Monotonically increasing server-assigned sync cursor. Currently computed by application code as latest sequence + 1. |
| `entity` | Entity type, such as `project`, `scene`, or `shot`. |
| `operation` | Sync operation, such as `upsert` or `delete`. |
| `entityID` | UUID of the changed entity. |
| `userID` | Owner of the changed sync graph. |
| `updatedAt` | Entity update timestamp exposed through the sync protocol. |
| `payload` | Optional event payload or enough metadata to reconstruct the download change. |
| `createdAt` | Server timestamp when the event was recorded. |

The exact schema will be defined during implementation. This document defines the architecture, not the migration contents.

## Event Flow

```text
Client
  |
  | POST /api/v1/sync
  | changes: [project, scene, shot]
  v
SyncService
  |
  v
Entity Sync Handlers
  |
  | apply database mutation
  | create SyncEvent
  v
SyncEvent Log
  |
  | query events after lastSyncToken
  v
SyncDownloadCollector
  |
  | response changes + latest sequence token
  v
Client stores lastSyncToken
```

## Sequence-Based Incremental Sync

Given a client token:

```json
{
  "lastSyncToken": "42"
}
```

The backend interprets it as:

```text
lastSequence = 42
```

The download collector later queries:

```sql
SELECT *
FROM sync_events
WHERE user_id = current_user
  AND sequence > 42
ORDER BY sequence ASC;
```

The response returns changes derived from those events and a new token:

```json
{
  "syncToken": "57",
  "changes": []
}
```

The client then stores:

```text
lastSyncToken = "57"
```

## Client Token Storage

Clients should treat `syncToken` as opaque at the API boundary, even though M4.5 will initially encode it as a sequence string.

Client behavior:

- Store the latest successful `syncToken`.
- Send it as `lastSyncToken` on the next sync.
- Do not parse it for business logic.
- If no token exists, send `null`.

Example first sync:

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": null,
  "changes": []
}
```

Example later sync:

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": "57",
  "changes": []
}
```

## Upload Handler Responsibilities

When an upload handler applies a change, it should also create a sync event.

For `upsert`:

```text
1. Decode payload.
2. Verify ownership.
3. Create or update entity.
4. Create SyncEvent(entity, operation: upsert, entityID, userID, updatedAt).
```

For `delete`:

```text
1. Find entity.
2. Verify ownership.
3. Set deletedAt and updatedAt.
4. Create SyncEvent(entity, operation: delete, entityID, userID, updatedAt).
```

The entity mutation and `SyncEvent` creation should happen together as one durable operation where practical.

## Download Collector Behavior

The download collector has two modes.

Initial sync model:

```text
Download all active entities for user
```

Incremental sync model:

```text
Download only events where sequence > lastSyncToken
```

The collector can then convert events into `DownloadChange` values:

```text
SyncEvent(project, upsert, projectID) -> DownloadChange(project, upsert, project payload)
SyncEvent(scene, upsert, sceneID) -> DownloadChange(scene, upsert, scene payload)
SyncEvent(shot, delete, shotID) -> DownloadChange(shot, delete, nil payload)
```

## Expected Token Shape

M4.5 sync tokens should be returned as strings to preserve the existing API shape:

```json
{
  "syncToken": "57"
}
```

The value represents the latest per-user sync sequence known to the server when the response is produced.

Future token formats may become more structured while remaining opaque to clients:

```text
v1:57
```

or:

```text
seq:57
```

M4.5 should choose the simplest stable representation unless version tagging is needed during migration.

## Migration From Current UUID Tokens

Current token behavior:

```json
{
  "syncToken": "32AA79AD-58AF-41C8-AD30-A9EEFA85F0E8"
}
```

Target token behavior:

```json
{
  "syncToken": "57"
}
```

Migration plan:

1. Add `SyncEvent` persistence.
2. Start writing events for Project, Scene, and Shot mutations.
3. Return the latest known sequence as `syncToken`.
4. Accept `null` `lastSyncToken` as a full initial sync.
5. Treat invalid or old UUID-style `lastSyncToken` values as unsupported for incremental sync.
6. During development, clients can reset local sync state and request a fresh initial sync.

Production migration rules should be revisited before existing external clients depend on UUID tokens.

## Example

### Initial Upload

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": null,
  "changes": [
    {
      "entity": "project",
      "operation": "upsert",
      "id": "11111111-1111-1111-1111-111111111111",
      "updatedAt": "2026-06-25T15:00:00Z",
      "payload": {
        "title": "Synced Project",
        "notes": "Created through sync engine"
      }
    }
  ]
}
```

### Conceptual Event

```text
sequence: 58
entity: project
operation: upsert
entityID: 11111111-1111-1111-1111-111111111111
userID: current user
```

### Response

```json
{
  "success": true,
  "data": {
    "syncToken": "58",
    "serverTime": "2026-06-25T19:00:15Z",
    "changes": [
      {
        "entity": "project",
        "operation": "upsert",
        "id": "11111111-1111-1111-1111-111111111111",
        "updatedAt": "2026-06-25T15:00:00Z",
        "payload": {
          "title": "Synced Project",
          "notes": "Created through sync engine"
        }
      }
    ],
    "conflicts": []
  }
}
```

## Risks And Limitations

- A global event log can grow quickly and will need retention planning.
- Sequence generation is currently application-computed as latest sequence + 1, which is simple but less robust under concurrent writers than a PostgreSQL sequence or equivalent database-backed allocator.
- Event creation must not be skipped when entity writes succeed.
- Backfilling events for existing data may be needed for non-empty environments.
- Delete events require enough metadata for clients to apply tombstones.
- The first implementation may still need a full download path for `lastSyncToken: null`.
- Conflict handling should not expand beyond the M4.5 Last Write Wins scope.

## M4.5 Implementation Phases

### Phase 1 — Documentation

Document the hardening milestone and persistent token architecture.

### Phase 2 — Developer Test Scripts

Create reusable scripts for login, upload sync, download sync, and smoke testing.

### Phase 3 — Persistent Sync Tokens

Add the persistent event model, migration, and token generation behavior.

### Phase 4 — Incremental Downloads

Update download collection to use `SyncEvents` and `lastSyncToken`.

### Phase 5 — Conflict Handling

Formalize Last Write Wins behavior and conflict reporting boundaries.

### Phase 6 — Integration Tests

Cover Project, Scene, and Shot upload/download flows with persistent tokens.

### Phase 7 — Final Validation And Tag

Run smoke tests, integration tests, documentation review, and tag `M4.5-Production-Hardening`.
