import Vapor

struct SyncPullResponse: Content {
    let projects: [ProjectDTO]
    let scenes: [SceneDTO]
    let shots: [ShotDTO]
    let serverTime: Date
}
