import Fluent
import Vapor

struct SceneDTO: Content {
    let id: UUID?
    let projectID: UUID
    let title: String
    let notes: String?
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(scene: Scene) throws {
        self.id = try scene.requireID()
        self.projectID = scene.$project.id
        self.title = scene.title
        self.notes = scene.notes
        self.sortOrder = scene.sortOrder
        self.createdAt = scene.createdAt
        self.updatedAt = scene.updatedAt
        self.deletedAt = scene.deletedAt
    }
}