import Fluent
import Vapor

struct ProjectDTO: Content {
    let id: UUID?
    let userID: UUID
    let title: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(project: Project) throws {
        self.id = try project.requireID()
        self.userID = project.$user.id
        self.title = project.title
        self.notes = project.notes
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
        self.deletedAt = project.deletedAt
    }
}