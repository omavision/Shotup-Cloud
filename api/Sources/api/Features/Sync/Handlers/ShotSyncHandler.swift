import Fluent
import Vapor

struct ShotSyncHandler: SyncHandler {
    let database: any Database

    func canHandle(_ entity: SyncEntity) -> Bool {
        entity == .shot
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
        let payload = try change.decodePayload(ShotPayload.self)
        let sceneID = payload.sceneID
        _ = try await requireOwnedScene(id: sceneID, user: user)

        if let existing = try await Shot.query(on: database)
            .filter(\.$id == change.id)
            .filter(\.$scene.$id == sceneID)
            .first() {
            guard existing.updatedAt <= change.updatedAt else {
                return SyncConflict(
                    entity: .shot,
                    id: change.id,
                    reason: "Server version is newer"
                )
            }

            existing.title = payload.title
            existing.notes = payload.notes
            existing.shotSize = payload.shotSize
            existing.cameraMovement = payload.cameraMovement
            existing.lensMM = payload.lensMMDouble
            existing.sortOrder = payload.sortOrderInt
            existing.updatedAt = change.updatedAt
            try await existing.update(on: database)
        } else {
            let shot = Shot(
                id: change.id,
                sceneID: sceneID,
                title: payload.title,
                notes: payload.notes,
                shotSize: payload.shotSize,
                cameraMovement: payload.cameraMovement,
                lensMM: payload.lensMMDouble,
                sortOrder: payload.sortOrderInt,
                createdAt: change.updatedAt,
                updatedAt: change.updatedAt
            )

            try await shot.save(on: database)
        }

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .shot,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }

    private func delete(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict? {
        guard let shot = try await Shot.find(change.id, on: database) else {
            return nil
        }

        _ = try await requireOwnedScene(id: shot.$scene.id, user: user)

        shot.deletedAt = change.updatedAt
        shot.updatedAt = change.updatedAt
        try await shot.update(on: database)

        let recorder = SyncEventRecorder(database: database)
        _ = try await recorder.record(
            userID: user.id,
            entity: .shot,
            entityID: change.id,
            operation: change.operation
        )

        return nil
    }

    private func requireOwnedScene(
        id sceneID: UUID,
        user: AuthenticatedUser
    ) async throws -> Scene {
        guard let scene = try await Scene.find(sceneID, on: database) else {
            throw Abort(.notFound, reason: "Scene not found")
        }

        let projectRepository = ProjectRepository(database: database)
        let projectService = ProjectService(repository: projectRepository)
        _ = try await projectService.requireOwnedProject(id: scene.$project.id, userID: user.id)

        return scene
    }
}
