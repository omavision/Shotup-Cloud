import Vapor

struct MediaManifestRequest: Content {
    let projectIDs: [UUID]
}
