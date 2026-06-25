# Shotup Cloud System Overview

> High-level architecture of the Shotup ecosystem.

---

# Overview

Shotup Cloud provides secure synchronization, authentication, media storage, and collaboration services for the Shotup family of applications.

The system is designed around one core principle:

> **The local device is always the source of truth.**

Every client maintains its own SQLite database.

Cloud services synchronize changes between devices while allowing the application to remain fully functional offline.

---

# Ecosystem

```
                        Shotup Ecosystem

 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │                     Shotup Applications                     │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘
                │                    │
                │                    │
      ┌─────────▼────────┐  ┌────────▼────────┐
      │  Shotup iPhone   │  │  Shotup iPad    │
      │                  │  │                 │
      │     SQLite       │  │     SQLite      │
      └─────────┬────────┘  └────────┬────────┘
                │                    │
                └──────────┬─────────┘
                           │
                    HTTPS + JWT
                           │
                ┌──────────▼──────────┐
                │   Shotup Cloud API   │
                │       Vapor          │
                └───────┬───────┬─────┘
                        │       │
          ┌─────────────┘       └──────────────┐
          │                                    │
 ┌────────▼────────┐                 ┌─────────▼─────────┐
 │   PostgreSQL    │                 │  Cloudflare R2    │
 │                 │                 │                   │
 │ Metadata Store  │                 │ Photos / Videos   │
 └────────┬────────┘                 └─────────┬─────────┘
          │                                    │
          └──────────────────┬─────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Web Dashboard  │
                    │     (Future)    │
                    └─────────────────┘
```

---

# Components

## Shotup Client

Responsibilities

- Project creation
- Scene management
- Shot planning
- Camera metadata
- Local SQLite database
- Offline operation

The client never depends on continuous Internet connectivity.

---

## SQLite Database

SQLite stores:

- Users
- Projects
- Scenes
- Shots
- Camera setups
- Lens setups
- Metadata
- Sync state

SQLite is considered the primary working database.

---

## Synchronization Layer

Responsibilities

- Upload local changes
- Download remote changes
- Resolve conflicts
- Track synchronization state

Synchronization is incremental.

Only changed records are transferred.

---

## Shotup Cloud API

Responsibilities

- Authentication
- Authorization
- Synchronization
- Project management
- Media management
- Collaboration

The backend is implemented using:

- Swift 6
- Vapor
- Fluent
- PostgreSQL

---

## PostgreSQL

Stores structured metadata.

Examples

- Users
- Projects
- Scenes
- Shots
- Refresh Tokens
- Sync Metadata

Binary media is never stored in PostgreSQL.

---

## Cloudflare R2

Stores

- Photos
- Videos
- Generated thumbnails
- Future AI assets

Large media is uploaded directly using signed URLs.

---

## Web Dashboard

Future web application.

Capabilities

- Browse projects
- Review shots
- Search metadata
- Download reports
- Team collaboration

---

# Authentication

Authentication uses:

```
Sign in with Apple
        │
        ▼
Identity Token
        │
        ▼
Shotup Cloud
        │
Apple Verification
        │
        ▼
JWT Access Token
        │
        ▼
Protected API
```

Authentication is stateless.

---

# Synchronization Flow

```
SQLite

↓

Local Changes

↓

Synchronization API

↓

Cloud

↓

Server Changes

↓

SQLite Updated
```

Only differences are transmitted.

---

# Media Flow

```
Capture

↓

SQLite Metadata

↓

R2 Upload

↓

Signed URL

↓

Cloud Reference

↓

Other Devices
```

Media and metadata are synchronized independently.

---

# Security Model

Every request passes through:

```
HTTPS

↓

JWT Validation

↓

Authorization

↓

Ownership Verification

↓

Business Logic
```

Every project belongs to one authenticated user.

Future collaboration will extend ownership into team permissions.

---

# Technology Stack

| Layer | Technology |
|--------|------------|
| Language | Swift 6 |
| Backend | Vapor |
| Database | PostgreSQL |
| ORM | Fluent |
| Auth | JWT |
| Identity | Sign in with Apple |
| Storage | Cloudflare R2 |
| Local DB | SQLite |
| Sync | Delta Synchronization |

---

# Design Goals

The architecture prioritizes:

- Offline-first workflow
- Security
- Simplicity
- Maintainability
- Scalability
- Native Apple technologies

Every component should remain independently replaceable while preserving clear interfaces.

---

# Current Status

| Milestone | Status |
|------------|--------|
| M1 Foundation | ✅ |
| M2 Authenticated API | ✅ |
| M3 Production Authentication | ✅ |
| M4 SQLite Synchronization | 🚧 |
| M5 Media Storage | Planned |
| M6 Web Dashboard | Planned |

---

# Summary

Shotup Cloud is designed as a modern, secure, and scalable backend that complements—not replaces—the local filmmaking workflow.

The local device remains the creative workspace.

The cloud extends that workspace across devices, users, and future collaboration features.