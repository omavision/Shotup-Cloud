import Vapor

struct UserService {
    let repository: UserRepository

    func findUser(id: UUID) async throws -> UserDTO? {
        guard let user = try await repository.find(id: id) else {
            return nil
        }

        return try UserDTO(user: user)
    }
}