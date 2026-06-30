import Fluent
import Vapor

struct SyncService {
    let database: any Database

    /// Dependency rank for applying changes within a batch: a child entity's parent
    /// must be applied first, or its handler's ownership lookup fails even when the
    /// parent's own change is present later in the same batch.
    private static let entityApplyOrder: [SyncEntity: Int] = [
        .project: 0,
        .scene: 1,
        .shot: 2
    ]

    func synchronize(
        request: SyncRequest,
        user: AuthenticatedUser
    ) async throws -> SyncResponse {
        let registry = SyncRegistry(database: database)
        var conflicts: [SyncConflict] = []

        let orderedChanges = Self.orderedByDependency(request.changes)

        for change in orderedChanges {
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

            do {
                if let conflict = try await handler.apply(
                    change: change,
                    user: user
                ) {
                    conflicts.append(conflict)
                }
            } catch let abort as Abort {
                conflicts.append(
                    SyncConflict(
                        entity: change.entity,
                        id: change.id,
                        reason: abort.reason
                    )
                )
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

    private static func orderedByDependency(_ changes: [SyncChange]) -> [SyncChange] {
        changes.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = entityApplyOrder[lhs.element.entity] ?? .max
                let rhsRank = entityApplyOrder[rhs.element.entity] ?? .max
                if lhsRank == rhsRank {
                    return lhs.offset < rhs.offset
                }
                return lhsRank < rhsRank
            }
            .map(\.element)
    }

    private func latestSyncToken(for user: AuthenticatedUser) async throws -> String {
        let latestEvent = try await SyncEvent.query(on: database)
            .filter(\.$user.$id == user.id)
            .sort(\.$sequence, .descending)
            .first()

        return String(latestEvent?.sequence ?? 0)
    }
}
