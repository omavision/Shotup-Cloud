import Vapor

struct ConfirmUploadResponse: Content, Sendable {
    let success: Bool
}
