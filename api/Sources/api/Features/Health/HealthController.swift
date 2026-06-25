import Vapor

struct HealthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("health", use: health)
    }

    func health(req: Request) async throws -> HealthResponse {
        HealthResponse(
            status: "ok",
            service: "Shotup Cloud API"
        )
    }
}

struct HealthResponse: Content {
    let status: String
    let service: String
}