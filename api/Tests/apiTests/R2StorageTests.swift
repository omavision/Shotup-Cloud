@testable import api
import Foundation
import Vapor
import XCTest

final class R2StorageTests: XCTestCase {
    private let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let projectID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let sceneID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let frameID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let fixedDate = Date(timeIntervalSince1970: 1_798_761_600)

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

    func testPresignedUploadURLGeneration() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let fixedDate = fixedDate
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] },
            now: { fixedDate }
        )

        let upload = try await service.presignedUploadURL(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            frameID: frameID,
            contentType: "image/jpeg"
        )

        XCTAssertEqual(
            upload.objectKey,
            "users/11111111-1111-1111-1111-111111111111/projects/22222222-2222-2222-2222-222222222222/scenes/33333333-3333-3333-3333-333333333333/frames/44444444-4444-4444-4444-444444444444/original.jpg"
        )
        XCTAssertEqual(upload.expiresAt, fixedDate.addingTimeInterval(900))
        XCTAssertEqual(upload.requiredHeaders, ["Content-Type": "image/jpeg"])

        let components = try XCTUnwrap(URLComponents(string: upload.uploadURL))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "test-account.r2.cloudflarestorage.com")
        XCTAssertEqual(
            components.path,
            "/shotup-media-dev/users/11111111-1111-1111-1111-111111111111/projects/22222222-2222-2222-2222-222222222222/scenes/33333333-3333-3333-3333-333333333333/frames/44444444-4444-4444-4444-444444444444/original.jpg"
        )

        let query = Dictionary(
            uniqueKeysWithValues: try XCTUnwrap(components.queryItems).map {
                ($0.name, try XCTUnwrap($0.value))
            }
        )

        XCTAssertEqual(query["X-Amz-Algorithm"], "AWS4-HMAC-SHA256")
        XCTAssertEqual(query["X-Amz-Credential"], "test-access-key/20270101/auto/s3/aws4_request")
        XCTAssertEqual(query["X-Amz-Date"], "20270101T000000Z")
        XCTAssertEqual(query["X-Amz-Expires"], "900")
        XCTAssertEqual(query["X-Amz-SignedHeaders"], "content-type;host")
        XCTAssertNotNil(query["X-Amz-Signature"])
        XCTAssertEqual(query["X-Amz-Signature"]?.count, 64)
    }

    func testPresignedUploadRejectsUnsupportedContentType() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] }
        )

        do {
            _ = try await service.presignedUploadURL(
                userID: userID,
                projectID: projectID,
                sceneID: sceneID,
                frameID: frameID,
                contentType: "image/png"
            )
            XCTFail("Expected image/png to be rejected.")
        } catch let error as R2StorageError {
            XCTAssertEqual(error, .unsupportedContentType("image/png"))
        }
    }

    func testPresignedUploadRejectsInvalidEndpointConfiguration() async throws {
        let config = R2Configuration(
            accountID: "test-account",
            accessKeyID: "test-access-key",
            secretAccessKey: "test-secret-key",
            bucket: R2Configuration.devBucket,
            endpoint: "not a url"
        )
        let service = R2StorageService(configuration: config)

        do {
            _ = try await service.presignedUploadURL(
                userID: userID,
                projectID: projectID,
                sceneID: sceneID,
                frameID: frameID,
                contentType: "image/jpeg"
            )
            XCTFail("Expected invalid endpoint to be rejected.")
        } catch let error as R2StorageError {
            XCTAssertEqual(error, .invalidEndpoint("not a url"))
        }
    }

    func testNonUploadMethodsAreExplicitlyUnsupported() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] }
        )

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

    func testObjectExistsReturnsTrueForSuccessfulHeadResponse() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let client = StubR2Client(eventLoop: EmbeddedEventLoop(), status: .ok)
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] },
            client: client
        )

        let exists = try await service.objectExists(
            objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg"
        )

        XCTAssertTrue(exists)
    }

    func testObjectExistsReturnsFalseForMissingObject() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let client = StubR2Client(eventLoop: EmbeddedEventLoop(), status: .notFound)
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] },
            client: client
        )

        let exists = try await service.objectExists(objectKey: "missing-key.jpg")

        XCTAssertFalse(exists)
    }

    func testObjectExistsThrowsWhenClientNotConfigured() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let service = R2StorageService(configuration: try R2Configuration.load { values[$0] })

        do {
            _ = try await service.objectExists(objectKey: "any-key.jpg")
            XCTFail("Expected objectExists to throw when client is not configured.")
        } catch let error as R2StorageError {
            XCTAssertEqual(error, .unsupported("R2 client is not configured."))
        }
    }

    func testObjectExistsSignsHeadRequestWithExpectedHeaders() async throws {
        let values = environment(bucket: R2Configuration.devBucket)
        let client = StubR2Client(eventLoop: EmbeddedEventLoop(), status: .ok)
        let fixedDate = fixedDate
        let service = R2StorageService(
            configuration: try R2Configuration.load { values[$0] },
            client: client,
            now: { fixedDate }
        )

        _ = try await service.objectExists(
            objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg"
        )

        let request = try XCTUnwrap(client.lastRequest)
        XCTAssertEqual(request.method, .HEAD)
        XCTAssertEqual(request.url.host, "test-account.r2.cloudflarestorage.com")
        XCTAssertEqual(
            request.url.path,
            "/shotup-media-dev/users/u/projects/p/scenes/s/frames/f/original.jpg"
        )
        XCTAssertEqual(request.headers.first(name: "x-amz-date"), "20270101T000000Z")
        XCTAssertTrue(
            request.headers.first(name: "authorization")?
                .hasPrefix("AWS4-HMAC-SHA256 Credential=test-access-key/20270101/auto/s3/aws4_request") ?? false
        )
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

final class StubR2Client: Client, @unchecked Sendable {
    let eventLoop: any EventLoop
    private let status: HTTPStatus
    private(set) var lastRequest: ClientRequest?

    init(eventLoop: any EventLoop, status: HTTPStatus) {
        self.eventLoop = eventLoop
        self.status = status
    }

    func delegating(to eventLoop: any EventLoop) -> any Client {
        self
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        lastRequest = request
        return eventLoop.makeSucceededFuture(ClientResponse(status: status))
    }
}
