import Fluent
import Vapor

struct MediaController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("request-upload", use: requestUpload)
    }

    @Sendable
    func requestUpload(req: Request) async throws -> APIResponse<RequestUploadResponse> {
        let auth = try req.auth.require(AuthenticatedUser.self)
        let payload = try req.content.decode(RequestUploadRequest.self)

        guard let storage = req.application.r2Storage else {
            throw Abort(.internalServerError, reason: "Storage service unavailable")
        }

        let service = MediaService(database: req.db, storage: storage)
        let response = try await service.requestUpload(userID: auth.id, payload: payload)

        return APIResponse(data: response)
    }
}
