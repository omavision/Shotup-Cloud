import Foundation

struct R2ObjectKeyBuilder {
    static func originalFrameKey(
        userID: UUID,
        projectID: UUID,
        sceneID: UUID,
        frameID: UUID
    ) -> String {
        "users/\(userID.keyPathComponent)/projects/\(projectID.keyPathComponent)/scenes/\(sceneID.keyPathComponent)/frames/\(frameID.keyPathComponent)/original.jpg"
    }
}

private extension UUID {
    var keyPathComponent: String {
        uuidString.lowercased()
    }
}
