import Vapor

protocol MediaRepository: Sendable {
    func createPendingUpload(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        objectKey: String,
        bucket: String,
        mimeType: String
    ) async throws -> MediaAsset

    func upsertPendingUpload(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        objectKey: String,
        bucket: String,
        mimeType: String
    ) async throws -> MediaAsset

    func markUploaded(
        objectKey: String,
        sizeBytes: Int64,
        checksum: String?,
        uploadedAt: Date
    ) async throws -> MediaAsset?

    func findByFrameID(_ frameID: UUID) async throws -> [MediaAsset]

    func findByObjectKey(_ objectKey: String) async throws -> MediaAsset?

    func findPendingUpload(objectKey: String) async throws -> MediaAsset?

    func findUploadedMedia(userID: UUID, projectIDs: [UUID]) async throws -> [MediaAsset]

    func delete(_ asset: MediaAsset) async throws
}
