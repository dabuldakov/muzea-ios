import Foundation

/// Реализация `AuthRepositoryProtocol` на основном бэкенде: вход/регистрация и
/// сохранение сессии. Профиль пользователя вынесен в `UserRepositoryImpl`.
final class AuthRepositoryImpl: AuthRepositoryProtocol {
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

    func logout() {
        store.clear()
    }
}
