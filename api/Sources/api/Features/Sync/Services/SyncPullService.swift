import Fluent
import Vapor

struct SyncPullService {
    let database: any Database

    func pull(
        updatedSince: Date?,
        user: AuthenticatedUser,
        serverTime: Date = Date()
    ) async throws -> SyncPullResponse {
        let projects = try await queryProjects(for: user.id, updatedSince: updatedSince)
        let scenes = try await queryScenes(for: user.id, updatedSince: updatedSince)
        let shots = try await queryShots(for: user.id, updatedSince: updatedSince)

        return try SyncPullResponse(
            projects: projects.map { try ProjectDTO(project: $0) },
            scenes: scenes.map { try SceneDTO(scene: $0) },
            shots: shots.map { try ShotDTO(shot: $0) },
            serverTime: serverTime
        )
    }

    private func queryProjects(
        for userID: UUID,
        updatedSince: Date?
    ) async throws -> [Project] {
        let query = Project.query(on: database)
            .filter(\.$user.$id == userID)
            .filter(\.$deletedAt == nil)

        if let updatedSince {
            query.filter(\.$updatedAt > updatedSince)
        }

        return try await query
            .sort(\.$updatedAt, .ascending)
            .all()
    }

    private func queryScenes(
        for userID: UUID,
        updatedSince: Date?
    ) async throws -> [Scene] {
        let query = Scene.query(on: database)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)

        if let updatedSince {
            query.filter(\.$updatedAt > updatedSince)
        }

        return try await query
            .sort(\.$updatedAt, .ascending)
            .all()
    }

    private func queryShots(
        for userID: UUID,
        updatedSince: Date?
    ) async throws -> [Shot] {
        let query = Shot.query(on: database)
            .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(Scene.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)

        if let updatedSince {
            query.filter(\.$updatedAt > updatedSince)
        }

        return try await query
            .sort(\.$updatedAt, .ascending)
            .all()
    }
}
