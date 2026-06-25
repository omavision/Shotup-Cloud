@testable import api
import Fluent
import Vapor
import XCTVapor

final class SyncIntegrationTests: XCTestCase {
    private let projectID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let sceneID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let shotID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let secondShotID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let tombstoneShotID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

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

    func testProjectSceneShotUpsertFlow() async throws {
        try await withApp { app in
            let token = try await devLogin(app)

            let projectResponse = try await sync(app, token: token, changes: [projectUpsert()])
            XCTAssertTrue(projectResponse.conflicts.isEmpty)
            XCTAssertEqual(projectResponse.syncToken, "1")

            let sceneResponse = try await sync(app, token: token, changes: [sceneUpsert()])
            XCTAssertTrue(sceneResponse.conflicts.isEmpty)
            XCTAssertEqual(sceneResponse.syncToken, "2")

            let shotResponse = try await sync(app, token: token, changes: [shotUpsert()])
            XCTAssertTrue(shotResponse.conflicts.isEmpty)
            XCTAssertEqual(shotResponse.syncToken, "3")

            let download = try await sync(app, token: token, changes: [])
            XCTAssertTrue(download.changes.map(\.entity).contains(.project))
            XCTAssertTrue(download.changes.map(\.entity).contains(.scene))
            XCTAssertTrue(download.changes.map(\.entity).contains(.shot))
        }
    }

    func testIncrementalSyncReturnsZeroChangesAfterLatestToken() async throws {
        try await withApp { app in
            let token = try await devLogin(app)
            let initial = try await seedProjectSceneShot(app, token: token)

            let incremental = try await sync(
                app,
                token: token,
                lastSyncToken: initial.syncToken,
                changes: []
            )

            XCTAssertTrue(incremental.changes.isEmpty)
            XCTAssertTrue(incremental.conflicts.isEmpty)
            XCTAssertEqual(incremental.syncToken, initial.syncToken)
        }
    }

    func testNewChangeAfterTokenReturnsOnlyThatChange() async throws {
        try await withApp { app in
            let token = try await devLogin(app)
            let initial = try await seedProjectSceneShot(app, token: token)

            let incremental = try await sync(
                app,
                token: token,
                lastSyncToken: initial.syncToken,
                changes: [
                    shotUpsert(
                        id: secondShotID,
                        title: "Shot 1B",
                        notes: "Incremental synced shot",
                        shotSize: "Medium",
                        cameraMovement: "Dolly",
                        lensMM: "50",
                        sortOrder: "2",
                        updatedAt: "2026-06-25T18:00:00Z"
                    )
                ]
            )

            XCTAssertTrue(incremental.conflicts.isEmpty)
            XCTAssertEqual(incremental.changes.count, 1)
            XCTAssertEqual(incremental.changes.first?.entity, .shot)
            XCTAssertEqual(incremental.changes.first?.id, secondShotID)
            XCTAssertEqual(incremental.syncToken, "4")
        }
    }

    func testDeleteOperationReturnsTombstone() async throws {
        try await withApp { app in
            let token = try await devLogin(app)
            _ = try await seedProjectSceneShot(app, token: token)
            let baseline = try await sync(
                app,
                token: token,
                changes: [
                    shotUpsert(
                        id: tombstoneShotID,
                        title: "Tombstone Validation Shot",
                        notes: "Will be deleted",
                        updatedAt: "2026-06-25T19:00:00Z"
                    )
                ]
            )

            let tombstone = try await sync(
                app,
                token: token,
                lastSyncToken: baseline.syncToken,
                changes: [
                    TestSyncChange(
                        entity: .shot,
                        operation: .delete,
                        id: tombstoneShotID,
                        updatedAt: "2026-06-25T19:05:00Z",
                        payload: nil
                    )
                ]
            )

            XCTAssertEqual(tombstone.changes.count, 1)
            XCTAssertEqual(tombstone.changes.first?.entity, .shot)
            XCTAssertEqual(tombstone.changes.first?.operation, .delete)
            XCTAssertEqual(tombstone.changes.first?.id, tombstoneShotID)
            XCTAssertNil(tombstone.changes.first?.payload)
        }
    }

