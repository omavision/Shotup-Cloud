# Sync Protocol v1

## Purpose

Sync Protocol v1 defines the client-server contract used by Shotup Cloud to exchange local changes from authenticated devices and return the current server-side state needed by those devices.

The protocol is designed for offline-capable clients. A client uploads a batch of changes, the backend applies each supported change through entity-specific sync handlers, and the backend returns downloadable changes plus conflict metadata.

This document describes the M4.5 protocol contract as implemented by the Vapor backend. It is an architecture document only; database schema, authentication behavior, and source implementation are defined elsewhere.

## Status

M4.5 currently supports synchronization for:

- `project`
- `scene`
- `shot`

Planned synchronization entities:

- `media`

Additional future enum cases already reserved in code include:

- `cameraSetup`
- `lensSetup`

## Authentication

All sync requests require an authenticated user.

Clients must call the sync endpoint with a valid bearer access token. The backend resolves the authenticated user from JWT authentication before decoding and applying the sync request.

The sync protocol does not define anonymous synchronization.

## Endpoint

Current sync requests are sent to:

```http
POST /api/v1/sync
Authorization: Bearer <access-token>
Content-Type: application/json
```

## SyncRequest

`SyncRequest` is the client upload envelope.

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": null,
  "changes": []
}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `deviceID` | `String` | Yes | Stable client device identifier used for sync observability and future device-specific sync behavior. |
| `lastSyncToken` | `String?` | No | Last server-issued sync token known to the client. When present, it is parsed as the last observed `sync_events.sequence` and used for incremental downloads. |
| `changes` | `[SyncChange]` | Yes | Client-side changes to apply before collecting server changes. May be empty. |

## SyncChange

`SyncChange` represents one client-originated entity mutation.

```json
{
  "entity": "scene",
  "operation": "upsert",
  "id": "22222222-2222-2222-2222-222222222222",
  "updatedAt": "2026-06-25T16:00:00Z",
  "payload": {
    "projectID": "11111111-1111-1111-1111-111111111111",
    "title": "Opening Scene",
    "notes": "Opening sequence",
    "sortOrder": "1"
  }
}
```

Fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `entity` | `SyncEntity` | Yes | Entity type being changed. |
| `operation` | `SyncOperation` | Yes | Mutation type. |
| `id` | `UUID` | Yes | Stable client/server entity identifier. Used for idempotent retries. |
| `updatedAt` | `Date` | Yes | Client-provided update timestamp for the change. |
| `payload` | `[String:String]?` | Required for `upsert`; optional for `delete` | Entity-specific payload encoded as string key-value pairs in the current protocol. |

## SyncResponse

`SyncResponse` is returned inside the standard API response envelope.

```json
{
  "success": true,
  "data": {
    "syncToken": "57",
    "serverTime": "2026-06-25T19:00:15Z",
    "changes": [],
    "conflicts": []
  }
}
```

Fields:

| Field | Type | Description |
| --- | --- | --- |
| `syncToken` | `String` | Server-issued token for the completed sync response. Currently the latest per-user `SyncEvent.sequence` encoded as a string. |
| `serverTime` | `Date` | Server timestamp when the response was created. |
| `changes` | `[DownloadChange]` | Server-originated changes visible to the authenticated user. |
| `conflicts` | `[SyncConflict]` | Changes that could not be applied or require client awareness. |

## DownloadChange

`DownloadChange` represents one server-originated entity state returned to the client.

Fields:

| Field | Type | Description |
| --- | --- | --- |
| `entity` | `SyncEntity` | Entity type returned to the client. |
| `operation` | `SyncOperation` | Operation the client should apply locally. Incremental downloads may return `upsert` changes or `delete` tombstones. |
| `id` | `UUID` | Stable entity identifier. |
| `updatedAt` | `Date` | Server-side entity update timestamp. |
| `payload` | `[String:String]?` | Entity-specific string key-value payload. |

