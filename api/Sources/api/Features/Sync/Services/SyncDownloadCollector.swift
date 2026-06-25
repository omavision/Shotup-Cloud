import Fluent
import Vapor

struct SyncDownloadCollector {
    let database: any Database

    func collectChanges(
        for user: AuthenticatedUser,
        since lastSyncToken: String?
    ) async throws -> [DownloadChange] {

        // M4 implementation:
        // Ignore lastSyncToken for now and return all active projects.
        let projects = try await Project.query(on: database)
            .filter(\.$user.$id == user.id)
            .filter(\.$deletedAt == nil)
            .all()

        return projects.map { project in
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
    }
}