import Fluent
import Vapor

struct SyncController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post(use: sync)
    }

    @Sendable
    func sync(req: Request) async throws -> APIResponse<SyncResponse> {
        let user = try req.auth.require(AuthenticatedUser.self)
        let request = try req.content.decode(SyncRequest.self)

        req.logger.info("Sync request received from device \(request.deviceID) with \(request.changes.count) changes")

        let response = try await SyncService()
            .synchronize(
                request: request,
                user: user
            )

        return APIResponse(data: response)
    }
}