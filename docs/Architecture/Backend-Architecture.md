# Backend Architecture

> Internal architecture of the Shotup Cloud backend.

---

# Purpose

Shotup Cloud is implemented as a modular backend using Swift 6, Vapor and Fluent.

The architecture prioritizes:

- readability
- maintainability
- scalability
- testability
- clear separation of concerns

Every feature follows the same structure, making the codebase predictable as it grows.

---

# Design Principles

The backend follows several architectural principles.

## Feature Based

Code is grouped by business feature instead of technical layer.

Instead of folders like:

```
Controllers/
Models/
Services/
Repositories/
```

Shotup groups related files together.

Example:

```
Authentication/

Projects/

Scenes/

Users/

Shots/
```

This keeps every feature self-contained.

---

## Separation of Responsibilities

Every layer has a single responsibility.

```
HTTP Request

↓

Controller

↓

Service

↓

Repository

↓

Database
```

No layer should perform the work of another layer.

---

# Folder Structure

```
Sources/api/

Application/
    configure.swift
    routes.swift

Features/

Authentication/
Projects/
Scenes/
Shots/
Users/

Shared/

Database/

Middleware/
```

---

# Feature Structure

Every feature follows the same layout.

Example:

```
Projects/

Controllers/
DTO/
Models/
Repositories/
Services/
Migrations/
```

---

# Controllers

Controllers are responsible only for HTTP.

Responsibilities

- decode requests
- call services
- return responses
- map errors

Controllers never contain business logic.

Example

```
POST /projects

↓

decode CreateProjectRequest

↓

ProjectService

↓

return ProjectDTO
```

---

# Services

Services contain business logic.

Examples

- create project
- rotate refresh token
- verify ownership
- synchronize changes

Services coordinate repositories.

Services never perform SQL queries directly.

---

# Repositories

Repositories isolate database access.

Responsibilities

- queries
- filtering
- persistence
- pagination

Repositories know Fluent.

Services do not.

---

# DTOs

DTO = Data Transfer Object

DTOs isolate the API from database models.

Request DTO

```
CreateProjectRequest
```

Response DTO

```
ProjectDTO
```

Benefits

- stable API
- hidden database fields
- easier versioning

---

# Models

Models represent database tables.

Examples

```
User

Project

Scene

Shot

RefreshToken
```

Models should not contain business workflows.

---

# Migrations

Every schema change is implemented through Fluent migrations.

Examples

```
CreateUser

CreateProject

CreateScene

CreateShot

CreateRefreshToken
```

Migrations are immutable.

Existing migrations should never be modified after deployment.

---

# Middleware

Middleware processes requests before controllers.

Current middleware

- JWT Authentication

Future middleware

- Rate limiting
- Logging
- Metrics
- Request IDs
- CORS
- Compression

---

# Dependency Flow

Dependencies move only downward.

```
Controller

↓

Service

↓

Repository

↓

Database
```

Repositories never call Services.

Controllers never query the database directly.

---

# Request Lifecycle

Example

```
POST /projects

↓

JWT Middleware

↓

Controller

↓

Service

↓

Repository

↓

PostgreSQL

↓

Repository

↓

Service

↓

DTO

↓

HTTP Response
```

Every request follows this flow.

---

# Authentication

Authentication is centralized.

```
Sign in with Apple

↓

Apple JWT

↓

Shotup JWT

↓

Protected Routes
```

Business features never verify Apple tokens directly.

---

# Error Handling

Errors are returned using consistent API responses.

Example

```
{
    "success": false,
    "error": {
        "code": "project_not_found",
        "message": "Project not found."
    }
}
```

Future versions will standardize all error codes.

---

# Database Access

Only repositories communicate with Fluent.

Example

```
ProjectRepository

↓

Fluent Query

↓

PostgreSQL
```

This keeps business logic database-independent.

---

# Concurrency

Shotup Cloud uses Swift structured concurrency.

Guidelines

- async/await
- Sendable types
- no blocking operations
- actor isolation where appropriate

Future work will introduce background jobs using Swift concurrency.

---

# Security

Security is enforced in multiple layers.

```
HTTPS

↓

JWT Validation

↓

Ownership Verification

↓

Business Rules

↓

Database
```

No feature trusts client-provided identifiers without authorization.

---

# API Versioning

All endpoints are versioned.

Current

```
/api/v1/
```

Future versions will introduce

```
/api/v2/
```

without breaking existing clients.

---

# Scalability

The architecture supports horizontal scaling.

Stateless components include

- JWT authentication
- Controllers
- Services

Shared state resides only in PostgreSQL and object storage.

---

# Testing Strategy

Unit Tests

- Services
- Repositories

Integration Tests

- HTTP endpoints
- Authentication
- Synchronization

Future

- Load testing
- Performance benchmarks
- End-to-end synchronization tests

---

# Adding a New Feature

Recommended workflow

1. Create Feature folder

2. Create Model

3. Create Migration

4. Create Repository

5. Create Service

6. Create DTOs

7. Create Controller

8. Register Routes

9. Add Tests

10. Update Documentation

Every feature should follow the same architecture.

---

# Architectural Goals

The backend should remain

- predictable
- modular
- secure
- testable
- scalable

New features should integrate naturally without changing the existing architecture.

---

# Summary

The Shotup Cloud backend follows a feature-based architecture with clear separation between HTTP handling, business logic and persistence.

This approach keeps the project easy to understand today while providing a strong foundation for future capabilities such as synchronization, media storage, collaboration and AI services.