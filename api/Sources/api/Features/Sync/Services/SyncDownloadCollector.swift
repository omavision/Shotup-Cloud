import Fluent
import Vapor

struct SyncDownloadCollector {
    let database: any Database

    func collectChanges(
        for user: AuthenticatedUser,
        since lastSyncToken: String?
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

        return changes
    }
}