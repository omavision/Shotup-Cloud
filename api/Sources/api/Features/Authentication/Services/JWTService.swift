import Fluent
import JWT
import Vapor

struct JWTService {
    let application: Application

    func signAccessToken(for user: User) async throws -> String {
        let userID = try user.requireID()

        let payload = AuthTokenPayload(
            subject: SubjectClaim(value: userID.uuidString),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(60 * 60)),
            userID: userID
        )

        return try await application.jwt.keys.sign(payload)
    }
}