import Fluent
import Vapor

struct MeController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get(use: me)
    }

    @Sendable
    func me(req: Request) async throws -> APIResponse<UserDTO> {
        let authenticatedUser = try req.auth.require(AuthenticatedUser.self)

        let repository = UserRepository(database: req.db)

        guard let user = try await repository.find(id: authenticatedUser.id) else {
            throw Abort(.notFound, reason: "User not found")
        }

        return APIResponse(data: try UserDTO(user: user))
    }
}