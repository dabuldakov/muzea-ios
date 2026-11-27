import Foundation
import os

/// Единственный владелец обновления пары токенов.
///
/// Refresh-токен одноразовый: повторное использование отзывает всю family и
/// разлогинивает пользователя. Поэтому все параллельные 401 ждут один общий
/// запрос, а запрос, чей токен уже заменён, не делает второй refresh.
actor TokenRefresher {
    private static let logger = Logger(subsystem: "com.cyber.muzea", category: "Auth")

    private let client: HTTPClient
    private let store: TokenStore
    private var inFlight: Task<Bool, Never>?
    private var expiredHandler: (@Sendable () -> Void)?

    init(client: HTTPClient, store: TokenStore) {
        self.client = client
        self.store = store
    }

    func setExpiredHandler(_ handler: @escaping @Sendable () -> Void) {
        expiredHandler = handler
    }

    /// `failedToken` — токен, с которым ушёл запрос, получивший 401/403.
    func refresh(failedToken: String?) async -> Bool {
        if let failedToken, !failedToken.isEmpty {
            // Пока запрос ждал, токен уже обновил другой запрос.
            if let current = store.token, !current.isEmpty, current != failedToken {
                return true
            }
        } else {
            // Запрос ушёл без access-токена. Это может быть сбой чтения
            // Keychain: если в хранилище нет текущего токена, но есть refresh,
            // пробуем восстановить сессию. Если токен есть — 401 не наш.
            guard (store.token ?? "").isEmpty else { return false }
        }

        if let inFlight {
            return await inFlight.value
        }

        let task = Task { await self.performRefresh() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private func performRefresh() async -> Bool {
        guard let refreshToken = store.refreshToken, !refreshToken.isEmpty else {
            Self.logger.error("refresh skipped: no refresh token in store")
            expireIfSessionExists()
            return false
        }

        do {
            let response: AuthTokenResponse = try await client.request(
                "POST",
                "/auth/token/refresh",
                body: AuthRefreshRequest(refreshToken: refreshToken, deviceId: store.deviceId),
                authorized: false
            )
            // Сначала refresh, потом access: если процесс убьют между записями,
            // на диске останется новый refresh и старый access. Следующий 401
            // обновит пару. Обратный порядок оставил бы уже использованный
            // refresh-токен, и сервер отозвал бы всю family.
            store.refreshToken = response.refreshToken
            store.token = response.accessToken
            if let user = response.user {
                if let username = user.username { store.username = username }
                if let email = user.email { store.email = email }
            }
            Self.logger.info("token refresh succeeded")
            return true
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                Self.logger.error("token refresh rejected: unauthorized")
                expireIfSessionExists()
            case .server(let code, _) where [400, 401, 403].contains(code):
                Self.logger.error("token refresh rejected: status=\(code)")
                expireIfSessionExists()
            default:
                // Сеть/5xx/разбор ответа: токены не трогаем, повторим позже.
                Self.logger.error("token refresh failed: \(error.localizedDescription, privacy: .public)")
            }
            return false
        } catch {
            Self.logger.error("token refresh failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Не дёргаем expired-handler повторно, если сессию уже очистил другой
    /// параллельный запрос.
    private func expireIfSessionExists() {
        guard !(store.token ?? "").isEmpty || !(store.refreshToken ?? "").isEmpty else { return }
        expire()
    }

    private func expire() {
        store.clearSession()
        expiredHandler?()
    }
}
