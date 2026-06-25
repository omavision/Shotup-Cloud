# Shotup Cloud

> Secure, offline-first cloud synchronization for Shotup — the professional shot planning platform for filmmakers.

---

# Overview

Shotup Cloud is the backend platform powering the Shotup ecosystem.

It provides secure authentication, project synchronization, cloud storage, and future collaboration features while preserving Shotup's offline-first philosophy.

Unlike traditional cloud-first applications, Shotup is designed so that filmmakers can continue working even without an Internet connection. Every device maintains its own local SQLite database. Shotup Cloud synchronizes data between devices when connectivity becomes available.

The iPhone (and future iPad/macOS applications) always remain fully functional offline.

---

# Vision

Shotup Cloud exists to make filmmaking projects available everywhere without sacrificing reliability on set.

The local device is always the primary workspace.

The cloud provides synchronization, backup, collaboration, and media storage.

Our guiding principles are:

- Offline First
- Secure by Default
- Fast Synchronization
- Native Apple Experience
- Production Ready

---

# Architecture

```
                    Shotup Ecosystem

              ┌─────────────────────────┐
              │      Shotup iPhone      │
              │       SQLite DB         │
              └────────────┬────────────┘
                           │
                     HTTPS + JWT
                           │
              ┌────────────▼────────────┐
              │     Shotup Cloud API    │
              │        Vapor 4          │
              └────────────┬────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
┌────────▼─────────┐               ┌─────────▼─────────┐
│    PostgreSQL    │               │   Cloudflare R2   │
│ Metadata Storage │               │ Photos / Videos   │
└──────────────────┘               └───────────────────┘
                           │
              ┌────────────▼────────────┐
              │     Web Dashboard       │
              └─────────────────────────┘
```

---

# Core Features

## Authentication

- Sign in with Apple
- JWT Access Tokens
- Refresh Token Rotation
- Apple JWKS Verification
- Device Sessions
- Protected API Routes

---

## Project Synchronization

- Offline-first workflow
- SQLite synchronization
- Delta synchronization
- Conflict detection
- Automatic recovery
- Future multi-device support

---

## Media

Planned

- Cloudflare R2 storage
- Signed uploads
- Thumbnail generation
- Media metadata
- Secure downloads

---

## Collaboration

Planned

- Shared projects
- Team workspaces
- Roles
- Permissions
- Activity history

---

# Technology Stack

| Layer | Technology |
|--------|------------|
| Language | Swift 6 |
| Framework | Vapor 4 |
| ORM | Fluent |
| Database | PostgreSQL |
| Authentication | JWT + Sign in with Apple |
| Storage | Cloudflare R2 |
| Client | Shotup iOS |
| Synchronization | SQLite Delta Sync |

---

# Repository Structure

```
Shotup-Cloud/

api/
    Sources/
    Tests/

docs/
    Architecture/
    API/
    ADR/
    Milestones/

README.md
CHANGELOG.md
CONTRIBUTING.md
LICENSE
```

---

# Current Milestones

## Completed

### M1 — Foundation

- Vapor
- PostgreSQL
- Fluent
- Feature Architecture
- Environment Configuration

---

### M2 — Authenticated API

- JWT
- Protected Routes
- Project Ownership
- Authenticated Endpoints

---

### M3 — Production Authentication

- Refresh Tokens
- Rotation
- Apple Sign In
- Apple JWKS
- Audience Validation

---

## Current Development

### M4 — SQLite Synchronization Engine

In Progress

Goals

- Delta Synchronization
- Conflict Resolution
- Offline-first Sync
- Media Awareness

---

# Development

Clone the repository

```bash
git clone https://github.com/<your-org>/Shotup-Cloud.git
```

Install dependencies

```bash
swift package resolve
```

Run

```bash
swift run api serve
```

---

# Environment

Create

```
.env.development
```

Required values

```
APP_ENV
DATABASE_HOST
DATABASE_PORT
DATABASE_NAME
DATABASE_USERNAME
DATABASE_PASSWORD
JWT_SECRET
APPLE_BUNDLE_ID
```

---

# Documentation

Additional documentation can be found inside the `docs` directory.

## Architecture

- Roadmap
- System Overview
- Backend Architecture
- Authentication
- Synchronization

## API

- Authentication
- Projects
- Scenes
- Sync
- Errors

## ADR

Architecture Decision Records documenting major technical decisions.

## Milestones

Project development history from M1 onward.

---

# Design Principles

## Offline First

The local SQLite database is the source of truth.

Cloud synchronization augments—not replaces—the local workflow.

---

## Security

- Short-lived JWTs
- Refresh Token Rotation
- Apple Identity Verification
- HTTPS Only
- Secure Passwordless Authentication

---

## Scalability

The backend is designed around feature modules, making it easy to expand with future services without major architectural changes.

---

# Roadmap

- ✅ Foundation
- ✅ Authenticated API
- ✅ Production Authentication
- 🚧 SQLite Synchronization
- ⏳ Media Storage
- ⏳ Web Dashboard
- ⏳ Collaboration
- ⏳ AI Services
- ⏳ Production Deployment

---

# License

Copyright © Still Colors LLC.

All rights reserved.

---

# About

Shotup Cloud is part of the Shotup ecosystem, a professional filmmaking platform focused on shot planning, camera metadata, synchronization, and collaboration for cinematographers, directors, and production teams.