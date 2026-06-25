import Vapor

struct CreateProjectRequest: Content {
    let title: String
    let notes: String?
}