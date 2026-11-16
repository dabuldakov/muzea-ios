import Foundation

/// Общая для чат-репозиториев обёртка авторизации: гарантирует, что сессия IdP
/// жива и chat-профиль получен. Обновление токена и повтор запроса после 401
/// выполняет `HTTPClient` через `TokenRefresher` — здесь дублировать нельзя,
/// иначе получится второй refresh и отзыв family.
final class ChatAuthorization {
    let client: HTTPClient
    let auth: ChatAuthManager

    init(client: HTTPClient, auth: ChatAuthManager) {
        self.client = client
        self.auth = auth
    }

    func authorized<T>(_ operation: () async throws -> T) async throws -> T {
        guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
        return try await operation()
    }

    /// Аутентификация без выполнения запроса (например, перед удалением
    /// аккаунта, где 401 — ожидаемый ответ).
    func ensureAuthenticated() async -> Bool {
        await auth.ensureAuthenticated()
    }
}
