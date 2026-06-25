import Fluent
import Vapor

final class SyncEvent: Model, Content, @unchecked Sendable {
    static let schema = "sync_events"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "entity")
    var entity: String

    @Field(key: "entity_id")
    var entityID: UUID

    @Field(key: "operation")
    var operation: String

    @Field(key: "sequence")
    var sequence: Int64

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        entity: String,
        entityID: UUID,
        operation: String,
        sequence: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.$user.id = userID
        self.entity = entity
        self.entityID = entityID
        self.operation = operation
        self.sequence = sequence
        self.createdAt = createdAt
    }
}
