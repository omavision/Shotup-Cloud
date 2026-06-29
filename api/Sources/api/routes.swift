import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")
    let v1 = api.grouped("v1")

    try v1.register(collection: HealthController())

    let auth = v1.grouped("auth")
    try auth.register(collection: AuthController())

    let protected = v1.grouped(JWTAuthenticator())

    let me = protected.grouped("me")
    try me.register(collection: MeController())

    let users = protected.grouped("users")
    try users.register(collection: UserController())

    let projects = protected.grouped("projects")
    try projects.register(collection: ProjectController())

    let projectScenes = protected.grouped("projects", ":projectID", "scenes")
    try projectScenes.register(collection: SceneController())

    let sync = protected.grouped("sync")
    try sync.register(collection: SyncController())

    let media = protected.grouped("media")
    try media.register(collection: MediaController())
}