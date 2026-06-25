import Fluent
import JWT
import Vapor

struct JWTAuthenticator: AsyncBearerAuthenticator {
    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        let payload = try await request.application.jwt.keys.verify(
            bearer.token,
            as: AuthTokenPayload.self
        )

        request.auth.login(AuthenticatedUser(id: payload.userID))
    }
}