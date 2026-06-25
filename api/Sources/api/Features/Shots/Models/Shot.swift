import Fluent
import Vapor

final class Shot: Model, Content, @unchecked Sendable {
    static let schema = "shots"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "scene_id")
    var scene: Scene

    @Field(key: "title")
    var title: String

    @Field(key: "notes")
    var notes: String?

    @Field(key: "shot_size")
    var shotSize: String?

    @Field(key: "camera_movement")
    var cameraMovement: String?

    @Field(key: "lens_mm")
    var lensMM: Double?

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
        sceneID: UUID,
        title: String,
        notes: String? = nil,
        shotSize: String? = nil,
        cameraMovement: String? = nil,
        lensMM: Double? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.$scene.id = sceneID
        self.title = title
        self.notes = notes
        self.shotSize = shotSize
        self.cameraMovement = cameraMovement
        self.lensMM = lensMM
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}