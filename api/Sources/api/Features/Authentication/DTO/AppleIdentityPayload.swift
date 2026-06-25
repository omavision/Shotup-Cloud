import JWT
import Vapor

struct AppleIdentityPayload: JWTPayload {
    var issuer: IssuerClaim
    var subject: SubjectClaim
    var audience: AudienceClaim
    var expiration: ExpirationClaim
    var email: String?

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()

        guard issuer.value == "https://appleid.apple.com" else {
            throw Abort(.unauthorized, reason: "Invalid Apple token issuer")
        }
    }
}