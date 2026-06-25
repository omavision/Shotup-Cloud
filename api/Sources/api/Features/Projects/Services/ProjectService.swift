import Vapor

struct ProjectService {
    let repository: ProjectRepository

    func listProjects(for userID: UUID) async throws -> [ProjectDTO] {
        let projects = try await repository.list(for: userID)
        return try projects.map { try ProjectDTO(project: $0) }
    }

    func createProject(from request: CreateProjectRequest) async throws -> ProjectDTO {
        let project = Project(
            userID: request.userID,
            title: request.title,
            notes: request.notes
        )

        let savedProject = try await repository.create(project)
        return try ProjectDTO(project: savedProject)
    }
}