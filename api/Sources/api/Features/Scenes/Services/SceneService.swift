import Vapor

struct SceneService {
    let repository: SceneRepository

    func listScenes(for projectID: UUID) async throws -> [SceneDTO] {
        let scenes = try await repository.list(for: projectID)
        return try scenes.map { try SceneDTO(scene: $0) }
    }

    func createScene(
        projectID: UUID,
        title: String,
        notes: String?,
        sortOrder: Int
    ) async throws -> SceneDTO {
        let scene = Scene(
            projectID: projectID,
            title: title,
            notes: notes,
            sortOrder: sortOrder
        )

        let savedScene = try await repository.create(scene)
        return try SceneDTO(scene: savedScene)
    }
}