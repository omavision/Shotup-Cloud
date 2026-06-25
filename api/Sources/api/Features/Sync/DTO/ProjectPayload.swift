import Vapor

struct ProjectPayload: Content {
    let title: String
    let notes: String?
}