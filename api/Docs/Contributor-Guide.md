# Contributor Guide

## Purpose

This guide explains how developers should contribute to the Shotup Cloud backend safely and consistently.

## 1. Overview

Shotup Cloud is a Swift/Vapor backend for metadata sync, media upload/download, authentication, and cloud media reconciliation.

Core technologies and patterns:

- Vapor backend.
- Swift and Swift concurrency.
- Fluent with PostgreSQL.
- Cloudflare R2 for media object storage.
- `APIResponse` wrapper for successful JSON responses.
- JWT Bearer authentication for protected routes.

Contributors should keep changes small, tested, and aligned with the current feature/service/repository structure.

## 2. Repository Structure

Key backend folders:

- `Sources/api/API`
  - Shared API DTOs, currently including media request and response contracts.
- `Sources/api/Features`
  - Feature modules such as Authentication, Media, Projects, Scenes, Shots, Sync, Users, and Health.
- `Sources/api/Infrastructure`
  - Infrastructure integrations such as Cloudflare R2 configuration, object key building, and storage services.
- `Tests/apiTests`
  - Backend unit and integration tests.
- `Architecture`
  - Architecture and milestone design documentation.
- `Docs`
  - Developer-facing setup, deployment, environment, and usage documentation.

## 3. Branching Workflow

Recommended workflow:

- Create feature branches for non-trivial work.
- Use descriptive branch names, such as `feature/media-batch-exists` or `fix/sync-dependency-order`.
- Make descriptive commits.
- Avoid direct commits to `develop` or `main`.
- Push the branch and open a pull request when ready.
- Keep pull requests focused on one behavior or one documentation change when practical.

These are recommended practices unless the project later formalizes a different branching policy.

## 4. Coding Standards

General standards:

- Prefer clear Swift code over clever abstractions.
- Use Swift concurrency safely.
- Mark DTOs `Sendable` where appropriate, especially for API request/response types used across concurrency boundaries.
- Keep controllers thin.
- Put business logic in services.
- Put persistence logic in repositories.
- Keep infrastructure integrations behind focused types.
- Do not put secrets in source code.
- Avoid force unwraps unless they are narrowly justified and safe by construction.
- Use explicit errors and meaningful HTTP status codes.

Current layering style:

- Controllers decode requests, require auth, call services, and encode responses.
- Services enforce business rules and authorization decisions.
- Repositories perform database persistence and queries.
- Infrastructure services integrate with external systems such as R2.

## 5. API Design Rules

API rules:

- Use the `/api/v1` base path.
- Use `APIResponse` for standard successful JSON responses.
- Put private routes behind JWT authentication.
- Check ownership for user data.
- Return meaningful HTTP status codes.
- Do not expose raw storage credentials.
- Keep request and response DTOs explicit.
- Preserve compatibility where possible.

Expected status code semantics:

- `400`: validation or malformed client input.
- `401`: authentication failure.
- `403`: authorization failure.
- `404`: missing resource or dependency.
- `409`: valid request but invalid current state.
- `5xx`: unexpected backend or infrastructure failure.

## 6. Database Rules

Database contribution rules:

- Schema changes require Fluent migrations.
- Migrations must be ordered after the tables they depend on.
- Avoid destructive migrations without a rollback and backup plan.
- Add tests for new models and repositories.
- Preserve ownership integrity through foreign keys and service-level checks.
- Prefer additive migrations for production safety.
- Do not manually depend on production data shape without documenting it.

When adding a new persisted feature:

- Add the model.
- Add the migration.
- Register the migration in `configure.swift`.
- Add repository or query tests.
- Add endpoint integration tests if the model is exposed through the API.

## 7. Media Pipeline Rules

Media pipeline rules:

- Never expose R2 credentials to iOS or API clients.
- Use presigned URLs for upload and download.
- `request-upload` creates or resets a `pending` `media_assets` record.
- `confirm-upload` verifies object existence and marks the record `uploaded`.
- `media/exists` is a database-only reconciliation endpoint.
- Download uses a presigned GET URL after backend authorization.
- Do not use `request-download` as a media existence probe.
- Preserve traceability with `X-Trace-ID` across upload request and confirm calls.

Backend components to understand before changing media behavior:

- `MediaController`
- `MediaService`
- `MediaRepository`
- `FluentMediaRepository`
- `R2StorageService`
- `R2ObjectKeyBuilder`

## 8. Testing

Recommended local validation:

```bash
swift build
swift test
```

Testing expectations:

- Add integration tests for new endpoints.
- Add repository tests for persistence behavior.
- Add contract tests for new request/response DTOs.
- Use fixture credentials, stubs, or test configuration for storage tests.
- Do not require real production credentials in tests.
- Cover ownership and unauthorized access paths for protected resources.
- Cover error cases, not only success paths.

When changing media upload/download:

- Test missing dependency behavior.
- Test unauthorized access.
- Test invalid MIME type.
- Test pending and uploaded states.
- Test R2 success/failure behavior through stubs or test services where possible.

## 9. Documentation Expectations

Update documentation when behavior changes:

- Update `Architecture` docs for design, lifecycle, schema, operations, or milestone changes.
- Update `Docs` for developer-facing setup, deployment, environment, and examples.
- Document new endpoints in API reference and examples.
- Update environment docs when new variables are added.
- Update deployment docs when runtime requirements change.

Documentation should distinguish existing behavior from proposed or future behavior.

## 10. Security Checklist

Before merging security-sensitive changes, verify:

- No secrets are committed.
- JWT is required for private routes.
- Ownership is checked for user data.
- Presigned URLs are short-lived.
- R2 credentials remain server-side only.
- Tokens, passwords, secrets, and presigned URLs are not logged.
- Error messages do not leak cross-user data.
- New endpoints have authorization tests.

## 11. Pull Request Checklist

Use this checklist before opening or merging a pull request:

- [ ] Build passes.
- [ ] Tests pass.
- [ ] Migrations included if needed.
- [ ] Migration order is correct.
- [ ] Docs updated if needed.
- [ ] API examples updated if endpoint behavior changed.
- [ ] No secrets committed.
- [ ] Logs are safe.
- [ ] Ownership and auth behavior validated.
- [ ] Error cases covered.
- [ ] Behavior validated manually if appropriate.

## 12. Release / Tagging

Recommended milestone tag examples:

- `backend-phase-7-cloud-sync-foundation`
- `backend-phase-7-cloud-sync-docs`

Tag naming style:

- Use lowercase.
- Use hyphen-separated words.
- Include the scope, phase or milestone, and concise outcome.
- Prefer stable milestone names over vague labels.

Example future tag shapes:

- `backend-phase-8-cloud-download`
- `backend-phase-8-multi-device-readiness`
- `backend-hotfix-media-confirm-upload`

Tagging policy is a recommendation until the project formalizes release management.

## 13. Future Contributor Notes

Areas likely to evolve:

- Production auth hardening.
- CI/CD.
- Deployment automation.
- Monitoring and alerting.
- Background reconciliation.
- Multi-device conflict handling.
- Collaboration and permissions.

Contributors working in these areas should update both architecture and developer docs as implementation details become concrete.
