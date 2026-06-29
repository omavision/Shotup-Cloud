import Vapor

struct DeleteMediaResponse: Content, Sendable {
    let success: Bool
}