## SyncEntity

Current enum values:

| Value | Status | Notes |
| --- | --- | --- |
| `project` | Supported | Handled by `ProjectSyncHandler`; returned by the download collector. |
| `scene` | Supported | Handled by `SceneSyncHandler`; returned by the download collector. |
| `shot` | Supported | Handled by `ShotSyncHandler`; returned by the download collector. |
| `media` | Planned | Reserved for later media sync work. |
| `cameraSetup` | Future | Reserved for later production metadata sync. |
| `lensSetup` | Future | Reserved for later production metadata sync. |

Unsupported entities return a sync conflict with reason `Unsupported entity`.

## SyncOperation

Current enum values:

| Value | Description |
| --- | --- |
| `upsert` | Create the entity if missing, or update the existing entity if it belongs to the authenticated user. |
| `delete` | Soft-delete the existing entity if it belongs to the authenticated user. |

## Payload Conventions

Payloads are entity-specific.

Current temporary limitation:

- `payload` is still modeled as `[String:String]?`.
- All payload values must be encoded as strings, including numeric values.
- Example: `sortOrder` must be sent as `"1"`, not `1`.

This preserves the current protocol compatibility while M4.5 validates behavior across entities.

Future direction:

- Replace string-only payload dictionaries with true typed JSON payloads.
- Allow numeric, boolean, object, and array values where appropriate.
- Keep entity-specific DTOs at the sync handler boundary.
- Version the protocol before introducing any breaking payload shape changes.

### Project Payload

Current project upload payload fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `title` | `String` | Yes | Project title. |
| `notes` | `String?` | No | Optional project notes. |

### Scene Payload

Current scene upload payload fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `projectID` | `String` | Yes | Parent project UUID as a string. |
| `title` | `String` | Yes | Scene title. |
| `notes` | `String?` | No | Optional scene notes. |
| `sortOrder` | `String` | Yes | Scene order encoded as a string integer. |

## Idempotency Rules

Clients must use stable UUIDs for all synced entities.

`upsert` is idempotent by entity `id`:

- If the entity exists and belongs to the authenticated user, it is updated.
- If the entity does not exist, it is created.
- Replaying the same `upsert` with the same `id` should not create duplicates.

`delete` is idempotent:

- If the entity does not exist, the backend treats the delete as already satisfied.
- If the entity exists and belongs to the authenticated user, the backend marks it deleted.

Ownership is enforced through the authenticated user and the entity's project/user relationship.

## Soft Delete Rules

Deletes use soft delete semantics.

For supported entities:

- `delete` sets `deletedAt` to the change timestamp.
- `delete` also updates `updatedAt` to the change timestamp.
- Full initial downloads exclude soft-deleted entities.
- Incremental downloads return delete events as tombstone `DownloadChange` values with `operation: "delete"` and `payload: null`.

The protocol continues to prefer soft deletes so clients can receive tombstones through incremental sync.

## Conflict Strategy

The initial conflict strategy is Last Write Wins.

Current behavior:

- Supported `upsert` changes overwrite mutable fields on the matching entity.
- `updatedAt` is set from the incoming change timestamp.
- If the existing server row has a newer `updatedAt`, the change returns a conflict instead of overwriting server state.
- Unsupported entities are reported in `conflicts`.
- The current implementation does not perform field-level merging.

Future conflict handling may add:

- Per-field conflict metadata.
- Client-visible resolution options.
- Tombstone conflict behavior for deletes.

## Sync Tokens And Incremental Downloads

`lastSyncToken` and `syncToken` are part of the v1 contract and are backed by `sync_events.sequence`.

Current behavior:

- Clients may send `lastSyncToken` as the previous `syncToken` value.
- If `lastSyncToken` is `null`, the download collector returns all non-deleted supported entities visible to the authenticated user.
- If `lastSyncToken` is present, it must parse as an integer sequence.
- Incremental downloads query `sync_events` for the authenticated user where `sequence > lastSyncToken`, ordered by ascending sequence.
- Incremental delete events return tombstone `DownloadChange` values.
- The backend returns the latest per-user `SyncEvent.sequence` as `syncToken`, encoded as a string.

