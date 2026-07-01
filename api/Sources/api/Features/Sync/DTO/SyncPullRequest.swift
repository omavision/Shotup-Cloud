import Vapor

struct SyncPullRequest: Content {
    let updatedSince: Date?
}
