import Fluent
import Vapor

struct MediaManifestResponse: Content {
    let media: [MediaManifestItem]
}

struct MediaManifestItem: Content {
    let mediaAssetID: UUID
    let frameID: UUID
    let projectID: UUID
    let sceneID: UUID
    let objectKey: String
    let mimeType: String
    let sizeBytes: Int?
    let status: String
    let uploadedAt: Date?
    let updatedAt: Date?

    init(asset: MediaAsset) throws {
        self.mediaAssetID = try asset.requireID()
        self.frameID = asset.shotID
        self.projectID = asset.projectID
        self.sceneID = asset.sceneID
        self.objectKey = asset.objectKey
        self.mimeType = asset.mimeType
        self.sizeBytes = Int(asset.sizeBytes)
        self.status = asset.status
        self.uploadedAt = asset.uploadedAt
        self.updatedAt = asset.updatedAt
    }
}
