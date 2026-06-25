import Vapor

struct AppleJWKSResponse: Content {
    let keys: [AppleJWK]
}

struct AppleJWK: Content {
    let kty: String
    let kid: String
    let use: String?
    let alg: String?
    let n: String
    let e: String
}