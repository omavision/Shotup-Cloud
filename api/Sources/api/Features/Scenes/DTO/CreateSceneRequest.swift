import Vapor

struct CreateSceneRequest: Content {
    let projectID: UUID
    let title: String
    let notes: String?
    let sortOrder: Int?
}