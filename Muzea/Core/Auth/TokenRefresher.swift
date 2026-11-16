import Foundation

/// Единственный владелец обновления пары токенов.
///
/// Refresh-токен одноразовый: повторное использование отзывает всю family и
/// разлогинивает пользователя. Поэтому все параллельные 401 ждут один общий
/// запрос, а запрос, чей токен уже заменён, не делает второй refresh.
actor TokenRefresher {
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
        guard let failedToken, !failedToken.isEmpty else { return false }

        // Пока запрос ждал, токен уже обновил другой запрос.
        if store.token != failedToken {
            return true
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
            expire()
            return false
        }

        do {
            let response: AuthTokenResponse = try await client.request(
                "POST",
                "/auth/token/refresh",
                body: AuthRefreshRequest(refreshToken: refreshToken, deviceId: store.deviceId),
                authorized: false
            )
            store.token = response.accessToken
            store.refreshToken = response.refreshToken
            if let user = response.user {
                if let username = user.username { store.username = username }
                if let email = user.email { store.email = email }
            }
            return true
        } catch {
            expire()
            return false
        }
    }

    private func expire() {
        store.clearSession()
        expiredHandler?()
    }
}
