import Vapor

struct DownloadChange: Content {
    let entity: SyncEntity
    let operation: SyncOperation
    let id: UUID
    let updatedAt: Date
    let payload: [String: String]?
}