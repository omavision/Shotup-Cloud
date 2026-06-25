import Fluent
import Vapor

struct ProjectRepository {
    let database: any Database

    func find(id: UUID) async throws -> Project? {
        try await Project.find(id, on: database)
    }

    func list(for userID: UUID) async throws -> [Project] {
        try await Project.query(on: database)
            .filter(\.$user.$id == userID)
            .filter(\.$deletedAt == nil)
            .sort(\.$updatedAt, .descending)
            .all()
    }

    func create(_ project: Project) async throws -> Project {
        try await project.save(on: database)
        return project
    }

    func findOwnedProject(id projectID: UUID, userID: UUID) async throws -> Project? {
        try await Project.query(on: database)
            .filter(\.$id == projectID)
            .filter(\.$user.$id == userID)
            .filter(\.$deletedAt == nil)
            .first()
    }
}