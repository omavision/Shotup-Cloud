import Fluent
import Vapor

struct SceneController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get(use: listScenes)
        routes.post(use: createScene)
    }

    @Sendable
    func listScenes(req: Request) async throws -> APIResponse<[SceneDTO]> {
        guard let projectIDString = req.query[String.self, at: "projectID"],
              let projectID = UUID(uuidString: projectIDString) else {
            throw Abort(.badRequest, reason: "Missing or invalid projectID")
        }

        let repository = SceneRepository(database: req.db)
        let service = SceneService(repository: repository)

        let scenes = try await service.listScenes(for: projectID)
        return APIResponse(data: scenes)
    }

    @Sendable
    func createScene(req: Request) async throws -> APIResponse<SceneDTO> {
        let request = try req.content.decode(CreateSceneRequest.self)

        let repository = SceneRepository(database: req.db)
        let service = SceneService(repository: repository)

        let scene = try await service.createScene(from: request)
        return APIResponse(data: scene)
    }
}