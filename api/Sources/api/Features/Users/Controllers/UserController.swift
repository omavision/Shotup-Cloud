import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get(":id", use: getUser)
    }

    @Sendable
    func getUser(req: Request) async throws -> APIResponse<UserDTO> {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let repository = UserRepository(database: req.db)
        let service = UserService(repository: repository)

        guard let user = try await service.findUser(id: id) else {
            throw Abort(.notFound, reason: "User not found")
        }

        return APIResponse(data: user)
    }
}