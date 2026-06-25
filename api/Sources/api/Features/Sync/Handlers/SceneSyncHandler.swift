import Fluent
import Vapor

struct SceneSyncHandler: SyncHandler {
    let database: any Database

    func canHandle(_ entity: SyncEntity) -> Bool {
        entity == .scene
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
        let payload = try change.decodePayload(ScenePayload.self)
        let projectID = payload.projectID

        let projectRepository = ProjectRepository(database: database)
        let projectService = ProjectService(repository: projectRepository)
        _ = try await projectService.requireOwnedProject(id: projectID, userID: user.id)

        if let existing = try await Scene.query(on: database)
            .filter(\.$id == change.id)
            .filter(\.$project.$id == projectID)
            .first() {
            existing.title = payload.title
            existing.notes = payload.notes
            existing.sortOrder = payload.sortOrderInt
            existing.updatedAt = change.updatedAt
            try await existing.update(on: database)
        } else {
            let scene = Scene(
                id: change.id,
                projectID: projectID,
                title: payload.title,
                notes: payload.notes,
                sortOrder: payload.sortOrderInt,
                createdAt: change.updatedAt,
                updatedAt: change.updatedAt
            )

            try await scene.save(on: database)
        }

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .scene,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }

    private func delete(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict? {
        guard let scene = try await Scene.find(change.id, on: database) else {
            return nil
        }

        let projectRepository = ProjectRepository(database: database)
        let projectService = ProjectService(repository: projectRepository)
        _ = try await projectService.requireOwnedProject(id: scene.$project.id, userID: user.id)

        scene.deletedAt = change.updatedAt
        scene.updatedAt = change.updatedAt
        try await scene.update(on: database)

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .scene,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }
}
