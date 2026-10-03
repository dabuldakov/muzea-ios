import Foundation

/// Общая для чат-репозиториев обёртка авторизации: гарантирует аутентификацию
/// на chat-сервере и один раз повторяет запрос после инвалидации токена на 401.
///
/// Вынесена из бывшего god-репозитория, чтобы каждый SRP-репозиторий не дублировал
/// логику повторного входа.
final class ChatAuthorization {
    let client: HTTPClient
    let auth: ChatAuthManager

    init(client: HTTPClient, auth: ChatAuthManager) {
        self.client = client
        self.auth = auth
    }

    func authorized<T>(_ operation: () async throws -> T) async throws -> T {
        guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
        do {
            return try await operation()
        } catch APIError.unauthorized {
            auth.invalidate()
            guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
            return try await operation()
        }
    }

    /// Аутентификация без повтора: нужна там, где 401 — ожидаемый ответ
    /// (например, удаление аккаунта, после которого сессия уже уничтожена).
    func ensureAuthenticated() async -> Bool {
        await auth.ensureAuthenticated()
    }

    func invalidate() {
        auth.invalidate()
    }
}
