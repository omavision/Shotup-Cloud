import Fluent
import Vapor

struct ProjectController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("cloud", use: listCloudProjects)
        routes.get(use: listProjects)
        routes.post(use: createProject)
    }

    @Sendable
    func listCloudProjects(req: Request) async throws -> APIResponse<CloudProjectListResponse> {
        let auth = try req.auth.require(AuthenticatedUser.self)

        let repository = ProjectRepository(database: req.db)
        let service = ProjectService(repository: repository)

        let projects = try await service.listCloudProjects(for: auth.id)
        return APIResponse(data: projects)
    }

    @Sendable
    func listProjects(req: Request) async throws -> APIResponse<[ProjectDTO]> {
        let auth = try req.auth.require(AuthenticatedUser.self)

        let repository = ProjectRepository(database: req.db)
        let service = ProjectService(repository: repository)

        let projects = try await service.listProjects(for: auth.id)
        return APIResponse(data: projects)
    }

    @Sendable
    func createProject(req: Request) async throws -> APIResponse<ProjectDTO> {
        let auth = try req.auth.require(AuthenticatedUser.self)
        let request = try req.content.decode(CreateProjectRequest.self)

        let repository = ProjectRepository(database: req.db)
        let service = ProjectService(repository: repository)

        let project = try await service.createProject(
            userID: auth.id,
            title: request.title,
            notes: request.notes
        )

        return APIResponse(data: project)
    }
}
