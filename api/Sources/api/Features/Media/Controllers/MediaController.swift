import Fluent
import Vapor

struct MediaController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("request-upload", use: requestUpload)
        routes.post("confirm-upload", use: confirmUpload)
    }

    @Sendable
    func requestUpload(req: Request) async throws -> Response {
        let traceID = MediaUploadTrace.resolve(from: req)
        var logger = req.logger
        logger[metadataKey: "traceID"] = .string(traceID)

        let auth = try req.auth.require(AuthenticatedUser.self)
        let payload = try req.content.decode(RequestUploadRequest.self)

        guard let storage = req.application.r2Storage else {
            throw Abort(.internalServerError, reason: "Storage service unavailable")
        }

        let repository = FluentMediaRepository(database: req.db)
        let service = MediaService(database: req.db, storage: storage, repository: repository)

        logger.info("media.upload.request.started", metadata: [
            "event": .string("media.upload.request.started"),
            "userID": .string(auth.id.uuidString),
            "projectID": .string(payload.projectID.uuidString),
            "sceneID": .string(payload.sceneID.uuidString),
            "frameID": .string(payload.frameID.uuidString)
        ])

        let start = Date()

        do {
            let response = try await service.requestUpload(userID: auth.id, payload: payload)
            let requestDurationMs = MediaUploadTrace.durationMilliseconds(since: start)

            logger.info("media.upload.request.completed", metadata: [
                "event": .string("media.upload.request.completed"),
                "objectKey": .string(response.objectKey),
                "requestDurationMs": .stringConvertible(requestDurationMs)
            ])

            let apiResponse = try await APIResponse(data: response).encodeResponse(for: req)
            apiResponse.headers.replaceOrAdd(name: MediaUploadTrace.headerName, value: traceID)
            return apiResponse
        } catch {
            let requestDurationMs = MediaUploadTrace.durationMilliseconds(since: start)
            let reason = (error as? any AbortError)?.reason ?? String(describing: error)

            logger.warning("media.upload.request.failed", metadata: [
                "event": .string("media.upload.request.failed"),
                "reason": .string(reason),
                "requestDurationMs": .stringConvertible(requestDurationMs)
            ])

            throw error
        }
    }

    @Sendable
    func confirmUpload(req: Request) async throws -> Response {
        let traceID = MediaUploadTrace.resolve(from: req)
        var logger = req.logger
        logger[metadataKey: "traceID"] = .string(traceID)

        let auth = try req.auth.require(AuthenticatedUser.self)
        let payload = try req.content.decode(ConfirmUploadRequest.self)

        guard let storage = req.application.r2Storage else {
            throw Abort(.internalServerError, reason: "Storage service unavailable")
        }

        let repository = FluentMediaRepository(database: req.db)
        let service = MediaService(database: req.db, storage: storage, repository: repository)

        logger.info("media.upload.confirm.started", metadata: [
            "event": .string("media.upload.confirm.started"),
            "userID": .string(auth.id.uuidString),
            "objectKey": .string(payload.objectKey)
        ])

        let pendingAsset = try? await repository.findPendingUpload(objectKey: payload.objectKey)
        let start = Date()

        do {
            let response = try await service.confirmUpload(userID: auth.id, payload: payload)
            let confirmDurationMs = MediaUploadTrace.durationMilliseconds(since: start)

            var metadata: Logger.Metadata = [
                "event": .string("media.upload.confirm.completed"),
                "objectKey": .string(payload.objectKey),
                "confirmDurationMs": .stringConvertible(confirmDurationMs)
            ]

            if let createdAt = pendingAsset?.createdAt {
                metadata["putDurationMs"] = .stringConvertible(
                    MediaUploadTrace.durationMilliseconds(since: createdAt, until: start)
                )
                metadata["totalDurationMs"] = .stringConvertible(
                    MediaUploadTrace.durationMilliseconds(since: createdAt)
                )
            }

            logger.info("media.upload.confirm.completed", metadata: metadata)

            let apiResponse = try await APIResponse(data: response).encodeResponse(for: req)
            apiResponse.headers.replaceOrAdd(name: MediaUploadTrace.headerName, value: traceID)
            return apiResponse
        } catch {
            let confirmDurationMs = MediaUploadTrace.durationMilliseconds(since: start)
            let reason = (error as? any AbortError)?.reason ?? String(describing: error)

            var metadata: Logger.Metadata = [
                "event": .string("media.upload.confirm.failed"),
                "objectKey": .string(payload.objectKey),
                "reason": .string(reason),
                "confirmDurationMs": .stringConvertible(confirmDurationMs)
            ]

            if reason == MediaService.objectNotFoundInStorageReason {
                metadata["retryReason"] = .string("object_not_yet_visible_in_storage")
            }

            logger.warning("media.upload.confirm.failed", metadata: metadata)

            throw error
        }
    }
}
