import Vapor

struct AppleTokenVerifier {
    let application: Application

    func verify(identityToken: String) async throws -> AppleIdentityPayload {
        // Temporary placeholder.
        // Next step: verify signature using Apple's public JWKS.
        throw Abort(.notImplemented, reason: "Apple token verification not implemented yet")
    }
}