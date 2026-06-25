import Fluent
import Vapor

struct SyncRegistry {
    private let handlers: [any SyncHandler]

    init(database: any Database) {
        handlers = [
            ProjectSyncHandler(database: database),
            SceneSyncHandler(database: database),
            ShotSyncHandler(database: database)
        ]
    }

    func handler(for entity: SyncEntity) -> (any SyncHandler)? {
        handlers.first { $0.canHandle(entity) }
    }
}
