import Fluent
import Vapor

struct ProjectService {
    let repository: ProjectRepository

    func listProjects(for userID: UUID) async throws -> [ProjectDTO] {
        let projects = try await repository.list(for: userID)
        return try projects.map { try ProjectDTO(project: $0) }
    }

    func listCloudProjects(for userID: UUID) async throws -> CloudProjectListResponse {
        let projects = try await repository.list(for: userID)
        var cloudProjects: [CloudProjectDTO] = []

        for project in projects {
            let projectID = try project.requireID()
            let sceneCount = try await repository.countScenes(for: projectID)
            let shotCount = try await repository.countShots(for: projectID)
            let mediaAssetCount = try await repository.countMediaAssets(for: projectID)

            let cloudProject = try CloudProjectDTO(
                project: project,
                sceneCount: sceneCount,
                shotCount: shotCount,
                mediaAssetCount: mediaAssetCount
            )

            cloudProjects.append(cloudProject)
        }

        return CloudProjectListResponse(projects: cloudProjects)
    }

    func createProject(userID: UUID, title: String, notes: String?) async throws -> ProjectDTO {
        let project = Project(
            userID: userID,
            title: title,
            notes: notes
        )

        let savedProject = try await repository.create(project)
        return try ProjectDTO(project: savedProject)
    }

    func requireOwnedProject(id projectID: UUID, userID: UUID) async throws -> Project {
        guard let project = try await repository.findOwnedProject(id: projectID, userID: userID) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        return project
    }
}
