import Vapor

struct R2Configuration: Sendable {
    static let devBucket = "shotup-media-dev"
    static let prodBucket = "shotup-media-prod"

    let accountID: String
    let accessKeyID: String
    let secretAccessKey: String
    let bucket: String
    let endpoint: String

    static func loadFromEnvironment() throws -> R2Configuration {
        try load { Environment.get($0) }
    }

    static func load(_ valueForKey: (String) -> String?) throws -> R2Configuration {
        let accountID = try required("R2_ACCOUNT_ID", valueForKey)
        let accessKeyID = try required("R2_ACCESS_KEY_ID", valueForKey)
        let secretAccessKey = try required("R2_SECRET_ACCESS_KEY", valueForKey)
        let bucket = try required("R2_BUCKET", valueForKey)
        let endpoint = try required("R2_ENDPOINT", valueForKey)

        guard [devBucket, prodBucket].contains(bucket) else {
            throw R2ConfigurationError.invalidBucket(bucket)
        }

        return R2Configuration(
            accountID: accountID,
            accessKeyID: accessKeyID,
            secretAccessKey: secretAccessKey,
            bucket: bucket,
            endpoint: endpoint
        )
    }

    private static func required(
        _ key: String,
        _ valueForKey: (String) -> String?
    ) throws -> String {
        guard let value = valueForKey(key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            throw R2ConfigurationError.missingRequiredEnvironmentVariable(key)
        }

        return value
    }
}

enum R2ConfigurationError: Error, CustomStringConvertible, Equatable {
    case missingRequiredEnvironmentVariable(String)
    case invalidBucket(String)

    var description: String {
        switch self {
        case .missingRequiredEnvironmentVariable(let key):
            return "Missing required R2 environment variable: \(key)"
        case .invalidBucket(let bucket):
            return "Invalid R2 bucket: \(bucket)"
        }
    }
}
