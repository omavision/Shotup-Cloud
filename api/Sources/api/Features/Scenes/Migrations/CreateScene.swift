import Fluent

struct CreateScene: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Scene.schema)
            .id()
            .field("project_id", .uuid, .required, .references(Project.schema, .id, onDelete: .cascade))
            .field("title", .string, .required)
            .field("notes", .string)
            .field("sort_order", .int, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Scene.schema).delete()
    }
}