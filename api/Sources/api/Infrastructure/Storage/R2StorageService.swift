import Foundation
import CryptoKit
import Vapor

protocol R2StorageServicing: Sendable {
    func presignedUploadURL(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        frameID: UUID,
        contentType: String
    ) async throws -> R2PresignedUpload

    func presignedDownloadURL(
        objectKey: String,
        expiresIn seconds: Int
    ) async throws -> String

    func deleteObject(objectKey: String) async throws

    func objectExists(objectKey: String) async throws -> Bool
}

struct R2PresignedUpload: Content, Equatable, Sendable {
    let uploadURL: String
    let objectKey: String
    let bucket: String
    let expiresAt: Date
    let requiredHeaders: [String: String]
}

struct R2StorageService: R2StorageServicing {
    static let uploadExpirationSeconds = 900

    let configuration: R2Configuration
    private let now: @Sendable () -> Date
    private let client: (any Client)?

    init(
        configuration: R2Configuration,
        client: (any Client)? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.client = client
        self.now = now
    }

    func presignedUploadURL(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        frameID: UUID,
        contentType: String
    ) async throws -> R2PresignedUpload {
        let normalizedContentType = contentType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedContentType == "image/jpeg" else {
            throw R2StorageError.unsupportedContentType(contentType)
        }

        guard var components = URLComponents(string: configuration.endpoint),
              components.scheme == "https" || components.scheme == "http",
              let host = components.host,
              !host.isEmpty
        else {
            throw R2StorageError.invalidEndpoint(configuration.endpoint)
        }

        let objectKey = R2ObjectKeyBuilder.originalFrameKey(
            userID: userID,
            projectID: projectID,
            sceneID: sceneID,
            frameID: frameID
        )
        let requestDate = now()
        let expiresAt = requestDate.addingTimeInterval(
            TimeInterval(Self.uploadExpirationSeconds)
        )
        let dateStamp = Self.dateStampFormatter.string(from: requestDate)
        let amzDate = Self.amzDateFormatter.string(from: requestDate)
        let credentialScope = "\(dateStamp)/auto/s3/aws4_request"
        let credential = "\(configuration.accessKeyID)/\(credentialScope)"
        let canonicalURI = "/\(configuration.bucket)/\(objectKey)"
        let signedHeaders = "content-type;host"
        let queryItems = [
            URLQueryItem(name: "X-Amz-Algorithm", value: "AWS4-HMAC-SHA256"),
            URLQueryItem(name: "X-Amz-Credential", value: credential),
            URLQueryItem(name: "X-Amz-Date", value: amzDate),
            URLQueryItem(name: "X-Amz-Expires", value: "\(Self.uploadExpirationSeconds)"),
            URLQueryItem(name: "X-Amz-SignedHeaders", value: signedHeaders)
        ]
        let canonicalQuery = Self.canonicalQueryString(queryItems)
        let canonicalHeaders = "content-type:\(normalizedContentType)\nhost:\(host)\n"
        let canonicalRequest = [
            "PUT",
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            Self.sha256Hex(canonicalRequest)
        ].joined(separator: "\n")
        let signingKey = Self.signingKey(
            secretAccessKey: configuration.secretAccessKey,
            dateStamp: dateStamp
        )
        let signature = Self.hmacSHA256Hex(
            stringToSign,
            key: signingKey
        )

        var signedQueryItems = queryItems
        signedQueryItems.append(URLQueryItem(name: "X-Amz-Signature", value: signature))

        components.path = canonicalURI
        components.queryItems = signedQueryItems

        guard let uploadURL = components.url?.absoluteString else {
            throw R2StorageError.invalidEndpoint(configuration.endpoint)
        }

        return R2PresignedUpload(
            uploadURL: uploadURL,
            objectKey: objectKey,
            bucket: configuration.bucket,
            expiresAt: expiresAt,
            requiredHeaders: ["Content-Type": normalizedContentType]
        )
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
        guard let client else {
            throw R2StorageError.unsupported("R2 client is not configured.")
        }

        guard var components = URLComponents(string: configuration.endpoint),
              components.scheme == "https" || components.scheme == "http",
              let host = components.host,
              !host.isEmpty
        else {
            throw R2StorageError.invalidEndpoint(configuration.endpoint)
        }

        let requestDate = now()
        let dateStamp = Self.dateStampFormatter.string(from: requestDate)
        let amzDate = Self.amzDateFormatter.string(from: requestDate)
        let credentialScope = "\(dateStamp)/auto/s3/aws4_request"
        let credential = "\(configuration.accessKeyID)/\(credentialScope)"
        let canonicalURI = "/\(configuration.bucket)/\(objectKey)"
        let payloadHash = Self.sha256Hex("")
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders = "host:\(host)\nx-amz-content-sha256:\(payloadHash)\nx-amz-date:\(amzDate)\n"
        let canonicalRequest = [
            "HEAD",
            canonicalURI,
            "",
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            Self.sha256Hex(canonicalRequest)
        ].joined(separator: "\n")
        let signingKey = Self.signingKey(
            secretAccessKey: configuration.secretAccessKey,
            dateStamp: dateStamp
        )
        let signature = Self.hmacSHA256Hex(stringToSign, key: signingKey)
        let authorization = "AWS4-HMAC-SHA256 Credential=\(credential), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        components.path = canonicalURI

        guard let url = components.url else {
            throw R2StorageError.invalidEndpoint(configuration.endpoint)
        }

        let headers: HTTPHeaders = [
            "host": host,
            "x-amz-content-sha256": payloadHash,
            "x-amz-date": amzDate,
            "authorization": authorization
        ]

        let response = try await client.send(.HEAD, headers: headers, to: URI(string: url.absoluteString))

        switch response.status.code {
        case 200..<300:
            return true
        case 404:
            return false
        default:
            throw R2StorageError.unsupported("Unexpected R2 HEAD response status: \(response.status.code)")
        }
    }
}

