import Fluent
import SQLKit

struct CreateSyncEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(SyncEvent.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
            .field("entity", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("operation", .string, .required)
            .field("sequence", .int64, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "sequence")
            .create()

        let sql = database as! any SQLDatabase
        try await sql.raw("CREATE INDEX sync_events_user_id_sequence_idx ON sync_events (user_id, sequence)").run()
        try await sql.raw("CREATE INDEX sync_events_entity_entity_id_idx ON sync_events (entity, entity_id)").run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(SyncEvent.schema).delete()
    }
}
