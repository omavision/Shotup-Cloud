import Fluent

struct CreateShot: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Shot.schema)
            .id()
            .field("scene_id", .uuid, .required, .references(Scene.schema, .id, onDelete: .cascade))
            .field("title", .string, .required)
            .field("notes", .string)
            .field("shot_size", .string)
            .field("camera_movement", .string)
            .field("lens_mm", .double)
            .field("sort_order", .int, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Shot.schema).delete()
    }
}