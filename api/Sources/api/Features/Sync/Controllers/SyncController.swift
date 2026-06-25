import Fluent
import Vapor

struct SyncController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post(use: sync)
    }

    @Sendable
    func sync(req: Request) async throws -> APIResponse<SyncResponse> {
        _ = try req.auth.require(AuthenticatedUser.self)
        let request = try req.content.decode(SyncRequest.self)

        let response = SyncResponse(
            syncToken: UUID().uuidString,
            serverTime: Date(),
            changes: [],
            conflicts: []
        )

        req.logger.info("Sync request received from device \(request.deviceID) with \(request.changes.count) changes")

        return APIResponse(data: response)
    }
}