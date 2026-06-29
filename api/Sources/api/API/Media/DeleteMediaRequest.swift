import Foundation
import Vapor

struct DeleteMediaRequest: Content, Sendable {
    let frameID: UUID
}
