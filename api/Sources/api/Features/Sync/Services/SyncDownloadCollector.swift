import Foundation
import Fluent
import Vapor

struct SyncDownloadCollector {
    let database: any Database

    func collectChanges(
        for user: AuthenticatedUser,
        since lastSyncToken: String?
    ) async throws -> [DownloadChange] {
        guard let lastSyncToken else {
            return try await collectAllActiveChanges(for: user)
        }

        guard let lastSequence = Int64(lastSyncToken) else {
            throw Abort(.badRequest, reason: "Invalid sync token")
        }

        return try await collectIncrementalChanges(
            for: user,
            since: lastSequence
        )
    }

    private func collectAllActiveChanges(
        for user: AuthenticatedUser
    ) async throws -> [DownloadChange] {
        var changes: [DownloadChange] = []

        let projects = try await Project.query(on: database)
            .filter(\.$user.$id == user.id)
            .filter(\.$deletedAt == nil)
            .all()

        changes += projects.map { project in
            DownloadChange(
                entity: .project,
                operation: .upsert,
                id: project.id!,
                updatedAt: project.updatedAt,
                payload: [
                    "title": project.title,
                    "notes": project.notes ?? ""
                ]
            )
        }

        let scenes = try await Scene.query(on: database)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == user.id)
            .filter(\.$deletedAt == nil)
            .all()

        changes += scenes.map { scene in
            DownloadChange(
                entity: .scene,
                operation: .upsert,
                id: scene.id!,
                updatedAt: scene.updatedAt,
                payload: [
                    "projectID": scene.$project.id.uuidString,
                    "title": scene.title,
                    "notes": scene.notes ?? "",
                    "sortOrder": String(scene.sortOrder)
                ]
            )
        }

        let shots = try await Shot.query(on: database)
            .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == user.id)
            .filter(\.$deletedAt == nil)
            .all()

        changes += shots.map { shot in
            DownloadChange(
                entity: .shot,
                operation: .upsert,
                id: shot.id!,
                updatedAt: shot.updatedAt,
                payload: [
                    "sceneID": shot.$scene.id.uuidString,
                    "title": shot.title,
                    "notes": shot.notes ?? "",
                    "shotSize": shot.shotSize ?? "",
                    "cameraMovement": shot.cameraMovement ?? "",
                    "lensMM": shot.lensMM.map { "\($0)" } ?? "",
                    "sortOrder": "\(shot.sortOrder)",
                    "deletedAt": shot.deletedAt?.iso8601 ?? ""
                ]
            )
        }

        return changes
    }

    private func collectIncrementalChanges(
        for user: AuthenticatedUser,
        since lastSequence: Int64
    ) async throws -> [DownloadChange] {
        let events = try await SyncEvent.query(on: database)
            .filter(\.$user.$id == user.id)
            .filter(\.$sequence > lastSequence)
            .sort(\.$sequence, .ascending)
            .all()

        var changes: [DownloadChange] = []

        for event in events {
            guard let change = try await downloadChange(for: event, user: user) else {
                continue
            }

            changes.append(change)
        }

        return changes
    }

    private func downloadChange(
        for event: SyncEvent,
        user: AuthenticatedUser
    ) async throws -> DownloadChange? {
        guard let entity = SyncEntity(rawValue: event.entity) else {
            return nil
        }

        guard let operation = SyncOperation(rawValue: event.operation) else {
            return nil
        }

        if operation == .delete {
            return tombstoneDownloadChange(
                entity: entity,
                id: event.entityID,
                updatedAt: event.createdAt
            )
        }

        switch entity {
        case .project:
            guard let project = try await Project.query(on: database)
                .filter(\.$id == event.entityID)
                .filter(\.$user.$id == user.id)
                .filter(\.$deletedAt == nil)
                .first()
            else {
                return nil
            }

            return projectDownloadChange(project)

        case .scene:
            guard let scene = try await Scene.query(on: database)
                .join(Project.self, on: \Scene.$project.$id == \Project.$id)
                .filter(\.$id == event.entityID)
                .filter(Project.self, \.$user.$id == user.id)
                .filter(\.$deletedAt == nil)
                .first()
            else {
                return nil
            }

            return sceneDownloadChange(scene)

        case .shot:
            guard let shot = try await Shot.query(on: database)
                .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
                .join(Project.self, on: \Scene.$project.$id == \Project.$id)
                .filter(\.$id == event.entityID)
                .filter(Project.self, \.$user.$id == user.id)
                .first()
            else {
                return nil
            }

            return shotDownloadChange(shot)

        case .media, .cameraSetup, .lensSetup:
            return nil
        }
    }

    private func tombstoneDownloadChange(
        entity: SyncEntity,
        id: UUID,
        updatedAt: Date
    ) -> DownloadChange {
        DownloadChange(
            entity: entity,
            operation: .delete,
            id: id,
            updatedAt: updatedAt,
            payload: nil
        )
    }

    private func projectDownloadChange(_ project: Project) -> DownloadChange {
        DownloadChange(
            entity: .project,
            operation: .upsert,
            id: project.id!,
            updatedAt: project.updatedAt,
            payload: [
                "title": project.title,
                "notes": project.notes ?? ""
            ]
        )
    }

    private func sceneDownloadChange(_ scene: Scene) -> DownloadChange {
        DownloadChange(
            entity: .scene,
            operation: .upsert,
            id: scene.id!,
            updatedAt: scene.updatedAt,
            payload: [
                "projectID": scene.$project.id.uuidString,
                "title": scene.title,
                "notes": scene.notes ?? "",
                "sortOrder": String(scene.sortOrder)
            ]
        )
    }

    private func shotDownloadChange(_ shot: Shot) -> DownloadChange {
        DownloadChange(
            entity: .shot,
            operation: .upsert,
            id: shot.id!,
            updatedAt: shot.updatedAt,
            payload: [
                "sceneID": shot.$scene.id.uuidString,
                "title": shot.title,
                "notes": shot.notes ?? "",
                "shotSize": shot.shotSize ?? "",
                "cameraMovement": shot.cameraMovement ?? "",
                "lensMM": shot.lensMM.map { "\($0)" } ?? "",
                "sortOrder": "\(shot.sortOrder)",
                "deletedAt": shot.deletedAt?.iso8601 ?? ""
            ]
        )
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
