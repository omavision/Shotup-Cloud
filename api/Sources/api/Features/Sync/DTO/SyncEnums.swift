import Vapor

enum SyncEntity: String, Content, Codable {
    case project
    case scene
    case shot

    // Future
    case media
    case cameraSetup
    case lensSetup
}

enum SyncOperation: String, Content, Codable {
    case upsert
    case delete
}