Roadmap:

- Make sync tokens opaque to clients.
- Consider a future token format with explicit versioning if the cursor representation changes.
- Preserve backward compatibility within v1 where possible.

## Versioning Rules

Sync Protocol v1 is tied to the `/api/v1` API namespace.

Within v1:

- Additive fields may be introduced when clients can safely ignore them.
- New entity types may be added when handlers and download payloads are implemented.
- Existing field meanings should not change.
- Existing enum values should not be renamed.
- Breaking payload changes require a new protocol version or an explicit compatibility strategy.

Typed JSON payloads are considered a breaking protocol change unless introduced through a compatible migration path.

## Examples

### Project Upload

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

### Scene Upload

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": null,
  "changes": [
    {
      "entity": "scene",
      "operation": "upsert",
      "id": "22222222-2222-2222-2222-222222222222",
      "updatedAt": "2026-06-25T16:00:00Z",
      "payload": {
        "projectID": "11111111-1111-1111-1111-111111111111",
        "title": "Opening Scene",
        "notes": "Opening sequence",
        "sortOrder": "1"
      }
    }
  ]
}
```

### Shot Upload

```json
{
  "deviceID": "iphone-dev-001",
  "lastSyncToken": null,
  "changes": [
    {
      "entity": "shot",
      "operation": "upsert",
      "id": "33333333-3333-3333-3333-333333333333",
      "updatedAt": "2026-06-25T17:00:00Z",
      "payload": {
        "sceneID": "22222222-2222-2222-2222-222222222222",
        "title": "Wide Shot",
        "notes": "Establishing frame",
        "shotSize": "wide",
        "cameraMovement": "static",
        "lensMM": "35",
        "sortOrder": "1"
      }
    }
  ]
}
```

### Sync Response

```json
{
  "success": true,
  "data": {
    "syncToken": "57",
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
      },
      {
        "entity": "scene",
        "operation": "upsert",
        "id": "22222222-2222-2222-2222-222222222222",
        "updatedAt": "2026-06-25T16:00:00Z",
        "payload": {
          "projectID": "11111111-1111-1111-1111-111111111111",
          "title": "Opening Scene",
          "notes": "Opening sequence",
          "sortOrder": "1"
        }
      },
      {
        "entity": "shot",
        "operation": "upsert",
        "id": "33333333-3333-3333-3333-333333333333",
        "updatedAt": "2026-06-25T17:00:00Z",
        "payload": {
          "sceneID": "22222222-2222-2222-2222-222222222222",
          "title": "Wide Shot",
          "notes": "Establishing frame",
          "shotSize": "wide",
          "cameraMovement": "static",
          "lensMM": "35.0",
          "sortOrder": "1"
        }
      },
      {
        "entity": "shot",
        "operation": "delete",
        "id": "44444444-4444-4444-4444-444444444444",
        "updatedAt": "2026-06-25T18:00:00Z",
        "payload": null
      }
    ],
    "conflicts": []
  }
}
```

## Known Limitations

- Payload values are string-only.
- `lastSyncToken` must currently be an integer sequence string when provided.
- Initial downloads still return all non-deleted supported entities for the authenticated user.
- Conflict handling is coarse and does not include field-level merge data.
- `media`, `cameraSetup`, and `lensSetup` are not synchronized in the current handler registry.
- Sequence allocation is part of the backend contract, but clients should still treat tokens as opaque strings.

## Future Work

Potential follow-up work:

- Add Media synchronization.
- Move from `[String:String]` payloads to typed JSON payloads through a versioned compatibility path.
- Expand conflict detection beyond the initial Last Write Wins strategy.
- Add integration tests for more protocol edge cases.
