import Foundation
import Vapor

struct AppleTokenVerifier {
    let application: Application

    func verify(identityToken: String) async throws -> AppleIdentityPayload {
        let header = try decodeHeader(from: identityToken)
        let jwks = try await fetchAppleJWKS()

        guard jwks.keys.contains(where: { $0.kid == header.kid }) else {
            throw Abort(.unauthorized, reason: "Matching Apple public key not found")
        }

        throw Abort(.notImplemented, reason: "Apple key selected. Signature verification not implemented yet.")
    }

    private func fetchAppleJWKS() async throws -> AppleJWKSResponse {
        try await application.client
            .get("https://appleid.apple.com/auth/keys")
            .content
            .decode(AppleJWKSResponse.self)
    }

    private func decodeHeader(from token: String) throws -> JWTHeader {
        let parts = token.split(separator: ".")

        guard parts.count == 3 else {
            throw Abort(.unauthorized, reason: "Invalid Apple identity token")
        }

        let headerPart = String(parts[0])
        let padded = headerPart.padding(
            toLength: ((headerPart.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )

        guard let data = Data(base64Encoded: padded) else {
            throw Abort(.unauthorized, reason: "Invalid Apple token header")
        }

        return try JSONDecoder().decode(JWTHeader.self, from: data)
    }
}