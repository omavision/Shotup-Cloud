import Vapor

struct ScenePayload: Content {
    let name: String
    let order: Int
}