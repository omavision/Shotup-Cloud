import Fluent
import Vapor

struct SyncService {
    let database: any Database

    func synchronize(
        request: SyncRequest,
        user: AuthenticatedUser
    ) async throws -> SyncResponse {
        let registry = SyncRegistry(database: database)
        var conflicts: [SyncConflict] = []

        for change in request.changes {
            guard let handler = registry.handler(for: change.entity) else {
                conflicts.append(
                    SyncConflict(
                        entity: change.entity,
                        id: change.id,
                        reason: "Unsupported entity"
                    )
                )
                continue
            }

            if let conflict = try await handler.apply(
                change: change,
                user: user
            ) {
                conflicts.append(conflict)
            }
        }

        let syncToken = try await latestSyncToken(for: user)

        let downloadChanges = try await SyncDownloadCollector(database: database)
            .collectChanges(
                for: user,
                since: request.lastSyncToken
            )

        return SyncResponse(
            syncToken: syncToken,
            serverTime: Date(),
            changes: downloadChanges,
            conflicts: conflicts
        )
    }

    private func latestSyncToken(for user: AuthenticatedUser) async throws -> String {
        let latestEvent = try await SyncEvent.query(on: database)
            .filter(\.$user.$id == user.id)
            .sort(\.$sequence, .descending)
            .first()

        return String(latestEvent?.sequence ?? 0)
    }
}
