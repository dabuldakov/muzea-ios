import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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
            tokenProvider: { tokenStore.token },
            session: session()
        )
    }

    static func authClient(tokenStore: TokenStore) -> HTTPClient {
        HTTPClient(
            baseURL: Config.authBaseURL,
            tokenProvider: { tokenStore.token },
            session: session()
        )
    }

    /// Изолированный UserDefaults, чтобы тесты не влияли друг на друга.
    /// Токены — в памяти, чтобы не трогать Keychain симулятора.
    static func makeStore() -> TokenStore {
        let defaults = UserDefaults(suiteName: "muzea-tests-\(UUID().uuidString)")!
        return TokenStore(defaults: defaults, tokens: InMemoryTokenStore())
    }

    static func makeStore(
        defaults: UserDefaults,
        tokens: SecureTokenStoring = InMemoryTokenStore()
    ) -> TokenStore {
        TokenStore(defaults: defaults, tokens: tokens)
    }

    static func data(_ json: String) -> Data { Data(json.utf8) }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(json))
    }

    /// Secure-хранилище, запоминающее порядок записей токенов.
    final class RecordingTokenStore: SecureTokenStoring {
        private(set) var writes: [String] = []
        private(set) var clears = 0

        var accessToken: String? {
            didSet {
                if accessToken != oldValue { writes.append("access") }
            }
        }

        var refreshToken: String? {
            didSet {
                if refreshToken != oldValue { writes.append("refresh") }
            }
        }

        func clear() {
            clears += 1
            accessToken = nil
            refreshToken = nil
        }

        func resetWrites() {
            writes.removeAll()
        }
    }

    /// Secure-хранилище, у которого можно смоделировать сбой чтения/удаления,
    /// сохранив при этом значения (как при `errSecInteractionNotAllowed`).
    final class UnreliableTokenStore: SecureTokenStoring {
        private var storedAccess: String?
        private var storedRefresh: String?
        var failReads = false
        var failClear = false

        var accessToken: String? {
            get { failReads ? nil : storedAccess }
            set { storedAccess = newValue }
        }

        var refreshToken: String? {
            get { failReads ? nil : storedRefresh }
            set { storedRefresh = newValue }
        }

        func clear() {
            guard !failClear else { return }
            storedAccess = nil
            storedRefresh = nil
        }
    }
}
