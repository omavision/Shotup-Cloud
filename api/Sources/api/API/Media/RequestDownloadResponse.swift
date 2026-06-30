import Foundation
import Vapor

struct RequestDownloadResponse: Content, Sendable {
    let downloadURL: String
    let objectKey: String
    let expiresAt: Date
}
