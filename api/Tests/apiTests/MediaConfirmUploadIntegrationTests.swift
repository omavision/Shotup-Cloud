@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaConfirmUploadIntegrationTests: XCTestCase {
    private func withApp(
        r2Status: HTTPStatus = .ok,
        _ test: (Application) async throws -> ()
    ) async throws {
        let app = try await Application.make(.testing)

        do {
            try await configure(app)
            let client = StubR2Client(eventLoop: app.eventLoopGroup.next(), status: r2Status)
            app.r2Storage = R2StorageService(configuration: testR2Configuration, client: client)
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

    func testConfirmUploadSucceedsForOwnedPendingAsset() async throws {
        try await withApp(r2Status: .ok) { app in
            let owner = try await devLogin(app, appleUserID: "dev.confirm.owner")
            let frame = try await seedFrame(app, userID: owner.userID)
            let pending = try await seedPendingAsset(app, frame: frame, objectKey: "confirm-success-key.jpg")

            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: pending.objectKey,
                            checksum: "sha256:abc",
                            size: 2_048,
                            mimeType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<ConfirmUploadResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.success, true)
                }
            )

            let updated = try await MediaAsset.find(pending.id, on: app.db)
            XCTAssertEqual(updated?.status, MediaAssetStatus.uploaded.rawValue)
            XCTAssertEqual(updated?.sizeBytes, 2_048)
            XCTAssertEqual(updated?.checksum, "sha256:abc")
            XCTAssertNotNil(updated?.uploadedAt)
        }
    }

    func testConfirmUploadReturnsNotFoundForMissingPendingAsset() async throws {
        try await withApp(r2Status: .ok) { app in
            let owner = try await devLogin(app, appleUserID: "dev.confirm.missing")

            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: "does-not-exist.jpg",
                            checksum: nil,
                            size: 1_024,
                            mimeType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testConfirmUploadReturnsForbiddenForUnauthorizedAsset() async throws {
        try await withApp(r2Status: .ok) { app in
            let owner = try await devLogin(app, appleUserID: "dev.confirm.owner.2")
            let frame = try await seedFrame(app, userID: owner.userID)
            let pending = try await seedPendingAsset(app, frame: frame, objectKey: "confirm-unauthorized-key.jpg")

            let intruder = try await devLogin(app, appleUserID: "dev.confirm.intruder")

            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: intruder.accessToken)
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: pending.objectKey,
                            checksum: nil,
                            size: 1_024,
                            mimeType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .forbidden)
                }
            )
        }
    }

    func testConfirmUploadReturnsNotFoundWhenObjectMissingInR2() async throws {
        try await withApp(r2Status: .notFound) { app in
            let owner = try await devLogin(app, appleUserID: "dev.confirm.missing.object")
            let frame = try await seedFrame(app, userID: owner.userID)
            let pending = try await seedPendingAsset(app, frame: frame, objectKey: "confirm-missing-object-key.jpg")

            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: pending.objectKey,
                            checksum: nil,
                            size: 1_024,
                            mimeType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testConfirmUploadReturnsBadRequestForInvalidMimeType() async throws {
        try await withApp(r2Status: .ok) { app in
            let owner = try await devLogin(app, appleUserID: "dev.confirm.badtype")
            let frame = try await seedFrame(app, userID: owner.userID)
            let pending = try await seedPendingAsset(app, frame: frame, objectKey: "confirm-badtype-key.jpg")

            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: pending.objectKey,
                            checksum: nil,
                            size: 1_024,
                            mimeType: "image/png"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                }
            )
        }
    }

    func testConfirmUploadReturnsUnauthorizedForInvalidJWT() async throws {
        try await withApp(r2Status: .ok) { app in
            try await app.test(
                .POST,
                "api/v1/media/confirm-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(
                        ConfirmUploadRequest(
                            objectKey: "irrelevant-key.jpg",
                            checksum: nil,
                            size: 1_024,
                            mimeType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .unauthorized)
                }
            )
        }
    }

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
                        displayName: "Confirm Upload Test User"
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
        let project = Project(userID: userID, title: "Confirm Upload Test Project")
        try await project.save(on: app.db)
        let projectID = try XCTUnwrap(project.id)

        let scene = Scene(projectID: projectID, title: "Confirm Upload Test Scene")
        try await scene.save(on: app.db)
        let sceneID = try XCTUnwrap(scene.id)

        let shot = Shot(sceneID: sceneID, title: "Confirm Upload Test Shot")
        try await shot.save(on: app.db)
        let shotID = try XCTUnwrap(shot.id)

        return SeededFrame(userID: userID, projectID: projectID, sceneID: sceneID, shotID: shotID)
    }

    private func seedPendingAsset(
        _ app: Application,
        frame: SeededFrame,
        objectKey: String
    ) async throws -> MediaAsset {
        let repository = FluentMediaRepository(database: app.db)
        return try await repository.upsertPendingUpload(
            userID: frame.userID,
            projectID: frame.projectID,
            sceneID: frame.sceneID,
            shotID: frame.shotID,
            objectKey: objectKey,
            bucket: R2Configuration.devBucket,
            mimeType: "image/jpeg"
        )
    }
}
