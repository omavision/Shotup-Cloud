import Foundation

extension SyncChange {
    func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        guard let payload else {
            throw DecodingError.valueNotFound(
                T.self,
                .init(
                    codingPath: [],
                    debugDescription: "Missing payload"
                )
            )
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(T.self, from: data)
    }
}