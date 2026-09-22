import Foundation
@testable import Muzea

enum TestSupport {

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func makeupClient(tokenStore: TokenStore) -> HTTPClient {
        HTTPClient(
            baseURL: Config.makeupBaseURL,
            tokenProvider: { tokenStore.token },
            session: session()
        )
    }

    static func chatClient(tokenStore: TokenStore) -> HTTPClient {
        HTTPClient(
            baseURL: Config.chatBaseURL,
            tokenProvider: { tokenStore.chatToken },
            session: session()
        )
    }

    /// Изолированный UserDefaults, чтобы тесты не влияли друг на друга.
    static func makeStore() -> TokenStore {
        let defaults = UserDefaults(suiteName: "muzea-tests-\(UUID().uuidString)")!
        return TokenStore(defaults: defaults)
    }

    static func data(_ json: String) -> Data { Data(json.utf8) }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(json))
    }
}