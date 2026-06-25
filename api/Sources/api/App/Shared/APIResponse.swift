import Vapor

struct APIResponse<T: Content>: Content {
    let success: Bool
    let data: T?
    let message: String?

    init(data: T) {
        self.success = true
        self.data = data
        self.message = nil
    }

    init(message: String) {
        self.success = false
        self.data = nil
        self.message = message
    }
}