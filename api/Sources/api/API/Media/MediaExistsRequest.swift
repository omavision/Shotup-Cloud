import Foundation
import Vapor

struct MediaExistsRequest: Content, Sendable {
    let frameID: UUID
}
