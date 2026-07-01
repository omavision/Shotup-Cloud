import Vapor

struct MediaManifestService {
    let repository: any MediaRepository

    func manifest(
        userID: UUID,
        payload: MediaManifestRequest
    ) async throws -> MediaManifestResponse {
        guard payload.projectIDs.isEmpty == false else {
            return MediaManifestResponse(media: [])
        }

        let assets = try await repository.findUploadedMedia(
            userID: userID,
            projectIDs: payload.projectIDs
        )

        return try MediaManifestResponse(
            media: assets.map { try MediaManifestItem(asset: $0) }
        )
    }
}
