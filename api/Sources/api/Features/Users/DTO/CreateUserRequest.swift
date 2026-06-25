import Vapor

struct CreateUserRequest: Content {
    let appleUserID: String?
    let email: String?
    let displayName: String?
}