import Vapor

func routes(_ app: Application) throws {

    let api = app.grouped("api")
    let v1 = api.grouped("v1")

    try v1.register(collection: HealthController())
}