import Foundation
import Vapor

struct RequestUploadResponse: Content, Sendable {
    let uploadURL: String
    let objectKey: String
    let expiresAt: Date
    let requiredHeaders: [String: String]
}
