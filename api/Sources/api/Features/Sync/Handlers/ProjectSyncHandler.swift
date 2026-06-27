import Fluent
import Foundation
import Vapor

struct ProjectSyncHandler: SyncHandler {
    let database: any Database

    func canHandle(_ entity: SyncEntity) -> Bool {
        entity == .project
    }

    func apply(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict? {
        switch change.operation {
        case .upsert:
            return try await upsert(change: change, user: user)

        case .delete:
            return try await delete(change: change, user: user)
        }
    }

    private func upsert(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict? {
        let payload = try change.decodePayload(ProjectPayload.self)
        let title = payload.title
        let notes = payload.notes
        let deletedAt = try parseDeletedAt(payload.deletedAt)

        if let existing = try await Project.query(on: database)
            .filter(\.$id == change.id)
            .filter(\.$user.$id == user.id)
            .first() {
            guard existing.updatedAt <= change.updatedAt else {
                return SyncConflict(
                    entity: .project,
                    id: change.id,
                    reason: "Server version is newer"
                )
            }

            existing.title = title
            existing.notes = notes
            existing.deletedAt = deletedAt
            existing.updatedAt = change.updatedAt
            try await existing.update(on: database)
        } else {
            let project = Project(
                id: change.id,
                userID: user.id,
                title: title,
                notes: notes,
                createdAt: change.updatedAt,
                updatedAt: change.updatedAt,
                deletedAt: deletedAt
            )

            try await project.save(on: database)
        }

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .project,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }

    private func parseDeletedAt(_ value: String?) throws -> Date? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: trimmedValue) {
            return date
        }

        formatter.formatOptions.insert(.withFractionalSeconds)
        if let date = formatter.date(from: trimmedValue) {
            return date
        }

        throw Abort(.badRequest, reason: "Invalid project deletedAt")
    }

    private func delete(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict? {
        guard let project = try await Project.query(on: database)
            .filter(\.$id == change.id)
            .filter(\.$user.$id == user.id)
            .first()
        else {
            return nil
        }

        project.deletedAt = change.updatedAt
        project.updatedAt = change.updatedAt
        try await project.update(on: database)

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .project,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }
}
