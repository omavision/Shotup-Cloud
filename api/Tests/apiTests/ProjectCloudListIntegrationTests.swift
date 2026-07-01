@testable import api
import Fluent
import Vapor
import XCTVapor

final class ProjectCloudListIntegrationTests: XCTestCase {
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

    func testCloudProjectsReturnsOnlyAuthenticatedUsersProjects() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.cloud.owner.only")
            let other = try await devLogin(app, appleUserID: "dev.cloud.other.only")

            let ownerProject = try await seedProject(
                app,
                userID: owner.userID,
                title: "Owner Cloud Project",
                updatedAt: Date(timeIntervalSince1970: 300)
            )
            _ = try await seedProject(
                app,
                userID: other.userID,
                title: "Other Cloud Project",
                updatedAt: Date(timeIntervalSince1970: 400)
            )

            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<CloudProjectListResponse>.self)
                    XCTAssertTrue(body.success)
                    let projects = try XCTUnwrap(body.data?.projects)
                    XCTAssertEqual(projects.map(\.id), [ownerProject.id])
                    XCTAssertEqual(projects.first?.title, "Owner Cloud Project")
                }
            )
        }
    }

    func testCloudProjectsIncludesSceneShotAndMediaCounts() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.cloud.counts")
            let project = try await seedProject(app, userID: owner.userID, title: "Counted Project")
            let firstScene = try await seedScene(app, projectID: project.id)
            let secondScene = try await seedScene(app, projectID: project.id)
            let deletedScene = try await seedScene(app, projectID: project.id, deletedAt: Date())
            let firstShot = try await seedShot(app, sceneID: firstScene)
            let secondShot = try await seedShot(app, sceneID: firstScene)
            let thirdShot = try await seedShot(app, sceneID: secondScene)
            _ = try await seedShot(app, sceneID: firstScene, deletedAt: Date())
            _ = try await seedShot(app, sceneID: deletedScene)
            try await seedMediaAsset(app, userID: owner.userID, projectID: project.id, sceneID: firstScene, shotID: firstShot, key: "counts-1.jpg")
            try await seedMediaAsset(app, userID: owner.userID, projectID: project.id, sceneID: firstScene, shotID: secondShot, key: "counts-2.jpg")
            try await seedMediaAsset(app, userID: owner.userID, projectID: project.id, sceneID: secondScene, shotID: thirdShot, key: "counts-3.jpg")

            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<CloudProjectListResponse>.self)
                    let cloudProject = try XCTUnwrap(body.data?.projects.first)
                    XCTAssertEqual(cloudProject.sceneCount, 2)
                    XCTAssertEqual(cloudProject.shotCount, 3)
                    XCTAssertEqual(cloudProject.mediaAssetCount, 3)
                }
            )
        }
    }

    func testCloudProjectsExcludesOtherUsersProjects() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.cloud.owner.excludes")
            let other = try await devLogin(app, appleUserID: "dev.cloud.other.excludes")

            _ = try await seedProject(app, userID: owner.userID, title: "Visible Project")
            let otherProject = try await seedProject(app, userID: other.userID, title: "Hidden Project")

            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<CloudProjectListResponse>.self)
                    let projectIDs = try XCTUnwrap(body.data?.projects.map(\.id))
                    XCTAssertFalse(projectIDs.contains(otherProject.id))
                }
            )
        }
    }

    func testCloudProjectsReturnsUnauthorizedForInvalidJWT() async throws {
        try await withApp { app in
            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .unauthorized)
                }
            )
        }
    }

    func testCloudProjectsEmptyStateReturnsEmptyProjectsArray() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.cloud.empty")

            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<CloudProjectListResponse>.self)
                    XCTAssertTrue(body.success)
                    XCTAssertEqual(body.data?.projects.count, 0)
                }
            )
        }
    }

    func testCloudProjectsExcludesSoftDeletedProjectsAndSortsByUpdatedAtDescending() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.cloud.sort.deleted")

            let older = try await seedProject(
                app,
                userID: owner.userID,
                title: "Older Project",
                updatedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try await seedProject(
                app,
                userID: owner.userID,
                title: "Deleted Project",
                updatedAt: Date(timeIntervalSince1970: 300),
                deletedAt: Date()
            )
            let newer = try await seedProject(
                app,
                userID: owner.userID,
                title: "Newer Project",
                updatedAt: Date(timeIntervalSince1970: 200)
            )

            try await app.test(
                .GET,
                "api/v1/projects/cloud",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<CloudProjectListResponse>.self)
                    let projects = try XCTUnwrap(body.data?.projects)
                    XCTAssertEqual(projects.map(\.id), [newer.id, older.id])
                }
            )
        }
    }

    private struct LoggedInUser {
        let userID: UUID
        let accessToken: String
    }

    private struct SeededProject {
        let id: UUID
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
                        displayName: "Cloud Project Test User"
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

    private func seedProject(
        _ app: Application,
        userID: UUID,
        title: String,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) async throws -> SeededProject {
        let project = Project(
            userID: userID,
            title: title,
            createdAt: Date(timeInterval: -60, since: updatedAt),
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
        try await project.save(on: app.db)
        return SeededProject(id: try XCTUnwrap(project.id))
    }

    private func seedScene(
        _ app: Application,
        projectID: UUID,
        deletedAt: Date? = nil
    ) async throws -> UUID {
        let scene = Scene(projectID: projectID, title: "Cloud Test Scene", deletedAt: deletedAt)
        try await scene.save(on: app.db)
        return try XCTUnwrap(scene.id)
    }

    private func seedShot(
        _ app: Application,
        sceneID: UUID,
        deletedAt: Date? = nil
    ) async throws -> UUID {
        let shot = Shot(sceneID: sceneID, title: "Cloud Test Shot", deletedAt: deletedAt)
        try await shot.save(on: app.db)
        return try XCTUnwrap(shot.id)
    }

    private func seedMediaAsset(
        _ app: Application,
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        shotID: UUID,
        key: String
    ) async throws {
        let asset = MediaAsset(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            shotID: shotID,
            objectKey: key,
            bucket: R2Configuration.devBucket,
            mimeType: "image/jpeg",
            status: .uploaded,
            uploadedAt: Date()
        )
        try await asset.save(on: app.db)
    }
}
