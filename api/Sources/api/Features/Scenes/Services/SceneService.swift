import Vapor

struct SceneService {
    let repository: SceneRepository

    func listScenes(for projectID: UUID) async throws -> [SceneDTO] {
        let scenes = try await repository.list(for: projectID)
        return try scenes.map { try SceneDTO(scene: $0) }
    }

    func createScene(from request: CreateSceneRequest) async throws -> SceneDTO {
        let scene = Scene(
            projectID: request.projectID,
            title: request.title,
            notes: request.notes,
            sortOrder: request.sortOrder ?? 0
        )

        let savedScene = try await repository.create(scene)
        return try SceneDTO(scene: savedScene)
    }
}