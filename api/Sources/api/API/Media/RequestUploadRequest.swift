import Foundation
import Vapor

struct RequestUploadRequest: Content, Sendable {
    let projectID: UUID
    let sceneID: UUID
    let frameID: UUID
    let contentType: String
}
