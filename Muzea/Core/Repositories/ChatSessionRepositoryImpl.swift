import Foundation

/// Реализация `ChatSessionRepository`: сессия на chat-сервере, heartbeat и
/// удаление аккаунта.
final class ChatSessionRepositoryImpl: ChatSessionRepository {
    private let auth: ChatAuthorization

    init(auth: ChatAuthorization) {
        self.auth = auth
    }

    /// Полное удаление аккаунта на чат-сервере вместе с сообщениями, контактами,
    /// вложениями и FCM-токенами.
    ///
    /// Намеренно обходится без повторной авторизации: сервер отвечает 401 после
    /// удаления, а перерегистрация тут же создала бы аккаунт заново. 401 и 404
    /// считаются успехом.
    func deleteAccount() async throws {
        guard await auth.ensureAuthenticated() else { throw APIError.unauthorized }
        do {
            try await auth.client.requestVoid("DELETE", "/api/users/me")
        } catch APIError.unauthorized {
            return
        } catch APIError.server(let code, _) where code == 404 {
            return
        }
    }

    /// Heartbeat «я на переднем плане». Тихий метод: ошибку показывать нечего,
    /// упавший удар значит лишь «статус обновится чуть позже». Возвращает успех.
    func sendHeartbeat() async -> Bool {
        guard await auth.ensureAuthenticated() else { return false }
        do {
            try await auth.client.requestVoid("POST", "/api/presence/heartbeat")
            return true
        } catch {
            return false
        }
    }

    func totalUnreadCount() async throws -> Int64 {
        let response: UnreadCountResponse = try await auth.authorized {
            try await auth.client.request("GET", "/api/chats/unread-count/all")
        }
        return response.count
    }
}
