import Fluent
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
        let title = change.payload?["title"] ?? "Untitled Project"
        let notes = change.payload?["notes"]

        if let existing = try await Project.query(on: database)
            .filter(\.$id == change.id)
            .filter(\.$user.$id == user.id)
            .first() {
            existing.title = title
            existing.notes = notes
            existing.updatedAt = change.updatedAt
            try await existing.update(on: database)
        } else {
            let project = Project(
                id: change.id,
                userID: user.id,
                title: title,
                notes: notes,
                createdAt: change.updatedAt,
                updatedAt: change.updatedAt
            )

            try await project.save(on: database)
        }

        return nil
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

        return nil
    }
}