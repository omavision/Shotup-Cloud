import Fluent
import Foundation

struct SyncEventRecorder {
    let database: any Database

    func record(
        userID: UUID,
        entity: SyncEntity,
        entityID: UUID,
        operation: SyncOperation
    ) async throws -> Int64 {
        let latestEvent = try await SyncEvent.query(on: database)
            .sort(\.$sequence, .descending)
            .first()

        let sequence = (latestEvent?.sequence ?? 0) + 1

        let event = SyncEvent(
            userID: userID,
            entity: entity.rawValue,
            entityID: entityID,
            operation: operation.rawValue,
            sequence: sequence,
            createdAt: Date()
        )

        try await event.save(on: database)

        return sequence
    }
}
