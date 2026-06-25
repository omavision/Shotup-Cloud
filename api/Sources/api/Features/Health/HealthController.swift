import Vapor

struct HealthController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        routes.get("health", use: health)
    }

    @Sendable
    func health(req: Request) async throws -> APIResponse<HealthResponse> {
        APIResponse(
            data: HealthResponse(
                status: "ok",
                service: "Shotup Cloud API",
                version: "0.1.0"
            )
        )
    }
}

struct HealthResponse: Content {
    let status: String
    let service: String
    let version: String
}