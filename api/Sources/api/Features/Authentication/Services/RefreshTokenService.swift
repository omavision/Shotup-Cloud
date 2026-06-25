import Crypto
import Fluent
import Vapor

struct RefreshTokenService {
    let database: any Database

    func createRefreshToken(for user: User, deviceName: String?) async throws -> String {
        let userID = try user.requireID()
        let rawToken = [UInt8].random(count: 32).base64
        let tokenHash = Self.hash(rawToken)

        let refreshToken = RefreshToken(
            userID: userID,
            tokenHash: tokenHash,
            deviceName: deviceName,
            expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 30)
        )

        try await refreshToken.save(on: database)
        return rawToken
    }

    func rotateRefreshToken(_ rawToken: String, deviceName: String?) async throws -> (user: User, refreshToken: String) {
        let tokenHash = Self.hash(rawToken)

        guard let existingToken = try await RefreshToken.query(on: database)
            .filter(\.$tokenHash == tokenHash)
            .filter(\.$revokedAt == nil)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }

        guard existingToken.expiresAt > Date() else {
            throw Abort(.unauthorized, reason: "Refresh token expired")
        }

        let user = try await existingToken.$user.get(on: database)

        existingToken.revokedAt = Date()
        try await existingToken.update(on: database)

        let newRefreshToken = try await createRefreshToken(
            for: user,
            deviceName: deviceName
        )

        return (user, newRefreshToken)
    }

    static func hash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}