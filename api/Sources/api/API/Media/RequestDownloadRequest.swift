import Foundation
import Vapor

struct RequestDownloadRequest: Content, Sendable {
    let frameID: UUID
}
