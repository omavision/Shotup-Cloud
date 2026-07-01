import Fluent
import Vapor

struct SyncController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("pull", use: pull)
        routes.post(use: sync)
    }

    @Sendable
    func pull(req: Request) async throws -> APIResponse<SyncPullResponse> {
        let user = try req.auth.require(AuthenticatedUser.self)
        let request = try req.content.decode(SyncPullRequest.self)
        let serverTime = Date()

        let response = try await SyncPullService(database: req.db)
            .pull(
                updatedSince: request.updatedSince,
                user: user,
                serverTime: serverTime
            )

        return APIResponse(data: response)
    }

    @Sendable
    func sync(req: Request) async throws -> APIResponse<SyncResponse> {
        let user = try req.auth.require(AuthenticatedUser.self)
        let request = try req.content.decode(SyncRequest.self)

        req.logger.info("Sync request received from device \(request.deviceID) with \(request.changes.count) changes")

        let response = try await SyncService(database: req.db)
            .synchronize(
                request: request,
                user: user
            )

        return APIResponse(data: response)
    }
}
