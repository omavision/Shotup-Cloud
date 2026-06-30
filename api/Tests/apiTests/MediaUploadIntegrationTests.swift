@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaUploadIntegrationTests: XCTestCase {
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

    func testRequestUploadSucceedsForOwnedFrame() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.owner")
            let frame = try await seedProjectSceneShot(app, userID: owner.userID)
            var capturedObjectKey: String?

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: frame.projectID,
                            sceneID: frame.sceneID,
                            frameID: frame.shotID,
                            contentType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<RequestUploadResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.requiredHeaders["Content-Type"], "image/jpeg")
                    XCTAssertTrue(body.data?.objectKey.contains(frame.shotID.uuidString.lowercased()) ?? false)
                    XCTAssertNotNil(body.data?.uploadURL)
                    capturedObjectKey = body.data?.objectKey
                }
            )

            let objectKey = try XCTUnwrap(capturedObjectKey)
            let asset = try await MediaAsset.query(on: app.db)
                .filter(\.$objectKey == objectKey)
                .first()

            XCTAssertNotNil(asset)
            XCTAssertEqual(asset?.status, MediaAssetStatus.pending.rawValue)
            XCTAssertEqual(asset?.sizeBytes, 0)
            XCTAssertNil(asset?.checksum)
            XCTAssertNil(asset?.uploadedAt)
            XCTAssertEqual(asset?.shotID, frame.shotID)
        }
    }

    func testRequestUploadUpsertsPendingAssetOnRepeat() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.upsert")
            let frame = try await seedProjectSceneShot(app, userID: owner.userID)

            let request = RequestUploadRequest(
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                frameID: frame.shotID,
                contentType: "image/jpeg"
            )

            for _ in 1...2 {
                try await app.test(
                    .POST,
                    "api/v1/media/request-upload",
                    beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                        try req.content.encode(request)
                    },
                    afterResponse: { res async throws in
                        XCTAssertEqual(res.status, .ok)
                    }
                )
            }

            let assets = try await MediaAsset.query(on: app.db)
                .filter(\.$shotID == frame.shotID)
                .all()

            XCTAssertEqual(assets.count, 1)
            XCTAssertEqual(assets.first?.status, MediaAssetStatus.pending.rawValue)
        }
    }

    func testRequestUploadReturnsNotFoundForMissingProject() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.missing.project")

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: UUID(),
                            sceneID: UUID(),
                            frameID: UUID(),
                            contentType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testRequestUploadReturnsNotFoundForMissingScene() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.missing.scene")
            let projectID = try await makeProject(app, userID: owner.userID)

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: projectID,
                            sceneID: UUID(),
                            frameID: UUID(),
                            contentType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testRequestUploadReturnsNotFoundForMissingFrame() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.missing.frame")
            let projectID = try await makeProject(app, userID: owner.userID)
            let sceneID = try await makeScene(app, projectID: projectID)

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: projectID,
                            sceneID: sceneID,
                            frameID: UUID(),
                            contentType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testRequestUploadReturnsForbiddenForUnauthorizedProject() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.owner.2")
            let frame = try await seedProjectSceneShot(app, userID: owner.userID)

            let intruder = try await devLogin(app, appleUserID: "dev.media.intruder")

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: intruder.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: frame.projectID,
                            sceneID: frame.sceneID,
                            frameID: frame.shotID,
                            contentType: "image/jpeg"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .forbidden)
                }
            )
        }
    }

    func testRequestUploadReturnsBadRequestForInvalidContentType() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.media.badtype")
            let frame = try await seedProjectSceneShot(app, userID: owner.userID)

            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: frame.projectID,
                            sceneID: frame.sceneID,
                            frameID: frame.shotID,
                            contentType: "image/png"
                        )
                    )
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                }
            )
        }
    }

    func testRequestUploadReturnsUnauthorizedForInvalidJWT() async throws {
        try await withApp { app in
            try await app.test(
                .POST,
                "api/v1/media/request-upload",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(
                        RequestUploadRequest(
                            projectID: UUID(),
                            sceneID: UUID(),
                            frameID: UUID(),
                            contentType: "image/jpeg"
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
                        displayName: "Media Test User"
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
        let projectID: UUID
        let sceneID: UUID
        let shotID: UUID
    }

    private func seedProjectSceneShot(
        _ app: Application,
        userID: UUID
    ) async throws -> SeededFrame {
        let projectID = try await makeProject(app, userID: userID)
        let sceneID = try await makeScene(app, projectID: projectID)
        let shot = Shot(sceneID: sceneID, title: "Frame Shot")
        try await shot.save(on: app.db)

        return SeededFrame(
            projectID: projectID,
            sceneID: sceneID,
            shotID: try XCTUnwrap(shot.id)
        )
    }

    private func makeProject(_ app: Application, userID: UUID) async throws -> UUID {
        let project = Project(userID: userID, title: "Media Test Project")
        try await project.save(on: app.db)
        return try XCTUnwrap(project.id)
    }

    private func makeScene(_ app: Application, projectID: UUID) async throws -> UUID {
        let scene = Scene(projectID: projectID, title: "Media Test Scene")
        try await scene.save(on: app.db)
        return try XCTUnwrap(scene.id)
    }
}
