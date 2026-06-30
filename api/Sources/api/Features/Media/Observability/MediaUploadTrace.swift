import Vapor

enum MediaUploadTrace {
    static let headerName = "X-Trace-ID"

    static func resolve(from req: Request) -> String {
        req.headers.first(name: headerName) ?? UUID().uuidString
    }

    static func durationMilliseconds(since start: Date, until end: Date = Date()) -> Int {
        Int((end.timeIntervalSince(start) * 1_000).rounded())
    }
}