    func testStaleUpdateReturnsConflictAndDoesNotOverwrite() async throws {
        try await withApp { app in
            let token = try await devLogin(app)

            let newer = try await sync(
                app,
                token: token,
                changes: [
                    projectUpsert(
                        title: "LWW Newer Project Title",
                        notes: "Newer update should win",
                        updatedAt: "2026-06-25T20:00:00Z"
                    )
                ]
            )
            XCTAssertTrue(newer.conflicts.isEmpty)

            let stale = try await sync(
                app,
                token: token,
                changes: [
                    projectUpsert(
                        title: "STALE SHOULD NOT OVERWRITE",
                        notes: "Stale update should conflict",
                        updatedAt: "2026-06-25T19:00:00Z"
                    )
                ]
            )

            XCTAssertEqual(stale.conflicts.count, 1)
            XCTAssertEqual(stale.conflicts.first?.entity, .project)
            XCTAssertEqual(stale.conflicts.first?.id, projectID)
            XCTAssertEqual(stale.conflicts.first?.reason, "Server version is newer")

            let project = try await Project.find(projectID, on: app.db)
            XCTAssertEqual(project?.title, "LWW Newer Project Title")
            XCTAssertEqual(project?.notes, "Newer update should win")

            let events = try await SyncEvent.query(on: app.db)
                .filter(\.$entity == SyncEntity.project.rawValue)
                .filter(\.$entityID == projectID)
                .filter(\.$operation == SyncOperation.upsert.rawValue)
                .all()
            XCTAssertEqual(events.count, 1)
        }
    }

    @discardableResult
    private func seedProjectSceneShot(
        _ app: Application,
        token: String
    ) async throws -> SyncResponse {
        _ = try await sync(app, token: token, changes: [projectUpsert()])
        _ = try await sync(app, token: token, changes: [sceneUpsert()])
        return try await sync(app, token: token, changes: [shotUpsert()])
    }

    private func devLogin(_ app: Application) async throws -> String {
        var accessToken: String?

        try await app.test(
            .POST,
            "api/v1/auth/dev-login",
            beforeRequest: { req in
                try req.content.encode(
                    DevLoginRequest(
                        appleUserID: "dev.apple.user.004",
                        email: "dev4@shotup.cc",
                        displayName: "Dev User 4"
                    )
                )
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(APIResponse<AuthResponse>.self)
                XCTAssertTrue(body.success)
                accessToken = body.data?.accessToken
            }
        )

        return try XCTUnwrap(accessToken)
    }

    private func sync(
        _ app: Application,
        token: String,
        lastSyncToken: String? = nil,
        changes: [TestSyncChange]
    ) async throws -> SyncResponse {
        var syncResponse: SyncResponse?

        try await app.test(
            .POST,
            "api/v1/sync",
            beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(
                    TestSyncRequest(
                        deviceID: "test-device",
                        lastSyncToken: lastSyncToken,
                        changes: changes
                    )
                )
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(APIResponse<SyncResponse>.self)
                XCTAssertTrue(body.success)
                syncResponse = body.data
            }
        )

        return try XCTUnwrap(syncResponse)
    }

    private func projectUpsert(
        title: String = "Synced Project",
        notes: String = "Created through sync engine",
        updatedAt: String = "2026-06-25T15:00:00Z"
    ) -> TestSyncChange {
        TestSyncChange(
            entity: .project,
            operation: .upsert,
            id: projectID,
            updatedAt: updatedAt,
            payload: [
                "title": title,
                "notes": notes
            ]
        )
    }

    private func sceneUpsert(
        updatedAt: String = "2026-06-25T16:00:00Z"
    ) -> TestSyncChange {
        TestSyncChange(
            entity: .scene,
            operation: .upsert,
            id: sceneID,
            updatedAt: updatedAt,
            payload: [
                "projectID": projectID.uuidString,
                "title": "Opening Scene",
                "notes": "Opening sequence",
                "sortOrder": "1"
            ]
        )
    }

    private func shotUpsert(
        id: UUID? = nil,
        title: String = "Shot 1A",
        notes: String = "First synced shot",
        shotSize: String = "Wide",
        cameraMovement: String = "Static",
        lensMM: String = "35",
        sortOrder: String = "1",
        updatedAt: String = "2026-06-25T17:00:00Z"
    ) -> TestSyncChange {
        TestSyncChange(
            entity: .shot,
            operation: .upsert,
            id: id ?? shotID,
            updatedAt: updatedAt,
            payload: [
                "sceneID": sceneID.uuidString,
                "title": title,
                "notes": notes,
                "shotSize": shotSize,
                "cameraMovement": cameraMovement,
                "lensMM": lensMM,
                "sortOrder": sortOrder
            ]
        )
    }
}

private struct TestSyncRequest: Content {
    let deviceID: String
    let lastSyncToken: String?
    let changes: [TestSyncChange]
}

private struct TestSyncChange: Content {
    let entity: SyncEntity
    let operation: SyncOperation
    let id: UUID
    let updatedAt: String
    let payload: [String: String]?
}
