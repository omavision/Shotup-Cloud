import Vapor

struct ShotPayload: Content {
    let sceneID: UUID
    let title: String
    let notes: String?
    let shotSize: String?
    let cameraMovement: String?
    let lensMM: String?
    let sortOrder: String

    var lensMMDouble: Double? {
        guard let lensMM else {
            return nil
        }

        return Double(lensMM)
    }

    var sortOrderInt: Int {
        Int(sortOrder) ?? 0
    }
}
