import Vapor

struct AppleSignInRequest: Content {
    let identityToken: String
    let authorizationCode: String?
    let displayName: String?
    let deviceName: String?
}