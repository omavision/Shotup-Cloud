@testable import api
import Fluent
import Vapor
import XCTVapor

final class MediaRepositoryTests: XCTestCase {
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

    func testMediaAssetsTableSupportsFullSchema() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)

            let uploadedAt = Date()
            let asset = MediaAsset(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg",
                sizeBytes: 2_048,
                checksum: "sha256:abc",
                status: .uploaded,
                uploadedAt: uploadedAt
            )

            try await asset.save(on: app.db)

            let repository = FluentMediaRepository(database: app.db)
            let fetched = try await repository.findByObjectKey(asset.objectKey)

            XCTAssertEqual(fetched?.id, asset.id)
            XCTAssertEqual(fetched?.userID, frame.userID)
            XCTAssertEqual(fetched?.projectID, frame.projectID)
            XCTAssertEqual(fetched?.sceneID, frame.sceneID)
            XCTAssertEqual(fetched?.shotID, frame.shotID)
            XCTAssertEqual(fetched?.bucket, "shotup-media-dev")
            XCTAssertEqual(fetched?.mimeType, "image/jpeg")
            XCTAssertEqual(fetched?.sizeBytes, 2_048)
            XCTAssertEqual(fetched?.checksum, "sha256:abc")
            XCTAssertEqual(fetched?.status, MediaAssetStatus.uploaded.rawValue)
            XCTAssertNotNil(fetched?.uploadedAt)
        }
    }

    func testCreatePendingUploadPersistsPendingRecord() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let asset = try await repository.createPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            XCTAssertNotNil(asset.id)
            XCTAssertEqual(asset.status, MediaAssetStatus.pending.rawValue)
            XCTAssertEqual(asset.sizeBytes, 0)
            XCTAssertNil(asset.checksum)
            XCTAssertNil(asset.uploadedAt)

            let persisted = try await MediaAsset.find(asset.id, on: app.db)
            XCTAssertEqual(persisted?.objectKey, asset.objectKey)
        }
    }

    func testMarkUploadedUpdatesExistingRecord() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let pending = try await repository.createPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            let uploadedAt = Date()
            let updated = try await repository.markUploaded(
                objectKey: pending.objectKey,
                sizeBytes: 4_096,
                checksum: "sha256:def",
                uploadedAt: uploadedAt
            )

            XCTAssertEqual(updated?.id, pending.id)
            XCTAssertEqual(updated?.status, MediaAssetStatus.uploaded.rawValue)
            XCTAssertEqual(updated?.sizeBytes, 4_096)
            XCTAssertEqual(updated?.checksum, "sha256:def")
            XCTAssertNotNil(updated?.uploadedAt)
        }
    }

    func testMarkUploadedReturnsNilForUnknownObjectKey() async throws {
        try await withApp { app in
            let repository = FluentMediaRepository(database: app.db)

            let updated = try await repository.markUploaded(
                objectKey: "does/not/exist.jpg",
                sizeBytes: 10,
                checksum: nil,
                uploadedAt: Date()
            )

            XCTAssertNil(updated)
        }
    }

    func testFindByFrameIDReturnsOnlyAssetsForThatFrame() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let otherFrame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            _ = try await repository.createPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "frame-a-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )
            _ = try await repository.createPendingUpload(
                userID: otherFrame.userID,
                projectID: otherFrame.projectID,
                sceneID: otherFrame.sceneID,
                shotID: otherFrame.shotID,
                objectKey: "frame-b-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            let assets = try await repository.findByFrameID(frame.shotID)

            XCTAssertEqual(assets.count, 1)
            XCTAssertEqual(assets.first?.objectKey, "frame-a-key.jpg")
        }
    }

    func testFindByObjectKeyReturnsNilWhenMissing() async throws {
        try await withApp { app in
            let repository = FluentMediaRepository(database: app.db)
            let result = try await repository.findByObjectKey("missing-key.jpg")
            XCTAssertNil(result)
        }
    }

    func testFindPendingUploadReturnsPendingAsset() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let pending = try await repository.createPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "pending-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            let found = try await repository.findPendingUpload(objectKey: pending.objectKey)

            XCTAssertEqual(found?.id, pending.id)
            XCTAssertEqual(found?.status, MediaAssetStatus.pending.rawValue)
        }
    }

    func testFindPendingUploadIgnoresUploadedAsset() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let pending = try await repository.createPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "uploaded-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            _ = try await repository.markUploaded(
                objectKey: pending.objectKey,
                sizeBytes: 1_024,
                checksum: "sha256:abc",
                uploadedAt: Date()
            )

            let found = try await repository.findPendingUpload(objectKey: pending.objectKey)

            XCTAssertNil(found)
        }
    }

    func testUpsertPendingUploadCreatesWhenMissing() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let asset = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "new-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            XCTAssertNotNil(asset.id)
            XCTAssertEqual(asset.status, MediaAssetStatus.pending.rawValue)
            XCTAssertEqual(asset.sizeBytes, 0)
            XCTAssertNil(asset.checksum)
            XCTAssertNil(asset.uploadedAt)
        }
    }

    func testUpsertPendingUploadUpdatesExistingPendingRowWithoutDuplicateConflict() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let first = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "retry-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            let second = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "retry-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            XCTAssertEqual(second.id, first.id)

            let matches = try await repository.findByFrameID(frame.shotID)
            XCTAssertEqual(matches.filter { $0.objectKey == "retry-key.jpg" }.count, 1)
        }
    }

    func testUpsertPendingUploadResetsUploadedRowBackToPending() async throws {
        try await withApp { app in
            let frame = try await seedFrame(app)
            let repository = FluentMediaRepository(database: app.db)

            let pending = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "reupload-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            _ = try await repository.markUploaded(
                objectKey: pending.objectKey,
                sizeBytes: 8_192,
                checksum: "sha256:uploaded",
                uploadedAt: Date()
            )

            let reuploaded = try await repository.upsertPendingUpload(
                userID: frame.userID,
                projectID: frame.projectID,
                sceneID: frame.sceneID,
                shotID: frame.shotID,
                objectKey: "reupload-key.jpg",
                bucket: "shotup-media-dev",
                mimeType: "image/jpeg"
            )

            XCTAssertEqual(reuploaded.id, pending.id)
            XCTAssertEqual(reuploaded.status, MediaAssetStatus.pending.rawValue)
            XCTAssertEqual(reuploaded.sizeBytes, 0)
            XCTAssertNil(reuploaded.checksum)
            XCTAssertNil(reuploaded.uploadedAt)
        }
    }

    private struct SeededFrame {
        let userID: UUID
        let projectID: UUID
        let sceneID: UUID
        let shotID: UUID
    }

    private func seedFrame(_ app: Application) async throws -> SeededFrame {
        let user = User(appleUserID: UUID().uuidString)
        try await user.save(on: app.db)
        let userID = try XCTUnwrap(user.id)

        let project = Project(userID: userID, title: "Repo Test Project")
        try await project.save(on: app.db)
        let projectID = try XCTUnwrap(project.id)

        let scene = Scene(projectID: projectID, title: "Repo Test Scene")
        try await scene.save(on: app.db)
        let sceneID = try XCTUnwrap(scene.id)

        let shot = Shot(sceneID: sceneID, title: "Repo Test Shot")
        try await shot.save(on: app.db)
        let shotID = try XCTUnwrap(shot.id)

        return SeededFrame(userID: userID, projectID: projectID, sceneID: sceneID, shotID: shotID)
    }
}
