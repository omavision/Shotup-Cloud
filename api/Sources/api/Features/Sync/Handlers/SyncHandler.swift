import Vapor

protocol SyncHandler {
    func canHandle(_ entity: SyncEntity) -> Bool

    func apply(
        change: SyncChange,
        user: AuthenticatedUser
    ) async throws -> SyncConflict?
}