import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")
    let v1 = api.grouped("v1")

    try v1.register(collection: HealthController())

    let users = v1.grouped("users")
    try users.register(collection: UserController())

    let projects = v1.grouped("projects")
    try projects.register(collection: ProjectController())
}