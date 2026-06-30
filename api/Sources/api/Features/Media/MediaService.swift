import Fluent
import Vapor

struct MediaService {
    static let objectNotFoundInStorageReason = "Object not found in storage"
    static let mediaNotUploadedReason = "Media not uploaded yet"

    let database: any Database
    let storage: any R2StorageServicing
    let repository: any MediaRepository

    func requestUpload(
        userID: UUID,
        payload: RequestUploadRequest
    ) async throws -> RequestUploadResponse {
        guard let project = try await Project.find(payload.projectID, on: database) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        guard project.$user.id == userID else {
            throw Abort(.forbidden, reason: "You do not have access to this project")
        }

        guard let scene = try await Scene.find(payload.sceneID, on: database),
              scene.$project.id == payload.projectID else {
            throw Abort(.notFound, reason: "Scene not found")
        }

        guard let shot = try await Shot.find(payload.frameID, on: database),
              shot.$scene.id == payload.sceneID else {
            throw Abort(.notFound, reason: "Frame not found")
        }

        let normalizedContentType = payload.contentType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedContentType == "image/jpeg" else {
            throw Abort(.badRequest, reason: "Unsupported content type: \(payload.contentType)")
        }

        let presigned = try await storage.presignedUploadURL(
            userID: userID,
            projectID: payload.projectID,
            sceneID: payload.sceneID,
            frameID: payload.frameID,
            contentType: payload.contentType
        )

        _ = try await repository.upsertPendingUpload(
            userID: userID,
            projectID: payload.projectID,
            sceneID: payload.sceneID,
            shotID: payload.frameID,
            objectKey: presigned.objectKey,
            bucket: presigned.bucket,
            mimeType: normalizedContentType
        )

        return RequestUploadResponse(
            uploadURL: presigned.uploadURL,
            objectKey: presigned.objectKey,
            expiresAt: presigned.expiresAt,
            requiredHeaders: presigned.requiredHeaders
        )
    }

    func confirmUpload(
        userID: UUID,
        payload: ConfirmUploadRequest
    ) async throws -> ConfirmUploadResponse {
        guard let asset = try await repository.findPendingUpload(objectKey: payload.objectKey) else {
            throw Abort(.notFound, reason: "Pending media asset not found")
        }

        guard asset.userID == userID else {
            throw Abort(.forbidden, reason: "You do not have access to this media asset")
        }

        guard try await storage.objectExists(objectKey: payload.objectKey) else {
            throw Abort(.notFound, reason: Self.objectNotFoundInStorageReason)
        }

        let normalizedMimeType = payload.mimeType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedMimeType == "image/jpeg" else {
            throw Abort(.badRequest, reason: "Unsupported content type: \(payload.mimeType)")
        }

        _ = try await repository.markUploaded(
            objectKey: payload.objectKey,
            sizeBytes: payload.size,
            checksum: payload.checksum,
            uploadedAt: Date()
        )

        return ConfirmUploadResponse(success: true)
    }

    func requestDownload(
        userID: UUID,
        payload: RequestDownloadRequest
    ) async throws -> RequestDownloadResponse {
        guard let asset = try await repository.findByFrameID(payload.frameID).first else {
            throw Abort(.notFound, reason: "Media asset not found")
        }

        guard asset.userID == userID else {
            throw Abort(.forbidden, reason: "You do not have access to this media asset")
        }

        guard asset.status == MediaAssetStatus.uploaded.rawValue else {
            throw Abort(.conflict, reason: Self.mediaNotUploadedReason)
        }

        let expiresIn = R2StorageService.downloadExpirationSeconds
        let downloadURL = try await storage.presignedDownloadURL(
            objectKey: asset.objectKey,
            expiresIn: expiresIn
        )

        return RequestDownloadResponse(
            downloadURL: downloadURL,
            objectKey: asset.objectKey,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    func checkExists(
        userID: UUID,
        payload: MediaExistsRequest
    ) async throws -> MediaExistsResponse {
        guard let asset = try await repository.findByFrameID(payload.frameID).first else {
            return MediaExistsResponse(
                exists: false,
                mediaAssetID: nil,
                objectKey: nil,
                status: nil
            )
        }

        guard asset.userID == userID else {
            throw Abort(.forbidden, reason: "You do not have access to this media asset")
        }

        return MediaExistsResponse(
            exists: true,
            mediaAssetID: asset.id,
            objectKey: asset.objectKey,
            status: asset.status
        )
    }
}
