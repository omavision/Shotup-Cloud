import Fluent
import Vapor

struct UserDTO: Content {
    let id: UUID?
    let appleUserID: String?
    let email: String?
    let displayName: String?
    let createdAt: Date
    let updatedAt: Date

    init(user: User) throws {
        self.id = try user.requireID()
        self.appleUserID = user.appleUserID
        self.email = user.email
        self.displayName = user.displayName
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}