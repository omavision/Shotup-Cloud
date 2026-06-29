import Fluent

struct CreateMediaAsset: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(MediaAsset.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
            .field("project_id", .uuid, .required, .references(Project.schema, .id, onDelete: .cascade))
            .field("scene_id", .uuid, .required, .references(Scene.schema, .id, onDelete: .cascade))
            .field("shot_id", .uuid, .required, .references(Shot.schema, .id, onDelete: .cascade))
            .field("object_key", .string, .required)
            .field("bucket", .string, .required)
            .field("mime_type", .string, .required)
            .field("size_bytes", .int64, .required)
            .field("checksum", .string)
            .field("status", .string, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("uploaded_at", .datetime)
            .unique(on: "object_key")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(MediaAsset.schema).delete()
    }
}
