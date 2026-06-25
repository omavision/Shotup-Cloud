import Fluent
import Vapor

final class Scene: Model, Content, @unchecked Sendable {
    static let schema = "scenes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Field(key: "title")
    var title: String

    @Field(key: "notes")
    var notes: String?

    @Field(key: "sort_order")
    var sortOrder: Int

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "updated_at")
    var updatedAt: Date

    @Field(key: "deleted_at")
    var deletedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        projectID: UUID,
        title: String,
        notes: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.$project.id = projectID
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}