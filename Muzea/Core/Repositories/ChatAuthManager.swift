import Foundation

/// Аутентификация на chat-сервере: проверяет владельца сохранённого токена,
/// при необходимости логинится/регистрируется и регистрирует FCM-токен.
final class ChatAuthManager {
    private let client: HTTPClient
    private let store: TokenStore

    /// Причина последней неудачной аутентификации (nil — успех).
    private(set) var lastFailureMessage: String?

    init(client: HTTPClient, store: TokenStore) {
        self.client = client
        self.store = store
    }

    @discardableResult
    func ensureAuthenticated() async -> Bool {
        lastFailureMessage = nil
        if let token = store.chatToken, !token.isEmpty {
            if let current = store.username,
               store.chatTokenUser != current {
                invalidate()
            } else {
                await registerFcmTokenIfNeeded()
                return true
            }
        }

        guard let username = store.username, !username.isEmpty,
              let password = store.password, !password.isEmpty else {
            lastFailureMessage = "No saved credentials. Please log in to the app first."
            return false
        }

        if await tryLogin(username: username, password: password) {
            await registerFcmTokenIfNeeded()
            return true
        }
        if await tryRegister(username: username, password: password) {
            await registerFcmTokenIfNeeded()
            return true
        }
        return false
    }

    func invalidate() {
        store.chatToken = nil
        store.chatTokenUser = nil
    }

    private func tryLogin(username: String, password: String) async -> Bool {
        do {
            let response: ChatAuthResponse = try await client.request(
                "POST",
                "/api/auth/login",
                body: ChatLoginRequest(
                    username: username,
                    password: password,
                    deviceId: store.deviceId,
                    deviceName: store.deviceName,
                    deviceType: store.deviceType
                ),
                authorized: false
            )
            store.chatToken = response.token
            store.chatTokenUser = username
            return true
        } catch let error as APIError {
            if case .server(let code, _) = error {
                lastFailureMessage = "Login rejected by the chat server (HTTP \(code))."
            } else {
                lastFailureMessage = "Cannot reach the chat server."
            }
            return false
        } catch {
            lastFailureMessage = "Cannot reach the chat server."
            return false
        }
    }

    private func tryRegister(username: String, password: String) async -> Bool {
        let email = store.email ?? "\(username)@example.com"
        do {
            let response: ChatAuthResponse = try await client.request(
                "POST",
                "/api/auth/register",
                body: ChatRegisterRequest(
                    username: username,
                    email: email,
                    password: password,
                    deviceId: store.deviceId,
                    deviceName: store.deviceName,
                    deviceType: store.deviceType
                ),
                authorized: false
            )
            store.chatToken = response.token
            store.chatTokenUser = username
            return true
        } catch let error as APIError {
            if case .server(let code, _) = error, code == 409 {
                lastFailureMessage = "Chat account \"\(username)\" already exists on the chat server " +
                    "with another password (likely from an older install). Log in with that password, " +
                    "or use a different username."
            } else if case .server(let code, _) = error {
                lastFailureMessage = "Registration rejected by the chat server (HTTP \(code))."
            } else {
                lastFailureMessage = "Cannot reach the chat server."
            }
            return false
        } catch {
            lastFailureMessage = "Cannot reach the chat server."
            return false
        }
    }

    private func registerFcmTokenIfNeeded() async {
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
            // Повторим при следующей проверке аутентификации.
        }
    }
}
