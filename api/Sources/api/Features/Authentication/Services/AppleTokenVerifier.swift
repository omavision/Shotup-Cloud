import Vapor

struct AppleTokenVerifier {
    let application: Application

    func verify(identityToken: String) async throws -> AppleIdentityPayload {
        let jwks = try await fetchAppleJWKS()

        guard !jwks.keys.isEmpty else {
            throw Abort(.unauthorized, reason: "Apple public keys unavailable")
        }

        // Next step: select key by JWT header kid and verify signature.
        throw Abort(.notImplemented, reason: "Apple JWKS fetched. Signature verification not implemented yet.")
    }

    private func fetchAppleJWKS() async throws -> AppleJWKSResponse {
        try await application.client
            .get("https://appleid.apple.com/auth/keys")
            .content
            .decode(AppleJWKSResponse.self)
    }
}