import Fluent
import Vapor

struct SceneController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get(use: listScenes)
        routes.post(use: createScene)
    }

    @Sendable
    func listScenes(req: Request) async throws -> APIResponse<[SceneDTO]> {
        let auth = try req.auth.require(AuthenticatedUser.self)

        guard let projectIDString = req.parameters.get("projectID"),
              let projectID = UUID(uuidString: projectIDString) else {
            throw Abort(.badRequest, reason: "Missing or invalid projectID")
        }

        let projectRepository = ProjectRepository(database: req.db)
        let projectService = ProjectService(repository: projectRepository)
        _ = try await projectService.requireOwnedProject(id: projectID, userID: auth.id)

        let sceneRepository = SceneRepository(database: req.db)
        let sceneService = SceneService(repository: sceneRepository)

        let scenes = try await sceneService.listScenes(for: projectID)
        return APIResponse(data: scenes)
    }

    @Sendable
    func createScene(req: Request) async throws -> APIResponse<SceneDTO> {
        let auth = try req.auth.require(AuthenticatedUser.self)

        guard let projectIDString = req.parameters.get("projectID"),
              let projectID = UUID(uuidString: projectIDString) else {
            throw Abort(.badRequest, reason: "Missing or invalid projectID")
        }

        let request = try req.content.decode(CreateSceneRequest.self)

        let projectRepository = ProjectRepository(database: req.db)
        let projectService = ProjectService(repository: projectRepository)
        _ = try await projectService.requireOwnedProject(id: projectID, userID: auth.id)

        let sceneRepository = SceneRepository(database: req.db)
        let sceneService = SceneService(repository: sceneRepository)

        let scene = try await sceneService.createScene(
            projectID: projectID,
            title: request.title,
            notes: request.notes,
            sortOrder: request.sortOrder ?? 0
        )

        return APIResponse(data: scene)
    }
}