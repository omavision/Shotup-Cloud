import Fluent
import Vapor

enum MediaAssetStatus: String {
    case pending
    case uploaded
}

final class MediaAsset: Model, Content, @unchecked Sendable {
    static let schema = "media_assets"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user_id")
    var userID: UUID

    @Field(key: "project_id")
    var projectID: UUID

    @Field(key: "scene_id")
    var sceneID: UUID

    @Field(key: "shot_id")
    var shotID: UUID

    @Field(key: "object_key")
    var objectKey: String

    @Field(key: "bucket")
    var bucket: String

    @Field(key: "mime_type")
    var mimeType: String

    @Field(key: "size_bytes")
    var sizeBytes: Int64

    @Field(key: "checksum")
    var checksum: String?

    @Field(key: "status")
    var status: String

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "updated_at")
    var updatedAt: Date

    @Field(key: "uploaded_at")
    var uploadedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        objectKey: String,
        bucket: String,
        mimeType: String,
        sizeBytes: Int64 = 0,
        checksum: String? = nil,
        status: MediaAssetStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        uploadedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.projectID = projectID
        self.sceneID = sceneID
        self.shotID = shotID
        self.objectKey = objectKey
        self.bucket = bucket
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.checksum = checksum
        self.status = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.uploadedAt = uploadedAt
    }
}
