import Vapor

struct SyncRequest: Content {
    let deviceID: String
    let lastSyncToken: String?
    let changes: [SyncChange]
}

struct SyncChange: Content {
    let entity: SyncEntity
    let operation: SyncOperation
    let id: UUID
    let updatedAt: Date
    let payload: [String: String]?
}