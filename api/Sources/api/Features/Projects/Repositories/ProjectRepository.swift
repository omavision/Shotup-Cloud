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

    func countScenes(for projectID: UUID) async throws -> Int {
        try await Scene.query(on: database)
            .filter(\.$project.$id == projectID)
            .filter(\.$deletedAt == nil)
            .count()
    }

    func countShots(for projectID: UUID) async throws -> Int {
        try await Shot.query(on: database)
            .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
            .filter(Scene.self, \.$project.$id == projectID)
            .filter(Scene.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)
            .count()
    }

    func countMediaAssets(for projectID: UUID) async throws -> Int {
        try await MediaAsset.query(on: database)
            .filter(\.$projectID == projectID)
            .count()
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
