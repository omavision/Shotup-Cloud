import Vapor

struct AuthenticatedUser: Authenticatable {
    let id: UUID
}