import Fluent
import JWT
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("dev-login", use: devLogin)
        routes.post("refresh", use: refresh)
        routes.post("apple", use: appleSignIn)
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

        return try await issueAuthResponse(
            for: user,
            request: req,
            deviceName: "Development Device"
        )
    }

    @Sendable
    func refresh(req: Request) async throws -> APIResponse<AuthResponse> {
        let request = try req.content.decode(RefreshTokenRequest.self)

        let rotated = try await RefreshTokenService(database: req.db)
            .rotateRefreshToken(request.refreshToken, deviceName: "Development Device")

        return try await issueAuthResponse(
            for: rotated.user,
            request: req,
            refreshToken: rotated.refreshToken
        )
    }

    @Sendable
    func appleSignIn(req: Request) async throws -> APIResponse<AuthResponse> {
        let request = try req.content.decode(AppleSignInRequest.self)

        let applePayload = try await AppleTokenVerifier(application: req.application)
            .verify(identityToken: request.identityToken)

        let userRepository = UserRepository(database: req.db)

        let user: User
        if let existingUser = try await userRepository.findByAppleUserID(applePayload.subject.value) {
            existingUser.email = applePayload.email ?? existingUser.email
            existingUser.displayName = request.displayName ?? existingUser.displayName
            user = try await userRepository.update(existingUser)
        } else {
            user = try await userRepository.create(
                User(
                    appleUserID: applePayload.subject.value,
                    email: applePayload.email,
                    displayName: request.displayName
                )
            )
        }

        return try await issueAuthResponse(
            for: user,
            request: req,
            deviceName: request.deviceName
        )
    }

    private func issueAuthResponse(
        for user: User,
        request req: Request,
        deviceName: String? = nil,
        refreshToken existingRefreshToken: String? = nil
    ) async throws -> APIResponse<AuthResponse> {
        let accessToken = try await JWTService(application: req.application)
            .signAccessToken(for: user)

        let refreshToken: String
        if let existingRefreshToken {
            refreshToken = existingRefreshToken
        } else {
            refreshToken = try await RefreshTokenService(database: req.db)
                .createRefreshToken(for: user, deviceName: deviceName)
        }

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