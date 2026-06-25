import JWT
import Vapor

struct AuthTokenPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var userID: UUID

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}