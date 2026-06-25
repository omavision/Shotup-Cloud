import Vapor

struct ShotPayload: Content {
    let name: String
    let order: Int
}