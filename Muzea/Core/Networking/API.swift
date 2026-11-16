import Foundation

/// Три HTTP-клиента: IdP и два ресурсных сервиса.
///
/// Все ресурсные запросы используют один access-токен IdP. Клиенты `makeup` и
/// `chat` получают `unauthorizedHandler` в `AppContainer`, который обновляет
/// пару токенов и повторяет запрос. У `auth` обработчика нет: `/auth/token/refresh`
/// не должен рекурсивно обновлять сам себя.
final class API {
    let auth: HTTPClient
    let makeup: HTTPClient
    let chat: HTTPClient

    init(tokenStore: TokenStore) {
        auth = HTTPClient(baseURL: Config.authBaseURL) { tokenStore.token }
        makeup = HTTPClient(baseURL: Config.makeupBaseURL) { tokenStore.token }
        chat = HTTPClient(baseURL: Config.chatBaseURL) { tokenStore.token }
    }
}
