import Vapor

struct UserService {
    let repository: UserRepository

    func findUser(id: UUID) async throws -> UserDTO? {
        guard let user = try await repository.find(id: id) else {
            return nil
        }

        return try UserDTO(user: user)
    }

    func createUser(from request: CreateUserRequest) async throws -> UserDTO {
        let user = User(
            appleUserID: request.appleUserID,
            email: request.email,
            displayName: request.displayName
        )

        let savedUser = try await repository.create(user)
        return try UserDTO(user: savedUser)
    }
}