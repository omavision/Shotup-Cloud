import Vapor

struct JWTHeader: Content {
    let alg: String
    let kid: String
    let typ: String?
}