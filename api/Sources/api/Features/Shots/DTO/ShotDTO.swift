import Fluent
import Vapor

struct ShotDTO: Content {
    let id: UUID?
    let sceneID: UUID
    let title: String
    let notes: String?
    let shotSize: String?
    let cameraMovement: String?
    let lensMM: Double?
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(shot: Shot) throws {
        self.id = try shot.requireID()
        self.sceneID = shot.$scene.id
        self.title = shot.title
        self.notes = shot.notes
        self.shotSize = shot.shotSize
        self.cameraMovement = shot.cameraMovement
        self.lensMM = shot.lensMM
        self.sortOrder = shot.sortOrder
        self.createdAt = shot.createdAt
        self.updatedAt = shot.updatedAt
        self.deletedAt = shot.deletedAt
    }
}
