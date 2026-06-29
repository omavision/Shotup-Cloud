import Foundation
import Vapor

struct ConfirmUploadRequest: Content, Sendable {
    let objectKey: String
    let checksum: String?
    let size: Int64
    let mimeType: String
}
