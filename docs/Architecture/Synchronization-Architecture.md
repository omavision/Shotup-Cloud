# Synchronization Architecture

> Offline-first synchronization architecture for Shotup Cloud.

---

# Overview

Synchronization is the core capability of Shotup Cloud.

Unlike traditional cloud applications, Shotup treats the **local SQLite database as the primary source of truth**.

Cloud synchronization exists to distribute changes between trusted devices while preserving a fast, reliable offline workflow.

The user should never have to think about synchronization.

It simply happens.

---

# Design Goals

The synchronization engine is designed to satisfy six primary goals.

- Offline First
- Automatic Synchronization
- Conflict Awareness
- Efficient Network Usage
- Secure Data Transfer
- Future Multi-Device Collaboration

---

# Philosophy

Traditional applications often work like this:

```
Client

↓

REST API

↓

Database
```

Every action depends on an active network connection.

Shotup intentionally uses a different model.

```
SQLite

↓

Local Changes

↓

Synchronization

↓

Cloud

↓

Other Devices
```

The application is fully usable without connectivity.

Synchronization is asynchronous.

---

# Source of Truth

The source of truth always exists on the device.

```
Shotup

SQLite

↓

User edits

↓

Sync Queue

↓

Cloud
```

The cloud never becomes a blocking dependency.

---

# High-Level Architecture

```
                 Shotup Device

            ┌────────────────────┐
            │     SQLite DB      │
            └─────────┬──────────┘
                      │
               Local Change Log
                      │
                      ▼
             Synchronization Engine
                      │
               HTTPS + JWT
                      │
──────────────────────────────────────────────
                      │
                      ▼
               Shotup Cloud API
                      │
             Synchronization Service
                      │
            PostgreSQL Metadata Store
```

---

# Synchronization Model

Synchronization is based on **changes**, not entire databases.

Instead of sending every project:

```
Project

Scene

Shot

Shot

Shot
```

Only modified records are transferred.

Example

```
Scene Updated

↓

Upload Scene

↓

Done
```

---

# Delta Synchronization

The server returns only data changed since the client's last successful sync.

```
Last Sync

↓

Server compares timestamps

↓

Return differences only
```

Advantages

- Fast
- Small payloads
- Battery efficient

---

# Change Tracking

Every synchronized entity contains metadata.

Example

```
id

updatedAt

deletedAt

syncVersion

deviceID
```

This allows the server to identify changes.

---

# Synchronization Cycle

```
User edits Project

↓

SQLite updated

↓

Record added to Sync Queue

↓

Network available

↓

Upload Changes

↓

Server applies changes

↓

Server returns remote changes

↓

SQLite updated

↓

Sync Complete
```

---

# Conflict Detection

Conflicts occur when two devices modify the same object.

Example

```
Device A

↓

Edit Scene

────────────

Device B

↓

Edit Scene
```

Both synchronize later.

---

# Conflict Strategy

Default strategy

**Last Write Wins**

Future options

- Merge notes
- Manual resolution
- Version history

The strategy can evolve without changing the synchronization protocol.

---

# Deleted Records

Deleted objects are not removed immediately.

Instead

```
deletedAt

!= nil
```

The server distributes deletion events.

Eventually records can be permanently removed.

---

# Synchronization Queue

Every local change enters a queue.

```
Create

↓

Update

↓

Delete

↓

Upload
```

Benefits

- Retry failed requests
- Resume after crash
- Preserve ordering

---

# Batch Synchronization

Multiple operations are uploaded together.

Instead of

```
100 HTTP Requests
```

Shotup sends

```
1 Synchronization Request
```

Advantages

- Less latency
- Lower battery usage
- Better throughput

---

# Media Synchronization

Metadata and media are synchronized independently.

Metadata

```
SQLite

↓

Sync
```

Media

```
Photo

↓

Cloudflare R2

↓

Metadata references file
```

This keeps synchronization lightweight.

---

# Authentication

Every synchronization request requires

```
Authorization

Bearer JWT
```

Refresh tokens renew authentication automatically.

---

# Compression

Future versions may compress synchronization payloads.

Candidate

```
gzip
```

This reduces bandwidth usage.

---

# Background Synchronization

Future versions will support

- BackgroundTasks
- Push-triggered sync
- Periodic sync

Users should not need to manually synchronize.

---

# Error Recovery

If synchronization fails

```
Retry

↓

Resume

↓

Continue
```

The local database is never discarded.

---

# Security

Synchronization uses

- HTTPS
- JWT Authentication
- Ownership Verification
- Server-side Validation

Every uploaded record is verified.

---

# Future Collaboration

Current ownership

```
User

↓

Project
```

Future

```
Team

↓

Project

↓

Permissions

↓

Synchronization
```

The synchronization protocol is designed to support collaboration without redesign.

---

# Scalability

The protocol should support

- Thousands of projects
- Hundreds of thousands of shots
- Millions of metadata records

Synchronization remains incremental regardless of project size.

---

# Synchronization Principles

Synchronization must always be

- Safe
- Idempotent
- Incremental
- Restartable
- Deterministic

Running synchronization twice should never duplicate data.

---

# Planned API

```
POST /api/v1/sync

GET /api/v1/sync/status
```

Future

```
POST /api/v1/media/upload

POST /api/v1/media/complete
```

---

# Future Enhancements

Planned

- Selective synchronization
- Team synchronization
- Live collaboration
- Background push sync
- Synchronization metrics
- Sync diagnostics
- Conflict history
- Device management

---

# Summary

Shotup Cloud synchronization is designed around one central idea:

> **The device owns the data. The cloud distributes it.**

This architecture ensures that filmmakers can continue working anywhere, regardless of connectivity, while keeping every authorized device synchronized automatically and efficiently.