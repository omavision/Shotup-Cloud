import Vapor

struct SyncService {
    func synchronize(
        request: SyncRequest,
        user: AuthenticatedUser
    ) async throws -> SyncResponse {
        SyncResponse(
            syncToken: UUID().uuidString,
            serverTime: Date(),
            changes: [],
            conflicts: []
        )
    }
}