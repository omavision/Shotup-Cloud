import Vapor

struct CreateProjectRequest: Content {
    let userID: UUID
    let title: String
    let notes: String?
}