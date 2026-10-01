import Foundation

final class AuthRepository {
    private let client: HTTPClient
    private let store: TokenStore

    init(client: HTTPClient, store: TokenStore) {
        self.client = client
        self.store = store
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await client.request(
            "POST",
            "/auth/login",
            body: LoginRequest(username: username, password: password),
            authorized: false
        )
        store.token = response.token
        store.username = response.username
        store.password = password
        return response
    }

    func register(username: String, email: String, password: String, fullName: String) async throws -> AuthResponse {
        let response: AuthResponse = try await client.request(
            "POST",
            "/auth/register",
            body: RegisterRequest(username: username, email: email, password: password, fullName: fullName),
            authorized: false
        )
        store.token = response.token
        store.username = response.username
        store.email = email
        store.password = password
        return response
    }

    func currentUser() async throws -> UserResponse {
        try await client.request("GET", "/api/users/me")
    }

    func updateUser(id: Int64, fullName: String, email: String) async throws -> UserResponse {
        try await client.request(
            "PUT",
            "/api/users/\(id)",
            body: UpdateUserRequest(fullName: fullName, email: email, enabled: true)
        )
    }

    /// Удаление новостей, видео и профиля на основном бэкенде.
    ///
    /// 404 считается успехом: аккаунт мог быть удалён при предыдущей попытке,
    /// где чат-сервер отвечает раньше основного.
    func deleteAccount(id: Int64) async throws {
        do {
            try await client.requestVoid("DELETE", "/api/users/\(id)")
        } catch APIError.server(let code, _) where code == 404 {
            return
        }
    }

    func logout() {
        store.clear()
    }
}
