import Fluent
import Vapor

struct CloudProjectDTO: Content {
    let id: UUID
    let title: String
    let updatedAt: Date?
    let createdAt: Date?
    let sceneCount: Int
    let shotCount: Int
    let mediaAssetCount: Int

    init(
        project: Project,
        sceneCount: Int,
        shotCount: Int,
        mediaAssetCount: Int
    ) throws {
        self.id = try project.requireID()
        self.title = project.title
        self.updatedAt = project.updatedAt
        self.createdAt = project.createdAt
        self.sceneCount = sceneCount
        self.shotCount = shotCount
        self.mediaAssetCount = mediaAssetCount
    }
}

struct CloudProjectListResponse: Content {
    let projects: [CloudProjectDTO]
}
