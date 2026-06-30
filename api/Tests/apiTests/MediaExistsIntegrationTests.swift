@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaExistsIntegrationTests: XCTestCase {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)

        do {
            try await configure(app)
            app.r2Storage = R2StorageService(configuration: testR2Configuration)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }

    func testExistsReturnsTrueForUploadedAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.exists.owner")
            let frame = try await seedFrame(app, userID: owner.userID)
            let asset = try await seedUploadedAsset(
                app,
                frame: frame,
                objectKey: "exists-true-key.jpg"
            )

            try await app.test(
                .POST,
                "api/v1/media/exists",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaExistsRequest(frameID: frame.shotID))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaExistsResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.exists, true)
                    XCTAssertEqual(body.data?.mediaAssetID, asset.id)
                    XCTAssertEqual(body.data?.objectKey, asset.objectKey)
                    XCTAssertEqual(body.data?.status, MediaAssetStatus.uploaded.rawValue)
                }
            )
        }
    }

    func testExistsReturnsFalseForMissingAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.exists.missing")

            try await app.test(
                .POST,
                "api/v1/media/exists",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaExistsRequest(frameID: UUID()))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaExistsResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.exists, false)
                    XCTAssertNil(body.data?.mediaAssetID)
                    XCTAssertNil(body.data?.objectKey)
                    XCTAssertNil(body.data?.status)
                }
            )
        }
    }

    func testExistsReturnsForbiddenForUnauthorizedAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.exists.owner.2")
            let frame = try await seedFrame(app, userID: owner.userID)
            _ = try await seedUploadedAsset(
                app,
                frame: frame,
                objectKey: "exists-unauthorized-key.jpg"
            )

            let intruder = try await devLogin(app, appleUserID: "dev.exists.intruder")

            try await app.test(
                .POST,
                "api/v1/media/exists",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: intruder.accessToken)
                    try req.content.encode(MediaExistsRequest(frameID: frame.shotID))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .forbidden)
                }
            )
        }
    }

    func testExistsReturnsUnauthorizedForInvalidJWT() async throws {
        try await withApp { app in
            try await app.test(
                .POST,
                "api/v1/media/exists",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(MediaExistsRequest(frameID: UUID()))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .unauthorized)
                }
            )
        }
    }

    // MARK: - Helpers

    private var testR2Configuration: R2Configuration {
        R2Configuration(
            accountID: "test-account",
            accessKeyID: "test-access-key",
            secretAccessKey: "test-secret-key",
            bucket: R2Configuration.devBucket,
            endpoint: "https://test-account.r2.cloudflarestorage.com"
        )
    }

    private struct LoggedInUser {
        let userID: UUID
        let accessToken: String
    }

    private func devLogin(
        _ app: Application,
        appleUserID: String
    ) async throws -> LoggedInUser {
        var loggedInUser: LoggedInUser?

        try await app.test(
            .POST,
            "api/v1/auth/dev-login",
            beforeRequest: { req in
                try req.content.encode(
                    DevLoginRequest(
                        appleUserID: appleUserID,
                        email: "\(appleUserID)@shotup.cc",
                        displayName: "Media Exists Test User"
                    )
                )
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(APIResponse<AuthResponse>.self)
                XCTAssertTrue(body.success)
                let data = try XCTUnwrap(body.data)
                let userID = try XCTUnwrap(data.user.id)
                loggedInUser = LoggedInUser(userID: userID, accessToken: data.accessToken)
            }
        )

        return try XCTUnwrap(loggedInUser)
    }

    private struct SeededFrame {
        let userID: UUID
        let projectID: UUID
        let sceneID: UUID
        let shotID: UUID
    }

    private func seedFrame(_ app: Application, userID: UUID) async throws -> SeededFrame {
        let project = Project(userID: userID, title: "Media Exists Test Project")
        try await project.save(on: app.db)
        let projectID = try XCTUnwrap(project.id)

        let scene = Scene(projectID: projectID, title: "Media Exists Test Scene")
        try await scene.save(on: app.db)
        let sceneID = try XCTUnwrap(scene.id)

        let shot = Shot(sceneID: sceneID, title: "Media Exists Test Shot")
        try await shot.save(on: app.db)
        let shotID = try XCTUnwrap(shot.id)

        return SeededFrame(userID: userID, projectID: projectID, sceneID: sceneID, shotID: shotID)
    }

    private func seedUploadedAsset(
        _ app: Application,
        frame: SeededFrame,
        objectKey: String
    ) async throws -> MediaAsset {
        let repository = FluentMediaRepository(database: app.db)
        _ = try await repository.upsertPendingUpload(
            userID: frame.userID,
            projectID: frame.projectID,
            sceneID: frame.sceneID,
            shotID: frame.shotID,
            objectKey: objectKey,
            bucket: R2Configuration.devBucket,
            mimeType: "image/jpeg"
        )

        let uploaded = try await repository.markUploaded(
            objectKey: objectKey,
            sizeBytes: 2_048,
            checksum: "sha256:abc",
            uploadedAt: Date()
        )

        return try XCTUnwrap(uploaded)
    }
}
