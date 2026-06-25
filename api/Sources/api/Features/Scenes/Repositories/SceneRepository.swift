import Fluent
import Vapor

struct SceneRepository {
    let database: any Database

    func list(for projectID: UUID) async throws -> [Scene] {
        try await Scene.query(on: database)
            .filter(\.$project.$id == projectID)
            .filter(\.$deletedAt == nil)
            .sort(\.$sortOrder, .ascending)
            .all()
    }

    func create(_ scene: Scene) async throws -> Scene {
        try await scene.save(on: database)
        return scene
    }
}