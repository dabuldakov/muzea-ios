import Foundation

/// Пара HTTP-клиентов к двум бэкендам приложения.
final class API {
    let makeup: HTTPClient
    let chat: HTTPClient

    init(tokenStore: TokenStore) {
        makeup = HTTPClient(baseURL: Config.makeupBaseURL) { tokenStore.token }
        chat = HTTPClient(baseURL: Config.chatBaseURL) { tokenStore.chatToken }
    }
}
