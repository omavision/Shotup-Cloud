# M2 — Authenticated API

## Goal

Convert Shotup Cloud from an open development API into a JWT-authenticated backend with protected user resources.

## Completed

* JWT dependency added
* JWT access token generation
* JWT middleware
* `/api/v1/me` endpoint
* Protected API route group
* Authenticated project creation
* Authenticated project listing
* Project ownership verification
* Scenes converted to nested project routes
* M2 Git tag created: `M2-Authenticated-API`

## API Changes

### Before

```http
GET /api/v1/projects?userID=...
POST /api/v1/projects
```

### After

```http
GET /api/v1/projects
POST /api/v1/projects
Authorization: Bearer <accessToken>
```

Scenes now follow the project hierarchy:

```http
GET /api/v1/projects/:projectID/scenes
POST /api/v1/projects/:projectID/scenes
```

## Security Improvements

The client no longer sends `userID` in project requests. The backend derives the authenticated user from the JWT payload.

Project access is verified through ownership checks before child resources are accessed.

## Out of Scope

* Production Apple Sign In
* Refresh token rotation
* SQLite sync engine
* Media upload
* Cloudflare R2 storage

## Status

Completed.
