@testable import api
import Fluent
import Vapor
import XCTVapor

final class SyncStatusIntegrationTests: XCTestCase {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)

        do {
            try await configure(app)
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

    func testEmptyUserReturnsZeroCountsAndNilDates() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.status.empty")

            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncStatusResponse>.self)
                    XCTAssertTrue(body.success)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projectCount, 0)
                    XCTAssertEqual(data.sceneCount, 0)
                    XCTAssertEqual(data.shotCount, 0)
                    XCTAssertEqual(data.mediaAssetCount, 0)
                    XCTAssertEqual(data.uploadedMediaCount, 0)
                    XCTAssertEqual(data.pendingMediaCount, 0)
                    XCTAssertNil(data.lastMetadataUpdate)
                    XCTAssertNil(data.lastMediaUpload)
                }
            )
        }
    }

    func testUserWithMetadataAndMediaReturnsCorrectCounts() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.status.counts")
            let firstProject = try await seedProject(app, userID: owner.userID, updatedAt: date(100))
            let secondProject = try await seedProject(app, userID: owner.userID, updatedAt: date(200))
            let firstScene = try await seedScene(app, projectID: firstProject, updatedAt: date(300))
            let secondScene = try await seedScene(app, projectID: secondProject, updatedAt: date(400))
            let firstShot = try await seedShot(app, sceneID: firstScene, updatedAt: date(500))
            let secondShot = try await seedShot(app, sceneID: secondScene, updatedAt: date(450))
            try await seedMediaAsset(app, userID: owner.userID, projectID: firstProject, sceneID: firstScene, shotID: firstShot, key: "status-uploaded-1.jpg", status: .uploaded, uploadedAt: date(600))
            try await seedMediaAsset(app, userID: owner.userID, projectID: secondProject, sceneID: secondScene, shotID: secondShot, key: "status-uploaded-2.jpg", status: .uploaded, uploadedAt: date(700))
            try await seedMediaAsset(app, userID: owner.userID, projectID: firstProject, sceneID: firstScene, shotID: firstShot, key: "status-pending.jpg", status: .pending)

            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncStatusResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projectCount, 2)
                    XCTAssertEqual(data.sceneCount, 2)
                    XCTAssertEqual(data.shotCount, 2)
                    XCTAssertEqual(data.mediaAssetCount, 3)
                    XCTAssertEqual(data.uploadedMediaCount, 2)
                    XCTAssertEqual(data.pendingMediaCount, 1)
                    XCTAssertEqualSeconds(data.lastMetadataUpdate, 500)
                    XCTAssertEqualSeconds(data.lastMediaUpload, 700)
                }
            )
        }
    }

    func testOtherUsersDataIsExcluded() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.status.owner")
            let other = try await devLogin(app, appleUserID: "dev.status.other")

            let ownerProject = try await seedProject(app, userID: owner.userID)
            let ownerScene = try await seedScene(app, projectID: ownerProject)
            let ownerShot = try await seedShot(app, sceneID: ownerScene)
            try await seedMediaAsset(app, userID: owner.userID, projectID: ownerProject, sceneID: ownerScene, shotID: ownerShot, key: "status-owner.jpg", status: .uploaded)

            let otherProject = try await seedProject(app, userID: other.userID)
            let otherScene = try await seedScene(app, projectID: otherProject)
            let otherShot = try await seedShot(app, sceneID: otherScene)
            try await seedMediaAsset(app, userID: other.userID, projectID: otherProject, sceneID: otherScene, shotID: otherShot, key: "status-other.jpg", status: .uploaded)

            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncStatusResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projectCount, 1)
                    XCTAssertEqual(data.sceneCount, 1)
                    XCTAssertEqual(data.shotCount, 1)
                    XCTAssertEqual(data.mediaAssetCount, 1)
                    XCTAssertEqual(data.uploadedMediaCount, 1)
                    XCTAssertEqual(data.pendingMediaCount, 0)
                }
            )
        }
    }

    func testPendingAndUploadedMediaCountsAreSeparated() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.status.media.counts")
            let frame = try await seedFrame(app, userID: owner.userID)
            try await seedMediaAsset(app, frame: frame, key: "status-uploaded-a.jpg", status: .uploaded, uploadedAt: date(100))
            try await seedMediaAsset(app, frame: frame, key: "status-uploaded-b.jpg", status: .uploaded, uploadedAt: date(200))
            try await seedMediaAsset(app, frame: frame, key: "status-pending-a.jpg", status: .pending)
            try await seedMediaAsset(app, frame: frame, key: "status-pending-b.jpg", status: .pending)

            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncStatusResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.mediaAssetCount, 4)
                    XCTAssertEqual(data.uploadedMediaCount, 2)
                    XCTAssertEqual(data.pendingMediaCount, 2)
                    XCTAssertEqualSeconds(data.lastMediaUpload, 200)
                }
            )
        }
    }

    func testSoftDeletedMetadataIsExcluded() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.status.deleted")
            let activeProject = try await seedProject(app, userID: owner.userID, updatedAt: date(100))
            let deletedProject = try await seedProject(app, userID: owner.userID, updatedAt: date(900), deletedAt: date(901))
            let activeScene = try await seedScene(app, projectID: activeProject, updatedAt: date(200))
            let deletedScene = try await seedScene(app, projectID: activeProject, updatedAt: date(800), deletedAt: date(801))
            let sceneUnderDeletedProject = try await seedScene(app, projectID: deletedProject, updatedAt: date(700))
            let activeShot = try await seedShot(app, sceneID: activeScene, updatedAt: date(300))
            _ = try await seedShot(app, sceneID: activeScene, updatedAt: date(600), deletedAt: date(601))
            _ = try await seedShot(app, sceneID: deletedScene, updatedAt: date(500))
            _ = try await seedShot(app, sceneID: sceneUnderDeletedProject, updatedAt: date(400))
            try await seedMediaAsset(app, userID: owner.userID, projectID: activeProject, sceneID: activeScene, shotID: activeShot, key: "status-deleted-media.jpg", status: .uploaded)

            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncStatusResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projectCount, 1)
                    XCTAssertEqual(data.sceneCount, 1)
                    XCTAssertEqual(data.shotCount, 1)
                    XCTAssertEqual(data.mediaAssetCount, 1)
                    XCTAssertEqualSeconds(data.lastMetadataUpdate, 300)
                }
            )
        }
    }

    func testInvalidJWTReturnsUnauthorized() async throws {
        try await withApp { app in
            try await app.test(
                .GET,
                "api/v1/sync/status",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .unauthorized)
                }
            )
        }
    }

    private struct LoggedInUser {
        let userID: UUID
        let accessToken: String
    }

    private struct SeededFrame {
        let userID: UUID
        let projectID: UUID
        let sceneID: UUID
        let shotID: UUID
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
                        displayName: "Sync Status Test User"
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

    private func seedFrame(_ app: Application, userID: UUID) async throws -> SeededFrame {
        let projectID = try await seedProject(app, userID: userID)
        let sceneID = try await seedScene(app, projectID: projectID)
        let shotID = try await seedShot(app, sceneID: sceneID)
        return SeededFrame(userID: userID, projectID: projectID, sceneID: sceneID, shotID: shotID)
    }

    private func seedProject(
        _ app: Application,
        userID: UUID,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) async throws -> UUID {
        let project = Project(
            userID: userID,
            title: "Sync Status Project",
            createdAt: Date(timeInterval: -60, since: updatedAt),
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
        try await project.save(on: app.db)
        return try XCTUnwrap(project.id)
    }

    private func seedScene(
        _ app: Application,
        projectID: UUID,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) async throws -> UUID {
        let scene = Scene(
            projectID: projectID,
            title: "Sync Status Scene",
            createdAt: Date(timeInterval: -60, since: updatedAt),
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
        try await scene.save(on: app.db)
        return try XCTUnwrap(scene.id)
    }

    private func seedShot(
        _ app: Application,
        sceneID: UUID,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) async throws -> UUID {
        let shot = Shot(
            sceneID: sceneID,
            title: "Sync Status Shot",
            createdAt: Date(timeInterval: -60, since: updatedAt),
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
        try await shot.save(on: app.db)
        return try XCTUnwrap(shot.id)
    }

    private func seedMediaAsset(
        _ app: Application,
        frame: SeededFrame,
        key: String,
        status: MediaAssetStatus,
        uploadedAt: Date? = Date()
    ) async throws {
        try await seedMediaAsset(
            app,
            userID: frame.userID,
            projectID: frame.projectID,
            sceneID: frame.sceneID,
            shotID: frame.shotID,
            key: key,
            status: status,
            uploadedAt: uploadedAt
        )
    }

    private func seedMediaAsset(
        _ app: Application,
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        key: String,
        status: MediaAssetStatus,
        uploadedAt: Date? = Date()
    ) async throws {
        let effectiveUploadedAt = status == .uploaded ? uploadedAt : nil
        let asset = MediaAsset(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            shotID: shotID,
            objectKey: key,
            bucket: R2Configuration.devBucket,
            mimeType: "image/jpeg",
            sizeBytes: 1_024,
            status: status,
            updatedAt: effectiveUploadedAt ?? Date(),
            uploadedAt: effectiveUploadedAt
        )
        try await asset.save(on: app.db)
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private func XCTAssertEqualSeconds(
        _ actual: Date?,
        _ expectedSeconds: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected date, got nil", file: file, line: line)
            return
        }

        XCTAssertEqual(actual.timeIntervalSince1970, expectedSeconds, accuracy: 0.001, file: file, line: line)
    }
}
