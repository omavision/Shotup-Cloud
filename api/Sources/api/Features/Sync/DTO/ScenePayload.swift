import Vapor

struct ScenePayload: Content {
    let projectID: UUID
    let title: String
    let notes: String?
    let sortOrder: Int
}