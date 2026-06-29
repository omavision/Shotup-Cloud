@testable import api
import Foundation
import XCTest

final class R2StorageTests: XCTestCase {
    private let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let projectID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let sceneID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let frameID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    func testR2ConfigurationLoadsRequiredEnvironmentValues() throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let config = try R2Configuration.load { values[$0] }

        XCTAssertEqual(config.accountID, "test-account")
        XCTAssertEqual(config.accessKeyID, "test-access-key")
        XCTAssertEqual(config.secretAccessKey, "test-secret-key")
        XCTAssertEqual(config.bucket, R2Configuration.devBucket)
        XCTAssertEqual(config.endpoint, "https://test-account.r2.cloudflarestorage.com")
    }

    func testR2ConfigurationFailsWhenRequiredEnvironmentValueIsMissing() {
        var values = environment(bucket: R2Configuration.devBucket)
        values.removeValue(forKey: "R2_SECRET_ACCESS_KEY")

        XCTAssertThrowsError(try R2Configuration.load { values[$0] }) { error in
            XCTAssertEqual(
                error as? R2ConfigurationError,
                .missingRequiredEnvironmentVariable("R2_SECRET_ACCESS_KEY")
            )
        }
    }

    func testR2ConfigurationAcceptsKnownBuckets() throws {
        let devValues = environment(bucket: R2Configuration.devBucket)
        let prodValues = environment(bucket: R2Configuration.prodBucket)
        let dev = try R2Configuration.load { devValues[$0] }
        let prod = try R2Configuration.load { prodValues[$0] }

        XCTAssertEqual(dev.bucket, "shotup-media-dev")
        XCTAssertEqual(prod.bucket, "shotup-media-prod")
    }

    func testR2ConfigurationRejectsUnknownBucket() {
        let values = environment(bucket: "shotup-media-local")

        XCTAssertThrowsError(try R2Configuration.load { values[$0] }) { error in
            XCTAssertEqual(error as? R2ConfigurationError, .invalidBucket("shotup-media-local"))
        }
    }

    func testOriginalFrameObjectKeyGeneration() {
        let key = R2ObjectKeyBuilder.originalFrameKey(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            frameID: frameID
        )

        XCTAssertEqual(
            key,
            "users/11111111-1111-1111-1111-111111111111/projects/22222222-2222-2222-2222-222222222222/scenes/33333333-3333-3333-3333-333333333333/frames/44444444-4444-4444-4444-444444444444/original.jpg"
        )
    }

    func testPresignedMethodsAreExplicitlyUnsupported() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] }
        )

        do {
            _ = try await service.presignedUploadURL(objectKey: "test.jpg", expiresIn: 300)
            XCTFail("Expected presignedUploadURL to be unsupported.")
        } catch let error as R2StorageError {
            XCTAssertEqual(
                error,
                .unsupported("R2 presigned upload URLs are not implemented yet.")
            )
        }

        do {
            _ = try await service.presignedDownloadURL(objectKey: "test.jpg", expiresIn: 300)
            XCTFail("Expected presignedDownloadURL to be unsupported.")
        } catch let error as R2StorageError {
            XCTAssertEqual(
                error,
                .unsupported("R2 presigned download URLs are not implemented yet.")
            )
        }
    }

    private func environment(bucket: String) -> [String: String] {
        [
            "R2_ACCOUNT_ID": "test-account",
            "R2_ACCESS_KEY_ID": "test-access-key",
            "R2_SECRET_ACCESS_KEY": "test-secret-key",
            "R2_BUCKET": bucket,
            "R2_ENDPOINT": "https://test-account.r2.cloudflarestorage.com"
        ]
    }
}
