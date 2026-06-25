import Vapor

struct DevLoginRequest: Content {
    let appleUserID: String
    let email: String?
    let displayName: String?
}