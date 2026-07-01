@testable import api
import Fluent
import Vapor
import XCTVapor

final class SyncPullIntegrationTests: XCTestCase {
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

    func testFullSyncReturnsAllMetadata() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.pull.full")
            let firstProject = try await seedProject(
                app,
                userID: owner.userID,
                title: "First Pull Project",
                updatedAt: Date(timeIntervalSince1970: 100)
            )
            let secondProject = try await seedProject(
                app,
                userID: owner.userID,
                title: "Second Pull Project",
                updatedAt: Date(timeIntervalSince1970: 200)
            )
            let firstScene = try await seedScene(app, projectID: firstProject, updatedAt: Date(timeIntervalSince1970: 300))
            let secondScene = try await seedScene(app, projectID: secondProject, updatedAt: Date(timeIntervalSince1970: 400))
            let firstShot = try await seedShot(app, sceneID: firstScene, updatedAt: Date(timeIntervalSince1970: 500))
            let secondShot = try await seedShot(app, sceneID: secondScene, updatedAt: Date(timeIntervalSince1970: 600))

            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(SyncPullRequest(updatedSince: nil))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncPullResponse>.self)
                    XCTAssertTrue(body.success)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projects.compactMap(\.id), [firstProject, secondProject])
                    XCTAssertEqual(data.scenes.compactMap(\.id), [firstScene, secondScene])
                    XCTAssertEqual(data.shots.compactMap(\.id), [firstShot, secondShot])
                }
            )
        }
    }

    func testIncrementalSyncReturnsOnlyUpdatedEntities() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.pull.incremental")
            let threshold = Date(timeIntervalSince1970: 1_000)
            _ = try await seedProject(app, userID: owner.userID, title: "Old Project", updatedAt: Date(timeIntervalSince1970: 900))
            let newProject = try await seedProject(app, userID: owner.userID, title: "New Project", updatedAt: Date(timeIntervalSince1970: 1_100))
            let projectForChildren = try await seedProject(app, userID: owner.userID, title: "Parent Project", updatedAt: Date(timeIntervalSince1970: 800))
            _ = try await seedScene(app, projectID: projectForChildren, updatedAt: Date(timeIntervalSince1970: 950))
            let newScene = try await seedScene(app, projectID: projectForChildren, updatedAt: Date(timeIntervalSince1970: 1_200))
            _ = try await seedShot(app, sceneID: newScene, updatedAt: Date(timeIntervalSince1970: 990))
            let newShot = try await seedShot(app, sceneID: newScene, updatedAt: Date(timeIntervalSince1970: 1_300))

            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(SyncPullRequest(updatedSince: threshold))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncPullResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projects.compactMap(\.id), [newProject])
                    XCTAssertEqual(data.scenes.compactMap(\.id), [newScene])
                    XCTAssertEqual(data.shots.compactMap(\.id), [newShot])
                }
            )
        }
    }

    func testDifferentUserReceivesOnlyOwnMetadata() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.pull.owner")
            let other = try await devLogin(app, appleUserID: "dev.pull.other")

            let ownerProject = try await seedProject(app, userID: owner.userID, title: "Owner Project")
            let ownerScene = try await seedScene(app, projectID: ownerProject)
            let ownerShot = try await seedShot(app, sceneID: ownerScene)

            let otherProject = try await seedProject(app, userID: other.userID, title: "Other Project")
            let otherScene = try await seedScene(app, projectID: otherProject)
            _ = try await seedShot(app, sceneID: otherScene)

            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(SyncPullRequest(updatedSince: nil))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncPullResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projects.compactMap(\.id), [ownerProject])
                    XCTAssertEqual(data.scenes.compactMap(\.id), [ownerScene])
                    XCTAssertEqual(data.shots.compactMap(\.id), [ownerShot])
                }
            )
        }
    }

    func testEmptyAccountReturnsEmptyArrays() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.pull.empty")

            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(SyncPullRequest(updatedSince: nil))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncPullResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertTrue(data.projects.isEmpty)
                    XCTAssertTrue(data.scenes.isEmpty)
                    XCTAssertTrue(data.shots.isEmpty)
                }
            )
        }
    }

    func testInvalidJWTReturnsUnauthorized() async throws {
        try await withApp { app in
            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not-a-real-token")
                    try req.content.encode(SyncPullRequest(updatedSince: nil))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .unauthorized)
                }
            )
        }
    }

    func testSoftDeletedEntitiesAreExcluded() async throws {
        try await withApp { app in
            let owner = try await devLogin(app, appleUserID: "dev.pull.deleted")
            let activeProject = try await seedProject(app, userID: owner.userID, title: "Active Project")
            let deletedProject = try await seedProject(app, userID: owner.userID, title: "Deleted Project", deletedAt: Date())
            let activeScene = try await seedScene(app, projectID: activeProject)
            let deletedScene = try await seedScene(app, projectID: activeProject, deletedAt: Date())
            let sceneUnderDeletedProject = try await seedScene(app, projectID: deletedProject)
            let activeShot = try await seedShot(app, sceneID: activeScene)
            _ = try await seedShot(app, sceneID: activeScene, deletedAt: Date())
            _ = try await seedShot(app, sceneID: deletedScene)
            _ = try await seedShot(app, sceneID: sceneUnderDeletedProject)

            try await app.test(
                .POST,
                "api/v1/sync/pull",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: owner.accessToken)
                    try req.content.encode(SyncPullRequest(updatedSince: nil))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let body = try res.content.decode(APIResponse<SyncPullResponse>.self)
                    let data = try XCTUnwrap(body.data)
                    XCTAssertEqual(data.projects.compactMap(\.id), [activeProject])
                    XCTAssertEqual(data.scenes.compactMap(\.id), [activeScene])
                    XCTAssertEqual(data.shots.compactMap(\.id), [activeShot])
                }
            )
        }
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
                        displayName: "Sync Pull Test User"
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
    ) async throws -> UUID {
        let project = Project(
            userID: userID,
            title: title,
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
            title: "Sync Pull Scene",
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
            title: "Sync Pull Shot",
            createdAt: Date(timeInterval: -60, since: updatedAt),
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
        try await shot.save(on: app.db)
        return try XCTUnwrap(shot.id)
    }
}
