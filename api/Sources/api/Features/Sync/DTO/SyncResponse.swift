import Vapor

struct SyncResponse: Content {
    let syncToken: String
    let serverTime: Date
    let changes: [SyncChange]
    let conflicts: [SyncConflict]
}

struct SyncConflict: Content {
    let entity: SyncEntity
    let id: UUID
    let reason: String
}