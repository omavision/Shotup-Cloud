@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaManifestIntegrationTests: XCTestCase {
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

    func testManifestReturnsUploadedMediaForRequestedProjects() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.manifest.owner")
            let firstFrame = try await seedFrame(app, userID: owner.userID)
            let secondFrame = try await seedFrame(app, userID: owner.userID)
            let unrequestedFrame = try await seedFrame(app, userID: owner.userID)

            let laterAsset = try await seedMediaAsset(
                app,
                frame: firstFrame,
                objectKey: "manifest-later.jpg",
                status: .uploaded,
                uploadedAt: Date(timeIntervalSince1970: 200)
            )
            let earlierAsset = try await seedMediaAsset(
                app,
                frame: secondFrame,
                objectKey: "manifest-earlier.jpg",
                status: .uploaded,
                uploadedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try await seedMediaAsset(
                app,
                frame: unrequestedFrame,
                objectKey: "manifest-unrequested.jpg",
                status: .uploaded,
                uploadedAt: Date(timeIntervalSince1970: 50)
            )

            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaManifestRequest(projectIDs: [firstFrame.projectID, secondFrame.projectID]))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaManifestResponse>.self)
                    XCTAssertTrue(body.success)
                    let media = try XCTUnwrap(body.data?.media)
                    XCTAssertEqual(media.map(\.mediaAssetID), [earlierAsset, laterAsset])
                    XCTAssertEqual(media.map(\.frameID), [secondFrame.shotID, firstFrame.shotID])
                    XCTAssertEqual(media.first?.objectKey, "manifest-earlier.jpg")
                    XCTAssertEqual(media.first?.mimeType, "image/jpeg")
                    XCTAssertEqual(media.first?.sizeBytes, 2_048)
                    XCTAssertNotNil(media.first?.uploadedAt)
                    XCTAssertNotNil(media.first?.updatedAt)
                }
            )
        }
    }

    func testManifestExcludesPendingMedia() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.manifest.pending")
            let uploadedFrame = try await seedFrame(app, userID: owner.userID)
            let pendingFrame = try await seedFrame(app, userID: owner.userID)

            let uploadedAsset = try await seedMediaAsset(
                app,
                frame: uploadedFrame,
                objectKey: "manifest-uploaded.jpg",
                status: .uploaded
            )
            _ = try await seedMediaAsset(
                app,
                frame: pendingFrame,
                objectKey: "manifest-pending.jpg",
                status: .pending
            )

            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaManifestRequest(projectIDs: [uploadedFrame.projectID, pendingFrame.projectID]))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaManifestResponse>.self)
                    XCTAssertEqual(body.data?.media.map(\.mediaAssetID), [uploadedAsset])
                    XCTAssertEqual(body.data?.media.first?.status, MediaAssetStatus.uploaded.rawValue)
                }
            )
        }
    }

    func testManifestExcludesOtherUsersMedia() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.manifest.owner.2")
            let other = try await devLogin(app, appleUserID: "dev.manifest.other")
            let ownerFrame = try await seedFrame(app, userID: owner.userID)
            let otherFrame = try await seedFrame(app, userID: other.userID)

            let ownerAsset = try await seedMediaAsset(app, frame: ownerFrame, objectKey: "manifest-owner.jpg", status: .uploaded)
            _ = try await seedMediaAsset(app, frame: otherFrame, objectKey: "manifest-other.jpg", status: .uploaded)

            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaManifestRequest(projectIDs: [ownerFrame.projectID, otherFrame.projectID]))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaManifestResponse>.self)
                    XCTAssertEqual(body.data?.media.map(\.mediaAssetID), [ownerAsset])
                }
            )
        }
    }

    func testManifestEmptyProjectListReturnsEmptyArray() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.manifest.empty")

            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaManifestRequest(projectIDs: []))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaManifestResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.media.count, 0)
                }
            )
        }
    }

    func testManifestUnknownProjectIDsReturnEmptyArray() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.manifest.unknown")
            let frame = try await seedFrame(app, userID: owner.userID)
            _ = try await seedMediaAsset(app, frame: frame, objectKey: "manifest-known.jpg", status: .uploaded)

            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(MediaManifestRequest(projectIDs: [UUID()]))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<MediaManifestResponse>.self)
                    XCTAssertEqual(body.data?.media.count, 0)
                }
            )
        }
    }

    func testManifestInvalidJWTReturnsUnauthorized() async throws {
        try await withApp { app in
            try await app.test(
                .POST,
                "api/v1/media/manifest",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(MediaManifestRequest(projectIDs: [UUID()]))
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
                        displayName: "Manifest Test User"
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
        let project = Project(userID: userID, title: "Manifest Test Project")
        try await project.save(on: app.db)
        let projectID = try XCTUnwrap(project.id)

        let scene = Scene(projectID: projectID, title: "Manifest Test Scene")
        try await scene.save(on: app.db)
        let sceneID = try XCTUnwrap(scene.id)

        let shot = Shot(sceneID: sceneID, title: "Manifest Test Shot")
        try await shot.save(on: app.db)
        let shotID = try XCTUnwrap(shot.id)

        return SeededFrame(userID: userID, projectID: projectID, sceneID: sceneID, shotID: shotID)
    }

    private func seedMediaAsset(
        _ app: Application,
        frame: SeededFrame,
        objectKey: String,
        status: MediaAssetStatus,
        uploadedAt: Date? = Date()
    ) async throws -> UUID {
        let effectiveUploadedAt = status == .uploaded ? uploadedAt : nil
        let asset = MediaAsset(
            userID: frame.userID,
            projectID: frame.projectID,
            sceneID: frame.sceneID,
            shotID: frame.shotID,
            objectKey: objectKey,
            bucket: R2Configuration.devBucket,
            mimeType: "image/jpeg",
            sizeBytes: 2_048,
            status: status,
            updatedAt: effectiveUploadedAt ?? Date(),
            uploadedAt: effectiveUploadedAt
        )
        try await asset.save(on: app.db)
        return try XCTUnwrap(asset.id)
    }
}
