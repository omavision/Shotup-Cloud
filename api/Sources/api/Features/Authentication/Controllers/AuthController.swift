import Fluent
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("dev-login", use: devLogin)
    }

    @Sendable
    func devLogin(req: Request) async throws -> APIResponse<AuthResponse> {
        let request = try req.content.decode(DevLoginRequest.self)

        let userRepository = UserRepository(database: req.db)

        let user: User
        if let existingUser = try await userRepository.findByAppleUserID(request.appleUserID) {
            existingUser.email = request.email
            existingUser.displayName = request.displayName
            user = try await userRepository.update(existingUser)
        } else {
            user = try await userRepository.create(
                User(
                    appleUserID: request.appleUserID,
                    email: request.email,
                    displayName: request.displayName
                )
            )
        }

        let accessToken = try await JWTService(application: req.application)
            .signAccessToken(for: user)

        let refreshToken = try await RefreshTokenService(database: req.db)
            .createRefreshToken(for: user, deviceName: "Development Device")

        return APIResponse(
            data: AuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: "Bearer",
                expiresIn: 3600,
                user: try UserDTO(user: user)
            )
        )
    }
}