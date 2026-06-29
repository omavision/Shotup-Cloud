import Foundation
import Vapor

protocol R2StorageServicing: Sendable {
    func presignedUploadURL(
        objectKey: String,
        expiresIn seconds: Int
    ) async throws -> String

    func presignedDownloadURL(
        objectKey: String,
        expiresIn seconds: Int
    ) async throws -> String

    func deleteObject(objectKey: String) async throws

    func objectExists(objectKey: String) async throws -> Bool
}

struct R2StorageService: R2StorageServicing {
    let configuration: R2Configuration

    func presignedUploadURL(
        objectKey: String,
        expiresIn seconds: Int
    ) async throws -> String {
        throw R2StorageError.unsupported("R2 presigned upload URLs are not implemented yet.")
    }

    func presignedDownloadURL(
        objectKey: String,
        expiresIn seconds: Int
    ) async throws -> String {
        throw R2StorageError.unsupported("R2 presigned download URLs are not implemented yet.")
    }

    func deleteObject(objectKey: String) async throws {
        throw R2StorageError.unsupported("R2 object deletion is not implemented yet.")
    }

    func objectExists(objectKey: String) async throws -> Bool {
        throw R2StorageError.unsupported("R2 object existence checks are not implemented yet.")
    }
}

enum R2StorageError: Error, CustomStringConvertible, Equatable {
    case unsupported(String)

    var description: String {
        switch self {
        case .unsupported(let message):
            return message
        }
    }
}

private struct R2StorageServiceKey: StorageKey {
    typealias Value = any R2StorageServicing
}

extension Application {
    var r2Storage: (any R2StorageServicing)? {
        get {
            storage[R2StorageServiceKey.self]
        }
        set {
            storage[R2StorageServiceKey.self] = newValue
        }
    }
}
