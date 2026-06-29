@testable import api
import Foundation
import XCTest

final class MediaContractTests: XCTestCase {
    private let projectID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let sceneID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let frameID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let expiresAt = Date(timeIntervalSince1970: 1_798_762_500)

    func testRequestUploadRequestRoundTrips() throws {
        let value = RequestUploadRequest(
            projectID: projectID,
            sceneID: sceneID,
            frameID: frameID,
            contentType: "image/jpeg"
        )

        let decoded = try roundTrip(value)

        XCTAssertEqual(decoded.projectID, projectID)
        XCTAssertEqual(decoded.sceneID, sceneID)
        XCTAssertEqual(decoded.frameID, frameID)
        XCTAssertEqual(decoded.contentType, "image/jpeg")
    }

    func testRequestUploadResponseRoundTrips() throws {
        let value = RequestUploadResponse(
            uploadURL: "https://example.com/upload",
            objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
            expiresAt: expiresAt,
            requiredHeaders: ["Content-Type": "image/jpeg"]
        )

        let decoded = try roundTrip(value)

        XCTAssertEqual(decoded.uploadURL, "https://example.com/upload")
        XCTAssertEqual(decoded.objectKey, "users/u/projects/p/scenes/s/frames/f/original.jpg")
        XCTAssertEqual(decoded.expiresAt, expiresAt)
        XCTAssertEqual(decoded.requiredHeaders, ["Content-Type": "image/jpeg"])
    }

    func testConfirmUploadRequestRoundTrips() throws {
        let value = ConfirmUploadRequest(
            objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
            checksum: "sha256:test",
            size: 1_024,
            mimeType: "image/jpeg"
        )

        let decoded = try roundTrip(value)

        XCTAssertEqual(decoded.objectKey, "users/u/projects/p/scenes/s/frames/f/original.jpg")
        XCTAssertEqual(decoded.checksum, "sha256:test")
        XCTAssertEqual(decoded.size, 1_024)
        XCTAssertEqual(decoded.mimeType, "image/jpeg")
    }

    func testConfirmUploadRequestRoundTripsNilChecksum() throws {
        let value = ConfirmUploadRequest(
            objectKey: "users/u/projects/p/scenes/s/frames/f/original.jpg",
            checksum: nil,
            size: 1_024,
            mimeType: "image/jpeg"
        )

        let decoded = try roundTrip(value)

        XCTAssertNil(decoded.checksum)
    }

    func testConfirmUploadResponseRoundTrips() throws {
        let decoded = try roundTrip(ConfirmUploadResponse(success: true))

        XCTAssertTrue(decoded.success)
    }

    func testRequestDownloadRequestRoundTrips() throws {
        let decoded = try roundTrip(RequestDownloadRequest(frameID: frameID))

        XCTAssertEqual(decoded.frameID, frameID)
    }

    func testRequestDownloadResponseRoundTrips() throws {
        let value = RequestDownloadResponse(
            downloadURL: "https://example.com/download",
            expiresAt: expiresAt
        )

        let decoded = try roundTrip(value)

        XCTAssertEqual(decoded.downloadURL, "https://example.com/download")
        XCTAssertEqual(decoded.expiresAt, expiresAt)
    }

    func testDeleteMediaRequestRoundTrips() throws {
        let decoded = try roundTrip(DeleteMediaRequest(frameID: frameID))

        XCTAssertEqual(decoded.frameID, frameID)
    }

    func testDeleteMediaResponseRoundTrips() throws {
        let decoded = try roundTrip(DeleteMediaResponse(success: true))

        XCTAssertTrue(decoded.success)
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
