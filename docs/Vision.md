# Shotup Cloud Vision

> Empower filmmakers with a professional, offline-first cloud platform that extends the Shotup experience across devices without compromising speed, reliability, or creative workflow.

---

# Mission

Shotup Cloud exists to seamlessly synchronize filmmaking projects while respecting the realities of production.

Unlike many cloud applications that depend on constant Internet access, Shotup is designed around a different philosophy:

**The device is always the primary workspace.**

Cloud services enhance the experience rather than becoming a dependency.

A cinematographer should be able to work the entire shooting day without network connectivity and synchronize everything later with complete confidence.

---

# Product Philosophy

Shotup Cloud is built around five core principles.

## 1. Offline First

Every device contains a complete local SQLite database.

Users can:

- create projects
- edit scenes
- capture references
- organize shots
- review metadata

without any network connection.

Synchronization happens only when connectivity is available.

---

## 2. Cloud as an Extension

The cloud is not the primary source of truth.

Instead it provides:

- synchronization
- backup
- collaboration
- media storage
- web access

The creative workflow never depends on the cloud.

---

## 3. Native Apple Experience

Shotup Cloud embraces Apple technologies wherever appropriate.

Examples include:

- Sign in with Apple
- Swift
- Vapor
- Swift Concurrency
- Secure Keychain storage
- Background synchronization
- APNs (future)

The goal is a backend that feels as native as the client applications.

---

## 4. Security by Design

Security is considered a product feature.

Authentication relies on:

- Sign in with Apple
- JWT access tokens
- Refresh token rotation
- Apple public key verification
- HTTPS communication
- Secure device sessions

Sensitive user information is minimized whenever possible.

---

## 5. Built for Professionals

Shotup is not designed for casual photography.

It is built specifically for:

- Cinematographers
- Directors
- Camera Operators
- Assistant Camera
- Gaffers
- Film Students
- Production Teams

Every engineering decision should support professional filmmaking workflows.

---

# Long-Term Vision

Shotup Cloud will evolve beyond simple synchronization.

Future capabilities include:

## Collaboration

- Shared productions
- Team workspaces
- Roles
- Permissions

---

## Media

- Secure media storage
- Thumbnail generation
- Proxy workflows
- Cloud backup

---

## Web Platform

Access projects through a browser.

Examples:

- Shot browser
- Storyboard review
- Camera reports
- Production planning

---

## AI

Future AI services may include:

- Shot search
- Automatic metadata enrichment
- Reference organization
- Lighting analysis
- Relighting experiments
- Visual similarity search

AI should support filmmakers without replacing creative decisions.

---

# Architectural Principles

Shotup Cloud follows several long-term architectural principles.

## Modular

Each feature is developed independently.

Examples:

- Authentication
- Projects
- Scenes
- Synchronization
- Media

---

## Scalable

Every component should support horizontal scaling.

Examples:

- Stateless authentication
- PostgreSQL
- Cloud object storage
- Background jobs

---

## Maintainable

The project prioritizes:

- Feature-based architecture
- Clear separation of concerns
- Small services
- Repository pattern
- Documentation
- Architecture Decision Records

---

# Success Criteria

Shotup Cloud succeeds when users no longer think about synchronization.

Projects simply appear everywhere they are needed.

The technology should remain invisible, allowing filmmakers to focus entirely on storytelling.

---

# Guiding Principle

> Think before you shoot.
>
> Synchronize without thinking.

This philosophy guides every technical decision made within Shotup Cloud.