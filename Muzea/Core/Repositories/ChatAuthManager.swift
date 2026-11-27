import Foundation
import os

/// Готовность к работе с chat-сервером на едином access-токене IdP.
///
/// Раньше здесь был отдельный логин/регистрация на chat-сервере по паролю.
/// Теперь chat принимает тот же JWT (через JWKS), поэтому остаётся только
/// однократно получить локальный chat-профиль (нужен `userUuid`) и
/// зарегистрировать FCM-токен.
final class ChatAuthManager {
    private static let logger = Logger(subsystem: "com.cyber.muzea", category: "ChatAuth")

    private let client: HTTPClient
    private let store: TokenStore

    init(client: HTTPClient, store: TokenStore) {
        self.client = client
        self.store = store
    }

    @discardableResult
    func ensureAuthenticated() async -> Bool {
        guard let token = store.token, !token.isEmpty else {
            return false
        }
        await ensureChatProfile()
        await registerFcmTokenIfAny()
        return true
    }

    /// Однократно тянет профиль на chat-сервере: это провижинит локального
    /// пользователя и даёт его `userUuid` (нужен для чатов/контактов).
    private func ensureChatProfile() async {
        if let uuid = store.chatUserUuid, !uuid.isEmpty { return }
        do {
            let user: ChatUserResponse = try await client.request("GET", "/api/users/me")
            if !user.userUuid.isEmpty {
                store.chatUserUuid = user.userUuid
            }
        } catch {
            Self.logger.error("chat profile fetch failed: \(error.localizedDescription, privacy: .public)")
            // Попробуем при следующем обращении.
        }
    }

    private func registerFcmTokenIfAny() async {
        guard let token = store.fcmToken, !token.isEmpty else { return }
        guard token != store.registeredFcmToken else { return }
        do {
            try await client.requestVoid(
                "PUT",
                "/api/users/me/fcm-token",
                body: FcmTokenRequest(token: token, deviceId: store.deviceId)
            )
            store.registeredFcmToken = token
        } catch {
            Self.logger.error("fcm token registration failed: \(error.localizedDescription, privacy: .public)")
            // Повторим при следующей проверке аутентификации.
        }
    }
}
