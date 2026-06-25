import Fluent
import Vapor

struct ProjectController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get(use: listProjects)
        routes.post(use: createProject)
    }

    @Sendable
    func listProjects(req: Request) async throws -> APIResponse<[ProjectDTO]> {
        guard let userIDString = req.query[String.self, at: "userID"],
              let userID = UUID(uuidString: userIDString) else {
            throw Abort(.badRequest, reason: "Missing or invalid userID")
        }

        let repository = ProjectRepository(database: req.db)
        let service = ProjectService(repository: repository)

        let projects = try await service.listProjects(for: userID)
        return APIResponse(data: projects)
    }

    @Sendable
    func createProject(req: Request) async throws -> APIResponse<ProjectDTO> {
        let request = try req.content.decode(CreateProjectRequest.self)

        let repository = ProjectRepository(database: req.db)
        let service = ProjectService(repository: repository)

        let project = try await service.createProject(from: request)
        return APIResponse(data: project)
    }
}