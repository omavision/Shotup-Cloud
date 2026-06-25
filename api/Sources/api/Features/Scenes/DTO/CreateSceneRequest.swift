import Vapor

struct CreateSceneRequest: Content {
    let title: String
    let notes: String?
    let sortOrder: Int?
}