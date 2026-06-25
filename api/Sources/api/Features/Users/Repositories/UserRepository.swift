import Fluent
import Vapor

struct UserRepository {
    let database: any Database

    func find(id: UUID) async throws -> User? {
        try await User.find(id, on: database)
    }

    func findByAppleUserID(_ appleUserID: String) async throws -> User? {
        try await User.query(on: database)
            .filter(\.$appleUserID == appleUserID)
            .first()
    }

    func create(_ user: User) async throws -> User {
        try await user.save(on: database)
        return user
    }

    func update(_ user: User) async throws -> User {
        user.updatedAt = Date()
        try await user.update(on: database)
        return user
    }
}