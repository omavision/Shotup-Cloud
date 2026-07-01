import Fluent
import Vapor

struct SyncStatusService {
    let database: any Database

    func status(
        for user: AuthenticatedUser,
        serverTime: Date = Date()
    ) async throws -> SyncStatusResponse {
        let projectCount = try await activeProjectCount(for: user.id)
        let sceneCount = try await activeSceneCount(for: user.id)
        let shotCount = try await activeShotCount(for: user.id)
        let mediaAssetCount = try await mediaCount(for: user.id)
        let uploadedMediaCount = try await mediaCount(
            for: user.id,
            status: MediaAssetStatus.uploaded.rawValue
        )
        let pendingMediaCount = try await mediaCount(
            for: user.id,
            status: MediaAssetStatus.pending.rawValue
        )
        let lastMetadataUpdate = try await latestMetadataUpdate(for: user.id)
        let lastMediaUpload = try await latestMediaUpload(for: user.id)

        return SyncStatusResponse(
            serverTime: serverTime,
            projectCount: projectCount,
            sceneCount: sceneCount,
            shotCount: shotCount,
            mediaAssetCount: mediaAssetCount,
            uploadedMediaCount: uploadedMediaCount,
            pendingMediaCount: pendingMediaCount,
            lastMetadataUpdate: lastMetadataUpdate,
            lastMediaUpload: lastMediaUpload
        )
    }

    private func activeProjectCount(for userID: UUID) async throws -> Int {
        try await Project.query(on: database)
            .filter(\.$user.$id == userID)
            .filter(\.$deletedAt == nil)
            .count()
    }

    private func activeSceneCount(for userID: UUID) async throws -> Int {
        try await Scene.query(on: database)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)
            .count()
    }

    private func activeShotCount(for userID: UUID) async throws -> Int {
        try await Shot.query(on: database)
            .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(Scene.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)
            .count()
    }

    private func mediaCount(for userID: UUID, status: String? = nil) async throws -> Int {
        let query = MediaAsset.query(on: database)
            .filter(\.$userID == userID)

        if let status {
            query.filter(\.$status == status)
        }

        return try await query.count()
    }

    private func latestMetadataUpdate(for userID: UUID) async throws -> Date? {
        let latestProject = try await Project.query(on: database)
            .filter(\.$user.$id == userID)
            .filter(\.$deletedAt == nil)
            .sort(\.$updatedAt, .descending)
            .first()

        let latestScene = try await Scene.query(on: database)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)
            .sort(\.$updatedAt, .descending)
            .first()

        let latestShot = try await Shot.query(on: database)
            .join(Scene.self, on: \Shot.$scene.$id == \Scene.$id)
            .join(Project.self, on: \Scene.$project.$id == \Project.$id)
            .filter(Project.self, \.$user.$id == userID)
            .filter(Project.self, \.$deletedAt == nil)
            .filter(Scene.self, \.$deletedAt == nil)
            .filter(\.$deletedAt == nil)
            .sort(\.$updatedAt, .descending)
            .first()

        return [
            latestProject?.updatedAt,
            latestScene?.updatedAt,
            latestShot?.updatedAt
        ]
        .compactMap { $0 }
        .max()
    }

    private func latestMediaUpload(for userID: UUID) async throws -> Date? {
        let latestUploadedAsset = try await MediaAsset.query(on: database)
            .filter(\.$userID == userID)
            .filter(\.$status == MediaAssetStatus.uploaded.rawValue)
            .sort(\.$uploadedAt, .descending)
            .first()

        return latestUploadedAsset?.uploadedAt
    }
}
