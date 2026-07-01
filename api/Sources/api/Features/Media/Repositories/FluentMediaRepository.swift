import Fluent
import Vapor

struct FluentMediaRepository: MediaRepository {
    let database: any Database

    func createPendingUpload(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        objectKey: String,
        bucket: String,
        mimeType: String
    ) async throws -> MediaAsset {
        try await upsertPendingUpload(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            shotID: shotID,
            objectKey: objectKey,
            bucket: bucket,
            mimeType: mimeType
        )
    }

    func upsertPendingUpload(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        objectKey: String,
        bucket: String,
        mimeType: String
    ) async throws -> MediaAsset {
        if let existing = try await findByObjectKey(objectKey) {
            let now = Date()
            existing.userID = userID
            existing.projectID = projectID
            existing.sceneID = sceneID
            existing.shotID = shotID
            existing.bucket = bucket
            existing.mimeType = mimeType
            existing.status = MediaAssetStatus.pending.rawValue
            existing.sizeBytes = 0
            existing.checksum = nil
            existing.uploadedAt = nil
            existing.updatedAt = now

            try await existing.update(on: database)
            return existing
        }

        let asset = MediaAsset(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            shotID: shotID,
            objectKey: objectKey,
            bucket: bucket,
            mimeType: mimeType,
            status: .pending
        )

        try await asset.save(on: database)
        return asset
    }

    func markUploaded(
        objectKey: String,
        sizeBytes: Int64,
        checksum: String?,
        uploadedAt: Date
    ) async throws -> MediaAsset? {
        guard let asset = try await findByObjectKey(objectKey) else {
            return nil
        }

        asset.sizeBytes = sizeBytes
        asset.checksum = checksum
        asset.status = MediaAssetStatus.uploaded.rawValue
        asset.uploadedAt = uploadedAt
        asset.updatedAt = uploadedAt

        try await asset.update(on: database)
        return asset
    }

    func findByFrameID(_ frameID: UUID) async throws -> [MediaAsset] {
        try await MediaAsset.query(on: database)
            .filter(\.$shotID == frameID)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func findByObjectKey(_ objectKey: String) async throws -> MediaAsset? {
        try await MediaAsset.query(on: database)
            .filter(\.$objectKey == objectKey)
            .first()
    }

    func findPendingUpload(objectKey: String) async throws -> MediaAsset? {
        try await MediaAsset.query(on: database)
            .filter(\.$objectKey == objectKey)
            .filter(\.$status == MediaAssetStatus.pending.rawValue)
            .first()
    }

    func findUploadedMedia(userID: UUID, projectIDs: [UUID]) async throws -> [MediaAsset] {
        guard projectIDs.isEmpty == false else {
            return []
        }

        return try await MediaAsset.query(on: database)
            .filter(\.$userID == userID)
            .filter(\.$projectID ~~ projectIDs)
            .filter(\.$status == MediaAssetStatus.uploaded.rawValue)
            .sort(\.$uploadedAt, .ascending)
            .sort(\.$shotID, .ascending)
            .all()
    }

    func delete(_ asset: MediaAsset) async throws {
        try await asset.delete(on: database)
    }
}
