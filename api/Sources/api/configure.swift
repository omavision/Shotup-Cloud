import Foundation
import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

/// Configures your application.
func configure(_ app: Application) async throws {
    // Uncomment to serve files from /Public folder.
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.postgres(
        configuration: .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? "shotup",
            password: Environment.get("DATABASE_PASSWORD") ?? "shotup_dev_password",
            database: Environment.get("DATABASE_NAME") ?? "shotup_cloud_dev",
            tls: .prefer(try .init(configuration: .clientDefault))
        )
    ), as: .psql)

    // Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateProject())
    app.migrations.add(CreateScene())
    app.migrations.add(CreateShot())
    app.migrations.add(CreateRefreshToken())

   // JWT
let jwtSecret = Environment.get("JWT_SECRET") ?? "development-secret"

await app.jwt.keys.add(
    hmac: HMACKey(from: Data(jwtSecret.utf8)),
    digestAlgorithm: .sha256
)

    // Routes
    try routes(app)
}