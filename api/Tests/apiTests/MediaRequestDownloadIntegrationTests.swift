@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaRequestDownloadIntegrationTests: XCTestCase {
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

    func testRequestDownloadSucceedsForOwnedUploadedAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.download.owner")
            let frame = try await seedFrame(app, userID: owner.userID)
            let asset = try await seedUploadedAsset(
                app,
                frame: frame,
                objectKey: "download-success-key.jpg"
            )

            try await app.test(
                .POST,
                "api/v1/media/request-download",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(RequestDownloadRequest(frameID: frame.shotID))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<RequestDownloadResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.objectKey, asset.objectKey)
                    XCTAssertNotNil(body.data?.downloadURL)
                    XCTAssertGreaterThan(body.data?.expiresAt ?? .distantPast, Date())
                }
            )
        }
    }

    func testRequestDownloadReturnsNotFoundForMissingAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.download.missing")

            try await app.test(
                .POST,
                "api/v1/media/request-download",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(RequestDownloadRequest(frameID: UUID()))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testRequestDownloadReturnsForbiddenForUnauthorizedAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.download.owner.2")
            let frame = try await seedFrame(app, userID: owner.userID)
            _ = try await seedUploadedAsset(
                app,
                frame: frame,
                objectKey: "download-unauthorized-key.jpg"
            )

            let intruder = try await devLogin(app, appleUserID: "dev.download.intruder")

            try await app.test(
                .POST,
                "api/v1/media/request-download",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: intruder.accessToken)
                    try req.content.encode(RequestDownloadRequest(frameID: frame.shotID))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .forbidden)
                }
            )
        }
    }

    func testRequestDownloadReturnsConflictForPendingAsset() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.download.pending")
            let frame = try await seedFrame(app, userID: owner.userID)
            let repository = FluentMediaRepository(database: app.db)
            _ = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "download-pending-key.jpg",
                bucket: R2Configuration.devBucket,
                mimeType: "image/jpeg"
            )

            try await app.test(
                .POST,
                "api/v1/media/request-download",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(RequestDownloadRequest(frameID: frame.shotID))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }

    func testRequestDownloadReturnsUnauthorizedForInvalidJWT() async throws {
        try await withApp { app in
            try await app.test(
                .POST,
                "api/v1/media/request-download",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(RequestDownloadRequest(frameID: UUID()))
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
                        displayName: "Request Download Test User"
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
        let project = Project(userID: userID, title: "Request Download Test Project")
        try await project.save(on: app.db)
        let projectID = try XCTUnwrap(project.id)

        let scene = Scene(projectID: projectID, title: "Request Download Test Scene")
        try await scene.save(on: app.db)
        let sceneID = try XCTUnwrap(scene.id)

        let shot = Shot(sceneID: sceneID, title: "Request Download Test Shot")
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
