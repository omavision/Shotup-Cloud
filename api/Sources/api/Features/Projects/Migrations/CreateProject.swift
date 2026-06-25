import Fluent

struct CreateProject: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Project.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
            .field("title", .string, .required)
            .field("notes", .string)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Project.schema).delete()
    }
}