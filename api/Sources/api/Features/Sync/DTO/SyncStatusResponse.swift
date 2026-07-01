import Vapor

struct SyncStatusResponse: Content {
    let serverTime: Date
    let projectCount: Int
    let sceneCount: Int
    let shotCount: Int
    let mediaAssetCount: Int
    let uploadedMediaCount: Int
    let pendingMediaCount: Int
    let lastMetadataUpdate: Date?
    let lastMediaUpload: Date?
}
