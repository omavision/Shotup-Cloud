import Vapor

struct ScenePayload: Content {
    let projectID: UUID
    let title: String
    let notes: String?
    let sortOrder: String
    let deletedAt: String?

    var sortOrderInt: Int {
        Int(sortOrder) ?? 0
    }
}
