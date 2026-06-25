import Fluent
import Vapor

final class RefreshToken: Model, Content, @unchecked Sendable {
    static let schema = "refresh_tokens"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "token_hash")
    var tokenHash: String

    @Field(key: "device_name")
    var deviceName: String?

    @Field(key: "expires_at")
    var expiresAt: Date

    @Field(key: "revoked_at")
    var revokedAt: Date?

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        tokenHash: String,
        deviceName: String? = nil,
        expiresAt: Date,
        revokedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.deviceName = deviceName
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.createdAt = createdAt
    }
}