enum R2StorageError: Error, CustomStringConvertible, Equatable {
    case unsupported(String)
    case unsupportedContentType(String)
    case invalidEndpoint(String)

    var description: String {
        switch self {
        case .unsupported(let message):
            return message
        case .unsupportedContentType(let contentType):
            return "Unsupported R2 upload content type: \(contentType)"
        case .invalidEndpoint(let endpoint):
            return "Invalid R2 endpoint: \(endpoint)"
        }
    }
}

private extension R2StorageService {
    static let amzDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    static let dateStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static func canonicalQueryString(_ queryItems: [URLQueryItem]) -> String {
        queryItems
            .map { item in
                "\(percentEncode(item.name))=\(percentEncode(item.value ?? ""))"
            }
            .sorted()
            .joined(separator: "&")
    }

    static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func signingKey(
        secretAccessKey: String,
        dateStamp: String
    ) -> SymmetricKey {
        let dateKey = hmacSHA256Data(dateStamp, key: SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8)))
        let regionKey = hmacSHA256Data("auto", key: SymmetricKey(data: dateKey))
        let serviceKey = hmacSHA256Data("s3", key: SymmetricKey(data: regionKey))
        let signingKey = hmacSHA256Data("aws4_request", key: SymmetricKey(data: serviceKey))
        return SymmetricKey(data: signingKey)
    }

    static func hmacSHA256Hex(_ value: String, key: SymmetricKey) -> String {
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: Data(value.utf8),
            using: key
        )
        return Data(authenticationCode).map { String(format: "%02x", $0) }.joined()
    }

    static func hmacSHA256Data(_ value: String, key: SymmetricKey) -> Data {
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: Data(value.utf8),
            using: key
        )
        return Data(authenticationCode)
    }

    static func percentEncode(_ value: String) -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
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
