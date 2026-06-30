import Foundation
import Vapor

struct MediaExistsResponse: Content, Sendable {
    let exists: Bool
    let mediaAssetID: UUID?
    let objectKey: String?
    let status: String?
}
